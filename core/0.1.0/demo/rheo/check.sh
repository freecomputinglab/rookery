#!/usr/bin/env bash
# Asserts on this demo's OUTPUT. Everything checked here exists only under rheo
# and none of it is covered by `demo/pure`, which is a single native `typst
# compile` with no minted pages and no cross-page hrefs at all.
#
# Greps rather than a test framework, deliberately: the package ships no runner
# and adding one for four assertions would be more machinery than the thing it
# checks. Run it through `just check`, which builds first.
set -euo pipefail
cd "$(dirname "$0")"
H=build/html
fail=0
note() { echo "FAIL: $*"; fail=1; }

# 1. One minted page per registered note, including the note nested inside
#    another note's body and the one written on the nested vertebra.
for slug in root-note inner-note plain-note sub-note; do
  [ -f "$H/ideas/$slug.html" ] || note "no minted page at ideas/$slug.html"
done

# 2. Depth arithmetic. The root vertebra links to a minted page with no `../`;
#    the nested one, handle `sub:page`, pays exactly one; the doubly-nested one,
#    handle `sub:deeper:page`, pays exactly two. This is the assertion a
#    root-only or one-level spine cannot make, and an off-by-one here breaks
#    every link on every page of a real site.
grep -q 'href="ideas/root-note.html"' "$H/index.html" ||
  note "index.html does not link ideas/root-note.html at depth 0"
grep -q 'href="\.\./ideas/root-note.html"' "$H/sub/page.html" ||
  note "sub/page.html does not link ../ideas/root-note.html at depth 1"
grep -q 'href="\.\./\.\./ideas/w-outer\.html"' "$H/sub/deeper/page.html" ||
  note "sub/deeper/page.html does not link ../../ideas/w-outer.html at depth 2"
# `if !` rather than `grep ... && note ...`: an AND-list whose first command is
# meant to FAIL reads as an accident, and one edit away from tripping `set -e`.
if grep -q 'href="\.\./\.\./' "$H/sub/page.html"; then
  note "sub/page.html has a ../../ href — one level deep should never need two"
fi
if grep -q 'href="\.\./\.\./\.\./' "$H/sub/deeper/page.html"; then
  note "sub/deeper/page.html has a ../../../ href — two levels deep should never need three"
fi

# 3. `idea-page-template` ran, and the minted page carries both footer sections.
#    The banner comes from `content/lib.typ`'s named `idea-page` function, so its
#    absence means the state channel from vertebra to bundle root is broken.
for slug in root-note sub-note; do
  grep -q 'demo-minted-banner' "$H/ideas/$slug.html" ||
    note "ideas/$slug.html is missing the idea-page-template banner"
  grep -q '>Context</h2>' "$H/ideas/$slug.html" ||
    note "ideas/$slug.html has no Context section"
done
grep -q '>Backlinks</h2>' "$H/ideas/root-note.html" ||
  note "ideas/root-note.html has no Backlinks section — sub-note windows it"

# A WINDOW EMITTED FROM INSIDE A `#context` BLOCK STILL PRODUCES A BACKLINK.
#
# `_page-links-beacon` walks the vertebra's content at `#show: rookery` time,
# and that walk cannot enter a context block — the body does not exist until
# layout. So the unlabelled `metadata((rookery-window: ..))` a `#window`
# announces itself with is invisible there, and every note such a window
# transcludes used to lose its backlink from the page transcluding it.
#
# NOT A HYPOTHETICAL: any package that computes its rows must emit its windows
# from inside a context block, because a registry read needs one.
# `@rookery/todos`'s `#todos-ready(windows: true)` is the real case, and
# MEASURED before the fix it produced no backlink at all while a hand-written
# window on the same page produced one.
#
# `content/sub/page.typ` holds the fixture: a `#context { window("plain-note") }`.
grep -q 'href="../sub/page.html"' "$H/ideas/plain-note.html" ||
  note "plain-note has no backlink from sub/page.html — a window inside #context announced to nobody"

