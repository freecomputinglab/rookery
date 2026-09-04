#!/usr/bin/env bash
# Asserts on this fixture's OUTPUT, not merely that the build succeeded.
#
# Greps rather than a test framework, deliberately, matching @rookery/core's own
# demo check: the package already has a `node --test` suite for its browser half
# and a parity harness for its ranking, and neither can see what rheo actually
# wrote to disk. THAT is what this file is for — the asset plumbing and the
# island, which only exist after a real rheo build.
#
# Run through `just check`, which builds first.
set -euo pipefail
cd "$(dirname "$0")"
H=build/html
fail=0
note() { echo "FAIL: $*"; fail=1; }

# 1. The build produced the pages the spine declares, at both depths. The
#    nested vertebra is not decoration: every depth assertion below needs a page
#    that is not at the root.
for f in index.html sub/page.html; do
  [ -f "$H/$f" ] || note "no page at $f"
done

# 2. The package's assets were copied in by rheo's own package-asset detection,
#    which scans a project's `.typ` files for `@rheo/<pkg>` imports. `dist/` is
#    gitignored, so a missing file here usually means `just build` was skipped.
#
#    NO JavaScript FILENAME IS NAMED, here or in 3. This package declares its
#    scripts twice in `typst.toml` — `[tool.rheo.html]`'s single vite bundle
#    (`dist/lib.js`) and `[tool.rheo.source.html]`'s fourteen unbundled modules
#    — and which of the two rheo injects depends on how the package was
#    RESOLVED: from a directory on disk (what a `path` override is) it serves
#    the source list, as a built package it serves the bundle. Both are wanted
#    shipping shapes, so a check that greps for `lib.js` is a check the fixture
#    can only ever be run one of those two ways. The contract this asserts
#    instead is the shape-independent one: SOME search JavaScript was copied
#    under `rookery/search/`, and every page links it at that page's own
#    prefix. `search.css` is the same file either way and is still named.
js=$(find "$H/rookery/search" -maxdepth 1 -name '*.js' -printf '%f\n' 2>/dev/null | sort)
[ -n "$js" ] || note "no .js copied under rookery/search/ (did you run 'just build'?)"
[ -f "$H/rookery/search/search.css" ] ||
  note "asset not copied to rookery/search/search.css (did you run 'just build'?)"

# 3. Both assets are LINKED from every page, at the right depth-relative
#    prefix — `rheo/...` at the root, `../rheo/...` one level down. This is the
#    assertion a root-only fixture cannot make, and getting it wrong ships a
#    site whose search silently never loads on its inner pages.
links_js() { # page prefix — is one of the copied .js files linked at this prefix?
  local page=$1 prefix=$2 f
  for f in $js; do
    if grep -q "\"$prefix$f\"" "$page"; then return 0; fi
  done
  return 1
}
links_js "$H/index.html" "rookery/search/" ||
  note "index.html does not link the search JS at the root-relative prefix"
grep -q '"rookery/search/search.css"' "$H/index.html" ||
  note "index.html does not link search.css at the root-relative prefix"
links_js "$H/sub/page.html" "../rookery/search/" ||
  note "sub/page.html does not link the search JS at the depth-relative prefix"
grep -q '"../rookery/search/search.css"' "$H/sub/page.html" ||
  note "sub/page.html does not link search.css at the depth-relative prefix"

# 4. The JSON island is present and parses, with one row per registered note.
#    `#search-index` filters to notes that have a minted page (`href != none`),
#    so this also proves the two packages agree about the registry.
python3 - "$H/index.html" <<'PY' || fail=1
import json, re, sys
h = open(sys.argv[1]).read()
m = re.search(r'<script type="application/json"[^>]*>(.*?)</script>', h, re.S)
if not m:
    print("FAIL: no JSON search island in index.html"); sys.exit(1)
try:
    rows = json.loads(m.group(1))
except json.JSONDecodeError as e:
    print(f"FAIL: search island is not valid JSON: {e}"); sys.exit(1)
if not rows:
    print("FAIL: search island is empty"); sys.exit(1)
for r in rows:
    if "id" not in r or "href" not in r:
        print(f"FAIL: row missing id or href: {r}"); sys.exit(1)
    # Tag NAMES only, never the 0.5.0 tag dictionary's values: a value can be a
    # datetime or content, and `json.encode` of content does not error — it
    # emits a structural blob and bloats every page. See @rookery/core's
    # `ideas()`, which publishes keys for exactly this reason.
    tags = r.get("tags", [])
    if not isinstance(tags, list) or not all(isinstance(t, str) for t in tags):
        print(f"FAIL: row {r['id']} has non-string tags: {tags!r}"); sys.exit(1)
