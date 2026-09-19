"""Independent check of recovery kit v1 (crypto doc §7.3) from its Argon2id
output on: the HKDF-SHA256 derivations (RFC 5869), the Ed25519 and X25519
public keys (RFC 8032, 7748) and the sealed note (XChaCha20-Poly1305),
sharing no code with the Rust crates. Argon2id itself is checked in Rust
against RFC 9106 §5.3; the BIP-39 words against BIP-39's own vectors.

    python3 verify_recovery.py recovery-v1.json
"""
import json, sys

from verify_envelope import hkdf_sha256, xchacha_open
from verify_grant import ed_public, x25519


def main(path):
    v = json.load(open(path))
    root = bytes.fromhex(v['root'])
    assert hkdf_sha256(root, b'fam.recovery.id.v1')[:16].hex() == v['lookup_id'], 'lookup id'
    assert ed_public(hkdf_sha256(root, b'fam.recovery.sig.v1')).hex() == v['signing_public_key'], 'signing key'
    kem = x25519(hkdf_sha256(root, b'fam.recovery.kem.v1'), (9).to_bytes(32, 'little'))
    assert kem.hex() == v['kem_public_key'], 'kem key'
    sealed = bytes.fromhex(v['sealed_note'])
    note = xchacha_open(hkdf_sha256(root, b'fam.recovery.note.v1'), sealed[:24],
                        b'fam.recovery.note.v1', sealed[24:])
    assert note == v['note'].encode(), 'note'
    print('recovery v1: derivations, keys and note verified')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'recovery-v1.json')
