//! Adding a device by QR code through the public API: crypto doc §7.1.

use ciborium::Value;
use family_crypto::pairing::CODE_PREFIX;
use family_crypto::{
    CryptoError, DeviceIdentity, DeviceRecord, Keyring, ObjectRef, PairingSession, ScannedCode,
    accept, endorse, generate_group_key, grant, open, seal, verify_endorsement,
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

    fn record(&self) -> DeviceRecord {
        DeviceRecord::of(self.id, &self.identity)
    }
}

fn edited(bytes: &[u8], edit: impl FnOnce(&mut Vec<(Value, Value)>)) -> Vec<u8> {
    let Value::Map(mut entries) = ciborium::from_reader(bytes).unwrap() else {
        panic!()
    };
    edit(&mut entries);
    let mut out = Vec::new();
    ciborium::into_writer(&Value::Map(entries), &mut out).unwrap();
    out
}

fn field<'a>(entries: &'a mut [(Value, Value)], key: &str) -> &'a mut Value {
    &mut entries
        .iter_mut()
        .find(|(k, _)| k.as_text() == Some(key))
        .unwrap()
        .1
}

#[test]
fn a_new_tablet_joins_the_family() {
    let parent = Device::new("parent-phone");
    let tablet = Device::new("kitchen-tablet");
    let all = generate_group_key("all", 0);

    // The tablet shows a code; the parent scans it off the screen.
    let session = PairingSession::start(&tablet.identity, FAMILY, tablet.id).unwrap();
    let code = session.code();
    assert!(code.starts_with(CODE_PREFIX));
    let scanned = ScannedCode::parse(&code).unwrap();
    assert_eq!(
        scanned.device,
        tablet.record(),
        "the keys come from the screen"
    );
    assert_eq!(scanned.family_id, FAMILY);

    // The parent admits it and grants the family key.
    let admission = scanned.admit(parent.id, &[parent.record()]).unwrap();
    let g = grant(
        &all,
        FAMILY,
        &parent.identity,
        parent.id,
        tablet.id,
        &scanned.device.kem_key,
    )
    .unwrap();

    // The tablet learns whom to trust from the admission, then takes the key.
    let trusted = session.accept(&admission).unwrap();
    assert_eq!(trusted, [parent.record()]);
    let trusted: Vec<_> = trusted.iter().map(DeviceRecord::trusted).collect();
    let key = accept(&g, FAMILY, &tablet.identity, tablet.id, &trusted).unwrap();

    let object = ObjectRef {
        object_type: "event".into(),
        id: "e1".into(),
        family_id: FAMILY.into(),
    };
    let envelope = seal(b"Dinner 18:00", &object, &[all]).unwrap();
    assert_eq!(
        open(&envelope, &Keyring::new(vec![key])).unwrap().payload,
        b"Dinner 18:00"
    );
}

#[test]
fn the_rest_of_the_family_learns_the_new_device_from_the_endorsement() {
    let parent = Device::new("parent-phone");
    let other_parent = Device::new("other-phone");
    let tablet = Device::new("kitchen-tablet");

    let endorsement = endorse(&parent.identity, parent.id, FAMILY, &tablet.record()).unwrap();

    // The other parent's phone trusts the admitting phone already.
    let learned = verify_endorsement(&endorsement, FAMILY, &[parent.record().trusted()]).unwrap();
    assert_eq!(learned, tablet.record());

    // Now it can wrap future epochs to the tablet.
    let next = generate_group_key("all", 1);
    let g = grant(
        &next,
        FAMILY,
        &other_parent.identity,
        other_parent.id,
        tablet.id,
        &learned.kem_key,
    );
    assert!(g.is_ok());
}

#[test]
fn codes_survive_being_read_back_in_lowercase() {
    let tablet = Device::new("tablet");
    let session = PairingSession::start(&tablet.identity, FAMILY, tablet.id).unwrap();
    let code = session.code();
    let (prefix, body) = code.split_at(CODE_PREFIX.len());
    let lower = format!("{prefix}{}", body.to_lowercase());
    assert_eq!(ScannedCode::parse(&lower).unwrap().device, tablet.record());
}

mod admission_attacks {
    use super::*;

    fn paired() -> (Device, Device, PairingSession, Vec<u8>) {
        let parent = Device::new("parent");
        let tablet = Device::new("tablet");
        let session = PairingSession::start(&tablet.identity, FAMILY, tablet.id).unwrap();
        let admission = ScannedCode::parse(&session.code())
            .unwrap()
            .admit(parent.id, &[parent.record()])
            .unwrap();
        (parent, tablet, session, admission)
    }

    #[test]
    fn the_server_cannot_forge_an_admission() {
        // It knows every public key but never saw the code's secret.
        let (_, tablet, session, _) = paired();
        let server_made = Device::new("server-made");
        let impostor_session = PairingSession::start(&tablet.identity, FAMILY, tablet.id).unwrap();
        let forged = ScannedCode::parse(&impostor_session.code())
            .unwrap()
            .admit(server_made.id, &[server_made.record()])
            .unwrap();

        assert_eq!(session.accept(&forged).err(), Some(CryptoError::Tampered));
    }