# 4. No minted page appears in another note's PAGE backlinks. `_is-vertebra`
#    filters them out, and its own comment records six wrong backlinks from the
#    build where that filter was missing: a minted page links to the notes it
#    transcludes, so without the filter every note lists every other note's page
#    as a place it was "written".
python3 - "$H" <<'PY'
import re, sys, pathlib
root = pathlib.Path(sys.argv[1])
bad = 0
for page in sorted((root / "ideas").glob("*.html")):
    html = page.read_text()
    for block in re.findall(r'<div class="idea-context">.*?</div>', html, re.S):
        for href in re.findall(r'href="([^"]+)"', block):
            if "ideas/" in href:
                print(f"FAIL: {page.name}'s Context lists a minted page: {href}")
                bad += 1
sys.exit(1 if bad else 0)
PY

# 5. A citation written inside a `#footnote` belongs to the idea the footnote was
#    written in. `plain-note`'s ONLY citation sits in one, so the whole
#    references block on both its pages depends on the walk descending into the
#    footnote's metadata payload. MEASURED before that descent existed: the
#    author-date marker rendered, `.idea-references` was emitted nowhere, and an
#    empty `.idea-page-refs` appeared in its place — a reader saw a citation with
#    nothing on the site saying what it cited.
#
#    Counted, not merely found: the BIBLIOGRAPHY ENTRY must appear exactly once
#    per page. The footnote body is rendered as well as scanned, and a walk
#    claiming the citation from both places would list the work twice. The
#    author-date MARKER is a separate string ("Lamport 1994", inside the
#    footnote's own text) and is asserted separately, so neither check can pass
#    by finding the other.
for p in index.html ideas/plain-note.html; do
  grep -q 'idea-references' "$H/$p" ||
    note "$p has no references block for plain-note's footnote citation"
  grep -q 'doc-biblioref">Lamport 1994<' "$H/$p" ||
    note "$p is missing the footnote's own author-date citation marker"
  n=$(grep -o 'Lamport, Leslie' "$H/$p" | wc -l)
  [ "$n" -eq 1 ] ||
    note "$p lists the footnote's cited work $n times in its bibliography, expected exactly 1"
done


# 6. The `ideas/index.html` landing page, on by default (`content/lib.typ`
#    also sets `index-page: true` explicitly). `/ideas/` is the parent directory
#    of every permalink this demo mints and the URL a reader will guess;
#    without this page it is a 404.
#
#    Its rows must point AT the minted pages, which is what makes it an index of
#    them rather than a second table of contents: `#ideas-outline` links each row
#    to the note's anchor on the vertebra that authored it, and this page
#    deliberately does not use it.
#
#    AS A BARE BASENAME, and that is the assertion, not an incidental spelling.
#    This page IS `ideas/index.html`, so a minted note page is its SIBLING and
#    `<slug>.html` is the whole correct href. It used to be spelled
#    `ideas/<slug>.html` here, matching what rookery emitted — and what rookery
#    emitted was wrong, resolving to `ideas/ideas/<slug>.html`. Measured on an
#    82-note site: every row 404. So the old form must NOT be accepted again.
[ -f "$H/ideas/index.html" ] || note "no ideas/index.html was minted"
if [ -f "$H/ideas/index.html" ]; then
  idx="$H/ideas/index.html"
  # One row per minted note, each linking to that note's own page.
  for slug in root-note inner-note plain-note sub-note; do
    grep -q "idea-outline-row[^\"]*\"><a href=\"$slug.html\"" "$idx" ||
      note "ideas/index.html does not link $slug.html as a sibling basename"
    if grep -q "idea-outline-row[^\"]*\"><a href=\"[^\"]*ideas/$slug.html\"" "$idx"; then
      note "ideas/index.html links $slug through a directory prefix; from inside ideas/ that resolves to ideas/ideas/$slug.html"
    fi
  done
  # No row may link to an anchor on an authoring vertebra — that is the
  # `#ideas-outline` shape this page exists to avoid.
  if grep -q 'idea-outline-row"><a href="[^"]*#loc-' "$idx"; then
    note "ideas/index.html links a row at a vertebra anchor, not at a minted page"
  fi
  # Every registered note but the excluded one. `private-note` never registers,
  # which makes this count also the assertion that exclusion reaches the index
  # page — so it grows with the rookery's content rather than staying pinned.
  grep -q 'idea-index-count">30 ideas<' "$idx" ||
    note "ideas/index.html does not count its 30 ideas"
  # A dated note carries its date; sub-note is the demo's only dated one.
  grep -q 'idea-date">2026-03-14<' "$idx" ||
    note "ideas/index.html does not show the dated note's date"
  # Tag classes ride on the row, as they do in the outline, so a stylesheet can
  # reach them without this page inventing its own vocabulary.
  grep -q 'idea-outline-row idea-tag-note' "$idx" ||
    note "ideas/index.html does not carry a tagged note's idea-tag-note class"
  # The project's template wrapped it, exactly as it wraps a note page. `id` is
  # none here, and lib.typ's branch on that is what this proves runs.
  grep -q 'Minted page for the rookery' "$idx" ||
    note "ideas/index.html did not go through idea-page-template"
