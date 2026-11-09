# Draws a candidate world in the chart's colours: python3 tools/worldgen/preview.py <dir> <seed> [scale]
import json, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops
d, seed = sys.argv[1], sys.argv[2]; scale = float(sys.argv[3]) if len(sys.argv) > 3 else 0.5
meta = json.load(open(f'{d}/{seed}.json'))
m = Image.open(f'{d}/{seed}_mask.png').getchannel('R')
W, H = int(3600 * scale), int(1600 * scale)
land = m.resize((W, H), Image.LANCZOS).point(lambda v: 255 if v > 127 else 0)
edge = ImageChops.subtract(land.filter(ImageFilter.MaxFilter(3)), land.filter(ImageFilter.MinFilter(3)))
glow = land.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(3))
img = Image.new('RGB', (W, H), (0x18, 0x30, 0x39))
img = Image.composite(Image.new('RGB', (W, H), (0x3a, 0x5c, 0x66)), img, glow.point(lambda v: v * 0.45))
img = Image.composite(Image.new('RGB', (W, H), (0xc9, 0xbb, 0x93)), img, land)
img = Image.composite(Image.new('RGB', (W, H), (0x7e, 0x6e, 0x4a)), img, edge)
g = ImageDraw.Draw(img, 'RGBA')
X = lambda lon: (lon + 180) / 360 * W; Y = lambda lat: (82 - lat) / 160 * H
for lon in range(-180, 181, 10): g.line([(X(lon), 0), (X(lon), H)], fill=(127, 176, 219, 22))
for lat in range(80, -79, -10): g.line([(0, Y(lat)), (W, Y(lat))], fill=(127, 176, 219, 22))
g.line([(0, Y(0)), (W, Y(0))], fill=(227, 178, 61, 50))
# March pack-ice edges (the real game bends these with currents)
g.line([(0, Y(78)), (W, Y(78))], fill=(230, 240, 245, 70)); g.line([(0, Y(-62)), (W, Y(-62))], fill=(230, 240, 245, 70))
fb = ImageFont.truetype('/usr/share/fonts/opentype/inter/Inter-Medium.otf', max(11, int(26 * scale)))
fs = ImageFont.truetype('/usr/share/fonts/opentype/inter/Inter-Medium.otf', max(10, int(18 * scale)))
for t in meta['labels']:
    s = ' '.join(t['text']); g.text((X(t['lon']), Y(t['lat'])), s, font=fb, fill=(200, 225, 235, 120), anchor='mm')
for c in meta['channels']:
    p = c['pts'][len(c['pts']) // 2]; x, y = X(p[0]), Y(p[1]); col = (227, 120, 70, 255) if c['role'] == 'canal' else (236, 200, 90, 255)
    g.ellipse([x - 5, y - 5, x + 5, y + 5], outline=col, width=2)
    g.text((x + 8, y - 6), c['name'], font=fs, fill=col)
g.text((10, H - 10), f"seed {meta['seed']}", font=fb, fill=(238, 240, 236, 200), anchor='ld')
img.save(f'{d}/candidate_{seed}.png')
print('wrote', f'{d}/candidate_{seed}.png')
