//! Chat groups over MLS (RFC 9420) with OpenMLS: crypto doc §7.2.
//!
//! Every device is one MLS member. Its MLS signature key *is* its device
//! signing key (§2.1): MLS signs with its own labels ("MLS 1.0 ..."), so the
//! key never signs anything another format could mistake for its own, and
//! a member's credential can be checked against the device record pinned at
//! pairing, rather than trusted because the server delivered it.
//!
//! Group state lives in OpenMLS's memory storage, exported whole as bytes for
//! the platform to keep encrypted at rest.

use openmls::prelude::tls_codec::{Deserialize as _, Serialize as _};
use openmls::prelude::*;
use openmls_memory_storage::MemoryStorage;
use openmls_rust_crypto::RustCrypto;
use openmls_traits::OpenMlsProvider;
use openmls_traits::signatures::{Signer, SignerError};
use openmls_traits::types::SignatureScheme;

use crate::device::DeviceIdentity;
use crate::envelope::CryptoError;

type Result<T> = std::result::Result<T, CryptoError>;

/// Leads every exported state, so a stray blob is refused, not misread.
const STATE_MAGIC: &[u8] = b"fam.mls.state.v1";

/// X25519, ChaCha20-Poly1305, SHA-256, Ed25519: the primitives the rest of
/// the core already uses.
pub const CIPHERSUITE: Ciphersuite =
    Ciphersuite::MLS_128_DHKEMX25519_CHACHA20POLY1305_SHA256_Ed25519;

/// A device another device already trusts, as far as chat is concerned: its
/// id and pinned signing key.
#[derive(Debug, Clone)]
pub struct MlsPeer {
    pub device_id: String,
    pub signing_key: [u8; 32],
}

/// What processing one message from the delivery service produced.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Incoming {
    /// A chat message: who sent it (device id) and its bytes.
    Application { sender: String, content: Vec<u8> },
    /// A membership change, merged: the group's new epoch.
    Commit { epoch: u64 },
    /// This device's own message, echoed back: nothing to do.
    Own,
}

/// A commit that adds or removes members, not yet merged: merge it once the
/// delivery service accepts it, discard it if another commit got there first.
pub struct PendingCommit {
    pub commit: Vec<u8>,
    /// For each added device, the welcome that lets it join.
    pub welcome: Option<Vec<u8>>,
}

struct Provider {
    crypto: RustCrypto,
    storage: MemoryStorage,
}

impl OpenMlsProvider for Provider {
    type CryptoProvider = RustCrypto;
    type RandProvider = RustCrypto;
    type StorageProvider = MemoryStorage;

    fn storage(&self) -> &Self::StorageProvider {
        &self.storage
    }

    fn crypto(&self) -> &Self::CryptoProvider {
        &self.crypto
    }

    fn rand(&self) -> &Self::RandProvider {
        &self.crypto
    }
}

/// The device key as an OpenMLS signer, so the private key never leaves the
/// device identity.
struct DeviceSigner<'a>(&'a DeviceIdentity);

impl Signer for DeviceSigner<'_> {
    fn sign(&self, payload: &[u8]) -> std::result::Result<Vec<u8>, SignerError> {
        Ok(self.0.sign(payload).to_bytes().to_vec())
    }

    fn signature_scheme(&self) -> SignatureScheme {
        SignatureScheme::ED25519
    }
}

/// One device's MLS state: every group it's in and its unused key packages.
pub struct MlsState {
    provider: Provider,
}

impl Default for MlsState {
    fn default() -> Self {
        Self::new()
    }
}

impl MlsState {
    pub fn new() -> Self {
        MlsState {
            provider: Provider {
                crypto: RustCrypto::default(),
                storage: MemoryStorage::default(),
            },
        }
    }

