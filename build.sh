#!/bin/bash
# Builds Vidget.app into ./build and (optionally) launches it.
#   ./build.sh         build only
#   ./build.sh run     build and launch
set -euo pipefail
cd "$(dirname "$0")"

APP=build/Vidget.app
ARCH="$(uname -m)"            # arm64 or x86_64
MIN_OS="13.0"

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "▸ compiling for $ARCH (macOS $MIN_OS+)"
xcrun swiftc -O \
  -parse-as-library \
  -target "${ARCH}-apple-macos${MIN_OS}" \
  -framework AppKit -framework SwiftUI -framework WebKit \
  Sources/Vidget/*.swift \
  -o "$APP/Contents/MacOS/Vidget"

cp Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "▸ ad-hoc code signing"
codesign --force --deep --sign - "$APP" >/dev/null

echo "✓ built $APP"
if [[ "${1:-}" == "run" ]]; then
  pkill -x Vidget 2>/dev/null || true
  open "$APP"
fi
