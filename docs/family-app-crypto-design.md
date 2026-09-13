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
| Device identity keypair | Keychain / Keystore, hardware-backed, non-exportable | Device lifetime |
| Group content key (GCK) | Derived and held per member device | Until group membership changes |
| Object data key (DEK) | Random per encrypted object | Object lifetime |
| Recovery key | Derived from the recovery code, never stored | Until recovery code is regenerated |
| MLS group keys | Managed by OpenMLS | Per epoch |

### Device identity

Each device generates, on first run:

- **Ed25519** signing keypair — authenticates the device
- **X25519** keypair — receives wrapped keys via HPKE

Private keys are generated in and never leave hardware-backed storage where the platform allows it. Public keys are published to the server's key directory, signed, and pinned by other family devices at provisioning time.

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

1. New device generates its keypair, publishes its public key
2. Existing device displays a **short authentication string** derived from both public keys
3. Both users compare the string out loud — this is the step that prevents a server-substituted key, and it must not be skippable
4. Existing device wraps current-epoch GCKs to the new device's public key
5. New device syncs and begins decrypting from that epoch forward

A device added this way reads content written in earlier epochs only if those objects' DEKs were wrapped to a group epoch it holds. In practice, lazy rewrap on write means recent content is reachable and old content may not be. Accept this and surface it as "older items may not appear on a new device until they're next updated", or backfill by having the admitting device rewrap on demand.

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
