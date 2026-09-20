# Putting the app on an iPhone

What the Mac and the phones need, and what only an Apple account can do.
Android is not covered here: it needs none of this.

## On each iPhone, once

1. **A data cable.** A charge-only cable looks identical and the phone
   never appears.
2. **Unlock the phone, then tap Trust This Computer** and enter the
   passcode. The prompt only shows while the phone is unlocked.
3. **Settings → Privacy & Security → Developer Mode → on**, then restart
   the phone and confirm after it reboots. Without it the phone hides
   itself from Xcode (iOS 16 and later).
4. Check with `flutter devices` from `app/apps/family`.

A second phone — another parent's, a child's — needs exactly the same
three steps. It does **not** need its own Apple account: the phone is
registered to the team that signs the build.

## In the Developer Program, once

The app uses two capabilities a free account cannot:

- **App groups** (`group.io.github.johancarlstedt.family`) — how the
  home-screen widget and the share extension talk to the app.
- **Push notifications** — the server's contentless wakes.

After enrolling:

1. Copy `app/apps/family/ios/Flutter/Signing.xcconfig.example` to
   `Signing.xcconfig` (gitignored) and set `DEVELOPMENT_TEAM` to the Team
   ID from developer.apple.com → Membership. Enrolling usually changes it.
2. Open `app/apps/family/ios/Runner.xcworkspace` in Xcode once, with the
   account added under Xcode → Settings → Accounts, and let automatic
   signing create the profiles for all three targets (Runner, TodayWidget,
   ShareExtension). It registers the app group and the push capability for
   you.
3. Plug each phone in and install:
   `scripts/ios-device.sh <udid> http://<mac-ip>:5081`. It builds
   **release** on purpose — iOS refuses to launch a debug Flutter build
   from the home screen, so a debug install looks broken to whoever holds
   the phone. Pass `debug` as a third argument when you want the
   debugger.

A phone also needs the app to reach the family's server: the app allows
plain http to local addresses only, and iOS asks the person once whether
the app may talk to devices on the network. Saying no leaves the app
unable to sync, and it's granted again under Settings > Family Planner >
Local Network.

## Push on iOS

The app turns push on by itself as soon as Firebase starts on the phone,
and schedules its own local reminders when it can't (`pushSupported`,
`localRemindersOnly`). To make it start:

1. In the Firebase console (project `family-planner-a5bad`), add an **iOS
   app** with bundle id `io.github.johancarlstedt.family`, download
   `GoogleService-Info.plist` and put it in `app/apps/family/ios/Runner/`.
   It is gitignored, like the Android one.
2. In developer.apple.com → Certificates, Identifiers & Profiles → Keys,
   create an **APNs auth key** (.p8), then upload it to Firebase under
   Project settings → Cloud Messaging, with the Key ID and Team ID.
3. Reinstall the app. It asks for notification permission on first run,
   registers its token, and wakes exactly as Android does.

Until step 1 is done an iPhone still reminds — it just plans the
reminders itself and can't hear about a change made on another phone
while it is closed.

## An older iPhone (iOS 16 and earlier)

Apple's current device tooling only talks to iOS 17 and later: an iPhone 8
shows up on USB and in `devicectl` as `pairing: unsupported`, and Xcode
doesn't list it at all. There is nothing to fix on the phone — a cable
install is simply not available with this Xcode.

TestFlight is the way in: it installs over the air and never involves
Xcode talking to the phone. The app is built for iOS 15 and up, so an
iPhone 8 on 16.7 runs it.

## TestFlight, for a phone that isn't at the Mac

Once enrolled, App Store Connect can hand builds to the family over the
air, and they last 90 days instead of the 7 a free account gives:

1. App Store Connect → Apps → new app, bundle id
   `io.github.johancarlstedt.family`.
2. `scripts/ios-testflight.sh https://your-server 2` — it reads the team
   from Signing.xcconfig, writes the export options, builds the IPA with
   that API address compiled in, and says how to upload it. The build
   number must be one App Store Connect hasn't seen; leave it out and the
   script takes the next one after the pubspec's.
3. Upload with Transporter (drag the .ipa in) or `xcrun altool`, then add
   the family as internal testers. They install TestFlight and the build
   arrives there.

**The API address is compiled in.** A phone away from home needs a server
it can reach and a certificate it trusts, so this has to be an https
address that resolves outside the house — the script refuses anything
else. Until the backend is reachable from outside, a TestFlight build can
only work on the home network.
