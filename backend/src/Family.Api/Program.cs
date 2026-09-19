using Family.Api.Auth;
using Family.Api.Data;
using Family.Api.Domain;
using Family.Api.Endpoints;
using Family.Api.Push;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<AppDbContext>(o =>
    o.UseNpgsql(builder.Configuration.GetConnectionString("Postgres")));

// FCM when a service account is configured (a gitignored file in secrets/), a
// logging stand-in otherwise, so development works without Google credentials.
var fcmAccount = builder.Configuration["Push:FcmServiceAccountFile"];
if (fcmAccount is not null && File.Exists(Path.Combine(builder.Environment.ContentRootPath, fcmAccount)))
{
    var path = Path.Combine(builder.Environment.ContentRootPath, fcmAccount);
    builder.Services.AddHttpClient(nameof(FcmPushSender));
    builder.Services.AddSingleton<IPushSender>(sp => FcmPushSender.FromFile(
        path,
        sp.GetRequiredService<IHttpClientFactory>().CreateClient(nameof(FcmPushSender)),
        sp.GetRequiredService<ILogger<FcmPushSender>>()));
}
else
{
    builder.Services.AddSingleton<IPushSender, LoggingPushSender>();
}
builder.Services.AddHostedService<WakeSender>();
builder.Services.AddMemoryCache();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddOpenApi();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    await db.Database.MigrateAsync();
}

app.UseMiddleware<DeviceAuthMiddleware>();

app.MapGet("/v1/health", () => Results.Ok(new { status = "ok", utc = DateTimeOffset.UtcNow }));

app.MapDevices();
app.MapSync();
app.MapCommands();
app.MapSchedule();
app.MapPairing();
app.MapMls();

app.Run();

// ---------------------------------------------------------------------------

/// <summary>
/// Development-grade device authentication: the device sends its id, and we look
/// it up. Before any external user, replace with signature verification — the
/// device signs a challenge with its Ed25519 key and we verify against the stored
/// public key. The shape of every endpoint stays the same; only this changes.
/// </summary>
public class DeviceAuthMiddleware
{
    // Exact method and path. A prefix match here once made every route under
    // /v1/families and /v1/devices anonymous, the key directory included.
    // Registering a device is not anonymous: a parent's device does it.
    private static readonly (string Method, string Path)[] Anonymous =
    {
        ("GET", "/v1/health"),
        ("POST", "/v1/families"),
    };

    /// <summary>
    /// A new device collects its admission before it has a device id to
    /// authenticate with (crypto doc §7.1).
    /// </summary>
    private const string MailboxPrefix = "/v1/pairing/mailbox/";

    private readonly RequestDelegate _next;
    public DeviceAuthMiddleware(RequestDelegate next) => _next = next;

    public async Task InvokeAsync(HttpContext ctx, AppDbContext db, IWebHostEnvironment env, IMemoryCache cache)
    {
        var path = (ctx.Request.Path.Value ?? "").TrimEnd('/');
        var method = ctx.Request.Method;

        var anonymous = Anonymous.Any(a =>
                a.Method == method && string.Equals(a.Path, path, StringComparison.OrdinalIgnoreCase))
            || (method == "GET" && path.StartsWith(MailboxPrefix, StringComparison.Ordinal)
                && !path[MailboxPrefix.Length..].Contains('/'))
            // The OpenAPI document is mapped in Development only.
            || (env.IsDevelopment() && path.StartsWith("/openapi", StringComparison.OrdinalIgnoreCase));

        if (anonymous)
        {
            await _next(ctx);
            return;
        }

        var headers = ctx.Request.Headers;
        if (!Guid.TryParse(headers[RequestSignature.DeviceHeader], out var deviceId)
            || !long.TryParse(headers[RequestSignature.TimestampHeader], out var timestampMs)
            || !TryBase64(headers[RequestSignature.SignatureHeader], out var signature))
        {
            await Reject(ctx, "missing_signature");
            return;
        }

        var skew = DateTimeOffset.UtcNow - DateTimeOffset.FromUnixTimeMilliseconds(timestampMs);
        if (skew.Duration() > RequestSignature.MaxSkew)
        {
            await Reject(ctx, "clock_skew");
            return;
        }

        var device = await db.Devices.FirstOrDefaultAsync(d => d.Id == deviceId && d.RevokedAt == null);
        if (device is null)
        {
            await Reject(ctx, "unknown_device");
            return;
        }

        // The body is covered by the signature, so it's read here and rewound
        // for the endpoint.
        ctx.Request.EnableBuffering();
        using var buffer = new MemoryStream();
        await ctx.Request.Body.CopyToAsync(buffer, ctx.RequestAborted);
        ctx.Request.Body.Position = 0;

        // The target exactly as sent, before any decoding, is what was signed.
        var target = ctx.Features.Get<IHttpRequestFeature>()?.RawTarget
                     ?? ctx.Request.Path + ctx.Request.QueryString;
        var message = RequestSignature.Message(
            deviceId.ToString(), method, target, timestampMs, buffer.ToArray());
        if (!RequestSignature.Verify(device.SigningPublicKey, message, signature))
        {
            await Reject(ctx, "bad_signature");
            return;
        }

        // A captured request can't be sent again inside the skew window.
        var replayKey = $"req:{deviceId}:{Convert.ToBase64String(signature)}";
        if (cache.TryGetValue(replayKey, out _))
        {
            await Reject(ctx, "replayed");
            return;
        }
        cache.Set(replayKey, true, RequestSignature.MaxSkew * 2);

        ctx.Items["device"] = device;
        await _next(ctx);
    }

    private static bool TryBase64(string? value, out byte[] bytes)
    {
        bytes = [];
        if (string.IsNullOrEmpty(value)) return false;
        try
        {
            bytes = Convert.FromBase64String(value);
            return true;
        }
        catch (FormatException)
        {
            return false;
        }
    }

    /// <summary>401 with a reason a client can act on (a skewed clock, say), and nothing more.</summary>
    private static Task Reject(HttpContext ctx, string reason)
    {
        ctx.Response.StatusCode = StatusCodes.Status401Unauthorized;
        return ctx.Response.WriteAsJsonAsync(new { error = reason });
    }
}

public static class HttpContextExtensions
{
    public static Device GetDevice(this HttpContext ctx)
        => ctx.Items["device"] as Device
           ?? throw new InvalidOperationException("No authenticated device on this request.");
}
