using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Family.Api.Data;
using Family.Api.Domain;
using Microsoft.EntityFrameworkCore;

namespace Family.Api.Endpoints;

/// <summary>
/// What a family is entitled to, and how the billing provider says so
/// (docs/going-public.md "Billing, and how it meets end-to-end encryption").
///
/// Two directions, and they are deliberately not the same route. Devices
/// <em>read</em> the entitlement, signed as themselves. Only the provider
/// <em>writes</em> it, on a path no device uses, because a client that could
/// declare itself paid is not a paywall.
/// </summary>
public static class SubscriptionEndpoints
{
    /// <summary>Anonymous: the provider has no device key. Guarded by a shared secret.</summary>
    public const string WebhookPath = "/v1/billing/events";

    public static void MapSubscriptions(this IEndpointRouteBuilder app)
    {
        // What this family may use, and the id to register with the provider.
        app.MapGet("/v1/entitlement", async (
            HttpContext http, AppDbContext db, TimeProvider clock, CancellationToken ct) =>
        {
            var device = http.GetDevice();
            var subscription = await EnsureFor(db, device.FamilyId, ct);
            await db.SaveChangesAsync(ct);

            var now = clock.GetUtcNow();
            return Results.Ok(new
            {
                billingId = subscription.BillingId,
                premium = subscription.IsPremiumAt(now),
                // Null rather than the year 9999 on the wire: a client that
                // renders a date should not have to know about our sentinel.
                premiumUntil = subscription.PremiumUntil == Subscription.Forever
                    ? null
                    : subscription.PremiumUntil,
                source = subscription.Source.ToString(),
                // So a phone that cannot reach us again knows how stale its
                // answer is, rather than guessing from its own clock alone.
                asOf = now
            });
        });

        // The provider's notifications: purchases, renewals, cancellations,
        // refunds, billing retries, and grants made from its dashboard.
        app.MapPost(WebhookPath, async (
            HttpContext http, AppDbContext db, IConfiguration config,
            ILoggerFactory logs, CancellationToken ct) =>
        {
            var log = logs.CreateLogger("Billing");
            var expected = config["Billing:WebhookToken"];
            if (string.IsNullOrWhiteSpace(expected))
            {
                // Not configured is not the same as wrong. A server with no
                // secret set must not be talkable into changing entitlements.
                log.LogWarning("A billing event arrived but Billing:WebhookToken is unset");
                return Results.StatusCode(StatusCodes.Status503ServiceUnavailable);
            }

            var offered = http.Request.Headers.Authorization.ToString();
            if (!FixedTimeEquals(offered, expected)) return Results.Unauthorized();

            using var body = await JsonDocument.ParseAsync(http.Request.Body, cancellationToken: ct);
            if (!body.RootElement.TryGetProperty("event", out var e))
                return Results.BadRequest(new { error = "no_event" });

            if (!e.TryGetProperty("app_user_id", out var user) ||
                !Guid.TryParse(user.GetString(), out var billingId))
                return Results.BadRequest(new { error = "no_app_user_id" });

            var subscription = await db.Subscriptions
                .FirstOrDefaultAsync(s => s.BillingId == billingId, ct);
            if (subscription is null)
            {
                // A purchase for a family that is not here: a test event, or a
                // family deleted between paying and the notification arriving.
                // Accepted so the provider stops retrying, and logged so it is
                // noticed if it becomes a pattern.
                log.LogWarning("Billing event for unknown billing id {BillingId}", billingId);
                return Results.Ok(new { status = "unknown" });
            }

            var outcome = Apply(subscription, e);
            await db.SaveChangesAsync(ct);

            log.LogInformation(
                "Billing {Type} for {BillingId}: {Outcome}, premium until {Until}",
                e.TryGetProperty("type", out var t) ? t.GetString() : "?",
                billingId, outcome, subscription.PremiumUntil);
            return Results.Ok(new { status = outcome });
        });
    }

    /// <summary>
    /// Applies one provider event to a subscription. Pure, so the part that
    /// is actually easy to get wrong can be tested without a database.
    /// </summary>
    public static string Apply(Subscription subscription, JsonElement e)
    {
        var at = Millis(e, "event_timestamp_ms");
        if (at is not null && subscription.LastEventAt >= at)
        {
            // Out of order, and by the provider's own clock — so nothing here
            // is newer than what we already applied. This is the case that
            // would otherwise expire a family that has paid: a renewal and
            // the billing-issue notice it resolves arrive seconds apart and
            // not always in that order.
            return "stale";
        }

        // Deliberately not a switch on event type. Every event that moves a
        // subscription carries the expiry it results in, so applying that one
        // field covers purchase, renewal, cancellation, refund, billing grace
        // and expiry alike — and cannot be wrong about what CANCELLATION
        // means (the paid-for period stands; it is the renewal that stopped).
        var type = e.TryGetProperty("type", out var t) ? t.GetString() ?? "" : "";
        var period = e.TryGetProperty("period_type", out var p) ? p.GetString() ?? "" : "";
        var expires = Millis(e, "expiration_at_ms");

        if (expires is null && period == "PROMOTIONAL")
        {
            // A grant with no end date, from the provider's dashboard.
            subscription.PremiumUntil = Subscription.Forever;
        }
        else if (expires is not null)
        {
            subscription.PremiumUntil = expires;
        }
        else if (type is "EXPIRATION" or "SUBSCRIPTION_PAUSED")
        {
            subscription.PremiumUntil = at ?? DateTimeOffset.UtcNow;
        }
        else
        {
            // Nothing here says anything about entitlement — an alias or a
            // transfer notice. Recorded as seen, and otherwise left alone.
            subscription.LastEventAt = at ?? subscription.LastEventAt;
            return "ignored";
        }

        subscription.Source = period == "PROMOTIONAL"
            ? SubscriptionSource.Granted
            : StoreOf(e);
        subscription.ProductId = e.TryGetProperty("product_id", out var product)
            ? product.GetString()
            : subscription.ProductId;
        subscription.LastEventAt = at ?? subscription.LastEventAt;
        subscription.UpdatedAt = DateTimeOffset.UtcNow;
        return "applied";
    }

    /// <summary>
    /// The family's subscription row, made if this is the first time anyone
    /// asked. Does not save: the caller decides when.
    /// </summary>
    public static async Task<Subscription> EnsureFor(
        AppDbContext db, Guid familyId, CancellationToken ct)
    {
        var existing = await db.Subscriptions.FirstOrDefaultAsync(s => s.FamilyId == familyId, ct);
        if (existing is not null) return existing;

        var made = new Subscription { FamilyId = familyId, BillingId = Guid.NewGuid() };
        db.Subscriptions.Add(made);
        return made;
    }

    private static SubscriptionSource StoreOf(JsonElement e) =>
        e.TryGetProperty("store", out var store) ? store.GetString() switch
        {
            "APP_STORE" or "MAC_APP_STORE" => SubscriptionSource.AppStore,
            "PLAY_STORE" => SubscriptionSource.PlayStore,
            "PROMOTIONAL" => SubscriptionSource.Granted,
            _ => SubscriptionSource.None
        } : SubscriptionSource.None;

    private static DateTimeOffset? Millis(JsonElement e, string field) =>
        e.TryGetProperty(field, out var value) && value.ValueKind == JsonValueKind.Number
            ? DateTimeOffset.FromUnixTimeMilliseconds(value.GetInt64())
            : null;

    private static bool FixedTimeEquals(string a, string b) =>
        CryptographicOperations.FixedTimeEquals(
            Encoding.UTF8.GetBytes(a), Encoding.UTF8.GetBytes(b));
}
