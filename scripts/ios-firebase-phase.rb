# Adds the build phase that puts GoogleService-Info.plist into the app.
#
#   ruby -I<cocoapods gems> scripts/ios-firebase-phase.rb
#
# Run once; it is idempotent, and the change belongs in project.pbxproj.
#
# The plist itself is gitignored, because it is this Firebase project's
# config and not anyone else's. So it cannot be an ordinary resource
# reference: on a machine without it Xcode would fail the build with a
# missing input file, and a checkout that cannot build is a worse problem
# than push being off. A script phase copies it when it is there and says
# so when it is not — the same shape as the Maps key, where a missing key
# changes what the app can do and never whether it runs.

require "xcodeproj"

PHASE = "Firebase config (if present)".freeze

root = File.expand_path("..", __dir__)
path = File.join(root, "app/apps/family/ios/Runner.xcodeproj")
project = Xcodeproj::Project.open(path)
runner = project.targets.find { |t| t.name == "Runner" } or abort "no Runner target"

if runner.build_phases.any? { |p| p.respond_to?(:name) && p.name == PHASE }
  puts "already there"
  exit
end

phase = runner.new_shell_script_build_phase(PHASE)
phase.shell_script = <<~SH
  # Firebase reads this from the bundle at start-up. Without it the app
  # runs and schedules its own reminders instead of taking push wakes
  # (pushSupported in the Dart side).
  src="$SRCROOT/Runner/GoogleService-Info.plist"
  if [ -f "$src" ]; then
    cp "$src" "$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app/GoogleService-Info.plist"
  else
    echo "note: no GoogleService-Info.plist, so iOS push stays off"
  fi
SH
phase.show_env_vars_in_log = "0"

# Before "Thin Binary", which is where Flutter finishes with the bundle,
# and before signing — a file added afterwards would not be signed with
# the rest and the install would be refused.
thin = runner.build_phases.index { |p| p.respond_to?(:name) && p.name == "Thin Binary" }
if thin
  runner.build_phases.delete(phase)
  runner.build_phases.insert(thin, phase)
end

project.save
puts "added '#{PHASE}' to Runner"
