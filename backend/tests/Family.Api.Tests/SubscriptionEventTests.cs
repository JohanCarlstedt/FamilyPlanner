using System.Text.Json;
using Family.Api.Domain;
using Family.Api.Endpoints;

namespace Family.Api.Tests;

/// <summary>
/// What the billing provider's notifications do to a family's entitlement.
///
/// This is the part that costs money when it is wrong, in both directions: a
/// family that has paid and is refused, or one that stopped paying a year ago
/// and still has everything. Neither shows up in ordinary use, and both are
/// discovered by a person who is already annoyed.
/// </summary>
public class SubscriptionEventTests
{
    private static JsonElement Event(
        string type,
        long? expirationMs = null,
        long? timestampMs = null,
        string? periodType = null,
        string? store = null,
        string? productId = null)
    {
        var fields = new Dictionary<string, object?>
        {
            ["type"] = type,
            ["app_user_id"] = Guid.NewGuid().ToString(),
            ["event_timestamp_ms"] = timestampMs,
            ["expiration_at_ms"] = expirationMs,
            ["period_type"] = periodType,
            ["store"] = store,
            ["product_id"] = productId
        };
        foreach (var empty in fields.Where(f => f.Value is null).Select(f => f.Key).ToList())
            fields.Remove(empty);

        return JsonDocument.Parse(JsonSerializer.Serialize(fields)).RootElement;
    }

    private static long Ms(DateTimeOffset at) => at.ToUnixTimeMilliseconds();

    private static readonly DateTimeOffset Now =
        new(2026, 9, 21, 12, 0, 0, TimeSpan.Zero);

    [Fact]
    public void A_purchase_grants_premium_until_the_expiry_the_store_gave()
    {
        var subscription = new Subscription { FamilyId = Guid.NewGuid() };
        var until = Now.AddMonths(1);

        var outcome = SubscriptionEndpoints.Apply(subscription, Event(
            "INITIAL_PURCHASE",
            expirationMs: Ms(until),
            timestampMs: Ms(Now),
            store: "APP_STORE",
            productId: "premium.monthly"));

        Assert.Equal("applied", outcome);
        Assert.True(subscription.IsPremiumAt(Now));
        Assert.Equal(until, subscription.PremiumUntil);
        Assert.Equal(SubscriptionSource.AppStore, subscription.Source);
        Assert.Equal("premium.monthly", subscription.ProductId);
    }

    [Fact]
    public void Cancelling_keeps_the_period_that_was_paid_for()
    {
        // The single most tempting mistake: CANCELLATION reads like "stop", and
        // it means "do not renew". A family that cancels in week one has paid
        // for the month and keeps the month.
        var until = Now.AddDays(20);
        var subscription = new Subscription
        {
            FamilyId = Guid.NewGuid(),
            PremiumUntil = until,
            Source = SubscriptionSource.AppStore
        };

        SubscriptionEndpoints.Apply(subscription, Event(
            "CANCELLATION", expirationMs: Ms(until), timestampMs: Ms(Now)));

        Assert.True(subscription.IsPremiumAt(Now));
        Assert.True(subscription.IsPremiumAt(until.AddSeconds(-1)));
        Assert.False(subscription.IsPremiumAt(until.AddSeconds(1)));
    }

    [Fact]
    public void A_renewal_that_overtakes_a_billing_issue_is_not_undone_by_it()
    {
        // Both arrive within seconds and not always in order. Applying the
        // older one second would expire a family whose payment went through.
        var subscription = new Subscription { FamilyId = Guid.NewGuid() };

        var renewalAt = Now;
        var issueAt = Now.AddSeconds(-30);

        SubscriptionEndpoints.Apply(subscription, Event(
            "RENEWAL",
            expirationMs: Ms(Now.AddMonths(1)),
            timestampMs: Ms(renewalAt)));

        var outcome = SubscriptionEndpoints.Apply(subscription, Event(
            "BILLING_ISSUE",
            expirationMs: Ms(Now.AddDays(1)),
            timestampMs: Ms(issueAt)));

        Assert.Equal("stale", outcome);
        Assert.Equal(Now.AddMonths(1), subscription.PremiumUntil);
        Assert.True(subscription.IsPremiumAt(Now.AddDays(20)));
    }

    [Fact]
    public void Expiry_ends_premium()
    {
        var subscription = new Subscription
        {
            FamilyId = Guid.NewGuid(),
            PremiumUntil = Now.AddDays(5),
            Source = SubscriptionSource.PlayStore
        };

        SubscriptionEndpoints.Apply(subscription, Event(
            "EXPIRATION",
            expirationMs: Ms(Now),
            timestampMs: Ms(Now),
            store: "PLAY_STORE"));

        Assert.False(subscription.IsPremiumAt(Now));
    }

    [Fact]
    public void An_expiry_notice_with_no_date_ends_it_at_the_notice()
    {
        var subscription = new Subscription
        {
            FamilyId = Guid.NewGuid(),
            PremiumUntil = Now.AddDays(5)
        };

        SubscriptionEndpoints.Apply(subscription, Event(
            "EXPIRATION", timestampMs: Ms(Now)));

        Assert.False(subscription.IsPremiumAt(Now));
    }

    [Fact]
    public void A_grant_with_no_end_date_lasts()
    {
        var subscription = new Subscription { FamilyId = Guid.NewGuid() };

        SubscriptionEndpoints.Apply(subscription, Event(
            "INITIAL_PURCHASE",
            timestampMs: Ms(Now),
            periodType: "PROMOTIONAL",
            store: "PROMOTIONAL"));

        Assert.Equal(Subscription.Forever, subscription.PremiumUntil);
        Assert.Equal(SubscriptionSource.Granted, subscription.Source);
        Assert.True(subscription.IsPremiumAt(Now.AddYears(50)));
    }

    [Fact]
    public void A_grant_for_three_months_ends_after_three_months()
    {
        var subscription = new Subscription { FamilyId = Guid.NewGuid() };

        SubscriptionEndpoints.Apply(subscription, Event(
            "INITIAL_PURCHASE",
            expirationMs: Ms(Now.AddMonths(3)),
            timestampMs: Ms(Now),
            periodType: "PROMOTIONAL"));

        Assert.Equal(SubscriptionSource.Granted, subscription.Source);
        Assert.True(subscription.IsPremiumAt(Now.AddMonths(2)));
        Assert.False(subscription.IsPremiumAt(Now.AddMonths(4)));
    }

    [Fact]
    public void A_notice_that_says_nothing_about_entitlement_changes_nothing()
    {
        var until = Now.AddMonths(1);
        var subscription = new Subscription
        {
            FamilyId = Guid.NewGuid(),
            PremiumUntil = until,
            Source = SubscriptionSource.AppStore,
            ProductId = "premium.monthly"
        };

        var outcome = SubscriptionEndpoints.Apply(subscription, Event(
            "SUBSCRIBER_ALIAS", timestampMs: Ms(Now)));

        Assert.Equal("ignored", outcome);
        Assert.Equal(until, subscription.PremiumUntil);
        Assert.Equal("premium.monthly", subscription.ProductId);
        // Still recorded as seen, so it cannot be replayed later as new.
        Assert.Equal(Now, subscription.LastEventAt);
    }

    [Fact]
    public void A_family_that_never_paid_has_nothing()
    {
        var subscription = new Subscription { FamilyId = Guid.NewGuid() };

        Assert.False(subscription.IsPremiumAt(Now));
        Assert.Null(subscription.PremiumUntil);
        Assert.Equal(SubscriptionSource.None, subscription.Source);
    }
}
