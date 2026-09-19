using System.Text;
using System.Text.Json;
using Family.Api.Auth;

namespace Family.Api.Tests;

/// <summary>
/// The server against the shared vector the Rust core and the Python verifier
/// also check: all three must agree on every byte (crypto doc §2.2).
/// </summary>
public class RequestSignatureTests
{
    private static readonly JsonElement Vector = JsonDocument.Parse(File.ReadAllText(
        Path.Combine(AppContext.BaseDirectory, "request-v1.json"))).RootElement;

    private static string Text(string key) => Vector.GetProperty(key).GetString()!;

    private static byte[] VectorMessage() => RequestSignature.Message(
        Text("device_id"), Text("method"), Text("path_and_query"),
        Vector.GetProperty("timestamp_ms").GetInt64(), Encoding.UTF8.GetBytes(Text("body")));

    private static string PublicKey() =>
        Convert.ToBase64String(Convert.FromHexString(Text("signing_public_key")));

    [Fact]
    public void Builds_the_same_message_as_the_vector()
        => Assert.Equal(Text("message"), Encoding.UTF8.GetString(VectorMessage()));

    [Fact]
    public void Verifies_the_vector_signature()
        => Assert.True(RequestSignature.Verify(
            PublicKey(), VectorMessage(), Convert.FromHexString(Text("signature"))));

    [Fact]
    public void Rejects_a_changed_request()
    {
        var tampered = RequestSignature.Message(
            Text("device_id"), "GET", Text("path_and_query"),
            Vector.GetProperty("timestamp_ms").GetInt64(), Encoding.UTF8.GetBytes(Text("body")));
        Assert.False(RequestSignature.Verify(
            PublicKey(), tampered, Convert.FromHexString(Text("signature"))));
    }

    [Fact]
    public void Rejects_malformed_keys_and_signatures()
    {
        var signature = Convert.FromHexString(Text("signature"));
        Assert.False(RequestSignature.Verify("not base64!", VectorMessage(), signature));
        Assert.False(RequestSignature.Verify(Convert.ToBase64String(new byte[31]), VectorMessage(), signature));
        Assert.False(RequestSignature.Verify(PublicKey(), VectorMessage(), signature[..63]));
    }
}