    /// Restores state from [MlsState::export].
    pub fn restore(bytes: &[u8]) -> Result<Self> {
        let malformed = || CryptoError::Malformed("mls state".into());
        let mut rest = bytes;
        let mut take = |n: usize| -> Result<&[u8]> {
            if rest.len() < n {
                return Err(malformed());
            }
            let (head, tail) = rest.split_at(n);
            rest = tail;
            Ok(head)
        };
        let header = take(STATE_MAGIC.len())?;
        if header != STATE_MAGIC {
            return Err(malformed());
        }
        let count = u64::from_be_bytes(take(8)?.try_into().map_err(|_| malformed())?);
        let mut values = std::collections::HashMap::new();
        for _ in 0..count {
            let k_len = u64::from_be_bytes(take(8)?.try_into().map_err(|_| malformed())?);
            let v_len = u64::from_be_bytes(take(8)?.try_into().map_err(|_| malformed())?);
            let k = take(usize::try_from(k_len).map_err(|_| malformed())?)?.to_vec();
            let v = take(usize::try_from(v_len).map_err(|_| malformed())?)?.to_vec();
            values.insert(k, v);
        }
        if !rest.is_empty() {
            return Err(malformed());
        }
        let storage = MemoryStorage::default();
        *storage.values.write().map_err(|_| malformed())? = values;
        Ok(MlsState {
            provider: Provider {
                crypto: RustCrypto::default(),
                storage,
            },
        })
    }

    /// Everything, for storage encrypted at rest. Holds private keys.
    /// `fam.mls.state.v1`, then a count and length-prefixed key/value pairs
    /// in key order, so the same state always exports the same bytes.
    pub fn export(&self) -> Result<Vec<u8>> {
        let values = self
            .provider
            .storage
            .values
            .read()
            .map_err(|_| CryptoError::Malformed("mls state".into()))?;
        let mut entries: Vec<_> = values.iter().collect();
        entries.sort();
        let mut out = STATE_MAGIC.to_vec();
        out.extend_from_slice(&(entries.len() as u64).to_be_bytes());
        for (k, v) in entries {
            out.extend_from_slice(&(k.len() as u64).to_be_bytes());
            out.extend_from_slice(&(v.len() as u64).to_be_bytes());
            out.extend_from_slice(k);
            out.extend_from_slice(v);
        }
        Ok(out)
    }

    fn credential(device: &DeviceIdentity, device_id: &str) -> CredentialWithKey {
        CredentialWithKey {
            credential: BasicCredential::new(device_id.as_bytes().to_vec()).into(),
            signature_key: device.public_keys().signing.to_vec().into(),
        }
    }

    /// Fresh key packages others can use to add this device to a group. The
    /// private halves stay in this state.
    pub fn key_packages(
        &mut self,
        device: &DeviceIdentity,
        device_id: &str,
        count: usize,
    ) -> Result<Vec<Vec<u8>>> {
        let signer = DeviceSigner(device);
        (0..count)
            .map(|_| {
                let bundle = KeyPackage::builder()
                    .build(
                        CIPHERSUITE,
                        &self.provider,
                        &signer,
                        Self::credential(device, device_id),
                    )
                    .map_err(|e| CryptoError::Malformed(format!("key package: {e}")))?;
                bundle
                    .key_package()
                    .tls_serialize_detached()
                    .map_err(|e| CryptoError::Malformed(format!("key package: {e}")))
            })
            .collect()
    }

    /// Starts a group with this device as its only member.
    pub fn create_group(
        &mut self,
        device: &DeviceIdentity,
        device_id: &str,
        group_id: &[u8],
    ) -> Result<()> {
        let config = MlsGroupCreateConfig::builder()
            .ciphersuite(CIPHERSUITE)
            .use_ratchet_tree_extension(true)
            .build();
        MlsGroup::new_with_group_id(
            &self.provider,
            &DeviceSigner(device),
            &config,
            GroupId::from_slice(group_id),
            Self::credential(device, device_id),
        )
        .map_err(|e| CryptoError::Malformed(format!("create group: {e}")))?;
        Ok(())
    }

    fn group(&self, group_id: &[u8]) -> Result<MlsGroup> {
        MlsGroup::load(&self.provider.storage, &GroupId::from_slice(group_id))
            .map_err(|e| CryptoError::Malformed(format!("load group: {e}")))?
            .ok_or_else(|| CryptoError::Malformed("no such group".into()))
    }

    /// Drops a group this device made but lost the race to register: another
    /// device's group with the same id won, and this one waits to be welcomed
    /// into that instead.
    pub fn forget_group(&mut self, group_id: &[u8]) -> Result<()> {
        let mut group = self.group(group_id)?;
        group
            .delete(self.provider.storage())
            .map_err(|e| CryptoError::Malformed(format!("forget group: {e}")))
    }

