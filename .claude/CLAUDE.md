# Family App

A family organiser for iPhone, iPad and Android. Flutter client, .NET backend,
PostgreSQL. End-to-end encrypted: **the server cannot read family content.**

## Read these before changing anything structural

- `docs/family-app-spec.md` — product model, entities, permission rules
- `docs/family-app-architecture.md` — stack, sync, hosting, release
- `docs/family-app-crypto-design.md` — envelope format, key hierarchy, lifecycles

These documents are the source of truth for *why*. When code and documents
disagree, one of them is wrong — say which, don't silently pick.

## Layout

```
backend/src/Family.Api/     ASP.NET Core, EF Core, Postgres
app/                        Melos monorepo (architecture doc §4 "Project layout")
  packages/domain/          Pure Dart. No Flutter, no IO. Golden tests live here
  packages/crypto/          Rust + flutter_rust_bridge bindings. Envelope only so far
  packages/data/            Payloads, encrypted Drift store, command queue, sync
  packages/ui_kit/          Design tokens, shared components (not yet built)
  apps/family/              The Flutter app. Shell and placeholder screens only
  apps/ios_native/          Notification service extension, WidgetKit widget
  apps/android_native/      Glance widget, geofence service
docs/                       Design documents
infra/                      Compose files, deploy config, CI
scripts/                    Dev tooling
secrets/                    Gitignored. Keystore, local credentials
```

The architecture doc shows `packages/` and `apps/` at the repo root; here they
sit under `app/` so the backend and client stay side by side. Same structure,
one level down.

## Invariants — do not break these without saying so explicitly

1. **The server never sees plaintext content.** Objects are opaque `Envelope`
   byte arrays plus routing metadata (kind, scope, sequence, version). If a
   change adds a server-side field holding a title, name, note or list item,
   stop and flag it — that is an architecture change, not an implementation
   detail.

2. **The domain package never imports Flutter.** It must stay runnable under
   plain `dart test` in milliseconds.

3. **Encrypted payloads are additive only.** Fields are never removed,
   repurposed, or retyped, and unknown fields are preserved on rewrite. There is
   no migration path for data the server cannot read.

4. **Recurrence expands in wall-clock local time plus an IANA zone**, never in
   UTC. The golden tests encode this. If one fails, fix the code.

5. **Offline writes are commands, not row state.** Idempotent on
   `(DeviceId, ClientCommandId)`. The allowlist in `CommandEndpoints.Allowed` is
   deliberately short — adding to it is a decision worth stating.

6. **Cancelling an occurrence must cancel its scheduled wakes and prep actions
   in the same transaction.** This is the failure that destroys trust in every
   other reminder.

## Commands

```bash
# backend — dev Postgres is on port 5433, either Docker or a native install
cd backend && docker compose up -d        # or once, natively: psql -p 5433 -U postgres -f scripts/dev-db-setup.sql
dotnet tool restore
dotnet run --project backend/src/Family.Api   # launchSettings: Development, port 5080
dotnet ef migrations add <Name> --project backend/src/Family.Api

# end-to-end smoke test against the running API — run after any backend change
# (pwsh is a .NET global tool here: dotnet tool install --global PowerShell)
pwsh scripts/smoke-test.ps1 -BaseUrl http://localhost:5080

# domain tests — run these constantly, they are fast
cd app/packages/domain && dart test

# app workspace — run from app/. `flutter pub get` resolves every package at once
dart run melos run analyze
dart run melos run test:app
cd app/apps/family && flutter run --flavor dev   # Android needs a flavour: dev or prod
# The app talks to API_BASE_URL (default http://10.0.2.2:5080, the host as seen
# from the emulator). For a phone, run the API on all interfaces and pass the
# Mac's LAN address:
#   dotnet run --project backend/src/Family.Api --urls http://0.0.0.0:5080
#   flutter run --flavor dev --dart-define=API_BASE_URL=http://<mac-ip>:5080
# Pairing flow against a live backend (the on-device suite includes it):
#   flutter test integration_test --flavor dev -d <emulator> --dart-define=API_BASE_URL=http://10.0.2.2:5080

# crypto core — Rust tests, then the bridge on a real device or emulator
cd app/packages/crypto/rust && cargo test && cargo clippy --all-targets -- -D warnings
cd app/packages/crypto && flutter_rust_bridge_codegen generate   # after changing rust/src/api
cd app/apps/family && flutter test integration_test --flavor dev -d <device>
```

