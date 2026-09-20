using Family.Api.Auth;
using Family.Api.Data;
using Family.Api.Domain;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

namespace Family.Api.Endpoints;

public record SaveRecoveryKitRequest(string LookupId, Guid DeviceId, string Note);

/// <summary>
/// Recovery kits (crypto doc §7.3). The server holds a lookup id, a device id
/// and a note it can't open; the words are the only way in.
/// </summary>
public static class RecoveryEndpoints
{
    public const string LookupPrefix = "/v1/recovery/";

    public static void MapRecovery(this IEndpointRouteBuilder app)
    {
        // A parent's device stores its member's kit, replacing any earlier one:
        // the old words stop working the moment new ones exist.
        app.MapPost("/v1/recovery", async (
            HttpContext http, AppDbContext db, SaveRecoveryKitRequest req, CancellationToken ct) =>
        {
            var caller = http.GetDevice();
            if (!IsLookupId(req.LookupId)) return Results.BadRequest(new { error = "bad_lookup_id" });
            var kitDevice = await db.Devices.FirstOrDefaultAsync(
                d => d.Id == req.DeviceId && d.FamilyId == caller.FamilyId
                     && d.MemberId == caller.MemberId && d.Platform == "recovery"
                     && d.RevokedAt == null, ct);
            if (kitDevice is null) return Results.BadRequest(new { error = "not_a_recovery_device" });

            var earlier = await db.RecoveryKits.Where(k => k.MemberId == caller.MemberId).ToListAsync(ct);
            foreach (var old in earlier)
            {
                if (old.DeviceId != kitDevice.Id)
                {
                    var device = await db.Devices.FindAsync([old.DeviceId], ct);
                    if (device is not null) device.RevokedAt ??= DateTimeOffset.UtcNow;
                }
                db.RecoveryKits.Remove(old);
            }
            db.RecoveryKits.Add(new RecoveryKit
            {
                LookupId = req.LookupId,
                FamilyId = caller.FamilyId,
                MemberId = caller.MemberId,
                DeviceId = kitDevice.Id,
                Note = Convert.FromBase64String(req.Note)
            });
            await db.SaveChangesAsync(ct);
            return Results.NoContent();
        });

        // Anonymous: every device is gone. The id is 128 bits derived from the
        // words, so it can't be guessed, and it reveals nothing without them.
        app.MapGet("/v1/recovery/{lookupId}", async (
            AppDbContext db, string lookupId, CancellationToken ct) =>
        {
            if (!IsLookupId(lookupId)) return Results.NotFound();
            var kit = await db.RecoveryKits.AsNoTracking().FirstOrDefaultAsync(k => k.LookupId == lookupId, ct);
            if (kit is null) return Results.NotFound();
            var device = await db.Devices.AsNoTracking().FirstOrDefaultAsync(d => d.Id == kit.DeviceId, ct);
            if (device is null || device.RevokedAt is not null) return Results.NotFound();
            return Results.Ok(new
            {
                deviceId = kit.DeviceId,
                familyId = kit.FamilyId,
                memberId = kit.MemberId,
                note = Convert.ToBase64String(kit.Note)
            });
        })
        // The kit answers on an id alone, so guessing at it is the attack.
        // Slow enough that guessing is hopeless, fast enough for someone
        // typing their recovery words in badly the first time.
        .RequireRateLimiting(RateLimiting.Lookup);
    }

    public static bool IsLookupId(string id) => id.Length == 32 && id.All(Uri.IsHexDigit);
}
