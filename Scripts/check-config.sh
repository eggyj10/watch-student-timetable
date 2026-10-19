#!/usr/bin/env bash
#
# Preflight for the configuration mistakes that do not fail the build.
#
# Every check here exists because something silently broke once. Xcode rewrites
# entitlements files when a capability cannot be provisioned, and the result
# compiles, installs, runs, and shows the wrong timetable on your wrist for a
# fortnight. Run this before every archive.
#
#   ./Scripts/check-config.sh

set -uo pipefail
cd "$(dirname "$0")/.."

fail=0
ok()   { printf '  ok    %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }

echo "Checking configuration..."
echo

# --- App Group -------------------------------------------------------------
# The one that bit. No entitlement means the watch app and the widget read
# different files, and the widget shows stale data rather than failing loudly.

group=$(sed -n 's/.*appGroupIdentifier = "\([^"]*\)".*/\1/p' Shared/TimetableStorage.swift)

if [[ -z "$group" ]]; then
  bad "could not read appGroupIdentifier from Shared/TimetableStorage.swift"
else
  ok "code expects App Group: $group"
  for target in iOS Watch Widget; do
    file="Config/$target.entitlements"
    if [[ ! -f "$file" ]]; then
      bad "$file is missing"
    elif ! grep -q "<string>$group</string>" "$file"; then
      bad "$file does not grant $group (Xcode strips this when it cannot provision)"
    else
      ok "$file grants it"
    fi
  done
fi

# --- Widget extension point ------------------------------------------------
# Must be nested inside the NSExtension dict. A top-level key passes the build
# and is rejected at upload.

plist="Config/Widget-Info.plist"
if [[ ! -f "$plist" ]]; then
  bad "$plist is missing"
elif tr -d ' \t\n' < "$plist" | grep -q "<key>NSExtension</key><dict><key>NSExtensionPointIdentifier</key>"; then
  ok "widget NSExtensionPointIdentifier is nested correctly"
else
  bad "$plist: NSExtensionPointIdentifier must sit inside the NSExtension dict"
fi

# --- Bundle identifiers ----------------------------------------------------
# App Store Connect rejects the upload unless the watch app is exactly
# <iOS bundle id>.watchkitapp.

ios_id=$(sed -n 's/^ *PRODUCT_BUNDLE_IDENTIFIER: \(.*\.timetable\)$/\1/p' project.yml | head -1)
watch_id=$(grep -o '[A-Za-z0-9.]*\.timetable\.watchkitapp' project.yml | head -1)

if [[ -z "$ios_id" || -z "$watch_id" ]]; then
  bad "could not read bundle identifiers from project.yml"
elif [[ "$watch_id" == "$ios_id.watchkitapp" ]]; then
  ok "watch bundle id is $ios_id.watchkitapp"
else
  bad "watch bundle id is '$watch_id', must be '$ios_id.watchkitapp'"
fi

# --- Leftover placeholders -------------------------------------------------

if grep -rqn "CHANGEME99" project.yml; then
  bad "project.yml still contains the placeholder Team ID"
else
  ok "Team ID has been set"
fi

# --- Build number ----------------------------------------------------------

build=$(sed -n 's/^ *CURRENT_PROJECT_VERSION: "\([0-9]*\)".*/\1/p' project.yml | head -1)
[[ -n "$build" ]] && echo "  note  current build number is $build (must increase for every upload)"

echo
if [[ $fail -eq 0 ]]; then
  echo "All configuration checks passed."
else
  echo "$fail check(s) failed. Fix before archiving."
fi
exit $fail
