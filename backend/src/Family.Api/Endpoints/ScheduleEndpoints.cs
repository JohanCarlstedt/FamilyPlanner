using Family.Api.Contracts;
using Family.Api.Data;
using Family.Api.Domain;
using Family.Api.Push;
using Microsoft.EntityFrameworkCore;

namespace Family.Api.Endpoints;

public static class ScheduleEndpoints
{
    public static void MapSchedule(this IEndpointRouteBuilder app)
    {
        // The device computes leave-by times itself — it is the only party that can
        // read the event. It registers bare (device, timestamp) pairs here.
        app.MapPost("/v1/wakes", async (
            HttpContext http, AppDbContext db, RegisterWakesRequest req, CancellationToken ct) =>
        {
            var device = http.GetDevice();

            var cancelled = 0;
            if (req.CancelRefs.Count > 0)
            {
                var toCancel = await db.ScheduledWakes
                    .Where(w => w.DeviceId == device.Id
                                && w.State == "scheduled"
                                && req.CancelRefs.Contains(w.CorrelationRef))
                    .ToListAsync(ct);

                foreach (var w in toCancel) w.State = "cancelled";
                cancelled = toCancel.Count;
            }

            var scheduled = 0;
            foreach (var wake in req.Wakes)
            {
                // Npgsql only writes offset-zero DateTimeOffsets to timestamptz, and the
                // device naturally sends its local offset.
                var fireAt = wake.FireAt.ToUniversalTime();

                var existing = await db.ScheduledWakes.FirstOrDefaultAsync(
                    w => w.DeviceId == device.Id
                         && w.CorrelationRef == wake.CorrelationRef
                         && w.State == "scheduled", ct);

                if (existing is not null)
                {
                    existing.FireAt = fireAt;   // rescheduling is an update, not a duplicate
                    continue;
                }

                db.ScheduledWakes.Add(new ScheduledWake
                {
                    Id = Guid.NewGuid(),
                    FamilyId = device.FamilyId,
                    DeviceId = device.Id,
                    CorrelationRef = wake.CorrelationRef,
                    FireAt = fireAt
                });
                scheduled++;
            }

            await db.SaveChangesAsync(ct);
            return Results.Ok(new RegisterWakesResponse(scheduled, cancelled));
        });
    }
}

/// <summary>
/// Claims due wakes and sends contentless pushes. Uses FOR UPDATE SKIP LOCKED so
/// several instances can run without coordinating.
/// </summary>
public class WakeSender : BackgroundService
{
    private readonly IServiceScopeFactory _scopes;
    private readonly IPushSender _push;
    private readonly ILogger<WakeSender> _log;

    public WakeSender(IServiceScopeFactory scopes, IPushSender push, ILogger<WakeSender> log)
        => (_scopes, _push, _log) = (scopes, push, log);

    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            try
            {
                using var scope = _scopes.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

                // Row locks last only as long as the transaction. Without one, the SELECT
                // autocommits, the locks release immediately, and SKIP LOCKED protects nothing.
                await using var tx = await db.Database.BeginTransactionAsync(ct);

                var due = await db.ScheduledWakes
                    .FromSqlRaw("""
                        SELECT * FROM "ScheduledWakes"
                        WHERE "State" = 'scheduled' AND "FireAt" <= now()
                        ORDER BY "FireAt"
                        LIMIT 100
                        FOR UPDATE SKIP LOCKED
                        """)
                    .ToListAsync(ct);

                foreach (var wake in due)
                {
                    var device = await db.Devices.FindAsync(new object[] { wake.DeviceId }, ct);
                    if (device?.PushToken is null || device.RevokedAt is not null)
                    {
                        wake.State = "failed";
                        continue;
                    }

                    // Contentless by design. The payload carries a correlation reference
                    // and nothing else; the device decrypts locally and writes the
                    // notification text itself.
                    switch (await _push.SendSilentAsync(device.PushToken, wake.CorrelationRef, ct))
                    {
                        case PushResult.Sent:
                            wake.State = "sent";
                            wake.SentAt = DateTimeOffset.UtcNow;
                            break;
                        case PushResult.TokenGone:
                            device.PushToken = null;
                            wake.State = "failed";
                            break;
                        // Retried on the next pass, but a reminder ten minutes late is
                        // worse than none.
                        case PushResult.Failed when wake.FireAt < DateTimeOffset.UtcNow.AddMinutes(-10):
                            wake.State = "failed";
                            break;
                    }
                }

                await db.SaveChangesAsync(ct);
                await tx.CommitAsync(ct);
            }
            catch (Exception ex)
            {
                _log.LogError(ex, "Wake sender pass failed");
            }

            await Task.Delay(TimeSpan.FromSeconds(15), ct);
        }
    }
}
