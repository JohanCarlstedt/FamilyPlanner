using Family.Api.Auth;
using Family.Api.Data;
using Family.Api.Domain;
using Family.Api.Endpoints;
using Family.Api.Push;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.HttpOverrides;
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
// So a test can ask what a family is entitled to on a chosen day rather
// than only today.
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddHostedService<WakeSender>();
builder.Services.AddFamilyRateLimits();

// Caddy terminates TLS and forwards; without this every request looks like it
// came from the proxy, which would put the whole internet in one rate-limit
// partition. The proxy is trusted because nothing else can reach the API:
// compose publishes no port for it (infra/compose.yml). Publishing one makes
// these headers forgeable.
builder.Services.Configure<ForwardedHeadersOptions>(o =>
{
    o.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    o.KnownNetworks.Clear();
    o.KnownProxies.Clear();
});
builder.Services.AddMemoryCache();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddOpenApi();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

// Development migrates on every start. A deployed server migrates only when
// its configuration says to (infra/compose.yml sets it): the schema is
// expand-contract, so applying it early is safe for the clients still
// calling, but it should be a thing the deploy decided, not a side effect of
// a container restarting.
if (app.Environment.IsDevelopment()
    || builder.Configuration.GetValue<bool>("Database:ApplyMigrations"))
{
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    await db.Database.MigrateAsync();
}

app.UseForwardedHeaders();
// Before the signature check, so a flood costs a counter rather than a
// database lookup per request.
app.UseRateLimiter();

app.UseMiddleware<DeviceAuthMiddleware>();

app.MapGet("/v1/health", () => Results.Ok(new { status = "ok", utc = DateTimeOffset.UtcNow }));

app.MapDevices();
app.MapSync();
app.MapCommands();
app.MapSchedule();
app.MapPairing();
app.MapMls();
app.MapRecovery();
app.MapBlobs();
app.MapSubscriptions();

app.Run();

// ---------------------------------------------------------------------------

/// <summary>
/// Device authentication (crypto doc §2.2): every request outside the short
/// anonymous list carries the device id, a timestamp and an Ed25519 signature
/// over method, path, timestamp and body, verified here against the public key
/// the device registered. A revoked device is refused like an unknown one.
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
        // The billing provider has no device key. Guarded by a shared secret
        // inside the handler instead, and it may only write entitlement.
        ("POST", SubscriptionEndpoints.WebhookPath),
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
            // After total loss there's no device to sign with: the kit lookup
            // is anonymous, by an id only the recovery words give.
            || (method == "GET" && path.StartsWith(RecoveryEndpoints.LookupPrefix, StringComparison.Ordinal)
                && !path[RecoveryEndpoints.LookupPrefix.Length..].Contains('/'))
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

/// <summary>
/// Top-level statements compile to an internal Program; the test project
/// needs it visible to stand the application up in memory.
/// </summary>
public partial class Program;
