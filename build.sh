#!/bin/sh
set -eu
cd "$(dirname "$0")"
app="dist/Ai7 interface.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/Tools" "$app/Contents/Resources/Licenses"
cp Info.plist "$app/Contents/Info.plist"
cp vendor/bin/ffmpeg "$app/Contents/Resources/Tools/ffmpeg"
cp vendor/licenses/* "$app/Contents/Resources/Licenses/"
cp Assets/Recorder.png "$app/Contents/Resources/Recorder.png"
if [ -f Assets/Recorder.icns ]; then cp Assets/Recorder.icns "$app/Contents/Resources/Recorder.icns"; fi
xcrun clang -arch arm64 -arch x86_64 -mmacosx-version-min=11.0 -fobjc-arc -fmodules -fmodules-cache-path="${TMPDIR:-/tmp}/ai7-clang-cache" -Wall -Wextra -Wno-unused-parameter -Wno-deprecated-declarations Sources/*.m -framework Cocoa -framework CoreBluetooth -o "$app/Contents/MacOS/Ai7Interface"
codesign --force --sign - "$app/Contents/Resources/Tools/ffmpeg"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
printf 'Built: %s\n' "$app"
