#!/usr/bin/env bash
# Asserts on the LAYOUT this example exists to prove — the depth-first block
# sequence each page emits, the one row holding the four todos `kickoff`
# releases, in priority-then-name order, and a `max-width` on every slip
# sharing a row with another — rather than merely that the build succeeded.
# Modelled on `search/0.1.0/demo/rheo/check.sh` and `../ordering/check.sh`:
# greps for what a grep can express, a python3 heredoc for the rest.
#
# Run through `just examples`, which builds this package and compiles every
# example first — `@rookery/todos` is a SIBLING package with its own build
# step, so it has to be built separately at least once (`../readme.md`).
set -euo pipefail
cd "$(dirname "$0")"
H=build/html
fail=0
note() { echo "FAIL: $*"; fail=1; }

for f in index across open-only wide; do
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

TAGS = (r'<div class="slip-row" data-row="(\d+)"|<div\b|</div>'
        r'|<section class="slip[^"]*" id="([^"]+)"')

def blocks(html):
    # Every `div.slip-row` and every `section.slip` that is NOT inside one, in
    # document order: `("row", data-row, ids)` or `("bare", None, [id])`.
    #
    # NESTING IS TRACKED, NOT SPLIT ON. A deck now mixes bare slides in among
    # its rows, and splitting the markup on the wrapper's opening tag would
    # sweep every later bare slide into whichever row preceded it. The opening
    # `div.slipshow` itself matches the bare-`<div>` alternative, so depth
    # starts at 1 inside the deck and a row's own depth is what closes it.
    out, depth, rowdepth = [], 0, None
    for m in re.finditer(TAGS, html):
        s = m.group(0)
        if s.startswith('<div class="slip-row"'):
            depth += 1
            rowdepth = depth
            out.append(("row", m.group(1), []))
        elif s.startswith('<div'):
            depth += 1
        elif s == '</div>':
            if depth == rowdepth:
                rowdepth = None
            depth -= 1
        elif rowdepth is not None:
            out[-1][2].append(m.group(2))
        else:
            out.append(("bare", None, [m.group(2)]))
    return out

def rows(html):
    return [(r, ids) for kind, r, ids in blocks(html) if kind == "row"]

def seq(html):
    # The same sequence with the `slip-idea:` prefix and the row number
    # dropped — the row NUMBERS are group ids `dfs-of` mints and nothing
    # reads them as an index, so pinning them would assert an implementation
    # detail rather than a layout.
    return [
        (kind, [i.removeprefix("slip-idea:") for i in ids])
        for kind, _, ids in blocks(html)
    ]

# 1. THE DEPTH-FIRST SEQUENCE, block by block. `kickoff` stacks on its own,
#    the four todos it releases share ONE row, and each of those four is then
#    followed down its own branch before the next dependency-free todo starts
#    — `merge-results` and `ship-final` are `audit-logs`' branch, not a layer.
#    The four remaining dependency-free todos come last, in priority-then-name
#    order (`note-onboarding` 2, `renew-lease` 2, `sync-calendar` 3,
#    `retire-legacy` 4), each stacking on its own.
INDEX_SEQ = [
    ("bare", ["kickoff"]),
    ("row", ["audit-logs", "collect-data", "review-budget", "draft-notes"]),
    ("bare", ["merge-results"]),
    ("bare", ["ship-final"]),
    ("bare", ["compile-summary"]),
    ("bare", ["sign-off"]),
    ("bare", ["publish-report"]),
    ("bare", ["note-onboarding"]),
    ("bare", ["renew-lease"]),
    ("bare", ["sync-calendar"]),
    ("bare", ["retire-legacy"]),
]
check("index.html block sequence", seq(deck("index")), INDEX_SEQ)

# 2. The one row's ORDER: priority then name, unprioritised last.
#    `audit-logs`/`collect-data` share priority 1 (name breaks the tie),
#    `review-budget` is priority 3, and `draft-notes` carries no priority at
#    all — the corpus's one deliberately unprioritised sibling
#    (`content/corpus.typ`) — so it must still come last, not first. Pinned
#    separately from the sequence above because it is the tie-break rule
#    `dfs-of` shares with `layers()`, not a fact about the walk.
idx = rows(deck("index"))
if len(idx) != 1:
    print(f"FAIL: index.html: expected 1 div.slip-row, found {len(idx)}"); bad = 1
