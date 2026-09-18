//! Adding a device by QR code: crypto design doc §7.1.
//!
//! The new device shows a pairing code; a trusted family device scans it,
//! registers it with the server, and admits it.
//!
//! - The scan authenticates the new device: its keys come off the screen, not
//!   from the server.
//! - A random secret in the code authenticates the scanner back: its admission,
//!   which tells the new device its family, member and device id, is tagged with
//!   a key only a device that saw the screen can hold. The new device collects
//!   it from a mailbox whose address is also derived from that secret.
//! - An endorsement, signed by the admitting device, introduces the new device
//!   to every other family device that already trusts the admitter.

use ciborium::Value;
use ed25519_dalek::Signature;
use hkdf::Hkdf;
use hmac::{Hmac, KeyInit, Mac};
use sha2::Sha256;
use zeroize::{Zeroize, ZeroizeOnDrop, Zeroizing};

use crate::cbor::{self, Fields, malformed};
use crate::device::{self, DeviceIdentity};
use crate::envelope::{CryptoError, OsRandom, Random};
use crate::grant::TrustedDevice;

type Result<T> = std::result::Result<T, CryptoError>;

/// Version shared by the pairing code, admission and endorsement formats.
pub const PAIRING_VERSION: u64 = 1;

/// Prefix of a pairing code's text form: marks the format and its version, and
/// stays within the QR alphanumeric character set.
pub const CODE_PREFIX: &str = "FAM1:";

const KEY_LEN: usize = 32;
const SECRET_LEN: usize = 32;
const TAG_LEN: usize = 32;
const SIG_LEN: usize = 64;

const ADMIT_KEY_INFO: &[u8] = b"fam.admit.v1";
const MAILBOX_INFO: &[u8] = b"fam.mailbox.v1";
const MAILBOX_LEN: usize = 16;
const ADMIT_LABEL: &str = "fam.admit";
const ENDORSE_LABEL: &str = "fam.endorse";

/// A device as the family knows it: id and both public keys.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DeviceRecord {
    pub device_id: String,
    pub signing_key: [u8; KEY_LEN],
    pub kem_key: [u8; KEY_LEN],
}

impl DeviceRecord {
    pub fn of(device_id: impl Into<String>, identity: &DeviceIdentity) -> Self {
        let keys = identity.public_keys();
        DeviceRecord {
            device_id: device_id.into(),
            signing_key: keys.signing,
            kem_key: keys.kem,
        }
    }

    pub fn trusted(&self) -> TrustedDevice {
        TrustedDevice {
            device_id: self.device_id.clone(),
            signing_key: self.signing_key,
        }
    }

    fn to_value(&self) -> Value {
        Value::Map(vec![
            (text("id"), text(&self.device_id)),
            (text("sig"), Value::Bytes(self.signing_key.to_vec())),
            (text("kem"), Value::Bytes(self.kem_key.to_vec())),
        ])
    }

    fn from_value(value: &Value) -> Result<Self> {
        let f = Fields::of(value, "device")?;
        f.only(&["id", "sig", "kem"])?;
        let record = DeviceRecord {
            device_id: non_empty(f.text("id")?)?,
            signing_key: key32(&f, "sig")?,
            kem_key: key32(&f, "kem")?,
        };
        device::verifying_key(&record.signing_key)?;
        Ok(record)
    }
}

// ---------------------------------------------------------------------------
// New device: show a code, wait at the mailbox, accept the admission.

/// What a new device learns from its admission: where it now belongs, and whom
/// to trust.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Admitted {
    pub family_id: String,
    pub member_id: String,
    /// The id the admitting device registered this device under.
    pub device_id: String,
    /// The devices to trust from now on, the admitter among them.
    pub trusted: Vec<DeviceRecord>,
}

/// Held by the new device from showing its code until the admission arrives.
/// Single use: drop it when the pairing screen closes.
///
/// A new device belongs to no family yet and has no device id, so its code
/// carries only its public keys and the secret. The admitting device registers
/// it, and the admission tells it where it now belongs.
#[derive(Zeroize, ZeroizeOnDrop)]
pub struct PairingSession {
    #[zeroize(skip)]
    signing_key: [u8; KEY_LEN],
    #[zeroize(skip)]
    kem_key: [u8; KEY_LEN],
    secret: [u8; SECRET_LEN],
}

impl PairingSession {
    pub fn start(identity: &DeviceIdentity) -> Self {
        Self::start_with(&mut OsRandom, identity)
    }

