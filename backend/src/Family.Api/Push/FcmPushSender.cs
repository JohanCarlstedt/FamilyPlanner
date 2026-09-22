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
        if (response.IsSuccessStatusCode)
        {
            // Said out loud, because until now nothing did. Failures were
            // logged and success was silent, so "is push working?" could
            // only be answered by standing next to a phone — which is why
            // it went months without anyone being sure. The reference is
            // an HMAC, not a title: this says a wake went out, never what
            // it was about.
            // The reference and nothing else: it is an HMAC, so this says a
            // wake went out and never what it was about. The push token is
            // deliberately not here — a log is not the place for it.
            _log.LogInformation("Push accepted by FCM, ref={Ref}", correlationRef);
            return PushResult.Sent;
        }

        var error = await response.Content.ReadAsStringAsync(ct);
        var result = Classify(response.StatusCode, error);
        if (result == PushResult.TokenGone) return result;

        if (response.StatusCode == HttpStatusCode.Unauthorized) _accessToken = null;
        // What it objected to, not merely that it objected. The body is
        // FCM's own error — a status and a sentence — and it is the whole
        // difference between "push is broken" and knowing why. Truncated,
        // because an error is not a place to pour a response into, and the
        // token is never logged: a log is not where that belongs.
        _log.LogWarning(
            "FCM send failed: {Status} {Error}",
            (int)response.StatusCode,
            Summarise(error));
        return result;
    }

    /// <summary>
    /// What a refusal from FCM means for the token that caused it.
    ///
    /// Retiring a token is destructive — that device stops being woken
    /// until it next opens the app and registers again — so this errs
    /// towards keeping it. The one case worth being sure about is a token
    /// FCM itself says it cannot parse, which it reports as 400
    /// INVALID_ARGUMENT naming <c>message.token</c>, never as 404. Before
    /// this, that token was retried at every wake, for ever.
    ///
    /// The named field is the whole of the distinction: the same 400 is
    /// what a malformed <em>message</em> gets, and reading that as a dead
    /// token would throw away every device's token at once, for a fault
    /// that is ours and fixed by a deploy.
    /// </summary>
    public static PushResult Classify(HttpStatusCode status, string body)
    {
        // 404 UNREGISTERED is FCM's word for a token that will never work
        // again: the app was uninstalled, or the token was rotated.
        if (status == HttpStatusCode.NotFound || body.Contains("UNREGISTERED"))
            return PushResult.TokenGone;

        if (status == HttpStatusCode.BadRequest && body.Contains("message.token"))
            return PushResult.TokenGone;

        return PushResult.Failed;
    }

    /// <summary>FCM's own status and message, short enough for a log line.</summary>
    public static string Summarise(string body)
    {
        try
        {
            var error = JsonDocument.Parse(body).RootElement.GetProperty("error");
            var status = error.TryGetProperty("status", out var s) ? s.GetString() : null;
            var message = error.TryGetProperty("message", out var m) ? m.GetString() : null;
            var text = string.Join(": ", new[] { status, message }.Where(x => x is not null));
            return text.Length > 200 ? text[..200] : text;
        }
        catch (JsonException)
        {
            return body.Length > 200 ? body[..200] : body;
        }
        catch (KeyNotFoundException)
        {
            return body.Length > 200 ? body[..200] : body;
        }
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
