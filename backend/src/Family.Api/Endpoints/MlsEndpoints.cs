using Family.Api.Data;
using Family.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Family.Api.Endpoints;

public record PublishKeyPackagesRequest(List<string> KeyPackages);
public record ClaimKeyPackagesRequest(List<Guid> DeviceIds);
public record MlsCommitRequest(long Epoch, string Commit, string? Welcome, List<Guid>? WelcomeTo);
public record MlsApplicationRequest(long Epoch, string Message, string? Slot = null);

/// <summary>
/// The MLS delivery service (architecture doc §10, crypto doc §7.2): key
/// packages, commit ordering and an opaque relay. It can't read a message, and
/// devices don't take its word for who is in a group: they check members
/// against the devices they pinned at pairing.
/// </summary>
public static class MlsEndpoints
{
    /// <summary>Enough for a few additions without letting one device fill the table.</summary>
    private const int MaxUnclaimed = 20;

    /// <summary>The reference a chat wake carries.</summary>
    public const string ChatWakeRef = "chat";

    /// <summary>
    /// True when no device that ever committed, sent to or was welcomed into
    /// the group is still in the family.
    /// </summary>
    static async Task<bool> IsAbandoned(AppDbContext db, string groupId, CancellationToken ct)
    {
        var everIn = db.MlsMessages
            .Where(m => m.GroupId == groupId)
            .Select(m => m.RecipientDeviceId ?? m.SenderDeviceId);
        return !await db.Devices.AnyAsync(d => d.RevokedAt == null && everIn.Contains(d.Id), ct);
    }

