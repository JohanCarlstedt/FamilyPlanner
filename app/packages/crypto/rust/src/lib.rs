//! The family app's cryptographic core. All cryptography lives here
//! (architecture doc §4); Dart only ever sees the functions in `api`.
//!
//! This slice implements the object envelope of crypto design doc §4. Device
//! identity, HPKE key distribution, recovery and MLS come later.

pub mod api;
mod cbor;
pub mod envelope;
mod frb_generated;
#[cfg(test)]
mod vectors;

pub use envelope::{
    CryptoError, GroupKey, Header, Keyring, ObjectRef, Opened, Wrap, generate_group_key, inspect,
    open, rewrap, seal,
};
