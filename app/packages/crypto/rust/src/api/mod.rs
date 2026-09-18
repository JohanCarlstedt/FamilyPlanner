//! The surface Dart sees, generated into `lib/src/rust` by flutter_rust_bridge.
//!
//! Key material stays on this side. Dart holds an opaque [Device] and an
//! opaque [Keyring] and names group keys by group and epoch. Group key bytes
//! never cross the bridge: a keyring is persisted as the grants that built it
//! (each sealed to this device), and only the device secret needs storing,
//! encrypted under a hardware-backed key (crypto doc §2.1).

use flutter_rust_bridge::frb;

use crate::device::DeviceIdentity;
use crate::envelope::{self, CryptoError, GroupKey};
use crate::grant;
use crate::pairing;

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

/// A device this device already trusts: pinned at provisioning time after the
/// out-of-band comparison, never taken on the server's word alone.
pub struct TrustedDevice {
    pub device_id: String,
    pub signing_key: Vec<u8>,
}

/// A device as the family knows it: its id and both 32-byte public keys.
#[derive(Clone)]
pub struct DeviceRecord {
    pub device_id: String,
    pub signing_key: Vec<u8>,
    pub kem_key: Vec<u8>,
}

/// Who a grant claims to be from and for. Unverified: routing only.
pub struct GrantInfo {
    pub family_id: String,
    pub group: String,
    pub epoch: u32,
    pub to_device: String,
    pub from_device: String,
}

/// Why a crypto operation failed. A plain enum keeps the Dart side free of
/// code generation; the detail is in [CryptoException::message].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CryptoErrorKind {
    Malformed,
    UnsupportedVersion,
    UnsupportedAlgorithm,
    /// This device holds no key for any audience of the object.
    NoAccess,
    /// Altered, moved, or opened with a wrong key or signature.
    Tampered,
    /// The keyring lacks a key the caller asked it to use.
    MissingKey,
    /// A grant signed by a device this device doesn't trust.
    UntrustedSender,
    /// A grant addressed to another device or family.
    WrongRecipient,
}

#[derive(Debug)]
pub struct CryptoException {
    pub kind: CryptoErrorKind,
    pub message: String,
}

impl CryptoException {
    fn new(kind: CryptoErrorKind, message: impl Into<String>) -> Self {
        CryptoException {
            kind,
            message: message.into(),
        }
    }

    fn malformed(message: impl Into<String>) -> Self {
        CryptoException::new(CryptoErrorKind::Malformed, message)
    }
}

impl From<CryptoError> for CryptoException {
    fn from(error: CryptoError) -> Self {
        let kind = match error {
            CryptoError::Malformed(_) => CryptoErrorKind::Malformed,
            CryptoError::UnsupportedVersion(_) => CryptoErrorKind::UnsupportedVersion,
            CryptoError::UnsupportedAlgorithm(_) => CryptoErrorKind::UnsupportedAlgorithm,
            CryptoError::NoAccess => CryptoErrorKind::NoAccess,
            CryptoError::Tampered => CryptoErrorKind::Tampered,
            CryptoError::UntrustedSender => CryptoErrorKind::UntrustedSender,
            CryptoError::WrongRecipient => CryptoErrorKind::WrongRecipient,
        };
        CryptoException::new(kind, error.to_string())
    }
}

// ---------------------------------------------------------------------------
// Device

/// This device's identity: an Ed25519 key that authenticates it and an X25519
/// key that group keys are sealed to.
#[frb(opaque)]
pub struct Device {
    inner: DeviceIdentity,
}

impl Device {
    /// A new identity, generated on first run.
    #[frb(sync)]
    pub fn generate() -> Device {
        Device {
            inner: DeviceIdentity::generate(),
        }
    }

    /// Restores an identity from [Device::export_secret]'s output.
    #[frb(sync)]
    pub fn restore(secret: Vec<u8>) -> Result<Device, CryptoException> {
        Ok(Device {
            inner: DeviceIdentity::from_secret_bytes(&secret)?,
        })
    }

    /// The private keys, for storage encrypted under a hardware-backed key.
    /// Never send this anywhere.
    #[frb(sync)]
    pub fn export_secret(&self) -> Vec<u8> {
        self.inner.to_secret_bytes().to_vec()
    }

    /// Ed25519 public key (32 bytes), published as the directory's signing key.
    #[frb(sync, getter)]
    pub fn signing_public_key(&self) -> Vec<u8> {
        self.inner.public_keys().signing.to_vec()
    }

    /// X25519 public key (32 bytes), published as the directory's KEM key.
    #[frb(sync, getter)]
    pub fn kem_public_key(&self) -> Vec<u8> {
        self.inner.public_keys().kem.to_vec()
    }

    /// This device's public record, registered as [device_id].
    #[frb(sync)]
    pub fn record(&self, device_id: String) -> DeviceRecord {
        pairing::DeviceRecord::of(device_id, &self.inner).into()
    }
}

