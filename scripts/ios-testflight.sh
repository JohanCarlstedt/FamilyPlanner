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
  *)
    echo "The API address must be https: phones outside the house won't" >&2
    echo "reach anything else, and the traffic is signed but not private." >&2
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
flutter build ipa \
  --release \
  --build-number="$build" \
  --dart-define=API_BASE_URL="$api" \
  --export-options-plist="$options"

ipa="$(ls -t "$app"/build/ios/ipa/*.ipa 2>/dev/null | head -1)"
echo
echo "Built $ipa"
echo
echo "To hand it to App Store Connect, either:"
echo "  • open Transporter (Mac App Store), sign in, drag the .ipa in; or"
echo "  • xcrun altool --upload-app -f \"$ipa\" -t ios \\"
echo "      --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>"
echo "    with the key .p8 in ~/.appstoreconnect/private_keys (never in this repo)."
echo
echo "Then App Store Connect → TestFlight → add the family as internal testers."
