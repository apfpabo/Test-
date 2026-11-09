# Parses the owner's foundational lore (docs/lore/foundational_lore.md, kept word for word) into the "world" part of
# godot/data/lore.json, which the codex, origin screens, survey sites and faction panels read. The text is not
# rewritten: each entry is a slice of the owner's file. Run: python3 tools/lore_to_json.py
import json, re
SRC, OUT = 'docs/lore/foundational_lore.md', 'godot/data/lore.json'
lines = open(SRC, encoding='utf-8').read().split('\n')
FAC = {'Hesperian Concord': 'concord', 'Vargan Directorate': 'directorate', 'Halcyon Federation': 'pacific', 'Meridian Combine': 'combine',
       'Tarsene Free Republic': 'republic', 'Freeport Syndicate': 'freeport', 'Halvard Enclaves': 'enclave'}
ORIGIN = {'Disgraced Officer': 'disgraced', 'The Hijacker': 'hijacker', 'Merchant Captain': 'merchant', 'Survivor of the Lost Fleet': 'survivor',
          'Privateer': 'privateer', 'Defector': 'defector', 'Smuggler': 'smuggler', 'Academy Cast-Off': 'academy'}

def section(title):   # the lines under a ### heading, up to the next heading or rule
    i = next(k for k, l in enumerate(lines) if l.startswith('### ') and title in l)
    out = []
    for l in lines[i + 1:]:
        if l.startswith('### ') or l.strip() == '---': break
        out.append(l)
    return '\n'.join(out).strip()

def blocks(text):     # entries that start with a **bold** line
    out, cur = [], None
    for l in text.split('\n'):
        m = re.match(r'^\*\*(.+?)\*\*\s*$', l.strip())
        if m: cur = [m.group(1), []]; out.append(cur)
        elif cur is not None: cur[1].append(l.rstrip())
    return [(t, '\n'.join(b).strip()) for t, b in out]

def key_of(title, table):
    for k, v in table.items():
        if k in title: return v
    raise SystemExit('no key for ' + title)

world = {
    'source': SRC,
    'brief': section('The World in Brief'),
    'war': section('The Unfinished War'),
    'atmosphere': section('Current Atmosphere'),
    'history_title': 'The Meridian War (1939–1945)',
    'history': re.split(r'\*\*The Meridian War \(1939–1945\)\*\*\s*\n', section('Official History of the Meridian War'), maxsplit=1)[1].strip(),
    'quiet_race': section('The Research & Technology Race'),
    'powers': {}, 'profiles': {}, 'mysteries': [], 'backstories': {},
}
for t, b in blocks(section('The Major Factions (1946)')):
    home = re.match(r'Home: (.+?)\s*\n', b + '\n').group(1)
    world['powers'][key_of(t, FAC)] = {'name': t, 'home': home, 'text': b.split('\n', 1)[1].strip()}
for t, b in blocks(section('Faction Profiles (1946)')):
    prof = {}
    for m in re.finditer(r'^- \*\*(.+?)\*\*: (.+?)\s*$', b, re.M): prof[m.group(1)] = m.group(2)
    world['profiles'][key_of(t, FAC)] = prof
for m in re.finditer(r'^- \*\*(.+?)\*\*\s*\n\s+(.+?)\s*$', section('Key Unresolved Mysteries'), re.M):
    world['mysteries'].append({'name': m.group(1), 'text': m.group(2)})
for t, b in blocks(section('Starting Background Lore Blurbs')):
    world['backstories'][key_of(t, ORIGIN)] = {'title': t, 'text': b}

lore = json.load(open(OUT, encoding='utf-8')); lore['world'] = world
json.dump(lore, open(OUT, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('powers', list(world['powers']), 'profiles', [len(v) for v in world['profiles'].values()], 'mysteries', len(world['mysteries']), 'backstories', list(world['backstories']))
