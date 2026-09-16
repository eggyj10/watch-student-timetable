#!/usr/bin/env bash
#
# Replaces the placeholder bundle prefix and Team ID everywhere they appear.
# Run this once on the Mac, before the first build.
#
#   ./Scripts/configure.sh com.edwardjones ABCDE12345
#
# The prefix must be a reverse-domain string that is yours and unique on the
# App Store. The Team ID is the 10-character string at the top right of
# developer.apple.com/account, under Membership details.

set -euo pipefail

OLD_PREFIX="com.ejones"
OLD_TEAM="CHANGEME99"

NEW_PREFIX="${1:-}"
NEW_TEAM="${2:-}"

if [[ -z "$NEW_PREFIX" || -z "$NEW_TEAM" ]]; then
  echo "usage: $0 <bundle-prefix> <team-id>" >&2
  echo "   eg: $0 com.edwardjones ABCDE12345" >&2
  exit 1
fi

if [[ ! "$NEW_PREFIX" =~ ^[A-Za-z0-9.-]+$ ]]; then
  echo "error: '$NEW_PREFIX' does not look like a reverse-domain prefix" >&2
  exit 1
fi

if [[ ! "$NEW_TEAM" =~ ^[A-Z0-9]{10}$ ]]; then
  echo "error: '$NEW_TEAM' does not look like a Team ID (10 chars, A-Z0-9)" >&2
  exit 1
fi

cd "$(dirname "$0")/.."

FILES=(
  project.yml
  Config/iOS.entitlements
  Config/Watch.entitlements
  Config/Widget.entitlements
  Shared/TimetableStorage.swift
  Shared/TimetableStore.swift
)

for file in "${FILES[@]}"; do
  [[ -f "$file" ]] || { echo "error: $file is missing" >&2; exit 1; }
  # Portable in-place edit: BSD and GNU sed disagree about -i.
  tmp="$(mktemp)"
  sed -e "s/${OLD_PREFIX}/${NEW_PREFIX}/g" -e "s/${OLD_TEAM}/${NEW_TEAM}/g" "$file" > "$tmp"
  mv "$tmp" "$file"
  echo "updated $file"
done

echo
echo "Bundle identifiers are now:"
echo "  ${NEW_PREFIX}.timetable                        (iPhone app)"
echo "  ${NEW_PREFIX}.timetable.watchkitapp            (Watch app)"
echo "  ${NEW_PREFIX}.timetable.watchkitapp.widget     (complication)"
echo "  group.${NEW_PREFIX}.timetable                  (App Group)"
echo
echo "Check nothing was missed (this script itself will match, that is fine):"
echo "  grep -rn '${OLD_PREFIX}\\|${OLD_TEAM}' . --exclude-dir=.git --exclude-dir=Scripts"
echo
echo "Then: xcodegen generate && open Timetable.xcodeproj"
