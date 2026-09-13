using Family.Api.Contracts;
using Family.Api.Data;
using Microsoft.EntityFrameworkCore;

namespace Family.Api.Endpoints;

public static class SyncEndpoints
{
    private const int PageSize = 500;

    public static void MapSync(this IEndpointRouteBuilder app)
    {
        app.MapGet("/v1/sync", async (
            HttpContext http,
            AppDbContext db,
            long? since,
            CancellationToken ct) =>
        {
            var device = http.GetDevice();
            var cursor = since ?? 0;

            // Scopes this device may receive. Deliberately coarse: the fine-grained
            // "may this member read this object" question is answered by whether the
            // device holds a key that unwraps it, not by a server-side filter.
            var scopes = await ScopesForDevice(db, device.FamilyId, device.MemberId, ct);

            var rows = await db.SyncObjects
                .AsNoTracking()
                .Where(o => o.FamilyId == device.FamilyId
                            && o.Sequence > cursor
                            && scopes.Contains(o.Scope))
                .OrderBy(o => o.Sequence)
                .Take(PageSize + 1)
                .ToListAsync(ct);

            var hasMore = rows.Count > PageSize;
            if (hasMore) rows.RemoveAt(rows.Count - 1);

            var changes = rows.Select(o => new SyncObjectDto(
                o.Id,
                o.Kind,
                o.Scope,
                o.Deleted ? null : o.Envelope,
                o.Version,
                o.Deleted,
                o.UpdatedAt)).ToList();

            var next = rows.Count > 0 ? rows[^1].Sequence : cursor;

            device.LastSeenAt = DateTimeOffset.UtcNow;
            await db.SaveChangesAsync(ct);

            return Results.Ok(new SyncResponse(changes, next, hasMore));
        });
    }

    internal static async Task<List<string>> ScopesForDevice(
        AppDbContext db, Guid familyId, Guid memberId, CancellationToken ct)
    {
        var scopes = new List<string>
        {
            $"family:{familyId}",
            $"member:{memberId}"
        };

        // Children in a custody arrangement have a scope delivered to both households.
        // Modelled here as a placeholder until the custody feature lands; the shape is
        // what matters, so that adding it later is data rather than schema.
        var childScopes = await db.SyncObjects
            .AsNoTracking()
            .Where(o => o.FamilyId == familyId && o.Scope.StartsWith("child:"))
            .Select(o => o.Scope)
            .Distinct()
            .ToListAsync(ct);

        scopes.AddRange(childScopes);
        return scopes;
    }
}
