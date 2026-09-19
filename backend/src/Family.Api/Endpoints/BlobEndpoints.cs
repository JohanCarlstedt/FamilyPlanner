using Family.Api.Data;
using Family.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Family.Api.Endpoints;

/// <summary>
/// Encrypted blobs: photos and files, downscaled, stripped of their metadata
/// and sealed on the phone. The server keeps bytes it can't read, for the
/// family that sent them, within a size limit per blob and a cap per family.
/// </summary>
public static class BlobEndpoints
{
    /// <summary>A downscaled photo is a few hundred kilobytes; this is room to spare.</summary>
    public const int MaxBlobBytes = 4 * 1024 * 1024;

    /// <summary>Spec §3 "Quota and retention": the one thing that grows without bound.</summary>
    public const long FamilyQuotaBytes = 2L * 1024 * 1024 * 1024;

    public static void MapBlobs(this IEndpointRouteBuilder app)
    {
        // Idempotent on the id the phone chose: a retried upload changes nothing.
        app.MapPut("/v1/blobs/{id:guid}", async (
            HttpContext http, AppDbContext db, Guid id, CancellationToken ct) =>
        {
            var device = http.GetDevice();
            using var buffer = new MemoryStream();
            await http.Request.Body.CopyToAsync(buffer, ct);
            var bytes = buffer.ToArray();
            if (bytes.Length == 0) return Results.BadRequest(new { error = "empty" });
            if (bytes.Length > MaxBlobBytes) return Results.StatusCode(413);

            var existing = await db.Blobs.AsNoTracking()
                .Where(b => b.Id == id)
                .Select(b => new { b.FamilyId })
                .FirstOrDefaultAsync(ct);
            if (existing is not null)
            {
                return existing.FamilyId == device.FamilyId ? Results.NoContent() : Results.Conflict();
            }
            var used = await db.Blobs.Where(b => b.FamilyId == device.FamilyId)
                .SumAsync(b => (long)b.Size, ct);
            if (used + bytes.Length > FamilyQuotaBytes)
            {
                return Results.Json(new { error = "quota", used, quota = FamilyQuotaBytes }, statusCode: 507);
            }
            db.Blobs.Add(new Blob
            {
                Id = id,
                FamilyId = device.FamilyId,
                UploadedByDeviceId = device.Id,
                Size = bytes.Length,
                Bytes = bytes
            });
            await db.SaveChangesAsync(ct);
            return Results.NoContent();
        });

        app.MapGet("/v1/blobs/{id:guid}", async (
            HttpContext http, AppDbContext db, Guid id, CancellationToken ct) =>
        {
            var device = http.GetDevice();
            var blob = await db.Blobs.AsNoTracking()
                .FirstOrDefaultAsync(b => b.Id == id && b.FamilyId == device.FamilyId, ct);
            return blob is null
                ? Results.NotFound()
                : Results.Bytes(blob.Bytes, "application/octet-stream");
        });

        app.MapDelete("/v1/blobs/{id:guid}", async (
            HttpContext http, AppDbContext db, Guid id, CancellationToken ct) =>
        {
            var device = http.GetDevice();
            var deleted = await db.Blobs
                .Where(b => b.Id == id && b.FamilyId == device.FamilyId)
                .ExecuteDeleteAsync(ct);
            return deleted == 0 ? Results.NotFound() : Results.NoContent();
        });

        // What the family uses of its cap, to show in the app.
        app.MapGet("/v1/blobs/usage", async (HttpContext http, AppDbContext db, CancellationToken ct) =>
        {
            var device = http.GetDevice();
            var used = await db.Blobs.Where(b => b.FamilyId == device.FamilyId)
                .SumAsync(b => (long)b.Size, ct);
            return Results.Ok(new { used, quota = FamilyQuotaBytes });
        });
    }
}
