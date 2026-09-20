using Family.Api.Auth;
using Family.Api.Contracts;
using Family.Api.Data;
using Family.Api.Domain;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

namespace Family.Api.Endpoints;

public static class DeviceEndpoints
{
    public static void MapDevices(this IEndpointRouteBuilder app)
    {
        // Family creation. The founder device brings its own keys; the server never
        // generates key material for anyone.
        app.MapPost("/v1/families", async (AppDbContext db, CreateFamilyRequest req, CancellationToken ct) =>
        {
            // The only write anyone can reach without a key, so it is also
            // the only one a stranger will send nonsense to. Without this a
            // missing field became a constraint violation deep in EF and came
            // back as 500 — an error that says "the server is broken" when it
            // means "that request was".
            if (string.IsNullOrWhiteSpace(req.Name)
                || string.IsNullOrWhiteSpace(req.TimeZone)
                || string.IsNullOrWhiteSpace(req.SigningPublicKey)
                || string.IsNullOrWhiteSpace(req.KemPublicKey)
                || string.IsNullOrWhiteSpace(req.Platform)
                || req.FounderProfileEnvelope is null or { Length: 0 })
            {
                return Results.BadRequest(new { error = "incomplete" });
            }

            // Sizes a real founder stays well inside. A public endpoint that
            // accepts a megabyte of name is a disk filling up.
            if (req.Name.Length > 200
                || req.TimeZone.Length > 64
                || req.SigningPublicKey.Length > 256
                || req.KemPublicKey.Length > 256
                || req.Platform.Length > 40
                || req.FounderProfileEnvelope.Length > 64 * 1024)
            {
                return Results.BadRequest(new { error = "too_large" });
            }

            var family = new FamilyGroup
            {
                Id = Guid.NewGuid(),
                Name = req.Name,
                TimeZone = req.TimeZone
            };

            var member = new Member
            {
                Id = Guid.NewGuid(),
                FamilyId = family.Id,
                Role = MemberRole.Parent,
                ProfileEnvelope = req.FounderProfileEnvelope
            };

            var device = new Device
            {
                Id = Guid.NewGuid(),
                MemberId = member.Id,
                FamilyId = family.Id,
                SigningPublicKey = req.SigningPublicKey,
                KemPublicKey = req.KemPublicKey,
                Platform = req.Platform
            };

            db.Families.Add(family);
            db.Members.Add(member);
            db.Devices.Add(device);
            await db.SaveChangesAsync(ct);

            return Results.Ok(new CreateFamilyResponse(family.Id, member.Id, device.Id));
        })
        // Anonymous by necessity — there is no device yet to sign with. A
        // family is a handful of rows and a quota; a few an hour per address
        // is more than anyone starting one needs.
        .RequireRateLimiting(RateLimiting.CreateFamily);

        // A parent adds a member row: a child, or a placeholder the second parent's
        // device later claims (spec §9). The profile may be empty: it is an envelope
        // bound to the member's id, so it can only be sealed once that id exists,
        // and arrives through sync like any other content.
        app.MapPost("/v1/members", async (
            HttpContext http, AppDbContext db, CreateMemberRequest req, CancellationToken ct) =>
        {
            var caller = http.GetDevice();
            if (!await IsParentDevice(db, caller, ct)) return Results.StatusCode(StatusCodes.Status403Forbidden);

            var member = new Member
            {
                Id = Guid.NewGuid(),
                FamilyId = caller.FamilyId,
                Role = req.Role,
                ProfileEnvelope = req.ProfileEnvelope
            };
            db.Members.Add(member);
            await db.SaveChangesAsync(ct);
            return Results.Ok(new CreateMemberResponse(member.Id));
        });

        // A parent's device registers a new device after scanning its pairing code
        // (crypto doc §7.1), with the keys read off the new device's screen. A new
        // device can't register itself: it doesn't know its family yet, and letting
        // anyone who knows a family id add devices to it was a hole.
        app.MapPost("/v1/devices", async (
            HttpContext http, AppDbContext db, RegisterDeviceRequest req, CancellationToken ct) =>
        {
            var caller = http.GetDevice();
            if (!await IsParentDevice(db, caller, ct)) return Results.StatusCode(StatusCodes.Status403Forbidden);

            var member = await db.Members.FirstOrDefaultAsync(
                m => m.Id == req.MemberId && m.FamilyId == caller.FamilyId && m.EndedAt == null, ct);
            if (member is null) return Results.NotFound();

            // Registering a public key is not the same as being trusted. The device
            // becomes useful only once the admitting device grants it group keys.
            var device = new Device
            {
                Id = Guid.NewGuid(),
                MemberId = member.Id,
                FamilyId = member.FamilyId,
                SigningPublicKey = req.SigningPublicKey,
                KemPublicKey = req.KemPublicKey,
                Platform = req.Platform
            };

            db.Devices.Add(device);
            try
            {
                await db.SaveChangesAsync(ct);
            }
            catch (DbUpdateException)
            {
                // The signing key is unique: this device is already registered.
                return Results.Conflict(new { error = "device_already_registered" });
            }

            return Results.Ok(new RegisterDeviceResponse(device.Id));
        });

        // Key directory. Devices fetch each other's public keys to wrap group keys.
        app.MapGet("/v1/families/{familyId:guid}/devices", async (
            HttpContext http, AppDbContext db, Guid familyId, CancellationToken ct) =>
        {
            // Only your own family's directory. Not found rather than forbidden,
            // so the response doesn't confirm another family exists.
            if (http.GetDevice().FamilyId != familyId) return Results.NotFound();

            var devices = await db.Devices
                .AsNoTracking()
                .Where(d => d.FamilyId == familyId)
                .Select(d => new DeviceKeyDto(
                    d.Id, d.MemberId, d.SigningPublicKey, d.KemPublicKey, d.RevokedAt != null, d.Platform))
                .ToListAsync(ct);

            return Results.Ok(devices);
        });

        // Wrapped group keys in and out. Opaque blobs; the server is a post box.
        app.MapPost("/v1/keys", async (
            HttpContext http, AppDbContext db, PublishWrappedKeysRequest req, CancellationToken ct) =>
        {
            var device = http.GetDevice();

            // Only wrap to devices in the caller's own family. Otherwise a device elsewhere
            // could pre-publish a junk key for someone's next epoch, and the real one would
            // be skipped as "already exists" below.
            var familyDeviceIds = await db.Devices
                .Where(d => d.FamilyId == device.FamilyId)
                .Select(d => d.Id)
                .ToListAsync(ct);

            if (req.Keys.Any(k => !familyDeviceIds.Contains(k.DeviceId)))
                return Results.BadRequest(new { error = "device_not_in_family" });

            foreach (var k in req.Keys)
            {
                var exists = await db.WrappedGroupKeys.AnyAsync(
                    w => w.DeviceId == k.DeviceId
                         && w.GroupName == req.GroupName
                         && w.Epoch == req.Epoch, ct);

                if (exists) continue;

                db.WrappedGroupKeys.Add(new WrappedGroupKey
                {
                    Id = Guid.NewGuid(),
                    FamilyId = device.FamilyId,
                    GroupName = req.GroupName,
                    Epoch = req.Epoch,
                    DeviceId = k.DeviceId,
                    WrappedKey = k.WrappedKey
                });
            }

            await db.SaveChangesAsync(ct);
            return Results.Ok();
        });

        app.MapGet("/v1/keys", async (HttpContext http, AppDbContext db, CancellationToken ct) =>
        {
            var device = http.GetDevice();

            var keys = await db.WrappedGroupKeys
                .AsNoTracking()
                .Where(w => w.DeviceId == device.Id)
                .OrderBy(w => w.GroupName).ThenBy(w => w.Epoch)
                .Select(w => new { w.GroupName, w.Epoch, w.WrappedKey })
                .ToListAsync(ct);

            return Results.Ok(keys);
        });

        // Removing a device (crypto doc §7 "A member leaving", §9): it stops
        // authenticating at once. Its keys stay valid for what it already holds;
        // the removing device rotates the groups it was in, so it reads nothing
        // written from here on.
        app.MapPost("/v1/devices/{deviceId:guid}/revoke", async (
            HttpContext http, AppDbContext db, Guid deviceId, CancellationToken ct) =>
        {
            var caller = http.GetDevice();
            if (!await IsParentDevice(db, caller, ct)) return Results.StatusCode(403);
            if (deviceId == caller.Id) return Results.BadRequest(new { error = "cannot_revoke_self" });

            var target = await db.Devices.FirstOrDefaultAsync(
                d => d.Id == deviceId && d.FamilyId == caller.FamilyId, ct);
            if (target is null) return Results.NotFound();
            if (target.RevokedAt is not null) return Results.NoContent();

            target.RevokedAt = DateTimeOffset.UtcNow;
            target.PushToken = null;
            await db.ScheduledWakes
                .Where(w => w.DeviceId == deviceId && w.State == "scheduled")
                .ExecuteUpdateAsync(u => u.SetProperty(w => w.State, "cancelled"), ct);
            await db.SaveChangesAsync(ct);
            return Results.NoContent();
        });

        app.MapPut("/v1/devices/push-token", async (
            HttpContext http, AppDbContext db, PushTokenRequest req, CancellationToken ct) =>
        {
            var device = http.GetDevice();
            // A token belongs to one app installation. A phone that reset its
            // identity keeps its token, so the old device record must let go
            // of it, or its wakes would still reach the phone.
            await db.Devices
                .Where(d => d.PushToken == req.Token && d.Id != device.Id)
                .ExecuteUpdateAsync(u => u.SetProperty(d => d.PushToken, (string?)null), ct);
            device.PushToken = req.Token;
            await db.SaveChangesAsync(ct);
            return Results.NoContent();
        });
    }

    private static Task<bool> IsParentDevice(AppDbContext db, Device device, CancellationToken ct)
        => db.Members.AnyAsync(
            m => m.Id == device.MemberId && m.Role == MemberRole.Parent && m.EndedAt == null, ct);
}
