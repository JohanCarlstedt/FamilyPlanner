//! The recovery kit: crypto doc §7.3.
//!
//! Twelve words (BIP-39, 128 bits and a checksum) are everything. Argon2id
//! stretches them into a root; HKDF splits the root into a recovery device
//! identity, a lookup id and a note key. The identity is registered as a
//! device of the parent who made the kit, so it holds the family's keys like
//! any device and follows every rotation; whoever types the words can act as
//! it, and nobody else can.

use argon2::{Algorithm, Argon2, Params, Version};
use chacha20poly1305::aead::{Aead, KeyInit, Payload};
use chacha20poly1305::{XChaCha20Poly1305, XNonce};
use hkdf::Hkdf;
use sha2::Sha256;
use zeroize::Zeroizing;

use crate::device::DeviceIdentity;
use crate::envelope::{CryptoError, OsRandom, Random};

type Result<T> = std::result::Result<T, CryptoError>;

/// Argon2id: 32 MiB, 3 passes, one lane. About a second on a mid-range
/// phone; the words' 128 bits do the real work, the stretching is margin.
pub const ARGON2_MEMORY_KIB: u32 = 32 * 1024;
pub const ARGON2_PASSES: u32 = 3;
pub const ARGON2_LANES: u32 = 1;

/// Fixed: the words are random, so no two kits share a secret to salt apart,
/// and a new device has nothing else to salt with before it knows the family.
const ARGON2_SALT: &[u8] = b"fam.recovery.v1.argon2id";

const SIGNING_INFO: &[u8] = b"fam.recovery.sig.v1";
const KEM_INFO: &[u8] = b"fam.recovery.kem.v1";
const LOOKUP_INFO: &[u8] = b"fam.recovery.id.v1";
const NOTE_INFO: &[u8] = b"fam.recovery.note.v1";
const NOTE_AD: &[u8] = b"fam.recovery.note.v1";
const NONCE_LEN: usize = 24;

/// Twelve fresh words.
pub fn generate_words() -> String {
    let mut entropy = Zeroizing::new([0u8; 16]);
    OsRandom.fill(entropy.as_mut());
    words_for(entropy.as_ref())
}

pub(crate) fn words_for(entropy: &[u8]) -> String {
    bip39::Mnemonic::from_entropy(entropy)
        .expect("16 bytes is valid BIP-39 entropy")
        .words()
        .collect::<Vec<_>>()
        .join(" ")
}

/// What the words open.
pub struct RecoveryKit {
    root: Zeroizing<[u8; 32]>,
}

impl RecoveryKit {
    /// Reads twelve words, forgiving case and spacing, and stretches them.
    /// A word not in the list, or a checksum that doesn't hold (usually a
    /// mistyped word), is refused before any stretching.
    pub fn open(words: &str) -> Result<Self> {
        let normalized = words
            .split_whitespace()
            .map(str::to_lowercase)
            .collect::<Vec<_>>()
            .join(" ");
        let mnemonic = bip39::Mnemonic::parse_normalized(&normalized)
            .map_err(|e| CryptoError::Malformed(format!("recovery words: {e}")))?;
        let entropy = Zeroizing::new(mnemonic.to_entropy());
        if entropy.len() != 16 {
            return Err(CryptoError::Malformed(
                "recovery words: 12 are needed".into(),
            ));
        }
        Ok(RecoveryKit {
            root: Self::stretch(&entropy)?,
        })
    }

    fn stretch(entropy: &[u8]) -> Result<Zeroizing<[u8; 32]>> {
        let params = Params::new(ARGON2_MEMORY_KIB, ARGON2_PASSES, ARGON2_LANES, Some(32))
            .map_err(|e| CryptoError::Malformed(format!("argon2: {e}")))?;
        let mut root = Zeroizing::new([0u8; 32]);
        Argon2::new(Algorithm::Argon2id, Version::V0x13, params)
            .hash_password_into(entropy, ARGON2_SALT, root.as_mut())
            .map_err(|e| CryptoError::Malformed(format!("argon2: {e}")))?;
        Ok(root)
    }

    #[cfg(test)]
    pub(crate) fn from_root(root: [u8; 32]) -> Self {
        RecoveryKit {
            root: Zeroizing::new(root),
        }
    }

    #[cfg(test)]
    pub(crate) fn root(&self) -> [u8; 32] {
        *self.root
    }

    fn derive(&self, info: &[u8]) -> Zeroizing<[u8; 32]> {
        let mut out = Zeroizing::new([0u8; 32]);
        Hkdf::<Sha256>::new(None, self.root.as_ref())
            .expand(info, out.as_mut())
            .expect("32 bytes is a valid HKDF-SHA256 length");
        out
    }

