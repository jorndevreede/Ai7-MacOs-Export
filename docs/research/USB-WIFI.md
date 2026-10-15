# USB and WiFi investigation — 2026-10-12

Status: USB enable and mount verified on hardware on 12 October; WiFi remains static evidence only. Do not equate a setting acknowledgement with a mounted disk or successful WiFi download.

## Preferred route: USB storage

The supplied device manual describes triple-click as displaying the MAC address and A/N number. It does not document this as enabling USB storage.

The user's earlier USB screenshot shows VID 1908, PID 0226 and USB device revision 1.11. USB revision is not the recorder firmware version. The USB ID repository lists 1908:0226 as a MicroSD Card Reader/Writer (https://usb-ids.gowdy.us/read/UD/1908). That supports investigating mass storage, but is not proof of the Ai7's exact chipset or mode-switch procedure.

The installed MindRec application's BOT implementation exposes a USB enable setting:

- `usbSwitchHandle:` passes its boolean as a decimal string to internal command enum 30.
- `ZBRBluetoothBOTCMD` maps enum 30 to wire command `0x15`.
- Its parameter builder converts the string to an integer and sends the first byte.
- Enable frame: `CA AC 15 01 01`; disable frame: `CA AC 15 01 00`.
- Device-information parsing includes an `isUSBSupport` field. The name alone does not establish whether this is capability or current state.

The app button/menu, **Enable USB storage…**, sends the enable setting only after connecting, while idle, and after a user-visible prompt. It does not format, erase or repair storage. No automatic disable is provided: a mounted disk must first be ejected normally.

Live result on 12 October: after a successful BLE connection with the cable attached, the enable command received a response and macOS mounted `/Volumes/NO NAME`. System Information identified `Beken-USB MSC DEMO`. Six recording files were readable: `Note<14-digit ID>` and `Call<14-digit ID>`, without extensions. A sample was identified as MPEG ADTS AAC, 16 kHz mono. No format or repair was needed. The first connection attempt timed out, but a subsequent attempt succeeded without removing the cable.

Version 0.3.0 adds USB file selection after loading the recorder's BLE list. Every nonempty entry must match its USB filename and byte count. Transfer uses a bounded-memory USB copy and the same AAC preservation, MP3 conversion, complete decode check and no-overwrite publishing as BLE. Device deletion is disabled while USB is selected. USB selection is session-only; choosing Bluetooth again does not unmount the disk.

## Alternative route: device WiFi hotspot

Static evidence from the installed MindRec BOT implementation:

- `sendWifiSwitch` sends internal enum 45 with parameter string `1`.
- BOT mapping translates enum 45 to wire `0xF3`; parameter is one integer byte.
- Hotspot enable candidate: `CA AC F3 01 01`.
- BOT response parsing extracts SSID and password by splitting a UTF-8 string on a comma. Full payload offsets and reply handling still need live validation.
- BOT WiFi endpoint: `192.168.10.1`, TCP port **22000**.
- `fileDownLoadWithIdentify:` builds `CA AC 08 <length> <UTF-8 file identifier>`; unlike the BLE request builder it does not append a four-byte offset.
- Dedicated BOT socket/file parser exists. Do not assume FTP: MindRec supports multiple recorder families, some using FTP and others a proprietary TCP protocol.

Implementation would require activating the hotspot over BLE, joining its network, connecting to TCP 22000, validating stream framing/end-of-file behavior and preserving the same exact-byte/hash checks as BLE. Joining the recorder's WiFi may temporarily disconnect the Mac from its internet network. Do not switch networks silently during an active remote session.

## Provenance

Inspected locally installed MindRec Objective-C metadata and disassembly, plus supplied manual/screenshots. No proprietary binary or disassembly is redistributed. Reimplementation notes describe observed interoperability behavior; no firmware brute force, reset, format or undocumented command sweep was used.
