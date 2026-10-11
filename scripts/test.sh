#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build
xcrun clang -fobjc-arc -Wno-deprecated-declarations -I Sources Tests/Tests.m Sources/AI7Protocol.m Sources/AI7Store.m -framework Foundation -o build/tests
build/tests
# Synthetic AAC only; no user's recordings are stored in the repository.
vendor/bin/ffmpeg -v error -xerror -nostdin -y -i Tests/tone.aac -c:a libmp3lame -b:a 64k build/tone.mp3
vendor/bin/ffmpeg -v error -xerror -nostdin -i build/tone.mp3 -f null -
echo 'PASS: bundled converter encodes and decodes synthetic audio'
