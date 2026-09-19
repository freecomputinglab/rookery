#!/usr/bin/env bash
# Asserts on the SEQUENCE of `id` attributes each deck renders, not on
# counts: a count cannot tell a correct order from a reversed one, which is
# the entire subject of this example. Modelled on `search/0.1.0/demo/rheo/
# check.sh` — greps and a python3 heredoc for anything a grep cannot express,
# run through `just examples`, which builds first.
set -euo pipefail
cd "$(dirname "$0")"
H=build/html
fail=0
note() { echo "FAIL: $*"; fail=1; }

for f in corpus index functions reverse tag-values; do
  [ -f "$H/$f.html" ] || note "no page at $H/$f.html"
done

python3 - "$H" <<'PY' || fail=1
import re, sys

H = sys.argv[1]

def decks(page):
    # One list of bare note names per `div.slipshow` on the page, in
    # document order — `id="slip-idea:<name>"` is `_slip-attrs`'s own
    # scheme (`src/slipshow.typ`), so this reads the DOM the same way a
    # browser would rather than re-deriving the order out-of-band.
    h = open(f"{H}/{page}.html").read()
    segs = [s for s in re.split(r'(?=<div class="slipshow")', h) if s.startswith('<div class="slipshow"')]
    return [re.findall(r'<section class="slip[^"]*" id="slip-idea:([^"]+)"', s) for s in segs]

bad = 0
def check(label, got, want):
    global bad
    if got != want:
        print(f"FAIL: {label}\n  got:  {got}\n  want: {want}")
        bad = 1

ID_ORDER = ["alpha", "bravo", "charlie", "delta", "echo", "foxtrot", "golf",
            "hotel", "india", "juliett", "kilo", "lima"]

# 1. `content/index.typ`'s explicit array names three notes; the other nine
#    follow in id order.
idx = decks("index")
if len(idx) != 3:
    print(f"FAIL: index.html: expected 3 div.slipshow, found {len(idx)}"); bad = 1
else:
    check("index.html deck 1 (order: array)", idx[0],
          ["lima", "alpha", "kilo", "bravo", "charlie", "delta", "echo",
           "foxtrot", "golf", "hotel", "india", "juliett"])
    # 2. Ascending `created`: undated `golf`/`kilo` are LAST, and the
    #    same-dated `alpha`/`charlie` keep id order between themselves.
    check("index.html deck 2 (order: \"created\")", idx[1],
          ["bravo", "lima", "foxtrot", "india", "juliett", "alpha",
           "charlie", "echo", "hotel", "delta", "golf", "kilo"])
    check("index.html deck 3 (default order: \"slip-order\")", idx[2],
          ["foxtrot", "charlie", "kilo", "echo", "india", "golf", "alpha",
           "lima", "delta", "hotel", "bravo", "juliett"])

# 3. `content/functions.typ`'s `order: r => r.label` sequence differs from
#    the plain id-sorted sequence — proof the key function actually ran.
fns = decks("functions")
if len(fns) != 3:
    print(f"FAIL: functions.html: expected 3 div.slipshow, found {len(fns)}"); bad = 1
else:
    label_order = ["kilo", "juliett", "india", "hotel", "golf", "foxtrot",
                   "echo", "delta", "charlie", "bravo", "alpha", "lima"]
    check("functions.html deck 1 (order: r => r.label)", fns[0], label_order)
    if fns[0] == ID_ORDER:
        print("FAIL: functions.html deck 1 matches id order — the label key function did not run")
        bad = 1
    check("functions.html deck 2 (order: r => r.body.len())", fns[1],
          ["lima", "kilo", "delta", "hotel", "juliett", "golf", "echo",
           "foxtrot", "india", "bravo", "charlie", "alpha"])
    check("functions.html deck 3 (order: r => r.page)", fns[2], ID_ORDER)

# 4. `content/reverse.typ`'s reverse-chronological deck is the exact reverse
#    of `index.html`'s `"created"` deck's KEYED portion (the ten dated
#    notes), and its undated notes are still last, not first.
rev = decks("reverse")
if len(rev) != 2:
    print(f"FAIL: reverse.html: expected 2 div.slipshow, found {len(rev)}"); bad = 1
else:
    created_keyed = ["bravo", "lima", "foxtrot", "india", "juliett", "alpha",
                     "charlie", "echo", "hotel", "delta"]
    want_reverse_created = list(reversed(created_keyed)) + ["golf", "kilo"]
    check("reverse.html deck 1 (order: \"created\", reverse: true)", rev[0], want_reverse_created)
    if rev[0][-2:] != ["golf", "kilo"]:
        print(f"FAIL: reverse.html deck 1: undated notes are not last: {rev[0]}")
        bad = 1
    check("reverse.html deck 2 (order: r => r.label, reverse: true)", rev[1],
          list(reversed(label_order)))

# 5. `content/tag-values.typ`'s filtered deck holds only the `weight`-bearing
#    notes, ascending; the unfiltered deck holds all twelve, with the
#    keyless nine after the three that have a `weight`.
tv = decks("tag-values")
if len(tv) != 2:
    print(f"FAIL: tag-values.html: expected 2 div.slipshow, found {len(tv)}"); bad = 1
else:
    check("tag-values.html deck 1 (where: has weight)", tv[0], ["hotel", "echo", "india"])
    check("tag-values.html deck 2 (no where:, keyless last)", tv[1],
          ["hotel", "echo", "india", "alpha", "bravo", "charlie", "delta",
           "foxtrot", "golf", "juliett", "kilo", "lima"])

if not bad:
    print("  every deck's id sequence matches its order form")
sys.exit(bad)
PY

if [ "$fail" -eq 0 ]; then echo "examples/ordering OK"; else echo "examples/ordering FAILED"; exit 1; fi
