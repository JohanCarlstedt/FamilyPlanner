//! The family app's cryptographic core. All cryptography lives here
//! (architecture doc §4); Dart only ever sees the functions in `api`.
//!
//! Implemented: the object envelope (crypto doc §4), device identity (§2) and
//! signed HPKE group key grants (§3). Recovery and MLS come later.

pub mod api;
mod cbor;
pub mod device;
pub mod envelope;
mod frb_generated;
pub mod grant;
#[cfg(test)]
mod vectors;

pub use device::{DeviceIdentity, DevicePublicKeys};
pub use envelope::{
    CryptoError, GroupKey, Header, Keyring, ObjectRef, Opened, Wrap, generate_group_key, inspect,
    open, rewrap, seal,
};
pub use grant::{GrantHeader, TrustedDevice, accept, grant};