else:
    check(
        "index.html row id sequence (priority, then name, unprioritised last)",
        idx[0][1],
        ["slip-idea:audit-logs", "slip-idea:collect-data",
         "slip-idea:review-budget", "slip-idea:draft-notes"],
    )

# 3. `across.html` is the same graph under `direction: "across"`, and the one
#    difference is the top: the five todos with nothing blocking them span a
#    single row instead of stacking, and everything they release is laid out
#    exactly as it is on `index.html`.
ACROSS_SEQ = [
    ("row", ["kickoff", "note-onboarding", "renew-lease", "sync-calendar",
             "retire-legacy"]),
    ("row", ["audit-logs", "collect-data", "review-budget", "draft-notes"]),
    ("bare", ["merge-results"]),
    ("bare", ["ship-final"]),
    ("bare", ["compile-summary"]),
    ("bare", ["sign-off"]),
    ("bare", ["publish-report"]),
]
check("across.html block sequence", seq(deck("across")), ACROSS_SEQ)

# 4. Every section sharing a row with another carries a `max-width` in its
#    inline `style` — a multi-slip row with no cap is four full-width slips
#    scrolled one at a time, not the layout this example is proving.
for page in ("index", "across"):
    html = deck(page)
    for row, ids in rows(html):
        if len(ids) <= 1:
            continue
        for id in ids:
            sec = re.search(
                r'<section class="slip[^"]*" id="' + re.escape(id) + r'"[^>]*>', html,
            )
            if sec is None or "max-width" not in sec.group(0):
                note(f"{page}.html: {id} (row {row}) carries no max-width")

# 5. `open-only.html` drops exactly the one closed todo (`retire-legacy`,
#    `content/corpus.typ`) and nothing else. `graph-slice` narrows the graph;
#    it does not disturb the walk over what is left, so the sequence is
#    `index.html`'s with that one bare block removed.
check("open-only.html block sequence",
      seq(deck("open-only")),
      [b for b in INDEX_SEQ if b != ("bare", ["retire-legacy"])])

# 6. `wide.html` is the deliberately overdone case: one row, eight slips,
#    each capped at 20em so the row overflows and scrolls horizontally
#    within itself rather than the page growing wider.
wide = rows(deck("wide"))
if len(wide) != 1:
    print(f"FAIL: wide.html: expected 1 div.slip-row, found {len(wide)}"); bad = 1
else:
    check("wide.html row 0 section count", len(wide[0][1]), 8)

# 7. The status rail: `todo-slip-keys`'s `class:` function (`todos/0.1.0/
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

# 8. A DANGLING DEP DOES NOT BLOCK (`is-blocked`, `todos/0.1.0/src/
#    graph.typ`): `note-onboarding`'s one dep names `legacy-import`, which is
#    not itself a todo, so it resolves to nothing rather than a blocker —
#    the one assertion here that pins that rule from the deck side. It is the
#    same rule that makes `note-onboarding` a root of the walk above.
has_class("index", idx_classes, "slip-idea:note-onboarding", "todo-slip-ready")
if "todo-slip-blocked" in idx_classes.get("slip-idea:note-onboarding", []):
    print("FAIL: index.html: note-onboarding carries todo-slip-blocked despite its one dep being dangling")
    bad = 1

# 9. `open-only.html` composes `todo-slip-keys` by hand (`content/
#    open-only.typ`) rather than through `#todo-slipshow`, and the same
#    ready/blocked classes land there too — proof the keys work standalone
#    on the `slips:` route. `todo-slip-closed` cannot appear on this page:
#    the one closed todo, `retire-legacy`, is exactly what
#    `graph-slice(closed: false)` drops (check 5, above).
oo_classes = section_classes(deck("open-only"))
for name in ("kickoff", "renew-lease", "sync-calendar", "note-onboarding"):
    has_class("open-only", oo_classes, "slip-idea:" + name, "todo-slip-ready")
for name in ("audit-logs", "collect-data", "review-budget", "draft-notes"):
    has_class("open-only", oo_classes, "slip-idea:" + name, "todo-slip-blocked")

