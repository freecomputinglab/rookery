#!/usr/bin/env bash
# Asserts on the LAYOUT this example exists to prove — one `div.slip-row`
# per graph layer, the wide layer's four members in priority-then-name
# order, and a `max-width` on every slip sharing a row with another —
# rather than merely that the build succeeded. Modelled on
# `search/0.1.0/demo/rheo/check.sh` and `../ordering/check.sh`: greps for
# what a grep can express, a python3 heredoc for the rest.
#
# Run through `just examples`, which builds this package and compiles every
# example first — `@rookery/todos` is a SIBLING package with its own build
# step, so it has to be built separately at least once (`../readme.md`).
set -euo pipefail
cd "$(dirname "$0")"
H=build/html
fail=0
note() { echo "FAIL: $*"; fail=1; }

for f in index open-only wide; do
  [ -f "$H/$f.html" ] || note "no page at $H/$f.html"
done

python3 - "$H" <<'PY' || fail=1
import re, sys

H = sys.argv[1]
bad = 0

def check(label, got, want):
    global bad
    if got != want:
        print(f"FAIL: {label}\n  got:  {got}\n  want: {want}")
        bad = 1

def deck(page):
    # The one `div.slipshow` on the page, as raw HTML — every assertion
    # below reads the markup a browser would see, not a re-derivation of
    # the graph out of band.
    h = open(f"{H}/{page}.html").read()
    m = re.search(r'<div class="slipshow".*', h, re.S)
    if m is None:
        print(f"FAIL: {page}.html: no div.slipshow found")
        sys.exit(1)
    return m.group(0)

def rows(html):
    # One entry per `div.slip-row`, in document order: its `data-row` value
    # and the `id`s of the `section.slip` elements inside it. Splitting on
    # the wrapper's own opening tag keeps a row's sections from leaking into
    # its neighbour's.
    segs = re.split(r'(?=<div class="slip-row")', html)
    out = []
    for s in segs:
        m = re.match(r'<div class="slip-row" data-row="(\d+)"', s)
        if not m:
            continue
        ids = re.findall(r'<section class="slip[^"]*" id="([^"]+)"', s)
        out.append((m.group(1), ids))
    return out

# 1 & 2. Four layers, numbered 0-3, and the wide layer (row 1) holds exactly
#    the four todos that all depend on `kickoff` and on nothing else.
idx = rows(deck("index"))
if len(idx) != 4:
    print(f"FAIL: index.html: expected 4 div.slip-row, found {len(idx)}"); bad = 1
else:
    check("index.html row numbering", [r for r, _ in idx], ["0", "1", "2", "3"])
    check("index.html row 1 count", len(idx[1][1]), 4)

    # 3. Priority then name, unprioritised last: `audit-logs`/`collect-data`
    #    share priority 1 (name breaks the tie), `review-budget` is
    #    priority 3, and `draft-notes` carries no priority at all — the
    #    corpus's one deliberately unprioritised todo in this layer
    #    (`content/corpus.typ`) — so it must still come last, not first.
    check(
        "index.html row 1 id sequence (priority, then name, unprioritised last)",
        idx[1][1],
        ["slip-idea:audit-logs", "slip-idea:collect-data",
         "slip-idea:review-budget", "slip-idea:draft-notes"],
    )

# 4. Every section sharing a row with another carries a `max-width` in its
#    inline `style` — a multi-slip row with no cap is four full-width slips
#    scrolled one at a time, not the layout this example is proving.
if len(idx) == 4:
    for row, ids in idx:
        if len(ids) <= 1:
            continue
        html = deck("index")
        for id in ids:
            sec = re.search(
                r'<section class="slip[^"]*" id="' + re.escape(id) + r'"[^>]*>', html,
            )
            if sec is None or "max-width" not in sec.group(0):
                note(f"index.html: {id} (row {row}) carries no max-width")

# 5. `open-only.html` drops exactly the one closed todo (`retire-legacy`,
#    `content/corpus.typ`) and nothing else, and the remaining layers are
#    still contiguous and still numbered from 0 — `graph-slice` narrows a
#    layer, it does not renumber the ones around it.
oo = rows(deck("open-only"))
idx_total = sum(len(ids) for _, ids in idx) if len(idx) == 4 else None
oo_total = sum(len(ids) for _, ids in oo)
if idx_total is not None:
    check("open-only.html has exactly one fewer section than index.html",
          oo_total, idx_total - 1)
check("open-only.html row numbering (still contiguous from 0)",
      [r for r, _ in oo], ["0", "1", "2", "3"])
all_ids = [i for _, ids in oo for i in ids]
if "slip-idea:retire-legacy" in all_ids:
    print("FAIL: open-only.html: the closed todo (retire-legacy) is still present")
    bad = 1

# 6. `wide.html` is the deliberately overdone case: one row, eight slips,
#    each capped at 20em so the row overflows and scrolls horizontally
#    within itself rather than the page growing wider.
wide = rows(deck("wide"))
if len(wide) != 1:
    print(f"FAIL: wide.html: expected 1 div.slip-row, found {len(wide)}"); bad = 1
else:
    check("wide.html row 0 section count", len(wide[0][1]), 8)

if not bad:
    print("  index: 4 layers, row 1 in priority/name order, every row max-width'd")
    print("  open-only: one fewer section, layers still contiguous")
    print("  wide: one row, eight sections")
sys.exit(bad)
PY

if [ "$fail" -eq 0 ]; then echo "examples/dag OK"; else echo "examples/dag FAILED"; exit 1; fi
