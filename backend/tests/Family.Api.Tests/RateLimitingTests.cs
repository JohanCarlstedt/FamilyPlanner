using System.Net;
using Family.Api.Auth;
using Microsoft.AspNetCore.Mvc.Testing;

namespace Family.Api.Tests;

/// <summary>
/// The limiter is only worth anything if it runs before the signature check
/// and actually refuses. Both are easy to get wrong by ordering middleware
/// one line later, and neither shows up until someone is pointing a script
/// at the server.
/// </summary>
public class RateLimitingTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public RateLimitingTests(WebApplicationFactory<Program> factory) =>
        // WithWebHostBuilder builds its own host, so each test starts with an
        // empty set of counters — they share an address, and one that spent
        // the minute's budget would otherwise refuse the next test's first
        // request. Nothing here touches the database: health is a constant,
        // and a refusal happens before any endpoint runs.
        _factory = factory.WithWebHostBuilder(b => b.UseSetting("Database:ApplyMigrations", "false"));

    [Fact]
    public async Task An_address_is_refused_once_it_goes_over_the_minute()
    {
        using var client = _factory.CreateClient();

        for (var i = 0; i < RateLimiting.RequestsPerMinute; i++)
        {
            using var allowed = await client.GetAsync("/v1/health");
            Assert.Equal(HttpStatusCode.OK, allowed.StatusCode);
        }

        using var refused = await client.GetAsync("/v1/health");
        Assert.Equal(HttpStatusCode.TooManyRequests, refused.StatusCode);

        // A phone that is merely enthusiastic should learn when to come back
        // rather than retry in a loop.
        Assert.NotNull(refused.Headers.RetryAfter);
    }

    [Fact]
    public async Task Creating_families_runs_out_long_before_the_general_limit()
    {
        using var client = _factory.CreateClient();

        // Unsigned and unparseable on purpose: what matters is that the
        // refusal arrives at the policy's count, not the endpoint's — so
        // this must fail with something other than 429 until then, and the
        // limiter must not be waiting for the general limit.
        var refusedAt = 0;
        for (var i = 1; i <= RateLimiting.RequestsPerMinute; i++)
        {
            using var response = await client.PostAsync("/v1/families",
                new StringContent("{}", System.Text.Encoding.UTF8, "application/json"));
            if (response.StatusCode == HttpStatusCode.TooManyRequests)
            {
                refusedAt = i;
                break;
            }
        }

        Assert.Equal(RateLimiting.FamiliesPerHour + 1, refusedAt);
    }
}

/// <summary>
/// The one write a stranger can reach. What it does with a request that
/// makes no sense is part of its contract, and "500" is the wrong answer:
/// it invites a retry and says the fault is the server's.
/// </summary>
public class CreateFamilyValidationTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public CreateFamilyValidationTests(WebApplicationFactory<Program> factory) =>
        _factory = factory.WithWebHostBuilder(b => b.UseSetting("Database:ApplyMigrations", "false"));

    [Theory]
    // Nothing at all, and every field present but empty: both are refused
    // before anything touches the database, which is why these pass without
    // one.
    [InlineData("{}")]
    [InlineData("""
        {"name":"","timeZone":"","signingPublicKey":"","kemPublicKey":"","platform":"","founderProfileEnvelope":""}
        """)]
    public async Task An_incomplete_founder_is_refused_as_the_caller_s_fault(string body)
    {
        using var client = _factory.CreateClient();

        using var response = await client.PostAsync("/v1/families",
            new StringContent(body, System.Text.Encoding.UTF8, "application/json"));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task A_name_nobody_would_type_is_refused()
    {
        using var client = _factory.CreateClient();
        var body = $$"""
            {"name":"{{new string('x', 5000)}}","timeZone":"Europe/Stockholm",
             "signingPublicKey":"a","kemPublicKey":"b","platform":"android",
             "founderProfileEnvelope":"AQI="}
            """;

        using var response = await client.PostAsync("/v1/families",
            new StringContent(body, System.Text.Encoding.UTF8, "application/json"));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }
}
