//! Known-answer tests. The envelope vector pins the v1 wire format byte for
//! byte: if it changes, the format changed, and that needs a new `v`.

use chacha20poly1305::XChaCha20Poly1305;
use chacha20poly1305::aead::{Aead, KeyInit, Payload};

use crate::envelope::{GroupKey, Keyring, ObjectRef, Random, open, seal_with};

/// Deterministic stand-in for the OS random source: 0x00, 0x01, 0x02, ...
pub(crate) struct Counter(u8);

impl Random for Counter {
    fn fill(&mut self, buf: &mut [u8]) {
        for b in buf {
            *b = self.0;
            self.0 = self.0.wrapping_add(1);
        }
    }
}

fn unhex(s: &str) -> Vec<u8> {
    hex::decode(s.split_whitespace().collect::<String>()).unwrap()
}

/// XChaCha20-Poly1305 AEAD test vector, draft-irtf-cfrg-xchacha-03 §A.3.1.
#[test]
fn xchacha20poly1305_matches_the_published_vector() {
    let key = unhex("808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f");
    let nonce = unhex("404142434445464748494a4b4c4d4e4f5051525354555657");
    let aad = unhex("50515253c0c1c2c3c4c5c6c7");
    let plaintext = b"Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, sunscreen would be it.";
    let expected = unhex(
        "bd6d179d3e83d43b9576579493c0e939572a1700252bfaccbed2902c21396cbb
         731c7f1b0b4aa6440bf3a82f4eda7e39ae64c6708c54c216cb96b72e1213b452
         2f8c9ba40db5d945b11b69b982c1bb9e3f3fac2bc369488f76b2383565d3fff9
         21f9664c97637da9768812f615c68b13b52e
         c0875924c1c7987947deafd8780acf49",
    );

    let cipher = XChaCha20Poly1305::new(key.as_slice().try_into().unwrap());
    let nonce = nonce.as_slice().try_into().unwrap();
    let ciphertext = cipher
        .encrypt(
            &nonce,
            Payload {
                msg: plaintext,
                aad: &aad,
            },
        )
        .unwrap();
    assert_eq!(hex::encode(&ciphertext), hex::encode(&expected));
}

/// The worked example in crypto design doc §4.1.
#[test]
fn envelope_v1_worked_example() {
    let vector: serde_json::Value =
        serde_json::from_str(include_str!("../test-vectors/envelope-v1.json")).unwrap();
    let text = |k: &str| vector[k].as_str().unwrap().to_owned();

    let object = ObjectRef {
        object_type: text("object_type"),
        id: text("id"),
        family_id: text("family_id"),
    };
    let gck: [u8; 32] = unhex(&text("gck")).try_into().unwrap();
    let key = GroupKey::from_bytes(text("group"), vector["epoch"].as_u64().unwrap(), gck);
    let payload = unhex(&text("payload"));

    let envelope = seal_with(
        &mut Counter(0),
        &payload,
        &object,
        std::slice::from_ref(&key),
    )
    .unwrap();
    assert_eq!(hex::encode(&envelope), text("envelope"));

    let opened = open(&unhex(&text("envelope")), &Keyring::new(vec![key])).unwrap();
    assert_eq!(opened.payload, payload);
}
