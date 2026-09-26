using Family.Api.Endpoints;

namespace Family.Api.Tests;

/// <summary>
/// The feedback board's one promise about people: an anonymous post shows no
/// name, and the fingerprint kept instead is the same for a member every
/// time (one vote each, their own post removable) without being their id.
/// </summary>
public class FeedbackTests
{
    [Fact]
    public void A_member_has_one_fingerprint_that_is_not_their_id()
    {
        var member = Guid.NewGuid();
        var key = FeedbackEndpoints.KeyOf(member);

        Assert.Equal(key, FeedbackEndpoints.KeyOf(member));
        Assert.NotEqual(key, FeedbackEndpoints.KeyOf(Guid.NewGuid()));
        Assert.DoesNotContain(member.ToString("N"), key);
        Assert.DoesNotContain(member.ToString(), key);
        Assert.Equal(64, key.Length);
    }
}
