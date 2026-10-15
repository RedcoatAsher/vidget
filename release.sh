#!/bin/bash
# Signs with Developer ID, notarizes, staples, and publishes a GitHub release.
#   ./release.sh v0.3.0
#
# One-time setup (stores an app-specific password in your keychain; never in this repo):
#   xcrun notarytool store-credentials vidget-notary --apple-id YOU@EXAMPLE.COM --team-id H5K2TS4JRX
set -euo pipefail
cd "$(dirname "$0")"

TAG="${1:?usage: ./release.sh vX.Y.Z}"
VERSION="${TAG#v}"
PROFILE="${NOTARY_PROFILE:-vidget-notary}"
IDENTITY="${SIGN_IDENTITY:-Developer ID Application}"

grep -q "MARKETING_VERSION: \"$VERSION\"" project.yml || {
  echo "project.yml MARKETING_VERSION doesn't match $VERSION — update it (and Info.plist) first" >&2; exit 1; }
git diff --quiet || { echo "commit your changes first" >&2; exit 1; }

echo "▸ generating project + building (Developer ID)"
xcodegen generate --quiet
rm -rf build/Release
xcodebuild -project Vidget.xcodeproj -scheme Vidget -configuration Release \
  -destination "platform=macOS,arch=arm64" -derivedDataPath build/Release \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$IDENTITY" \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime" build -quiet
APP=build/Release/Build/Products/Release/Vidget.app
ZIP=build/Vidget-$VERSION.zip

echo "▸ zipping"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo "▸ notarizing (this takes a few minutes)"
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
spctl -a -vv "$APP" 2>&1 | grep -q "accepted" && echo "✓ Gatekeeper accepts $APP"

echo "▸ tagging + publishing"
git tag -f "$TAG" && git push -q origin "$TAG"
gh release create "$TAG" "$ZIP" --title "Vidget $VERSION" --generate-notes
echo "✓ released $TAG"
