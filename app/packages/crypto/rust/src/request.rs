//! Request authentication: crypto doc §2.2.
//!
//! Every authenticated API request carries an Ed25519 signature by the
//! device's own key over a domain-separated text message. The message is
//! built here, never by the caller, so the device key can't be made to sign
//! anything but a request.

use sha2::{Digest, Sha256};

use crate::device::DeviceIdentity;
use crate::envelope::CryptoError;

type Result<T> = std::result::Result<T, CryptoError>;

/// The first line of every signed request. Text, where every other signed
/// structure in this crate is a CBOR array (first byte 0x80–0x9f), so no
/// signature can be read as the other kind.
pub const REQUEST_LABEL: &str = "fam.req.v1";

/// The exact bytes a request signature covers:
///
/// ```text
/// fam.req.v1\n<device id>\n<METHOD>\n<raw path and query>\n<unix ms>\n<hex sha256(body)>
/// ```
///
/// Fields holding a line break are refused: they would make two different
/// requests share one message.
pub fn request_message(
    device_id: &str,
    method: &str,
    path_and_query: &str,
    timestamp_ms: u64,
    body: &[u8],
) -> Result<Vec<u8>> {
    for field in [device_id, method, path_and_query] {
        if field.is_empty() || field.contains(['\n', '\r']) {
            return Err(CryptoError::Malformed(
                "request field is empty or holds a line break".into(),
            ));
        }
    }
    let digest = Sha256::digest(body);
    let hex: String = digest.iter().map(|b| format!("{b:02x}")).collect();
    Ok(
        format!("{REQUEST_LABEL}\n{device_id}\n{method}\n{path_and_query}\n{timestamp_ms}\n{hex}")
            .into_bytes(),
    )
}

/// Signs a request as [identity]. 64 bytes, RFC 8032.
pub fn sign_request(
    identity: &DeviceIdentity,
    device_id: &str,
    method: &str,
    path_and_query: &str,
    timestamp_ms: u64,
    body: &[u8],
) -> Result<[u8; 64]> {
    let message = request_message(device_id, method, path_and_query, timestamp_ms, body)?;
    Ok(identity.sign(&message).to_bytes())
}

#[cfg(test)]
mod tests {
    use super::*;
    use ed25519_dalek::{Signature, Verifier, VerifyingKey};

    #[test]
    fn a_signature_verifies_against_the_published_key() {
        let device = DeviceIdentity::generate();
        let sig = sign_request(&device, "dev-1", "POST", "/v1/commands", 1, b"{}").unwrap();
        let key = VerifyingKey::from_bytes(&device.public_keys().signing).unwrap();
        let message = request_message("dev-1", "POST", "/v1/commands", 1, b"{}").unwrap();
        key.verify(&message, &Signature::from_bytes(&sig)).unwrap();
    }

    #[test]
    fn every_part_of_the_request_is_covered() {
        let base = request_message("dev-1", "POST", "/v1/commands", 1, b"{}").unwrap();
        for other in [
            request_message("dev-2", "POST", "/v1/commands", 1, b"{}"),
            request_message("dev-1", "PUT", "/v1/commands", 1, b"{}"),
            request_message("dev-1", "POST", "/v1/commands?x=1", 1, b"{}"),
            request_message("dev-1", "POST", "/v1/commands", 2, b"{}"),
            request_message("dev-1", "POST", "/v1/commands", 1, b"{ }"),
        ] {
            assert_ne!(other.unwrap(), base);
        }
    }

    #[test]
    fn line_breaks_in_fields_are_refused() {
        assert!(request_message("dev-1\nPOST", "GET", "/", 1, b"").is_err());
        assert!(request_message("dev-1", "GET", "/a\r\n", 1, b"").is_err());
        assert!(request_message("", "GET", "/", 1, b"").is_err());
    }
}
