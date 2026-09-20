# The map, and the key it needs

Without a Google Maps key the family map still works — positions, places,
who is where, the check-in buttons — but it draws as a list instead of a
map, and says so. The tiles are the only part that needs Google.

Two keys, one per platform, both gitignored. They are billable and tied to
your Google Cloud project, so restrict them before they go on anyone's
phone.

## In Google Cloud, once

1. <https://console.cloud.google.com> → a project (any name).
2. **APIs & Services → Library**: enable **Maps SDK for Android** and
   **Maps SDK for iOS**. They are separate products; enabling one does not
   enable the other.
3. **Credentials → Create credentials → API key**, twice — one per
   platform. One key would work, but a key restricted to both apps is a
   key neither restriction protects.
4. Restrict each one, under **Application restrictions**:
   - Android: package `io.github.johancarlstedt.family` plus the SHA-1 of
     the certificate the build is signed with. Debug builds are signed
     with the debug keystore, release builds with `secrets/`, so a key
     that works in debug says "not authorised" in release unless both
     fingerprints are listed. Read them with
     `keytool -list -v -keystore <file>` (it asks for the password —
     type it yourself, it does not belong in this repo).
   - iOS: bundle id `io.github.johancarlstedt.family`.
   Under **API restrictions**, limit each key to its own Maps SDK.
5. Billing has to be enabled on the project. Map loads for a family sit
   far inside the monthly free allowance, but Google will not serve tiles
   to a project without a card on file.

## On this Mac, once

```bash
cp app/apps/family/android/maps.properties.example app/apps/family/android/maps.properties
cp app/apps/family/ios/Flutter/Maps.xcconfig.example app/apps/family/ios/Flutter/Maps.xcconfig
```

Paste a key into each, then rebuild — the key is compiled in, so every
phone needs a new build, including the TestFlight one.

Both files are in `.gitignore`. Check with `git status` before committing
if you ever move them.

## Why the app asks before it draws

The Maps SDK does not fail politely on a missing or rejected key: it
aborts the process the moment a map is created. So the app asks the
platform first (`family/maps` → `hasKey`) and only builds a `GoogleMap`
when the answer is yes. A wrong or over-restricted key is a different
matter — the key is present, so the map is drawn, and the tiles come back
grey with the reason in the device log.

## Who appears on it

The key is only the canvas. A dot needs, per person:

- their own switch on — **Map → Share while I'm using the app**. Nobody
  can turn it on for someone else; a parent can only *ask* a supervised
  child to share, which the child then cannot turn off.
- an audience that includes the viewer. **Parents** is the default, so
  children see no one until someone picks **Whole family**; the position
  is encrypted to that audience, not filtered for it.
- a precision other than **Place only**, which shares "at school" with no
  point to put on a map.
- the app open recently. Positions are reported while the app is used and
  fetched while the map is open — never pushed, which would wake every
  phone every couple of minutes. An older position stays on the map with
  the time it was taken.
