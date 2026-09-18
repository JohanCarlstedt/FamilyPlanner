//! Group key grants through the public API: crypto doc §3.1.

use ciborium::Value;
use family_crypto::{
    CryptoError, DeviceIdentity, GroupKey, Keyring, ObjectRef, TrustedDevice, accept,
    generate_group_key, grant, open, seal,
};

const FAMILY: &str = "fam-1";

struct Device {
    id: &'static str,
    identity: DeviceIdentity,
}

impl Device {
    fn new(id: &'static str) -> Self {
        Device {
            id,
            identity: DeviceIdentity::generate(),
        }
    }

    fn trusted(&self) -> TrustedDevice {
        TrustedDevice {
            device_id: self.id.into(),
            signing_key: self.identity.public_keys().signing,
        }
    }

    fn kem(&self) -> [u8; 32] {
        self.identity.public_keys().kem
    }

    /// Grants [key] from this device to [to].
    fn grant_to(&self, key: &GroupKey, to: &Device) -> Vec<u8> {
        grant(key, FAMILY, &self.identity, self.id, to.id, &to.kem()).unwrap()
    }

    fn accept(&self, grant: &[u8], trusted: &[&Device]) -> Result<GroupKey, CryptoError> {
        let trusted: Vec<_> = trusted.iter().map(|d| d.trusted()).collect();
        accept(grant, FAMILY, &self.identity, self.id, &trusted)
    }
}

/// Decodes a grant, lets [edit] change it, and re-encodes it.
fn edited(grant: &[u8], edit: impl FnOnce(&mut Vec<(Value, Value)>)) -> Vec<u8> {
    let Value::Map(mut entries) = ciborium::from_reader(grant).unwrap() else {
        panic!()
    };
    edit(&mut entries);
    let mut out = Vec::new();
    ciborium::into_writer(&Value::Map(entries), &mut out).unwrap();
    out
}

fn set(entries: &mut [(Value, Value)], key: &str, value: Value) {
    entries
        .iter_mut()
        .find(|(k, _)| k.as_text() == Some(key))
        .unwrap()
        .1 = value;
}

fn flip(entries: &mut [(Value, Value)], key: &str) {
    let field = &mut entries
        .iter_mut()
        .find(|(k, _)| k.as_text() == Some(key))
        .unwrap()
        .1;
    let Value::Bytes(bytes) = field else { panic!() };
    bytes[0] ^= 0x01;
}

mod delivery {
    use super::*;

    #[test]
    fn a_granted_key_opens_what_the_granter_sealed() {
        let parent = Device::new("parent-phone");
        let child = Device::new("child-tablet");
        let all = generate_group_key("all", 0);

        let received = child
            .accept(&parent.grant_to(&all, &child), &[&parent])
            .unwrap();
        assert_eq!((received.group.as_str(), received.epoch), ("all", 0));

        let object = ObjectRef {
            object_type: "event".into(),
            id: "e1".into(),
            family_id: FAMILY.into(),
        };
        let envelope = seal(b"Football", &object, &[all]).unwrap();
        let opened = open(&envelope, &Keyring::new(vec![received])).unwrap();
        assert_eq!(opened.payload, b"Football");
    }

    #[test]
    fn a_device_can_grant_to_itself_to_store_its_keys() {
        let phone = Device::new("phone");
        let adults = generate_group_key("adults", 2);

        let stored = phone.grant_to(&adults, &phone);
        let restored = phone.accept(&stored, &[&phone]).unwrap();

        assert_eq!(restored.key_bytes(), adults.key_bytes());
    }

    #[test]
    fn the_group_and_epoch_come_from_the_signed_grant() {
        let parent = Device::new("parent");
        let child = Device::new("child");
        let key = generate_group_key("adults+helper:h1", 7);

        let received = child
            .accept(&parent.grant_to(&key, &child), &[&parent])
            .unwrap();
        assert_eq!(
            (received.group.as_str(), received.epoch),
            ("adults+helper:h1", 7)
        );
    }

    #[test]
    fn inspect_reads_the_routing_header_without_keys() {
        let parent = Device::new("parent");
        let child = Device::new("child");
        let g = parent.grant_to(&generate_group_key("all", 3), &child);

        let header = family_crypto::grant::inspect(&g).unwrap();
        assert_eq!(header.to_device, "child");
        assert_eq!(header.from_device, "parent");
        assert_eq!((header.group.as_str(), header.epoch), ("all", 3));
    }
}

mod trust {
    use super::*;

    #[test]
    fn a_key_from_an_unknown_device_is_refused() {
        // The attack the signature exists for: the server registers a device
        // of its own and hands a real device a group key it chose.
        let server_made = Device::new("server-made");
        let child = Device::new("child");
        let parent = Device::new("parent");

        let planted = server_made.grant_to(&generate_group_key("all", 0), &child);
        assert_eq!(
            child.accept(&planted, &[&parent]).err(),
            Some(CryptoError::UntrustedSender)
        );
    }

