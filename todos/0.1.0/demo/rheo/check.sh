#!/usr/bin/env bash
# Asserts on this demo's OUTPUT, not merely that the build succeeded.
#
# Greps rather than a test framework, matching the other demos here. The `node
# --test` suite covers the pure halves (`score`, `passes`, the graph layout) and
# `just test` covers the Typst helpers; neither can see what rheo wrote to disk.
#
# Run through `just check`, which builds first.
set -euo pipefail
cd "$(dirname "$0")"
H=build/html
fail=0
note() { echo "FAIL: $*"; fail=1; }

[ -f "$H/index.html" ] || note "no page at index.html"

# THE FILTER ACTUALLY HIDES ROWS. `#todos-search`'s script sets the `hidden`
# attribute, and that alone does NOTHING here: a search row carries `todo-row`,
# which the stylesheet makes `display: flex`, and the UA's
# `[hidden] { display: none }` loses to any author rule setting `display`.
#
# MEASURED on a live site before the rule existed: `hidden=true` and
# `display: flex` on the same element, so typing reordered the list and removed
# nothing from it. The JS was correct and the page was wrong.
#
# A computed-style assertion would need a browser and this repo's CI has none,
# so this greps for the rule instead — the cheap honest guard against the two
# halves drifting apart again.
grep -q 'todo-search-row\[hidden\]' "$H/rookery/todos/todos.css" ||
  note "the built CSS has no .todo-search-row[hidden] rule — the filter will hide nothing"

# The widget rendered, and ships closed so the no-JS state is the plain list.
grep -q 'class="todo-search"' "$H/index.html" ||
  note "index.html carries no #todos-search widget"
grep -q 'data-todo-search-ready="false"' "$H/index.html" ||
  note "the widget does not ship data-todo-search-ready=\"false\" (no-JS degradation)"

# Every row carries the attributes the filter reads. A row missing one is a row
# the filter silently never matches.
python3 - "$H/index.html" <<'PY' || fail=1
import re, sys
h = open(sys.argv[1]).read()
rows = re.findall(r'<li class="[^"]*todo-search-row[^"]*"([^>]*)>', h)
if not rows:
    print("FAIL: no todo-search-row elements"); sys.exit(1)
bad = 0
for r in rows:
    for a in ("data-todo-name", "data-todo-status", "data-todo-text"):
        if f"{a}=" not in r:
            print(f"FAIL: a search row is missing {a}"); bad = 1
if not bad:
    print(f"  search: {len(rows)} rows, all with name/status/text")
sys.exit(bad)
PY

# THE SKIN: `#window` from this package hides a closed todo, and `closed: true`
#    opts it back in. Asserted on the OUTPUT because the whole point is what did
#    not get rendered, which no Typst fixture can see.
python3 - "$H" <<'SKIN' || fail=1
import os, re, sys
H = sys.argv[1]
h = open(os.path.join(H, "index.html")).read()
i = h.index("closed todo is not transcluded")
j = h.index("An epic", i)
seg = h[i:j]

# THREE windows in that section: fetch (closed, hidden), fetch with closed: true
# (shown), parse (open, shown). So `fetch` appears ONCE, not twice.
n_fetch = seg.count("idea:fetch")
if n_fetch != 1:
    print(f"FAIL: idea:fetch appears {n_fetch} times in the skin section, wanted 1 —"
          f" a closed todo should be hidden by default and shown only with closed: true")
    sys.exit(1)
if "idea:parse" not in seg:
    print("FAIL: an OPEN todo was hidden too; the filter is not keyed on closedness")
    sys.exit(1)
print("  skin: closed todo hidden by default, shown with closed: true, open one unaffected")
SKIN

# `#filter-panel`'s FOUR PILL GROUPS, and the `tag` one in particular. Asserted on
#    the output because the whole claim is about markup nothing declared: the tag
#    pills are the union of what the listed todos carry, so a pill that is missing
#    is a filter the reader never sees and a pill too many is one that matches
#    nothing. Neither is visible from a Typst fixture, and neither would fail the
#    build.
python3 - "$H/index.html" <<'PANEL' || fail=1
import re, sys
h = open(sys.argv[1]).read()
i = h.index("Filter them in groups")
seg = h[i:h.index("The dependency graph", i)]

bad = 0
def note(m):
    global bad
    print("FAIL: " + m); bad = 1

groups = re.findall(r'data-panel-group="([^"]*)"', seg)
if groups != ["epic", "tag", "state", "priority"]:
    note(f"the panel's pill groups are {groups}, wanted epic/tag/state/priority")

# The script cannot infer which attributes hold a SET — a padded " a b " and a
# scalar are the same string — so the Typst side must say. Without this the tag
# pills would test equality against the whole token list and match nothing.
if 'data-panel-multi="tag"' not in seg:
    note("the panel does not declare data-panel-multi=\"tag\"; the tag pills would match nothing")

tags = re.findall(r'data-panel-facet="tag" data-panel-value="([^"]*)"', seg)
if tags != ["frontend", "phd"]:
    note(f"the tag pills are {tags}, wanted frontend/phd — the union of the plain tags"
         f" the listed todos carry, with `launch` dropped as the epic group's own")

# PADDED AT BOTH ENDS, per row, which is what keeps a token from half-matching one
# that is another's prefix. `ship` carries two; most carry none.
attrs = re.findall(r'data-tag="([^"]*)"', seg)
if not attrs:
    note("no row carries a data-tag attribute")
for a in attrs:
    if a and not (a.startswith(" ") and a.endswith(" ")):
        note(f"data-tag={a!r} is not space-padded at both ends")
if " frontend phd " not in attrs:
    note("no row carries two tags; the intersection test is unexercised")

if not bad:
    print(f"  filter-panel: 4 groups, tag pills {tags}, {len(attrs)} rows padded")
sys.exit(bad)
PANEL

if [ "$fail" -eq 0 ]; then echo "demo/rheo OK"; else echo "demo/rheo FAILED"; exit 1; fi
