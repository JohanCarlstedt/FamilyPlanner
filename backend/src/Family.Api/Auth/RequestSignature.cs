using System.Security.Cryptography;
using System.Text;
using Org.BouncyCastle.Math.EC.Rfc8032;

namespace Family.Api.Auth;

/// <summary>
/// Request signatures, crypto doc §2.2: Ed25519 by the device's own key over
/// <c>fam.req.v1\n{device}\n{METHOD}\n{raw path and query}\n{unix ms}\n{hex sha256(body)}</c>.
/// The test vector is app/packages/crypto/rust/test-vectors/request-v1.json.
/// </summary>
public static class RequestSignature
{
    public const string DeviceHeader = "X-Device-Id";
    public const string TimestampHeader = "X-Fam-Timestamp";
    public const string SignatureHeader = "X-Fam-Signature";

    /// <summary>How far a request's clock may be from the server's.</summary>
    public static readonly TimeSpan MaxSkew = TimeSpan.FromMinutes(5);

    public static byte[] Message(string deviceId, string method, string pathAndQuery, long timestampMs, byte[] body)
    {
        var digest = Convert.ToHexStringLower(SHA256.HashData(body));
        return Encoding.UTF8.GetBytes(
            $"fam.req.v1\n{deviceId}\n{method}\n{pathAndQuery}\n{timestampMs}\n{digest}");
    }

    public static bool Verify(string signingPublicKeyBase64, byte[] message, byte[] signature)
    {
        byte[] publicKey;
        try
        {
            publicKey = Convert.FromBase64String(signingPublicKeyBase64);
        }
        catch (FormatException)
        {
            return false;
        }
        return publicKey.Length == Ed25519.PublicKeySize
               && signature.Length == Ed25519.SignatureSize
               && Ed25519.Verify(signature, 0, publicKey, 0, message, 0, message.Length);
    }
}