    pub(crate) fn start_with(rng: &mut impl Random, identity: &DeviceIdentity) -> Self {
        let keys = identity.public_keys();
        let mut secret = [0u8; SECRET_LEN];
        rng.fill(&mut secret);
        PairingSession {
            signing_key: keys.signing,
            kem_key: keys.kem,
            secret,
        }
    }

    /// The text to render as a QR code: `FAM1:` then base32 of the CBOR code.
    /// It contains the secret, so it is shown on screen and never sent anywhere.
    pub fn code(&self) -> Zeroizing<String> {
        let bytes = Zeroizing::new(cbor::encode(&Value::Map(vec![
            (text("v"), Value::Integer(PAIRING_VERSION.into())),
            (text("sig"), Value::Bytes(self.signing_key.to_vec())),
            (text("kem"), Value::Bytes(self.kem_key.to_vec())),
            (text("k"), Value::Bytes(self.secret.to_vec())),
        ])));
        Zeroizing::new(format!("{CODE_PREFIX}{}", base32::encode(&bytes)))
    }

    /// Where to collect the admission. See [mailbox].
    pub fn mailbox(&self) -> String {
        mailbox(&self.secret)
    }

    /// Verifies an admission and returns where this device now belongs.
    pub fn accept(&self, admission: &[u8]) -> Result<Admitted> {
        let value = cbor::decode(admission).map_err(CryptoError::Malformed)?;
        let f = Fields::of(&value, "admission")?;
        check_version(&f)?;
        f.only(&["v", "fam", "member", "to", "from", "devs", "tag"])?;

        let family_id = non_empty(f.text("fam")?)?;
        let member_id = non_empty(f.text("member")?)?;
        let device_id = non_empty(f.text("to")?)?;
        let from = non_empty(f.text("from")?)?;
        let Value::Array(entries) = f.get("devs")? else {
            return Err(malformed("devs must be an array"));
        };
        let trusted = entries
            .iter()
            .map(DeviceRecord::from_value)
            .collect::<Result<Vec<_>>>()?;
        if !trusted.iter().any(|d| d.device_id == from) {
            return Err(malformed(
                "the admitting device must be among the trusted devices",
            ));
        }

        let me = DeviceRecord {
            device_id,
            signing_key: self.signing_key,
            kem_key: self.kem_key,
        };
        let tag = f.bytes("tag", Some(TAG_LEN))?;
        // verify_slice compares in constant time.
        mac(&self.secret)
            .chain_update(admission_message(
                &family_id, &member_id, &me, &from, &trusted,
            ))
            .verify_slice(&tag)
            .map_err(|_| CryptoError::Tampered)?;

        Ok(Admitted {
            family_id,
            member_id,
            device_id: me.device_id,
            trusted,
        })
    }
}

// ---------------------------------------------------------------------------
// Admitting device: scan, register, admit, endorse.

/// A pairing code read off another device's screen.
#[derive(Zeroize, ZeroizeOnDrop)]
pub struct ScannedCode {
    /// The new device's Ed25519 key, as shown on its screen.
    #[zeroize(skip)]
    pub signing_key: [u8; KEY_LEN],
    /// The new device's X25519 key, as shown on its screen.
    #[zeroize(skip)]
    pub kem_key: [u8; KEY_LEN],
    secret: [u8; SECRET_LEN],
}

impl ScannedCode {
    pub fn parse(code: &str) -> Result<Self> {
        let encoded = code
            .trim()
            .strip_prefix(CODE_PREFIX)
            .ok_or_else(|| malformed("not a family pairing code"))?;
        let bytes = Zeroizing::new(base32::decode(encoded)?);
        let value = cbor::decode(&bytes).map_err(CryptoError::Malformed)?;
        let f = Fields::of(&value, "pairing code")?;
        check_version(&f)?;
        f.only(&["v", "sig", "kem", "k"])?;

        let signing_key = key32(&f, "sig")?;
        device::verifying_key(&signing_key)?;
        let mut secret = [0u8; SECRET_LEN];
        secret.copy_from_slice(&Zeroizing::new(f.bytes("k", Some(SECRET_LEN))?));
        Ok(ScannedCode {
            signing_key,
            kem_key: key32(&f, "kem")?,
            secret,
        })
    }

    /// Where the new device is waiting for its admission.
    pub fn mailbox(&self) -> String {
        mailbox(&self.secret)
    }

    /// The new device's record under the id it was registered with.
    pub fn record(&self, device_id: &str) -> DeviceRecord {
        DeviceRecord {
            device_id: device_id.into(),
            signing_key: self.signing_key,
            kem_key: self.kem_key,
        }
    }

