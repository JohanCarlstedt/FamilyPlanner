//! Group key grants: crypto design doc §3, byte-level rules in §3.1.
//!
//! A grant carries one group content key (GCK) to one device, sealed to its
//! X25519 key with HPKE and signed by the granting device's Ed25519 key.
//!
//! The signature is what makes this safe. HPKE's base mode lets anyone seal to
//! a public key, so without it the server could hand a device a group key of
//! its own choosing and read everything that device later writes.

use ciborium::Value;
use ed25519_dalek::Signature;
use hpke::aead::ChaCha20Poly1305;
use hpke::kdf::HkdfSha256;
use hpke::kem::X25519HkdfSha256;
use hpke::rand_core::{TryCryptoRng, TryRng};
use hpke::{Deserializable, OpModeR, OpModeS, Serializable};
use zeroize::Zeroizing;

use crate::cbor::{self, Fields, malformed};
use crate::device::{self, DeviceIdentity};
use crate::envelope::{CryptoError, GroupKey, OsRandom, Random};

type Result<T> = std::result::Result<T, CryptoError>;
type Kem = X25519HkdfSha256;

/// Grant format version.
pub const GRANT_VERSION: u64 = 1;

/// `suite` 1: HPKE base mode with DHKEM(X25519, HKDF-SHA256) = 0x0020,
/// HKDF-SHA256 = 0x0001, ChaCha20-Poly1305 = 0x0003. Never reuse a value.
pub const SUITE_X25519_SHA256_CHACHA: u64 = 1;

const KEY_LEN: usize = 32;
const ENC_LEN: usize = 32;
const SEALED_LEN: usize = KEY_LEN + 16;
const SIG_LEN: usize = 64;

const INFO_LABEL: &str = "fam.grant";
const SIG_LABEL: &str = "fam.grant.sig";

/// A device this device already trusts, pinned at provisioning time.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TrustedDevice {
    pub device_id: String,
    pub signing_key: [u8; KEY_LEN],
}

/// Who a grant is from and for, and what it carries.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct GrantHeader {
    pub family_id: String,
    pub group: String,
    pub epoch: u64,
    pub to_device: String,
    pub from_device: String,
}

/// Seals [key] to the device [to_device], whose X25519 key is [to_kem_key],
/// signed by [granter] as [from_device].
pub fn grant(
    key: &GroupKey,
    family_id: &str,
    granter: &DeviceIdentity,
    from_device: &str,
    to_device: &str,
    to_kem_key: &[u8; KEY_LEN],
) -> Result<Vec<u8>> {
    grant_with(
        &mut OsRandom,
        key,
        family_id,
        granter,
        from_device,
        to_device,
        to_kem_key,
    )
}

pub(crate) fn grant_with(
    rng: &mut impl Random,
    key: &GroupKey,
    family_id: &str,
    granter: &DeviceIdentity,
    from_device: &str,
    to_device: &str,
    to_kem_key: &[u8; KEY_LEN],
) -> Result<Vec<u8>> {
    let header = GrantHeader {
        family_id: family_id.into(),
        group: key.group.clone(),
        epoch: key.epoch,
        to_device: to_device.into(),
        from_device: from_device.into(),
    };
    validate(&header)?;

    let recipient = <Kem as hpke::Kem>::PublicKey::from_bytes(to_kem_key)
        .map_err(|_| malformed("not an X25519 public key"))?;
    let (enc, sealed) = hpke::single_shot_seal_with_rng::<ChaCha20Poly1305, HkdfSha256, Kem>(
        &OpModeS::Base,
        &recipient,
        &info(&header),
        key.key_bytes(),
        &[],
        &mut HpkeRng(rng),
    )
    // Fails only for a low-order recipient key, whose shared secret is zero.
    .map_err(|_| malformed("unusable X25519 public key"))?;
    let enc: [u8; ENC_LEN] = enc.to_bytes().into();

    let signature = granter.sign(&signed_bytes(&header, &enc, &sealed));
    Ok(encode(&header, &enc, &sealed, &signature.to_bytes()))
}

/// Reads who a grant claims to be from and for, without verifying anything.
/// Use it for routing only; [accept] is the only trustworthy reading.
pub fn inspect(grant: &[u8]) -> Result<GrantHeader> {
    Ok(Parsed::decode(grant)?.header)
}

/// Verifies and opens a grant addressed to [me] as [my_device] in [family_id].
///
/// The group and epoch come from inside the signed grant, never from anything
/// the server stores alongside it.
pub fn accept(
    grant: &[u8],
    family_id: &str,
    me: &DeviceIdentity,
    my_device: &str,
    trusted: &[TrustedDevice],
) -> Result<GroupKey> {
    let parsed = Parsed::decode(grant)?;
    let header = &parsed.header;
    if header.family_id != family_id || header.to_device != my_device {
        return Err(CryptoError::WrongRecipient);
    }

    let sender = trusted
        .iter()
        .find(|t| t.device_id == header.from_device)
        .ok_or(CryptoError::UntrustedSender)?;
    let signature = Signature::from_bytes(&parsed.signature);
    device::verifying_key(&sender.signing_key)?
        .verify_strict(
            &signed_bytes(header, &parsed.enc, &parsed.sealed),
            &signature,
        )
        .map_err(|_| CryptoError::Tampered)?;

    let enc = <Kem as hpke::Kem>::EncappedKey::from_bytes(&parsed.enc)
        .map_err(|_| CryptoError::Tampered)?;
    let opened = Zeroizing::new(
        hpke::single_shot_open::<ChaCha20Poly1305, HkdfSha256, Kem>(
            &OpModeR::Base,
            &me.kem_private(),
            &enc,
            &info(header),
            &parsed.sealed,
            &[],
        )
        .map_err(|_| CryptoError::Tampered)?,
    );

    let mut key = [0u8; KEY_LEN];
    key.copy_from_slice(&opened);
    Ok(GroupKey::from_bytes(
        header.group.clone(),
        header.epoch,
        key,
    ))
}

