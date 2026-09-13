# Family App — Technical Architecture

Companion to the product spec. Targets iPhone, iPad and Android, a .NET backend, and a real product rather than a personal tool.

---

## 1. The four constraints that decide everything else

Most of the stack falls out of these. Everything in section 2 is downstream.

1. **End-to-end encrypted chat.** No mature MLS implementation exists in C#, Dart or JavaScript. You will be wrapping a Rust library (OpenMLS) through FFI on the client, and the server becomes a dumb relay for ciphertext. This constrains the mobile framework more than any product requirement does.
2. **Offline reading, narrow offline writing.** Supermarkets have no signal and car parks have one bar, so reads must work offline. But the things a family does without signal are few and enumerable — tick an item, mark something done, send a message. That asymmetry lets you avoid a general sync engine entirely (section 6).
3. **Three form factors.** Phone, tablet and a wall-mounted kitchen display are three different layouts, not one scaled three ways.
4. **Background location and push on children's devices.** The most heavily gated permissions on both platforms, and the most scrutinised in store review.

---

## 2. Recommended stack

| Layer | Choice | Note |
|---|---|---|
| Mobile | **Flutter** | See section 3 — this is the contested one |
| Backend | **.NET 10, ASP.NET Core minimal APIs** | Plays to your existing C# depth |
| Database | **PostgreSQL 17+** with PostGIS | Not SQL Server — see below |
| Local DB | SQLite via Drift | |
| Client data | Local SQLite read cache + command queue | Server-authoritative; see section 6 |
| Realtime | WebSocket — change signals and chat | |
| Object storage | S3-compatible (MinIO locally, R2 or B2 in production) | Portable by design |
| Push | APNs and FCM directly | Data-only payloads, see section 8 |
| Jobs | Hangfire on Postgres | Transactional with your data |
| Hosting | Single VPS, Docker Compose, EU or Swedish provider | See section 13 |
| Identity | Own identity service, passkeys + device provisioning | Children have no email |
| Observability | OpenTelemetry → self-hosted or a free tier | |

**Why Postgres rather than SQL Server**, despite the Microsoft leaning: PostGIS for places and geofencing, native JSONB for the semi-structured fields the spec leans on, mature RRULE-adjacent tooling, and — decisively — the sync engines in this space are built on Postgres logical replication. SQL Server would mean giving up the sync engine and writing your own delta protocol.

---

## 3. Mobile framework — the argument

You're open to advice here, so here's the reasoning rather than just the answer.

**.NET MAUI is the trap.** It's the choice that matches your backend, and it's the wrong one for a consumer product on three form factors. The ecosystem is thin exactly where this app is demanding — background geofencing, notification service extensions, Rust FFI, custom high-performance calendar rendering — and every gap becomes a platform channel you write and maintain yourself. Don't pick a mobile framework to match a backend language; they share no code here.

**Flutter over React Native, for this app specifically:**

- **MLS binding.** `flutter_rust_bridge` is the most mature path to OpenMLS of the options, generating typed Dart bindings from Rust. React Native's JSI/Nitro modules can do it, but with more hand-written glue on a component that must not have bugs.
- **Calendar rendering.** Flutter draws its own widgets to a canvas. An agenda-week view with member lanes, tiled concurrent events and drag-to-reschedule is a custom-painting problem, and you get identical behaviour on both platforms rather than reconciling two native list implementations.
- **Adaptive layout.** Phone, iPad and kitchen display from one widget tree is Flutter's strong suit.
- **Consistency.** Three platforms, one rendering path, fewer "only on Android" bugs.

**Where React Native would win:** hiring (a much larger pool), and a richer third-party SDK ecosystem. If this becomes a team product and you expect to hire, that's a real counterweight. It's the defensible alternative, not a mistake.

**What stays native in either case**, written once per platform as a plugin: background location and geofencing, the iOS notification service extension for decrypting push payloads, home-screen widgets (SwiftUI WidgetKit and Glance on Android — these cannot be Flutter), watch complications, and the share-sheet extension for quick capture.

---

## 4. Client architecture

The encryption decision made this the bigger half of the system. The device holds the keys, the domain logic and the search index; the backend is infrastructure. Plan it with the seriousness you'd give a backend.

### Layers

```
UI shells            compact / medium / expanded, plus kitchen display
   ↓
State (Riverpod)     async notifiers, no logic in widgets
   ↓
Repositories         delta pull, command queue, cache reads
   ↓
Domain (pure Dart)   recurrence, conflicts, shopping generation, leave-by
   ↓
Local store          Drift over SQLCipher — decrypted content, encrypted at rest
   ↓
Crypto core (Rust)   OpenMLS, envelope encryption, key storage
   ↓
Platform plugins     location, notifications, widgets, secure storage
```

Two rules hold it together: **the domain package must not import Flutter**, and **all cryptography lives in Rust**. The first makes the hardest logic testable in milliseconds without a device. The second gives you one auditable implementation, callable from the app, from the notification extension, and from a web client later through WASM.

### Local store

Content is decrypted before it lands in SQLite, because a database of ciphertext can't answer "what's on Thursday". Protect the file with **SQLCipher**, keyed from iOS Keychain and Android Keystore, so it's unreadable off-device.

Keep two stores with very different guarantees:

- **The cache** — synced content. Disposable. Corruption is fixed by refetching, and there should be a "rebuild cache" path that loses nothing.
- **The command queue** — unsynced user intent. **Precious.** Ticked shopping items and completed actions that haven't uploaded exist nowhere else in the world. Separate file, separate backup treatment, never cleared by a cache reset.

Conflating those two is the bug that loses a family's shopping trip.

### State management

Riverpod, async notifiers per screen, compile-time-safe injection. Widgets render and dispatch; nothing else. Flutter tempts you to put a little logic in the widget — resist it here specifically, because the logic in question is recurrence expansion and departure timing, and you want it under unit test rather than a screenshot.

### Domain package

Pure Dart, no Flutter, no IO. The expensive correctness lives here:

- RRULE expansion with exception application
- Conflict and travel-gap detection
- Shopping list generation, unit conversion, merging
- Leave-by computation
- Permission resolution by role and tier

It carries the **golden test suites** — the DST and leap-day matrix, unit conversions, merge cases — running on every commit in seconds. That suite is the main reason the package exists separately.

### Background work

- **Periodic sync**: BGTaskScheduler on iOS, WorkManager on Android. Both best-effort; never let correctness depend on background execution firing.
- **Geofencing**: native plugins, OS-level, so the app needn't be running.
- **The notification service extension is the sharp edge.** A separate process with a tight memory budget that must decrypt an MLS payload — meaning the Rust core compiled into the extension and shared key access through a Keychain access group and App Group container.

  Design for it explicitly: give the extension a **minimal decryption subset** of group state rather than loading the full MLS state. Prototype it in the first month. It's the most common place this kind of architecture discovers it doesn't fit.

