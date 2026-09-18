//! The surface Dart sees, generated into `lib/src/rust` by flutter_rust_bridge.
//!
//! Key material stays on this side: Dart holds an opaque [Keyring] and names
//! keys by group and epoch. Raw key bytes cross only through
//! [Keyring::export_key] and [Keyring::import_key], which exist for persisting
//! keys to platform secure storage until device keys and HPKE take over.

use flutter_rust_bridge::frb;

use crate::envelope::{self, CryptoError, GroupKey};

/// Where an object lives: bound into its envelope so it can't be moved.
pub struct ObjectSlot {
    pub object_type: String,
    pub id: String,
    pub family_id: String,
}

/// An audience group at one epoch.
pub struct Audience {
    pub group: String,
    pub epoch: u32,
}

pub struct EnvelopeHeader {
    pub object: ObjectSlot,
    pub audiences: Vec<Audience>,
}

pub struct OpenedEnvelope {
    pub payload: Vec<u8>,
    pub header: EnvelopeHeader,
}

/// Why an envelope operation failed. A plain enum keeps the Dart side free of
/// code generation; the detail is in [EnvelopeError::message].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EnvelopeErrorKind {
    Malformed,
    UnsupportedVersion,
    UnsupportedAlgorithm,
    /// This device holds no key for any audience of the object.
    NoAccess,
    /// Altered, moved to another object, or opened with a wrong key.
    Tampered,
    /// The keyring lacks a key the caller asked it to use.
    MissingKey,
}

#[derive(Debug)]
pub struct EnvelopeError {
    pub kind: EnvelopeErrorKind,
    pub message: String,
}

impl EnvelopeError {
    fn new(kind: EnvelopeErrorKind, message: impl Into<String>) -> Self {
        EnvelopeError {
            kind,
            message: message.into(),
        }
    }
}

impl From<CryptoError> for EnvelopeError {
    fn from(error: CryptoError) -> Self {
        let kind = match error {
            CryptoError::Malformed(_) => EnvelopeErrorKind::Malformed,
            CryptoError::UnsupportedVersion(_) => EnvelopeErrorKind::UnsupportedVersion,
            CryptoError::UnsupportedAlgorithm(_) => EnvelopeErrorKind::UnsupportedAlgorithm,
            CryptoError::NoAccess => EnvelopeErrorKind::NoAccess,
            CryptoError::Tampered => EnvelopeErrorKind::Tampered,
            // Grants are not bridged yet; only grant::accept can produce these.
            CryptoError::UntrustedSender | CryptoError::WrongRecipient => {
                unreachable!("grants are not exposed through this API")
            }
        };
        EnvelopeError::new(kind, error.to_string())
    }
}

/// The group content keys this device holds.
#[frb(opaque)]
pub struct Keyring {
    inner: envelope::Keyring,
}

impl Keyring {
    #[frb(sync)]
    pub fn new() -> Keyring {
        Keyring {
            inner: envelope::Keyring::default(),
        }
    }

    /// Creates a fresh random key for [group] at [epoch], replacing any held.
    #[frb(sync)]
    pub fn generate(&mut self, group: String, epoch: u32) {
        self.inner
            .insert(envelope::generate_group_key(group, epoch.into()));
    }

    #[frb(sync)]
    pub fn contains(&self, group: String, epoch: u32) -> bool {
        self.inner.get(&group, epoch.into()).is_some()
    }

    /// The raw key, for writing to platform secure storage.
    #[frb(sync)]
    pub fn export_key(&self, group: String, epoch: u32) -> Result<Vec<u8>, EnvelopeError> {
        Ok(self.key(&group, epoch)?.key_bytes().to_vec())
    }

    /// Restores a key read back from platform secure storage.
    #[frb(sync)]
    pub fn import_key(
        &mut self,
        group: String,
        epoch: u32,
        key: Vec<u8>,
    ) -> Result<(), EnvelopeError> {
        let bytes: [u8; 32] = key.try_into().map_err(|_| {
            EnvelopeError::new(EnvelopeErrorKind::Malformed, "group keys are 32 bytes")
        })?;
        self.inner
            .insert(GroupKey::from_bytes(group, epoch.into(), bytes));
        Ok(())
    }

    fn key(&self, group: &str, epoch: u32) -> Result<&GroupKey, EnvelopeError> {
        self.inner.get(group, epoch.into()).ok_or_else(|| {
            EnvelopeError::new(
                EnvelopeErrorKind::MissingKey,
                format!("no key for {group} at epoch {epoch}"),
            )
        })
    }

    fn audience_keys(&self, audiences: &[Audience]) -> Result<Vec<GroupKey>, EnvelopeError> {
        audiences
            .iter()
            .map(|a| self.key(&a.group, a.epoch).cloned())
            .collect()
    }
}

/// Encrypts [payload] into [object]'s slot, readable by each of [audiences].
#[frb(sync)]
pub fn seal(
    payload: Vec<u8>,
    object: ObjectSlot,
    audiences: Vec<Audience>,
    keyring: &Keyring,
) -> Result<Vec<u8>, EnvelopeError> {
    let keys = keyring.audience_keys(&audiences)?;
    Ok(envelope::seal(&payload, &object.into(), &keys)?)
}

#[frb(sync)]
pub fn open(envelope: Vec<u8>, keyring: &Keyring) -> Result<OpenedEnvelope, EnvelopeError> {
    let opened = envelope::open(&envelope, &keyring.inner)?;
    Ok(OpenedEnvelope {
        payload: opened.payload,
        header: opened.header.try_into()?,
    })
}

/// Replaces who can read an object without re-encrypting it.
#[frb(sync)]
pub fn rewrap(
    envelope: Vec<u8>,
    audiences: Vec<Audience>,
    keyring: &Keyring,
) -> Result<Vec<u8>, EnvelopeError> {
    let keys = keyring.audience_keys(&audiences)?;
    Ok(envelope::rewrap(&envelope, &keyring.inner, &keys)?)
}

/// Routing metadata, readable without keys.
#[frb(sync)]
pub fn inspect(envelope: Vec<u8>) -> Result<EnvelopeHeader, EnvelopeError> {
    envelope::inspect(&envelope)?.try_into()
}

impl From<ObjectSlot> for envelope::ObjectRef {
    fn from(slot: ObjectSlot) -> Self {
        envelope::ObjectRef {
            object_type: slot.object_type,
            id: slot.id,
            family_id: slot.family_id,
        }
    }
}

impl TryFrom<envelope::Header> for EnvelopeHeader {
    type Error = EnvelopeError;

    fn try_from(header: envelope::Header) -> Result<Self, EnvelopeError> {
        let audiences = header
            .audiences
            .into_iter()
            .map(|w| {
                let epoch = u32::try_from(w.epoch).map_err(|_| {
                    EnvelopeError::new(
                        EnvelopeErrorKind::Malformed,
                        format!("epoch {} is beyond this client's range", w.epoch),
                    )
                })?;
                Ok(Audience {
                    group: w.group,
                    epoch,
                })
            })
            .collect::<Result<_, EnvelopeError>>()?;
        Ok(EnvelopeHeader {
            object: ObjectSlot {
                object_type: header.object.object_type,
                id: header.object.id,
                family_id: header.object.family_id,
            },
            audiences,
        })
    }
}

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}
