# Ai7 interface

A native macOS app for downloading recordings from compatible **Ai7 / AI07** voice recorders to local MP3 files. No MindRec account, cloud service, Homebrew or terminal commands are needed to use the packaged app.

## Use

1. Install the app from the DMG by dragging it to Applications.
2. Choose a local destination folder. The app remembers it between launches.
3. Turn on the recorder and close MindRec on your phone and Mac.
4. Click **Scan**, choose the recorder, then **Connect**.
5. Use the checkboxes, **Select all** or **Select none**. Click **Transfer selected**, or **Transfer all new recordings**.

**Delete selected from Ai7…** asks for explicit confirmation, warns when a verified backup is missing, and checks a fresh file list after each deletion. This permanently deletes recordings on the device; local copies are kept. Cancel is the default action. Nothing is deleted as part of transferring audio.

## USB transfer (0.3.0)

1. Attach a USB data cable, stop recording and connect over Bluetooth as above.
2. Click **USB storage…** and confirm. The recorder should appear in Finder as **NO NAME**.
3. In the **Ai7 interface** menu choose **Use USB recordings…**, then select that recorder volume.
4. The summary shows **USB**. Use the same selected/all-new transfer buttons to produce local MP3s via the cable.
5. Eject **NO NAME** in Finder before unplugging it.

Bluetooth is still required once per session for recorder identity and the file list. USB selection checks filenames and sizes against that list. USB originals are read only; device deletion is disabled in USB transfer mode. Do not record while transferring. Choose **Use Bluetooth transfers** in the app menu to switch back; this does not eject the disk.

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