fi


# 7. The `<feeds:item>` syndication beacons, opt-in via `syndicate: true` in
#    `content/lib.typ`. `.marrow.typ` emits one inside each MINTED page for every
#    note that carries a date, and `content/index.typ` queries them back on a
#    vertebra and renders their payloads — `#metadata` produces no HTML, so
#    without that rendering there is nothing here to grep.
#
#    That query is itself half the assertion: the beacons live inside documents
#    this page is not, so a passing check proves rheo's introspection carries
#    them across the bundle, which is the whole premise of the protocol. The
#    OTHER half is the payload shape, which `@rheo/feeds`'s `items()` reads by
#    key: id, title, page, categories.
#
#    This demo imports no feeds and feeds imports no rookery — neither
#    package sees the other, by design. The consuming side is covered in
#    feeds's own demo, which needs rheo >= 0.6.0 and so cannot run here.
#
#    EXACTLY the dated notes, and only them: `.marrow.typ` skips a beacon for a
#    note with no `created` date, because Atom requires `<updated>` and an
#    undated entry is one `items()` would drop anyway. root-note, inner-note and
#    derived-note are undated on purpose — this demo sets no document date, so
#    they resolve to none — and a beacon for any of them means that gate stopped
#    working.
# `{ grep || true; }` INSIDE the braces, the same guard this file's own header
# comment records for the version in `check-versions`: with `set -o pipefail`,
# grep's exit 1 for NO MATCHES kills the script before `note` can say anything —
# and no match is exactly the failure this line exists to report. MEASURED while
# writing it: with `syndicate: false` the check exited 1 silently instead of
# naming the count.
# SEVEN dated notes: `plain-note`, `secret-note` and `sub-note`, each carrying
# an explicit `created:`; `w-inner`/`w-outer`/`w-early` (added for `sort:
# "date"`, which needs notes that differ in date to order); and `tag-hat`
# (added for `show-date: true` alongside tag pills in the same hat).
# `private-note` is excluded and so emits no beacon either — a second place
# the exclusion has to reach, since `.marrow.typ` writes one beacon per
# minted page.
beacons=$({ grep -o '<li>idea:[^<]*</li>' "$H/index.html" || true; } | wc -l)
[ "$beacons" -eq 7 ] ||
  note "index.html renders $beacons syndication beacons, expected exactly 7 (the dated notes)"
# The TITLE the note authored, not its slug, and the minted page's own path.
grep -q '<li>idea:plain-note | Plain note | ideas/plain-note.html | note</li>' "$H/index.html" ||
  note "plain-note's beacon payload is wrong (id, title, page or categories)"
grep -q '<li>idea:sub-note | Sub note | ideas/sub-note.html |' "$H/index.html" ||
  note "sub-note's beacon payload is wrong — note it is written on a NESTED vertebra"
if grep -q '<li>idea:root-note' "$H/index.html"; then
  note "an undated note emitted a beacon; the created gate is not holding"
fi


