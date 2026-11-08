#!/usr/bin/env bash
# Build, sign, notarize and staple a release zip of Faux Film Print.
# Usage: scripts/release.sh <version> [notary-keychain-profile]
# The profile is created once with:
#   xcrun notarytool store-credentials <profile> --apple-id <apple-id> --team-id D9P7WX2BKD
set -euo pipefail
VERSION="${1:?usage: scripts/release.sh <version> [profile]}"
PROFILE="${2:-fauxfilm1}"
TEAM=D9P7WX2BKD
cd "$(dirname "$0")/.."

xcodegen generate -q
rm -rf build/release-dd
xcodebuild -project FauxFilm.xcodeproj -scheme FauxFilm -configuration Release \
  -destination 'platform=macOS' -derivedDataPath build/release-dd \
  MARKETING_VERSION="$VERSION" \
  CODE_SIGN_IDENTITY="Developer ID Application" DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Manual \
  ENABLE_HARDENED_RUNTIME=YES CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO OTHER_CODE_SIGN_FLAGS="--timestamp" \
  build -quiet

APP="build/release-dd/Build/Products/Release/Faux Film Print.app"
ZIP="build/dist/Faux-Film-Print-$VERSION.zip"
mkdir -p build/dist
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
spctl -a -vv "$APP"
echo "Ready: $ZIP"
