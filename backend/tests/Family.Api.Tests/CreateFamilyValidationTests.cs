using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Mvc.Testing;

namespace Family.Api.Tests;

/// <summary>
/// The one write a stranger can reach. What it does with a request that
/// makes no sense is part of its contract, and "500" is the wrong answer:
/// it invites a retry and says the fault is the server's.
///
/// The first test here exists because of a real first run that failed.
/// This endpoint demanded a non-empty founder profile envelope; the app
/// sends an empty one by design, because an envelope is sealed against a
/// member id that does not exist until the call returns. So every new
/// family was refused with "incomplete", and nothing caught it — the only
/// household on the server predated the check, the smoke test sends random
/// bytes rather than what the client sends, and the tests below covered
/// "every field empty" but never "every field right except that one".
/// </summary>
public class CreateFamilyValidationTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public CreateFamilyValidationTests(WebApplicationFactory<Program> factory) =>
        _factory = factory.WithWebHostBuilder(
            b => b.UseSetting("Database:ApplyMigrations", "false"));

    /// The request as the client builds it (FamilyApi.createFamily).
    private static object AsTheAppSends(
        string name = "Witkarsson",
        string timeZone = "Europe/Stockholm",
        string signing = "c2lnbmluZy1rZXk=",
        string kem = "a2VtLWtleQ==",
        string platform = "ios") => new
        {
            name,
            timeZone,
            signingPublicKey = signing,
            kemPublicKey = kem,
            platform,
            // Empty, deliberately, and it must stay acceptable.
            founderProfileEnvelope = ""
        };

    [Fact]
    public async Task The_founder_profile_envelope_is_empty_on_a_real_first_run()
    {
        using var client = _factory.CreateClient();

        using var response = await client.PostAsJsonAsync(
            "/v1/families", AsTheAppSends());

        // Anything but a refusal. The write itself may fail in a fixture
        // with no database, and that is not what is under test: whether the
        // request is understood is.
        Assert.NotEqual(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Theory]
    [InlineData("name")]
    [InlineData("timeZone")]
    [InlineData("signingPublicKey")]
    [InlineData("kemPublicKey")]
    [InlineData("platform")]
    public async Task A_field_a_founder_really_needs_is_refused_when_blank(string missing)
    {
        using var client = _factory.CreateClient();
        var body = missing switch
        {
            "name" => AsTheAppSends(name: "   "),
            "timeZone" => AsTheAppSends(timeZone: ""),
            "signingPublicKey" => AsTheAppSends(signing: ""),
            "kemPublicKey" => AsTheAppSends(kem: ""),
            _ => AsTheAppSends(platform: "")
        };

        using var response = await client.PostAsJsonAsync("/v1/families", body);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains("incomplete", await response.Content.ReadAsStringAsync());
    }

    [Theory]
    // Nothing at all, and every field present but empty: both refused
    // before anything touches the database, which is why these pass
    // without one.
    [InlineData("{}")]
    [InlineData("""
        {"name":"","timeZone":"","signingPublicKey":"","kemPublicKey":"","platform":"","founderProfileEnvelope":""}
        """)]
    public async Task An_incomplete_founder_is_refused_as_the_caller_s_fault(string body)
    {
        using var client = _factory.CreateClient();

        using var response = await client.PostAsync(
            "/v1/families",
            new StringContent(body, System.Text.Encoding.UTF8, "application/json"));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task A_name_nobody_would_type_is_refused()
    {
        using var client = _factory.CreateClient();

        using var response = await client.PostAsJsonAsync(
            "/v1/families", AsTheAppSends(name: new string('x', 5000)));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains("too_large", await response.Content.ReadAsStringAsync());
    }
}
