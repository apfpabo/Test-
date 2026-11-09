# Rewrites tools/worldgen/world.json with one entry per line and coordinates kept inline: python3 tools/worldgen/fmt.py
import json, re, sys
p = sys.argv[1] if len(sys.argv) > 1 else 'tools/worldgen/world.json'
w = json.load(open(p))
s = json.dumps(w, indent=2, ensure_ascii=False)
s = re.sub(r'\[\s+([-\d.,\s]+?)\s+\]', lambda m: '[' + re.sub(r'\s+', ' ', m.group(1)) + ']', s)        # number lists
s = re.sub(r'\[\s+(\[[-\d., ]+\](?:,\s+\[[-\d., ]+\])*)\s+\]', lambda m: '[' + re.sub(r'\s+', ' ', m.group(1)) + ']', s)  # lists of points
s = re.sub(r'\[\s+("[^"]*", [-\d.]+, [-\d.]+)\s+\]', r'[\1]', s)
s = re.sub(r'\{\s+("(?:name|note|near|pts)"[^{}\[\]]*?(?:\[[^\[\]]*(?:\[[^\[\]]*\][^\[\]]*)*\][^{}\[\]]*?)*)\s+\}', lambda m: '{ ' + re.sub(r'\n\s+', ' ', m.group(1)) + ' }', s)
open(p, 'w').write(s + '\n')
