#!/bin/bash
# Builds Vidget.app (with its WidgetKit extension) into ./build and optionally launches it.
#   ./build.sh         build only
#   ./build.sh run     build and launch
#
# Signing: uses your Apple Development certificate (team in project.yml) when one is in the
# keychain, so the widget extension and app group work. With no certificate (e.g. CI) it
# falls back to an ad-hoc signature — the app runs, but the gallery widget may not register.
set -euo pipefail
cd "$(dirname "$0")"

command -v xcodegen >/dev/null || { echo "xcodegen is required: brew install xcodegen" >&2; exit 1; }

echo "▸ generating Xcode project"
xcodegen generate --quiet

SIGN_ARGS=()
if ! security find-identity -v -p codesigning 2>/dev/null | grep -q "Apple Development"; then
  echo "▸ no Apple Development certificate — ad-hoc signing"
  SIGN_ARGS=(CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="" \
             CODE_SIGN_ENTITLEMENTS="" PROVISIONING_PROFILE_SPECIFIER="")
fi

echo "▸ building (Release)"
rm -rf build/Vidget.app
xcodebuild -project Vidget.xcodeproj -scheme Vidget -configuration Release \
  -destination "platform=macOS,arch=$(uname -m)" -derivedDataPath build/DerivedData ONLY_ACTIVE_ARCH=YES ${SIGN_ARGS[@]+"${SIGN_ARGS[@]}"} build -quiet \
  | grep -E "error:|warning: .*Sources/" | grep -v "exit code 0 but produced no further output" || true
test -d build/DerivedData/Build/Products/Release/Vidget.app || { echo "build failed" >&2; exit 1; }
cp -R build/DerivedData/Build/Products/Release/Vidget.app build/

echo "✓ built build/Vidget.app"
if [[ "${1:-}" == "run" ]]; then
  pkill -x Vidget 2>/dev/null || true
  sleep 0.5
  open build/Vidget.app
fi
