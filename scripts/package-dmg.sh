#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
sh build.sh
stage="$(mktemp -d "${TMPDIR:-/tmp}/ai7-dmg.XXXXXX")"
# Only this newly created staging directory is removed on exit.
trap 'rm -rf "$stage"' EXIT
cp -R "dist/Ai7 interface.app" "$stage/"
ln -s /Applications "$stage/Applications"
cp docs/INSTALL.txt "$stage/Start here.txt"
mkdir -p "$stage/Third-party sources"
cp vendor/sources/* vendor/licenses/* vendor/README.md vendor/SHA256SUMS "$stage/Third-party sources/"
cp scripts/build-media.sh "$stage/Third-party sources/build-media.sh"
# Keep the source tree layout required by the rebuild recipe as well.
mkdir -p "$stage/Third-party sources/rebuild/vendor/sources" "$stage/Third-party sources/rebuild/vendor/bin" "$stage/Third-party sources/rebuild/scripts"
cp vendor/sources/* "$stage/Third-party sources/rebuild/vendor/sources/"
cp scripts/build-media.sh "$stage/Third-party sources/rebuild/scripts/"
hdiutil makehybrid -ov -hfs -hfs-volume-name "Ai7 interface" -o "dist/Ai7-interface-staging.dmg" "$stage"
hdiutil convert "dist/Ai7-interface-staging.dmg" -ov -format UDZO -o "dist/Ai7-interface-0.2.0.dmg"
rm "dist/Ai7-interface-staging.dmg"
hdiutil verify "dist/Ai7-interface-0.2.0.dmg"
shasum -a 256 "dist/Ai7-interface-0.2.0.dmg" > "dist/Ai7-interface-0.2.0.dmg.sha256"
