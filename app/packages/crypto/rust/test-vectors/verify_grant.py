"""Independent check of grant v1 (crypto doc §3.1), written from RFC 7748
(X25519), RFC 8032 (Ed25519) and RFC 9180 (HPKE), sharing no code with the
Rust crates.

    python3 verify_grant.py grant-v1.json
"""
import hashlib, hmac, json, struct, sys

from verify_envelope import cbor_dec, cbor_enc, xchacha_open  # noqa: F401
from verify_envelope import block, chacha_xor, poly1305

P = 2**255 - 19

# --- X25519, RFC 7748 §5 -----------------------------------------------------
def x25519(k, u):
    k = bytearray(k); k[0] &= 248; k[31] &= 127; k[31] |= 64
    k = int.from_bytes(k, 'little'); u = int.from_bytes(u, 'little') & ((1 << 255) - 1)
    x1, x2, z2, x3, z3, swap = u, 1, 0, u, 1, 0
    for t in reversed(range(255)):
        kt = (k >> t) & 1; swap ^= kt
        if swap: x2, x3, z2, z3 = x3, x2, z3, z2
        swap = kt
        A = x2 + z2; AA = A * A; B = x2 - z2; BB = B * B; E = AA - BB
        C = x3 + z3; D = x3 - z3; DA = D * A; CB = C * B
        x3 = (DA + CB) ** 2 % P; z3 = x1 * (DA - CB) ** 2 % P
        x2 = AA * BB % P; z2 = E * (AA + 121665 * E) % P
    if swap: x2, z2 = x3, z3
    return (x2 * pow(z2, P - 2, P) % P).to_bytes(32, 'little')

BASE_U = (9).to_bytes(32, 'little')

