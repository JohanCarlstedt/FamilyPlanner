//! The object envelope: crypto design doc §4, byte-level rules in §4.1.
//!
//! Each object is encrypted once under a fresh random data key (DEK), and the
//! DEK is wrapped once per audience group that may read it. Changing who can
//! read an object is therefore a rewrap, never a re-encryption.

use chacha20poly1305::aead::{Aead, KeyInit, Payload};
use chacha20poly1305::{XChaCha20Poly1305, XNonce};
use ciborium::Value;
use hkdf::Hkdf;
use sha2::Sha256;
use zeroize::{Zeroize, ZeroizeOnDrop, Zeroizing};

use crate::cbor;

/// Envelope format version (`v`).
pub const VERSION: u64 = 1;

/// `alg` 1: XChaCha20-Poly1305. Decryption must support every value ever
/// written; encryption always uses the current one. Never remove a value.
pub const ALG_XCHACHA20POLY1305: u64 = 1;

const KEY_LEN: usize = 32;
const NONCE_LEN: usize = 24;
const TAG_LEN: usize = 16;
/// A wrap is its own nonce, the sealed DEK, and the tag.
const WRAP_LEN: usize = NONCE_LEN + KEY_LEN + TAG_LEN;

/// Domain separation strings. Changing any of these is a new format version.
const OBJECT_AD_LABEL: &str = "fam.obj";
const WRAP_AD_LABEL: &str = "fam.wrap";
const KEK_INFO: &[u8] = b"fam.kek.v1";

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CryptoError {
    /// Not a well-formed v1 envelope, or inputs that can't make one.
    Malformed(String),
    UnsupportedVersion(u64),
    UnsupportedAlgorithm(u64),
    /// This device holds no key for any audience the object is wrapped to.
    NoAccess,
    /// Authentication failed: the envelope was altered, moved to another
    /// object slot, or a key is wrong.
    Tampered,
}

impl std::fmt::Display for CryptoError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            CryptoError::Malformed(why) => write!(f, "malformed envelope: {why}"),
            CryptoError::UnsupportedVersion(v) => write!(f, "unsupported envelope version {v}"),
            CryptoError::UnsupportedAlgorithm(a) => write!(f, "unsupported algorithm {a}"),
            CryptoError::NoAccess => write!(f, "no key for any audience of this object"),
            CryptoError::Tampered => write!(f, "authentication failed"),
        }
    }
}

impl std::error::Error for CryptoError {}

type Result<T> = std::result::Result<T, CryptoError>;

/// The slot an object occupies: `aad` in the envelope. Bound to the ciphertext
/// so a valid envelope can't be moved to another object or family.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ObjectRef {
    /// Object type, e.g. `event`.
    pub object_type: String,
    pub id: String,
    pub family_id: String,
}

/// An audience group's content key (GCK) at one epoch.
#[derive(Clone, Zeroize, ZeroizeOnDrop)]
pub struct GroupKey {
    #[zeroize(skip)]
    pub group: String,
    #[zeroize(skip)]
    pub epoch: u64,
    key: [u8; KEY_LEN],
}

impl GroupKey {
    pub fn from_bytes(group: impl Into<String>, epoch: u64, key: [u8; KEY_LEN]) -> Self {
        GroupKey {
            group: group.into(),
            epoch,
            key,
        }
    }

    pub fn key_bytes(&self) -> &[u8; KEY_LEN] {
        &self.key
    }

    /// The wrapping key: HKDF-SHA256 of the GCK, so the GCK itself is never
    /// used directly as a cipher key and can serve other purposes later.
    fn kek(&self) -> Zeroizing<[u8; KEY_LEN]> {
        let mut out = Zeroizing::new([0u8; KEY_LEN]);
        Hkdf::<Sha256>::new(None, &self.key)
            .expand(KEK_INFO, out.as_mut())
            .expect("32 bytes is a valid HKDF-SHA256 output length");
        out
    }
}

