#!/bin/sh
set -eu
cd "$(dirname "$0")"
app="dist/AI07 Export.app"
mkdir -p "$app/Contents/MacOS"
cp Info.plist "$app/Contents/Info.plist"
xcrun clang -fobjc-arc -fmodules -fmodules-cache-path="${TMPDIR:-/tmp}/ai07-clang-cache" AI07Export.m -framework Cocoa -framework CoreBluetooth -o "$app/Contents/MacOS/AI07Probe"
codesign --force --sign - "$app"