# 8. The per-tag theme reaches MINTED pages. `theme: (tags-color: ..)` is
#    delivered as generated `.idea-tag-<tag>` rules, and `rookery()` emits them
#    once per VERTEBRA — which cannot reach a page `.marrow.typ` mints, that
#    being a separate `#document` that never calls `rookery()` again. So
#    `.marrow.typ` carries the block itself, on every note page and on the index,
#    and this is the assertion that notices if it stops. `content/lib.typ` themes
#    the `note` tag for exactly this reason; the demo has no other use for it.
for page in ideas/index.html ideas/root-note.html; do
  grep -q '@layer rookery-tags' "$H/$page" ||
    note "$page carries no @layer rookery-tags block, so a minted page lost its tag theme"
done
#    Matched DECLARATION BY DECLARATION, not as one exact rule string: the
#    generator publishes as many properties as the entry warrants, and asserting
#    the whole rule made adding `--idea-tag-line` look like a broken minted page.
grep -q 'idea-tag-note { --idea-tag-bg: #3366ff[;}]' "$H/ideas/root-note.html" ||
  note "ideas/root-note.html's generated rule does not set --idea-tag-bg for the note tag"
grep -q 'idea-tag-line: #3366ff' "$H/ideas/root-note.html" ||
  note "ideas/root-note.html's generated rule does not set --idea-tag-line for the note tag"


# 9. EXCLUDED TAGS reaching everything downstream of the registry. `demo/pure`
#    proves an excluded note is absent from one page's HTML; only here can it be
#    shown to mint no page, take no index row, emit no beacon and appear nowhere
#    in the whole output tree. `content/lib.typ` binds
#    `exclude-tags: ("private",)` on both `idea` and `tagged-idea`.
[ -f "$H/ideas/private-note.html" ] &&
  note "ideas/private-note.html was minted for an EXCLUDED note"
#    The strongest form of the assertion, and the one worth keeping: the note's
#    id, its slug and its body appear NOWHERE in the built tree — not on the index,
#    not in a backlink list, not in a beacon, not in a Context footer.
if grep -rq -e 'private-note' -e PRIVATEBODY "$H"; then
  note "an excluded note leaked into the build: $(grep -rl -e 'private-note' -e PRIVATEBODY "$H" | tr '\n' ' ')"
fi
#    The control: the note added alongside it, which is NOT excluded, did mint.
[ -f "$H/ideas/secret-note.html" ] ||
  note "no minted page at ideas/secret-note.html — the non-excluded control is missing"

# 10. INVISIBLE TAGS on the surfaces only a rheo build has. A minted note page
#     renders its tags UNCONDITIONALLY (nothing writes a `show-tags:` argument for
#     a page `.marrow.typ` mints), and the index page puts `idea-tag-<tag>` on
#     every row — so these are the two places an invisible tag would most
#     obviously leak. `content/lib.typ` sets `invisible-tags: ("secret",)` AND
#     themes `secret`, so the generated `@layer rookery-tags` block is checked too.
#     TARGETED greps, not a flat `grep -r secret`, and the reason is structural
#     rather than fussy: the note's own SLUG is `secret-note`, which appears
#     legitimately in every link to its page, in its Context footer and in its
#     beacon. What must be absent is the CLASS, the PILL and the generated RULE.
if grep -rq 'idea-tag-secret' "$H"; then
  note "invisible tag leaked as a class: $(grep -rl 'idea-tag-secret' "$H" | tr '\n' ' ')"
fi
if grep -rq '>secret<' "$H"; then
  note "invisible tag leaked as a pill: $(grep -rl '>secret<' "$H" | tr '\n' ' ')"
fi
if grep -rq 'idea-tag-secret {' "$H"; then
  note "a tags-color rule was generated for an invisible tag"
fi
#     The control again, on the same note and the same pages: its VISIBLE `note`
#     tag keeps its class everywhere, so these checks are a difference between two
#     tags rather than the absence of all tag markup.
grep -q 'idea-tag-note' "$H/ideas/secret-note.html" ||
  note "ideas/secret-note.html lost the visible 'note' tag class"
grep -q 'SECRETBODY' "$H/ideas/secret-note.html" ||
  note "ideas/secret-note.html does not render its body"