impl std::fmt::Debug for GroupKey {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "GroupKey({}@{})", self.group, self.epoch)
    }
}

/// The group keys a device holds.
#[derive(Debug, Clone, Default)]
pub struct Keyring {
    keys: Vec<GroupKey>,
}

impl Keyring {
    pub fn new(keys: Vec<GroupKey>) -> Self {
        Keyring { keys }
    }

    /// Adds [key], replacing any key held for the same group and epoch.
    pub fn insert(&mut self, key: GroupKey) {
        self.keys
            .retain(|k| !(k.group == key.group && k.epoch == key.epoch));
        self.keys.push(key);
    }

    pub fn get(&self, group: &str, epoch: u64) -> Option<&GroupKey> {
        self.keys
            .iter()
            .find(|k| k.group == group && k.epoch == epoch)
    }
}

/// One audience entry: which group and epoch a DEK is wrapped to.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Wrap {
    pub group: String,
    pub epoch: u64,
}

/// What anyone can read without keys: routing metadata only.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Header {
    pub object: ObjectRef,
    pub audiences: Vec<Wrap>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Opened {
    pub payload: Vec<u8>,
    pub header: Header,
}

/// Generates a fresh random group content key.
pub fn generate_group_key(group: impl Into<String>, epoch: u64) -> GroupKey {
    let mut key = [0u8; KEY_LEN];
    OsRandom.fill(&mut key);
    GroupKey::from_bytes(group, epoch, key)
}

/// Encrypts [payload] for [object], readable by each of [audiences].
pub fn seal(payload: &[u8], object: &ObjectRef, audiences: &[GroupKey]) -> Result<Vec<u8>> {
    seal_with(&mut OsRandom, payload, object, audiences)
}

/// Decrypts with the first audience this device holds a key for.
pub fn open(envelope: &[u8], keyring: &Keyring) -> Result<Opened> {
    let parsed = Parsed::decode(envelope)?;
    let dek = parsed.unwrap_dek(keyring)?;
    let payload = cipher(&dek)
        .decrypt(
            &xnonce(&parsed.nonce),
            Payload {
                msg: &parsed.ciphertext,
                aad: &object_ad(&parsed.object),
            },
        )
        .map_err(|_| CryptoError::Tampered)?;
    Ok(Opened {
        payload,
        header: parsed.header(),
    })
}

/// Replaces the audience list without touching the ciphertext. The caller
/// must hold a key for one current audience (to recover the DEK) and for every
/// new one (to wrap to it).
pub fn rewrap(envelope: &[u8], keyring: &Keyring, audiences: &[GroupKey]) -> Result<Vec<u8>> {
    rewrap_with(&mut OsRandom, envelope, keyring, audiences)
}

/// Reads the routing metadata without decrypting anything.
pub fn inspect(envelope: &[u8]) -> Result<Header> {
    Ok(Parsed::decode(envelope)?.header())
}

// ---------------------------------------------------------------------------
// Randomness, injectable so test vectors are reproducible.

pub(crate) trait Random {
    fn fill(&mut self, buf: &mut [u8]);
}

struct OsRandom;

impl Random for OsRandom {
    fn fill(&mut self, buf: &mut [u8]) {
        getrandom::fill(buf).expect("the OS random source is unavailable");
    }
}

pub(crate) fn seal_with(
    rng: &mut impl Random,
    payload: &[u8],
    object: &ObjectRef,
    audiences: &[GroupKey],
) -> Result<Vec<u8>> {
    validate_object(object)?;
    validate_audiences(audiences)?;

    let mut dek = Zeroizing::new([0u8; KEY_LEN]);
    rng.fill(dek.as_mut());
    let mut nonce = [0u8; NONCE_LEN];
    rng.fill(&mut nonce);

    let ciphertext = cipher(&dek)
        .encrypt(
            &xnonce(&nonce),
            Payload {
                msg: payload,
                aad: &object_ad(object),
            },
        )
        .expect("XChaCha20-Poly1305 encryption cannot fail for in-memory input");

    let wraps = audiences
        .iter()
        .map(|key| wrap_dek(rng, &dek, key, object))
        .collect();

    Ok(Parsed {
        object: object.clone(),
        wraps,
        nonce,
        ciphertext,
    }
    .encode())
}

