#!/usr/bin/env bash
# Builds a signed iOS release for TestFlight.
#
#   scripts/ios-testflight.sh https://family.example.com [build-number]
#
# The API address is compiled in, so it must be one the phones can reach
# from anywhere — a LAN address gives a build that only works at home.
# Needs a paid Apple account: the app group and push aren't available
# without one (docs/ios-devices.md).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app="$here/app/apps/family"
signing="$app/ios/Flutter/Signing.xcconfig"

api="${1:-}"
if [[ -z "$api" ]]; then
  echo "Usage: $0 <api-base-url> [build-number]" >&2
  exit 2
fi
case "$api" in
  https://*) ;;
  http://10.*|http://192.168.*|http://172.1[6-9].*|http://172.2[0-9].*|http://172.3[01].*)
    echo "WARNING: $api is on the home network." >&2
    echo "This build will work on that wifi, with the server running, and" >&2
    echo "nowhere else. Fine for trying TestFlight; not a build to hand to" >&2
    echo "anyone who leaves the house." >&2
    ;;
  *)
    echo "The API address must be https, or a home-network address." >&2
    echo "A phone elsewhere reaches nothing else, and plain http over the" >&2
    echo "internet is signed but not private." >&2
    exit 2
    ;;
esac

if [[ ! -f "$signing" ]]; then
  echo "No $signing. Copy Signing.xcconfig.example beside it and set" >&2
  echo "DEVELOPMENT_TEAM to the Team ID from developer.apple.com." >&2
  exit 2
fi
team="$(sed -n 's/^[[:space:]]*DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*//p' "$signing" | tr -d '[:space:]')"
if [[ -z "$team" ]]; then
  echo "No DEVELOPMENT_TEAM in $signing." >&2
  exit 2
fi

# Every upload needs a build number App Store Connect hasn't seen. Given
# none, take the next one after the pubspec's.
build="${2:-}"
if [[ -z "$build" ]]; then
  current="$(sed -n 's/^version:.*+//p' "$app/pubspec.yaml")"
  build=$(( current + 1 ))
fi

options="$(mktemp -t export-options).plist"
trap 'rm -f "$options"' EXIT
cat > "$options" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>teamID</key>
	<string>$team</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>uploadSymbols</key>
	<true/>
	<key>destination</key>
	<string>export</string>
</dict>
</plist>
PLIST

echo "Building for $api, build $build, team $team"
cd "$app"

# An .ipa from last time must not be able to masquerade as this build: the
# upload that follows would be rejected as a duplicate at best, and ship the
# wrong thing at worst. This happened — `flutter build ipa` failed on a
# deployment target, the script reported success, and the previous build was
# handed to TestFlight.
rm -f "$app"/build/ios/ipa/*.ipa

if ! flutter build ipa \
  --release \
  --build-number="$build" \
  --dart-define=API_BASE_URL="$api" \
  --export-options-plist="$options"; then
  echo >&2
  echo "The build failed; nothing to upload." >&2
  exit 1
fi

ipa="$(ls -t "$app"/build/ios/ipa/*.ipa 2>/dev/null | head -1)"
if [[ -z "$ipa" ]]; then
  echo "The build reported success but produced no .ipa." >&2
  exit 1
fi

# What is actually in it, so the number in the filename cannot be trusted
# over the number Apple will read.
built="$(unzip -p "$ipa" 'Payload/*.app/Info.plist' 2>/dev/null \
  | plutil -extract CFBundleVersion raw - 2>/dev/null || true)"
if [[ -n "$built" && "$built" != "$build" ]]; then
  echo "That .ipa is build $built, not $build. Refusing to upload it." >&2
  exit 1
fi
echo
echo "Built $ipa"
echo

# Which App Store Connect API key to upload with. Identifiers, not the key
# itself — the .p8 stays in ~/.appstoreconnect/private_keys, where altool
# looks for it by key id, and never in this repo. secrets/ is gitignored.
# shellcheck source=/dev/null
[[ -f "$here/secrets/appstore.env" ]] && source "$here/secrets/appstore.env"

if [[ -z "${ASC_KEY_ID:-}" || -z "${ASC_ISSUER_ID:-}" ]]; then
  echo "No ASC_KEY_ID / ASC_ISSUER_ID, so this stops at the .ipa." >&2
  echo "Put them in secrets/appstore.env to have this script upload too:" >&2
  echo "    ASC_KEY_ID=XXXXXXXXXX" >&2
  echo "    ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" >&2
  echo "Both are on App Store Connect → Users and Access → Integrations." >&2
  echo >&2
  echo "Meanwhile: open Transporter (Mac App Store) and drag the .ipa in." >&2
  exit 0
fi

echo "Uploading build $build to App Store Connect..."
# Kept out of the pipeline's exit status on purpose: altool says plenty
# that is not an error, and the words it uses are what decide this.
upload="$(xcrun altool --upload-app -f "$ipa" -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID" 2>&1 || true)"
echo "$upload" | grep -E "UPLOAD (SUCCEEDED|FAILED)|Delivery UUID|ERROR" || true

if ! grep -q "UPLOAD SUCCEEDED" <<<"$upload"; then
  echo >&2
  echo "The upload did not succeed. The whole of what it said:" >&2
  echo "$upload" >&2
  exit 1
fi

echo
echo "Build $build is with App Store Connect. It takes a few minutes to"
echo "finish processing before TestFlight will offer it to anyone."
