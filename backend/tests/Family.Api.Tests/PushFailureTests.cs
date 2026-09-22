using System.Net;
using Family.Api.Push;

namespace Family.Api.Tests;

/// <summary>
/// What a refusal from FCM means for the token that caused it.
///
/// Android push has never been watched working end to end, and this is
/// most of why: a failure logged only its status code, so the one line
/// anybody could look at said "FCM send failed: 400" and nothing else.
/// Behind that 400 were two entirely different situations — a token FCM
/// cannot parse, which will never work again, and a message we built
/// wrongly, which every device would hit at once.
///
/// Telling them apart is worth a test, because getting it wrong in the
/// generous direction retries a dead token for ever, and getting it wrong
/// in the other direction throws away every push token the family has.
/// </summary>
public class PushFailureTests
{
    private const string BadToken = """
        {"error":{"code":400,"message":"The registration token is not a valid FCM registration token",
        "status":"INVALID_ARGUMENT","details":[{"fieldViolations":[{"field":"message.token"}]}]}}
        """;

    private const string BadMessage = """
        {"error":{"code":400,"message":"Invalid value at 'message.android.ttl'",
        "status":"INVALID_ARGUMENT","details":[{"fieldViolations":[{"field":"message.android.ttl"}]}]}}
        """;

    private const string Unregistered = """
        {"error":{"code":404,"message":"Requested entity was not found.","status":"NOT_FOUND",
        "details":[{"errorCode":"UNREGISTERED"}]}}
        """;

    [Fact]
    public void A_token_FCM_cannot_parse_is_gone_for_good()
    {
        // It answers 400, never 404, so this used to fall through to
        // "try again" and be retried at every wake, for ever.
        Assert.Equal(
            PushResult.TokenGone,
            FcmPushSender.Classify(HttpStatusCode.BadRequest, BadToken));
    }

    [Fact]
    public void An_uninstalled_app_is_gone_for_good()
    {
        Assert.Equal(
            PushResult.TokenGone,
            FcmPushSender.Classify(HttpStatusCode.NotFound, Unregistered));
    }

    [Fact]
    public void A_message_we_built_wrongly_keeps_every_token()
    {
        // The same status and the same INVALID_ARGUMENT as a bad token.
        // Only the named field tells them apart, and reading this one as a
        // dead token would retire the push token of every device in the
        // family at once, for a fault that is ours and fixed by a deploy.
        Assert.Equal(
            PushResult.Failed,
            FcmPushSender.Classify(HttpStatusCode.BadRequest, BadMessage));
    }

    [Theory]
    [InlineData(HttpStatusCode.Unauthorized)]
    [InlineData(HttpStatusCode.TooManyRequests)]
    [InlineData(HttpStatusCode.InternalServerError)]
    [InlineData(HttpStatusCode.ServiceUnavailable)]
    public void Anything_that_might_pass_keeps_the_token(HttpStatusCode status)
    {
        Assert.Equal(PushResult.Failed, FcmPushSender.Classify(status, "{}"));
    }

    [Fact]
    public void The_log_line_says_what_FCM_objected_to()
    {
        var summary = FcmPushSender.Summarise(BadToken);
        Assert.Contains("INVALID_ARGUMENT", summary);
        Assert.Contains("registration token", summary);
    }

    [Fact]
    public void A_body_that_is_not_the_shape_we_expect_still_says_something()
    {
        // An HTML error page from something in front of FCM, say. Worse
        // than a parsed message, better than the status code alone.
        Assert.Contains("Gateway", FcmPushSender.Summarise("<html>502 Bad Gateway</html>"));
        Assert.Equal("", FcmPushSender.Summarise(""));
    }

    [Fact]
    public void A_long_body_does_not_become_a_long_log_line()
    {
        Assert.True(FcmPushSender.Summarise(new string('x', 5000)).Length <= 200);
    }
}
