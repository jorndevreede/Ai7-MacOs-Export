#!/bin/bash
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$project/build/media"
root="$project/build/media"
tar -xzf "$project/vendor/sources/lame-3.100.tar.gz" -C "$root"
tar -xJf "$project/vendor/sources/ffmpeg-8.0.1.tar.xz" -C "$root"
for arch in arm64 x86_64; do
 mkdir -p "$root/lame-$arch" "$root/ffmpeg-$arch" "$root/prefix-$arch"
 cd "$root/lame-$arch"
 lamehost="$arch"; if [ "$arch" = arm64 ]; then lamehost=arm; fi
 "$root/lame-3.100/configure" --prefix="$root/prefix-$arch" --disable-frontend --disable-shared --enable-static --disable-dependency-tracking --host="$lamehost-apple-darwin" CC=clang CFLAGS="-arch $arch -mmacosx-version-min=11.0 -O2" LDFLAGS="-arch $arch -mmacosx-version-min=11.0" > configure.log 2>&1
 make -j6 > make.log 2>&1
 make install > install.log 2>&1
 cd "$root/ffmpeg-$arch"
 ffarch="$arch"; if [ "$arch" = arm64 ]; then ffarch=aarch64; fi
 "$root/ffmpeg-8.0.1/configure" --prefix="$root/prefix-$arch" --cc=clang --arch="$ffarch" --target-os=darwin --enable-cross-compile --disable-autodetect --disable-everything --disable-doc --disable-debug --disable-ffplay --disable-ffprobe --disable-network --disable-x86asm --disable-shared --enable-static --enable-ffmpeg --enable-avcodec --enable-avformat --enable-avfilter --enable-swresample --enable-protocol=file --enable-demuxer=aac,mp3 --enable-parser=aac,mpegaudio --enable-decoder=aac,mp3,mp3float --enable-encoder=libmp3lame,pcm_s16le --enable-libmp3lame --enable-muxer=mp3,null --enable-filter=aresample,aformat,anull --extra-cflags="-arch $arch -mmacosx-version-min=11.0 -I$root/prefix-$arch/include" --extra-ldflags="-arch $arch -mmacosx-version-min=11.0 -L$root/prefix-$arch/lib" > configure.log 2>&1
 make -j6 > make.log 2>&1
 echo "$arch finished"
done
lipo -create "$root/ffmpeg-arm64/ffmpeg" "$root/ffmpeg-x86_64/ffmpeg" -output "$root/ffmpeg-universal"

cp "$root/ffmpeg-universal" "$project/vendor/bin/ffmpeg"