    /// The recovery device: registered on the kit maker's member, holding the
    /// family's keys, and signing requests like any device.
    pub fn identity(&self) -> DeviceIdentity {
        DeviceIdentity::from_seeds(*self.derive(SIGNING_INFO), *self.derive(KEM_INFO))
    }

    /// Where the server keeps this kit: 16 bytes, hex. Unguessable, so the
    /// lookup can be anonymous.
    pub fn lookup_id(&self) -> String {
        self.derive(LOOKUP_INFO)[..16]
            .iter()
            .map(|b| format!("{b:02x}"))
            .collect()
    }

    /// Seals [plaintext] (the family and the devices to trust) so only the
    /// words open it: 24-byte nonce, then XChaCha20-Poly1305.
    pub fn seal_note(&self, plaintext: &[u8]) -> Result<Vec<u8>> {
        let mut nonce = [0u8; NONCE_LEN];
        OsRandom.fill(&mut nonce);
        self.seal_note_with(plaintext, nonce)
    }

    pub(crate) fn seal_note_with(
        &self,
        plaintext: &[u8],
        nonce: [u8; NONCE_LEN],
    ) -> Result<Vec<u8>> {
        let key = self.derive(NOTE_INFO);
        let key: &[u8; 32] = &key;
        let cipher = XChaCha20Poly1305::new(key.into());
        let ct = cipher
            .encrypt(
                &XNonce::try_from(&nonce[..]).expect("24 bytes"),
                Payload {
                    msg: plaintext,
                    aad: NOTE_AD,
                },
            )
            .map_err(|_| CryptoError::Malformed("note".into()))?;
        let mut out = nonce.to_vec();
        out.extend_from_slice(&ct);
        Ok(out)
    }

    pub fn open_note(&self, sealed: &[u8]) -> Result<Vec<u8>> {
        if sealed.len() < NONCE_LEN + 16 {
            return Err(CryptoError::Malformed("note too short".into()));
        }
        let (nonce, ct) = sealed.split_at(NONCE_LEN);
        let key = self.derive(NOTE_INFO);
        let key: &[u8; 32] = &key;
        XChaCha20Poly1305::new(key.into())
            .decrypt(
                &XNonce::try_from(nonce).expect("split at 24 bytes"),
                Payload {
                    msg: ct,
                    aad: NOTE_AD,
                },
            )
            .map_err(|_| CryptoError::Tampered)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// RFC 9106 §5.3: Argon2id with secret and associated data. Checks the
    /// crate is the Argon2id this design specifies.
    #[test]
    fn argon2id_matches_rfc9106() {
        let params = argon2::ParamsBuilder::new()
            .m_cost(32)
            .t_cost(3)
            .p_cost(4)
            .output_len(32)
            .data(argon2::AssociatedData::new(&[4u8; 12]).unwrap())
            .build()
            .unwrap();
        let mut tag = [0u8; 32];
        Argon2::new_with_secret(&[3u8; 8], Algorithm::Argon2id, Version::V0x13, params)
            .unwrap()
            .hash_password_into(&[1u8; 32], &[2u8; 16], &mut tag)
            .unwrap();
        assert_eq!(
            tag.iter().map(|b| format!("{b:02x}")).collect::<String>(),
            "0d640df58d78766c08c037a34a8b53c9d01ef0452d75b65eb52520e96b01e659"
        );
    }

    /// BIP-39's first published vector: sixteen zero bytes.
    #[test]
    fn words_match_bip39() {
        assert_eq!(
            words_for(&[0u8; 16]),
            "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        );
    }

    #[test]
    fn a_mistyped_word_is_caught() {
        // The last word carries the checksum: "abandon" there doesn't fit.
        assert!(RecoveryKit::open(&"abandon ".repeat(12)).is_err());
        assert!(RecoveryKit::open("abandon abandon notaword").is_err());
        assert!(RecoveryKit::open("one two three").is_err());
    }

    #[test]
    fn the_same_words_give_the_same_kit_forgiving_case_and_spacing() {
        let words = generate_words();
        let a = RecoveryKit::open(&words).unwrap();
        let b = RecoveryKit::open(&format!("  {}  ", words.to_uppercase().replace(' ', "   ")))
            .unwrap();
        assert_eq!(a.lookup_id(), b.lookup_id());
        assert_eq!(a.identity().public_keys(), b.identity().public_keys());
        assert_eq!(a.lookup_id().len(), 32);
    }

    #[test]
    fn only_the_words_open_the_note() {
        let kit = RecoveryKit::from_root([7u8; 32]);
        let sealed = kit.seal_note(b"fam-1").unwrap();
        assert_eq!(kit.open_note(&sealed).unwrap(), b"fam-1");
        assert!(
            RecoveryKit::from_root([8u8; 32])
                .open_note(&sealed)
                .is_err()
        );
        let mut tampered = sealed.clone();
        *tampered.last_mut().unwrap() ^= 1;
        assert!(kit.open_note(&tampered).is_err());
    }
}