// ---------------------------------------------------------------------------

/// HPKE `info`: binds the sealed key to family, group, epoch and both devices,
/// so a grant can't be replayed as another group's key or to another device.
fn info(h: &GrantHeader) -> Vec<u8> {
    cbor::encode(&Value::Array(vec![
        Value::Text(INFO_LABEL.into()),
        Value::Integer(GRANT_VERSION.into()),
        Value::Integer(SUITE_X25519_SHA256_CHACHA.into()),
        Value::Text(h.family_id.clone()),
        Value::Text(h.group.clone()),
        Value::Integer(h.epoch.into()),
        Value::Text(h.to_device.clone()),
        Value::Text(h.from_device.clone()),
    ]))
}

/// Everything in the grant except the signature itself.
fn signed_bytes(h: &GrantHeader, enc: &[u8], sealed: &[u8]) -> Vec<u8> {
    cbor::encode(&Value::Array(vec![
        Value::Text(SIG_LABEL.into()),
        Value::Integer(GRANT_VERSION.into()),
        Value::Integer(SUITE_X25519_SHA256_CHACHA.into()),
        Value::Text(h.family_id.clone()),
        Value::Text(h.group.clone()),
        Value::Integer(h.epoch.into()),
        Value::Text(h.to_device.clone()),
        Value::Text(h.from_device.clone()),
        Value::Bytes(enc.to_vec()),
        Value::Bytes(sealed.to_vec()),
    ]))
}

fn validate(h: &GrantHeader) -> Result<()> {
    if [&h.family_id, &h.group, &h.to_device, &h.from_device]
        .iter()
        .any(|s| s.is_empty())
    {
        return Err(malformed(
            "family, group and both devices must be non-empty",
        ));
    }
    Ok(())
}

fn encode(h: &GrantHeader, enc: &[u8], sealed: &[u8], signature: &[u8]) -> Vec<u8> {
    let text = |s: &str| Value::Text(s.into());
    cbor::encode(&Value::Map(vec![
        (text("v"), Value::Integer(GRANT_VERSION.into())),
        (
            text("suite"),
            Value::Integer(SUITE_X25519_SHA256_CHACHA.into()),
        ),
        (text("fam"), text(&h.family_id)),
        (text("g"), text(&h.group)),
        (text("e"), Value::Integer(h.epoch.into())),
        (text("to"), text(&h.to_device)),
        (text("from"), text(&h.from_device)),
        (text("enc"), Value::Bytes(enc.to_vec())),
        (text("ct"), Value::Bytes(sealed.to_vec())),
        (text("sig"), Value::Bytes(signature.to_vec())),
    ]))
}

struct Parsed {
    header: GrantHeader,
    enc: [u8; ENC_LEN],
    sealed: Vec<u8>,
    signature: [u8; SIG_LEN],
}

impl Parsed {
    fn decode(bytes: &[u8]) -> Result<Parsed> {
        let value = cbor::decode(bytes).map_err(CryptoError::Malformed)?;
        let fields = Fields::of(&value, "grant")?;

        let version = fields.uint("v")?;
        if version != GRANT_VERSION {
            return Err(CryptoError::UnsupportedVersion(version));
        }
        let suite = fields.uint("suite")?;
        if suite != SUITE_X25519_SHA256_CHACHA {
            return Err(CryptoError::UnsupportedAlgorithm(suite));
        }
        fields.only(&[
            "v", "suite", "fam", "g", "e", "to", "from", "enc", "ct", "sig",
        ])?;

        let header = GrantHeader {
            family_id: fields.text("fam")?,
            group: fields.text("g")?,
            epoch: fields.uint("e")?,
            to_device: fields.text("to")?,
            from_device: fields.text("from")?,
        };
        validate(&header)?;

        Ok(Parsed {
            header,
            enc: fields
                .bytes("enc", Some(ENC_LEN))?
                .try_into()
                .expect("length checked"),
            sealed: fields.bytes("ct", Some(SEALED_LEN))?,
            signature: fields
                .bytes("sig", Some(SIG_LEN))?
                .try_into()
                .expect("length checked"),
        })
    }
}

/// Adapts this crate's random source to the RNG trait HPKE expects, so test
/// vectors can fix HPKE's ephemeral key too.
struct HpkeRng<'a, R: Random>(&'a mut R);

impl<R: Random> TryRng for HpkeRng<'_, R> {
    type Error = std::convert::Infallible;

    fn try_next_u32(&mut self) -> std::result::Result<u32, Self::Error> {
        let mut b = [0u8; 4];
        self.0.fill(&mut b);
        Ok(u32::from_le_bytes(b))
    }

    fn try_next_u64(&mut self) -> std::result::Result<u64, Self::Error> {
        let mut b = [0u8; 8];
        self.0.fill(&mut b);
        Ok(u64::from_le_bytes(b))
    }

    fn try_fill_bytes(&mut self, dst: &mut [u8]) -> std::result::Result<(), Self::Error> {
        self.0.fill(dst);
        Ok(())
    }
}

impl<R: Random> TryCryptoRng for HpkeRng<'_, R> {}
