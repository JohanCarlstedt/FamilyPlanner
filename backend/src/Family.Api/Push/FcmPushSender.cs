using System.Net;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Family.Api.Push;

/// <summary>What became of one push.</summary>
public enum PushResult
{
    Sent,

    /// <summary>The token is gone for good (app uninstalled, token rotated): forget it.</summary>
    TokenGone,

    /// <summary>Anything else. Worth another try while the wake is still fresh.</summary>
    Failed
}

public interface IPushSender
{
    Task<PushResult> SendSilentAsync(string token, string correlationRef, CancellationToken ct);
}

/// <summary>Development stand-in when no FCM credentials are configured.</summary>
public class LoggingPushSender(ILogger<LoggingPushSender> log) : IPushSender
{
    public Task<PushResult> SendSilentAsync(string token, string correlationRef, CancellationToken ct)
    {
        log.LogInformation("Silent push (not sent, no FCM credentials) ref={Ref}", correlationRef);
        return Task.FromResult(PushResult.Sent);
    }
}

/// <summary>
/// FCM HTTP v1, spoken directly (architecture doc §11): a data-only, high-priority
/// message carrying a correlation reference and nothing else. The OAuth token comes
/// from a JWT signed with the service account's own key, so no Google SDK is needed.
/// </summary>
public sealed class FcmPushSender : IPushSender, IDisposable
{
    private const string Scope = "https://www.googleapis.com/auth/firebase.messaging";

    private readonly HttpClient _http;
    private readonly RSA _key;
    private readonly string _clientEmail;
    private readonly string _tokenUri;
    private readonly string _sendUri;
    private readonly ILogger<FcmPushSender> _log;
    private readonly SemaphoreSlim _tokenLock = new(1, 1);
    private string? _accessToken;
    private DateTimeOffset _accessTokenExpiry;

    private FcmPushSender(ServiceAccount account, HttpClient http, ILogger<FcmPushSender> log)
    {
        _http = http;
        _log = log;
        _clientEmail = account.ClientEmail;
        _tokenUri = account.TokenUri ?? "https://oauth2.googleapis.com/token";
        _sendUri = $"https://fcm.googleapis.com/v1/projects/{account.ProjectId}/messages:send";
        _key = RSA.Create();
        _key.ImportFromPem(account.PrivateKey);
    }

    /// <summary>A sender for the service account file at <paramref name="path"/>.</summary>
    public static FcmPushSender FromFile(string path, HttpClient http, ILogger<FcmPushSender> log)
    {
        var account = JsonSerializer.Deserialize<ServiceAccount>(File.ReadAllText(path))
                      ?? throw new InvalidOperationException("Empty FCM service account file");
        return new FcmPushSender(account, http, log);
    }

    public async Task<PushResult> SendSilentAsync(string token, string correlationRef, CancellationToken ct)
    {
        var body = new
        {
            message = new
            {
                token,
                // Data only: no notification block, so nothing is shown until the
                // device has decrypted the event and written the text itself.
                data = new Dictionary<string, string> { ["type"] = "wake", ["ref"] = correlationRef },
                android = new { priority = "HIGH", ttl = "600s" }
            }
        };

        using var request = new HttpRequestMessage(HttpMethod.Post, _sendUri)
        {
            Content = JsonContent.Create(body)
        };
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", await AccessTokenAsync(ct));

        using var response = await _http.SendAsync(request, ct);
        if (response.IsSuccessStatusCode) return PushResult.Sent;

        var error = await response.Content.ReadAsStringAsync(ct);
        // 404 UNREGISTERED is FCM's word for a token that will never work again.
        if (response.StatusCode == HttpStatusCode.NotFound || error.Contains("UNREGISTERED"))
            return PushResult.TokenGone;

        if (response.StatusCode == HttpStatusCode.Unauthorized) _accessToken = null;
        _log.LogWarning("FCM send failed: {Status}", (int)response.StatusCode);
        return PushResult.Failed;
    }

    private async Task<string> AccessTokenAsync(CancellationToken ct)
    {
        await _tokenLock.WaitAsync(ct);
        try
        {
            if (_accessToken is not null && DateTimeOffset.UtcNow < _accessTokenExpiry)
                return _accessToken;

            var now = DateTimeOffset.UtcNow;
            var assertion = SignedJwt(new Dictionary<string, object>
            {
                ["iss"] = _clientEmail,
                ["scope"] = Scope,
                ["aud"] = _tokenUri,
                ["iat"] = now.ToUnixTimeSeconds(),
                ["exp"] = now.AddHours(1).ToUnixTimeSeconds()
            });

            using var response = await _http.PostAsync(_tokenUri, new FormUrlEncodedContent(
                new Dictionary<string, string>
                {
                    ["grant_type"] = "urn:ietf:params:oauth:grant-type:jwt-bearer",
                    ["assertion"] = assertion
                }), ct);
            response.EnsureSuccessStatusCode();

            var token = await response.Content.ReadFromJsonAsync<TokenResponse>(ct)
                        ?? throw new InvalidOperationException("Empty OAuth token response");
            _accessToken = token.AccessToken;
            // Renew a few minutes early rather than race the expiry.
            _accessTokenExpiry = now.AddSeconds(token.ExpiresIn - 300);
            return _accessToken;
        }
        finally
        {
            _tokenLock.Release();
        }
    }

    private string SignedJwt(Dictionary<string, object> claims)
    {
        var header = Base64Url(JsonSerializer.SerializeToUtf8Bytes(new { alg = "RS256", typ = "JWT" }));
        var payload = Base64Url(JsonSerializer.SerializeToUtf8Bytes(claims));
        var signingInput = $"{header}.{payload}";
        var signature = _key.SignData(
            Encoding.ASCII.GetBytes(signingInput), HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
        return $"{signingInput}.{Base64Url(signature)}";
    }

    private static string Base64Url(byte[] bytes) =>
        Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');

    public void Dispose()
    {
        _key.Dispose();
        _tokenLock.Dispose();
    }

    private sealed record ServiceAccount(
        [property: JsonPropertyName("project_id")] string ProjectId,
        [property: JsonPropertyName("client_email")] string ClientEmail,
        [property: JsonPropertyName("private_key")] string PrivateKey,
        [property: JsonPropertyName("token_uri")] string? TokenUri);

    private sealed record TokenResponse(
        [property: JsonPropertyName("access_token")] string AccessToken,
        [property: JsonPropertyName("expires_in")] int ExpiresIn);
}
