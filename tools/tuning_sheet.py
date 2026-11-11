#!/usr/bin/env python3
"""Builds the tuning sheet (docs/TUNING_SHEET.md and a JSON digest) from tests/tune_probe.tscn runs.
usage: python3 tools/tuning_sheet.py <dir of probe .json files> <out.md> [out_digest.json]
Each probe file is one unattended campaign (an origin, a seed). Numbers are averaged over the seeds of an origin.
Nothing in the game is changed by this: it is a report for the owner's tuning pass."""
import json, sys, glob, os, statistics as stt
from collections import defaultdict

src, out_md = sys.argv[1], sys.argv[2]
out_js = sys.argv[3] if len(sys.argv) > 3 else None
runs = defaultdict(list)
for f in sorted(glob.glob(os.path.join(src, '*.json'))):
    r = json.load(open(f)); runs[r['start']['origin']].append(r)

ORDER = ['merchant', 'hijacker', 'smuggler', 'privateer', 'disgraced', 'survivor', 'defector', 'academy']
LABEL = {'merchant': 'The Merchant Captain', 'hijacker': 'The Hijacker', 'smuggler': 'The Smuggler', 'privateer': 'The Privateer',
         'disgraced': 'The Disgraced Officer', 'survivor': 'The Survivor of the Lost Fleet', 'defector': 'The Defector', 'academy': 'The Academy Cast-Off'}
CLS = ['pt', 'corvette', 'dd', 'ss', 'freighter', 'ap', 'ao', 'ae', 'ar', 'cl', 'cve', 'ca', 'bb', 'ddg', 'ssn', 'cv', 'cg']
CNAME = {'pt': 'Motor torpedo boat', 'corvette': 'Corvette', 'dd': 'Destroyer', 'ss': 'Submarine', 'freighter': 'Freighter', 'cl': 'Light cruiser', 'cve': 'Escort carrier',
         'ca': 'Heavy cruiser', 'bb': 'Battleship', 'ddg': 'Missile destroyer', 'ssn': 'Nuclear attack sub', 'cv': 'Fleet carrier', 'cg': 'Missile cruiser',
         'ap': 'Troop transport', 'ao': 'Fleet oiler', 'ae': 'Ammunition ship', 'ar': 'Repair ship'}
WIN = [(1, 15), (16, 30), (31, 60), (61, 90), (91, 120), (121, 180), (181, 240)]
GOODS = ['fuel', 'food', 'steel', 'medicine', 'munitions', 'electronics']
SRC_IN = {'trade: sales': 'trade', 'trade: purchases': 'trade', 'contracts and orders paid in port': 'contracts', 'contracts paid at sea or on arrival': 'contracts', 'battle: prizes, bounty, salvage': 'battle', 'commission pay': 'commission'}
SRC_OUT = {'repairs': 'repairs', 'ammunition': 'ammo', 'crew hired': 'crew', 'fuel': 'fuel', 'food': 'food', 'fuel bought from a passing oiler': 'fuel'}

# How days turn into hours of play: a model, stated in the sheet. A chart day is 10 s at 1x.
BATTLE_MIN, PORT_MIN, CONTACT_MIN = 8.0, 1.5, 0.3
def minutes(r, day, chart_x):
    m = (day - 1) * 10.0 / chart_x / 60.0
    m += sum(BATTLE_MIN for c in r['contacts'] if c['day'] <= day and c['fought'])
    m += sum(CONTACT_MIN for c in r['contacts'] if c['day'] <= day)
    m += sum(PORT_MIN for p in r['prices'] if p['day'] <= day)
    return m
def day_at(r, mins, chart_x):
    last = r['daily'][-1]['day'] if r['daily'] else 1
    for d in range(1, last + 1):
        if minutes(r, d, chart_x) >= mins: return d
    return None

def mean(xs):
    xs = [x for x in xs if x is not None]
    return sum(xs) / len(xs) if xs else None
def fmt(x, nd=0):
    if x is None: return '–'
    return f"{x:,.{nd}f}"

