"""Package pre-sized PNG representations into an Apple ICNS container (no image edits)."""
from pathlib import Path
import struct
root = Path(__file__).resolve().parent.parent
sizes = {"icp4":"icon_16x16.png", "icp5":"icon_32x32.png", "icp6":"icon_32x32@2x.png", "ic07":"icon_128x128.png", "ic08":"icon_256x256.png", "ic09":"icon_512x512.png", "ic10":"icon_512x512@2x.png", "ic11":"icon_16x16@2x.png", "ic12":"icon_32x32@2x.png", "ic13":"icon_128x128@2x.png", "ic14":"icon_256x256@2x.png"}
chunks=[]
for kind, name in sizes.items():
    png=(root/'Assets'/'Recorder.iconset'/name).read_bytes()
    assert png.startswith(b'\x89PNG\r\n\x1a\n')
    chunks.append(kind.encode()+struct.pack('>I',len(png)+8)+png)
body=b''.join(chunks)
(root/'Assets'/'Recorder.icns').write_bytes(b'icns'+struct.pack('>I',len(body)+8)+body)