# --- Ed25519, RFC 8032 §5.1 ---------------------------------------------------
L = 2**252 + 27742317777372353535851937790883648493
D = -121665 * pow(121666, P - 2, P) % P
I = pow(2, (P - 1) // 4, P)
def recover_x(y, sign):
    x2 = (y * y - 1) * pow(D * y * y + 1, P - 2, P)
    x = pow(x2, (P + 3) // 8, P)
    if (x * x - x2) % P: x = x * I % P
    if (x * x - x2) % P: return None
    if x & 1 != sign: x = P - x
    return x
GY = 4 * pow(5, P - 2, P) % P
G = (recover_x(GY, 0), GY, 1, recover_x(GY, 0) * GY % P)
def add(a, b):
    A = (a[1] - a[0]) * (b[1] - b[0]) % P; B = (a[1] + a[0]) * (b[1] + b[0]) % P
    C = 2 * a[3] * b[3] * D % P; Dd = 2 * a[2] * b[2] % P
    E, F, Gg, H = B - A, Dd - C, Dd + C, B + A
    return (E * F % P, Gg * H % P, F * Gg % P, E * H % P)
def mul(s, p):
    q = (0, 1, 1, 0)
    while s:
        if s & 1: q = add(q, p)
        p = add(p, p); s >>= 1
    return q
def enc_point(p):
    zi = pow(p[2], P - 2, P); x = p[0] * zi % P; y = p[1] * zi % P
    return (y | ((x & 1) << 255)).to_bytes(32, 'little')
def dec_point(b):
    y = int.from_bytes(b, 'little'); sign = y >> 255; y &= (1 << 255) - 1
    x = recover_x(y, sign)
    return None if x is None or y >= P else (x, y, 1, x * y % P)
def ed_public(seed):
    h = hashlib.sha512(seed).digest()
    a = int.from_bytes(h[:32], 'little'); a &= (1 << 254) - 8; a |= 1 << 254
    return enc_point(mul(a, G))
def ed_verify(pub, msg, sig):
    A = dec_point(pub); R = dec_point(sig[:32]); s = int.from_bytes(sig[32:], 'little')
    if A is None or R is None or s >= L: return False
    h = int.from_bytes(hashlib.sha512(sig[:32] + pub + msg).digest(), 'little') % L
    return enc_point(mul(s, G)) == enc_point(add(R, mul(h, A)))

# --- HPKE base mode, RFC 9180 -------------------------------------------------
def hkdf_extract(salt, ikm): return hmac.new(salt or b'\0' * 32, ikm, hashlib.sha256).digest()
def hkdf_expand(prk, info, n):
    out, t, i = b'', b'', 1
    while len(out) < n:
        t = hmac.new(prk, t + info + bytes([i]), hashlib.sha256).digest(); out += t; i += 1
    return out[:n]
def labeled_extract(suite, salt, label, ikm):
    return hkdf_extract(salt, b'HPKE-v1' + suite + label + ikm)
def labeled_expand(suite, prk, label, info, n):
    return hkdf_expand(prk, n.to_bytes(2, 'big') + b'HPKE-v1' + suite + label + info, n)
KEM = b'KEM' + (0x0020).to_bytes(2, 'big')
HPKE = b'HPKE' + b''.join(x.to_bytes(2, 'big') for x in (0x0020, 0x0001, 0x0003))
def decap(enc, sk):
    dh = x25519(sk, enc); pk = x25519(sk, BASE_U)
    eae = labeled_extract(KEM, b'', b'eae_prk', dh)
    return labeled_expand(KEM, eae, b'shared_secret', enc + pk, 32)
def chacha_poly_open(key, nonce12, ad, ct):
    body, tag = ct[:-16], ct[-16:]
    otk = block(key, 0, nonce12)[:32]
    pad = lambda b: b + b'\0' * (-len(b) % 16)
    if not hmac.compare_digest(poly1305(otk, pad(ad) + pad(body) + struct.pack('<QQ', len(ad), len(body))), tag):
        raise ValueError('HPKE tag mismatch')
    return chacha_xor(key, 1, nonce12, body)
def hpke_open(sk, enc, info, ct, aad=b''):
    ss = decap(enc, sk)
    psk_id = labeled_extract(HPKE, b'', b'psk_id_hash', b'')
    info_h = labeled_extract(HPKE, b'', b'info_hash', info)
    secret = labeled_extract(HPKE, ss, b'secret', b'')
    ctx = b'\x00' + psk_id + info_h
    key = labeled_expand(HPKE, secret, b'key', ctx, 32)
    base_nonce = labeled_expand(HPKE, secret, b'base_nonce', ctx, 12)
    return chacha_poly_open(key, base_nonce, aad, ct)

# --- The grant, crypto doc §3.1 -----------------------------------------------
if __name__ == '__main__':
    v = json.load(open(sys.argv[1]))
    h = bytes.fromhex
    assert ed_public(h(v['granter_signing_seed'])).hex() == v['granter_signing_public'], 'granter key'
    assert x25519(h(v['recipient_kem_secret']), BASE_U).hex() == v['recipient_kem_public'], 'recipient key'

    raw = h(v['grant']); g, end = cbor_dec(raw); assert end == len(raw)
    assert g['v'] == 1 and g['suite'] == 1
    fields = [g['fam'], g['g'], g['e'], g['to'], g['from']]
    # The signed array ends in two byte strings, which cbor_enc doesn't write:
    # append them by hand and bump the array length from 8 to 10.
    def bstr(b): return (bytes([0x40 | len(b)]) if len(b) < 24 else bytes([0x58, len(b)])) + b
    head = cbor_enc(['fam.grant.sig', 1, 1] + fields)
    signed = bytes([head[0] + 2]) + head[1:] + bstr(g['enc']) + bstr(g['ct'])
    assert ed_verify(h(v['granter_signing_public']), signed, g['sig']), 'signature'
    info = cbor_enc(['fam.grant', 1, 1] + fields)
    gck = hpke_open(h(v['recipient_kem_secret']), g['enc'], info, g['ct'])
    assert gck.hex() == v['gck'], 'group key'
    print('grant verified: signature, HPKE open and group key all match')