# 11. NOT COVERED HERE, deliberately, and recorded so the gap is a decision
#     rather than an oversight: the `sys.inputs` half of the exclusion
#     (`--input rookery-exclude=..` / `rookery-include=..`). `rheo compile`
#     forwards no `--input` at all today — `build_inputs` in rheo core inserts
#     only `rheo-context` — so there is no way to vary it from here.
#     `demo/pure` covers that half (it compiles `excluded.typ` twice, one
#     `--input` apart), and rheo beads `rheo-cli-input-flag-q12` /
#     `rheo-toml-inputs-table-rih` are what will make it reachable from a rheo
#     build. Nothing in this package changes when they land.

# 12. A DERIVED TITLE ON A MINTED PAGE. `demo/pure` asserts the derivation on a
#     card; only here is there a minted page, whose `<title>` and `<h1>` used to
#     fall back to the note's SLUG — so an untitled note's own page was named `1`.
#     The note is called `derived-note`, so the slug and the derived title are
#     plainly different strings and the assertion cannot pass by accident.
dp="$H/ideas/derived-note.html"
[ -f "$dp" ] || note "no minted page at ideas/derived-note.html"
if [ -f "$dp" ]; then
  grep -q '<title>DERIVEDBODY' "$dp" ||
    note "ideas/derived-note.html <title> is not the derived title: $(grep -oE '<title>[^<]*' "$dp")"
  #   AND THE <h1> IS EMPTY, which is the other half of the split and the
  #   regression guard for the defect it fixed: a derived name is a LABEL for
  #   referring to the note, not a heading to print above the note's own body.
  #   MEASURED before the split — the minted page rendered `<h1>DERIVEDBODY..</h1>`
  #   and then `<p>DERIVEDBODY..</p>`, the same text twice.
  grep -q '<h1 id="idea:derived-note" class="idea"></h1>' "$dp" ||
    note "ideas/derived-note.html <h1> is not empty — a label is being printed as a heading"
  if grep -q '<span class="idea-title">DERIVEDBODY' "$dp"; then
    note "ideas/derived-note.html prints its derived label as a heading"
  fi
  #   Cut to sixty characters with an ellipsis, on the minted page as on a card.
  grep -qE '<title>DERIVEDBODY[^<]{40,50}\.\.\.</title>' "$dp" ||
    note "the minted page's derived title was not truncated with an ellipsis"
fi
#     And the index row uses it rather than the bare id.
grep -q 'derived-note.html">DERIVEDBODY' "$H/ideas/index.html" ||
  note "ideas/index.html row for derived-note does not use its derived title"

# 13. THE SWEEP BLOCK AND THE CARD UNDER IT, which are two halves of one piece of
#     layout: `#idea` emits a title-less `.idea-page-refs` immediately before its
#     card and outside it, and the card's id is lifted out of its own box by a
#     whole label. A sweep that CAUGHT a citation therefore sits directly under
#     that overhang with about 2px of `li` margin to give it, and the id lands on
#     the last reference line unless the stylesheet pays the difference.
#
#     Both halves are asserted, because either alone can rot: the markup, so the
#     adjacency the rule exists for stays exercised by this demo (root-note cites
#     from inside its body, and inner-note's card follows that block; the nested
#     page cites outside any note, and sub-note's card follows that one; refs.html
#     cites in prose before `cited-note`), and the RULE in the built stylesheet,
#     since no browser is available here and a dropped rule would compile clean
#     and look wrong.
python3 - "$H/index.html" "$H/sub/page.html" "$H/refs.html" <<'SWEEP' || fail=1
import re, sys
bad = 0
# Keyed on data-rookery, the STABLE role name, rather than on the `idea-page-refs`/
# `idea-box` classes: those are the configurable public hook a project may rename
# (see core.css's own theme header), so a structural adjacency check has to
# survive a class rename to still be checking the same thing.
for path in sys.argv[1:]:
    h = open(path).read()
    if not re.search(
        r'<div[^>]*data-rookery="page-refs"[^>]*>.{0,600}?<li[^>]*>.{0,600}?'
        r'</ul></section></div><div[^>]*data-rookery="box"[^>]*>',
        h, re.S,
    ):
        print(f"FAIL: {path} has no populated .idea-page-refs immediately before an .idea-box —"
              f" the adjacency the hat-clearance rule exists for is no longer exercised")
        bad = 1
