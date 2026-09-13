# Family App — foundation

First working slice. Two pieces, chosen because everything else depends on them:
the backend's sync and command plumbing, and the pure-Dart recurrence engine.

**Not compiled or run.** The environment this was written in has neither the
.NET SDK nor Dart, so treat the first build as a debugging session rather than a
formality. The shapes and the reasoning are the deliverable; expect to fix
package versions and a few signatures.

```
backend/
  docker-compose.yml              Postgres (PostGIS) + MinIO for local dev
  src/Family.Api/
    Domain/Entities.cs            Server-side model — deliberately blind to content
    Data/AppDbContext.cs          Indexes, the sync sequence
    Contracts/Dtos.cs             The API contract
    Endpoints/SyncEndpoints.cs    Delta pull by scope
    Endpoints/CommandEndpoints.cs Idempotent offline writes
    Endpoints/DeviceEndpoints.cs  Family creation, key directory
    Endpoints/ScheduleEndpoints.cs Contentless wakes + sender
    Program.cs                    Wiring and dev-grade device auth

app/packages/domain/
  lib/src/recurrence.dart         Occurrence expansion
  test/recurrence_test.dart       The golden suite
```

## Running the backend

```bash
cd backend
docker compose up -d
dotnet restore
dotnet ef migrations add Initial --project src/Family.Api
dotnet run --project src/Family.Api
curl localhost:5000/v1/health
```

## Running the domain tests

```bash
cd app/packages/domain
dart pub get
dart test
```

These should be the fastest tests in the project and the ones you run most.

## What the design commits to here

**The server cannot read family content.** Every object is an opaque `Envelope`
byte array plus routing metadata: kind, scope, sequence, version. Search the
backend for a field holding a title or a note — there isn't one, and that is the
property to protect as the code grows.

**Writes are commands, not row state.** `POST /v1/commands` is idempotent on
`(DeviceId, ClientCommandId)`, so replaying a queue after a week offline is
free. The allowlist in `CommandEndpoints.Allowed` is deliberately short — adding
to it should feel like a decision.

**Reminders carry nothing.** `ScheduledWake` holds a device, a timestamp and an
opaque correlation reference. The device computes leave-by times itself, because
it is the only party that can read the event, and renders the notification text
locally after a silent push.

**Recurrence expands in wall-clock time.** A series stores local time plus an
IANA zone, never a UTC instant. The tests cover both DST boundaries, leap days
and month-end clamping. If one of them fails, fix the code, not the test.

## Next, in order

1. **EF migration and a smoke test** — create a family, register a device, push
   an object, pull it back from a second device.
2. **The Rust crypto core** — envelope encryption per the crypto design
   document, wrapped behind `flutter_rust_bridge`. Do this before any real data
   exists, because the envelope format is the one thing no migration can fix.
3. **Drift local store** — two databases, cache and command queue, with
   different durability guarantees. Conflating them is the bug that loses a
   family's shopping trip.
4. **The agenda-week screen**, reading occurrences from the domain package.
5. **FCM and the wake handler** — free on Android, and it proves the reminder
   pipeline end to end.

## Known gaps in this slice

- Device auth is a header lookup. Replace with Ed25519 challenge-response before
  anyone outside your household uses it; the endpoint shapes don't change.
- `ScopesForDevice` treats custody scopes as a placeholder.
- No migration files yet — generate with `dotnet ef`.
- `NextSequence` opens a raw command; tidy it once the first integration test is
  green.
- No rate limiting, no WebSocket channel, no attachment endpoints.
