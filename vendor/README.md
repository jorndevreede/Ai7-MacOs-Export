# Bundled audio tools

FFmpeg 8.0.1, minimal audio-only build, statically linked with LAME 3.100. LGPL-2.1-or-later; no GPL or nonfree configuration is enabled. The app launches FFmpeg as a separate program. No Homebrew or system FFmpeg is used at runtime.

Universal Mach-O: arm64 and x86_64; minimum deployment target macOS 11.0. No networking protocols compiled into FFmpeg; file protocol only. AAC and MP3 input; MP3 output and null output for validation.

Original, unmodified corresponding source archives are included in `sources/`. The exact build recipe is `../scripts/build-media.sh`. Rebuild using Xcode Command Line Tools and make. The bundled executable can be replaced with a compatible rebuilt FFmpeg. The binary is ad-hoc signed during app packaging; after modification re-sign the local bundle as described in the build instructions. No library validation entitlement prevents replacement.

Source URLs:
- https://ffmpeg.org/releases/ffmpeg-8.0.1.tar.xz
- https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz

The source archives, recipe and license notices are also included in the DMG under Third-party sources. See `SHA256SUMS` for source and binary digests. No recorder recordings are included here.