if not bad:
    print("  sweep block: a populated .idea-page-refs sits directly above a card on all three pages")
sys.exit(bad)
SWEEP

grep -q '\[data-rookery="page-refs"\]:has(li) + \[data-rookery="box"\]' "$H/rookery/core/core.css" ||
  note "the built CSS has no [data-rookery=\"page-refs\"]:has(li) + [data-rookery=\"box\"] rule — a card's id will overlap the references above it"

# 14. WINDOW DEPTHS (`content/sub/deeper/page.typ`). `depth: 0` renders a bare
#     link row with no transcluded body at all; `depth: 2` unfurls the nested
#     `#window("w-inner")` as a real window INSIDE `#window("w-outer")`'s own,
#     rather than collapsing it to a permalink the way the document default
#     (depth 1) does.
python3 - "$H/sub/deeper/page.html" <<'DEPTHS' || fail=1
import re, sys
h = open(sys.argv[1]).read()
bad = 0
# `data-rookery="page-list"`/`"page-row"` are the stable roles for this shape;
# the `<figure>...</figure>` wrapper with nothing else inside it is what makes
# it a BARE row rather than an unfurled window with a body.
if not re.search(
    r'<figure><ul[^>]*data-rookery="page-list"[^>]*><li[^>]*data-rookery="page-row"[^>]*>'
    r'<a href="\.\./\.\./ideas/w-outer\.html">Outer</a></li></ul></figure>',
    h,
):
    print("FAIL: sub/deeper/page.html's depth: 0 window is not a bare link row with no body")
    bad = 1
# w-inner's own body renders once as its own card, plus once per place a
# window actually unfurls it rather than collapsing it to a bare permalink.
# MEASURED at 5 with the depth: 2 call in place — removing that one call
# alone drops it to 4, which is what makes the count a regression signal for
# it specifically, whatever else on the page also happens to unfurl w-inner.
n = h.count("The innermost note, unfurled only when a window’s depth budget reaches it.")
if n != 5:
    print(f"FAIL: sub/deeper/page.html renders w-inner's body {n} times, expected exactly 5 — "
          f"the depth: 2 window may no longer be unfurling the window nested inside it")
    bad = 1
if not bad:
    print("  window depths: depth 0 is a bare link row, depth 2 unfurls the window nested inside it")
sys.exit(bad)
DEPTHS

# 15. CYCLES TERMINATE (`content/sub/deeper/page.typ`). A self-window and an
#     A-windows-B/B-windows-A pair each render their OWN card exactly once —
#     the failure shape a runaway `_flatten` would show is a repeated card,
#     not a compile error, so this is a count rather than a presence check.
for id in self-loop cycle-a cycle-b; do
  n=$(grep -o "id=\"idea:$id\" class=\"idea\"" "$H/sub/deeper/page.html" | wc -l)
  [ "$n" -eq 1 ] ||
    note "sub/deeper/page.html renders idea:$id's card $n times, expected exactly 1 — a cycle must terminate, not re-expand"
done

# 16. THE TWO `#ideas-outline` FORMS DIFFER UNDER RHEO (`content/sub/deeper/page.typ`),
#     which no `demo/pure` root can show: the page form reads `state("rheo-handle")`
#     and lists only this vertebra's own notes, while `rookery-wide: true` lists
#     every note in the rookery, root-note included.
python3 - "$H/sub/deeper/page.html" <<'FORMS' || fail=1
import sys
h = open(sys.argv[1]).read()
bad = 0
page_start = h.index("This page’s ideas</h4>")
whole_start = h.index("Whole rookery</h4>")
depth_start = h.index("Depth-capped</h4>")
page_section = h[page_start:whole_start]
whole_section = h[whole_start:depth_start]
if "Root note" in page_section:
    print("FAIL: sub/deeper/page.html's page-form outline lists a note from another vertebra")
    bad = 1
