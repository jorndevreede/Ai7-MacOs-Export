# Ai7 interface

A native macOS app for downloading recordings from compatible **Ai7 / AI07** voice recorders to local MP3 files. No MindRec account, cloud service, Homebrew or terminal commands are needed to use the packaged app.

## Use (0.4.0)

1. Install the app from the DMG by dragging it to Applications.
2. Attach a USB data cable, turn on the recorder, stop recording and close MindRec on your phone and Mac.
3. Click **Scan**, choose the recorder, then **Connect**. Allow macOS Bluetooth access if asked.
4. The app identifies the recorder, fetches its file list and automatically requests USB storage mode. It matches the mounted disk using recording filenames and sizes.
5. Under **Settings (⚙)** choose a local destination folder. The app remembers it.
6. When the summary shows **USB**, use **Select all**, **Select none**, **Transfer selected**, or **Transfer all new recordings**.
7. Eject **NO NAME** in Finder before unplugging the recorder.

Bluetooth is used for setup and the file list; all audio transfers use USB. There is no Bluetooth audio fallback. If automatic detection cannot find a unique matching disk, check the data cable and use **Settings → Choose USB volume manually…**. Transfer stays disabled until a matching source and destination are selected. Disconnect appears only while connected; it does not eject the USB disk.

The app reads USB originals without modifying them. **Delete selected…** asks for confirmation, warns about missing local backups, safely ejects USB storage, then deletes via Bluetooth and checks a fresh file list. Local copies are kept. This deletion workflow still needs hardware validation. Do not record or unplug during transfer. The full automatic setup-to-transfer workflow still requires live hardware validation; see [validation](VALIDATION.md).

## Local library

The selected folder contains a separate `Ai7-<device identifier>` directory per recorder:

- `Notes/`: MP3 notes.
- `Calls/`: MP3 calls.
- `Originals/Notes/` and `Originals/Calls/`: untouched AAC sources.
- `.receipts/`: per-recording hashes and source byte count.
- `.incomplete/`: unfinished transfers or failed conversions, retained for recovery.

The app labels absent files **new** and hash-verified files **local**. **local (unverified)**, **incomplete** and **conflict** entries are not overwritten. These statuses are based on this app's destination layout, not a search through arbitrary audio files elsewhere on disk. Empty recorder entries are displayed but cannot be transferred.

## Compatibility and distribution

macOS 11+, universal arm64/x86_64 build. Tested live on an Apple Silicon Mac with one Ai7/AI07 running MindRec firmware V1.0.0. Intel is compiled but not physically tested. Discovery is not hardcoded to a personal serial number; the app verifies the D0D0/D0D1–D0D4 GATT layout before sending list or transfer commands. Devices that share a product name may still use another protocol.

The DMG is a **preview**, locally ad-hoc signed, **not Developer ID signed or notarized**. Gatekeeper may block a downloaded copy. A publisher's Apple Developer account is required for normal signed/notarized distribution; this project does not disable or bypass Gatekeeper.

MP3 encoding and validation use a bundled minimal FFmpeg/LAME executable, without networking enabled. Corresponding sources, build flags and LGPL notices are included in the repository and DMG. No personal recordings, credentials or personal device identifiers are stored in Git.

WiFi transfer and StenoAI import are not included in this version. See [protocol](PROTOCOL.md), [validation](VALIDATION.md), [installation notes](docs/INSTALL.txt), and [third-party notices](vendor/README.md).

## Development

Requires Xcode Command Line Tools. No package-manager dependencies are needed for an ordinary build; the minimal universal audio executable is versioned under `vendor/bin` with matching sources.

```sh
sh scripts/test.sh
sh build.sh
sh scripts/package-dmg.sh
```

To rebuild the bundled audio tool from the included source archives:

```sh
bash scripts/build-media.sh
```

The native sources are in `Sources/`; tests cover framing, malformed inputs, source lengths, independent device paths, corruption detection and no-overwrite behavior, plus synthetic audio conversion. `Assets/` contains the generated recorder icon and its source/provenance. `--demo` runs the UI without Bluetooth commands; transfer and deletion are disabled in demo mode.