print(f"  island: {len(rows)} rows, all with id/href, tags flat strings")
PY

# 5. Every href in the island resolves to a file rheo actually wrote. A row
#    pointing at nothing is a search result that 404s on click.
python3 - "$H" <<'PY' || fail=1
import json, os, re, sys
H = sys.argv[1]
h = open(os.path.join(H, "index.html")).read()
rows = json.loads(re.search(r'<script type="application/json"[^>]*>(.*?)</script>', h, re.S).group(1))
missing = [r["href"] for r in rows if not os.path.isfile(os.path.join(H, r["href"]))]
if missing:
    print(f"FAIL: {len(missing)} island href(s) resolve to no file: {missing[:3]}"); sys.exit(1)
print(f"  hrefs: all {len(rows)} resolve to a file on disk")
PY

# 6. Both UI surfaces rendered. They are separate entry points and a project
#    may use either, so neither one standing in for the other is enough.
# `class="rookery-search"` is `#search-bar`'s own wrapper; the modal wears
# `rookery-search-modal`. Matched on the exact attribute so the bar's assertion
# cannot be satisfied by the modal's longer prefix.
grep -q 'class="rookery-search"' "$H/index.html" ||
  note "index.html does not carry the #search-bar element"
grep -q 'class="rookery-search-modal"' "$H/index.html" ||
  note "index.html does not carry the #search-modal element"

# 7. #panel — the projection-driven filter. A DIFFERENT surface again, and the
#    assertions below are the ones the widget's own design rules turn on rather
#    than "it rendered".
python3 - "$H" <<'PANEL' || fail=1
import os, re, sys
H = sys.argv[1]
h = open(os.path.join(H, "index.html")).read()

# FOUR PANELS: two `#panel`s over the projection, and two `#filter-panel`s over tags —
# one with authored pills, one with `pills: auto`. The facet assertions below are about
# the first two, so they are separated by MODE rather than by position —
# `data-panel-mode="tags"` is the attribute one script uses to tell the two kinds apart,
# and it is the honest discriminator here too.
panels = re.findall(r'<div class="panel"[^>]*>', h)
if len(panels) != 4:
    print(f"FAIL: expected 4 panels on index.html, found {len(panels)}"); sys.exit(1)
faceted = [p for p in panels if 'data-panel-mode="tags"' not in p]
tagged = [p for p in panels if 'data-panel-mode="tags"' in p]
if len(faceted) != 2 or len(tagged) != 2:
    print(f"FAIL: expected 2 faceted panels and 2 tag panels, got {len(faceted)}/{len(tagged)}")
    sys.exit(1)

# NO JSON ISLAND OF ITS OWN. A panel's facts ride as `data-` attributes on the
# rows, so the markup IS the payload and the two cannot disagree. Asserted as
# "every island on the page is the SEARCH index" rather than as a count: the bar
# and the modal each emit one by default, so this page legitimately carries three,
# all with the same id (MEASURED). A count would only have recorded that number.
ids = set(re.findall(r'<script type="application/json" id="([^"]*)"', h))
if ids != {"rookery-search-index"}:
    print(f"FAIL: a panel emitted a JSON island of its own; island ids are {ids}")
    sys.exit(1)

# Every panel starts NOT READY, which is what the stylesheet hangs the no-JS
# degradation on: no input, no pills, no scroll cap until the script says so.
if not all('data-panel-ready="false"' in p for p in panels):
    print("FAIL: a panel is not emitted with data-panel-ready=false"); sys.exit(1)

# The projected facet values reach the rows as `data-<field>`, and the pills are
# one per value A ROW ACTUALLY HAS — never per value the vocabulary permits.
# `<li class="panel-row"` MATCHES ONLY THE FACETED PANELS' ROWS, which is what keeps
# these assertions honest now that a third panel exists: a `#filter-panel` row is an
# `#idea-row` and its class list opens `idea-row panel-row`, so it cannot be confused
# for one of these.
kinds = set(re.findall(r'<li class="panel-row"[^>]*data-kind="([^"]*)"', h))
if not {"prose", "cited"} <= kinds:
    print(f"FAIL: panel rows do not carry projected data-kind values, got {kinds}"); sys.exit(1)
