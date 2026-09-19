"""Independent check of request signatures v1 (crypto doc §2.2), written from
FIPS 180-4 (SHA-256) and RFC 8032 (Ed25519), sharing no code with the Rust
crates.

    python3 verify_request.py request-v1.json
"""
import hashlib, json, sys

from verify_grant import ed_public, ed_verify


def message(v):
    digest = hashlib.sha256(v['body'].encode()).hexdigest()
    return '\n'.join(['fam.req.v1', v['device_id'], v['method'], v['path_and_query'],
                      str(v['timestamp_ms']), digest]).encode()


def main(path):
    v = json.load(open(path))
    public = ed_public(bytes.fromhex(v['signing_seed']))
    assert public.hex() == v['signing_public_key'], 'public key'
    m = message(v)
    assert m.decode() == v['message'], 'message'
    assert ed_verify(public, m, bytes.fromhex(v['signature'])), 'signature'
    tampered = m.replace(b'PUT', b'GET')
    assert not ed_verify(public, tampered, bytes.fromhex(v['signature'])), 'tamper'
    print('request v1: message and signature verified')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'request-v1.json')
