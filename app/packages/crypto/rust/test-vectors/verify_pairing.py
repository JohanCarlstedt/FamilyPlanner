"""Independent check of QR pairing v1 (crypto doc §7.1): the code, the
admission's HMAC and the endorsement's signature, written from RFC 4648
(base32), RFC 8949 (deterministic CBOR), RFC 2104/5869 (HMAC, HKDF) and
RFC 8032 (Ed25519), sharing no code with the Rust crates.

    python3 verify_pairing.py pairing-v1.json
"""
import base64, hashlib, hmac, json, sys

from verify_envelope import cbor_dec
from verify_grant import BASE_U, ed_public, ed_verify, x25519


def head(major, n):
    if n < 24: return bytes([major << 5 | n])
    for ai, width in ((24, 1), (25, 2), (26, 4), (27, 8)):
        if n < 1 << (8 * width): return bytes([major << 5 | ai]) + n.to_bytes(width, 'big')


def det_cbor(v):
    """RFC 8949 §4.2.1 core deterministic encoding, for the types used here."""
    if isinstance(v, int): return head(0, v)
    if isinstance(v, bytes): return head(2, len(v)) + v
    if isinstance(v, str): e = v.encode(); return head(3, len(e)) + e
    if isinstance(v, list): return head(4, len(v)) + b''.join(map(det_cbor, v))
    if isinstance(v, dict):
        items = sorted((det_cbor(k), det_cbor(x)) for k, x in v.items())
        return head(5, len(items)) + b''.join(k + x for k, x in items)
    raise TypeError(type(v))


def hkdf_sha256(ikm, info):
    prk = hmac.new(b'\0' * 32, ikm, hashlib.sha256).digest()
    return hmac.new(prk, info + b'\x01', hashlib.sha256).digest()


v = json.load(open(sys.argv[1]))
h = bytes.fromhex

# The code: FAM1: + unpadded uppercase base32 of CBOR {v, sig, kem, k}. A new
# device belongs to nothing yet, so it shows only its keys and the secret.
assert v['code'].startswith('FAM1:')
body = v['code'][5:]
raw = base64.b32decode(body + '=' * (-len(body) % 8))
code, end = cbor_dec(raw); assert end == len(raw)
assert det_cbor(code) == raw, 'code is deterministically encoded'
assert code['v'] == 1 and code['k'] == h(v['pairing_secret'])

secret = cbor_dec(h(v['new_device_secret']))[0]
sig, kem = ed_public(secret['s']), x25519(secret['k'], BASE_U)
assert (code['sig'], code['kem']) == (sig, kem), 'the code carries the new device\'s real keys'

# The mailbox: 16 bytes of HKDF of the secret, as lowercase hex.
assert hkdf_sha256(code['k'], b'fam.mailbox.v1')[:16].hex() == v['mailbox'], 'mailbox'

# The admission: an HMAC keyed by HKDF of the code's secret, telling the new
# device its family, member and device id.
adm, end = cbor_dec(h(v['admission'])); assert end == len(h(v['admission']))
assert adm['v'] == 1 and adm['fam'] == v['family_id'] and adm['member'] == v['member_id']
assert adm['to'] == v['new_device'] and adm['from'] == v['admitter_device']
assert any(d['id'] == adm['from'] for d in adm['devs'])
new_device = {'id': adm['to'], 'sig': sig, 'kem': kem}
key = hkdf_sha256(code['k'], b'fam.admit.v1')
message = det_cbor(['fam.admit', 1, adm['fam'], adm['member'], new_device, adm['from'], adm['devs']])
assert hmac.compare_digest(hmac.new(key, message, hashlib.sha256).digest(), adm['tag']), 'admission tag'

# The endorsement: the admitter's signature over the new device's record.
end_ = cbor_dec(h(v['endorsement']))[0]
assert end_['v'] == 1 and end_['fam'] == v['family_id'] and end_['by'] == v['admitter_device']
assert end_['dev'] == new_device
signed = det_cbor(['fam.endorse', 1, end_['fam'], end_['dev'], end_['by']])
assert ed_verify(h(v['admitter_signing_public']), signed, end_['s']), 'endorsement signature'

print('pairing verified: code, mailbox, admission tag and endorsement signature all match')