pill_vals = set(re.findall(r'data-panel-facet="kind" data-panel-value="([^"]*)"', h))
if not pill_vals or not pill_vals <= (kinds - {""}):
    print(f"FAIL: kind pills {pill_vals} are not drawn from the row values {kinds}")
    sys.exit(1)

# A `from:` extractor projecting a BOOL comes through as a scalar attribute,
# which is the whole point of the projection's scalar contract.
flags = set(re.findall(r'<li class="panel-row"[^>]*data-flag="([^"]*)"', h))
if not flags <= {"true", "false"}:
    print(f"FAIL: bool facet did not stringify to true/false, got {flags}"); sys.exit(1)

# NO ROW IS CAPPED AWAY. `visible:` is a scroll cap, not a data cap: the first
# panel declares 2 and the corpus is 4, so anything at or below 2 would mean rows
# had been dropped from the markup rather than merely scrolled out of view.
first = h[h.index(panels[0]):]
first = first[:first.index("</ul>")]
n_rows = len(re.findall(r'<li class="panel-row"', first))
if 'style="--panel-rows: 2"' not in panels[0]:
    print(f"FAIL: first panel does not carry --panel-rows: 2; got {panels[0]}"); sys.exit(1)
if n_rows <= 2:
    print(f"FAIL: first panel emitted only {n_rows} rows behind a 2-row box; visible: is a scroll cap, not a data cap")
    sys.exit(1)
print(f"  panels: 2, no island of their own, {n_rows} rows behind a 2-row box, kinds {sorted(kinds - {chr(39)+chr(39)})}")
PANEL

# 8. A TITLELESS NOTE IS NAMED BY ITS OPENING WORDS, in the island and in the
#    ranking. Rookery derives `label` for a note written as bare `#idea[body]`;
#    until this package read it, such a note shipped an empty title and the row
#    printed its sequence number instead.
python3 - "$H" <<'LABEL' || fail=1
import json, os, re, sys
H = sys.argv[1]
h = open(os.path.join(H, "index.html")).read()
rows = json.loads(re.search(r'<script type="application/json"[^>]*>(.*?)</script>', h, re.S).group(1))

# The demo's one titleless note. Found by its ABSENCE of an authored title, not
# by id: its id is an auto-assigned sequence number and pinning it here would
# break the moment a note is inserted earlier in the document.
derived = [r for r in rows if r["text"].startswith("Marginalia accumulate")]
if len(derived) != 1:
    got = [r["text"][:30] for r in rows]
    print(f"FAIL: no island row named by the titleless note's opening words; got {got}")
    sys.exit(1)

# Never the bare id or an empty string, which is what the old fallback produced.
title = derived[0]["text"]
if title == "" or title == derived[0]["name"]:
    print(f"FAIL: titleless row shipped its id or an empty title: {derived[0]}")
    sys.exit(1)
print(f'  label: titleless note ships as "{title[:34]}..."')

# THE RANKING HALF. `#search-ideas("marginalia")` renders its hits into
# `.demo-label-hits` as `id|kind` pairs. The note must come back in the NAME tier:
# a body-tier hit would mean the title score is still being skipped for a titleless
# note, which is the actual bug rather than a detail of it.
m = re.search(r'<p class="demo-label-hits">([^<]*)</p>', h)
if m is None:
    print("FAIL: index.html carries no .demo-label-hits probe"); sys.exit(1)
hits = [x for x in m.group(1).split(",") if x]
if not hits:
    print("FAIL: searching a titleless note's opening word found nothing"); sys.exit(1)
if not any(x.endswith("|name") for x in hits):
    print(f"FAIL: titleless note matched only in the body tier: {hits}"); sys.exit(1)
print(f"  label: 'marginalia' ranks {hits}")
LABEL

# ---- #filter-panel: tag pills over the shared #idea-row -----------------------
#
# The other panel shape. Everything here is about what only a real rheo build can
# show: the row markup came from @rookery/core (`.idea-row`), and a pill nothing
# carries was dropped before it reached the page.
FP=build/html/index.html
grep -q 'data-panel-mode="tags"' "$FP" || note "the filter panel did not emit data-panel-mode=tags"
grep -q 'data-panel-pill-match="all"' "$FP" || note "the declared pill-match did not reach the markup"
grep -q 'data-panel-tag="demo-a"' "$FP" || note "no demo-a pill"
grep -q 'data-panel-tag="demo-b"' "$FP" || note "no demo-b pill"
if grep -q 'data-panel-tag="never-carried"' "$FP"; then
  note "a pill no row carries reached the page; it must be dropped"