digest = {}
md = []
md.append('# Tuning sheet: the first hours of a campaign\n')
md.append('*A report for the owner\'s tuning pass (11 Nov 2026). All figures are measured, untuned, and his to judge. Three changes have been made since the first sheet, at his word: a 30-day grace from bounty squadrons, bounty squadrons and hunters sized to the captain\'s own squadron, and half pay with better prize money (see "The first change", "The second change" and "The third change"). The tables are measured with all three.*\n')
md.append('''## How it was measured

`tests/tune_probe.tscn` is the soak test's unattended captain (`tests/soak_test.gd`: real weather and calendar, every hostile contact fought out by the battle simulation as the battle screen sets it up) with **honest money**: the purse is never topped up and none of the soak's scripted events (reinforcements, a flag, the bomb) are run. In port he sells his cargo, repairs and rearms if he can pay, hires crew to need, buys fuel to the bunkers' room and food for forty days, takes contracts, commissions and story orders as the soak does, and rests a tired squadron. Before sailing he buys the good with the best margin at the port he is bound for, as many tons as still pay (prices move ton by ton). He is prudent, as a player would be: from any force that is not clearly weaker (the contact panel's strength ratio over 0.8, "an even fight" or worse) he tries to break off at the panel's own odds; caught all the same and outgunned, he orders a withdrawal; and until he has three ships he takes only peaceful contracts (deliveries, surveys, escorts, smuggling), no hunts, war contracts, strikes or story orders. He takes prizes, but **buys no ships**, so "affordable" below is read off his purse: the first day his money covers the cheapest design of that class he could order with the research he holds. He does no research of his own, and goes looking for a fight only once he has three ships.

Each origin was played for up to 240 days on four seeds (11, 23, 37, 51), the navy origins for the Concord. A run ends when the squadron is lost. Figures are the mean of the runs still afloat in that period (the "Afloat" column says how many).

**Days into hours.** A chart day lasts 10 s at 1×. The sheet assumes a battle takes 8 minutes of the player's time, a port call 1.5 minutes and any other contact 20 seconds, and reads off the day at which one and two hours are reached with the chart running at 2× and at 4×. These are assumptions, not measurements: the day columns are the measurement.
''')