    pub fn has_group(&self, group_id: &[u8]) -> bool {
        self.group(group_id).is_ok()
    }

    pub fn epoch(&self, group_id: &[u8]) -> Result<u64> {
        Ok(self.group(group_id)?.epoch().as_u64())
    }

    /// Device ids of every member, this device included.
    pub fn members(&self, group_id: &[u8]) -> Result<Vec<String>> {
        Ok(self
            .group(group_id)?
            .members()
            .filter_map(|m| device_id_of(&m.credential))
            .collect())
    }

    /// Adds devices by their key packages. Each key package must name a
    /// device in [trusted] and carry that device's pinned signing key: the
    /// server hands key packages out, so it must not be able to slip its own
    /// in. Returns the commit to send; merge it once the delivery service
    /// accepts it.
    pub fn add_members(
        &mut self,
        device: &DeviceIdentity,
        group_id: &[u8],
        key_packages: &[Vec<u8>],
        trusted: &[MlsPeer],
    ) -> Result<PendingCommit> {
        let mut validated = Vec::new();
        for bytes in key_packages {
            let key_package = KeyPackageIn::tls_deserialize(&mut bytes.as_slice())
                .map_err(|e| CryptoError::Malformed(format!("key package: {e}")))?
                .validate(self.provider.crypto(), ProtocolVersion::Mls10)
                .map_err(|_| CryptoError::Tampered)?;
            let leaf = key_package.leaf_node();
            check_trusted(leaf.credential(), leaf.signature_key().as_slice(), trusted)?;
            validated.push(key_package);
        }
        let mut group = self.group(group_id)?;
        let (commit, welcome, _) = group
            .add_members(&self.provider, &DeviceSigner(device), &validated)
            .map_err(|e| CryptoError::Malformed(format!("add members: {e}")))?;
        Ok(PendingCommit {
            commit: serialize(&commit)?,
            welcome: Some(serialize(&welcome)?),
        })
    }

    /// Removes devices, e.g. a revoked one. Returns the commit to send.
    pub fn remove_members(
        &mut self,
        device: &DeviceIdentity,
        group_id: &[u8],
        device_ids: &[String],
    ) -> Result<PendingCommit> {
        let mut group = self.group(group_id)?;
        let leaves: Vec<LeafNodeIndex> = group
            .members()
            .filter(|m| device_id_of(&m.credential).is_some_and(|id| device_ids.contains(&id)))
            .map(|m| m.index)
            .collect();
        if leaves.is_empty() {
            return Err(CryptoError::Malformed("none of them is a member".into()));
        }
        let (commit, welcome, _) = group
            .remove_members(&self.provider, &DeviceSigner(device), &leaves)
            .map_err(|e| CryptoError::Malformed(format!("remove members: {e}")))?;
        Ok(PendingCommit {
            commit: serialize(&commit)?,
            welcome: welcome.map(|w| serialize(&w)).transpose()?,
        })
    }

    /// The delivery service accepted this device's commit.
    pub fn merge_pending(&mut self, group_id: &[u8]) -> Result<u64> {
        let mut group = self.group(group_id)?;
        group
            .merge_pending_commit(&self.provider)
            .map_err(|e| CryptoError::Malformed(format!("merge: {e}")))?;
        Ok(group.epoch().as_u64())
    }

    /// Another commit got there first: drop this device's.
    pub fn discard_pending(&mut self, group_id: &[u8]) -> Result<()> {
        let mut group = self.group(group_id)?;
        group
            .clear_pending_commit(self.provider.storage())
            .map_err(|e| CryptoError::Malformed(format!("discard: {e}")))
    }