    #[test]
    fn slipping_a_device_into_a_real_admission_fails() {
        let (_, _, session, admission) = paired();
        let server_made = Device::new("server-made");
        let Value::Map(entries) = ciborium::from_reader(admission.as_slice()).unwrap() else {
            panic!()
        };
        let mut devs = entries
            .iter()
            .find(|(k, _)| k.as_text() == Some("devs"))
            .unwrap()
            .1
            .clone();
        let Value::Array(list) = &mut devs else {
            panic!()
        };
        list.push(Value::Map(vec![
            (Value::Text("id".into()), Value::Text(server_made.id.into())),
            (
                Value::Text("sig".into()),
                Value::Bytes(server_made.record().signing_key.to_vec()),
            ),
            (
                Value::Text("kem".into()),
                Value::Bytes(server_made.record().kem_key.to_vec()),
            ),
        ]));
        let widened = edited(&admission, |e| *field(e, "devs") = devs);

        assert_eq!(session.accept(&widened).err(), Some(CryptoError::Tampered));
    }

    #[test]
    fn swapping_the_admitter_fails() {
        let (_, _, session, admission) = paired();
        let renamed = edited(&admission, |e| {
            *field(e, "from") = Value::Text("someone-else".into());
        });
        // Rejected before the tag: `from` must be one of the listed devices.
        assert!(matches!(
            session.accept(&renamed),
            Err(CryptoError::Malformed(_))
        ));
    }

    #[test]
    fn an_admission_for_another_device_or_family_is_refused() {
        let (_, _, session, admission) = paired();
        let other_device = edited(&admission, |e| *field(e, "to") = Value::Text("x".into()));
        assert_eq!(
            session.accept(&other_device).err(),
            Some(CryptoError::WrongRecipient)
        );

        let other_family = edited(&admission, |e| *field(e, "fam") = Value::Text("f2".into()));
        assert_eq!(
            session.accept(&other_family).err(),
            Some(CryptoError::WrongRecipient)
        );
    }

    #[test]
    fn an_admission_only_works_for_the_session_that_showed_the_code() {
        // A second attempt shows a new code with a new secret.
        let (_, tablet, _, admission) = paired();
        let retry = PairingSession::start(&tablet.identity, FAMILY, tablet.id).unwrap();
        assert_eq!(retry.accept(&admission).err(), Some(CryptoError::Tampered));
    }

    #[test]
    fn a_flipped_tag_bit_fails() {
        let (_, _, session, admission) = paired();
        let damaged = edited(&admission, |e| {
            let Value::Bytes(tag) = field(e, "tag") else {
                panic!()
            };
            tag[0] ^= 1;
        });
        assert_eq!(session.accept(&damaged).err(), Some(CryptoError::Tampered));
    }
}

mod endorsement_attacks {
    use super::*;

    #[test]
    fn an_endorsement_from_an_untrusted_device_is_refused() {
        let server_made = Device::new("server-made");
        let parent = Device::new("parent");
        let e = endorse(
            &server_made.identity,
            server_made.id,
            FAMILY,
            &Device::new("x").record(),
        )
        .unwrap();
        assert_eq!(
            verify_endorsement(&e, FAMILY, &[parent.record().trusted()]).err(),
            Some(CryptoError::UntrustedSender)
        );
    }

    #[test]
    fn swapping_the_endorsed_kem_key_fails() {
        // The server keeps the device id and signing key but substitutes a KEM
        // key it holds, hoping grants get sealed to it.
        let parent = Device::new("parent");
        let tablet = Device::new("tablet");
        let e = endorse(&parent.identity, parent.id, FAMILY, &tablet.record()).unwrap();
        let swapped = edited(&e, |entries| {
            let Value::Map(dev) = field(entries, "dev") else {
                panic!()
            };
            *field(dev, "kem") = Value::Bytes(Device::new("s").record().kem_key.to_vec());
        });
        assert_eq!(
            verify_endorsement(&swapped, FAMILY, &[parent.record().trusted()]).err(),
            Some(CryptoError::Tampered)
        );
    }

    #[test]
    fn an_endorsement_for_another_family_is_refused() {
        let parent = Device::new("parent");
        let e = endorse(
            &parent.identity,
            parent.id,
            "fam-2",
            &Device::new("x").record(),
        )
        .unwrap();
        assert_eq!(
            verify_endorsement(&e, FAMILY, &[parent.record().trusted()]).err(),
            Some(CryptoError::WrongRecipient)
        );
    }
}

mod codes {
    use super::*;

    #[test]
    fn rejects_text_that_is_not_a_pairing_code() {
        for text in ["", "https://example.com", "FAM2:MZXW6", "FAM1:not base32!"] {
            assert!(
                matches!(ScannedCode::parse(text), Err(CryptoError::Malformed(_))),
                "{text:?}"
            );
        }
    }

    #[test]
    fn a_damaged_code_does_not_parse_into_other_keys() {
        let tablet = Device::new("tablet");
        let session = PairingSession::start(&tablet.identity, FAMILY, tablet.id).unwrap();
        let mut code = session.code().to_string();
        code.truncate(code.len() - 3);
        assert!(ScannedCode::parse(&code).is_err());
    }
}
