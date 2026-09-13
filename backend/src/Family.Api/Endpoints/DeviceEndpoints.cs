using Family.Api.Contracts;
using Family.Api.Data;
using Family.Api.Domain;
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
        });

        app.MapPost("/v1/devices", async (AppDbContext db, RegisterDeviceRequest req, CancellationToken ct) =>
        {
            var member = await db.Members
                .FirstOrDefaultAsync(m => m.Id == req.MemberId && m.FamilyId == req.FamilyId, ct);

            if (member is null) return Results.NotFound();

            // Registering a public key is not the same as being trusted. The device
            // becomes useful only once an existing device wraps group keys to it,
            // after the out-of-band short-authentication-string check.
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
            await db.SaveChangesAsync(ct);

            return Results.Ok(new RegisterDeviceResponse(device.Id));
        });

        // Key directory. Devices fetch each other's public keys to wrap group keys.
        app.MapGet("/v1/families/{familyId:guid}/devices", async (
            AppDbContext db, Guid familyId, CancellationToken ct) =>
        {
            var devices = await db.Devices
                .AsNoTracking()
                .Where(d => d.FamilyId == familyId)
                .Select(d => new DeviceKeyDto(
                    d.Id, d.MemberId, d.SigningPublicKey, d.KemPublicKey, d.RevokedAt != null))
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

        app.MapPut("/v1/devices/push-token", async (
            HttpContext http, AppDbContext db, PushTokenRequest req, CancellationToken ct) =>
        {
            var device = http.GetDevice();
            device.PushToken = req.Token;
            await db.SaveChangesAsync(ct);
            return Results.NoContent();
        });
    }
}
