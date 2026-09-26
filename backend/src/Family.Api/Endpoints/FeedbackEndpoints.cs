using System.Security.Cryptography;
using System.Text;
using Family.Api.Data;
using Family.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Family.Api.Endpoints;

/// <summary>
/// Feedback to the developers: bug reports and ideas, posted from the app,
/// seen by everyone who uses it, and voted up or down. Unlike everything
/// the family writes to each other, this is readable here: it is written
/// to us.
/// </summary>
public static class FeedbackEndpoints
{
    public const int MaxTitle = 120;
    public const int MaxBody = 4000;

    /// <summary>Posts one member may make a day: feedback, not a chat.</summary>
    public const int PerDay = 10;

    public record NewFeedback(
        string Kind,
        string Title,
        string Body,
        bool Anonymous,
        string? AuthorName,
        string? AppVersion,
        string? Platform);

    public record Vote(int Value);

    /// <summary>
    /// A one-way fingerprint of a member: the same every time, so they can
    /// vote once and remove their own post, and not their id.
    /// </summary>
    public static string KeyOf(Guid memberId) => Convert.ToHexString(
        SHA256.HashData(Encoding.UTF8.GetBytes($"feedback:{memberId}"))).ToLowerInvariant();

    public static void MapFeedback(this IEndpointRouteBuilder app)
    {
        app.MapGet("/v1/feedback", async (HttpContext http, AppDbContext db, CancellationToken ct) =>
        {
            var me = KeyOf(http.GetDevice().MemberId);
            var items = await db.Feedback.AsNoTracking().ToListAsync(ct);
            var votes = await db.FeedbackVotes.AsNoTracking().ToListAsync(ct);
            var byItem = votes.GroupBy(v => v.FeedbackId).ToDictionary(g => g.Key, g => g.ToList());
            var list = items
                .Select(i =>
                {
                    var mine = byItem.GetValueOrDefault(i.Id) ?? [];
                    return new
                    {
                        id = i.Id,
                        kind = i.Kind.ToString().ToLowerInvariant(),
                        title = i.Title,
                        body = i.Body,
                        author = i.AuthorName,
                        appVersion = i.AppVersion,
                        platform = i.Platform,
                        status = i.Status.ToString().ToLowerInvariant(),
                        reply = i.Reply,
                        createdAt = i.CreatedAt,
                        score = mine.Sum(v => v.Value),
                        myVote = mine.FirstOrDefault(v => v.VoterKey == me)?.Value ?? 0,
                        mine = i.AuthorKey == me,
                    };
                })
                .OrderByDescending(i => i.score)
                .ThenByDescending(i => i.createdAt)
                .ToList();
            return Results.Ok(list);
        });

        app.MapPost("/v1/feedback", async (
            NewFeedback req, HttpContext http, AppDbContext db, CancellationToken ct) =>
        {
            var device = http.GetDevice();
            var title = req.Title.Trim();
            var body = req.Body.Trim();
            if (title.Length == 0 || title.Length > MaxTitle || body.Length > MaxBody)
                return Results.BadRequest(new { error = "length" });
            if (!Enum.TryParse<FeedbackKind>(req.Kind, ignoreCase: true, out var kind))
                return Results.BadRequest(new { error = "kind" });

            var key = KeyOf(device.MemberId);
            var since = DateTimeOffset.UtcNow.AddDays(-1);
            if (await db.Feedback.CountAsync(f => f.AuthorKey == key && f.CreatedAt > since, ct) >= PerDay)
                return Results.StatusCode(StatusCodes.Status429TooManyRequests);

            var name = req.Anonymous ? null : req.AuthorName?.Trim();
            var item = new FeedbackItem
            {
                Id = Guid.NewGuid(),
                Kind = kind,
                Title = title,
                Body = body,
                AuthorName = string.IsNullOrEmpty(name) ? null : name[..Math.Min(name.Length, 60)],
                AuthorKey = key,
                AppVersion = req.AppVersion?[..Math.Min(req.AppVersion.Length, 40)],
                Platform = req.Platform?[..Math.Min(req.Platform.Length, 40)],
            };
            db.Feedback.Add(item);
            await db.SaveChangesAsync(ct);
            return Results.Ok(new { id = item.Id });
        });

        // Up, down, or neither (0 takes a vote back). One vote a member.
        app.MapPost("/v1/feedback/{id:guid}/vote", async (
            Guid id, Vote req, HttpContext http, AppDbContext db, CancellationToken ct) =>
        {
            if (req.Value is < -1 or > 1) return Results.BadRequest(new { error = "value" });
            if (!await db.Feedback.AnyAsync(f => f.Id == id, ct)) return Results.NotFound();
            var key = KeyOf(http.GetDevice().MemberId);
            var vote = await db.FeedbackVotes.FirstOrDefaultAsync(
                v => v.FeedbackId == id && v.VoterKey == key, ct);
            if (req.Value == 0)
            {
                if (vote is not null) db.FeedbackVotes.Remove(vote);
            }
            else if (vote is null)
            {
                db.FeedbackVotes.Add(new FeedbackVote { FeedbackId = id, VoterKey = key, Value = req.Value });
            }
            else
            {
                vote.Value = req.Value;
                vote.At = DateTimeOffset.UtcNow;
            }
            await db.SaveChangesAsync(ct);
            return Results.NoContent();
        });

        // Only whoever posted it may take it down.
        app.MapDelete("/v1/feedback/{id:guid}", async (
            Guid id, HttpContext http, AppDbContext db, CancellationToken ct) =>
        {
            var key = KeyOf(http.GetDevice().MemberId);
            var item = await db.Feedback.FirstOrDefaultAsync(f => f.Id == id, ct);
            if (item is null) return Results.NotFound();
            if (item.AuthorKey != key) return Results.Forbid();
            db.Feedback.Remove(item);
            db.FeedbackVotes.RemoveRange(db.FeedbackVotes.Where(v => v.FeedbackId == id));
            await db.SaveChangesAsync(ct);
            return Results.NoContent();
        });
    }
}