pub(crate) fn rewrap_with(
    rng: &mut impl Random,
    envelope: &[u8],
    keyring: &Keyring,
    audiences: &[GroupKey],
) -> Result<Vec<u8>> {
    validate_audiences(audiences)?;
    let parsed = Parsed::decode(envelope)?;
    let dek = parsed.unwrap_dek(keyring)?;

    // Confirm the DEK really opens this ciphertext before re-publishing it
    // under new wraps; a swapped ciphertext must not gain fresh audiences.
    cipher(&dek)
        .decrypt(
            &xnonce(&parsed.nonce),
            Payload {
                msg: &parsed.ciphertext,
                aad: &object_ad(&parsed.object),
            },
        )
        .map_err(|_| CryptoError::Tampered)?;

    let wraps = audiences
        .iter()
        .map(|key| wrap_dek(rng, &dek, key, &parsed.object))
        .collect();

    Ok(Parsed { wraps, ..parsed }.encode())
}

// ---------------------------------------------------------------------------
// Associated data. Both are deterministic CBOR arrays: a label, the format
// version and algorithm (so a downgrade fails authentication), then the slot.

fn object_ad(object: &ObjectRef) -> Vec<u8> {
    cbor::encode(&Value::Array(vec![
        Value::Text(OBJECT_AD_LABEL.into()),
        Value::Integer(VERSION.into()),
        Value::Integer(ALG_XCHACHA20POLY1305.into()),
        Value::Text(object.family_id.clone()),
        Value::Text(object.object_type.clone()),
        Value::Text(object.id.clone()),
    ]))
}

fn wrap_ad(group: &str, epoch: u64, object: &ObjectRef) -> Vec<u8> {
    cbor::encode(&Value::Array(vec![
        Value::Text(WRAP_AD_LABEL.into()),
        Value::Integer(VERSION.into()),
        Value::Integer(ALG_XCHACHA20POLY1305.into()),
        Value::Text(group.into()),
        Value::Integer(epoch.into()),
        Value::Text(object.family_id.clone()),
        Value::Text(object.object_type.clone()),
        Value::Text(object.id.clone()),
    ]))
}

fn xnonce(bytes: &[u8]) -> XNonce {
    XNonce::try_from(bytes).expect("nonces are length-checked on decode and generated at 24 bytes")
}

fn cipher(key: &[u8; KEY_LEN]) -> XChaCha20Poly1305 {
    XChaCha20Poly1305::new(key.into())
}

fn wrap_dek(
    rng: &mut impl Random,
    dek: &[u8; KEY_LEN],
    key: &GroupKey,
    object: &ObjectRef,
) -> (Wrap, Vec<u8>) {
    let mut nonce = [0u8; NONCE_LEN];
    rng.fill(&mut nonce);
    let sealed = cipher(&key.kek())
        .encrypt(
            &xnonce(&nonce),
            Payload {
                msg: dek,
                aad: &wrap_ad(&key.group, key.epoch, object),
            },
        )
        .expect("XChaCha20-Poly1305 encryption cannot fail for in-memory input");

    let mut w = Vec::with_capacity(WRAP_LEN);
    w.extend_from_slice(&nonce);
    w.extend_from_slice(&sealed);
    (
        Wrap {
            group: key.group.clone(),
            epoch: key.epoch,
        },
        w,
    )
}

fn validate_object(object: &ObjectRef) -> Result<()> {
    if object.object_type.is_empty() || object.id.is_empty() || object.family_id.is_empty() {
        return Err(CryptoError::Malformed(
            "object type, id and family must be non-empty".into(),
        ));
    }
    Ok(())
}