    /// The message that tells the new device where it belongs: [family_id], as
    /// [member_id], registered as [device_id], trusting [family_devices] with
    /// [from_device] (this device) among them.
    pub fn admit(
        &self,
        family_id: &str,
        member_id: &str,
        device_id: &str,
        from_device: &str,
        family_devices: &[DeviceRecord],
    ) -> Result<Vec<u8>> {
        for id in [family_id, member_id, device_id, from_device] {
            non_empty(id.to_owned())?;
        }
        if !family_devices.iter().any(|d| d.device_id == from_device) {
            return Err(malformed(
                "the admitting device must be among the trusted devices",
            ));
        }
        let me = self.record(device_id);
        let tag: [u8; TAG_LEN] = mac(&self.secret)
            .chain_update(admission_message(
                family_id,
                member_id,
                &me,
                from_device,
                family_devices,
            ))
            .finalize()
            .into_bytes()
            .into();
        Ok(cbor::encode(&Value::Map(vec![
            (text("v"), Value::Integer(PAIRING_VERSION.into())),
            (text("fam"), text(family_id)),
            (text("member"), text(member_id)),
            (text("to"), text(device_id)),
            (text("from"), text(from_device)),
            (
                text("devs"),
                Value::Array(family_devices.iter().map(DeviceRecord::to_value).collect()),
            ),
            (text("tag"), Value::Bytes(tag.to_vec())),
        ])))
    }
}

/// Vouches for [device] to the rest of the family, signed by [endorser].
pub fn endorse(
    endorser: &DeviceIdentity,
    endorser_id: &str,
    family_id: &str,
    device: &DeviceRecord,
) -> Result<Vec<u8>> {
    let family_id = non_empty(family_id.to_owned())?;
    let endorser_id = non_empty(endorser_id.to_owned())?;
    let signature = endorser.sign(&endorsement_message(&family_id, device, &endorser_id));
    Ok(cbor::encode(&Value::Map(vec![
        (text("v"), Value::Integer(PAIRING_VERSION.into())),
        (text("fam"), text(&family_id)),
        (text("dev"), device.to_value()),
        (text("by"), text(&endorser_id)),
        (text("s"), Value::Bytes(signature.to_bytes().to_vec())),
    ])))
}

/// Checks an endorsement from a device this device trusts, returning the
/// device it vouches for.
pub fn verify_endorsement(
    endorsement: &[u8],
    family_id: &str,
    trusted: &[TrustedDevice],
) -> Result<DeviceRecord> {
    let value = cbor::decode(endorsement).map_err(CryptoError::Malformed)?;
    let f = Fields::of(&value, "endorsement")?;
    check_version(&f)?;
    f.only(&["v", "fam", "dev", "by", "s"])?;

    if f.text("fam")? != family_id {
        return Err(CryptoError::WrongRecipient);
    }
    let device = DeviceRecord::from_value(f.get("dev")?)?;
    let by = f.text("by")?;
    let endorser = trusted
        .iter()
        .find(|t| t.device_id == by)
        .ok_or(CryptoError::UntrustedSender)?;

    let signature: [u8; SIG_LEN] = f
        .bytes("s", Some(SIG_LEN))?
        .try_into()
        .expect("length checked");
    device::verifying_key(&endorser.signing_key)?
        .verify_strict(
            &endorsement_message(family_id, &device, &by),
            &Signature::from_bytes(&signature),
        )
        .map_err(|_| CryptoError::Tampered)?;
    Ok(device)
}

// ---------------------------------------------------------------------------

/// What the admission tag covers: everything the new device will act on, plus
/// its own keys as the admitter read them off the screen.
fn admission_message(
    family_id: &str,
    member_id: &str,
    new_device: &DeviceRecord,
    from: &str,
    devices: &[DeviceRecord],
) -> Vec<u8> {
    cbor::encode(&Value::Array(vec![
        text(ADMIT_LABEL),
        Value::Integer(PAIRING_VERSION.into()),
        text(family_id),
        text(member_id),
        new_device.to_value(),
        text(from),
        Value::Array(devices.iter().map(DeviceRecord::to_value).collect()),
    ]))
}

/// The address a new device collects its admission from: 16 bytes of HKDF of
/// the code's secret, as 32 lowercase hex characters.
///
/// A new device can't authenticate to the server before it has a device id,
/// so it waits at an address only a device that saw its screen can compute.
/// The server learns the address, not the secret, and a separate HKDF label
/// keeps the address unrelated to the admission key.
fn mailbox(secret: &[u8; SECRET_LEN]) -> String {
    let mut address = [0u8; MAILBOX_LEN];
    Hkdf::<Sha256>::new(None, secret)
        .expand(MAILBOX_INFO, &mut address)
        .expect("16 bytes is a valid HKDF-SHA256 output length");
    address.iter().map(|b| format!("{b:02x}")).collect()
}