# 10. THE CONNECTOR EDGES. `todo-slip-keys`'s `edges:` function (`todos/
#     0.1.0/src/deck.typ`) hands `#slipshow` the todos BLOCKING each one, and
#     `#slipshow` resolves them to the element ids of the slides showing them
#     (`data-slip-edges`, `slipshow/0.1.0/src/slipshow.typ`'s header).
#
#     NOTHING HERE ASSERTS ON THE `<svg>` OR ITS PATHS, deliberately: the
#     connector layer is built by `src/edges.js` at runtime and this file
#     reads static build output, where no script has run, so a path count
#     could never pass. The declaration is the half that comes from the graph
#     and the half a build can see; the drawing is covered by
#     `test/edges.test.mjs` (its geometry) and by a browser (its appearance).
def section_edges(html):
    # `data-slip-edges` per section id. A section WITHOUT the attribute is
    # absent from the dict entirely rather than mapped to `[]` — the two are
    # different claims and three of the checks below turn on the difference.
    out = {}
    for tag in re.findall(r'<section class="slip[^"]*"[^>]*>', html):
        id_m = re.search(r' id="([^"]+)"', tag)
        e_m = re.search(r' data-slip-edges="([^"]*)"', tag)
        if id_m and e_m:
            out[id_m.group(1)] = e_m.group(1).split()
    return out

idx_edges = section_edges(deck("index"))
oo_edges = section_edges(deck("open-only"))

# A slide `kickoff` releases depends on it alone; one further down the branch
# on two todos, and the attribute keeps them in `deps` order rather than
# sorting them.
check("index.html audit-logs edges", idx_edges.get("slip-idea:audit-logs"),
      ["slip-idea:kickoff"])
check("index.html merge-results edges (in deps order)",
      idx_edges.get("slip-idea:merge-results"),
      ["slip-idea:audit-logs", "slip-idea:collect-data"])

# `kickoff` depends on nothing, so nothing feeds its rail and it carries no
# attribute at all — not an empty one.
if "slip-idea:kickoff" in idx_edges:
    print(f"FAIL: index.html: kickoff carries data-slip-edges="
          f"{idx_edges['slip-idea:kickoff']} despite depending on nothing")
    bad = 1

# THE DECK-SIDE TWIN OF CHECK 8. `note-onboarding`'s one dep is dangling, so
# it is not a blocker and draws no curve either — the pair pins that rule from
# both directions, the class and the edge.
if "slip-idea:note-onboarding" in idx_edges:
    print("FAIL: index.html: note-onboarding carries data-slip-edges despite "
          "its one dep being dangling")
    bad = 1

# EVERY ID NAMED RESOLVES TO A SLIDE ON THE SAME PAGE. This is what would
# catch the drop-names-outside-the-deck rule regressing into an attribute full
# of ids pointing nowhere — edges no curve could ever be drawn for.
for page, edges in (("index", idx_edges), ("open-only", oo_edges)):
    present = set(section_classes(deck(page)))
    for source, targets in edges.items():
        for t in targets:
            if t not in present:
                print(f"FAIL: {page}.html: {source}'s data-slip-edges names {t}, "
                      f"which is no section on this page")
                bad = 1

# `open-only.html` reaches `#slipshow` by the `slips:` route
# (`content/open-only.typ`), and the same edges land there: `edges:` composes
# with an explicit array exactly as `row:` and `class:` already do. The
# corpus's one closed todo blocks nothing, so dropping it takes no edge with
# it and the answer is the same as on `index.html`.
check("open-only.html merge-results edges",
      oo_edges.get("slip-idea:merge-results"),
      ["slip-idea:audit-logs", "slip-idea:collect-data"])

if not bad:
    print("  index: depth-first sequence, one sibling row in priority/name order")
    print("  across: the dependency-free todos span one row, the rest unchanged")
    print("  index/across: every multi-slip row is max-width'd")
    print("  index: status rail matches the graph, including the dangling-dep case")
    print("  index: connector edges are the open deps, and every id names a slide")
    print("  open-only: one fewer section, same walk, same rail")
    print("  wide: one row, eight sections")
sys.exit(bad)
PY

if [ "$fail" -eq 0 ]; then echo "examples/dag OK"; else echo "examples/dag FAILED"; exit 1; fi