fn validate_audiences(audiences: &[GroupKey]) -> Result<()> {
    if audiences.is_empty() {
        return Err(CryptoError::Malformed(
            "at least one audience is required".into(),
        ));
    }
    for (i, key) in audiences.iter().enumerate() {
        if key.group.is_empty() {
            return Err(CryptoError::Malformed(
                "group name must be non-empty".into(),
            ));
        }
        if audiences[..i].iter().any(|k| k.group == key.group) {
            return Err(CryptoError::Malformed(format!(
                "group {} listed twice",
                key.group
            )));
        }
    }
    Ok(())
}

// ---------------------------------------------------------------------------
// Wire form.

struct Parsed {
    object: ObjectRef,
    wraps: Vec<(Wrap, Vec<u8>)>,
    nonce: [u8; NONCE_LEN],
    ciphertext: Vec<u8>,
}

impl Parsed {
    fn header(&self) -> Header {
        Header {
            object: self.object.clone(),
            audiences: self.wraps.iter().map(|(w, _)| w.clone()).collect(),
        }
    }

    fn unwrap_dek(&self, keyring: &Keyring) -> Result<Zeroizing<[u8; KEY_LEN]>> {
        let (wrap, w) = self
            .wraps
            .iter()
            .find(|(wrap, _)| keyring.get(&wrap.group, wrap.epoch).is_some())
            .ok_or(CryptoError::NoAccess)?;
        let key = keyring.get(&wrap.group, wrap.epoch).expect("found above");

        let (nonce, sealed) = w.split_at(NONCE_LEN);
        let dek = cipher(&key.kek())
            .decrypt(
                &xnonce(nonce),
                Payload {
                    msg: sealed,
                    aad: &wrap_ad(&wrap.group, wrap.epoch, &self.object),
                },
            )
            .map_err(|_| CryptoError::Tampered)?;

        let mut out = Zeroizing::new([0u8; KEY_LEN]);
        out.copy_from_slice(&dek);
        let mut dek = dek;
        dek.zeroize();
        Ok(out)
    }

    fn encode(&self) -> Vec<u8> {
        let text = |s: &str| Value::Text(s.into());
        let wraps = self
            .wraps
            .iter()
            .map(|(wrap, w)| {
                Value::Map(vec![
                    (text("g"), text(&wrap.group)),
                    (text("e"), Value::Integer(wrap.epoch.into())),
                    (text("w"), Value::Bytes(w.clone())),
                ])
            })
            .collect();

        cbor::encode(&Value::Map(vec![
            (text("v"), Value::Integer(VERSION.into())),
            (text("alg"), Value::Integer(ALG_XCHACHA20POLY1305.into())),
            (text("dek"), Value::Array(wraps)),
            (text("n"), Value::Bytes(self.nonce.to_vec())),
            (
                text("aad"),
                Value::Map(vec![
                    (text("t"), text(&self.object.object_type)),
                    (text("id"), text(&self.object.id)),
                    (text("fam"), text(&self.object.family_id)),
                ]),
            ),
            (text("ct"), Value::Bytes(self.ciphertext.clone())),
        ]))
    }

