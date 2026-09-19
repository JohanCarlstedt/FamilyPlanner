using Family.Api.Data;
using Family.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Family.Api.Endpoints;

/// <summary>
/// Tells a family's other devices that something changed (spec §8 "Change
/// notifications"), without saying what: the server can't read it. Each gets
/// one contentless wake; the device syncs and decides what, if anything, its
/// member should hear.
/// </summary>
public static class ChangeWakes
{
    /// <summary>
    /// The reference a change wake carries. Device-chosen references are 32
    /// hex characters, so this can't collide with one.
    /// </summary>
    public const string Ref = "sync";

    /// <summary>
    /// Edits arrive in bursts (time, then place, then driver), and must reach
    /// people as one notification: the wake waits until the editing stops...
    /// </summary>
    public static readonly TimeSpan Settle = TimeSpan.FromMinutes(5);

    /// <summary>...but never longer than this after the first edit.</summary>
    public static readonly TimeSpan MaxDelay = TimeSpan.FromMinutes(15);

    public static async Task ScheduleAsync(AppDbContext db, Device author, CancellationToken ct)
    {
        var others = await db.Devices
            .Where(d => d.FamilyId == author.FamilyId && d.Id != author.Id
                        && d.RevokedAt == null && d.PushToken != null)
            .Select(d => d.Id)
            .ToListAsync(ct);
        if (others.Count == 0) return;

        var now = DateTimeOffset.UtcNow;
        var pending = await db.ScheduledWakes
            .Where(w => others.Contains(w.DeviceId) && w.CorrelationRef == Ref && w.State == "scheduled")
            .ToListAsync(ct);

        foreach (var deviceId in others)
        {
            var wake = pending.FirstOrDefault(w => w.DeviceId == deviceId);
            if (wake is null)
            {
                db.ScheduledWakes.Add(new ScheduledWake
                {
                    Id = Guid.NewGuid(),
                    FamilyId = author.FamilyId,
                    DeviceId = deviceId,
                    CorrelationRef = Ref,
                    FireAt = now + Settle,
                    CreatedAt = now
                });
            }
            else
            {
                var settled = now + Settle;
                var cap = wake.CreatedAt + MaxDelay;
                wake.FireAt = settled < cap ? settled : cap;
            }
        }
        await db.SaveChangesAsync(ct);
    }
}