fi
# Their tag attributes are what the script composes. The attribute is space-padded at
# both ends so a prefix cannot half-match. This panel declares `pill-match="all"`, the
# non-default, so the markup has to say so. (The per-panel ROW COUNT is asserted in the
# python block below, which can tell the two tag panels apart; a file-wide grep cannot.)
grep -q 'data-panel-tags=" demo-a demo-b "' "$FP" || note "the both-pills row's tags are wrong"
grep -q 'data-panel-tags=" demo-a "' "$FP" || note "the one-pill row's tags are wrong"
grep -q 'data-panel-tags="  "' "$FP" || note "the no-pills row should carry an empty padded list"
# THE ROW IS ROOKERY'S. If this fails, the panel is drawing its own markup again.
grep -q 'class="idea-row panel-row' "$FP" || note "filter-panel rows are not #idea-row"

# AND THE ATTRIBUTE, NOT ONLY THE CLASS — this is the assertion that says a
# filter-panel actually HIDES anything, and it is separate from the class check
# above because the class is not what does the hiding.
#
# `wirePanel` (src/panel.js) sets `row.el.hidden = true` on every excluded row,
# and a row stays on screen anyway unless some rule turns `[hidden]` into
# `display: none`. This package ships one — `.panel-row[hidden]`, src/search.css
# — but it sits inside `@layer search`, and an UNLAYERED author rule beats every
# layered one whatever its specificity. `style.css` next door is exactly such a
# rule, deliberately, so in this fixture the package's own hide rule LOSES.
#
# What still hides the row is @rookery/core's `[data-rookery="row"][hidden]`,
# which is unlayered and (0,2,0), and it reaches these rows only because
# `#filter-panel` builds them out of `#idea-row` rather than markup of its own
# (see core's `row.typ`, which records that this is where `#filter-panel` and
# `#panel` diverge). So the guarantee is a joint property of two packages, and
# these two assertions are its guard: the attribute must be on every row, and
# core's rule must stay out of a layer.
python3 - "$FP" "$H" <<'HIDE' || fail=1
import re, sys
page, built = sys.argv[1], sys.argv[2]
ok = True
html = open(page).read()
# BOTH CLASSES, and that narrowing is the point rather than belt-and-braces.
# `#panel` wraps its own `render:` output in a plain `<li class="panel-row">`
# and carries no `data-rookery`, so it has the same weakness — a real one, and
# a separate change, since core keys its own grid template on that attribute.
# This assertion is scoped to `#filter-panel`, whose rows ARE `#idea-row`s and
# therefore wear both classes.
rows = [r for r in re.findall(r'<li\b[^>]*>', html)
        if 'panel-row' in r and 'idea-row' in r]
if not rows:
    print('FAIL: no filter-panel <li> rows found at all'); ok = False
for r in rows:
    if 'data-rookery="row"' not in r:
        print('FAIL: a filter-panel row carries no data-rookery="row"; pressing '
              'a pill will update the count and hide nothing')
        print('      ' + r[:160])
        ok = False
        break
core = open(built + '/rookery/core/core.css').read()
if '[data-rookery="row"][hidden]' not in core:
    print('FAIL: core.css no longer hides [data-rookery="row"][hidden]; a filtered '
          'filter-panel row will stay on screen')
    ok = False
if re.search(r'(?m)^@layer\b', core):
    print('FAIL: core.css opened an @layer; its [hidden] rule would then lose to '
          "a project's own unlayered rule and hide nothing")
    ok = False
sys.exit(0 if ok else 1)
HIDE
grep -q 'class="idea-row-badges"' "$FP" || note "no shared badge strip in the filter panel"
grep -q 'class="idea-tag idea-tag-demo-a"' "$FP" || note "a pill tag did not become a chip on its row"

# ---- #filter-panel with pills: auto ------------------------------------------
#
# THE DERIVED PILL ROW, asserted on the output because every rule it follows is about
# markup that nothing declared: which tags became buttons, which did not, and which
# became chips. All three are correct-looking HTML when wrong, so neither a Typst
# fixture nor a build failure can see any of it.
#
# SEGMENTED BY PANEL, not grepped file-wide: there are two tag panels on this page now
# and a bare grep cannot say which one it found.
python3 - "$FP" <<'AUTO' || fail=1
import re, sys
h = open(sys.argv[1]).read()