    fn decode(bytes: &[u8]) -> Result<Parsed> {
        let value = cbor::decode(bytes).map_err(CryptoError::Malformed)?;
        let top = Fields::of(&value, "envelope")?;

        // Version first: a later version may not share any other field.
        let version = top.uint("v")?;
        if version != VERSION {
            return Err(CryptoError::UnsupportedVersion(version));
        }
        let alg = top.uint("alg")?;
        if alg != ALG_XCHACHA20POLY1305 {
            return Err(CryptoError::UnsupportedAlgorithm(alg));
        }
        top.only(&["v", "alg", "dek", "n", "aad", "ct"])?;

        let aad = Fields::of(top.get("aad")?, "aad")?;
        aad.only(&["t", "id", "fam"])?;
        let object = ObjectRef {
            object_type: aad.text("t")?,
            id: aad.text("id")?,
            family_id: aad.text("fam")?,
        };
        validate_object(&object)?;

        let Value::Array(entries) = top.get("dek")? else {
            return Err(malformed("dek must be an array"));
        };
        if entries.is_empty() {
            return Err(malformed("dek must list at least one wrap"));
        }
        let mut wraps: Vec<(Wrap, Vec<u8>)> = Vec::with_capacity(entries.len());
        for entry in entries {
            let fields = Fields::of(entry, "wrap")?;
            fields.only(&["g", "e", "w"])?;
            let group = fields.text("g")?;
            if group.is_empty() {
                return Err(malformed("wrap group must be non-empty"));
            }
            if wraps.iter().any(|(w, _)| w.group == group) {
                return Err(malformed("a group is wrapped twice"));
            }
            let epoch = fields.uint("e")?;
            let w = fields.bytes("w", Some(WRAP_LEN))?;
            wraps.push((Wrap { group, epoch }, w));
        }

        let nonce: [u8; NONCE_LEN] = top
            .bytes("n", Some(NONCE_LEN))?
            .try_into()
            .expect("length checked");
        let ciphertext = top.bytes("ct", None)?;
        if ciphertext.len() < TAG_LEN {
            return Err(malformed("ciphertext shorter than its tag"));
        }

        Ok(Parsed {
            object,
            wraps,
            nonce,
            ciphertext,
        })
    }
}

fn malformed(why: &str) -> CryptoError {
    CryptoError::Malformed(why.into())
}

/// Typed access to a CBOR map with text keys.
struct Fields<'a> {
    what: &'static str,
    entries: &'a [(Value, Value)],
}

impl<'a> Fields<'a> {
    fn of(value: &'a Value, what: &'static str) -> Result<Self> {
        match value {
            Value::Map(entries) => Ok(Fields { what, entries }),
            _ => Err(CryptoError::Malformed(format!("{what} must be a map"))),
        }
    }

    fn get(&self, key: &str) -> Result<&'a Value> {
        let mut found = self
            .entries
            .iter()
            .filter(|(k, _)| k.as_text() == Some(key));
        let (_, value) = found
            .next()
            .ok_or_else(|| CryptoError::Malformed(format!("{} is missing {key}", self.what)))?;
        if found.next().is_some() {
            return Err(CryptoError::Malformed(format!(
                "{} repeats {key}",
                self.what
            )));
        }
        Ok(value)
    }

    /// Rejects keys outside [allowed]. v1 has no extension points; new fields
    /// mean a new version.
    fn only(&self, allowed: &[&str]) -> Result<()> {
        for (k, _) in self.entries {
            match k.as_text() {
                Some(name) if allowed.contains(&name) => {}
                _ => {
                    return Err(CryptoError::Malformed(format!(
                        "{} has an unexpected key",
                        self.what
                    )));
                }
            }
        }
        Ok(())
    }

    fn uint(&self, key: &str) -> Result<u64> {
        match self.get(key)? {
            Value::Integer(i) => u64::try_from(*i)
                .map_err(|_| CryptoError::Malformed(format!("{key} must be unsigned"))),
            _ => Err(CryptoError::Malformed(format!("{key} must be an integer"))),
        }
    }

    fn text(&self, key: &str) -> Result<String> {
        match self.get(key)? {
            Value::Text(s) => Ok(s.clone()),
            _ => Err(CryptoError::Malformed(format!("{key} must be text"))),
        }
    }

    fn bytes(&self, key: &str, len: Option<usize>) -> Result<Vec<u8>> {
        match self.get(key)? {
            Value::Bytes(b) if len.is_none_or(|l| b.len() == l) => Ok(b.clone()),
            Value::Bytes(_) => Err(CryptoError::Malformed(format!(
                "{key} has the wrong length"
            ))),
            _ => Err(CryptoError::Malformed(format!("{key} must be bytes"))),
        }
    }
}