if "Root note" not in whole_section:
    print("FAIL: sub/deeper/page.html's rookery-wide outline is missing a note from another vertebra")
    bad = 1
if not bad:
    print("  outline forms: the page form is local, the rookery-wide form is not")
sys.exit(bad)
FORMS

# 17. PRUNE AND PROMOTE (`content/relations.typ`). Filtered to `tags: "phd"`, the
#     untitled parent that does not itself carry `phd` is absent, and its tagged
#     child ("Pinned") is promoted to the TOP LEVEL of that outline rather than
#     left dangling at a depth with no parent above it.
python3 - "$H/relations.html" <<'PRUNE' || fail=1
import re, sys
h = open(sys.argv[1]).read()
bad = 0
tail = h[h.index("Tagged phd</h4>"):]
if "Auto note" in tail:
    print("FAIL: relations.html's Tagged phd outline still lists the untagged parent — it should be pruned")
    bad = 1
# `data-rookery="outline"`/`"outline-row"` are the stable roles for the list and
# its row; `data-rookery-tags="phd draft"` is the stable tag-membership attribute
# (see core.css's own header) — checked instead of the `idea-tag-*` classes,
# which are a configurable public hook and whose ORDER is not part of the
# contract this check is defending.
if not re.search(
    r'<ul[^>]*data-rookery="outline"[^>]*><li[^>]*data-rookery="outline-row"[^>]*'
    r'data-rookery-tags="phd draft"[^>]*><a href="#loc-3">Pinned</a></li>',
    tail,
):
    print("FAIL: relations.html's Tagged phd outline does not promote Pinned to the top level")
    bad = 1
if not bad:
    print("  prune and promote: the untagged parent is pruned, its tagged child promoted")
sys.exit(bad)
PRUNE

# 18. THE OTHER TWO CITATION POSITIONS (`content/refs.typ`; the sweep position is
#     check 13 above). The in-body citation reaches the note's OWN References
#     block, on the page and again on its minted page. A `#footnote` written
#     outside any note falls to Typst's page-endnote mechanism rather than to
#     `.idea-footnotes` (which is a per-note block — check `content/index.typ`'s
#     `plain-note` for that half). And a citation with nothing following it on
#     the page is claimed by the document-wide TRAILING block, which — unlike a
#     sweep block — carries its own `<h2>References</h2>` heading because
#     nothing else on the page will.
grep -q 'idea-references' "$H/ideas/cited-note.html" ||
  note "ideas/cited-note.html has no References block for its own in-body citation"
grep -q 'role="doc-endnotes"' "$H/refs.html" ||
  note "refs.html has no page endnote section for the footnote written outside any note"
if grep -q 'idea-footnotes' "$H/refs.html"; then
  note "refs.html wraps its outside-any-note footnote in .idea-footnotes — that class is for a footnote INSIDE a note"
fi
n=$(grep -o 'idea-page-refs"><section role="doc-bibliography" class="hanging-indent"><h2>References</h2>' "$H/refs.html" | wc -l)
[ "$n" -eq 1 ] ||
  note "refs.html has $n trailing reference blocks (with their own heading), expected exactly 1"

# 19. THE EMPTY-BODIED NOTE (`content/refs.typ`'s `dt-empty`) — nothing to derive
#     a label from at all. It still mints a page, and that page's `<h1>` stays
#     EMPTY rather than gaining a derived title span it has no text to fill —
#     the same no-duplication guard check 12 pins for `derived-note`.
dp="$H/ideas/dt-empty.html"
[ -f "$dp" ] || note "no minted page at ideas/dt-empty.html"
if [ -f "$dp" ]; then
  grep -q '<h1 id="idea:dt-empty" class="idea"></h1>' "$dp" ||
    note "ideas/dt-empty.html's <h1> is not empty — an empty body must not gain a heading"
  if grep -q 'idea-title' "$dp"; then
    note "ideas/dt-empty.html prints a derived title span despite having no body to derive one from"
  fi
fi

if [ "$fail" -ne 0 ]; then
  echo "demo/rheo: FAILED"
  exit 1
fi
echo "demo/rheo OK"
