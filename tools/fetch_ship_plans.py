#!/usr/bin/env python3
"""
fetch_ship_plans.py: download the reference plans listed in tools/ship_plans_manifest.csv, untouched.

For the owner's PC (14 Nov 2026). Each image is saved exactly as the site serves it: no stamped scale bars, no
footers, no generated placeholders. The agent sets each ship's scale from her real length when tracing, and only
measurements go into the game; the images themselves stay private reference (several are other people's work).

    python tools/fetch_ship_plans.py                     # download everything with a link
    python tools/fetch_ship_plans.py --only Yamato,Littorio
    python tools/fetch_ship_plans.py --list              # show what would be fetched and what has no link
    python tools/fetch_ship_plans.py --contact you@example.com   # put your address in the User-Agent (Wikimedia asks for one)

Output (default ./ship_plans next to where you run it):
    ship_plans/<Batch>/<Ship_class>/<original file name>
    ship_plans/sources.csv     what was fetched, from where, size, checksum, and any warning on that row
    ship_plans/missing.txt     the classes with no link yet: these still need a plan
Needs only Python 3 (no Pillow).
"""
import argparse, csv, hashlib, os, re, sys, time, urllib.error, urllib.parse, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
MANIFEST = os.path.join(HERE, "ship_plans_manifest.csv")
DELAY = 3.0            # seconds between requests: be polite, especially to Wikimedia
RETRIES = 4

# Rows whose link is not what the manifest says it is (checked 14 Nov 2026). Recorded in sources.csv.
WARNINGS = {
    "Yamato": "Drawing by Alexpl (Wikimedia Commons, CC BY-SA 3.0), not Skulski: credit Alexpl if it is ever shown.",
    "Tarawa (LHA-1)": "The link is a Wasp-class drawing, a different ship: find a Tarawa plan.",
    "Los Angeles (SSN-688i)": "The link is a 3D illustration, not a plan.",
    "Oliver Hazard Perry (FFG-7)": "Side view only: a top view is still needed.",
    "Liberty Ship (EC2-S-C1)": "Side view only: a top view is still needed.",
    "LST Mk 2 (LST-1 / LST-542)": "A PDF booklet: send the deck-plan page.",
}


def slug(text: str) -> str:
    return re.sub(r"[^A-Za-z0-9_-]+", "_", text.strip()).strip("_")


def fetch(url: str, ua: str):
    """Return (bytes, content_type, final_url). Backs off on 429 and 503, as servers ask."""
    wait = 10.0
    for attempt in range(RETRIES):
        req = urllib.request.Request(url, headers={"User-Agent": ua})
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                return r.read(), r.headers.get("Content-Type", ""), r.geturl()
        except urllib.error.HTTPError as e:
            if e.code in (429, 503) and attempt < RETRIES - 1:
                ra = e.headers.get("Retry-After")
                pause = float(ra) if ra and ra.isdigit() else wait
                print(f"    the site says too many requests ({e.code}); waiting {pause:.0f} s")
                time.sleep(pause); wait *= 2; continue
            raise
    raise RuntimeError("gave up after retries")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--manifest", default=MANIFEST)
    ap.add_argument("--out", default="ship_plans")
    ap.add_argument("--only", default="", help="comma-separated ship classes (start of the name is enough)")
    ap.add_argument("--contact", default="", help="an e-mail or URL for the User-Agent")
    ap.add_argument("--list", action="store_true", help="only list what would be fetched")
    a = ap.parse_args()

    ua = "IronMeridianPlanFetcher/1.0 (personal reference use" + (f"; {a.contact}" if a.contact else "") + ")"
    rows = list(csv.DictReader(open(a.manifest, newline="", encoding="utf-8")))
    if a.only:
        want = [w.strip().lower() for w in a.only.split(",") if w.strip()]
        rows = [r for r in rows if any(r["ship_class"].lower().startswith(w) for w in want)]

    have = [r for r in rows if r["direct_url"].strip()]
    missing = [r for r in rows if not r["direct_url"].strip()]
    if a.list:
        print(f"{len(have)} with a link:")
        for r in have: print(f"  {r['ship_class']} ({r['fit_year']}): {r['direct_url']}" + (f"  [!] {WARNINGS[r['ship_class']]}" if r["ship_class"] in WARNINGS else ""))
        print(f"\n{len(missing)} still need a plan:")
        for r in missing: print(f"  {r['ship_class']} ({r['fit_year']})")
        return 0

    os.makedirs(a.out, exist_ok=True)
    log_path = os.path.join(a.out, "sources.csv"); new_log = not os.path.exists(log_path)
    log = open(log_path, "a", newline="", encoding="utf-8"); w = csv.writer(log)
    if new_log: w.writerow(["ship_class", "fit_year", "file", "url", "final_url", "content_type", "bytes", "sha256", "status", "warning"])
    ok = failed = 0
    for i, r in enumerate(have):
        url = r["direct_url"].strip(); cls = r["ship_class"]
        name = os.path.basename(urllib.parse.unquote(urllib.parse.urlparse(url).path)) or "plan"
        folder = os.path.join(a.out, slug(r["batch"]), slug(cls)); os.makedirs(folder, exist_ok=True)
        path = os.path.join(folder, name)
        print(f"[{i + 1}/{len(have)}] {cls}")
        if os.path.exists(path):
            print("    already here, skipped"); continue
        try:
            data, ctype, final = fetch(url, ua)
            if ctype.startswith("text/html"):   # a web page came back (a block page, a gallery), not the drawing
                raise RuntimeError("the site returned a web page, not an image")
            open(path, "wb").write(data)
            w.writerow([cls, r["fit_year"], path, url, final, ctype, len(data), hashlib.sha256(data).hexdigest(), "ok", WARNINGS.get(cls, "")])
            print(f"    saved {name} ({len(data) // 1024} KB)"); ok += 1
        except Exception as e:
            w.writerow([cls, r["fit_year"], "", url, "", "", 0, "", f"failed: {e}", WARNINGS.get(cls, "")])
            print(f"    failed: {e}"); failed += 1
        log.flush(); time.sleep(DELAY)
    log.close()
    with open(os.path.join(a.out, "missing.txt"), "w", encoding="utf-8") as f:
        for r in missing: f.write(f"{r['ship_class']} ({r['fit_year']})\n")
    print(f"\n{ok} saved, {failed} failed, {len(missing)} still need a plan (see {a.out}/missing.txt and {a.out}/sources.csv)")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
