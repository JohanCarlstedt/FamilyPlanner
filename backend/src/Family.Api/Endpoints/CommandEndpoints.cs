using Family.Api.Contracts;
using Family.Api.Data;
using Family.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Family.Api.Endpoints;

public static class CommandEndpoints
{
    /// <summary>
    /// The offline-capable allowlist from the architecture document. Keep it small
    /// and explicit: anything not listed here requires connectivity, and the client
    /// disables the control with a visible reason rather than failing later.
    /// </summary>
    private static readonly HashSet<string> Allowed = new(StringComparer.Ordinal)
    {
        "object.upsert",              // generic create/update of an encrypted object
        "object.delete",
        "shopping_item.tick",
        "equipment.check",
        "action.complete",
        "homework.complete",
        "event.rsvp"
    };

    public static void MapCommands(this IEndpointRouteBuilder app)
    {
        app.MapPost("/v1/commands", async (
            HttpContext http,
            AppDbContext db,
            SubmitCommandsRequest req,
            CancellationToken ct) =>
        {
            var device = http.GetDevice();
            var results = new List<CommandResultDto>();

            foreach (var cmd in req.Commands.OrderBy(c => c.IssuedAt))
            {
                if (!Allowed.Contains(cmd.Type))
                {
                    results.Add(new(cmd.ClientCommandId, "rejected", null, "unknown_command_type"));
                    continue;
                }

                // Idempotency. A replayed command returns its original outcome rather
                // than applying twice — this is what makes offline retry safe.
                var existing = await db.Commands
                    .AsNoTracking()
                    .FirstOrDefaultAsync(c => c.DeviceId == device.Id
                                              && c.ClientCommandId == cmd.ClientCommandId, ct);

                if (existing is not null)
                {
                    results.Add(new(cmd.ClientCommandId, "duplicate", existing.ResultingSequence, null));
                    continue;
                }

                await using var tx = await db.Database.BeginTransactionAsync(ct);
                try
                {
                    var obj = await db.SyncObjects
                        .FirstOrDefaultAsync(o => o.Id == cmd.TargetObjectId
                                                  && o.FamilyId == device.FamilyId, ct);

                    if (obj is null)
                    {
                        obj = new SyncObject
                        {
                            Id = cmd.TargetObjectId,
                            FamilyId = device.FamilyId,
                            Kind = cmd.TargetKind,
                            Scope = cmd.Scope,
                            Version = 0
                        };
                        db.SyncObjects.Add(obj);
                    }
                    else if (cmd.ExpectedVersion is { } expected && obj.Version != expected)
                    {
                        // Stale write. The client re-reads and decides; the server never
                        // merges, because it cannot read either version.
                        results.Add(new(cmd.ClientCommandId, "conflict", obj.Version, "version_mismatch"));
                        await tx.RollbackAsync(ct);
                        continue;
                    }

                    if (cmd.Type == "object.delete")
                    {
                        obj.Deleted = true;
                        obj.Envelope = Array.Empty<byte>();
                        obj.DeletedByDeviceId = device.Id;
                    }
                    else
                    {
                        obj.Envelope = cmd.Envelope;
                        obj.Deleted = false;
                    }

                    obj.Version += 1;
                    obj.UpdatedAt = DateTimeOffset.UtcNow;
                    obj.UpdatedByDeviceId = device.Id;

                    // A new sequence on every write is what moves it past other devices' cursors.
                    obj.Sequence = await NextSequence(db, ct);

                    db.Commands.Add(new CommandRecord
                    {
                        Id = Guid.NewGuid(),
                        FamilyId = device.FamilyId,
                        DeviceId = device.Id,
                        ClientCommandId = cmd.ClientCommandId,
                        Type = cmd.Type,
                        Envelope = cmd.Envelope,
                        TargetObjectId = cmd.TargetObjectId,
                        IssuedAt = cmd.IssuedAt,
                        ResultingSequence = obj.Sequence
                    });

                    await db.SaveChangesAsync(ct);
                    await tx.CommitAsync(ct);

                    results.Add(new(cmd.ClientCommandId, "applied", obj.Sequence, null));
                }
                catch (DbUpdateException)
                {
                    await tx.RollbackAsync(ct);
                    // Almost always the unique index on (DeviceId, ClientCommandId) firing
                    // because the same command arrived twice concurrently. Treat as duplicate.
                    results.Add(new(cmd.ClientCommandId, "duplicate", null, null));
                }
            }

            var cursor = await db.SyncObjects
                .Where(o => o.FamilyId == device.FamilyId)
                .MaxAsync(o => (long?)o.Sequence, ct) ?? 0;

            return Results.Ok(new SubmitCommandsResponse(results, cursor));
        });
    }

    private static async Task<long> NextSequence(AppDbContext db, CancellationToken ct)
    {
        await using var conn = db.Database.GetDbConnection().CreateCommand();
        conn.CommandText = "SELECT nextval('sync_sequence')";
        if (conn.Connection!.State != System.Data.ConnectionState.Open)
            await db.Database.OpenConnectionAsync(ct);
        var result = await conn.ExecuteScalarAsync(ct);
        return Convert.ToInt64(result);
    }

    private static async Task<object?> ExecuteScalarAsync(
        this System.Data.Common.DbCommand cmd, CancellationToken ct)
        => await cmd.ExecuteScalarAsync(ct);
}
