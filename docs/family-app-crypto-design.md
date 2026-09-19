# Family App — Cryptographic Design

The artefact flagged as unfixable-later. Envelope format, key hierarchy, the mapping from permissions to keys, and the lifecycle flows.

Chat is handled separately by MLS and is out of scope here except where it touches device identity.

---

## 1. Threat model

Being explicit about this prevents both over-building and overclaiming.

**Defended against:**

- The server operator reading family content — by design, not by policy
- A database dump, backup leak, or hosting provider compromise
- Network interception beyond TLS
- A stolen phone, provided it was locked (keys sit in hardware-backed storage)
- A family member reading content they were never granted — children reading parents-only events, a wishlist owner seeing claims, a helper seeing anything beyond their grant

**Not defended against, and worth saying so:**

- **A compromised device belonging to a legitimate member.** If a parent's unlocked phone is taken, everything that parent could read is readable.
- **A malicious family member.** Someone with a grant can screenshot, copy, or relay anything they can see. This is a household, not an adversarial network.
- **Metadata analysis by the server.** It sees the membership graph, object sizes, change timing, and that a delivery is scheduled for 16:45. Section 6 of the architecture document lists this precisely.
- **Forward secrecy for stored content.** A device that already decrypted an object keeps that plaintext. Revocation stops future access only.

---

## 2. Key inventory

| Key | Lives | Lifetime |
|---|---|---|
| Device identity keypair | Rust core; stored encrypted under a hardware-backed Keychain / Keystore key (§2.1) | Device lifetime |
| Group content key (GCK) | Derived and held per member device | Until group membership changes |
| Object data key (DEK) | Random per encrypted object | Object lifetime |
| Recovery key | Derived from the recovery code, never stored | Until recovery code is regenerated |
| MLS group keys | Managed by OpenMLS | Per epoch |

### Device identity

Each device generates, on first run:

- **Ed25519** signing keypair — authenticates the device
- **X25519** keypair — receives wrapped keys via HPKE

Private keys are generated in and never leave hardware-backed storage where the platform allows it. Public keys are published to the server's key directory, signed, and pinned by other family devices at provisioning time.

### 2.1 Device identity, byte-level

**Where the keys actually live.** In practice the platform doesn't allow it: Android Keystore and the iOS Secure Enclave don't offer X25519 or Ed25519 on the devices this app targets (the Secure Enclave is P-256 only). So both private keys are generated in the Rust core and stored **encrypted under a non-exportable, hardware-backed key** — Keystore AES on Android, a Keychain item with device-only accessibility on iOS. The practical protection is the same for a locked, stolen phone; the difference is that the keys briefly exist in app memory while in use.

**Generation.** 32 bytes from the OS CSPRNG as the Ed25519 seed (RFC 8032), and 32 as the X25519 secret (RFC 7748; clamping makes any 32 bytes valid).

**Published form.** The two 32-byte public keys, as the directory's `SigningPublicKey` and `KemPublicKey`.

**Stored secret form.** Deterministic CBOR `{v: 1, s: bstr(32) Ed25519 seed, k: bstr(32) X25519 secret}`, strict like the envelope. It exists only to be encrypted by the platform layer and never leaves the device.

**Storing the secret.** `DeviceVault` in `app/packages/crypto` holds it through flutter_secure_storage:

- **Android:** AES-GCM under a Keystore-wrapped key. The plugin's default of wiping all stored values on any error is turned **off** — for a device identity that would be silent, permanent loss — and migration between cipher algorithms keeps a backup copy. Shared preferences, where the plugin keeps its ciphertext, are excluded from cloud backup and device transfer: the Keystore key never leaves the phone, so a restored copy could never be decrypted.
- **iOS:** a Keychain item with `first_unlock_this_device` and no iCloud sync — readable after the first unlock following a restart, so background sync and the notification extension can use it, and never migrated to another device.
- **Failure is loud.** A secret that exists but can't be read or parsed raises an error for a person to resolve (recover, or re-pair as a new device). It never triggers a fresh identity, which would silently orphan the device from its family. Concurrent first calls share one creation.
- **Known limit:** the plugin stores strings, so the secret briefly exists as an immutable base64 string in Dart memory that can't be wiped, unlike the byte buffers around it. Acceptable for a locked-phone threat model; revisit if the key store moves into the Rust core.