### Home-screen widgets

WidgetKit and Glance can't be Flutter — SwiftUI and Kotlin, written twice — and they can't decrypt anything meaningful in their own budgets.

So the app writes a **small pre-rendered payload** to the shared container on every sync: next three events, who's driving, next action due. The widget reads and displays it, and degrades to an "open the app" state when stale.

### Adaptive shells

One widget tree, breakpoint-driven rather than device checks:

- **Compact** (phone) — bottom navigation, agenda-week default
- **Medium** (tablet portrait, split view) — navigation rail, agenda plus detail pane
- **Expanded** (tablet landscape) — the full seven-column grid the product spec defers to this size
- **Kitchen display** — its own route: week, today's meal, shopping list, large targets, a device-scoped session rather than a member login, and **no chat keys provisioned to it at all**

### Performance

- The calendar is a **custom painter**, not a stack of widgets. Member lanes, tiled concurrent events and drag-to-reschedule are a painting problem.
- **Batch decryption**, and cache decrypted objects for the visible window. Decrypting per row inside a list builder will show.
- Virtualise everything long — agenda, chat, shopping.

### Project layout

A melos monorepo:

```
packages/
  domain/         pure Dart, no Flutter, golden tests
  crypto/         Rust + flutter_rust_bridge bindings
  data/           Drift schema, repositories, sync, command queue
  ui_kit/         design tokens, shared components
apps/
  family/         the Flutter app
  ios_native/     notification service extension, WidgetKit widget
  android_native/ Glance widget, geofence service
```

### Testing

| Layer | How |
|---|---|
| Domain | Pure unit tests and golden suites, every commit |
| Repositories | In-memory SQLite, command replay and idempotency |
| Crypto | Rust test vectors, plus two-device MLS interop tests |
| UI | Widget tests on key screens, golden images for the calendar |
| End to end | Real devices — push, geofencing, provisioning, recovery |

That last row can't be automated away. Push decryption, background location and device provisioning only fail on real hardware, and they are your three highest-risk client subsystems.

---

## 5. Backend shape

Modular monolith, not microservices. One deployable, clear internal boundaries, split later if a module actually needs its own scaling. At the size this will realistically reach, microservices buy you distributed transactions and nothing else.

Modules, mapping to spec sections:

- **Identity & families** — accounts, devices, members, invitations, roles, custody
- **Calendar** — events, occurrence expansion, exceptions, places, conflicts
- **Scheduling** — reminder materialisation, delivery queue, change detection
- **Meals** — recipes, plans, polls, shopping lists, import
- **Messaging** — key directory, ciphertext relay, delivery receipts
- **Media** — attachment metadata, presigned URL issuance
- **Sharing** — wishlist and event share tokens, the public web surface

The public wishlist page is a **separate deployable** — a small Razor or static app with its own rate limits and no access to the main API surface. It's the only unauthenticated door in the product; don't put it in the same process as everything else.

### Tenancy and data isolation

Every table carries `family_id`. Enforce it twice:

1. **Postgres row-level security**, with the family id from a session variable set per request. Defence in depth — a forgotten `WHERE` clause returns nothing rather than another family's calendar.
2. Repository-level scoping in EF Core via global query filters.

Cross-household custody is the one place that deliberately crosses the boundary, and it should be an explicit, audited read path rather than a relaxation of RLS.

---

## 6. Where data lives — and the "mother" question

Worth taking seriously rather than dismissing, because the instinct behind it is right: this app accumulates children's locations, health notes, schedules and photos, and the less of that sits on a server you operate, the better for everyone.

There are three shapes. Two of them break on the same thing.

### The three options

**A. Central server, family as the partition root.** Every row carries `family_id`, RLS enforces it, sync pushes each family its own bucket. This is the current design.

