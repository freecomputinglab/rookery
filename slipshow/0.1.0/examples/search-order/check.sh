#!/usr/bin/env bash
# Asserts on the SEQUENCE of `id` attributes each deck renders — a count
# cannot tell a ranked order from an id-sorted one, and an empty deck looks
# identical to a build that ignored its predicate, which is why every check
# below also demands the deck be non-empty. Modelled on `examples/ordering/
# check.sh` and `search/0.1.0/demo/rheo/check.sh` — greps and a python3
# heredoc, run through `just examples`, which builds first.
set -euo pipefail
cd "$(dirname "$0")"
H=build/html
fail=0
note() { echo "FAIL: $*"; fail=1; }

for f in corpus index ranked narrowed; do
  [ -f "$H/$f.html" ] || note "no page at $H/$f.html"
done

python3 - "$H" <<'PY' || fail=1
import re, sys

H = sys.argv[1]

def decks(page):
    # One list of bare note ids per `div.slipshow` on the page, in document
    # order — `id="slip-idea:<name>"` is `_slip-attrs`'s own scheme
    # (`slipshow.typ`), so this reads the DOM the same way a browser would
    # rather than re-deriving the order out-of-band.
    h = open(f"{H}/{page}.html").read()
    segs = [s for s in re.split(r'(?=<div class="slipshow")', h) if s.startswith('<div class="slipshow"')]
    return [re.findall(r'<section class="slip[^"]*" id="slip-([^"]+)"', s) for s in segs]

bad = 0
def check(label, got, want):
    global bad
    if got != want:
        print(f"FAIL: {label}\n  got:  {got}\n  want: {want}")
        bad = 1

# 1. `index.html`'s query is `method&!draft` (`content/index.typ`) — every
#    note tagged `method` and not also `draft`. Five of the corpus's fifteen
#    notes qualify (`content/corpus.typ`): calib-alpha, calib-beta, calib-xi,
#    method-eta, and archive-lambda — the last carrying `archive` too, which
#    `method&!draft` never looks at.
idx = decks("index")
if len(idx) != 1:
    print(f"FAIL: index.html: expected 1 div.slipshow, found {len(idx)}"); bad = 1
else:
    check("index.html (tags: method&!draft)", idx[0], [
        "idea:archive-lambda", "idea:calib-alpha", "idea:calib-beta",
        "idea:calib-xi", "idea:method-eta",
    ])

# 2. `ranked.html` is `search-ideas("calibration", limit: 8)`'s hits, in RANK
#    order, not id order — the two sequences below differ from their very
#    first entry: `calib-xi`'s short, prefix-matching title outscores
#    `calib-alpha`'s longer one, so the top hit is not the lowest id.
ID_SORTED_TOP8 = [
    "idea:calib-alpha", "idea:calib-delta", "idea:calib-epsilon",
    "idea:calib-gamma", "idea:calib-omicron", "idea:calib-xi",
    "idea:calib-zeta", "idea:draft-nu",
]
RANK_ORDER = [
    "idea:calib-xi", "idea:calib-alpha", "idea:calib-gamma",
    "idea:calib-omicron", "idea:calib-zeta", "idea:calib-delta",
    "idea:calib-epsilon", "idea:draft-nu",
]
if sorted(ID_SORTED_TOP8) != sorted(RANK_ORDER):
    print("FAIL: test bug — ID_SORTED_TOP8 and RANK_ORDER name different sets"); bad = 1
if RANK_ORDER == ID_SORTED_TOP8:
    print("FAIL: test bug — ranked order matches id order; this proves nothing"); bad = 1

rk = decks("ranked")
if len(rk) != 1:
    print(f"FAIL: ranked.html: expected 1 div.slipshow, found {len(rk)}"); bad = 1
else:
    check("ranked.html (slips: search-ideas(..).map(r => r.name))", rk[0], RANK_ORDER)
    if rk[0] and rk[0][0] != RANK_ORDER[0]:
        print(f"FAIL: ranked.html's first slip is {rk[0][0]!r}, not the top hit {RANK_ORDER[0]!r}")
        bad = 1

# 3. Exactly one slip in the ranked deck carries `slip-fullscreen`: `calib-xi`
#    (`content/corpus.typ`) is both the top hit and the one note authored
#    with `fullscreen: true`. This is the assertion the example exists for —
#    passing `window(name)` instead of the bare name would compile and render
#    fine while silently emitting zero `slip-fullscreen` sections here.
h_ranked = open(f"{H}/ranked.html").read()
n_fullscreen = len(re.findall(r'class="slip slip-fullscreen"', h_ranked))
if n_fullscreen != 1:
    print(f"FAIL: ranked.html has {n_fullscreen} slip-fullscreen section(s), want 1")
    bad = 1

# 4. `narrowed.html`'s `where:` keeps only notes with a `created` date in 2026
#    or later, ascending. `calib-gamma` and `method-theta` carry no `created`
#    at all (`content/corpus.typ`) and both are excluded, alongside every
#    dated-but-pre-2026 note.
nw = decks("narrowed")
if len(nw) != 1:
    print(f"FAIL: narrowed.html: expected 1 div.slipshow, found {len(nw)}"); bad = 1
else:
    check("narrowed.html (where: created.year() >= 2026, order: created)", nw[0], [
        "idea:calib-alpha", "idea:calib-beta", "idea:calib-epsilon",
        "idea:method-eta", "idea:result-iota", "idea:draft-nu", "idea:calib-xi",
    ])
    for undated in ("idea:calib-gamma", "idea:method-theta"):
        if undated in nw[0]:
            print(f"FAIL: narrowed.html includes the undated note {undated}")
            bad = 1

# 5. No page's deck is empty. An empty deck is the silent failure mode of
#    every predicate on this page — a query that selects nothing renders a
#    bare `<div class="slipshow">` and looks identical to a build that never
#    ran the predicate at all.
for page, ds in (("index", idx), ("ranked", rk), ("narrowed", nw)):
    for i, d in enumerate(ds):
        if len(d) == 0:
            print(f"FAIL: {page}.html deck {i} is empty"); bad = 1

if not bad:
    print("  index: method&!draft selects 5; ranked: rank order differs from id order,"
          " top hit's fullscreen survived; narrowed: created >= 2026 excludes both"
          " undated notes")
sys.exit(bad)
PY

if [ "$fail" -eq 0 ]; then echo "examples/search-order OK"; else echo "examples/search-order FAILED"; exit 1; fi