    /// Joins a group from a welcome addressed to this device. Every existing
    /// member must be a trusted device, so a welcome can't draw this device
    /// into a group with a stranger listening. Returns the group id.
    pub fn join(&mut self, welcome: &[u8], trusted: &[MlsPeer]) -> Result<Vec<u8>> {
        let message = MlsMessageIn::tls_deserialize(&mut &welcome[..])
            .map_err(|e| CryptoError::Malformed(format!("welcome: {e}")))?;
        let MlsMessageBodyIn::Welcome(welcome) = message.extract() else {
            return Err(CryptoError::Malformed("not a welcome".into()));
        };
        let config = MlsGroupJoinConfig::builder()
            .use_ratchet_tree_extension(true)
            .build();
        let staged = StagedWelcome::new_from_welcome(&self.provider, &config, welcome, None)
            .map_err(|e| CryptoError::Malformed(format!("welcome: {e}")))?;
        for member in staged.members() {
            check_trusted(&member.credential, &member.signature_key, trusted)?;
        }
        let group = staged
            .into_group(&self.provider)
            .map_err(|e| CryptoError::Malformed(format!("join: {e}")))?;
        Ok(group.group_id().as_slice().to_vec())
    }

    /// Encrypts a chat message to everyone in the group.
    pub fn encrypt(
        &mut self,
        device: &DeviceIdentity,
        group_id: &[u8],
        content: &[u8],
    ) -> Result<Vec<u8>> {
        let mut group = self.group(group_id)?;
        let message = group
            .create_message(&self.provider, &DeviceSigner(device), content)
            .map_err(|e| CryptoError::Malformed(format!("encrypt: {e}")))?;
        serialize(&message)
    }

    /// Processes one message from the delivery service, in its order. A
    /// commit that adds anyone but a trusted device is refused, not merged.
    pub fn process(
        &mut self,
        group_id: &[u8],
        message: &[u8],
        trusted: &[MlsPeer],
    ) -> Result<Incoming> {
        let message = MlsMessageIn::tls_deserialize(&mut &message[..])
            .map_err(|e| CryptoError::Malformed(format!("message: {e}")))?;
        let protocol = message
            .try_into_protocol_message()
            .map_err(|_| CryptoError::Malformed("not a group message".into()))?;
        let mut group = self.group(group_id)?;
        let processed = group
            .process_message(&self.provider, protocol)
            .map_err(|e| match e {
                ProcessMessageError::ValidationError(ValidationError::WrongEpoch) => {
                    CryptoError::Malformed("wrong epoch".into())
                }
                _ => CryptoError::Tampered,
            })?;
        let sender = device_id_of(processed.credential());
        match processed.into_content() {
            ProcessedMessageContent::ApplicationMessage(app) => Ok(Incoming::Application {
                sender: sender.ok_or(CryptoError::UntrustedSender)?,
                content: app.into_bytes(),
            }),
            ProcessedMessageContent::StagedCommitMessage(staged) => {
                for add in staged.add_proposals() {
                    let leaf = add.add_proposal().key_package().leaf_node();
                    check_trusted(leaf.credential(), leaf.signature_key().as_slice(), trusted)?;
                }
                group
                    .merge_staged_commit(&self.provider, *staged)
                    .map_err(|e| CryptoError::Malformed(format!("merge: {e}")))?;
                Ok(Incoming::Commit {
                    epoch: group.epoch().as_u64(),
                })
            }
            ProcessedMessageContent::OwnPrivateMessage => Ok(Incoming::Own),
            // Standalone proposals and external joins aren't used here.
            _ => Err(CryptoError::Malformed("unexpected message kind".into())),
        }
    }
}

fn serialize(message: &MlsMessageOut) -> Result<Vec<u8>> {
    message
        .tls_serialize_detached()
        .map_err(|e| CryptoError::Malformed(format!("serialize: {e}")))
}

fn device_id_of(credential: &Credential) -> Option<String> {
    let basic = BasicCredential::try_from(credential.clone()).ok()?;
    String::from_utf8(basic.identity().to_vec()).ok()
}

/// A member is the device its credential names, with that device's pinned
/// signing key; anything else is someone the server introduced.
fn check_trusted(credential: &Credential, signing_key: &[u8], trusted: &[MlsPeer]) -> Result<()> {
    let id = device_id_of(credential).ok_or(CryptoError::UntrustedSender)?;
    let known = trusted
        .iter()
        .any(|t| t.device_id == id && t.signing_key.as_slice() == signing_key);
    if known {
        Ok(())
    } else {
        Err(CryptoError::UntrustedSender)
    }
}
