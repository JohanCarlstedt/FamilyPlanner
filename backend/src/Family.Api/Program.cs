using Family.Api.Data;
using Family.Api.Domain;
using Family.Api.Endpoints;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<AppDbContext>(o =>
    o.UseNpgsql(builder.Configuration.GetConnectionString("Postgres")));

builder.Services.AddSingleton<IPushSender, LoggingPushSender>();
builder.Services.AddHostedService<WakeSender>();
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
    private static readonly string[] Anonymous =
    {
        "/v1/health", "/v1/families", "/v1/devices", "/openapi"
    };

    private readonly RequestDelegate _next;
    public DeviceAuthMiddleware(RequestDelegate next) => _next = next;

    public async Task InvokeAsync(HttpContext ctx, AppDbContext db)
    {
        var path = ctx.Request.Path.Value ?? "";

        if (Anonymous.Any(p => path.StartsWith(p, StringComparison.OrdinalIgnoreCase))
            && !path.Contains("/devices/push-token"))
        {
            await _next(ctx);
            return;
        }

        if (!ctx.Request.Headers.TryGetValue("X-Device-Id", out var raw)
            || !Guid.TryParse(raw, out var deviceId))
        {
            ctx.Response.StatusCode = StatusCodes.Status401Unauthorized;
            return;
        }

        var device = await db.Devices.FirstOrDefaultAsync(d => d.Id == deviceId && d.RevokedAt == null);
        if (device is null)
        {
            ctx.Response.StatusCode = StatusCodes.Status401Unauthorized;
            return;
        }

        ctx.Items["device"] = device;
        await _next(ctx);
    }
}

public static class HttpContextExtensions
{
    public static Device GetDevice(this HttpContext ctx)
        => ctx.Items["device"] as Device
           ?? throw new InvalidOperationException("No authenticated device on this request.");
}