bad = 0
def note(m):
    global bad
    print("FAIL: " + m); bad = 1

# Each `.panel` div, split on the opening tag; the derived one is the panel whose
# placeholder says so. THE CLASS MUST END at the quote or a space: `panel-pills` starts
# with `panel` too, and a looser lookahead split each panel in half right before its own
# pill row — leaving a segment that held the input and no buttons at all.
panels = re.split(r'(?=<div class="panel[" ])', h)
auto = [p for p in panels if 'placeholder="Filter auto notes"' in p]
if len(auto) != 1:
    print(f"FAIL: found {len(auto)} derived-pill panels, wanted 1"); sys.exit(1)
seg = auto[0]

pills = re.findall(r'data-panel-tag="([^"]*)"', seg)
if sorted(pills) != ["auto-x", "auto-y"]:
    note(f"derived pills are {sorted(pills)}, wanted auto-x/auto-y — `auto-note` is a"
         f" VALUED tag and can have no pill, `hide-me-a` and the scoping `demo-auto`"
         f" are filtered out by tag-filter")

rows = re.findall(r'data-panel-tags="([^"]*)"', seg)
if len(rows) != 2:
    note(f"expected 2 rows in the derived panel, found {len(rows)}")
# The attribute carries the PILL set, never the chip set: a pill whose tag never
# reaches it is a button that hides every row.
if sorted(rows) != [" auto-x ", " auto-y "]:
    note(f"row pill sets are {sorted(rows)}, wanted ' auto-x ' and ' auto-y '")

# Chips are the AUTHORED list alone. `auto-y` earns a pill and must NOT earn a chip,
# which is the whole point of naming the two separately.
chips = re.findall(r'class="idea-tag idea-tag-([a-z0-9-]+)"', seg)
if chips != ["auto-x"]:
    note(f"chips are {chips}, wanted auto-x alone — a derived pill must not become a chip")

# THE QUERY CHANNEL, a SECOND attribute and not the pill set. Every tag the note
# carries rides here — including the ones the pills deliberately exclude, which is the
# whole reason it is separate: `tag-filter:` and `pills: auto` between them leave most
# of a note's tags unpressable, and a `tags:` expression must still be able to name
# them.
allt = re.findall(r'data-panel-all-tags="([^"]*)"', seg)
if len(allt) != 2:
    note(f"expected 2 data-panel-all-tags in the derived panel, found {len(allt)}")
both = [a for a in allt if "auto-x" in a]
if len(both) != 1:
    note(f"could not find the auto-both row's query tags among {allt}")
else:
    for want in ("demo-auto", "auto-x", "hide-me-a", "auto-note"):
        if want not in both[0]:
            note(f"{want!r} is missing from data-panel-all-tags={both[0]!r} —"
                 f" the query channel carries EVERY tag, pills or no pills")
for a in allt:
    if a and not (a.startswith(" ") and a.endswith(" ")):
        note(f"data-panel-all-tags={a!r} is not space-padded at both ends")

if not bad:
    print(f"  auto pills: {sorted(pills)}, chips {chips}, {len(rows)} rows,"
          f" query tags {both[0].strip().split() if both else None}")
sys.exit(bad)
AUTO

# EVERY PANEL ROW ON THE PAGE carries the query channel, in both panel kinds — the two
# faceted `#panel`s as well as the two tag panels. A row without it is a row no tag
# expression can ever match, which is invisible in the output and would look like the
# query language simply not working for that one note.
python3 - "$FP" <<'ALLTAGS' || fail=1
import re, sys
h = open(sys.argv[1]).read()
rows = len(re.findall(r'class="[^"]*panel-row', h))
attrs = len(re.findall(r'data-panel-all-tags="', h))
if rows == 0:
    print("FAIL: no panel rows at all"); sys.exit(1)
if rows != attrs:
    print(f"FAIL: {rows} panel rows but {attrs} data-panel-all-tags attributes — the"
          f" attribute must be unconditional, the empty string included")
    sys.exit(1)
print(f"  query channel: {attrs}/{rows} rows carry data-panel-all-tags")
ALLTAGS

if [ "$fail" -eq 0 ]; then echo "demo/rheo OK"; else echo "demo/rheo FAILED"; exit 1; fi