**B. A family hub — the "mother" device.** One designated device (a parent's phone, or the kitchen tablet) holds the authoritative family database. Other devices sync to it peer-to-peer. The server is a rendezvous point that stores nothing.

**C. Full peer-to-peer mesh.** No hub. Every device holds a replica, changes merge through CRDTs, the server relays when devices can't reach each other directly.

### What breaks B and C

**Push notifications.** This is decisive, not a detail. Only a server can talk to APNs and FCM. A hub device cannot reliably wake up to send the 16:45 departure reminder — it may be in a pocket, in a basement, or dead.

The obvious workaround is **on-device scheduled local notifications**, and it fails on a hard platform limit: iOS allows only **64 pending local notifications** per app. A family of five with activities, prep reminders, departure reminders, homework, actions and celebrations blows past 64 within about a week. You would be constantly rescheduling a rolling window on a device that may be asleep, and silently dropping reminders past the cap. The app's single most valuable function would become its least reliable one.

**Availability.** Hub offline means no one else can sync, a new device can't be provisioned, and the other parent's edit doesn't propagate. Families need the calendar to work when one phone is flat.

**Recovery.** Hub lost or broken means the family's data is gone unless they have been diligently backing up a phone. Families are not competent system operators, and they shouldn't have to be.

**Custody across two households** (spec section 3) requires data to cross a family boundary by design. A per-family hub makes the one structural feature you decided was core into the hardest thing in the system.

**The unauthenticated surfaces** — wishlist share pages, read-only event links — need a server regardless.

So B and C cost you reliability, recovery and your custody model, in exchange for a privacy benefit you can get more cheaply.

### What to do instead: keep the server, starve it

The goal behind the question — minimise what a central operator holds — is achievable without giving up the server. Three mechanisms, in increasing order of effort:

**1. Per-family data encryption key, with crypto-shredding.**
Each family gets a data encryption key, wrapped by a key-management service key. Sensitive columns — care information, location trail, wishlist claims, message ciphertext, attachment blobs — are encrypted under it. Deleting a family becomes deleting one key: the data is instantly unreadable everywhere, including in backups you can't otherwise reach. This makes GDPR erasure a single operation rather than a cascade across tables and snapshots, and it's worth doing for that reason alone.

**2. Split what the scheduler needs from what it doesn't.**
The server needs *when* and *who* in order to schedule and send. It does not need *what*.

Store event timing, recipients and kind in cleartext; store title, description, notes, location note and equipment as ciphertext the server cannot read. The push then carries only "you have something at 17:30", and the device decrypts locally and renders the real text — exactly the pattern already required for encrypted chat in section 9, so you build the mechanism once.

What the server still learns: that this family has an event on Thursday at 17:30 involving two members, at a place with these coordinates. That's real metadata, and you should say so plainly rather than claim more than you deliver. But it is a large reduction from holding the whole calendar in readable form.

The cost is honest too: server-side conflict detection, travel-gap warnings and search all need the fields they operate on. Timing and place stay readable precisely because those features depend on them.

**3. E2E for the genuinely sensitive categories.** Chat already is. Care information and the location trail are the next candidates — neither needs server-side processing, both are the most damaging to leak.

### The useful version of "mother"

Reframed, there *is* a per-family authority worth having — just not a data hub.

**A designated admin device.** The MLS design in section 9 already needs one: new devices are admitted to the family's key groups by an existing parent device confirming them out of band. That device is the family's root of trust for provisioning, and it's a real, named role in the product ("Anna's iPhone is this family's trusted device"), with a second parent device as backup so a single lost phone isn't fatal.

That gives you the property the hub idea was reaching for — the family, not the operator, controls who gets access — without making a phone in someone's pocket the availability bottleneck for the household's calendar.

### The partition question, separately

The other reading of "mother" — one root record per family that everything hangs off — is straightforwardly yes, and it's already the design. `family` is the aggregate root, every table carries `family_id`, RLS enforces it at the database, and sync buckets are keyed on it. Add the per-family encryption key above and that root becomes the unit of export, deletion and isolation as well as of querying.

The one deliberate exception stays custody: a child's events belong to the child and are readable by two family roots. Model that as an explicit, audited cross-reference rather than by weakening the partition.

---

### Everything is encrypted — no profile, no option

Single design: the family's content is encrypted on their devices under keys your servers never hold. No setting, no tiers, nothing to misconfigure. This is achievable, and it is a bigger change than it sounds, because **it moves most of the logic out of the backend.**

### What the server can still see

Be precise about this, internally and in the privacy copy, because "encrypted" gets overclaimed constantly.

**Cleartext, necessarily:**
- The membership graph — which accounts, members and devices belong to which family
- The family's name and home time zone, as set at creation. Member display names are not included — those are encrypted profiles. This is a deliberate exception: treat the family name as visible to the operator, and don't put anything in it you wouldn't show on a login screen
- Key packages and encrypted group state
- Ciphertext blobs, their sizes, and when they changed
- A delivery schedule: "send a silent push to device X at 16:45" — with no content attached
- Coordinate pairs passed to the routing proxy, unassociated with any family or event

**Ciphertext, always:** event titles, notes, equipment, homework, meals and recipes, shopping lists, wishlists, care information, attachments, location, chat.

So the server knows a family exists and what it is called, how many members it has, that something is scheduled at 16:45, and roughly how much data they store. It cannot read a single title, message, list or position. That is a truthful claim and it's the one to make.

### What moves to the client

With one Flutter codebase across iOS, iPad and Android, there is exactly one client implementation — which removes the objection to putting logic there.

Client-side now:

- **Recurrence expansion.** One Dart implementation, with the golden DST test suite moved to Dart and run in CI.
- **Conflict detection, travel gaps, unassigned-responsibility warnings.** The device holds the family's decrypted calendar; it doesn't need a server to notice two events needing the same driver.
- **Shopping list generation** from meal plans — expansion, unit conversion, merging.
- **Leave-by computation.** The device resolves the route (through the proxy), computes the departure time, and registers a bare `(device, timestamp)` with the scheduler. The server sends a contentless silent push; the device decrypts and renders the real notification text.
- **Search**, over the local decrypted index.

Server-side remaining: identity and device provisioning, ciphertext storage and delta sync, the notification scheduler as a dumb timer, the routing and unfurl proxies, object storage, and the opt-in share snapshots. It's a much thinner service than section 6 describes — closer to a sync and relay tier than an application backend.

**This is a real cost and worth naming:** your C# depth applies to less of the system, and Dart carries the hard logic. If that's the wrong trade for your team, the alternative is the split design from the previous draft, where timing and titles stay readable and the backend does the work. It is not possible to have both full encryption and a thick server.

### Permissions become key distribution

The sharpest consequence. A server that cannot read data cannot enforce field-level permissions — so the spec's visibility rules have to be expressed as **who holds which key**.

- A `parents_only` event is encrypted to parent devices only. A child's device never receives a decryptable copy, rather than receiving one and being asked not to look.
- Wishlist claims are encrypted to every member except the list owner — the hidden-claims rule from spec section 3 becomes structural rather than a query filter.
- Care information is encrypted to parents plus helpers explicitly granted it, for the window they're granted.
- Supervised DMs include a parent's device keys, as already designed.

Two implications to plan for:

1. **Changing visibility is a rewrap, not a re-encryption.** Because each object has its own data key wrapped once per audience, moving an event from family-wide to parents-only means swapping a few hundred bytes of wrapping — not re-encrypting content. See the crypto design document.
2. **Revocation is forward-only.** A device that already decrypted something keeps what it has. Rotating keys stops future access; it cannot un-read the past. True of every E2E system, worth stating in the product rather than implying otherwise.

### Recovery is now the highest-stakes UX in the app

If every family device is lost and the recovery material is gone, the data is gone. No support path, no reset, nothing you can do for them. Three mechanisms, all of them:

- **Device-to-device provisioning** — an existing parent device admits a new one. The everyday path, and the one that handles a replaced phone.
- **A recovery kit** generated during onboarding: a printable code that wraps the family key. Prompt to store it somewhere physical, and re-prompt until confirmed.
- **A second trusted device required before onboarding completes.** A family with one device holding the only keys is one dropped phone from losing everything. Push hard for a second parent device or a tablet during setup.

Encrypted server-side backups still work — they're ciphertext, restorable to a device holding the key.

### What the onboarding screen should say

Accurate, short, no overclaiming:

> Your family's calendar, messages, lists and photos are encrypted on your devices. Only people in your family can read them — we can't, and neither can anyone else.
>
> That also means we can't recover your data if every family device is lost. Keep your recovery code somewhere safe.

Avoid "military-grade", avoid "zero-knowledge" as a slogan, and don't imply the metadata above is hidden. The claim is strong enough without stretching it, and a privacy claim that turns out to be overstated is worse than not making one.

---

## 7. Client–server, with a read cache and a command queue

**Revising an earlier recommendation.** An earlier draft of this document reached for a general-purpose sync engine. On reflection that's over-built for this app, and the reason is worth stating precisely.

A bidirectional sync engine exists to solve *arbitrary offline editing* — any client changing any row at any time, merged later. This app doesn't need that. Look at what a family actually does without signal:

- ticks items off a shopping list in a supermarket
- marks an action or a piece of equipment done
- reads today's schedule in a car park
- sends a message

Nobody creates a recurring football season in a basement. The offline **read** surface is broad; the offline **write** surface is narrow and enumerable. Those want different machinery.

### The architecture

**The server is authoritative for structure, the client for content.** With full encryption (section 5), the backend owns identity, membership, ciphertext storage, the delta cursor, scheduling timestamps and the proxies. Recurrence expansion, conflict detection, travel gaps, shopping generation and search run on the device, because only the device can read the data they operate on. One Flutter codebase means one implementation of each, not three.

**Clients hold a local SQLite read cache**, not a replica. Delta sync per scope with an `updated_at` cursor:

```
GET /sync?scopes=family,member,child:{id}&since={cursor}
→ { changes: [...], deletes: [...], cursor: "..." }
```

Three scopes, matching the partition in section 5: `family`, `member`, and `child` for the cross-household case. Push a lightweight "something changed" signal over the WebSocket channel you already need for chat, and the client pulls. The cache is disposable — a corrupt or stale cache is fixed by refetching, which is not true of a replica holding unsynced writes.

**Offline writes are queued commands, not row state.** This is the part that makes it work:

```
POST /commands
{ client_command_id, type: "shopping_item.tick",
  payload: { item_id, state: "in_cart" }, issued_at }
```

Commands are idempotent, ordered per device, and replayed on reconnect. Two parents ticking the same item converge without a merge algorithm, because "tick this item" applied twice is the same as applied once — whereas two devices syncing conflicting row state have to be reconciled.

Maintain an explicit **allowlist of offline-capable commands**: tick a shopping item, check equipment, complete an action, mark homework done, RSVP, send a message, capture a photo. Everything else — creating events, editing recurrence, generating shopping lists, changing permissions — requires connectivity, and the UI says so plainly rather than accepting an edit it may later reject.

That honesty is a feature. A form that silently fails ten minutes later is worse than a button that's disabled with a reason.

### What this buys

- **Months of engineering.** No sync engine to operate, no CRDT semantics, no client-side schema migrations moving in lockstep with server ones.
- **Permissions are enforced by key distribution.** A child's device never holds data it shouldn't, because it never receives a copy it can decrypt — stronger than a server-side filter, and it survives a compromised client.
- **Data model changes get cheap.** Add a column, ship the server, clients pick it up on next delta. With a replica, every schema change is a migration running on phones you can't reach.
- **Debugging has one source of truth.**

### What it costs

- Complex editing needs connectivity. Acceptable — the spec's heavy editing flows are planning sessions done at a kitchen table.
- Cross-device realtime relies on your WebSocket channel rather than coming free with the sync engine. You need that channel for chat regardless.
- First launch on a new device needs a network round trip before the calendar renders.

### When to revisit

If the offline write allowlist grows past roughly a dozen command types, or if you find yourself wanting genuine multi-device concurrent editing of the same event, the calculus changes and a sync engine earns its place. Design the delta endpoint and the command queue so that swap stays possible — but don't pay for it on day one.

**Chat stays entirely separate** either way: ciphertext over its own WebSocket path and its own storage, never through the delta endpoint.

---

## 8. Recurrence engine

The highest-risk correctness area in the product.

- **Ical.Net** for RRULE parsing and expansion in .NET, with your own layer applying `event_exception` rows on top.
- **Expand server-side**, materialise a window, and sync the expanded occurrences down. Clients should not each implement RRULE expansion — that's three implementations disagreeing about the last Sunday in October.
- Store all timestamps as `timestamptz`; store the series' intended local time and IANA zone alongside, because a 17:30 training stays 17:30 across a DST change while the UTC instant moves.
- **A golden test suite**, run in CI: 02:30 events on both changeover nights, weekly series crossing March and October, monthly-by-weekday rules, 29 February birthdays, a family travelling across zones, and a series edited with each of the three scopes. Every calendar product breaks here; the ones that survive have this suite.

---

## 9. Scheduling and jobs

Hangfire backed by the same Postgres, so job state is transactional with your data and you don't run a separate broker early.

Three recurring jobs:

1. **Occurrence materialiser** — rolling 30-day window, re-run on any event, RRULE, exception or membership change.
2. **Delivery planner** — resolves rules and overrides into `notification_delivery` rows with the dedupe unique index.
3. **Sender** — claims due rows with `FOR UPDATE SKIP LOCKED`, sends, records the outcome.

The change-notification coalescer is a short delay queue keyed on `(event_id, occurrence_start, recipient)`, flushing after the edit window closes.

**The correctness requirement that matters most:** cancelling an occurrence must cancel its pending deliveries and its prep actions in the same transaction as the exception write. Use an outbox table rather than firing side effects inline.

---

## 10. Messaging subsystem

Keep this architecturally separate. It is the one part where the server is deliberately ignorant.

**Server responsibilities** (an MLS Delivery Service, roughly):

- **Key package directory** — devices publish key packages, others fetch them to add members
- **Ciphertext relay and store** — opaque blobs, ordered per group, fanned out over WebSocket
- **Group membership metadata** — who is in which group, needed for routing, visible to you
- **Nothing else.** No message content, no search index, no moderation hooks

**Client responsibilities**: OpenMLS through `flutter_rust_bridge`, key storage in iOS Keychain and Android Keystore, group state persisted locally, local full-text index over decrypted messages.

Supervision is implemented as group membership: a supervising parent's device keys are in the child's conversation group. Rotation on join means no retroactive access — which is both the privacy property the spec promises and a thing to test explicitly.

**Device provisioning** is the hardest UX in the build. Two paths, both needed: an existing parent device admits a new device after an out-of-band confirmation, and an encrypted backup recoverable with a code for the total-loss case.

---

## 11. Push notifications

Because payloads cannot carry message text:

- **iOS**: `mutable-content` push, decrypted in a Notification Service Extension, which has a tight memory budget and must load your MLS state — build and profile this early, it is a common late surprise.
- **Android**: data message, handled in a background service.
- **Fallback**: if decryption fails, show a generic "New message" rather than nothing.

Calendar and reminder notifications are not encrypted and can carry full text — but they'll leak family detail to APNs and FCM, which is worth one line in your privacy policy.

Talk to APNs and FCM directly rather than through an abstraction layer; you need per-platform control over silent pushes, and the abstraction costs more than it saves at this scale.

---

## 12. Third-party services

| Need | Options | Watch for |
|---|---|---|
| Geocoding | Google, Mapbox, or Lantmäteriet for Swedish addresses | Caching rights — several providers forbid storing coordinates, which breaks offline |
| Routing | Google Directions, Mapbox, HERE | Per-call cost; your learned-estimate model caps it |
| Transit times | Trafiklab (Swedish public transit) | Relevant for teens who take the bus |
| Maps display | Mapbox or platform-native | Native maps are free; Mapbox styles better |
| Recipe import | schema.org JSON-LD first, `recipe-scrapers` second | Run this in a small Python sidecar service; it's a Python library and rewriting it in C# is wasted work |

The recipe-scrapers sidecar is a pragmatic exception to the single-backend rule: a tiny containerised Python service behind an internal endpoint, doing one job.

---

## 13. Identity

Consumer identity with a twist the usual providers handle badly: **children may have no email address, no phone number, and sometimes no device.**

- Adults: passkeys as primary, email magic link as fallback.
- Children: an account is created by a parent as a member row with no credentials. When they get a device, an invitation token provisions it and binds the device to the member.
- Devices are first-class — each has its own identity and its own MLS key material.
- A shared kitchen tablet gets a **device-scoped session** with a restricted capability set, not a member login, and no chat keys.

Avoid Entra External ID here; it's built for a different shape of problem and the child-without-email case will fight it. A focused identity module in your own backend is less work than bending an IdP.

---

## 14. Hosting — local in development, cheap in production

The encryption decision helps here more than anywhere else. A backend that cannot read family data is a thin one — identity, ciphertext storage, a delta cursor, a timer, and two proxies. That fits comfortably on one small machine, and the hosting provider can't read anything even if you wouldn't otherwise trust them.

### What actually has to run

| Component | What it is |
|---|---|
| API | One ASP.NET Core container, HTTP + WebSocket |
| Database | PostgreSQL with PostGIS |
| Object storage | S3-compatible, for encrypted blobs |
| Scheduler | A hosted service in the same process |
| Reverse proxy | Caddy, for automatic TLS |
| Recipe sidecar | Small Python container for `recipe-scrapers` |

Five containers. No Redis early — Postgres handles the queue with `FOR UPDATE SKIP LOCKED`. No KMS, because with full end-to-end encryption there is no server-held family key to manage.

### Local development

**.NET Aspire** for orchestration. It spins up Postgres, MinIO and the sidecar as containers, wires connection strings into the API automatically, and gives you a dashboard with traces and logs across all of them. It's the natural fit for a C# developer and removes most of the Docker Compose fiddling.

```
dotnet run --project src/AppHost
```

brings up the whole stack; `dotnet watch` on the API for hot reload.

Two things specific to this app:

- **Testing on real phones.** The app needs HTTPS — iOS App Transport Security won't accept plain HTTP — and your phone needs to reach your laptop. Easiest path is a **Tailscale** tailnet across laptop and test devices, or a Cloudflare Tunnel if you want a real public hostname with real TLS. `mkcert` with a profile installed on the device also works but is more fiddly across two platforms.
- **Push notifications need real devices and real certificates.** Simulators can't receive APNs. Get the sandbox certificates working in the first weeks, not the last — the notification service extension decrypting an MLS payload is the riskiest single piece of client plumbing in the build.

Seed synthetic families with a `dotnet run seed` command. Never a copy of production data, which here means real children's data.

### Production, cheaply

**A single VPS running the same containers.** Docker Compose on one box, Caddy terminating TLS, Postgres in a container with a mounted volume.

Sensible providers, all EU:

| Provider | Where | Rough monthly |
|---|---|---|
| Hetzner | Germany, Finland | €4–8 for 2 vCPU / 4 GB |
| Netcup | Germany | Similar, often cheaper |
| Glesys, Elastx, Cleura | **Sweden** | Somewhat more, ~€15–30 |

For a Swedish family app, a Swedish provider is worth the premium as a product claim, not just a technical one — "your family's data stays in Sweden" is meaningful to the audience and costs you maybe €15 a month. Hetzner is the cheap default if that doesn't matter to you.

Object storage separately, because you don't want photos filling the VPS disk: **Cloudflare R2** (no egress charges, EU jurisdiction option) or **Backblaze B2**. Both are a few euros at this scale.

**Realistic early monthly total: €10–30**, plus routing API usage, which is the only line that scales with families rather than with time. The learned-estimate cache in the product spec exists to keep that near zero for repeated journeys.

### Keep the door open

The point of cheap hosting is that it shouldn't cost you anything to leave:

- **Use the S3 API, not a provider-specific storage SDK.** MinIO locally, R2 or B2 in production, anything else later — same code.
- **No provider-specific services.** No managed queues, no proprietary auth, no serverless bindings. Everything is a container and a connection string.
- **Postgres in a container now, managed Postgres later** is a `pg_dump` and restore, not a rewrite.
- Aspire is a development-time tool here. Don't adopt its Azure deployment path unless you decide to go to Azure.

### The part people skip

One box means you are the backup plan:

- Nightly `pg_dump` to object storage, encrypted, with a retention ladder.
- **Restore drills.** A backup you have never restored is a hypothesis. Do one before launch and one a quarter, timed.
- Uptime monitoring from outside the box, and alerting that reaches your phone.
- Automatic security updates, and a documented rebuild: how long from "the VPS is gone" to "serving again"? If you don't know, find out while it's still hypothetical.

The blobs and message bodies are ciphertext, so a backup leak isn't a data breach of family content. The membership graph is not encrypted, so treat backups as sensitive regardless.

### When to move off one machine

Not at a user count — at one of these:

- A restore would take longer than you can accept
- You have paying customers and downtime costs money
- Postgres and the API start competing for the same CPU under normal load

The next step is modest: keep the API on the VPS, move Postgres to managed (Neon, Supabase, or a provider's managed offering), then split the scheduler into its own container. Container Apps or similar only becomes worth its price well beyond that.

### Delivery

- **CI/CD**: GitHub Actions for backend and Flutter builds; Fastlane for signing and store upload; TestFlight and Play internal testing tracks. Deploy by building an image, pushing to a registry, and pulling on the VPS — a ten-line workflow, not a platform.
- **Environments**: local, staging, production. Staging can be a second container set on the same box early on; split it out when it starts mattering.
- **Migrations**: EF Core, expand-contract only. Clients run old versions for weeks after a release, and a destructive migration breaks phones you can't reach.

### Store review, worth planning for

- Background location plus children draws real scrutiny on both stores. Prepare the justification, the in-app rationale screens, and graceful degradation for "While Using" before submitting.
- Apple's rules for apps aimed at children restrict third-party analytics and advertising identifiers. Decide your age rating deliberately and keep the SDK list clean.
- Google Play's families policy requires a privacy policy covering children's data specifically.

---

## 15. Shipping new versions

Two problems wearing one name. Deploying the server is easy and you should make it boring. Deploying the client is genuinely hard, and it constrains how you design the API.

### The asymmetry that governs everything

**You cannot roll back a mobile release.** Once a build is on phones it is there until users update, and many won't for weeks. Store review adds a day or two before a fix even becomes available.

So the strategies invert. Server: deploy often, roll back instantly. Client: deploy carefully, roll *forward* only, and keep every remedy server-side — because the server is the only thing you can change today.

### Server deploys

**Use Kamal.** It does exactly this job: build an image, push it to a registry, pull and swap containers on one or more VPS hosts with health checks, zero-downtime cutover and a one-command rollback. It ships a proxy that also handles TLS, so it can replace Caddy. No daemon on the server, no platform to learn, config in one YAML file.

```
kamal deploy          # build, push, health-check, swap
kamal rollback        # previous image, seconds
kamal app logs -f
```

The alternative if you'd rather have a UI and git-push deploys is **Coolify** or **Dokploy** — self-hosted PaaS on the same VPS, with TLS, preview environments and a dashboard. More moving parts, less typing. Either is fine; the thing to avoid is hand-rolled SSH scripts, which work until the day they don't.

GitHub Actions builds the image on merge to main and calls the deploy. That's the whole pipeline.

### Migrations, with a constraint most projects don't have

Standard rule first: **expand-contract, always.** Add a column, deploy code that writes both, backfill, deploy code that reads the new one, drop the old one a release later. Never a destructive migration in the same release as the code that needs it, because phones running last month's build are still calling you.

Run migrations as a separate step before the app swap, idempotent, from a dedicated container.

**Then the constraint that's specific to this design: you cannot migrate encrypted data.** The server can't read event titles, lists or messages, so it can never run a backfill over them. That has three consequences worth building for from day one:

- **Version every encrypted payload** — a `v` field inside the envelope, before encryption.
- **Migrate lazily, on the client, on write.** A device reading a `v2` payload upgrades it to `v3` the next time it saves. Old payloads may sit unmigrated for years; that has to be fine.
- **Additive only, forever.** Never remove or repurpose a field in an encrypted payload. An old client must ignore what it doesn't recognise, and a new client must read every version ever written.

This is the price of the encryption decision and it's paid in discipline rather than money. Get the envelope format right early, because it is the one thing you genuinely cannot fix later with a migration.

### API compatibility

- **Support at least the last two client versions**, realistically more. Instrument which versions are actually in use before dropping any.
- **Tolerant readers on both sides** — ignore unknown fields rather than erroring.
- **Version the API path** (`/v1/`), and add endpoints rather than changing them.
- **A minimum-supported-version endpoint**, checked on launch: returns a soft nudge banner, or a hard block reserved for security issues only. Build this before your first release; retrofitting it is impossible, because the clients that need it are the ones that don't have it.

### Remote config and kill switches

Since you can't ship a client fix today, the server needs to be able to turn things off.

A simple config endpoint, cached locally, driving per-feature flags scoped by family and client version. Every non-trivial feature ships behind one. When the travel-time estimator misbehaves on Android 14, you disable it for those clients in a minute instead of waiting on review.

This is not optional infrastructure for a mobile product with a slow release path — it's the release valve.

### Flutter code push

**Shorebird** pushes updated Dart code to installed apps without a store submission. Given that the encryption decision moved recurrence expansion, conflict detection, shopping generation and leave-by maths into Dart, a large share of your likely bugs now live in exactly the layer Shorebird can patch — a recurrence bug fixed in hours rather than days.

Honest caveats: it's a paid third-party dependency in your release path, it can't patch native plugin code, and store policy on downloaded executable code is a judgement call — verify Apple's current position yourself rather than taking a vendor's word or mine. Worth evaluating after your first release, not before.

### Staged rollout and knowing when it's bad

- **Play staged rollout** and **App Store phased release**, both on, starting small. Halting a rollout is the closest thing to a mobile rollback you have.
- **Crash and error reporting** — Sentry, self-hostable to keep data in your own infrastructure. Watch crash-free-sessions per release; a drop is your signal to halt the rollout.
- Keep release cadence regular and small. Large infrequent releases make every rollout a high-stakes event, which is the opposite of what you want when rollback isn't available.

### What this means for tech choices

- **Kamal** over bespoke deploy scripts.
- **Flutter**, already chosen, gains a second argument here: one codebase means one release to coordinate rather than two diverging native ones.
- **Server thin, client thick** — already forced by encryption — makes client releases *more* consequential, which is precisely why the flags, the version floor and the payload versioning above are not optional.

---

## 16. What still needs a plan before building

Both documents describe *what* and *how*, and there are still artefacts missing that will block or misdirect work on day one. In rough priority.

### Must exist before the first commit

**1. The encrypted payload envelope.** The one thing you cannot fix later with a migration. Specify: envelope structure, the `v` field, which algorithm and mode, nonce handling, associated data, and the rule that fields are only ever added. Write it as a document with worked examples before any code writes a payload.

**2. Key hierarchy and lifecycle, as flows.** Not prose — actual sequence diagrams for: family creation, second device joining, child device provisioning, helper granted and expiring, supervision enabled and disabled, recovery from code, and total device loss. Each one has an edge case that will otherwise surface as a bug in month four.

**3. Permission-to-key mapping.** The spec's permission matrix is written for a server that enforces it. Now that permissions *are* key distribution, you need a table mapping each visibility rule to a concrete key group — `parents_only`, wishlist-claims-minus-owner, care info, supervised DMs, cross-household custody. This is the translation layer between the two documents and it does not exist yet.

**4. The API contract for the v1 slice.** OpenAPI, covering identity, delta sync, the command queue, scheduling registration and the proxies. It's small under this architecture, which is exactly why it's cheap to write now and expensive to discover later.

**5. Domain glossary.** Decide once whether code says `member` or `familyMember`, `action` or `task`, and whether Swedish domain terms (lov, vecka, namnsdag) appear in code or only in the UI layer. Both documents have already drifted once — `task` became `action` mid-spec. Pin it.

**6. v1 acceptance criteria.** A written definition of done for the first release: which screens, which commands are offline-capable, what "works" means for reminders. Without it, v1 expands continuously, which section 19 already names as the highest risk in the project.

### Must exist before the first external user

**7. A DPIA.** Children's data, location, and health information together almost certainly trigger the requirement for a Data Protection Impact Assessment under GDPR Article 35. This is not optional paperwork for a product with this data profile, and it's easier written alongside the design than reconstructed afterwards. Worth a lawyer's review, not just a template.

**8. Privacy policy and terms**, including a children's-data section that Google Play's families policy requires specifically, and a description of what your servers can see that matches section 6 honestly.

**9. A support and incident plan.** When a family loses all devices and their recovery code, what does support say? There is no technical answer — so decide the human one in advance, and write it into the recovery screens.

**10. Analytics policy.** You've made a strong privacy claim; decide now what telemetry is compatible with it. Crash reports and per-rule notification counts probably are. Third-party SDKs with advertising identifiers are not, and Apple's rules for apps aimed at children restrict them anyway.

### Start immediately, because of lead time

**11. Apple Developer Program enrolment.** $99/year. Individual enrolment is usually quick; enrolling as a company needs a D-U-N-S number and can take weeks. If this is a real product you'll want the company route eventually — start it now, in parallel with everything else.

**12. Google Play Console**, $25 one-time.

**13. Name, domain and bundle identifiers.** The bundle ID is effectively permanent, and TestFlight tester pools are per bundle ID.

### Deliberately not needed yet

Design system beyond tokens and two key screens, marketing site, pricing model, App Store assets. All real, none blocking, and all cheaper once the app exists.

---

## 17. Getting builds onto family devices

Your family is your first test group, which is the best position a product like this can be in — and both platforms support it well.

### The zero-cost path

Worth knowing before you spend anything: the two platforms are completely different here.

**Android is free, permanently.** No account, no fee, no review. Build a signed APK and install it. Three ways to get it onto family devices:

1. **Send the file.** Share the APK, they allow installs from unknown sources once, done. Zero infrastructure, but no automatic updates, which wears thin by the third build.
2. **GitHub Releases + Obtainium.** Push each build as a release asset; family members install Obtainium once and point it at your repo. They then get update notifications and one-tap updates, exactly like a store, for nothing. This is the best free option and it's what I'd use.
3. **A self-hosted F-Droid repository**, if you want something more store-like. More setup, same result.

One thing to get right immediately: **create your signing keystore and back it up properly.** If you later publish to Play you can enrol in Play App Signing, but an APK signed with a lost key can never be updated — family devices would have to uninstall and lose local data, which under this architecture means their command queue.

**iOS is not free in any practical sense.**

- A free Apple ID plus Xcode installs onto *your own* device with a **7-day certificate expiry**. You re-sign weekly, from a Mac, over cable or local wifi. Tolerable for your own phone during development. Not something to ask a family member to do.
- Sideloading tools (AltStore, Sideloadly) use the same free-account mechanism and inherit the same 7-day limit. AltStore's companion service can refresh automatically while on the same wifi, but it's fragile and each device needs setting up.
- The EU alternative-distribution routes opened by the DMA all require a paid Apple Developer membership anyway, plus notarisation, so they don't help here.

**The blocker that matters most: you cannot test push notifications on iOS without a paid membership.** The push entitlement requires it. Given that reminders are the core of this product, iOS is effectively untestable for its main feature until you pay the $99. A Mac is also required to build for iOS at all, which may be the larger cost if you don't have one.

### What this suggests for sequencing

Build Android-first, at zero cost, for as long as you can:

- Android covers everything architecturally interesting — the Rust crypto core, the domain layer, local storage, the command queue, background sync, geofencing, and push through FCM, which is free.
- Distribute via GitHub Releases and Obtainium to whichever family devices are Android.
- Keep iOS compiling but unreleased. Flutter makes this cheap; the iOS-specific work — notification service extension, WidgetKit — is a later phase that needs the Mac and the membership regardless.
- Pay the $99 when you need iOS family testing or push verification, not before.

**A Flutter web build** is also worth keeping alive as a free way to show screens to people and check adaptive layouts. Not a product — no background location, and the crypto core would need WASM work — but useful, and it costs nothing to host.

### iOS — TestFlight

Requires the Apple Developer Program at $99/year; there is no free distribution path on iOS.

Use **internal testers**: up to 100 people, each on up to 30 devices, builds available within minutes of upload with **no beta review**. External testers (up to 10,000) need a review pass on the first build of each version — irrelevant for family testing, useful later.

The flow:

1. App Store Connect → Users and Access → invite each family member's Apple ID with the Developer or App Manager role.
2. Assign them to the Internal Testing group on the app's TestFlight tab.
3. They install the TestFlight app, accept the invite, and get every new build automatically with a notification.

Two things to plan around: **builds expire 90 days after upload**, so a quiet period means everyone's app stops launching — push a fresh build at least quarterly. And **TestFlight builds use the production APNs environment**, while development builds use sandbox, so your push certificates and server configuration have to handle both. Given how central reminders are here, get that right early.

For your own device before enrolment completes, a free Apple ID can install via Xcode with a 7-day certificate expiry. Fine for your phone, not for the family.

### Android — Play Console internal testing

$25 one-time. The **internal testing track** takes up to 100 testers, publishes within minutes, and has no review wait. Testers opt in via a link and receive updates through Play normally.

Simpler still for early iteration: **send the APK directly**. Build, share the file, they enable installing from unknown sources. No accounts, no waiting — but no automatic updates either, which gets old by the third build.

### Both at once

**Codemagic** is Flutter-native CI and will build both platforms and publish to TestFlight and the Play internal track from one workflow. **GitHub Actions with Fastlane** does the same with more setup and no per-build cost. Either way the goal is one command: merge to main, both families' devices get the build.

**Firebase App Distribution** is the third option, covering both platforms with tester notifications, free. It works well, though it means a Google dependency in a product whose privacy positioning is a selling point — not a real data risk, since it distributes binaries rather than user data, but worth a conscious decision.

### What actually gets reviewed

Useful to be precise, because "app review" covers several different gates:

| Route | Review? | Typical wait |
|---|---|---|
| Android sideload / Obtainium | **None** | — |
| Play internal testing track | None in practice; policy checks only | Minutes |
| Play closed or open testing | Yes | Hours to days |
| Play production | Yes | Hours to days |
| TestFlight **internal** testers | **None** | Minutes |
| TestFlight **external** testers | Yes, first build of each version | Usually ~24h |
| App Store production | Yes, full review | Usually ~24h, longer for new apps |

So both platforms let you test with your family without any review at all — the difference is only that one of the two routes costs $99.

One thing to check when you do go to production: Google has required new **personal** developer accounts to run a closed test with a minimum number of testers over a continuous period before production access is granted. Verify the current rule when you enrol, since it affects your timeline rather than your architecture — and registering as a company rather than an individual changes what applies.

### The kitchen tablet

Treat it as a real device in every sense: its own provisioning, its own restricted session, and explicitly **no chat keys**, per section 4. Testing the display mode early is worthwhile — it's the surface most likely to reveal that your adaptive layout assumptions don't hold.

### Testing with your own children

You'll be running real family data through a pre-release build, which is the right way to find out whether the product works. Two things worth deciding deliberately: tell the children what the app can see, since the product's whole stance is that they should know, and keep a way to wipe and restart cleanly — early builds will corrupt local state, and you don't want the recovery path for that to be "lose the family's calendar".

---

## 18. Android: signing, local builds, and the path to Play

Android-first with a Play release later is a good plan, and it works cleanly — provided three decisions are made now rather than discovered at publish time.

### Decide these before the first build

**1. The application ID is permanent.** Something like `se.yourdomain.family`. It cannot change after a Play release, and changing it before then means every family tester uninstalls and loses local data — which under this architecture includes their unsynced command queue. Pick it once.

**2. Generate your release signing key now and guard it.**

```bash
keytool -genkeypair -v \
  -keystore family-release.jks \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -alias family
```

Back it up in two places — a password manager and something offline. An APK signed with a lost key can never be updated; the only remedy is a new application ID and a clean reinstall for everyone.

**3. Plan for signature continuity into Play.** This is the one most people get wrong.

Play requires **Play App Signing**. When you first publish you choose between letting Google generate a fresh app signing key, or **uploading the key you've been signing your sideloaded builds with**. Choose the second. Then family devices that have been running your local builds upgrade in place when you switch to Play — same signature, same data. If Google generates a new key, every tester has to uninstall first and loses everything local.

After enrolment you generate a separate **upload key** for submitting builds. Google re-signs with the app signing key on their side.

### Build configuration

Sign release builds properly from day one — don't test debug builds. R8 shrinking, ProGuard rules for the Rust FFI and Drift, and real performance characteristics all differ, and you want those problems now rather than the week you publish.

```
android/key.properties        # gitignored, local only
storePassword=…
keyPassword=…
keyAlias=family
storeFile=../family-release.jks
```

**Flavours** so builds can coexist on one phone:

| Flavour | Application ID | Signing |
|---|---|---|
| `dev` | `se.yourdomain.family.dev` | debug |
| `prod` | `se.yourdomain.family` | release key |

Family testing uses `prod` builds, signed with the release key, so the upgrade path to Play is a straight line.

**`versionCode` must increase strictly and monotonically**, for Play and for sideloaded upgrades to register as upgrades. Derive it from the CI run number or a timestamp rather than hand-editing:

```
versionCode = CI run number
versionName = 0.4.2+<short git sha>
```

### Two artefacts, one key

- `flutter build apk --release` → a universal **APK** for sideloading
- `flutter build appbundle --release` → an **AAB** for Play, which no longer accepts APKs

Both signed with the same key, so they're interchangeable from the device's point of view.

### The free distribution pipeline

GitHub Actions on a tag push, using the free tier:

1. Checkout, set up Flutter, build the Rust core
2. Decode the keystore from a base64 repository secret
3. `flutter build apk --release`
4. Attach the APK to a **GitHub Release**

Secrets needed: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`. The keystore file itself never enters the repository.

Family members install **Obtainium** once, add the repository URL, and from then on get update notifications and one-tap installs. Functionally a private app store, costing nothing.

When you're ready for Play, the same workflow gains a second job building the AAB and uploading through Fastlane to the internal track. Nothing about the earlier setup gets thrown away.

### Play requirements worth knowing now

Two will shape your code and timeline rather than just your paperwork:

**Background location needs a declaration and usually a demo video.** Play reviews apps requesting `ACCESS_BACKGROUND_LOCATION` specifically, asking you to justify why the feature can't work with foreground access only. Plan the justification alongside the feature — and note that the product spec's preference for geofenced arrival events over continuous tracking is a much easier case to argue than "we show a live map".

**Apps directed at children fall under Play's Families policy**, which restricts SDKs, requires a specific privacy policy, and adds review steps. Decide your target audience declaration deliberately; an app used *by* children but aimed at parents is a different declaration from one aimed at children, and it changes what applies.

Also: Play enforces a minimum `targetSdk` that advances yearly, the Data Safety form must match what your app actually does, and a privacy policy URL is required before publishing. New personal developer accounts have additionally had to run a closed test with a minimum number of testers over a continuous period before production access — verify the current rule when you enrol.

### Android reliability notes specific to this app

- **Background location on Android 10+** needs a separate grant flow after foreground permission, with its own rationale screen.
- **OEM battery management** — Xiaomi, Huawei, Samsung and others aggressively kill background work regardless of what the framework promises. Geofencing survives better than periodic tasks, which is another reason the product spec prefers arrival events. Test on at least one non-Pixel device before trusting reminders.
- **FCM is free** and has no equivalent of Apple's paid gate, so the full reminder pipeline is testable at zero cost.

---

## 19. Build order

The product spec's v1 assumes chat exists. From an engineering standpoint, invert that:

1. **Foundation** — identity, families, members, invitations, onboarding, RLS, and the delta-sync plus command-queue plumbing proven end to end on one entity.
2. **Calendar core** — events, recurrence engine with the golden test suite, places, occurrence projection, agenda-week view, member filtering, responsible adult, conflict detection.
3. **Reminder pipeline** — materialiser, delivery queue, change notifications, push plumbing with plaintext payloads.
4. **Ship it.** A family calendar with good reminders and no chat is already worth using, and it gets real families onto the data model before the expensive part.
5. **Messaging** — MLS, key directory, provisioning, recovery, encrypted push. Treat this as its own project with its own timeline.
6. Everything else in the product spec's v2 order.

**Chat cannot be retrofitted as encrypted**, which is exactly why it should ship late rather than early — there's no plaintext history to migrate if you never stored any.

---

## 20. Risk register

| Risk | Severity | Mitigation |
|---|---|---|
| Total key loss — family loses all devices | **Highest** | Three mechanisms: device provisioning, recovery kit, and a required second device before onboarding completes |
| Client-side logic weight in Dart | High | Golden test suites in Dart; accept that C# covers less of the system |
| Encrypted payload schema locked in early | High | Version the envelope from the first commit; additive changes only, lazy client-side migration |
| Bad mobile release with no rollback | Medium | Staged rollout, feature flags, minimum-version endpoint, crash-free-session monitoring |
| Recurrence and DST correctness | High | Golden test suite in CI from week one |
| Notification service extension memory limits | Medium | Prototype in the first month, not the last |
| Background location reliability across OEMs | Medium | Geofences over polling; degrade to last-known with timestamps |
| Store rejection over children plus location | Medium | Rationale screens and clean SDK list before first submission |
| Geocoding licence forbidding caching | Medium | Settle the provider contract before building against one |
| Scope | **Highest** | The spec is a multi-year product. Steps 1–4 above are one coherent release; resist bundling more into it |

The last row is the real one. The product spec describes something genuinely large, and the most likely failure is not a technical one — it's building four subsystems to 70% instead of one to shipping quality.
