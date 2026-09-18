using Family.Api.Contracts;
using Family.Api.Data;
using Family.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Family.Api.Endpoints;

/// <summary>
/// Relays for QR pairing (crypto doc §7.1). Admissions and endorsements are
/// authenticated end to end by the devices; the server only routes them within
/// a family and can neither read nor forge them.
/// </summary>
public static class PairingEndpoints
{
    /// <summary>An unacknowledged admission outlives any pairing screen by far.</summary>
    public static readonly TimeSpan AdmissionLifetime = TimeSpan.FromHours(24);

    /// <summary>Both formats are a few hundred bytes; this only stops abuse.</summary>
    private const int MaxBlobBytes = 16 * 1024;

    public static void MapPairing(this IEndpointRouteBuilder app)
    {
        app.MapPost("/v1/pairing/admissions", async (
            HttpContext http, AppDbContext db, SendAdmissionRequest req, CancellationToken ct) =>
        {
            var sender = http.GetDevice();
            if (req.Admission.Length is 0 or > MaxBlobBytes)
                return Results.BadRequest(new { error = "admission_size" });

            if (!await IsActiveFamilyDevice(db, sender.FamilyId, req.ToDeviceId, ct)
                || req.ToDeviceId == sender.Id)
                return Results.BadRequest(new { error = "device_not_in_family" });

            var admission = new PairingAdmission
            {
                Id = Guid.NewGuid(),
                FamilyId = sender.FamilyId,
                ToDeviceId = req.ToDeviceId,
                FromDeviceId = sender.Id,
                Admission = req.Admission
            };
            db.PairingAdmissions.Add(admission);
            await db.SaveChangesAsync(ct);
            return Results.Ok(new SendAdmissionResponse(admission.Id));
        });

        // The new device polls while its pairing screen is open.
        app.MapGet("/v1/pairing/admissions", async (
            HttpContext http, AppDbContext db, CancellationToken ct) =>
        {
            var device = http.GetDevice();
            var cutoff = DateTimeOffset.UtcNow - AdmissionLifetime;

            await db.PairingAdmissions
                .Where(a => a.ToDeviceId == device.Id && a.CreatedAt < cutoff)
                .ExecuteDeleteAsync(ct);

            var pending = await db.PairingAdmissions
                .AsNoTracking()
                .Where(a => a.ToDeviceId == device.Id)
                .OrderBy(a => a.CreatedAt)
                .Select(a => new AdmissionDto(a.Id, a.FromDeviceId, a.Admission, a.CreatedAt))
                .ToListAsync(ct);
            return Results.Ok(pending);
        });

        // Acknowledged separately from the fetch, so a lost response loses nothing.
        app.MapDelete("/v1/pairing/admissions/{admissionId:guid}", async (
            HttpContext http, AppDbContext db, Guid admissionId, CancellationToken ct) =>
        {
            var device = http.GetDevice();
            var deleted = await db.PairingAdmissions
                .Where(a => a.Id == admissionId && a.ToDeviceId == device.Id)
                .ExecuteDeleteAsync(ct);
            return deleted == 0 ? Results.NotFound() : Results.NoContent();
        });

        app.MapPost("/v1/pairing/endorsements", async (
            HttpContext http, AppDbContext db, PublishEndorsementRequest req, CancellationToken ct) =>
        {
            var endorser = http.GetDevice();
            if (req.Endorsement.Length is 0 or > MaxBlobBytes)
                return Results.BadRequest(new { error = "endorsement_size" });

            if (!await IsActiveFamilyDevice(db, endorser.FamilyId, req.SubjectDeviceId, ct)
                || req.SubjectDeviceId == endorser.Id)
                return Results.BadRequest(new { error = "device_not_in_family" });

            var existing = await db.DeviceEndorsements.FirstOrDefaultAsync(
                e => e.SubjectDeviceId == req.SubjectDeviceId && e.EndorserDeviceId == endorser.Id, ct);
            if (existing is null)
            {
                db.DeviceEndorsements.Add(new DeviceEndorsement
                {
                    Id = Guid.NewGuid(),
                    FamilyId = endorser.FamilyId,
                    SubjectDeviceId = req.SubjectDeviceId,
                    EndorserDeviceId = endorser.Id,
                    Endorsement = req.Endorsement
                });
            }
            else
            {
                existing.Endorsement = req.Endorsement;
                existing.CreatedAt = DateTimeOffset.UtcNow;
            }

            await db.SaveChangesAsync(ct);
            return Results.NoContent();
        });

        app.MapGet("/v1/pairing/endorsements", async (
            HttpContext http, AppDbContext db, CancellationToken ct) =>
        {
            var device = http.GetDevice();
            var endorsements = await db.DeviceEndorsements
                .AsNoTracking()
                .Where(e => e.FamilyId == device.FamilyId)
                .OrderBy(e => e.CreatedAt)
                .Select(e => new EndorsementDto(
                    e.SubjectDeviceId, e.EndorserDeviceId, e.Endorsement, e.CreatedAt))
                .ToListAsync(ct);
            return Results.Ok(endorsements);
        });
    }

    private static Task<bool> IsActiveFamilyDevice(
        AppDbContext db, Guid familyId, Guid deviceId, CancellationToken ct)
        => db.Devices.AnyAsync(d => d.Id == deviceId && d.FamilyId == familyId && d.RevokedAt == null, ct);
}
