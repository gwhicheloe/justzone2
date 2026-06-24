#!/bin/bash
#
# Build, sign, and upload a new TestFlight build in one command.
#
#   ./scripts/release_testflight.sh
#
# What it does:
#   1. Bumps CURRENT_PROJECT_VERSION (the build number) across all targets, in
#      sync, to one above the current max — TestFlight rejects a re-used build
#      number, so every upload must increment.
#   2. Archives a Release build (iPhone app + embedded Watch app + extensions).
#   3. Exports an App Store-signed .ipa.
#   4. Uploads it to App Store Connect / TestFlight via the App Store Connect API.
#
# Requirements (one-time):
#   - scripts/asc.env        (gitignored) with:
#         ASC_KEY_ID=<key id>
#         ASC_ISSUER_ID=<issuer id>
#   - The matching App Store Connect API key at
#         ~/.private_keys/AuthKey_<ASC_KEY_ID>.p8
#     (also copied to ~/.appstoreconnect/private_keys/ — altool looks there).
#   - The Apple Developer Program License Agreement must be accepted (otherwise
#     export fails with "PLA Update available").
#
# After a successful release, commit the build-number bump:
#   git commit -am "Bump build to <N> for TestFlight"
#
set -euo pipefail

cd "$(dirname "$0")/.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# --- credentials (kept out of git) ---
if [ -f scripts/asc.env ]; then
  # shellcheck disable=SC1091
  source scripts/asc.env
fi
: "${ASC_KEY_ID:?Set ASC_KEY_ID in scripts/asc.env}"
: "${ASC_ISSUER_ID:?Set ASC_ISSUER_ID in scripts/asc.env}"

PBX="justzone2.xcodeproj/project.pbxproj"
ARCHIVE="/tmp/justzone2.xcarchive"
EXPORT_DIR="/tmp/justzone2-export"

# --- 1. bump build number (all targets in sync) ---
CUR=$(grep -oE 'CURRENT_PROJECT_VERSION = [0-9]+' "$PBX" | grep -oE '[0-9]+' | sort -n | tail -1)
NEXT=$((CUR + 1))
sed -i '' -E "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = ${NEXT};/g" "$PBX"
echo "▸ Build number: ${CUR} → ${NEXT}"

# --- 2. archive ---
echo "▸ Archiving (Release)…"
rm -rf "$ARCHIVE"
xcodebuild -scheme justzone2 -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" -allowProvisioningUpdates archive \
  >/tmp/jz2-archive.log 2>&1 \
  || { echo "✗ Archive failed:"; tail -25 /tmp/jz2-archive.log; exit 1; }

# --- 3. export App Store-signed .ipa ---
echo "▸ Exporting .ipa…"
rm -rf "$EXPORT_DIR"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist scripts/exportOptions.plist -allowProvisioningUpdates \
  >/tmp/jz2-export.log 2>&1 \
  || { echo "✗ Export failed:"; tail -25 /tmp/jz2-export.log; exit 1; }

IPA="$EXPORT_DIR/justzone2.ipa"

# --- 4. upload to TestFlight ---
echo "▸ Uploading build ${NEXT} to TestFlight…"
xcrun altool --upload-app --type ios --file "$IPA" \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"

echo ""
echo "✅ Build ${NEXT} uploaded. App Store Connect → TestFlight (processing ~5–15 min)."
echo "   Remember to commit the bump:  git commit -am \"Bump build to ${NEXT} for TestFlight\""
