# Version 0.4.0 — 15 October 2026

- USB enable was hardware-confirmed on 12 October: NO NAME mounted and six extensionless AAC recordings were readable.
- USB source validation and copy tests pass: exact filenames/lengths, byte-identical copy, missing/changed sources, symlink refusal and no destination overwrite.
- Existing protocol/storage tests and bundled synthetic AAC-to-MP3 encode/decode tests pass.
- Universal application build and ad-hoc code-signature verification pass.
- USB-first UI visually inspected: numbered steps, Settings and hidden disconnected controls.
- Full automatic USB setup and new USB GUI transfer remains pending a successful live connection; no claim of complete end-to-end USB validation is made yet.
- Live mounted NO NAME and two readable files confirmed on 15 October. The GUI showed USB after manual volume selection. Automatic detection now also checks /Volumes and retries after its initial timeout; this fix is not yet live-validated.
- Deletion controls restored with safe USB ejection before BLE deletion. This new sequence is not hardware-validated; no recordings were deleted during testing.
- WiFi remains research only. No hotspot switching or WiFi downloads are enabled in this release.

# Validation — 11 October 2026

## Version 0.2.0

- Native universal build (arm64 and x86_64), macOS 11 minimum; ad-hoc signature verified.
- Protocol tests: framing, malformed input, recording identifiers, lengths and type validation.
- Storage tests: device isolation, Notes/Calls separation, exact source byte counts, hash verification, corruption detection and exclusive no-overwrite publication.
- Bundled FFmpeg/LAME successfully encodes and fully decodes synthetic audio.
- Live GUI scan and connection to one Ai7/AI07 with MindRec firmware V1.0.0 succeeded; 15 entries were listed (12 nonempty and 3 empty).
- Destination selection is persisted across app launches. A connect-before-folder bug discovered during UI testing was fixed.
- Final live UI check found the recorder again, connected, and displayed a new 10-second note. The GUI reported one completed MP3 transfer and changed its status to local. The destination folder persisted across launches. The full multi-selection workflow and permanent deletion have not yet been revalidated end to end on hardware.
- DMG HFS+ image creation and checksum verification passed. Mounting from the restricted build environment was unavailable; installation on a clean Mac remains untested.
- Delete command framing is derived from the MindRec implementation. The app sends each deletion once and verifies absence using a fresh complete list. Actual permanent deletion remains untested; do not treat it as confirmed compatible with other firmware.

## Earlier export-engine baseline

The earlier exporter established a direct CoreBluetooth connection without MindRec, listed 14 entries, and exported all 11 nonempty recordings (2,760,356 source bytes). Every transfer matched its advertised size. AAC originals were preserved; every MP3 was converted and fully decoded, with codec independently checked. Hashes were verified. A second export created no duplicates and preserved existing modification times. The largest recording tested was approximately eight minutes.

## Limits

No other recorder specimens, firmware versions, physical Intel Macs, long recordings, WiFi transfers or clean-machine installations have been tested. The DMG is a preview and is not Developer ID signed or notarized. Personal recordings, device identifiers and private test logs are excluded from this repository.