**Group keys at rest.** A device persists its keyring as **grants to itself** (§3.1): each group key sealed to its own X25519 key and signed by its own Ed25519 key. Only the device secret then needs hardware-backed protection, and group key bytes never leave the Rust core.

### 2.2 Request authentication, byte-level

The server needs to know which device is calling, and nothing weaker than the device's own key should do: a device id alone is not a secret. Every API request made as a device carries three headers:

- `X-Device-Id` — the device's id
- `X-Fam-Timestamp` — Unix time in milliseconds
- `X-Fam-Signature` — base64 of the Ed25519 signature (RFC 8032) by the device's signing key over

```
fam.req.v1\n<device id>\n<METHOD>\n<raw path and query>\n<timestamp>\n<hex sha256(body)>
```

**Domain separation.** The message is text beginning `fam.req.v1`; every other structure the signing key signs (grants §3.1, endorsements §7.1) is a CBOR array, whose first byte is 0x80–0x9f. No signature can be read as the other kind. The Rust core builds the message itself, so the device key can't be asked to sign arbitrary bytes.

**Verifying.** The server looks up the device's registered `SigningPublicKey` and refuses revoked devices, signatures that don't verify, timestamps more than 5 minutes from its own clock (`clock_skew`: the client retries once on the server's `Date`), and an exact signature seen before within the window (`replayed`). The path and query are verified as sent, before decoding.

**Anonymous routes** stay the only exceptions: health, creating a family (the founder registers its keys in that call), and collecting an admission from a pairing mailbox (§7.1).

**Test vector:** `rust/test-vectors/request-v1.json`, checked by the Rust core, the server's tests and `verify_request.py`.

**Known limit.** This authenticates requests, not responses; TLS carries that, and content is end-to-end encrypted anyway. A replay after a server restart within the window is possible on a single instance; acceptable while every write is idempotent on its client command id.

### Why there is no single family master key

The intuitive design is one Family Root Key held by everyone. It fails immediately: a child's device holding the root key can derive everything, including parents-only content. Permissions *are* key distribution here, so the key hierarchy has to mirror the audience structure.

Instead there are **audience groups**, each with its own content key.

---

## 3. Audience groups

A group is a named set of member devices that share a content key.

| Group | Members | Created |
|---|---|---|
| `all` | Every member including children | At family creation |
| `adults` | Parents only | At family creation |
| `adults+helper:{id}` | Parents plus one helper | When a helper is granted |
| `care:{person_id}` | Parents plus helpers granted care access for that child | On first care record |
| `wishlist:{id}:observers` | Everyone **except** the list owner | When a wishlist is created |
| `custody:{child_id}` | Members of both households | When a custody arrangement exists |
| `mls:{conversation_id}` | Conversation participants, managed by OpenMLS | Per conversation |

Each group has a monotonically increasing **epoch**. Membership changes bump the epoch and generate a fresh GCK, which is wrapped to every current member device's X25519 public key via HPKE and stored server-side as opaque blobs.

A device holds the GCKs for the groups it belongs to, for the epochs it has been a member of. It never receives keys for earlier epochs — which is what gives new members backward secrecy.

### 3.1 Group key grants, byte-level

A **grant** carries one GCK to one device. It is the opaque `WrappedKey` blob the server stores per device, group and epoch.

**HPKE alone is not enough.** HPKE's base mode lets *anyone* seal to a public key. Unsigned, the server could register a device of its own, seal a GCK it chose to a real device, and read everything that device later writes under it — the whole premise of this design broken by the post box. So every grant is **signed by the granting device's Ed25519 key**, and a device accepts a grant only from a device it already trusts: one pinned at provisioning after the out-of-band check (§7), never one taken from the directory on the server's word.

**Encoding.** A deterministic CBOR map with exactly these keys:

| Key | Type | Rule |
|---|---|---|
| `v` | uint | `1`, read first |
| `suite` | uint | `1` = HPKE base mode, DHKEM(X25519, HKDF-SHA256) `0x0020`, HKDF-SHA256 `0x0001`, ChaCha20-Poly1305 `0x0003` |
| `fam`, `g`, `to`, `from` | tstr | Family, group, recipient device id, granting device id; all non-empty |
| `e` | uint | Epoch |
| `enc` | bstr(32) | HPKE encapsulated key |
| `ct` | bstr(48) | The 32-byte GCK sealed, with its tag |
| `sig` | bstr(64) | Ed25519 signature |

**Sealing.**

```
info = [ "fam.grant", v, suite, fam, g, e, to, from ]                  ; deterministic CBOR
enc, ct = HPKE.SealBase(pk = recipient X25519, info, aad = "", pt = GCK)
sig = Ed25519.Sign(granter, [ "fam.grant.sig", v, suite, fam, g, e, to, from, enc, ct ])
```

`info` binds the sealed key to its family, group, epoch and both devices, so a grant can't be replayed as another group's key or to another device; the signature covers everything else.

**Accepting.** Check `fam` and `to` are this family and this device (else *wrong recipient*); find `from` among trusted devices (else *untrusted sender*); verify the signature strictly, refusing weak or non-canonical keys; then open with HPKE. Any failure after the trust check is *tampered*. **The group and epoch are taken from inside the signed grant**, never from the columns the server stores beside it.

**Worked example** in `app/packages/crypto/rust/test-vectors/grant-v1.json`, with every input fixed, including HPKE's ephemeral key. `verify_grant.py` beside it re-derives both devices' public keys, verifies the signature and opens the grant using X25519, Ed25519 and HPKE written from RFCs 7748, 8032 and 9180, sharing no code with the Rust crates. The HPKE suite itself is also checked against RFC 9180 §A.2.1.

---

## 4. Envelope format

Every encrypted object uses the same envelope. **CBOR**, not JSON — smaller on the wire, and these are attached to every row.

```
Envelope {
  v:    1                       ; envelope format version
  alg:  1                       ; 1 = XChaCha20-Poly1305
  dek:  [ Wrap, ... ]           ; the DEK wrapped once per audience
  n:    bstr(24)                ; nonce
  aad:  { t, id, fam }          ; bound, not encrypted
  ct:   bstr                    ; ciphertext of the payload
}

Wrap {
  g:  tstr                      ; group name, e.g. "adults"
  e:  uint                      ; group epoch
  w:  bstr                      ; DEK sealed to that group's GCK
}
```

### The per-object DEK is the important choice

Each object gets a **fresh random 256-bit DEK**. The payload is encrypted once under that DEK, and the DEK is then wrapped once per audience that may read the object.

This buys three things:

1. **Multiple audiences without duplicate ciphertext.** An event readable by `all` and separately by a helper carries one ciphertext and two wraps.
2. **Changing visibility is a rewrap, not a re-encryption.** Moving an event from family-wide to parents-only means dropping one `Wrap` entry and adding another — a few hundred bytes, instant. *This corrects an earlier claim in the architecture document that visibility changes require re-encrypting content; they don't.*
3. **Group key rotation doesn't touch content.** A new epoch rewraps DEKs lazily, as objects are next written, rather than forcing a mass re-encryption.

The limit stands regardless: a device that already decrypted an object keeps the plaintext. Dropping a wrap prevents future reads, not past ones.

### AAD binds the ciphertext to its slot

`aad` carries the object type, object id and family id in cleartext, authenticated but not encrypted. Without it, a valid ciphertext could be moved from one event to another, or between families, and still decrypt. With it, any such move fails authentication.

### Nonce

24-byte random nonce per encryption — XChaCha20's extended nonce makes random generation safe without a counter, which matters when several devices encrypt concurrently offline.

### Algorithm agility

`alg` exists so a future algorithm can be introduced. Decryption must support every value ever written; encryption always uses the current one. Do not remove old values.

### 4.1 Byte-level specification, v1

The sections above say what the envelope contains; this pins down exactly how, so two implementations produce and accept the same bytes. Implemented in `app/packages/crypto/rust` and fixed by the test vector below — if that vector's output changes, the format changed, and that means a new `v`.

**Encoding.** Writers emit CBOR in the core deterministic encoding of RFC 8949 §4.2.1: definite lengths, shortest-form integers, and map keys sorted by the bytewise order of their own encoding (so `n`, `v`, `ct`, `aad`, `alg`, `dek`). Readers accept any well-formed encoding of the same values. Nothing is authenticated over received bytes — only over associated data re-encoded by the reader — so encoding variation can't change what verifies.

**Envelope.** A CBOR map with exactly these text keys. Any other key is an error in v1; new fields mean a new version.

| Key | Type | Rule |
|---|---|---|
| `v` | uint | `1`. Read first; any other value is refused before the rest is parsed |
| `alg` | uint | `1` = XChaCha20-Poly1305 (32-byte key, 24-byte nonce, 16-byte tag) |
| `dek` | array of Wrap | At least one. Each group appears at most once |
| `n` | bstr | Exactly 24 bytes, random per encryption |
| `aad` | map | Exactly `t`, `id`, `fam`, each a non-empty tstr |
| `ct` | bstr | Ciphertext followed by the 16-byte tag |

**Wrap.** A map with exactly `g` (non-empty tstr, the group name), `e` (uint, the epoch) and `w` (bstr, exactly 72 bytes: a fresh 24-byte nonce, then the 32-byte DEK sealed, then its 16-byte tag).

**Keys.**

- DEK: 32 bytes from the OS CSPRNG, fresh for **every** encryption, including rewrites of the same object.
- GCK: 32 random bytes per group per epoch.
- Wrapping key: `KEK = HKDF-SHA256(salt = none, ikm = GCK, info = "fam.kek.v1", L = 32)`. The GCK is never used directly as a cipher key, which leaves it free to derive other keys later without reuse across purposes.

**Associated data.** Both are deterministic CBOR arrays. Each begins with a label and the format version and algorithm, so a downgrade or a cross-purpose substitution fails authentication rather than being misread.

```
AD_object = [ "fam.obj",  v, alg, fam, t, id ]
AD_wrap   = [ "fam.wrap", v, alg, g, e, fam, t, id ]

ct = XChaCha20-Poly1305(key = DEK, nonce = n,          ad = AD_object, pt = payload)
w  = wn || XChaCha20-Poly1305(key = KEK, nonce = wn,  ad = AD_wrap,   pt = DEK)
```

Binding each wrap to its group, epoch and object slot means a wrap can't be relabelled to another epoch or copied onto a different object. The spec above only required `aad = {t, id, fam}`; including `v` and `alg`, and binding the wraps too, is this section's addition.

**Opening.** Take the first wrap whose `(g, e)` the device holds a key for; if none, the result is *no access*. Unwrap the DEK and decrypt `ct`. Any authentication failure, in the wrap or the payload, is reported as *tampered* — never as a partial result.

**Rewrapping** (changing visibility, or moving to a new epoch): recover the DEK through any held wrap, verify it opens `ct`, then replace the whole `dek` array with fresh wraps. `n`, `aad` and `ct` are carried over unchanged. Verifying first stops a device from lending new audiences to a ciphertext it can't itself authenticate.

**The payload is opaque here.** The envelope encrypts bytes. The payload's own format — CBOR with `pv` and the preservation of unknown fields (§5) — belongs to the data layer.

**Worked example.** Fixed inputs, with the random source replaced by the byte counter `00 01 02 …`, drawn in order: DEK (32 bytes), payload nonce (24), then one wrap nonce (24) per audience.

```
object   t = "event", id = "evt-0001", fam = "fam-0001"
audience g = "all", e = 0, GCK = a0a1a2 … bebf (32 bytes counting up)
payload  a262707601657469746c6571466f6f7462616c6c20747261696e696e67
         (CBOR {"pv": 1, "title": "Football training"})

envelope
a6 616e 5818 202122232425262728292a2b2c2d2e2f3031323334353637
   6176 01
   626374 582d bf3b3dbd7a5260e24cd235cc0e286ea55f34bd50ffe774d4880f3547681e34c7
               fdd13f3d78f0e12d2e7af35a6b
   63616164 a3 6174 656576656e74 626964 686576742d30303031
               6366616d 6866616d2d30303031
   63616c67 01
   6364656b 81 a3 6165 00 6167 63616c6c
                  6177 5848 38393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f
                            d5844cb082680421d80ada8874b4ed110fc2459c35e8cba0
                            dcdbf13505088b6067abb222486939988c9b43f45981649a
```

The same vector lives in `app/packages/crypto/rust/test-vectors/envelope-v1.json`, alongside `verify_envelope.py`: a from-scratch implementation of this section in plain Python, sharing no code with the Rust crate, which decrypts it. The XChaCha20-Poly1305 primitive is also checked against its published vector (draft-irtf-cfrg-xchacha-03 §A.3.1).

---

## 5. Payload versioning

Two version numbers, deliberately separate:

- **`v` in the envelope** — the cryptographic format
- **`pv` inside the payload** — the field schema

```
EventPayload {
  pv: 3,
  title: tstr,
  notes: tstr,
  locationNote: tstr,
  equipmentSetId: tstr,
  ...
}
```

Three rules, absolute:

1. **Fields are only ever added.** Never removed, never repurposed, never have their type changed.
2. **Unknown fields are preserved on rewrite.** A `pv:3` client reading a `pv:4` payload it doesn't fully understand must carry the unrecognised fields through when it re-encrypts, or an old device will silently strip data a newer one wrote.
3. **Migration is lazy and client-side.** A device upgrades a payload's `pv` when it next writes that object. Old payloads may persist for years. The server cannot help — it cannot read them.

Rule 2 is the one that gets missed, and it's the one that loses data.

---

## 6. Permission-to-key mapping

The translation layer between the product spec's permission matrix and this design. Where the spec says "visible to X", this says which group holds the wrap.

| Spec rule | Wrapped to | Notes |
|---|---|---|
| Event `visibility: family` | `all` | Default |
| Event `visibility: parents_only` | `adults` | Child devices receive no readable copy |
| Event `visibility: participants` | `all` | Enforced in UI, not cryptographically — see below |
| Teen's private event | `adults` + that teen's device | Per-device wrap, no group needed |
| Homework | Owner's devices + `adults` | Per spec: parents see all homework |
| Care information | `care:{person_id}` | Helpers added per grant, removed on expiry |
| Wishlist items | `all` | Everyone sees the items |
| **Wishlist claims** | `wishlist:{id}:observers` | Owner's device is not in the group — the hidden-claims rule becomes structural |
| External wishlist share | Plaintext snapshot, scoped to one token | Deliberate publication, see section 8 |
| Meal plans, recipes, shopping | `all` | |
| Location trail | `adults` + the subject's own devices | Subject can always see their own |
| Actions, equipment | `all` | |
| Helper-visible content | `adults+helper:{id}` | Time-boxed; epoch bumped when the window closes |
| Cross-household child events | `custody:{child_id}` | Both households' adults |
| Chat | `mls:{conversation_id}` | Supervision = parent device in the group |

### Where cryptography is the wrong tool

`visibility: participants` and most tier-based restrictions are **UI-level, not cryptographic**. A kid-tier member and a teen-tier member are both in `all`; the difference between them is what the app offers, not what it could decrypt.

That's the right call. Encrypting every tier distinction would multiply groups beyond maintainability for restrictions that exist to reduce clutter and confusion, not to protect secrets. Reserve cryptographic separation for the cases where a member genuinely must not be able to read something: parents-only content, care information, wishlist claims, helper scoping, and chat.

Write this distinction down in the code — a `CryptographicallyEnforced` versus `UiEnforced` marker on each rule — so nobody later assumes a UI restriction is a security boundary.

---

## 7. Lifecycle flows

### Family creation

1. Founder device generates its identity keypair
2. Generates GCKs for `all` and `adults` at epoch 0
3. Wraps each to its own public key
4. Generates a **recovery code**: 20 characters, Crockford base32, ~100 bits
5. Derives a recovery key with **Argon2id** (memory-hard parameters tuned to ~1s on a mid-range phone)
6. Wraps every GCK to the recovery key; uploads those blobs
7. Onboarding does not complete until the code is confirmed re-entered

### Adding a second device (same or another adult)

Both devices are in the same room. The new device shows a QR code; a trusted family device scans it. Byte-level rules are in §7.1.

1. New device generates its identity and shows a pairing code holding its two public keys and a fresh random secret. It belongs to no family yet and has no device id, so that is all it can show
2. A parent's device scans the code. The keys it now holds came off the screen, not from the server
3. The parent chooses which member the device belongs to (claiming an existing member row, spec §9) and **registers** it with the server using the scanned keys. Only an authenticated family device can register another device
4. It sends an **admission**: the family, member and device id, and the family devices to trust, tagged with a key derived from the code's secret. Only a device that saw the screen can produce that tag. The server holds it at a **mailbox** whose address is also derived from the secret, since the new device can't authenticate before it knows its id
5. It publishes an **endorsement** — the new device's record signed by itself — so every other family device that trusts it learns the new device's keys without taking the server's word for them
6. It grants current-epoch GCKs to the new device (§3.1)
7. The new device collects the admission from its mailbox, verifies it, pins the listed devices, authenticates as its new device id from then on, accepts the grants, and begins decrypting from that epoch forward

*Earlier drafts compared a short authentication string read aloud. Derived only from the two public keys, such a string is forgeable: a malicious server substitutes its own key and searches offline for one whose string matches — about 10⁶ tries for six digits, which takes seconds. A scanned code carries the full keys, so there is nothing to search.*

A device added this way reads content written in earlier epochs only if those objects' DEKs were wrapped to a group epoch it holds. In practice, lazy rewrap on write means recent content is reachable and old content may not be. Accept this and surface it as "older items may not appear on a new device until they're next updated", or backfill by having the admitting device rewrap on demand.

### 7.1 Pairing by QR code, byte-level

Three formats, all version `1` and strict deterministic CBOR like the envelope. A **device record** is the map `{id: tstr, sig: bstr(32) Ed25519 key, kem: bstr(32) X25519 key}`.

**Pairing code** (new device → screen). `{v, sig: bstr(32), kem: bstr(32), k: bstr(32) random secret}`, rendered as the text `FAM1:` followed by unpadded uppercase base32 (RFC 4648) of the CBOR. Every character fits the QR alphanumeric mode. The secret never leaves the screen: it is not sent, logged or stored, and the session holding it is dropped when the pairing screen closes. Decoding accepts lowercase and rejects non-zero padding bits, so each code has exactly one reading.

**Mailbox.** `hex(HKDF-SHA256(salt = none, ikm = k, info = "fam.mailbox.v1", L = 16))`, 32 lowercase hex characters. The server learns the address, never the secret; the separate label keeps the address unrelated to the admission key, and 128 bits leaves nothing to guess.

**Admission** (scanner → new device, held at the mailbox).

```
{ v, fam, member, to: assigned device id, from: scanner id, devs: [device record, ...], tag: bstr(32) }

key = HKDF-SHA256(salt = none, ikm = k, info = "fam.admit.v1", L = 32)
tag = HMAC-SHA256(key, [ "fam.admit", v, fam, member, {id: to, sig, kem}, from, devs ])
```

The tag covers the family, member and device id the new device will adopt, and its own keys as the scanner read them, so the server can neither move the device to another family or member nor pass off substituted keys. `from` must be among `devs`. The new device verifies the tag in constant time (else *tampered*), then pins every device in `devs`. A retry shows a new code with a new secret, so an old admission fails against it.

**Endorsement** (scanner → the rest of the family, relayed by the server).

```
{ v, fam, dev: device record, by: endorser id, s: bstr(64) }
s = Ed25519.Sign(endorser, [ "fam.endorse", v, fam, dev, by ])
```

A device accepts it only from an endorser it already trusts (else *untrusted sender*), and only for its own family. Trust therefore grows outward from devices pinned by a scan, one signature at a time, and never from the directory alone.

**Worked example** in `app/packages/crypto/rust/test-vectors/pairing-v1.json`, continuing the grant example: the same parent phone admits the same child tablet, which then receives that grant and opens the envelope example with it. `verify_pairing.py` beside it re-derives the new device's keys from its secret and checks the code, the mailbox, the admission tag and the endorsement signature from the RFCs, sharing no code with the Rust crates.

**Server side.** Admissions and endorsements are opaque to the server, like wrapped keys, and routed only within the sender's family:

- `POST /v1/devices` registers a device, and only an authenticated parent device can call it, for a member of its own family. `POST /v1/members` adds a member row (a child, or a placeholder for the second parent) the same way. Nothing registers a device anonymously any more.
- `POST /v1/pairing/admissions` leaves an admission at a mailbox for one device; `GET /v1/pairing/mailbox/{mailbox}` collects it without authentication, since the new device can't authenticate yet; `DELETE /v1/pairing/admissions/{id}` acknowledges it once the new device authenticates as itself. Acknowledging is separate from collecting so a lost response loses nothing, and unacknowledged admissions expire after 24 hours.
- `POST /v1/pairing/endorsements` about one device, one per endorser (re-endorsing replaces it); `GET /v1/pairing/endorsements` for the whole family's.

### Provisioning a child's first device

Same flow, initiated by a parent, with the child's member row already existing. The child joins `all` at the current epoch and never receives `adults` keys.

### Granting a helper

1. Create group `adults+helper:{id}` at epoch 0
2. Wrap to parent devices and the helper's device
3. Objects the helper should see get an additional wrap on next write; the granting device rewraps the relevant recent objects immediately so the helper isn't looking at an empty calendar

### Expiring a helper

Bump the group epoch, excluding the helper. Stop adding wraps for them. Their device retains what it already decrypted — state this in the UI when granting access, because it is not obvious and it is not fixable.

### Enabling supervision on a child's DMs

Handled by MLS: the parent's device is added to the conversation group, which advances the MLS epoch. The parent can read from that epoch forward and not before. The child's thread shows a persistent marker.

### Disabling supervision

Remove the parent's device from the MLS group; the epoch advances and the parent's devices lose access to subsequent messages.

### A member leaving

1. Bump every group epoch they belonged to, excluding their devices
2. Revoke their device identity keys in the directory
3. Rewrap lazily as objects are written; rewrap recent objects eagerly
4. Their local copies are beyond reach — the spec's member-departure rules cover what happens to their authored content

### Recovery from the code

1. New device generates a keypair
2. User enters the recovery code; Argon2id derives the recovery key
3. Device fetches recovery-wrapped GCK blobs, unwraps, and admits itself
4. **Bump every group epoch afterwards**, because a recovery code may have been seen by others
5. Prompt to generate a fresh recovery code

### Total loss with no code

There is no path. The data is unrecoverable. This is why the architecture document requires a second trusted device before onboarding completes — the realistic protection is redundancy, not recovery.

---

## 8. Deliberate plaintext

Two places where content leaves the encrypted world, both explicit and both user-initiated.

**External wishlist shares.** The owner's device decrypts the item list and uploads a snapshot scoped to one share token, expiring with it. The prompt says exactly that. Nothing else in the family's data is affected.

**Read-only event share links** for carpooling work the same way: a snapshot of one event's public-facing fields, no more.

Both are recorded in an audit log visible in family settings, with a one-tap revoke that deletes the snapshot server-side.

---

## 9. Rotation policy

| Trigger | Action |
|---|---|
| Member or device added | Bump affected group epochs |
| Member or device removed | Bump affected group epochs |
| Helper window expires | Bump that helper group |
| Recovery used | Bump all group epochs |
| Suspected compromise | Bump all, revoke device keys, force re-provision |
| Routine schedule | **None** — rotation without a membership change adds cost without benefit here |

Rewrapping after a bump is lazy by default: objects get new wraps as they're next written. A background task on the admitting device can rewrap the most recent N objects eagerly so the experience isn't full of gaps.

---

## 10. Decisions still open

1. **How far back to eagerly rewrap** for a new device. Rewrapping a year of history on a phone is slow; rewrapping nothing makes a new device feel broken. A window of recent objects plus on-demand rewrap is probably right — needs measuring.
2. **Recovery code format and length.** 20 base32 characters is defensible; a 12-word mnemonic is easier to transcribe correctly and harder to lose. Test which your family actually writes down.
3. **Argon2id parameters** — tune on the oldest device you intend to support, not a flagship.
4. **Whether attachments get their own DEK** or inherit the parent object's. Separate is cleaner for thumbnails and partial fetches; inherited is simpler. Lean separate.
5. **Custody group governance** — which household can add members to `custody:{child_id}`, and what happens when the two disagree. This is a product question with a cryptographic consequence, and it should be answered before the custody feature is built rather than during.
