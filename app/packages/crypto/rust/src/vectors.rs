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

/// RFC 9180 §A.2.1: base mode, DHKEM(X25519, HKDF-SHA256), HKDF-SHA256,
/// ChaCha20-Poly1305. Proves the HPKE suite of crypto doc §3.1 is wired up
/// as specified, independently of this crate's own grant format.
#[test]
fn hpke_suite_matches_rfc9180_a21() {
    use hpke::aead::ChaCha20Poly1305;
    use hpke::kdf::HkdfSha256;
    use hpke::kem::X25519HkdfSha256;
    use hpke::{Deserializable, Kem, OpModeR};

    let sk = <X25519HkdfSha256 as Kem>::PrivateKey::from_bytes(&unhex(
        "8057991eef8f1f1af18f4a9491d16a1ce333f695d4db8e38da75975c4478e0fb",
    ))
    .unwrap();
    let enc = <X25519HkdfSha256 as Kem>::EncappedKey::from_bytes(&unhex(
        "1afa08d3dec047a643885163f1180476fa7ddb54c6a8029ea33f95796bf2ac4a",
    ))
    .unwrap();
    let plaintext = hpke::single_shot_open::<ChaCha20Poly1305, HkdfSha256, X25519HkdfSha256>(
        &OpModeR::Base,
        &sk,
        &enc,
        &unhex("4f6465206f6e2061204772656369616e2055726e"),
        &unhex(
            "1c5250d8034ec2b784ba2cfd69dbdb8af406cfe3ff938e131f0def8c8b60b4db
             21993c62ce81883d2dd1b51a28",
        ),
        &unhex("436f756e742d30"),
    )
    .unwrap();
    assert_eq!(plaintext, b"Beauty is truth, truth beauty");
}

/// The worked example in crypto design doc §3.1.
#[test]
fn grant_v1_worked_example() {
    use crate::device::DeviceIdentity;
    use crate::grant::{TrustedDevice, accept, grant_with};

    let vector: serde_json::Value =
        serde_json::from_str(include_str!("../test-vectors/grant-v1.json")).unwrap();
    let text = |k: &str| vector[k].as_str().unwrap().to_owned();

    // Granter draws 0x10.., recipient 0x60.., HPKE's ephemeral key 0xc0...
    let granter = DeviceIdentity::generate_with(&mut Counter(0x10));
    let recipient = DeviceIdentity::generate_with(&mut Counter(0x60));
    assert_eq!(
        hex::encode(granter.public_keys().signing),
        text("granter_signing_public")
    );
    assert_eq!(
        hex::encode(recipient.public_keys().kem),
        text("recipient_kem_public")
    );
    assert_eq!(
        hex::encode(recipient.to_secret_bytes()),
        text("recipient_secret")
    );

    let gck: [u8; 32] = unhex(&text("gck")).try_into().unwrap();
    let key = GroupKey::from_bytes(text("group"), vector["epoch"].as_u64().unwrap(), gck);
    let granted = grant_with(
        &mut Counter(0xc0),
        &key,
        &text("family_id"),
        &granter,
        &text("from_device"),
        &text("to_device"),
        &recipient.public_keys().kem,
    )
    .unwrap();
    assert_eq!(hex::encode(&granted), text("grant"));

    let trusted = [TrustedDevice {
        device_id: text("from_device"),
        signing_key: granter.public_keys().signing,
    }];
    let received = accept(
        &unhex(&text("grant")),
        &text("family_id"),
        &recipient,
        &text("to_device"),
        &trusted,
    )
    .unwrap();
    assert_eq!(received.key_bytes(), &gck);
}
