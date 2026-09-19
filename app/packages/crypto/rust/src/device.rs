//! Device identity: crypto design doc §2, byte-level rules in §2.1.
//!
//! Each device holds an Ed25519 key that authenticates it and an X25519 key
//! that group keys are sealed to. Neither private key ever leaves the device;
//! the secret form below exists only so the platform layer can store it
//! encrypted under a hardware-backed key.

use ciborium::Value;
use ed25519_dalek::{Signature, Signer, SigningKey, VerifyingKey};
use hpke::kem::{Kem as _, X25519HkdfSha256};
use hpke::{Deserializable, Serializable};
use zeroize::{Zeroize, ZeroizeOnDrop, Zeroizing};

use crate::cbor::{self, Fields};
use crate::envelope::{CryptoError, OsRandom, Random};

type Result<T> = std::result::Result<T, CryptoError>;

/// Version of the stored secret form. Independent of the envelope's `v`.
const SECRET_VERSION: u64 = 1;
const KEY_LEN: usize = 32;

#[derive(Zeroize, ZeroizeOnDrop)]
pub struct DeviceIdentity {
    signing_seed: [u8; KEY_LEN],
    kem_secret: [u8; KEY_LEN],
}

/// A device's public half, as published to the key directory.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DevicePublicKeys {
    pub signing: [u8; KEY_LEN],
    pub kem: [u8; KEY_LEN],
}

impl DeviceIdentity {
    pub fn generate() -> Self {
        Self::generate_with(&mut OsRandom)
    }

    pub(crate) fn generate_with(rng: &mut impl Random) -> Self {
        let mut signing_seed = [0u8; KEY_LEN];
        rng.fill(&mut signing_seed);
        // X25519 clamps its scalar, so any 32 random bytes are a valid key.
        let mut kem_secret = [0u8; KEY_LEN];
        rng.fill(&mut kem_secret);
        DeviceIdentity {
            signing_seed,
            kem_secret,
        }
    }

    /// An identity from seeds derived elsewhere: the recovery kit's (§7.3).
    pub(crate) fn from_seeds(signing_seed: [u8; KEY_LEN], kem_secret: [u8; KEY_LEN]) -> Self {
        DeviceIdentity {
            signing_seed,
            kem_secret,
        }
    }

    pub fn public_keys(&self) -> DevicePublicKeys {
        DevicePublicKeys {
            signing: self.signing_key().verifying_key().to_bytes(),
            kem: self.kem_public().to_bytes().into(),
        }
    }

    /// CBOR `{v: 1, s: seed, k: kem secret}`, for encrypted local storage only.
    pub fn to_secret_bytes(&self) -> Zeroizing<Vec<u8>> {
        let text = |s: &str| Value::Text(s.into());
        Zeroizing::new(cbor::encode(&Value::Map(vec![
            (text("v"), Value::Integer(SECRET_VERSION.into())),
            (text("s"), Value::Bytes(self.signing_seed.to_vec())),
            (text("k"), Value::Bytes(self.kem_secret.to_vec())),
        ])))
    }

    pub fn from_secret_bytes(bytes: &[u8]) -> Result<Self> {
        let value = cbor::decode(bytes).map_err(CryptoError::Malformed)?;
        let fields = Fields::of(&value, "device secret")?;
        let version = fields.uint("v")?;
        if version != SECRET_VERSION {
            return Err(CryptoError::UnsupportedVersion(version));
        }
        fields.only(&["v", "s", "k"])?;
        let mut identity = DeviceIdentity {
            signing_seed: [0; KEY_LEN],
            kem_secret: [0; KEY_LEN],
        };
        identity
            .signing_seed
            .copy_from_slice(&Zeroizing::new(fields.bytes("s", Some(KEY_LEN))?));
        identity
            .kem_secret
            .copy_from_slice(&Zeroizing::new(fields.bytes("k", Some(KEY_LEN))?));
        Ok(identity)
    }

    pub(crate) fn sign(&self, message: &[u8]) -> Signature {
        self.signing_key().sign(message)
    }

    pub(crate) fn kem_private(&self) -> <X25519HkdfSha256 as hpke::Kem>::PrivateKey {
        <X25519HkdfSha256 as hpke::Kem>::PrivateKey::from_bytes(&self.kem_secret)
            .expect("any 32 bytes are an X25519 private key")
    }

    fn signing_key(&self) -> SigningKey {
        SigningKey::from_bytes(&self.signing_seed)
    }

    fn kem_public(&self) -> <X25519HkdfSha256 as hpke::Kem>::PublicKey {
        X25519HkdfSha256::sk_to_pk(&self.kem_private())
    }
}

impl std::fmt::Debug for DeviceIdentity {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "DeviceIdentity({:02x?}…)",
            &self.public_keys().signing[..4]
        )
    }
}

/// Parses a published Ed25519 key, refusing weak and non-canonical points.
pub(crate) fn verifying_key(bytes: &[u8; KEY_LEN]) -> Result<VerifyingKey> {
    let key = VerifyingKey::from_bytes(bytes)
        .map_err(|_| CryptoError::Malformed("not an Ed25519 public key".into()))?;
    if key.is_weak() {
        return Err(CryptoError::Malformed("weak Ed25519 public key".into()));
    }
    Ok(key)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_secret_form_round_trips_to_the_same_public_keys() {
        let identity = DeviceIdentity::generate();
        let restored = DeviceIdentity::from_secret_bytes(&identity.to_secret_bytes()).unwrap();
        assert_eq!(restored.public_keys(), identity.public_keys());
    }

    #[test]
    fn two_devices_never_share_keys() {
        let a = DeviceIdentity::generate().public_keys();
        let b = DeviceIdentity::generate().public_keys();
        assert_ne!(a.signing, b.signing);
        assert_ne!(a.kem, b.kem);
    }

    #[test]
    fn rejects_a_truncated_secret() {
        let identity = DeviceIdentity::generate();
        let bytes = identity.to_secret_bytes();
        assert!(DeviceIdentity::from_secret_bytes(&bytes[..bytes.len() - 1]).is_err());
    }

    #[test]
    fn rejects_the_identity_point_as_a_signing_key() {
        let mut identity_point = [0u8; KEY_LEN];
        identity_point[0] = 1;
        assert!(verifying_key(&identity_point).is_err());
    }
}
