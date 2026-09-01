#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/assets/AppIcon.png"
ICONSET="$ROOT/macos/Gutenkern/Resources/AppIcon.iconset"
ICNS="$ROOT/macos/Gutenkern/Resources/AppIcon.icns"
ICO="$ROOT/windows/Gutenkern/AppIcon.ico"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" "$ICONSET"' EXIT

resize() {
    sips -z "$1" "$1" "$SRC" --out "$2" >/dev/null
}

mkdir -p "$ICONSET" "$(dirname "$ICO")"
resize 16   "$ICONSET/icon_16x16.png"
resize 32   "$ICONSET/icon_16x16@2x.png"
resize 32   "$ICONSET/icon_32x32.png"
resize 64   "$ICONSET/icon_32x32@2x.png"
resize 128  "$ICONSET/icon_128x128.png"
resize 256  "$ICONSET/icon_128x128@2x.png"
resize 256  "$ICONSET/icon_256x256.png"
resize 512  "$ICONSET/icon_256x256@2x.png"
resize 512  "$ICONSET/icon_512x512.png"
resize 1024 "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$ICNS"

resize 16  "$TMP/16.png"
resize 24  "$TMP/24.png"
resize 32  "$TMP/32.png"
resize 48  "$TMP/48.png"
resize 64  "$TMP/64.png"
resize 128 "$TMP/128.png"
resize 256 "$TMP/256.png"

python3 - "$ICO" "$TMP/16.png" "$TMP/24.png" "$TMP/32.png" "$TMP/48.png" "$TMP/64.png" "$TMP/128.png" "$TMP/256.png" <<'PY'
import struct
import sys
from pathlib import Path

out = Path(sys.argv[1])
images = []
for path in sys.argv[2:]:
    data = Path(path).read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(f"not a PNG: {path}")
    width = struct.unpack(">I", data[16:20])[0]
    height = struct.unpack(">I", data[20:24])[0]
    images.append((width, height, data))

offset = 6 + 16 * len(images)
buf = bytearray(struct.pack("<HHH", 0, 1, len(images)))
blobs = bytearray()
for width, height, data in images:
    buf += struct.pack(
        "<BBBBHHII",
        width if width < 256 else 0,
        height if height < 256 else 0,
        0,
        0,
        1,
        32,
        len(data),
        offset,
    )
    blobs += data
    offset += len(data)

out.write_bytes(bytes(buf) + bytes(blobs))
PY

echo "Wrote $ICNS"
echo "Wrote $ICO"
