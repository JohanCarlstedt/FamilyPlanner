#!/usr/bin/env bash
# Builds and installs on a cabled iPhone or iPad.
#
#   scripts/ios-device.sh <device-udid> [api-base-url]
#   FREE_ACCOUNT=1 scripts/ios-device.sh ...   # without a paid membership
#
# The home-screen widget, the share extension and push all need an app
# group, which a free Apple account can't sign. FREE_ACCOUNT=1 leaves those
# three out so the rest still installs (docs/ios-devices.md).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app="$here/app/apps/family"
project="$app/ios/Runner.xcodeproj/project.pbxproj"
gems=(/opt/homebrew/Cellar/cocoapods/*/libexec/gems/*/lib)

device="${1:-}"
api="${2:-http://$(ipconfig getifaddr en0 2>/dev/null || echo 127.0.0.1):5081}"
if [[ -z "$device" ]]; then
  echo "Usage: $0 <device-udid> [api-base-url]" >&2
  echo "Devices:" >&2
  xcrun devicectl list devices 2>/dev/null | grep -v simulated >&2
  exit 2
fi

# The project is put back whatever happens: an interrupted build must not
# leave the extensions detached.
backup="$(mktemp -t project.pbxproj)"
cp "$project" "$backup"
restore() { cp "$backup" "$project"; rm -f "$backup"; }
trap restore EXIT

if [[ "${FREE_ACCOUNT:-}" == 1 ]]; then
ruby "${gems[@]/#/-I}" -e '
require "xcodeproj"
project = Xcodeproj::Project.open(ARGV[0])
app = project.targets.find { |t| t.name == "Runner" }
extensions = project.targets.select { |t| t.product_type.include?("app-extension") }
names = extensions.map(&:name)

app.build_configurations.each do |c|
  # App groups and push need a paid account; without the entitlements file
  # the app signs with a free one.
  c.build_settings.delete("CODE_SIGN_ENTITLEMENTS")
end
app.build_phases.each do |phase|
  next unless phase.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
  phase.files.dup.each do |f|
    phase.remove_build_file(f) if names.include?(f.file_ref&.path.to_s.sub(".appex", ""))
  end
end
app.dependencies.dup.each do |d|
  app.dependencies.delete(d) if names.include?(d.target&.name)
end
project.save
puts "left out: #{names.join(", ")}"
' "$app/ios/Runner.xcodeproj"
else
  echo "with the widget and share extension (paid account)"
fi

cd "$app"
# `run` rather than `build`: it aims the build at the phone, which is what
# makes automatic signing register it with the team, and `install` can't
# take the API address. The session is stopped once the app is on; the app
# stays.
echo "Building for $api and installing on $device"
log="$(mktemp -t ios-run)"
pidfile="$(mktemp -t ios-run-pid)"
flutter run --debug -d "$device" --dart-define=API_BASE_URL="$api" \
  --pid-file="$pidfile" > "$log" 2>&1 &
runner=$!

installed=0
for _ in $(seq 1 180); do
  # "Installing and launching" is the app landing on the phone; the
  # debugger attaching afterwards is a nicety, and fails over Wi-Fi.
  if grep -qE "Installing and launching|Flutter run key commands|Syncing files to device" "$log"; then
    installed=1
    break
  fi
  if ! kill -0 "$runner" 2>/dev/null; then break; fi
  sleep 5
done

if [[ "$installed" == 1 ]]; then
  kill "$runner" 2>/dev/null || true
  wait "$runner" 2>/dev/null || true
  echo
  echo "Installed and started on $device."
  echo "The first run from a new Mac needs the developer trusted on the"
  echo "device: Settings > General > VPN & Device Management."
else
  wait "$runner" 2>/dev/null || true
  echo
  echo "It did not get as far as installing:" >&2
  grep -iE "error|developer mode|trust|provisioning" "$log" | head -10 >&2
  echo "(full log: $log)" >&2
  exit 1
fi
