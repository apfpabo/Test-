#!/usr/bin/env python3
"""Give the exported Windows .exe the game's icon, in place.

Godot only stamps an icon on a Windows export through rcedit, which needs Windows or Wine. The export template
already carries six icon pictures (16, 32, 48, 64, 128 px as bitmaps, 256 px as PNG); this writes ours over them at
the same sizes, byte for byte, so nothing in the file moves and the game data appended to the .exe stays valid.

    python3 tools/set_exe_icon.py build/IronMeridian.exe godot/icon.png      (needs: pip install pefile pillow)
"""
import io, struct, sys, zlib
import pefile
from PIL import Image

def dib(im, n):
    """A 32-bit icon bitmap: header, pixels bottom-up as BGRA, then the 1-bit mask (all visible: alpha does the work)."""
    im = im.resize((n, n), Image.LANCZOS).convert("RGBA")
    head = struct.pack("<IiiHHIIiiII", 40, n, n * 2, 1, 32, 0, n * n * 4, 0, 0, 0, 0)
    rows = [im.crop((0, y, n, y + 1)).tobytes("raw", "BGRA") for y in range(n - 1, -1, -1)]
    mask = bytes(((n + 31) // 32) * 4) * n
    return head + b"".join(rows) + mask

def png(im, n, size):
    """A PNG of exactly `size` bytes: padded with a text chunk, or cut down in colours until it fits."""
    im = im.resize((n, n), Image.LANCZOS).convert("RGBA")
    for colours in (0, 256, 128, 64, 32):
        buf = io.BytesIO(); (im if not colours else im.quantize(colours, method=Image.FASTOCTREE)).save(buf, "PNG", optimize=True)
        data = buf.getvalue()
        if len(data) + 12 <= size: break
    else: raise SystemExit("the 256 px icon will not fit in %d bytes" % size)
    pad = size - len(data) - 12
    if pad < 0: return data + bytes(size - len(data))
    body = b"tEXt" + b"Comment\x00" [:min(8, pad)] + b" " * max(0, pad - 8)
    chunk = struct.pack(">I", len(body) - 4) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)
    return data[:-12] + chunk + data[-12:]          # before IEND

def main(exe, icon):
    im = Image.open(icon).convert("RGBA")
    pe = pefile.PE(exe, fast_load=True)
    pe.parse_data_directories(directories=[pefile.DIRECTORY_ENTRY["IMAGE_DIRECTORY_ENTRY_RESOURCE"]])
    data = pe.__data__; jobs = []
    for e in pe.DIRECTORY_ENTRY_RESOURCE.entries:
        if e.id != pefile.RESOURCE_TYPE["RT_ICON"]: continue
        for e2 in e.directory.entries:
            for e3 in e2.directory.entries:
                d = e3.data.struct; off = pe.get_offset_from_rva(d.OffsetToData); size = d.Size
                if data[off:off + 4] == b"\x89PNG": jobs.append((off, size, png(im, 256, size)))
                else:
                    n = struct.unpack_from("<i", data, off + 4)[0]
                    if struct.unpack_from("<H", data, off + 14)[0] != 32: raise SystemExit("icon %d px is not 32-bit" % n)
                    jobs.append((off, size, dib(im, n)))
    pe.close()
    if not jobs: raise SystemExit("no icons found in " + exe)
    with open(exe, "r+b") as f:
        for off, size, new in jobs:
            if len(new) != size: raise SystemExit("size mismatch at %d: %d against %d" % (off, len(new), size))
            f.seek(off); f.write(new)
    print("icon written over %d pictures in %s" % (len(jobs), exe))

if __name__ == "__main__": main(sys.argv[1], sys.argv[2])
