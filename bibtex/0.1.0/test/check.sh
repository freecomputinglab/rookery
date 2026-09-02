#!/usr/bin/env bash
# Asserts on `test/sweep.typ`'s rendered OUTPUT, not merely that it compiled.
# `units.typ` covers `bibtex(..)`'s pure logic; this covers what `all()`
# actually registers — one note per bibliography key not already claimed by a
# hand-written `#citation`, each keyed by its BibTeX key rather than by the
# unnamed-note counter.
set -euo pipefail
cd "$(dirname "$0")/.."
S=test/build/sweep.html
fail=0
note() { echo "FAIL: $*"; fail=1; }

[ -f "$S" ] || { echo "FAIL: no $S — run 'just test' first"; exit 1; }

python3 - "$S" <<'PY' || fail=1
import re, sys
h = open(sys.argv[1]).read()

def txt(s):
    return " ".join(re.sub(r"<[^>]+>", " ", s).split())

# Each row is a `<div class="sweep-row">` holding one `<span class="sweep-id">`
# and one `<span class="sweep-body">` — separate elements rather than a single
# text-joined string, so the empty-body row cannot be mangled by HTML's own
# whitespace collapsing. One row per note `ideas()` found registered — a
# faithful count of the registry, not of what the fixture merely asked to mint.
rows = re.findall(r'<div class="sweep-row">(.*?)</div>', h, re.S)
if len(rows) != 2:
    print(f"FAIL: expected 2 registered notes, found {len(rows)}: {rows}"); sys.exit(1)

def cell(row, cls):
    m = re.search(rf'<span class="{cls}">(.*?)</span>', row, re.S)
    return txt(m.group(1)) if m else None

pairs = [(cell(r, "sweep-id"), cell(r, "sweep-body")) for r in rows]
ids = sorted(p[0] for p in pairs)
if ids != ["idea:badiou2002", "idea:smith2020"]:
    print(f"FAIL: registered ids are {ids}, wanted idea:badiou2002 and idea:smith2020")
    sys.exit(1)

# NEITHER named `1`: the whole defect this design exists to avoid is `all()`
# reading a single-argument mint as an unnamed note, landing it on the
# sequence counter as `idea:1` instead of under its own key.
if any(p[0] == "idea:1" for p in pairs):
    print(f"FAIL: a note minted as the unnamed counter's `idea:1`: {rows}"); sys.exit(1)

by_id = dict(pairs)
if by_id["idea:badiou2002"] != "A hand-written body.":
    print(f"FAIL: the hand-written citation's body is {by_id['idea:badiou2002']!r}, "
          f"wanted 'A hand-written body.'")
    sys.exit(1)
if by_id["idea:smith2020"] != "":
    print(f"FAIL: the swept note's body is {by_id['idea:smith2020']!r}, wanted empty")
    sys.exit(1)

print(f"  all(): 2 notes registered — {rows}")
PY

if [ "$fail" -eq 0 ]; then echo "sweep OK"; else echo "sweep FAILED"; exit 1; fi
