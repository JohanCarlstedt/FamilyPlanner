# Putting the Android app on Google Play

The family can already install the APK by cable or file. Play is worth the
trouble for one reason: updates arrive by themselves, on everyone's phone,
without you fetching anyone's handset.

## Take the internal testing track, not production

Google requires personal developer accounts made after 13 November 2023 to
run a **closed test with at least 12 testers, opted in continuously for 14
days**, before an app may go to production. A household does not have 12
testers, and recruiting strangers to sit in a test for a private family
organiser is absurd.

**Internal testing is exempt.** Up to 100 testers, invited by email
address, no waiting period, updates available minutes after upload. That
is the right track, and it is where this should stay. Nothing below
assumes you will ever press "production".

## What only you can do

1. **A Play Console account** — <https://play.google.com/console>, a
   one-off 25 USD fee. Sign in with the Google account you want to own
   this permanently; moving an app between accounts later is painful.
2. **Identity verification.** Google asks for a legal name, address and
   phone number, and posts or messages a code. Allow a few days.
3. **Create the app**: name *Family Planner*, language, "App", "Free".

## What is already prepared

| Thing | Where |
|---|---|
| App bundle (`.aab`, what Play takes) | `app/apps/family/build/app/outputs/bundle/prodRelease/app-prod-release.aab` |
| Icon, 512×512 | `app/apps/family/tool/play/icon-512.png` |
| Feature graphic, 1024×500 | `app/apps/family/tool/play/feature-1024x500.png` |
| Privacy policy, publicly reachable | `https://<your-domain>/privacy` (served by Caddy, `infra/site/privacy.html`) |

Rebuild the bundle with:

```bash
cd app/apps/family
flutter build appbundle --release --flavor prod \
  --dart-define=API_BASE_URL=https://<your-domain>
```

**The server address is compiled in.** A bundle on Play points at whatever
server it was built against, so moving the server means a new upload.

**The version code must go up every upload.** It comes from `pubspec.yaml`
(`version: 0.1.0+1` → code 1). Play refuses a repeat, so bump the number
after the `+` for each release.

## Signing, and the one irreversible choice

Play offers **Play App Signing**: you upload bundles signed with your own
key, and Google re-signs them with a key it holds. Enrolling cannot be
undone for that app.

Take it anyway. The alternative is that `secrets/` holds the only key that
can ever update this app on Play, and losing it means a new listing and
every phone reinstalling. Your keystore becomes the *upload* key, which
Google can reset for you if it is ever lost.

## Screenshots

Four, in `app/apps/family/tool/play/`: Today, the week, shopping, and an
event opened. Regenerate after any UI change with

```bash
cd app/apps/family
flutter test --update-goldens tool/make_screenshots.dart
```

They are photographs of the real screens, taken through the widget tests
with the invented household in `lib/src/data/sample_family.dart` — not an
emulator, and never a real phone. A store listing is public for good, and
the only family on a phone in this house is a real one.

## The declarations Play insists on

Before any release, including internal testing:

- **Privacy policy URL** — the one above.
- **Data safety.** Answer it honestly; the app does collect the lot. The
  answers that fit what this actually does:
  - Collected: location (approximate and precise), personal info (names),
    photos, messages, files, calendar events.
  - Shared with third parties: **no**.
  - Encrypted in transit: **yes**. Also say it is end-to-end encrypted,
    which Play has a box for.
  - Can users request deletion: **yes** — they delete it in the app, or
    the family deletes its server.
  - Collected for: app functionality only. Not analytics, not advertising,
    not personalisation — none of which exist here.
- **Content rating** questionnaire. No violence, no ads, no purchases.
  User-generated content exists (chat), but it is visible only within one
  family, which the questionnaire has a place for.
- **Target audience.** Children use it. Declaring an audience that
  includes under-13s brings Google's Families policy and its extra rules.
  For an app distributed only to your own household on internal testing,
  the honest answer is that it is designed for a family and its content
  is private to that family — answer as it is, and expect Families policy
  questions if you tick young ages.
- **Ads: none. In-app purchases: none.**

## Then

Upload the `.aab` to **Testing → Internal testing**, add the family's
Google accounts as testers, and send them the opt-in link. They install
from Play like any app, and every later upload reaches them on its own.
