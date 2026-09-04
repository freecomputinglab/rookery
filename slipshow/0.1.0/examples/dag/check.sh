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

# 7. Every layer's member count, matching the corpus's own shape
#    (`content/corpus.typ`): layer 0 is `kickoff` plus four unrelated todos,
#    layer 1 the four that all depend on `kickoff` alone, layer 2 three,
#    layer 3 two. Row 1's count is already pinned above (the id sequence
#    check); this is the regression that matters most through the rewrite to
#    `#todo-slipshow` — the same `div.slip-row` layout, member-for-member,
#    with none of it authored on the page any more.
if len(idx) == 4:
    check("index.html row 0 count", len(idx[0][1]), 5)
    check("index.html row 2 count", len(idx[2][1]), 3)
    check("index.html row 3 count", len(idx[3][1]), 2)

# 8. The status rail: `todo-slip-keys`'s `class:` function (`todos/0.1.0/
#    src/deck.typ`) mints `todo-slip-ready`/`-blocked`/`-closed` straight
#    onto each slide's own `<section>` — the classes `todos.css`'s
#    `.todo-slip-ready`/`-blocked`/`-closed` rules key on.
def section_classes(html):
    return {
        id: cls.split()
        for cls, id in re.findall(r'<section class="([^"]*)" id="([^"]+)"', html)
    }

def has_class(page, classes, id, cls):
    global bad
    if cls not in classes.get(id, []):
        print(f"FAIL: {page}.html: {id} missing class {cls!r}, has {classes.get(id)}")
        bad = 1

idx_classes = section_classes(deck("index"))
has_class("index", idx_classes, "slip-idea:retire-legacy", "todo-slip-closed")
for name in ("kickoff", "renew-lease", "sync-calendar"):
    has_class("index", idx_classes, "slip-idea:" + name, "todo-slip-ready")
for name in ("audit-logs", "collect-data", "review-budget", "draft-notes"):
    has_class("index", idx_classes, "slip-idea:" + name, "todo-slip-blocked")

# 9. A DANGLING DEP DOES NOT BLOCK (`is-blocked`, `todos/0.1.0/src/
#    graph.typ`): `note-onboarding`'s one dep names `legacy-import`, which is
#    not itself a todo, so it resolves to nothing rather than a blocker —
#    the one assertion here that pins that rule from the deck side.
has_class("index", idx_classes, "slip-idea:note-onboarding", "todo-slip-ready")
if "todo-slip-blocked" in idx_classes.get("slip-idea:note-onboarding", []):
    print("FAIL: index.html: note-onboarding carries todo-slip-blocked despite its one dep being dangling")
    bad = 1

# 10. `open-only.html` composes `todo-slip-keys` by hand (`content/
#     open-only.typ`) rather than through `#todo-slipshow`, and the same
#     ready/blocked classes land there too — proof the keys work standalone
#     on the `slips:` route. `todo-slip-closed` cannot appear on this page:
#     the one closed todo, `retire-legacy`, is exactly what
#     `graph-slice(closed: false)` drops (check 5, above).
oo_classes = section_classes(deck("open-only"))
for name in ("kickoff", "renew-lease", "sync-calendar", "note-onboarding"):
    has_class("open-only", oo_classes, "slip-idea:" + name, "todo-slip-ready")
for name in ("audit-logs", "collect-data", "review-budget", "draft-notes"):
    has_class("open-only", oo_classes, "slip-idea:" + name, "todo-slip-blocked")

if not bad:
    print("  index: 4 layers, row 1 in priority/name order, every row max-width'd")
    print("  index: status rail matches the graph, including the dangling-dep case")
    print("  open-only: one fewer section, layers still contiguous, same rail")
    print("  wide: one row, eight sections")
sys.exit(bad)
PY

if [ "$fail" -eq 0 ]; then echo "examples/dag OK"; else echo "examples/dag FAILED"; exit 1; fi