    public static void MapMls(this IEndpointRouteBuilder app)
    {
        app.MapPost("/v1/mls/key-packages", async (
            HttpContext http, AppDbContext db, PublishKeyPackagesRequest req, CancellationToken ct) =>
        {
            var device = http.GetDevice();
            var unclaimed = await db.MlsKeyPackages
                .CountAsync(k => k.DeviceId == device.Id && k.ClaimedAt == null, ct);
            foreach (var kp in req.KeyPackages.Take(Math.Max(0, MaxUnclaimed - unclaimed)))
            {
                db.MlsKeyPackages.Add(new MlsKeyPackage
                {
                    Id = Guid.NewGuid(),
                    FamilyId = device.FamilyId,
                    DeviceId = device.Id,
                    KeyPackage = Convert.FromBase64String(kp)
                });
            }
            await db.SaveChangesAsync(ct);
            return Results.Ok(new
            {
                unclaimed = await db.MlsKeyPackages
                    .CountAsync(k => k.DeviceId == device.Id && k.ClaimedAt == null, ct)
            });
        });

        app.MapGet("/v1/mls/key-packages/count", async (
            HttpContext http, AppDbContext db, CancellationToken ct) =>
        {
            var device = http.GetDevice();
            return Results.Ok(new
            {
                unclaimed = await db.MlsKeyPackages
                    .CountAsync(k => k.DeviceId == device.Id && k.ClaimedAt == null, ct)
            });
        });

        // One key package per device, each handed out once.
        app.MapPost("/v1/mls/key-packages/claim", async (
            HttpContext http, AppDbContext db, ClaimKeyPackagesRequest req, CancellationToken ct) =>
        {
            var device = http.GetDevice();
            var claimed = new List<object>();
            foreach (var deviceId in req.DeviceIds.Distinct())
            {
                var kp = await db.MlsKeyPackages
                    .Where(k => k.DeviceId == deviceId && k.FamilyId == device.FamilyId && k.ClaimedAt == null)
                    .OrderBy(k => k.CreatedAt)
                    .FirstOrDefaultAsync(ct);
                if (kp is null) continue;
                var target = await db.Devices.FindAsync([deviceId], ct);
                if (target?.RevokedAt is not null) continue;
                kp.ClaimedAt = DateTimeOffset.UtcNow;
                claimed.Add(new { deviceId, keyPackage = Convert.ToBase64String(kp.KeyPackage) });
            }
            await db.SaveChangesAsync(ct);
            return Results.Ok(claimed);
        });

        // One commit per epoch: the first to arrive wins, the rest get the epoch
        // to catch up to. The first commit at epoch 0 creates the group.
        app.MapPost("/v1/mls/groups/{groupId}/commit", async (
            HttpContext http, AppDbContext db, string groupId, MlsCommitRequest req, CancellationToken ct) =>
        {
            var device = http.GetDevice();
            if (!IsGroupId(groupId)) return Results.BadRequest(new { error = "bad_group_id" });

            await using var tx = await db.Database.BeginTransactionAsync(ct);
            var group = await db.MlsGroups
                .FromSqlRaw("""SELECT * FROM "MlsGroups" WHERE "GroupId" = {0} FOR UPDATE""", groupId)
                .FirstOrDefaultAsync(ct);
            if (group is null)
            {
                if (req.Epoch != 0) return Results.Conflict(new { epoch = 0L });
                group = new MlsGroupState { GroupId = groupId, FamilyId = device.FamilyId, Epoch = 0 };
                db.MlsGroups.Add(group);
            }
            else if (group.FamilyId != device.FamilyId)
            {
                return Results.NotFound();
            }
            else if (req.Epoch == 0 && group.Epoch != 0 && await IsAbandoned(db, groupId, ct))
            {
                // Total loss (crypto doc §7.3): every device ever in the thread
                // is removed, so nobody is left to welcome anyone. The thread
                // starts over; what was relayed for it is unreadable to all.
                await db.MlsMessages.Where(m => m.GroupId == groupId).ExecuteDeleteAsync(ct);
                group.Epoch = 0;
            }
            else if (group.Epoch != req.Epoch)
            {
                return Results.Conflict(new { epoch = group.Epoch });
            }

            db.MlsMessages.Add(new MlsMessage
            {
                FamilyId = device.FamilyId,
                GroupId = groupId,
                Epoch = req.Epoch,
                Kind = "commit",
                SenderDeviceId = device.Id,
                Body = Convert.FromBase64String(req.Commit)
            });
            if (req.Welcome is not null)
            {
                var recipients = await db.Devices
                    .Where(d => d.FamilyId == device.FamilyId && d.RevokedAt == null
                                && (req.WelcomeTo ?? new()).Contains(d.Id))
                    .Select(d => d.Id)
                    .ToListAsync(ct);
                foreach (var to in recipients)
                {
                    db.MlsMessages.Add(new MlsMessage
                    {
                        FamilyId = device.FamilyId,
                        GroupId = groupId,
                        Epoch = req.Epoch + 1,
                        Kind = "welcome",
                        SenderDeviceId = device.Id,
                        RecipientDeviceId = to,
                        Body = Convert.FromBase64String(req.Welcome)
                    });
                }
            }
            group.Epoch = req.Epoch + 1;
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            await Wake(db, device, ct);
            return Results.Ok(new { epoch = group.Epoch });
        });

        app.MapPost("/v1/mls/groups/{groupId}/messages", async (
            HttpContext http, AppDbContext db, string groupId, MlsApplicationRequest req, CancellationToken ct) =>
        {
            var device = http.GetDevice();
            var group = await db.MlsGroups.FirstOrDefaultAsync(g => g.GroupId == groupId, ct);
            if (group is null || group.FamilyId != device.FamilyId) return Results.NotFound();
            // Sent before the sender saw the latest commit: whoever that
            // added couldn't read it. The sender catches up and sends again.
            if (group.Epoch != req.Epoch) return Results.Conflict(new { epoch = group.Epoch });
            if (req.Slot is { Length: 0 or > 32 }) return Results.BadRequest(new { error = "bad_slot" });
            if (req.Slot is not null)
            {
                // Latest only: what it replaces is gone, not kept unread.
                await db.MlsMessages
                    .Where(m => m.GroupId == groupId && m.SenderDeviceId == device.Id
                                && m.Kind == "application" && m.Slot == req.Slot)
                    .ExecuteDeleteAsync(ct);
            }
            var message = new MlsMessage
            {
                FamilyId = device.FamilyId,
                GroupId = groupId,
                Epoch = req.Epoch,
                Kind = "application",
                SenderDeviceId = device.Id,
                Slot = req.Slot,
                Body = Convert.FromBase64String(req.Message)
            };
            db.MlsMessages.Add(message);
            await db.SaveChangesAsync(ct);
            // A position is fetched when someone looks, not pushed to every phone.
            if (req.Slot is null) await Wake(db, device, ct);
            return Results.Ok(new { seq = message.Seq });
        });

        // Everything for the caller's family since the cursor, welcomes only for
        // the device they're addressed to.
        app.MapGet("/v1/mls/messages", async (
            HttpContext http, AppDbContext db, long? since, CancellationToken ct) =>
        {
            var device = http.GetDevice();
            var from = since ?? 0;
            var messages = await db.MlsMessages
                .AsNoTracking()
                .Where(m => m.FamilyId == device.FamilyId && m.Seq > from
                            && (m.Kind != "welcome" || m.RecipientDeviceId == device.Id))
                .OrderBy(m => m.Seq)
                .Take(200)
                .Select(m => new
                {
                    m.Seq, m.GroupId, m.Epoch, m.Kind,
                    Sender = m.SenderDeviceId,
                    Body = Convert.ToBase64String(m.Body)
                })
                .ToListAsync(ct);
            return Results.Ok(new
            {
                messages,
                cursor = messages.Count == 0 ? from : messages[^1].Seq,
                hasMore = messages.Count == 200
            });
        });
    }

    private static bool IsGroupId(string id) =>
        id.Length is > 0 and <= 256 && id.All(Uri.IsHexDigit);

    /// <summary>Every other device in the family hears there's something new, at once.</summary>
    private static async Task Wake(AppDbContext db, Device author, CancellationToken ct)
    {
        var others = await db.Devices
            .Where(d => d.FamilyId == author.FamilyId && d.Id != author.Id
                        && d.RevokedAt == null && d.PushToken != null)
            .Select(d => d.Id)
            .ToListAsync(ct);
        var pending = await db.ScheduledWakes
            .Where(w => others.Contains(w.DeviceId) && w.CorrelationRef == ChatWakeRef && w.State == "scheduled")
            .Select(w => w.DeviceId)
            .ToListAsync(ct);
        foreach (var id in others.Except(pending))
        {
            db.ScheduledWakes.Add(new ScheduledWake
            {
                Id = Guid.NewGuid(),
                FamilyId = author.FamilyId,
                DeviceId = id,
                CorrelationRef = ChatWakeRef,
                FireAt = DateTimeOffset.UtcNow
            });
        }
        await db.SaveChangesAsync(ct);
    }
}