## Conventions

- C#: file-scoped namespaces, records for DTOs, minimal APIs over controllers.
- Dart: `lints/recommended`, no `print`, prefer final locals.
- Naming follows the spec's glossary: `member`, `action` (not task), `person`,
  `place`, `occurrence`. Swedish domain terms (lov, vecka, namnsdag) appear in
  the UI layer only, never in code identifiers.
- Migrations are expand-contract. Never destructive in the same release as the
  code needing it — old clients are still calling.

## Current state

Working: backend sync and command endpoints, key directory, contentless wake
scheduling, recurrence expansion with its golden suite. Flutter app scaffold:
Riverpod, go_router, adaptive shell (bottom nav / rail by width), placeholder
screens, Android dev/prod flavours with release signing from key.properties.
Application ID `io.github.johancarlstedt.family` — permanent, don't change it.

Crypto core: the v1 envelope (crypto doc §4.1), device identity (§2.1), signed
HPKE group key grants (§3.1) and QR pairing with admissions and endorsements
(§7.1), in Rust with test vectors, bridged to Dart.
Dart holds opaque `Device` and `Keyring` handles; group key bytes never cross the
bridge, and a keyring is persisted as grants to the device itself. The formats
are pinned by `rust/test-vectors/*.json` and checked by from-scratch Python
verifiers beside them; if a vector test fails, the wire format changed, which
needs a new `v`, not a new expected value. After editing the vectors, run
`generate_dart_vectors.py` to refresh the on-device test.

Backend: pairing relay for admissions and endorsements (crypto doc §7.1).
Anonymous access is by exact method and path (health, create family) plus the
pairing mailbox; everything else needs a device. Only a parent's device can add
members or register devices, and the key directory answers only for the
caller's own family.

The device secret lives in `DeviceVault` (Keystore / Keychain via
flutter_secure_storage, crypto doc §2.1). Its reset-on-error default is off on
purpose, and Android shared preferences are excluded from backup; keep both.

App: first-run onboarding (create a family with your name, or join by showing
a QR code), More → Add a device (scan, naming a new member), and Today → New
event. Today reads real content from packages/data: an encrypted cache and a
separate command queue (SQLite3 Multiple Ciphers), synced at start, after each
edit and every 30 s. Group keys are rebuilt from the server's grants at start,
so the app needs the network to open for now. The sample family is for widget
tests only.

Wall-clock times travel as `DateTime.utc(y, m, d, h, min)` fields everywhere; a
local DateTime silently moves DST-gap times through the device's zone.

This Mac has 8 GB: Colima runs with 2 GB, and a sluggish emulator usually needs
a cold restart (`adb emu kill`, then `emulator -avd Pixel_Android_36
-no-snapshot-load`) rather than code changes. Measure startup on a profile build.

Not built yet: recovery (Argon2id), MLS, Drift local store, real Flutter screens, iOS
flavours (need Xcode schemes), FCM handling,
real device authentication (currently a header lookup — replace before anyone
outside the household uses it).

## How I'd like you to work here

- Prefer reading the relevant doc section over inferring intent from code.
- Write the test first for anything in `domain/` — that package exists to be
  provable.
- Small commits, one subsystem at a time.
- If something in the design looks wrong, say so rather than implementing around
  it. Several decisions here were reversed during design and would be reversed
  again on good evidence.