/// HMAC-SHA256 keyed by HKDF of the code's secret, so the secret itself is
/// never used directly as a key.
fn mac(secret: &[u8; SECRET_LEN]) -> Hmac<Sha256> {
    let mut key = Zeroizing::new([0u8; KEY_LEN]);
    Hkdf::<Sha256>::new(None, secret)
        .expand(ADMIT_KEY_INFO, key.as_mut())
        .expect("32 bytes is a valid HKDF-SHA256 output length");
    <Hmac<Sha256> as KeyInit>::new_from_slice(key.as_ref()).expect("HMAC takes any key length")
}

fn endorsement_message(family_id: &str, device: &DeviceRecord, by: &str) -> Vec<u8> {
    cbor::encode(&Value::Array(vec![
        text(ENDORSE_LABEL),
        Value::Integer(PAIRING_VERSION.into()),
        text(family_id),
        device.to_value(),
        text(by),
    ]))
}

fn check_version(f: &Fields) -> Result<()> {
    let version = f.uint("v")?;
    if version != PAIRING_VERSION {
        return Err(CryptoError::UnsupportedVersion(version));
    }
    Ok(())
}

fn key32(f: &Fields, key: &str) -> Result<[u8; KEY_LEN]> {
    Ok(f.bytes(key, Some(KEY_LEN))?
        .try_into()
        .expect("length checked"))
}

fn non_empty(s: String) -> Result<String> {
    if s.is_empty() {
        return Err(malformed("ids must be non-empty"));
    }
    Ok(s)
}

fn text(s: &str) -> Value {
    Value::Text(s.into())
}

/// RFC 4648 base32, uppercase, no padding: fits the QR alphanumeric mode,
/// which packs 5.5 bits per character against byte mode's 8.
mod base32 {
    use crate::cbor::malformed;
    use crate::envelope::CryptoError;

    const ALPHABET: &[u8; 32] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

    pub fn encode(bytes: &[u8]) -> String {
        let mut out = String::with_capacity(bytes.len().div_ceil(5) * 8);
        let (mut buffer, mut bits) = (0u32, 0u32);
        for &b in bytes {
            buffer = (buffer << 8) | u32::from(b);
            bits += 8;
            while bits >= 5 {
                bits -= 5;
                out.push(ALPHABET[((buffer >> bits) & 31) as usize] as char);
            }
        }
        if bits > 0 {
            out.push(ALPHABET[((buffer << (5 - bits)) & 31) as usize] as char);
        }
        out
    }

    pub fn decode(text: &str) -> Result<Vec<u8>, CryptoError> {
        let mut out = Vec::with_capacity(text.len() * 5 / 8);
        let (mut buffer, mut bits) = (0u32, 0u32);
        for c in text.bytes() {
            let value = ALPHABET
                .iter()
                .position(|&a| a == c.to_ascii_uppercase())
                .ok_or_else(|| malformed("pairing code has an invalid character"))?;
            buffer = (buffer << 5) | value as u32;
            bits += 5;
            if bits >= 8 {
                bits -= 8;
                out.push((buffer >> bits) as u8);
            }
        }
        // Leftover bits are padding and must be zero, so each byte string has
        // exactly one encoding.
        if bits >= 5 || buffer & ((1 << bits) - 1) != 0 {
            return Err(malformed("pairing code has trailing bits"));
        }
        Ok(out)
    }

    #[cfg(test)]
    mod tests {
        use super::*;

        /// RFC 4648 §10, padding removed.
        #[test]
        fn matches_the_rfc_vectors() {
            let cases = [
                ("", ""),
                ("f", "MY"),
                ("fo", "MZXQ"),
                ("foo", "MZXW6"),
                ("foob", "MZXW6YQ"),
                ("fooba", "MZXW6YTB"),
                ("foobar", "MZXW6YTBOI"),
            ];
            for (plain, encoded) in cases {
                assert_eq!(encode(plain.as_bytes()), encoded);
                assert_eq!(decode(encoded).unwrap(), plain.as_bytes());
            }
        }

        #[test]
        fn decoding_ignores_case_but_not_stray_bits() {
            assert_eq!(decode("mzxw6").unwrap(), b"foo");
            assert!(
                decode("MZ").is_err(),
                "a lone byte's padding bits must be zero"
            );
            assert!(decode("M1").is_err());
        }
    }
}