// ---------------------------------------------------------------------------
// Keyring

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
    /// Persist it by granting it to this device itself (see [Keyring::grant]).
    #[frb(sync)]
    pub fn generate(&mut self, group: String, epoch: u32) {
        self.inner
            .insert(envelope::generate_group_key(group, epoch.into()));
    }

    #[frb(sync)]
    pub fn contains(&self, group: String, epoch: u32) -> bool {
        self.inner.get(&group, epoch.into()).is_some()
    }

    /// Seals the held key for [group] at [epoch] to another device (or to this
    /// one, for storage), signed by [granter] as [from_device].
    #[frb(sync)]
    #[allow(clippy::too_many_arguments)]
    pub fn grant(
        &self,
        group: String,
        epoch: u32,
        family_id: String,
        granter: &Device,
        from_device: String,
        to_device: String,
        to_kem_key: Vec<u8>,
    ) -> Result<Vec<u8>, CryptoException> {
        let key = self.key(&group, epoch)?;
        let to_kem_key: [u8; 32] = to_kem_key
            .try_into()
            .map_err(|_| CryptoException::malformed("KEM public keys are 32 bytes"))?;
        Ok(grant::grant(
            key,
            &family_id,
            &granter.inner,
            &from_device,
            &to_device,
            &to_kem_key,
        )?)
    }

    /// Verifies a grant addressed to [me] as [my_device] and adds its key.
    /// The group and epoch come from inside the signed grant, never from
    /// anything the server stores alongside it.
    #[frb(sync)]
    pub fn accept_grant(
        &mut self,
        grant: Vec<u8>,
        family_id: String,
        me: &Device,
        my_device: String,
        trusted: Vec<TrustedDevice>,
    ) -> Result<Audience, CryptoException> {
        let trusted = trusted_devices(trusted)?;
        let key = grant::accept(&grant, &family_id, &me.inner, &my_device, &trusted)?;
        let audience = Audience {
            group: key.group.clone(),
            epoch: epoch_u32(key.epoch)?,
        };
        self.inner.insert(key);
        Ok(audience)
    }

    fn key(&self, group: &str, epoch: u32) -> Result<&GroupKey, CryptoException> {
        self.inner.get(group, epoch.into()).ok_or_else(|| {
            CryptoException::new(
                CryptoErrorKind::MissingKey,
                format!("no key for {group} at epoch {epoch}"),
            )
        })
    }

    fn audience_keys(&self, audiences: &[Audience]) -> Result<Vec<GroupKey>, CryptoException> {
        audiences
            .iter()
            .map(|a| self.key(&a.group, a.epoch).cloned())
            .collect()
    }
}

/// Who a grant claims to be from and for, without verifying it.
#[frb(sync)]
pub fn inspect_grant(grant: Vec<u8>) -> Result<GrantInfo, CryptoException> {
    let h = grant::inspect(&grant)?;
    Ok(GrantInfo {
        family_id: h.family_id,
        group: h.group,
        epoch: epoch_u32(h.epoch)?,
        to_device: h.to_device,
        from_device: h.from_device,
    })
}

// ---------------------------------------------------------------------------
// Pairing by QR code (crypto doc §7.1)

/// What a new device learns from its admission.
pub struct Admitted {
    pub family_id: String,
    pub member_id: String,
    pub device_id: String,
    pub trusted: Vec<DeviceRecord>,
}

/// The new device's side: show [PairingSession::code] as a QR code, poll the
/// server at [PairingSession::mailbox], then accept the admission found there.
/// Single use; drop it when the pairing screen closes.
#[frb(opaque)]
pub struct PairingSession {
    inner: pairing::PairingSession,
}

impl PairingSession {
    #[frb(sync)]
    pub fn start(device: &Device) -> PairingSession {
        PairingSession {
            inner: pairing::PairingSession::start(&device.inner),
        }
    }

    /// The text to render as a QR code. It holds a secret: show it on screen,
    /// never send or log it.
    #[frb(sync, getter)]
    pub fn code(&self) -> String {
        self.inner.code().to_string()
    }

    /// Where the admission will arrive. Safe to send to the server.
    #[frb(sync, getter)]
    pub fn mailbox(&self) -> String {
        self.inner.mailbox()
    }

    /// Verifies the admission and returns where this device now belongs.
    #[frb(sync)]
    pub fn accept(&self, admission: Vec<u8>) -> Result<Admitted, CryptoException> {
        let a = self.inner.accept(&admission)?;
        Ok(Admitted {
            family_id: a.family_id,
            member_id: a.member_id,
            device_id: a.device_id,
            trusted: a.trusted.into_iter().map(Into::into).collect(),
        })
    }
}

/// The admitting device's side: a pairing code read by the camera.
#[frb(opaque)]
pub struct ScannedCode {
    inner: pairing::ScannedCode,
}

impl ScannedCode {
    #[frb(sync)]
    pub fn parse(code: String) -> Result<ScannedCode, CryptoException> {
        Ok(ScannedCode {
            inner: pairing::ScannedCode::parse(&code)?,
        })
    }

    /// The new device's Ed25519 key, as shown on its screen. Register the
    /// device with these keys, not any the server offers.
    #[frb(sync, getter)]
    pub fn signing_key(&self) -> Vec<u8> {
        self.inner.signing_key.to_vec()
    }