all_prices = defaultdict(lambda: defaultdict(list))
summary_rows = []
for o in ORDER:
    rs = runs.get(o, [])
    if not rs: continue
    d = {}
    st = rs[0]['start']
    d['start_credits'] = mean([r['start']['credits'] for r in rs]); d['start_ships'] = st['ships']; d['port'] = st['port']
    d['lost'] = [r.get('lost_day') for r in rs]
    d['h'] = {}
    for x in (2, 4):
        d['h'][x] = (mean([day_at(r, 60, x) for r in rs]), mean([day_at(r, 120, x) for r in rs]))
    # windows
    wrows = []
    for a, b in WIN:
        per = []
        for r in rs:
            dl = [q for q in r['daily'] if a <= q['day'] <= b]
            if not dl: per.append(None); continue
            nxt = [q for q in r['daily'] if q['day'] == b + 1]
            last = b if nxt else dl[-1]['day'] - 1   # a run that ends inside the period: up to its last noted purse
            inc = defaultdict(float); out = defaultdict(float)
            for m in r['money']:
                if not (a <= m['day'] <= last): continue
                if m['src'] in SRC_IN: inc[SRC_IN[m['src']]] += m['amt']
                elif m['src'] in SRC_OUT: out[SRC_OUT[m['src']]] += -m['amt']
            wage = sum(q['wages'] + q['upkeep'] for q in dl if q['day'] <= last)
            # the purse is noted at the start of each day: a period runs from the start of its first day to the start
            # of the day after its last (or the end of the run)
            start = dl[0]['credits']
            end = nxt[0]['credits'] if nxt else dl[-1]['credits']
            net = end - start
            other = net - sum(inc.values()) + sum(out.values()) + wage
            cs = [c for c in r['contacts'] if a <= c['day'] <= b]
            per.append({'end': end, 'net_day': net / len(dl), 'trade': inc['trade'], 'commission': inc['commission'], 'contracts': inc['contracts'], 'battle': inc['battle'], 'other': other,
                        'wages': wage, 'repairs': out['repairs'] + out['ammo'], 'stores': out['fuel'] + out['food'] + out['crew'], 'ships': dl[-1]['ships'], 'tons': dl[-1]['tons'],
                        'contacts': len(cs), 'broke': sum(1 for c in cs if c.get('broke_off')), 'fought': sum(1 for c in cs if c['fought']), 'won': sum(1 for c in cs if c['won']), 'e_ships': [c['ships'] for c in cs], 'e_tons': [c['tons'] for c in cs],
                        'lost': sum(c['lost'] for c in cs), 'sunk': sum(c['sunk'] for c in cs), 'days': len(dl)})
            for p in r['prices']:
                if a <= p['day'] <= b:
                    for g in GOODS: all_prices[(a, b)][g].append(p['p'][g])
        ok = [p for p in per if p]
        if not ok: wrows.append(None); continue
        agg = {k: mean([p[k] for p in ok]) for k in ['end', 'net_day', 'trade', 'commission', 'contracts', 'battle', 'other', 'wages', 'repairs', 'stores', 'ships', 'tons', 'contacts', 'broke', 'fought', 'won', 'lost', 'sunk', 'days']}
        es = [x for p in ok for x in p['e_ships']]; et = [x for p in ok for x in p['e_tons']]
        agg['e_ships'] = mean(es); agg['e_tons'] = mean(et); agg['e_max_tons'] = max(et) if et else None
        agg['n_runs'] = len(ok)
        wrows.append(agg)
    d['win'] = wrows
    # affordability
    aff = {}
    for k in CLS:
        days = []; price = None; des = None; listed = None
        for r in rs:
            a_ = r['afford'].get(k)
            if a_ is None: days.append('never'); continue
            price = a_['price']; des = a_['design']; listed = a_['first_listed']
            days.append(a_.get('day', 'never'))
        if price is None: continue
        aff[k] = {'price': price, 'design': des, 'days': days, 'listed': listed}
    d['afford'] = aff
    # enemies met over all 240 days, by class
    kinds = defaultdict(int)
    for r in rs:
        for c in r['contacts']:
            for k, n in c['classes'].items(): kinds[k] += n
    d['kinds'] = dict(kinds)
    d['battles'] = mean([r['battles'] for r in rs]); d['won'] = mean([r['won'] for r in rs])
    digest[o] = d

# ------------------------------------------------------------------ the hand-written notes (docs/tuning_sheet_notes.md)
notes = os.path.join(os.path.dirname(os.path.abspath(out_md)), 'tuning_sheet_notes.md')
if os.path.exists(notes): md.append(open(notes).read().rstrip() + '\n')

# ------------------------------------------------------------------ the summary table
md.append('## At a glance\n')
md.append('| Origin | Starts with | Credits at start | Purse day 30 | Day 60 | Day 120 | Day 240 | Battles (won) in 240 days | 1 h / 2 h of play at 2× (day) | at 4× (day) |')
md.append('|---|---|---:|---:|---:|---:|---:|---:|---:|---:|')
def at(d, day):
    for (a, b), w in zip(WIN, d['win']):
        if b == day and w: return w['end']
    return None
for o in ORDER:
    if o not in digest: continue
    d = digest[o]
    lost = [x for x in d['lost'] if x]
    md.append(f"| {LABEL[o]} | {', '.join(d['start_ships'])} | {fmt(d['start_credits'])} | {fmt(at(d,30))} | {fmt(at(d,60))} | {fmt(at(d,120))} | {fmt(at(d,240))} | {fmt(d['battles'],1)} ({fmt(d['won'],1)})" + (f" · squadron lost on day {', '.join(map(str, lost))}" if lost else '') +
              f" | {fmt(d['h'][2][0])} / {fmt(d['h'][2][1])} | {fmt(d['h'][4][0])} / {fmt(d['h'][4][1])} |")
md.append('')

