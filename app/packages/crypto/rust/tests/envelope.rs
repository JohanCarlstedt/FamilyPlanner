//! Behaviour of the v1 envelope through the public API.

use ciborium::Value;
use family_crypto::{
    CryptoError, GroupKey, Keyring, ObjectRef, Wrap, generate_group_key, inspect, open, rewrap,
    seal,
};

fn event(id: &str) -> ObjectRef {
    ObjectRef {
        object_type: "event".into(),
        id: id.into(),
        family_id: "fam-1".into(),
    }
}

fn ring(keys: &[&GroupKey]) -> Keyring {
    Keyring::new(keys.iter().map(|k| (*k).clone()).collect())
}

/// Decodes an envelope, lets [edit] change it, and re-encodes it.
fn edited(envelope: &[u8], edit: impl FnOnce(&mut Vec<(Value, Value)>)) -> Vec<u8> {
    let Value::Map(mut entries) = ciborium::from_reader(envelope).unwrap() else {
        panic!("envelope is a map")
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

fn flip_last_byte(value: &mut Value) {
    let Value::Bytes(bytes) = value else {
        panic!("expected bytes")
    };
    *bytes.last_mut().unwrap() ^= 0x01;
}

mod round_trip {
    use super::*;

    #[test]
    fn opens_with_the_audience_key() {
        let all = generate_group_key("all", 0);
        let envelope = seal(
            b"Football, Tuesdays 17:30",
            &event("e1"),
            std::slice::from_ref(&all),
        )
        .unwrap();

        let opened = open(&envelope, &ring(&[&all])).unwrap();
        assert_eq!(opened.payload, b"Football, Tuesdays 17:30");
        assert_eq!(opened.header.object, event("e1"));
    }

    #[test]
    fn an_empty_payload_is_allowed() {
        let all = generate_group_key("all", 0);
        let envelope = seal(b"", &event("e1"), std::slice::from_ref(&all)).unwrap();
        assert_eq!(open(&envelope, &ring(&[&all])).unwrap().payload, b"");
    }

    #[test]
    fn each_audience_can_open_on_its_own() {
        let all = generate_group_key("all", 0);
        let helper = generate_group_key("adults+helper:h1", 0);
        let envelope = seal(b"x", &event("e1"), &[all.clone(), helper.clone()]).unwrap();

        assert!(open(&envelope, &ring(&[&all])).is_ok());
        assert!(open(&envelope, &ring(&[&helper])).is_ok());
    }

    #[test]
    fn sealing_twice_never_repeats_bytes() {
        let all = generate_group_key("all", 0);
        let a = seal(b"same", &event("e1"), std::slice::from_ref(&all)).unwrap();
        let b = seal(b"same", &event("e1"), &[all]).unwrap();
        assert_ne!(a, b);
    }

    #[test]
    fn inspect_reads_routing_metadata_without_keys() {
        let all = generate_group_key("all", 3);
        let adults = generate_group_key("adults", 1);
        let envelope = seal(b"secret", &event("e1"), &[all, adults]).unwrap();

        let header = inspect(&envelope).unwrap();
        assert_eq!(header.object, event("e1"));
        assert_eq!(
            header.audiences,
            [
                Wrap {
                    group: "all".into(),
                    epoch: 3
                },
                Wrap {
                    group: "adults".into(),
                    epoch: 1
                }
            ]
        );
    }
}

mod access {
    use super::*;

    #[test]
    fn a_device_outside_every_audience_has_no_access() {
        // A child's device holds `all`; this object is parents-only.
        let all = generate_group_key("all", 0);
        let adults = generate_group_key("adults", 0);
        let envelope = seal(b"gift ideas", &event("e1"), &[adults]).unwrap();

        assert_eq!(open(&envelope, &ring(&[&all])), Err(CryptoError::NoAccess));
    }

    #[test]
    fn an_old_epoch_key_does_not_open_a_new_epoch() {
        let old = generate_group_key("adults", 0);
        let new = generate_group_key("adults", 1);
        let envelope = seal(b"x", &event("e1"), &[new]).unwrap();

        assert_eq!(open(&envelope, &ring(&[&old])), Err(CryptoError::NoAccess));
    }

    #[test]
    fn a_wrong_key_for_the_right_group_is_tampering() {
        let real = generate_group_key("all", 0);
        let impostor = generate_group_key("all", 0);
        let envelope = seal(b"x", &event("e1"), &[real]).unwrap();

        assert_eq!(
            open(&envelope, &ring(&[&impostor])),
            Err(CryptoError::Tampered)
        );
    }
}

mod binding {
    use super::*;

    fn sealed() -> (GroupKey, Vec<u8>) {
        let all = generate_group_key("all", 0);
        let envelope = seal(b"x", &event("e1"), std::slice::from_ref(&all)).unwrap();
        (all, envelope)
    }

    fn with_aad(envelope: &[u8], key: &str, value: &str) -> Vec<u8> {
        edited(envelope, |e| {
            let Value::Map(aad) = field(e, "aad") else {
                panic!()
            };
            *field(aad, key) = Value::Text(value.into());
        })
    }

    #[test]
    fn moving_an_envelope_to_another_object_fails() {
        let (all, envelope) = sealed();
        let moved = with_aad(&envelope, "id", "e2");
        assert_eq!(open(&moved, &ring(&[&all])), Err(CryptoError::Tampered));
    }

    #[test]
    fn moving_an_envelope_to_another_family_fails() {
        let (all, envelope) = sealed();
        let moved = with_aad(&envelope, "fam", "fam-2");
        assert_eq!(open(&moved, &ring(&[&all])), Err(CryptoError::Tampered));
    }

    #[test]
    fn relabelling_the_object_type_fails() {
        let (all, envelope) = sealed();
        let moved = with_aad(&envelope, "t", "wishlist");
        assert_eq!(open(&moved, &ring(&[&all])), Err(CryptoError::Tampered));
    }

    #[test]
    fn a_wrap_copied_from_another_object_does_not_open_this_one() {
        let all = generate_group_key("all", 0);
        let first = seal(b"one", &event("e1"), std::slice::from_ref(&all)).unwrap();
        let second = seal(b"two", &event("e2"), std::slice::from_ref(&all)).unwrap();

        let Value::Map(second_entries) = ciborium::from_reader(second.as_slice()).unwrap() else {
            panic!()
        };
        let foreign_wraps = second_entries
            .iter()
            .find(|(k, _)| k.as_text() == Some("dek"))
            .unwrap()
            .1
            .clone();
        let spliced = edited(&first, |e| *field(e, "dek") = foreign_wraps);

        assert_eq!(open(&spliced, &ring(&[&all])), Err(CryptoError::Tampered));
    }

    #[test]
    fn relabelling_a_wrap_to_another_epoch_fails() {
        let all0 = generate_group_key("all", 0);
        let envelope = seal(b"x", &event("e1"), std::slice::from_ref(&all0)).unwrap();
        // Claim the wrap is for epoch 1 and present a key filed under epoch 1
        // with epoch 0's bytes: the epoch is bound, so this must not open.
        let relabelled = edited(&envelope, |e| {
            let Value::Array(wraps) = field(e, "dek") else {
                panic!()
            };
            let Value::Map(wrap) = &mut wraps[0] else {
                panic!()
            };
            *field(wrap, "e") = Value::Integer(1.into());
        });
        let misfiled = GroupKey::from_bytes("all", 1, *all0.key_bytes());

        assert_eq!(
            open(&relabelled, &ring(&[&misfiled])),
            Err(CryptoError::Tampered)
        );
    }

    #[test]
    fn a_flipped_ciphertext_bit_fails() {
        let (all, envelope) = sealed();
        let damaged = edited(&envelope, |e| flip_last_byte(field(e, "ct")));
        assert_eq!(open(&damaged, &ring(&[&all])), Err(CryptoError::Tampered));
    }

    #[test]
    fn a_flipped_wrap_bit_fails() {
        let (all, envelope) = sealed();
        let damaged = edited(&envelope, |e| {
            let Value::Array(wraps) = field(e, "dek") else {
                panic!()
            };
            let Value::Map(wrap) = &mut wraps[0] else {
                panic!()
            };
            flip_last_byte(field(wrap, "w"));
        });
        assert_eq!(open(&damaged, &ring(&[&all])), Err(CryptoError::Tampered));
    }

    #[test]
    fn a_flipped_nonce_bit_fails() {
        let (all, envelope) = sealed();
        let damaged = edited(&envelope, |e| flip_last_byte(field(e, "n")));
        assert_eq!(open(&damaged, &ring(&[&all])), Err(CryptoError::Tampered));
    }
}

mod versions {
    use super::*;

    #[test]
    fn an_unknown_version_is_refused_not_misread() {
        let all = generate_group_key("all", 0);
        let envelope = seal(b"x", &event("e1"), std::slice::from_ref(&all)).unwrap();
        let future = edited(&envelope, |e| *field(e, "v") = Value::Integer(2.into()));
        assert_eq!(
            open(&future, &ring(&[&all])),
            Err(CryptoError::UnsupportedVersion(2))
        );
    }

    #[test]
    fn an_unknown_algorithm_is_refused() {
        let all = generate_group_key("all", 0);
        let envelope = seal(b"x", &event("e1"), std::slice::from_ref(&all)).unwrap();
        let other = edited(&envelope, |e| *field(e, "alg") = Value::Integer(9.into()));
        assert_eq!(
            open(&other, &ring(&[&all])),
            Err(CryptoError::UnsupportedAlgorithm(9))
        );
    }

    #[test]
    fn readers_accept_non_canonical_key_order() {
        let all = generate_group_key("all", 0);
        let envelope = seal(b"x", &event("e1"), std::slice::from_ref(&all)).unwrap();
        let reordered = edited(&envelope, |e| e.reverse());
        assert_ne!(reordered, envelope);
        assert_eq!(open(&reordered, &ring(&[&all])).unwrap().payload, b"x");
    }
}

mod rewrapping {
    use super::*;

    #[test]
    fn narrowing_visibility_keeps_the_ciphertext_and_drops_access() {
        // Family-wide event becomes parents-only: a rewrap, not a re-encrypt.
        let all = generate_group_key("all", 0);
        let adults = generate_group_key("adults", 0);
        let envelope = seal(b"surprise party", &event("e1"), std::slice::from_ref(&all)).unwrap();

        let parents_device = ring(&[&all, &adults]);
        let narrowed = rewrap(&envelope, &parents_device, std::slice::from_ref(&adults)).unwrap();

        assert_eq!(
            open(&narrowed, &ring(&[&adults])).unwrap().payload,
            b"surprise party"
        );
        assert_eq!(open(&narrowed, &ring(&[&all])), Err(CryptoError::NoAccess));

        let ct = |env: &[u8]| {
            let Value::Map(e) = ciborium::from_reader(env).unwrap() else {
                panic!()
            };
            e.into_iter()
                .find(|(k, _)| k.as_text() == Some("ct"))
                .unwrap()
                .1
        };
        assert_eq!(
            ct(&narrowed),
            ct(&envelope),
            "the payload was not re-encrypted"
        );
    }

    #[test]
    fn moving_to_a_new_epoch() {
        let old = generate_group_key("adults", 0);
        let new = generate_group_key("adults", 1);
        let envelope = seal(b"x", &event("e1"), std::slice::from_ref(&old)).unwrap();

        let rotated = rewrap(&envelope, &ring(&[&old, &new]), std::slice::from_ref(&new)).unwrap();
        assert_eq!(
            inspect(&rotated).unwrap().audiences,
            [Wrap {
                group: "adults".into(),
                epoch: 1
            }]
        );
        assert_eq!(open(&rotated, &ring(&[&old])), Err(CryptoError::NoAccess));
        assert!(open(&rotated, &ring(&[&new])).is_ok());
    }

    #[test]
    fn requires_a_key_for_a_current_audience() {
        let adults = generate_group_key("adults", 0);
        let all = generate_group_key("all", 0);
        let envelope = seal(b"x", &event("e1"), &[adults]).unwrap();

        // A child's device can't widen a parents-only object.
        assert_eq!(
            rewrap(&envelope, &ring(&[&all]), std::slice::from_ref(&all)),
            Err(CryptoError::NoAccess)
        );
    }

    #[test]
    fn refuses_to_republish_a_swapped_ciphertext() {
        let all = generate_group_key("all", 0);
        let adults = generate_group_key("adults", 0);
        let envelope = seal(b"x", &event("e1"), std::slice::from_ref(&all)).unwrap();
        let damaged = edited(&envelope, |e| flip_last_byte(field(e, "ct")));

        assert_eq!(
            rewrap(
                &damaged,
                &ring(&[&all, &adults]),
                std::slice::from_ref(&adults)
            ),
            Err(CryptoError::Tampered)
        );
    }
}

mod malformed {
    use super::*;

    fn is_malformed<T: std::fmt::Debug>(result: Result<T, CryptoError>) -> bool {
        matches!(result, Err(CryptoError::Malformed(_)))
    }

    #[test]
    fn sealing_needs_an_audience() {
        assert!(is_malformed(seal(b"x", &event("e1"), &[])));
    }

    #[test]
    fn sealing_refuses_a_group_twice() {
        let a = generate_group_key("all", 0);
        let b = generate_group_key("all", 1);
        assert!(is_malformed(seal(b"x", &event("e1"), &[a, b])));
    }

    #[test]
    fn sealing_needs_a_complete_slot() {
        let all = generate_group_key("all", 0);
        let blank = ObjectRef {
            object_type: "event".into(),
            id: "".into(),
            family_id: "f".into(),
        };
        assert!(is_malformed(seal(b"x", &blank, &[all])));
    }

    #[test]
    fn rejects_garbage_and_trailing_bytes() {
        let all = generate_group_key("all", 0);
        assert!(is_malformed(inspect(b"not cbor at all")));

        let mut padded = seal(b"x", &event("e1"), &[all]).unwrap();
        padded.push(0x00);
        assert!(is_malformed(inspect(&padded)));
    }

    #[test]
    fn rejects_unknown_fields_in_v1() {
        let all = generate_group_key("all", 0);
        let envelope = seal(b"x", &event("e1"), &[all]).unwrap();
        let extended = edited(&envelope, |e| {
            e.push((Value::Text("extra".into()), Value::Integer(1.into())));
        });
        assert!(is_malformed(inspect(&extended)));
    }

    #[test]
    fn rejects_an_empty_audience_list() {
        let all = generate_group_key("all", 0);
        let envelope = seal(b"x", &event("e1"), &[all]).unwrap();
        let emptied = edited(&envelope, |e| *field(e, "dek") = Value::Array(vec![]));
        assert!(is_malformed(inspect(&emptied)));
    }

    #[test]
    fn rejects_a_short_nonce() {
        let all = generate_group_key("all", 0);
        let envelope = seal(b"x", &event("e1"), &[all]).unwrap();
        let short = edited(&envelope, |e| *field(e, "n") = Value::Bytes(vec![0; 12]));
        assert!(is_malformed(inspect(&short)));
    }
}

#[test]
fn the_latest_epoch_is_the_highest_held() {
    let mut keyring = Keyring::default();
    assert_eq!(keyring.latest_epoch("all"), None);
    keyring.insert(generate_group_key("all", 0));
    keyring.insert(generate_group_key("all", 2));
    keyring.insert(generate_group_key("all", 1));
    keyring.insert(generate_group_key("adults", 5));
    assert_eq!(keyring.latest_epoch("all"), Some(2));
    assert_eq!(keyring.latest_epoch("adults"), Some(5));
}
