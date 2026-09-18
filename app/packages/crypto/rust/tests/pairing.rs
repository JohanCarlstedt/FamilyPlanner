//! Adding a device by QR code through the public API: crypto doc §7.1.

use ciborium::Value;
use family_crypto::pairing::CODE_PREFIX;
use family_crypto::{
    CryptoError, DeviceIdentity, DeviceRecord, Keyring, ObjectRef, PairingSession, ScannedCode,
    accept, endorse, generate_group_key, grant, open, seal, verify_endorsement,
};

const FAMILY: &str = "fam-1";
const MEMBER: &str = "member-maja";

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
    let tablet = DeviceIdentity::generate();
    let all = generate_group_key("all", 0);

    // The tablet belongs to nothing yet: it shows only its keys and a secret.
    let session = PairingSession::start(&tablet);
    let code = session.code();
    assert!(code.starts_with(CODE_PREFIX));

    // The parent scans it, registers it (the server assigns an id), and admits it.
    let scanned = ScannedCode::parse(&code).unwrap();
    assert_eq!(
        scanned.signing_key,
        tablet.public_keys().signing,
        "keys from the screen"
    );
    assert_eq!(scanned.kem_key, tablet.public_keys().kem);
    assert_eq!(
        scanned.mailbox(),
        session.mailbox(),
        "both sides find the same mailbox"
    );
    let tablet_id = "dev-tablet";
    let admission = scanned
        .admit(FAMILY, MEMBER, tablet_id, parent.id, &[parent.record()])
        .unwrap();
    let g = grant(
        &all,
        FAMILY,
        &parent.identity,
        parent.id,
        tablet_id,
        &scanned.kem_key,
    )
    .unwrap();

    // The tablet learns where it belongs and whom to trust, then takes the key.
    let admitted = session.accept(&admission).unwrap();
    assert_eq!(admitted.family_id, FAMILY);
    assert_eq!(admitted.member_id, MEMBER);
    assert_eq!(admitted.device_id, tablet_id);
    assert_eq!(admitted.trusted, [parent.record()]);

    let trusted: Vec<_> = admitted.trusted.iter().map(DeviceRecord::trusted).collect();
    let key = accept(&g, FAMILY, &tablet, tablet_id, &trusted).unwrap();
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
    let learned = verify_endorsement(&endorsement, FAMILY, &[parent.record().trusted()]).unwrap();
    assert_eq!(learned, tablet.record());

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
fn mailboxes_are_unrelated_between_sessions_and_look_like_addresses() {
    let tablet = DeviceIdentity::generate();
    let a = PairingSession::start(&tablet).mailbox();
    let b = PairingSession::start(&tablet).mailbox();
    assert_ne!(a, b);
    assert_eq!(a.len(), 32);
    assert!(
        a.chars()
            .all(|c| c.is_ascii_hexdigit() && !c.is_ascii_uppercase())
    );
}

#[test]
fn codes_survive_being_read_back_in_lowercase() {
    let tablet = DeviceIdentity::generate();
    let session = PairingSession::start(&tablet);
    let code = session.code();
    let (prefix, body) = code.split_at(CODE_PREFIX.len());
    let lower = format!("{prefix}{}", body.to_lowercase());
    assert_eq!(
        ScannedCode::parse(&lower).unwrap().signing_key,
        tablet.public_keys().signing
    );
}

mod admission_attacks {
    use super::*;

    fn paired() -> (Device, PairingSession, Vec<u8>) {
        let parent = Device::new("parent");
        let session = PairingSession::start(&DeviceIdentity::generate());
        let admission = ScannedCode::parse(&session.code())
            .unwrap()
            .admit(FAMILY, MEMBER, "dev-tablet", parent.id, &[parent.record()])
            .unwrap();
        (parent, session, admission)
    }

    #[test]
    fn the_server_cannot_forge_an_admission() {
        // It knows the tablet's public keys but never saw the code's secret.
        let (_, session, _) = paired();
        let server_made = Device::new("server-made");
        let forged = ScannedCode::parse(&PairingSession::start(&DeviceIdentity::generate()).code())
            .unwrap()
            .admit(
                "its-family",
                MEMBER,
                "dev-tablet",
                server_made.id,
                &[server_made.record()],
            )
            .unwrap();
        assert_eq!(session.accept(&forged).err(), Some(CryptoError::Tampered));
    }

    #[test]
    fn the_server_cannot_move_the_device_to_another_family_or_member() {
        let (_, session, admission) = paired();
        for (key, value) in [
            ("fam", "fam-2"),
            ("member", "member-leo"),
            ("to", "dev-other"),
        ] {
            let moved = edited(&admission, |e| *field(e, key) = Value::Text(value.into()));
            assert_eq!(
                session.accept(&moved).err(),
                Some(CryptoError::Tampered),
                "{key}"
            );
        }
    }

    #[test]
    fn slipping_a_device_into_a_real_admission_fails() {
        let (_, session, admission) = paired();
        let server_made = Device::new("server-made");
        let widened = edited(&admission, |e| {
            let Value::Array(list) = field(e, "devs") else {
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
        });
        assert_eq!(session.accept(&widened).err(), Some(CryptoError::Tampered));
    }

    #[test]
    fn swapping_the_admitter_fails() {
        let (_, session, admission) = paired();
        let renamed = edited(&admission, |e| {
            *field(e, "from") = Value::Text("someone".into())
        });
        // Rejected before the tag: `from` must be one of the listed devices.
        assert!(matches!(
            session.accept(&renamed),
            Err(CryptoError::Malformed(_))
        ));
    }

    #[test]
    fn an_admission_only_works_for_the_session_that_showed_the_code() {
        let (_, _, admission) = paired();
        let retry = PairingSession::start(&DeviceIdentity::generate());
        assert_eq!(retry.accept(&admission).err(), Some(CryptoError::Tampered));
    }

    #[test]
    fn a_flipped_tag_bit_fails() {
        let (_, session, admission) = paired();
        let damaged = edited(&admission, |e| {
            let Value::Bytes(tag) = field(e, "tag") else {
                panic!()
            };
            tag[0] ^= 1;
        });
        assert_eq!(session.accept(&damaged).err(), Some(CryptoError::Tampered));
    }

    #[test]
    fn admitting_needs_complete_ids() {
        let parent = Device::new("parent");
        let scanned =
            ScannedCode::parse(&PairingSession::start(&DeviceIdentity::generate()).code()).unwrap();
        let result = scanned.admit(FAMILY, "", "dev-tablet", parent.id, &[parent.record()]);
        assert!(matches!(result, Err(CryptoError::Malformed(_))));
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
        let session = PairingSession::start(&DeviceIdentity::generate());
        let mut code = session.code().to_string();
        code.truncate(code.len() - 3);
        assert!(ScannedCode::parse(&code).is_err());
    }
}
