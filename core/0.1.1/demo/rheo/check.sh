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
# announces itself with is invisible there, and this assertion is what
# confirms every note such a window transcludes still gains its backlink
# from the page transcluding it.
#
# NOT A HYPOTHETICAL: any package that computes its rows must emit its windows
# from inside a context block, because a registry read needs one.
# `@rookery/todos`'s `#todos-ready(windows: true)` is the real case, where a
# window emitted this way gains the same backlink a hand-written window on
# the same page does.
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
#    references block on both its pages depends on the walk descending into
#    the footnote's metadata payload: the author-date marker renders and
#    `.idea-references` carries the citation, rather than an empty
#    `.idea-page-refs` leaving a reader with a citation and nothing on the
#    site saying what it cited.
#
#    Counted, not merely found, and scoped to the `.idea-references` BLOCK
#    ITSELF rather than the whole page: Typst emits an html body identically
#    in every mode now (bib.typ/state.typ) — a margin note beside the
#    footnote marker AND its bottom Footnotes-list copy, whatever this
#    project's own `footnotes:` setting is, core.css deciding which a reader
#    sees — and both copies of the footnote's body carry their own full-form
#    citation of the same work. Counting the whole page would see three
#    (references block, sidenote, Footnotes-list item) even though the
#    reference itself is entered ONCE; scoping to the references block keeps
#    this assertion about the WALK (`_own-cited-keys`) it exists for, not
#    about how many margin notes a citation happens to mint. The author-date
#    MARKER is a separate string ("Lamport 1994", inside the footnote's own
#    text) and is asserted separately, so neither check can pass by finding
#    the other.
for p in index.html ideas/plain-note.html; do
  grep -q 'idea-references' "$H/$p" ||
    note "$p has no references block for plain-note's footnote citation"
  grep -q 'doc-biblioref">Lamport 1994<' "$H/$p" ||
    note "$p is missing the footnote's own author-date citation marker"
  # Bounded to the bibliography's own `<section>...</section>` (Typst's own
  # element, closed well before the block's `</div>`), not the whole page —
  # see the comment above for why a page-wide count would not be 1.
  n=$(python3 -c "
import re, sys
h = open(sys.argv[1]).read()
m = re.search(r'data-rookery=\"references\"[^>]*>.*?</section>', h, re.S)
print(len(re.findall('Lamport, Leslie', m.group(0))) if m else -1)
" "$H/$p")
  [ "$n" -eq 1 ] ||
    note "$p's references block lists the footnote's cited work $n times, expected exactly 1"
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
#    `<slug>.html` is the whole correct href: a `ideas/<slug>.html` prefix
#    would resolve to `ideas/ideas/<slug>.html` from inside this page and
#    404 every row, so that prefixed form must NOT be accepted.
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
  grep -q 'idea-index-count">53 ideas<' "$idx" ||
    note "ideas/index.html does not count its 53 ideas"
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
# (added for `display-date: true` alongside tag pills in the same hat).
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
#    `exclude-tags: ("private",)` on `idea`, and every constructor built off
#    it with `.with()` inherits that binding.
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
#     renders its tags UNCONDITIONALLY (nothing writes a `display-tags:` argument for
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
#     `--input` apart). It becomes reachable from a rheo build once `rheo
#     compile` forwards `--input` to the compile it runs; nothing in this
#     package changes when that happens.

# 12. A DERIVED TITLE ON A MINTED PAGE. `demo/pure` asserts the derivation on a
#     card; only here is there a minted page, whose `<title>` and `<h1>` come
#     from the note's derived title rather than falling back to its SLUG.
#     The note is called `derived-note`, so the slug and the derived title are
#     plainly different strings and the assertion cannot pass by accident.
dp="$H/ideas/derived-note.html"
[ -f "$dp" ] || note "no minted page at ideas/derived-note.html"
if [ -f "$dp" ]; then
  grep -q '<title>DERIVEDBODY' "$dp" ||
    note "ideas/derived-note.html <title> is not the derived title: $(grep -oE '<title>[^<]*' "$dp")"
  #   AND THE <h1> IS EMPTY, which is the other half of the split: a derived
  #   name is a LABEL for referring to the note, not a heading to print above
  #   the note's own body, so the minted page's <h1> must stay empty rather
  #   than repeating `DERIVEDBODY..` as both the heading and the body's own
  #   paragraph.
  #   Keyed on `data-rookery="idea"` with `-P` lookaheads rather than one literal
  #   string, so the three attributes may appear in any order — `[^>]*></h1>`
  #   right after them is what still proves the heading holds no text node.
  grep -Pq '<h1(?=[^>]*\bid="idea:derived-note")(?=[^>]*\bclass="idea")(?=[^>]*\bdata-rookery="idea")[^>]*></h1>' "$dp" ||
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

# 14. WINDOW UNFURL (`content/sub/deeper/page.typ`). `unfurl: 0` renders a bare
#     link row with no transcluded body at all; `unfurl: 2` unfurls the nested
#     `#window("w-inner")` as a real window INSIDE `#window("w-outer")`'s own,
#     rather than collapsing it to a permalink the way the document default
#     (unfurl 1) does.
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
    print("FAIL: sub/deeper/page.html's unfurl: 0 window is not a bare link row with no body")
    bad = 1
# w-inner's own body renders once as its own card, plus once per place a
# window actually unfurls it rather than collapsing it to a bare permalink.
# MEASURED at 6 with the unfurl: 2 call in place — removing that one call
# alone drops it to 5, which is what makes the count a regression signal for
# it specifically, whatever else on the page also happens to unfurl w-inner.
# The sixth is `#window("w-outer", limit: 2)`'s own nested window: its tail is
# no longer thrown away behind an ellipsis but sits, collapsed, behind the
# window-more disclosure, and that tail still contains the second block's
# `#window("w-inner")`.
#
# RAISED FROM 6 TO 8, and the two that appeared were always being rendered —
# they were being rendered WRONG, so this string did not match them. w-inner's
# body contains an apostrophe, `smartquote` was missing from `_INLINE-FUNCS`
# (src/pure.typ), and unknown element names default to BLOCK, so every path
# through `_blocks` cut that one sentence into three paragraphs and flipped the
# apostrophe to an opening `‘`. The two renderings that go through `_blocks` —
# the truncating ones — therefore spelled the sentence differently from the six
# that do not. Whole again, all eight match. `<p>‘</p>` appears nowhere in this
# demo's output now, which is the other half of the same assertion.
n = h.count("The innermost note, unfurled only when a window’s depth budget reaches it.")
if n != 8:
    print(f"FAIL: sub/deeper/page.html renders w-inner's body {n} times, expected exactly 8 — "
          f"the unfurl: 2 window, or the limit: 2 window's expandable tail, may no longer be "
          f"unfurling the window nested inside it")
    bad = 1
# The same defect, stated as the symptom a reader sees rather than as a count:
# a `smartquote` treated as a block ends up alone in a paragraph of its own.
# Cheap, and it fails on any body with an apostrophe rather than only on this
# one sentence.
if re.search(r'<p>[‘’]</p>', h):
    print("FAIL: sub/deeper/page.html has a paragraph that is nothing but a quote mark — "
          "_blocks is treating a smartquote as a block and cutting a sentence around it")
    bad = 1
if not bad:
    print("  window unfurl: unfurl 0 is a bare link row, unfurl 2 unfurls the window nested inside it")
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
#     which no `demo/pure` root can show: `scope: "page"` reads `state("rheo-handle")`
#     and lists only this vertebra's own notes, while the default `scope: "rookery"`
#     lists every note in the rookery, root-note included.
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
    print("FAIL: sub/deeper/page.html's whole-rookery outline is missing a note from another vertebra")
    bad = 1
if not bad:
    print("  outline forms: the page form is local, the whole-rookery form is not")
sys.exit(bad)
FORMS

# 17. PRUNE AND PROMOTE (`content/relations.typ`). Filtered to `tagged: "phd"`, the
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
# contract this check is defending. `#loc-\d+`, not a literal `#loc-3`: that
# anchor number is Typst's own internal, document-wide location counter, and
# any change to how many native cross-#document label lookups exist anywhere
# earlier in the spine (titleless-pair.typ's own fixture among them) shifts
# it — a fact about Typst's numbering, not about whether promotion happened.
if not re.search(
    r'<ul[^>]*data-rookery="outline"[^>]*><li[^>]*data-rookery="outline-row"[^>]*'
    r'data-rookery-tags="phd draft"[^>]*><a href="#loc-\d+">Pinned</a></li>',
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
  # Order-tolerant on the same three attributes as check 12's derived-note
  # assertion, for the same reason — see the comment there.
  grep -Pq '<h1(?=[^>]*\bid="idea:dt-empty")(?=[^>]*\bclass="idea")(?=[^>]*\bdata-rookery="idea")[^>]*></h1>' "$dp" ||
    note "ideas/dt-empty.html's <h1> is not empty — an empty body must not gain a heading"
  if grep -q 'idea-title' "$dp"; then
    note "ideas/dt-empty.html prints a derived title span despite having no body to derive one from"
  fi
fi

# 20. A WINDOW WEARS ITS NOTE'S OWN VISIBLE TAGS, not only its card does.
#     `content/sub/page.typ`'s `#window("plain-note", ...)` (the fixture check 3
#     above already reads) transcludes a `#note`, which carries the sugar's
#     prepended `note` tag — so the window wrapper on `sub/page.html`, not just
#     `plain-note`'s own card, must carry that tag now.
#
#     Keyed on `data-rookery-tags`, not on the `idea-tag-note` class: the class
#     STEM is a project's configurable prefix (see core.css's own theme
#     header), the attribute name is not, so this is the assertion that
#     survives a project renaming its stem.
grep -q 'data-rookery="window" data-rookery-tags="note"' "$H/sub/page.html" ||
  note "sub/page.html's window of plain-note carries no data-rookery-tags — a window should wear its note's visible tags"

# 21. A CONSTRUCTOR NAMING SEVERAL TAGS in `base-tags:` prepends all of them,
#     so a family that narrows another belongs to the wider one.
#     `content/tags.typ` builds
#     `#participant = idea.with(base-tags: ("person", "participant"))`; the
#     narrower family's note must carry BOTH, and the caller's own tags must
#     survive alongside them.
#
#     Keyed on `data-rookery-tags` rather than the `idea-tag-*` classes, for
#     the reason check 20 gives: the class stem is a project's to rename, the
#     attribute is not. The attribute holds a space-separated list whose order
#     follows the factory, so each tag is matched on its own.
for slug in tag-p-person tag-p-participant tag-p-both; do
  [ -f "$H/ideas/$slug.html" ] || note "no minted page at ideas/$slug.html"
done
pp="$H/ideas/tag-p-participant.html"
if [ -f "$pp" ]; then
  grep -q 'data-rookery-tags="[^"]*\bperson\b' "$pp" ||
    note "ideas/tag-p-participant.html carries no person tag — a multi-tag factory must prepend every tag it names"
  grep -q 'data-rookery-tags="[^"]*\bparticipant\b' "$pp" ||
    note "ideas/tag-p-participant.html carries no participant tag"
fi
bp="$H/ideas/tag-p-both.html"
if [ -f "$bp" ]; then
  for t in person participant phd; do
    grep -q "data-rookery-tags=\"[^\"]*\\b$t\\b" "$bp" ||
      note "ideas/tag-p-both.html is missing the $t tag — a caller's tags must survive a multi-tag factory"
  done
fi
# `.with(tags: ..)` over a factory composes too: both the factory's tag and the
# bound one reach the note. The call-site-override caveat is not asserted — it is
# the documented behaviour of a default, named in the fixture's own comment.
wp="$H/ideas/tag-p-with.html"
if [ -f "$wp" ]; then
  for t in person recommender; do
    grep -q "data-rookery-tags=\"[^\"]*\\b$t\\b" "$wp" ||
      note "ideas/tag-p-with.html is missing the $t tag — .with over a factory must keep both"
  done
fi
# The wider tag selects the narrower family: the window on `tags.html` asks for
# `person` alone and must transclude the participants too.
grep -q 'tag-p-participant' "$H/tags.html" ||
  note "tags.html's #window(tagged: \"person\") does not reach tag-p-participant — the narrowing did not take"

# 22. A TITLE HOLDING A REFERENCE, on the minted page that renders it. A minted
# page never calls `rookery()`, so the `show ref:` rule has to be installed
# where the title span is built — without it the reference renders as its
# anchor figure's counter, a bare number, and the page's <title> loses the
# name altogether.
R="$H/ideas/ref-titled.html"
grep -q 'class="idea-title"[^>]*>About <span class="idea-ref"' "$R" ||
  note "ref-titled.html's <h1> does not render its title's reference through the ref rule"
grep -q '>Cited note<' "$R" ||
  note "ref-titled.html's <h1> does not name the note its title references"
grep -q '<title>About Cited note</title>' "$R" ||
  note "ref-titled.html's <title> does not resolve its title's reference"


# 23. `#ideate`'s FUNCTION-FORM TITLE AND NAME (`content/ideated.typ`). Every `==`
#     section there mints its own note, titled and named after its own
#     heading via function forms `(content, labels) => ...` rather than sharing
#     one fixed title and the package's auto-incrementing counter — so the pages
#     below are named by SLUG, never by a sequence number.
declare -A IDEATED_TITLES=(
  [literate-programming]="Literate programming"
  [fuzzy-search-ranking]="Fuzzy search ranking"
  [testing-edge-cases]="Testing edge cases"
  [rookery]="Rookery"
  #   A section with NOTHING under it mints too. `== An empty section` in that
  #   file has no body at all, and a stub heading is still a note an author
  #   wrote and reaches the registry just as a section with a sentence in it
  #   does, so a chapter of stubs is pinned in full, not only the sections
  #   that happen to carry prose. The page existing, titled by its own
  #   heading, is the assertion — and the twice-only count below holds for it
  #   unchanged.
  [an-empty-section]="An empty section"
)
for slug in "${!IDEATED_TITLES[@]}"; do
  p="$H/ideas/$slug.html"
  [ -f "$p" ] || { note "no minted page at ideas/$slug.html — #ideate's name function did not slug this section"; continue; }
  t="${IDEATED_TITLES[$slug]}"
  grep -q "<title>$t</title>" "$p" ||
    note "ideas/$slug.html's <title> is not its own heading's text ($t)"
  #   Exactly TWICE: the <title> above and the note's own <h1>/<h2> heading.
  #   A third occurrence would mean the source heading survived into the
  #   note's body as well as becoming its title — the same double-print guard
  #   check 12 pins for a DERIVED title, run here for an AUTHORED one instead.
  n=$(grep -o "$t" "$p" | wc -l)
  [ "$n" -eq 2 ] ||
    note "ideas/$slug.html contains \"$t\" $n time(s), expected exactly 2 (the <title> and the note's own heading) — the source heading may have been left in the note's body too"
done

# 24. `#ideate`'s TAG FROM `#ideate-tag` BEACON (`content/ideated.typ`). Its
#     fourth section, `== Rookery`, mints with the tag its body's `#ideate-tag("rookery")`
#     beacon names, on top of whatever `tags:` the call already applies
#     (nothing, here).
grep -q 'idea-tag-rookery' "$H/ideas/rookery.html" ||
  note "ideas/rookery.html does not carry the idea-tag-rookery class from its #ideate-tag beacon"
# Its sibling with no beacon and no `tags:` from the call either, wears
# no tag PILL at all — the control this feature must not touch. A bare
# `idea-tag-` substring is NOT the right test here: every page in this build
# carries the project-wide `.idea-tag-note { .. }` rule generated for the
# THEMED `note` tag used elsewhere in the demo, regardless of this note's own
# tags — `class="idea-tag` (the pill's own class, present only when a note
# has at least one visible tag) is what actually distinguishes them.
if grep -q 'class="idea-tag' "$H/ideas/literate-programming.html"; then
  note "ideas/literate-programming.html wears a tag pill despite no tags: and no beacon"
fi
# `== Testing edge cases <sec:one>` carries a label `<sec:one>` — this is
# unrelated to tagging (tags use `#ideate-tag`, not labels), so this label
# is left alone: no extra tag, no panic.
if grep -q 'idea-tag-sec"' "$H/ideas/testing-edge-cases.html"; then
  note "ideas/testing-edge-cases.html's unrelated label <sec:one> was misread as a tag"
fi

# 25. `#ideate`'s FUNCTION FORM FOR `name:` (`content/ideated-named.typ`). A
#     lambda receives each section's heading and labels, returns a custom id.
#     The lambda encodes `labels.len()` in the id, making the array argument
#     observable from a PATH. Sections with and without labels mint with
#     different counts, proving both branches of the lambda call work.
p="$H/ideas/wk-1-waterline.html"
[ -f "$p" ] || note "no minted page at ideas/wk-1-waterline.html — `name:` function did not build this id"
grep -q '<title>Waterline</title>' "$p" ||
  note "ideas/wk-1-waterline.html's <title> is not 'Waterline' — the function names the note without changing its title"

p="$H/ideas/wk-0-rheo.html"
[ -f "$p" ] || note "no minted page at ideas/wk-0-rheo.html — `name:` function did not build this id"
grep -q '<title>Rheo</title>' "$p" ||
  note "ideas/wk-0-rheo.html's <title> is not 'Rheo'"

# 26. `display-tags: true` SURVIVES A REPLAY. `tag-nest-inner` is hatched with a
#     pill on its own card in tags.html; the outer note's minted page rebuilds
#     that card from its beacon, and the pill has to come back with it.
grep -q 'class="idea-tag' "$H/tags.html" ||
  note "tags.html does not show the nested card's pill where it is hatched in place"
grep -q 'class="idea-tag' "$H/ideas/tag-nest-outer.html" ||
  note "ideas/tag-nest-outer.html replays the nested card without its tag pill"

# 27. `#ideate-name` NAMES A NOTE EXPLICITLY UNDER ANY SEPARATOR
#     (`content/ideated-id.typ`). `separator: none` has no heading to feed a
#     `name:` function at all — a single beacon anywhere in that one-note body
#     still mints it under a fixed id rather than the package counter.
p="$H/ideas/fixed-id-note.html"
[ -f "$p" ] || note "no minted page at ideas/fixed-id-note.html — #ideate-name did not name the separator: none note"
if [ -f "$p" ]; then
  grep -q 'FIXEDIDBODY' "$p" || note "ideas/fixed-id-note.html does not render its own body"
fi
#     `separator: par` splits two paragraphs into two notes; only the second
#     carries a beacon, so it alone mints under a fixed id while its sibling
#     keeps the counter — proving the beacon is per-section, not document-wide.
p="$H/ideas/second-para-note.html"
[ -f "$p" ] || note "no minted page at ideas/second-para-note.html — #ideate-name did not name the beaconed paragraph"
if [ -f "$p" ]; then
  grep -q 'SECONDPARABODY' "$p" || note "ideas/second-para-note.html does not render its own body"
  if grep -q 'AUTOCOUNTBODY' "$p"; then
    note "ideas/second-para-note.html also renders the OTHER paragraph's body — the split did not separate the two notes"
  fi
fi
#     The unbeaconed sibling paragraph still mints somewhere, under whatever
#     counter value the whole bundle assigns it — not asserted by number, only
#     that it exists and is not the named page above.
if ! grep -rq 'AUTOCOUNTBODY' "$H"; then
  note "AUTOCOUNTBODY never appears in the build — the unbeaconed paragraph did not mint at all"
fi
#     Two `#ideate-name` beacons in one section is a build error (panic naming
#     both ids), which a passing HTML build cannot exercise — verified
#     manually instead, the same way `#idea`'s own third-positional-argument
#     rejection is (see `core/0.1.1/test/units.typ`).

# 28. `separator: none` TITLES AND IDS ITS ONE NOTE FROM `document.title`
#     (`content/ideated-doctitle.typ`). No lead heading exists to take either
#     from, so the page's own `#set document(title: [Doc Title Note])` supplies
#     both: the title, and `slug(..)` of it as the id.
p="$H/ideas/doc-title-note.html"
[ -f "$p" ] || note "no minted page at ideas/doc-title-note.html — separator: none did not title/id its note from document.title"
if [ -f "$p" ]; then
  grep -q 'DOCTITLEBODY' "$p" || note "ideas/doc-title-note.html does not render its own body"
fi


# 29. A TRUNCATED WINDOW EXPANDS IN PLACE (`content/sub/deeper/page.typ`'s
#     `#window("w-outer", limit: 2)`). No JavaScript renders it: a second
#     `<details>` nested inside the window's own body is what makes the shown
#     blocks, not only the ellipsis, a click target for the hidden tail.
grep -q 'data-rookery="window-more"' "$H/sub/deeper/page.html" ||
  note "sub/deeper/page.html's truncated window has no nested window-more disclosure"
grep -q 'data-rookery="window-ellipsis"' "$H/sub/deeper/page.html" ||
  note "sub/deeper/page.html's truncated window has no window-ellipsis span"

# 30. A DUPLICATE TITLE-DERIVED ID NUMBERS INSTEAD OF PANICKING
#     (`content/same-title-pair.typ`). Two notes titled "Same Title" both
#     slug to `same-title`; the first keeps the bare slug and the second
#     gets a `-2` suffix, counted in document order, rather than the build
#     failing on the duplicate-note-id panic.
p1="$H/ideas/same-title.html"
p2="$H/ideas/same-title-2.html"
p3="$H/ideas/same-title-3.html"
[ -f "$p1" ] || note "no minted page at ideas/same-title.html — the first same-titled note did not keep the bare slug"
[ -f "$p2" ] || note "no minted page at ideas/same-title-2.html — the second same-titled note did not get the -2 suffix"
if [ -f "$p1" ] && [ -f "$p2" ]; then
  grep -q 'SAMETITLEONEBODY' "$p1" || note "ideas/same-title.html does not render the first note's own body"
  grep -q 'SAMETITLETWOBODY' "$p2" || note "ideas/same-title-2.html does not render the second note's own body"
fi
# `sub/page.typ` also transcludes the first same-titled note into a `#window`
# — a replay of its mint block from a different vertebra. A -2 suffix taken
# by REPLAY rather than by a genuine second note would mint a THIRD page here;
# its absence is the regression test for the slug-occupant fix.
[ -f "$p3" ] && note "ideas/same-title-3.html exists — transcluding the first same-titled note minted it a second, unearned occupant"
grep -q 'SAMETITLEONEBODY' "$H/sub/page.html" ||
  note "sub/page.html does not render the transcluded same-title note's body"

# 31. FOOTNOTE NUMBERS SURVIVE TRANSCLUSION (`content/index.typ`'s `plain-note`,
#     windowed by `content/sub/page.typ`). `plain-note` carries three
#     footnotes; the last two share IDENTICAL bodies ("Repeated note."),
#     which is the case a by-content match (`notes.position(n => n == it)`)
#     gets wrong — it always returns the FIRST index, so both would read the
#     same number. Numbering has to come from POSITION instead.
#
#     Checked on BOTH renderings: `plain-note`'s own minted page, and
#     `sub/page.html`, where the note is replayed a second time as a
#     `#window`. Before the fix, the shared counter behind these numbers was
#     read through `context` and did not converge across the two renderings
#     at all — this demo is too small to reproduce that non-convergence
#     directly, but a stable, WRONG pair (e.g. both footnotes reading "2")
#     would still fail the distinctness check below, and a passing run here
#     is the regression guard for the fix regardless of which failure mode
#     numbering-by-content reintroduces.
python3 - "$H/ideas/plain-note.html" "$H/sub/page.html" <<'FOOTNOTES' || fail=1
import re, sys
bad = 0
for path in sys.argv[1:]:
    h = open(path).read()
    items = re.findall(
        r'<li class="idea-footnote" id="fn-(\d+)-(\d+)"[^>]*><a class="idea-fn-backlink"[^>]*>\^</a> (.*?)</li>',
        h, re.S,
    )
    if len(items) != 3:
        print(f"FAIL: {path} has {len(items)} plain-note footnote list items, expected exactly 3")
        bad = 1
        continue
    block = items[0][0]
    numbers = [int(n) for (_, n, _) in items]
    texts = [t for (_, _, t) in items]
    if numbers != [1, 2, 3]:
        print(f"FAIL: {path}'s footnote list is numbered {numbers}, expected [1, 2, 3] in document order")
        bad = 1
    if "Repeated note." not in texts[1] or "Repeated note." not in texts[2]:
        print(f"FAIL: {path}'s second and third footnotes are not the identical-text fixture: {texts[1:]}")
        bad = 1
    # THE regression this fixture is for: two IDENTICAL footnote bodies must
    # not collapse to the same number.
    if numbers[1] == numbers[2]:
        print(f"FAIL: {path}'s two identical 'Repeated note.' footnotes both number {numbers[1]} — "
              f"numbering is matching by content, not by position")
        bad = 1
    refs = re.findall(rf'<sup class="idea-fn-ref" id="fnref-{block}-(\d+)"', h)
    if [int(n) for n in refs[:3]] != [1, 2, 3]:
        print(f"FAIL: {path}'s inline footnote references for block {block} read {refs[:3]}, "
              f"expected ['1', '2', '3'] in document order")
        bad = 1
if not bad:
    print("  footnote numbering: two identical footnotes number 1, 2, 3 in order on both plain-note's own page and its #window")
sys.exit(bad)
FOOTNOTES

# 32. A TITLELESS, UNNAMED NOTE'S MINTED PAGE (`content/index.typ`'s
#     content-derived note). Its filename is its body slug plus a content
#     digest, not a counter, and the id printed on the authoring vertebra —
#     the note's OWN rendering — has to be the exact same string as the
#     minted page's own basename, which is a SECOND rendering of that same
#     body. `demo/pure` cannot show this half at all: it never mints a page.
p=$(ls "$H"/ideas/contentidbody-*.html 2>/dev/null | head -1)
[ -n "$p" ] ||
  note "no minted page at ideas/contentidbody-<digest>.html — a titleless, unnamed note's id is not its body slug plus a content digest"
if [ -n "$p" ]; then
  id=$(basename "$p" .html)
  grep -q 'CONTENTIDBODY' "$p" ||
    note "ideas/$id.html does not render its own body"
  grep -q "id=\"idea:$id\"" "$H/index.html" ||
    note "index.html's authoring vertebra does not carry idea:$id, though its minted page is ideas/$id.html"
fi


# 33. A TAG-SELECTED WINDOW BACKLINKS THE PAGE THAT SHOWS IT
#     (`content/index.typ`'s `#window(tagged: "phd")`, on the root vertebra,
#     picks up `tag-t-both` from the DIFFERENT `tags` vertebra where it is
#     defined). `tag-t-both` is never named by that window, only tag-matched,
#     so its Backlinks section is empty unless the page-level link map
#     resolves the marker's tag selector against the final registry. A
#     same-page tag window, such as either on `content/tags.typ` itself,
#     cannot exercise this: Context already names a note's own origin page,
#     so Backlinks excludes it there on purpose.
grep -qi 'backlinks' "$H/ideas/tag-t-both.html" ||
  note "ideas/tag-t-both.html has no Backlinks section — a tag-selected window stopped registering a page backlink"

# 34. A TAG-SELECTED WINDOW INSIDE ANOTHER NOTE'S BODY BACKLINKS THAT NOTE
#     (`content/tags.typ`'s `tag-windower` note, whose body carries
#     `#window(tagged: ("todo", "phd"), match: "all")`). This is the
#     note-level counterpart to assertion 33: `tag-t-both` is only
#     tag-matched, never named, so its Backlinks section names
#     `tag-windower` only if the note-level link map also resolves a tag
#     selector, not just the page-level one.
grep -q 'tag-windower' "$H/ideas/tag-t-both.html" ||
  note "ideas/tag-t-both.html does not mention tag-windower — a tag window inside a note's body stopped registering a note backlink"

# 35. THIS PROJECT'S PAGE-TOP MODE MARKER names "vertical" for BOTH
#     attributes — this project sets no `footnotes:`/`citations:` of its
#     own, so it is checking the DEFAULT (`citations: auto` follows
#     `footnotes:`, unset here). `template.typ` emits it on an ordinary
#     vertebra (`index.html`), `.marrow.typ` on a minted note page
#     (`ideas/plain-note.html`) — the one remaining read of
#     `_footnote-mode`/`_citation-mode` in either file, kept out of
#     everything else that renders a note's body (bib.typ/state.typ) so an
#     html rendering never varies with either mode.
for p in index.html ideas/plain-note.html; do
  grep -q 'data-rookery="mode" data-rookery-footnotes="vertical" data-rookery-citations="vertical" hidden="hidden"' "$H/$p" ||
    note "$p has no vertical data-rookery=\"mode\" marker"
done

# 17. GROUP `display-bibliography` ON `#window` (`content/index.typ`'s
#     `#window((<knuth-note>, <plain-note>), display-bibliography: true)`).
#     `knuth-note` cites @knuth1984 with no nested note or window of its own
#     to claim the citation first; `plain-note`'s only citation
#     (@lamport1994) sits inside a footnote. Neither transcluded window
#     carries a references block of its own — the group's one combined block,
#     after the second window, lists both works instead, de-duplicated and
#     marked `data-rookery-bibliography="on"`.
python3 - "$H/index.html" <<'GROUPBIB' || fail=1
import re, sys
h = open(sys.argv[1]).read()
bad = 0

start = h.find('id="idea:knuth-note"')
combined = h.find('data-rookery="references" data-rookery-bibliography="on"', start)
if start == -1 or combined == -1:
    print("FAIL: index.html has no knuth-note heading or no combined references block after it")
    sys.exit(1)

# knuth-note's OWN card carries its own reference block (unaffected by the
# group below it), so bound the "no per-window block" check to AFTER that —
# from the first window figure of the group onward.
group_start = h.find('data-rookery="window"', start)
group = h[group_start:combined]
if group.count('data-rookery="window"') != 2:
    print(f"FAIL: index.html's group has {group.count('data-rookery=\"window\"')} windows before "
          f"its combined references block, expected 2")
    bad = 1
if 'data-rookery="references"' in group:
    print("FAIL: index.html's group has a references block inside one of its windows — "
          "display-bibliography: true should suppress every per-window block")
    bad = 1

section_end = h.index("</section>", combined)
section = h[combined:section_end]
if section.count("Knuth, Donald E. 1984") != 1:
    print("FAIL: index.html's group combined references block does not list Knuth exactly once")
    bad = 1
if section.count("Lamport, Leslie") != 1:
    print("FAIL: index.html's group combined references block does not list Lamport exactly once")
    bad = 1

if not bad:
    print("  group display-bibliography: knuth-note and plain-note's #window carries one combined "
          "references block, not two, listing both cited works")
sys.exit(bad)
GROUPBIB

if [ "$fail" -ne 0 ]; then
  echo "demo/rheo: FAILED"
  exit 1
fi
echo "demo/rheo OK"