    #[test]
    fn claiming_to_be_a_trusted_device_fails_the_signature() {
        let impostor = Device {
            id: "parent",
            identity: DeviceIdentity::generate(),
        };
        let parent = Device::new("parent");
        let child = Device::new("child");

        let forged = impostor.grant_to(&generate_group_key("all", 0), &child);
        assert_eq!(
            child.accept(&forged, &[&parent]).err(),
            Some(CryptoError::Tampered)
        );
    }

    #[test]
    fn a_grant_for_another_device_is_not_accepted() {
        let parent = Device::new("parent");
        let child = Device::new("child");
        let sibling = Device::new("sibling");

        let g = parent.grant_to(&generate_group_key("all", 0), &child);
        assert_eq!(
            sibling.accept(&g, &[&parent]).err(),
            Some(CryptoError::WrongRecipient)
        );
    }

    #[test]
    fn a_device_reusing_another_devices_id_still_cannot_open_its_grant() {
        let parent = Device::new("parent");
        let child = Device::new("child");
        let lookalike = Device {
            id: "child",
            identity: DeviceIdentity::generate(),
        };

        let g = parent.grant_to(&generate_group_key("all", 0), &child);
        assert_eq!(
            lookalike.accept(&g, &[&parent]).err(),
            Some(CryptoError::Tampered)
        );
    }

    #[test]
    fn a_grant_for_another_family_is_not_accepted() {
        let parent = Device::new("parent");
        let child = Device::new("child");
        let g = grant(
            &generate_group_key("all", 0),
            "fam-2",
            &parent.identity,
            parent.id,
            child.id,
            &child.kem(),
        )
        .unwrap();

        assert_eq!(
            child.accept(&g, &[&parent]).err(),
            Some(CryptoError::WrongRecipient)
        );
    }
}

mod tampering {
    use super::*;

    fn granted() -> (Device, Device, Vec<u8>) {
        let parent = Device::new("parent");
        let child = Device::new("child");
        let g = parent.grant_to(&generate_group_key("adults", 0), &child);
        (parent, child, g)
    }

    #[test]
    fn relabelling_the_group_fails() {
        // An `adults` grant must not be passed off as an `all` key, or vice versa.
        let (parent, child, g) = granted();
        let relabelled = edited(&g, |e| set(e, "g", Value::Text("all".into())));
        assert_eq!(
            child.accept(&relabelled, &[&parent]).err(),
            Some(CryptoError::Tampered)
        );
    }

    #[test]
    fn relabelling_the_epoch_fails() {
        let (parent, child, g) = granted();
        let relabelled = edited(&g, |e| set(e, "e", Value::Integer(5.into())));
        assert_eq!(
            child.accept(&relabelled, &[&parent]).err(),
            Some(CryptoError::Tampered)
        );
    }

    #[test]
    fn a_flipped_bit_anywhere_fails() {
        let (parent, child, g) = granted();
        for field in ["enc", "ct", "sig"] {
            let damaged = edited(&g, |e| flip(e, field));
            assert_eq!(
                child.accept(&damaged, &[&parent]).err(),
                Some(CryptoError::Tampered),
                "flipping {field}"
            );
        }
    }

    #[test]
    fn an_unknown_version_or_suite_is_refused() {
        let (parent, child, g) = granted();
        let v2 = edited(&g, |e| set(e, "v", Value::Integer(2.into())));
        assert_eq!(
            child.accept(&v2, &[&parent]).err(),
            Some(CryptoError::UnsupportedVersion(2))
        );

        let suite2 = edited(&g, |e| set(e, "suite", Value::Integer(2.into())));
        assert_eq!(
            child.accept(&suite2, &[&parent]).err(),
            Some(CryptoError::UnsupportedAlgorithm(2))
        );
    }

    #[test]
    fn rejects_unknown_fields() {
        let (parent, child, g) = granted();
        let extended = edited(&g, |e| {
            e.push((Value::Text("x".into()), Value::Integer(1.into())))
        });
        assert!(matches!(
            child.accept(&extended, &[&parent]),
            Err(CryptoError::Malformed(_))
        ));
    }
}

mod inputs {
    use super::*;

    #[test]
    fn refuses_a_low_order_kem_key() {
        let parent = Device::new("parent");
        let zero = [0u8; 32];
        let result = grant(
            &generate_group_key("all", 0),
            FAMILY,
            &parent.identity,
            "parent",
            "x",
            &zero,
        );
        assert!(matches!(result, Err(CryptoError::Malformed(_))));
    }

    #[test]
    fn refuses_empty_ids() {
        let parent = Device::new("parent");
        let child = Device::new("child");
        let result = grant(
            &generate_group_key("all", 0),
            FAMILY,
            &parent.identity,
            "",
            child.id,
            &child.kem(),
        );
        assert!(matches!(result, Err(CryptoError::Malformed(_))));
    }
}
