# Extracts named members from a remote zip using HTTP range requests, without downloading the whole archive.
# Used to get Godot's Windows export template (84 MB) out of the 1 GB export-templates archive:
#   python3 -I tools/fetch_from_zip.py https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz \
#       windows_release_x86_64.exe version.txt ~/.local/share/godot/export_templates/4.3.stable
# Uses the agent proxy's CA bundle when present.
import sys, struct, zlib, urllib.request, ssl
url, want, outdir = sys.argv[1], sys.argv[2:-1], sys.argv[-1]
import os
ctx = ssl.create_default_context(cafile='/root/.ccr/ca-bundle.crt') if os.path.exists('/root/.ccr/ca-bundle.crt') else ssl.create_default_context()
def rng(a, b):
    req = urllib.request.Request(url, headers={'Range': f'bytes={a}-{b}', 'User-Agent': 'remote-unzip'})
    with urllib.request.urlopen(req, context=ctx, timeout=600) as r: return r.read(), r.headers.get('Content-Range')
_, cr = rng(0, 0); size = int(cr.split('/')[1]); print('archive size', size)
tail, _ = rng(size - 65536 - 22, size - 1)
i = tail.rfind(b'PK\x05\x06'); eocd = tail[i:]
cd_size, cd_off = struct.unpack('<II', eocd[12:20])
if cd_off == 0xFFFFFFFF or size > 0xFFFFFFFF:  # zip64
    j = tail.rfind(b'PK\x06\x06'); cd_size, cd_off = struct.unpack('<QQ', tail[j + 40:j + 56])
cd, _ = rng(cd_off, cd_off + cd_size - 1); p = 0
while p < len(cd) and cd[p:p + 4] == b'PK\x01\x02':
    meth, = struct.unpack('<H', cd[p + 10:p + 12]); csize, usize = struct.unpack('<II', cd[p + 20:p + 28])
    nl, el, cl = struct.unpack('<HHH', cd[p + 28:p + 34]); loff, = struct.unpack('<I', cd[p + 42:p + 46])
    name = cd[p + 46:p + 46 + nl].decode(); extra = cd[p + 46 + nl:p + 46 + nl + el]
    q = 0
    while q < len(extra):
        hid, hl = struct.unpack('<HH', extra[q:q + 4])
        if hid == 1:
            vals = extra[q + 4:q + 4 + hl]; k = 0
            if usize == 0xFFFFFFFF: usize, = struct.unpack('<Q', vals[k:k + 8]); k += 8
            if csize == 0xFFFFFFFF: csize, = struct.unpack('<Q', vals[k:k + 8]); k += 8
            if loff == 0xFFFFFFFF: loff, = struct.unpack('<Q', vals[k:k + 8]); k += 8
        q += 4 + hl
    if name.split('/')[-1] in want:
        hdr, _ = rng(loff, loff + 29); fnl, fel = struct.unpack('<HH', hdr[26:30]); start = loff + 30 + fnl + fel
        data, _ = rng(start, start + csize - 1)
        if meth == 8: data = zlib.decompressobj(-15).decompress(data)
        open(outdir + '/' + name.split('/')[-1], 'wb').write(data); print('extracted', name, len(data))
    p += 46 + nl + el + cl