    /// The new device's X25519 key, as shown on its screen.
    #[frb(sync, getter)]
    pub fn kem_key(&self) -> Vec<u8> {
        self.inner.kem_key.to_vec()
    }

    /// Where the new device is waiting for its admission.
    #[frb(sync, getter)]
    pub fn mailbox(&self) -> String {
        self.inner.mailbox()
    }

    /// The new device's record under the id it was registered with.
    #[frb(sync)]
    pub fn record(&self, device_id: String) -> DeviceRecord {
        self.inner.record(&device_id).into()
    }

    /// The admission for the new device: [family_id], as [member_id], registered
    /// as [device_id], trusting [family_devices] with [from_device] (this
    /// device) among them.
    #[frb(sync)]
    pub fn admit(
        &self,
        family_id: String,
        member_id: String,
        device_id: String,
        from_device: String,
        family_devices: Vec<DeviceRecord>,
    ) -> Result<Vec<u8>, CryptoException> {
        let devices = family_devices
            .into_iter()
            .map(TryInto::try_into)
            .collect::<Result<Vec<pairing::DeviceRecord>, CryptoException>>()?;
        Ok(self
            .inner
            .admit(&family_id, &member_id, &device_id, &from_device, &devices)?)
    }
}

/// Vouches for [device] to the rest of the family, signed by [endorser].
#[frb(sync)]
pub fn endorse(
    endorser: &Device,
    endorser_id: String,
    family_id: String,
    device: DeviceRecord,
) -> Result<Vec<u8>, CryptoException> {
    Ok(pairing::endorse(
        &endorser.inner,
        &endorser_id,
        &family_id,
        &device.try_into()?,
    )?)
}

/// The device an endorsement from a trusted device vouches for.
#[frb(sync)]
pub fn verify_endorsement(
    endorsement: Vec<u8>,
    family_id: String,
    trusted: Vec<TrustedDevice>,
) -> Result<DeviceRecord, CryptoException> {
    let trusted = trusted_devices(trusted)?;
    Ok(pairing::verify_endorsement(&endorsement, &family_id, &trusted)?.into())
}

impl From<pairing::DeviceRecord> for DeviceRecord {
    fn from(r: pairing::DeviceRecord) -> Self {
        DeviceRecord {
            device_id: r.device_id,
            signing_key: r.signing_key.to_vec(),
            kem_key: r.kem_key.to_vec(),
        }
    }
}

impl TryFrom<DeviceRecord> for pairing::DeviceRecord {
    type Error = CryptoException;

    fn try_from(r: DeviceRecord) -> Result<Self, CryptoException> {
        Ok(pairing::DeviceRecord {
            device_id: r.device_id,
            signing_key: key32(r.signing_key, "signing keys are 32 bytes")?,
            kem_key: key32(r.kem_key, "KEM public keys are 32 bytes")?,
        })
    }
}

fn key32(bytes: Vec<u8>, why: &str) -> Result<[u8; 32], CryptoException> {
    bytes
        .try_into()
        .map_err(|_| CryptoException::malformed(why))
}

fn trusted_devices(
    trusted: Vec<TrustedDevice>,
) -> Result<Vec<grant::TrustedDevice>, CryptoException> {
    trusted
        .into_iter()
        .map(|t| {
            Ok(grant::TrustedDevice {
                device_id: t.device_id,
                signing_key: key32(t.signing_key, "signing keys are 32 bytes")?,
            })
        })
        .collect()
}

// ---------------------------------------------------------------------------
// Envelopes

/// Encrypts [payload] into [object]'s slot, readable by each of [audiences].
#[frb(sync)]
pub fn seal(
    payload: Vec<u8>,
    object: ObjectSlot,
    audiences: Vec<Audience>,
    keyring: &Keyring,
) -> Result<Vec<u8>, CryptoException> {
    let keys = keyring.audience_keys(&audiences)?;
    Ok(envelope::seal(&payload, &object.into(), &keys)?)
}

#[frb(sync)]
pub fn open(envelope: Vec<u8>, keyring: &Keyring) -> Result<OpenedEnvelope, CryptoException> {
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
) -> Result<Vec<u8>, CryptoException> {
    let keys = keyring.audience_keys(&audiences)?;
    Ok(envelope::rewrap(&envelope, &keyring.inner, &keys)?)
}

/// Routing metadata, readable without keys.
#[frb(sync)]
pub fn inspect(envelope: Vec<u8>) -> Result<EnvelopeHeader, CryptoException> {
    envelope::inspect(&envelope)?.try_into()
}

fn epoch_u32(epoch: u64) -> Result<u32, CryptoException> {
    u32::try_from(epoch).map_err(|_| {
        CryptoException::malformed(format!("epoch {epoch} is beyond this client's range"))
    })
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
    type Error = CryptoException;

    fn try_from(header: envelope::Header) -> Result<Self, CryptoException> {
        let audiences = header
            .audiences
            .into_iter()
            .map(|w| {
                Ok(Audience {
                    group: w.group,
                    epoch: epoch_u32(w.epoch)?,
                })
            })
            .collect::<Result<_, CryptoException>>()?;
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