# ------------------------------------------------------------------ per origin
for o in ORDER:
    if o not in digest: continue
    d = digest[o]
    md.append(f"## {LABEL[o]}\n")
    md.append(f"Starts at {d['port']} with {', '.join(d['start_ships'])} and {fmt(d['start_credits'])} credits. Two hours of play fall about day {fmt(d['h'][2][1])} with the chart at 2×, day {fmt(d['h'][4][1])} at 4×.\n")
    md.append('**Money** (credits in each period; mean of the seeds)\n')
    md.append('| Days | Purse at end | Net a day | Trade (net)² | Contracts and orders | Commission pay | Battles (prizes, bounty, salvage) | Other¹ | Wages and tenders | Repairs and ammunition | Fuel, food, crew |')
    md.append('|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|')
    for (a, b), w in zip(WIN, d['win']):
        if not w: continue
        md.append(f"| {a}–{b} | {fmt(w['end'])} | {fmt(w['net_day'])} | {fmt(w['trade'])} | {fmt(w['contracts'])} | {fmt(w['commission'])} | {fmt(w['battle'])} | {fmt(w['other'])} | −{fmt(w['wages'])} | −{fmt(w['repairs'])} | −{fmt(w['stores'])} |")
    md.append('\n¹ Anything else that moved the purse: tows, fines, charges at sea. ² Sales less purchases in the period: cargo bought near the end of a period is sold in the next.\n')
    md.append('\n**The sea** (hostile contacts in each period)\n')
    md.append('| Days | Afloat (of %d) | Own ships (tons) | Contacts | Broke off | Fought (won) | Enemy ships met, mean | Enemy tons met, mean (largest) | Enemy sunk | Own ships lost |' % len(runs[o]))
    md.append('|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|')
    for (a, b), w in zip(WIN, d['win']):
        if not w: md.append(f"| {a}–{b} | 0 | | | | | | | | |"); continue
        md.append(f"| {a}–{b} | {w['n_runs']} | {fmt(w['ships'],1)} ({fmt(w['tons'])}) | {fmt(w['contacts'],1)} | {fmt(w['broke'],1)} | {fmt(w['fought'],1)} ({fmt(w['won'],1)}) | {fmt(w['e_ships'],1)} | {fmt(w['e_tons'])} ({fmt(w['e_max_tons'])}) | {fmt(w['sunk'],1)} | {fmt(w['lost'],1)} |")
    if d['kinds']:
        md.append('\nEnemy ships met in 240 days, by class (all seeds): ' + ', '.join(f"{CNAME.get(k, k).lower()} {n}" for k, n in sorted(d['kinds'].items(), key=lambda x: -x[1])) + '.\n')
    md.append('**When each class becomes affordable** (first day the purse covers the cheapest design of the class with the research held; "never" = not within 240 days; one entry per seed)\n')
    md.append('| Class | Cheapest design | Price | Affordable on day |')
    md.append('|---|---|---:|---|')
    for k in CLS:
        if k not in d['afford']: continue
        a_ = d['afford'][k]
        md.append(f"| {CNAME[k]} | {a_['design']} | {fmt(a_['price'])} | {', '.join(str(x) for x in a_['days'])} |")
    md.append('')

# ------------------------------------------------------------------ prices
md.append('## Prices in port\n')
md.append('Port prices (before the 6% buying and 7% selling spread) seen by all captains when they made harbour, as median (lowest–highest).\n')
md.append('| Days | ' + ' | '.join(g.capitalize() for g in GOODS) + ' |')
md.append('|---|' + '---:|' * len(GOODS))
for (a, b) in WIN:
    pr = all_prices.get((a, b))
    if not pr: continue
    md.append(f"| {a}–{b} | " + ' | '.join(f"{fmt(stt.median(pr[g]))} ({fmt(min(pr[g]))}–{fmt(max(pr[g]))})" for g in GOODS) + ' |')
md.append('')
open(out_md, 'w').write('\n'.join(md) + '\n')
if out_js: json.dump({'origins': digest, 'prices': {f"{a}-{b}": v for (a, b), v in all_prices.items()}}, open(out_js, 'w'))
print('wrote', out_md)
