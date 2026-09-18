"""Independent check of envelope v1, written from the spec, sharing no code with Rust."""
import hashlib, hmac, struct, sys

def rotl(v, c): return ((v << c) & 0xffffffff) | (v >> (32 - c))
def qr(s, a, b, c, d):
    s[a]=(s[a]+s[b])&0xffffffff; s[d]=rotl(s[d]^s[a],16)
    s[c]=(s[c]+s[d])&0xffffffff; s[b]=rotl(s[b]^s[c],12)
    s[a]=(s[a]+s[b])&0xffffffff; s[d]=rotl(s[d]^s[a],8)
    s[c]=(s[c]+s[d])&0xffffffff; s[b]=rotl(s[b]^s[c],7)
def rounds(s):
    for _ in range(10):
        qr(s,0,4,8,12);qr(s,1,5,9,13);qr(s,2,6,10,14);qr(s,3,7,11,15)
        qr(s,0,5,10,15);qr(s,1,6,11,12);qr(s,2,7,8,13);qr(s,3,4,9,14)
C = list(struct.unpack('<4I', b'expand 32-byte k'))
def block(key, counter, nonce12):
    s = C + list(struct.unpack('<8I', key)) + [counter] + list(struct.unpack('<3I', nonce12))
    w = s[:]; rounds(w)
    return struct.pack('<16I', *[(a+b)&0xffffffff for a,b in zip(w,s)])
def hchacha(key, n16):
    s = C + list(struct.unpack('<8I', key)) + list(struct.unpack('<4I', n16)); rounds(s)
    return struct.pack('<8I', *(s[0:4]+s[12:16]))
def chacha_xor(key, counter, nonce12, data):
    out = bytearray()
    for i in range(0, len(data), 64):
        ks = block(key, counter + i//64, nonce12)
        out += bytes(x^y for x,y in zip(data[i:i+64], ks))
    return bytes(out)
def poly1305(key, msg):
    r = int.from_bytes(key[:16],'little') & 0x0ffffffc0ffffffc0ffffffc0fffffff
    s = int.from_bytes(key[16:],'little'); p=(1<<130)-5; acc=0
    for i in range(0,len(msg),16):
        acc = (acc + int.from_bytes(msg[i:i+16]+b'\x01','little'))*r % p
    return ((acc+s) & ((1<<128)-1)).to_bytes(16,'little')
def xchacha_open(key, nonce24, ad, ct):
    sub = hchacha(key, nonce24[:16]); n12 = b'\0'*4 + nonce24[16:]
    body, tag = ct[:-16], ct[-16:]
    otk = block(sub, 0, n12)[:32]
    pad = lambda b: b + b'\0'*(-len(b)%16)
    mac = poly1305(otk, pad(ad)+pad(body)+struct.pack('<QQ', len(ad), len(body)))
    if not hmac.compare_digest(mac, tag): raise ValueError('tag mismatch')
    return chacha_xor(sub, 1, n12, body)

# Minimal CBOR: exactly the major types the spec uses.
def cbor_dec(b, i=0):
    ib = b[i]; mt, ai = ib>>5, ib&31; i += 1
    if ai < 24: n = ai
    else:
        l = {24:1,25:2,26:4,27:8}[ai]; n = int.from_bytes(b[i:i+l],'big'); i += l
    if mt == 0: return n, i
    if mt == 2: return b[i:i+n], i+n
    if mt == 3: return b[i:i+n].decode(), i+n
    if mt == 4:
        out=[]; 
        for _ in range(n): v,i = cbor_dec(b,i); out.append(v)
        return out, i
    if mt == 5:
        out={}
        for _ in range(n):
            k,i = cbor_dec(b,i); v,i = cbor_dec(b,i); out[k]=v
        return out, i
    raise ValueError(mt)
def head(mt, n):
    if n < 24: return bytes([mt<<5|n])
    for ai,l in ((24,1),(25,2),(26,4),(27,8)):
        if n < 1<<(8*l): return bytes([mt<<5|ai]) + n.to_bytes(l,'big')
def cbor_enc(v):
    if isinstance(v,int): return head(0,v)
    if isinstance(v,str): e=v.encode(); return head(3,len(e))+e
    if isinstance(v,list): return head(4,len(v))+b''.join(map(cbor_enc,v))
    raise TypeError

def hkdf_sha256(ikm, info, length=32):
    prk = hmac.new(b'\0'*32, ikm, hashlib.sha256).digest()
    return hmac.new(prk, info + b'\x01', hashlib.sha256).digest()[:length]

env_hex, gck_hex = sys.argv[1], sys.argv[2]
env, end = cbor_dec(bytes.fromhex(env_hex)); assert end == len(bytes.fromhex(env_hex))
assert env['v'] == 1 and env['alg'] == 1
aad = env['aad']; t, oid, fam = aad['t'], aad['id'], aad['fam']
wrap = env['dek'][0]
kek = hkdf_sha256(bytes.fromhex(gck_hex), b'fam.kek.v1')
wrap_ad = cbor_enc(['fam.wrap', 1, 1, wrap['g'], wrap['e'], fam, t, oid])
dek = xchacha_open(kek, wrap['w'][:24], wrap_ad, wrap['w'][24:])
obj_ad = cbor_enc(['fam.obj', 1, 1, fam, t, oid])
payload = xchacha_open(dek, env['n'], obj_ad, env['ct'])
print('keys in wire order:', list(env.keys()))
print('dek:', dek.hex())
print('payload:', payload.hex())
