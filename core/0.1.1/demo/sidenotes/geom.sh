#!/usr/bin/env bash
# Asserts the RIGHT GUTTER SPLIT's geometry — `check.sh` covers what markup
# gets emitted, this covers where it lands on screen, at right-gutter: 40%
# (`content/index.typ`, `content/blocks.typ`). Headless Chromium measures the
# built page after layout; no JS ships in the package itself, this is a test
# tool only.
set -euo pipefail
cd "$(dirname "$0")"
H=build/html
fail=0
note() { echo "FAIL: $*"; fail=1; }

measure() {
  local page="$1" script="$2" label="$3" size="${4:-1400,900}"
  # Split on the LAST slash, not prepended across one — `page` can itself
  # carry a directory (`ideas/margin-note`), and `_geom-ideas/foo.html`
  # would name a file inside a directory named `_geom-ideas` that does not
  # exist. The prefix lands on the basename instead, next to the original
  # page, so its relative stylesheet link still resolves either way.
  local geom="$H/$(dirname "$page")/_geom-$(basename "$page").html"
  [ -f "$H/$page.html" ] || { note "no $H/$page.html"; return 1; }
  # Copied NEXT TO the original so its relative stylesheet link still resolves.
  cp "$H/$page.html" "$geom"
  python3 - "$geom" "$script" <<'PY'
import sys
p, script_path = sys.argv[1], sys.argv[2]
s = open(p).read()
js = "<script>" + open(script_path).read() + "</script>"
open(p, "w").write(s.replace("</body>", js + "</body>"))
PY
  local out
  out=$(timeout 60 chromium --headless=new --disable-gpu --no-sandbox --window-size=$size \
    --dump-dom "$geom" 2>/dev/null \
    | grep -o 'data-out="[^"]*"' | sed 's/&quot;/"/g; s/^data-out="//; s/"$//')
  if [ -z "$out" ]; then
    note "$label: chromium produced no data-out attribute"
    return 1
  fi
  echo "$out"
}

INDEX_JS="$(mktemp)"
BLOCKS_JS="$(mktemp)"
MARGIN_PAGE_JS="$(mktemp)"
MIXED_JS="$(mktemp)"
PREVIEW_JS="$(mktemp)"
trap 'rm -f "$INDEX_JS" "$BLOCKS_JS" "$MARGIN_PAGE_JS" "$MIXED_JS" "$PREVIEW_JS"' EXIT

# Reproduces search/0.1.1/src/preview.js's exact wrapper shape around a
# fetched page's own [data-rookery="page-body"] — the search preview pane
# re-parents that element inside a hand-built [data-rookery="window"], and a
# card WITH a sidenote is the worst case for the split rule this exercises.
cat > "$H/_preview-fixture.html" <<'HTML'
<!doctype html>
<html><head><meta charset="utf-8">
<link rel="stylesheet" href="rookery/core/core.css">
</head><body>
<div data-rookery="mode" data-rookery-footnotes="horizontal" data-rookery-citations="horizontal" hidden="hidden"></div>
<div class="idea-window idea-window-plain" data-rookery="window" data-rookery-plain="plain">
  <div class="idea-window-body" data-rookery="window-body">
    <div data-rookery="page-body" style="width:400px">
      <p>Some body text.</p>
      <sup data-rookery="fn-ref"><a href="#fn-1-1">1</a></sup>
      <span data-rookery="sidenote">A margin note that must not reserve a gutter here.</span>
    </div>
  </div>
</div>
</body></html>
HTML

cat > "$INDEX_JS" <<'JS'
const r = el => el.getBoundingClientRect();
const byIdea = name => document.getElementById("idea:" + name).closest('[data-rookery="box"]');

// A <p> is a block box: its own right edge sits at its containing block's
// edge regardless of how much text is in it, which is what makes it a
// clean "did this card split" probe — an idea whose body is ONE paragraph
// gets no <p> wrapper at all (Typst emits one only where a `parbreak`
// actually splits something), so this reads `null` for those and the
// caller falls back to the padding-right check instead.
const firstParagraphRight = box => {
  const p = box.querySelector(':scope > p');
  return p ? r(p).right : null;
};

const measure = box => {
  const b = r(box);
  // A citation cited INSIDE a footnote (the fourth footnote's own Lamport
  // reference) mints a `[data-rookery="sidenote"]` TWICE: once nested inside
  // that footnote's own sidenote, and again where the Footnotes list below
  // repeats the same footnote body. core.css hides the first by nesting
  // (`[data-rookery="sidenote"] [data-rookery-cite]`) and the second because
  // its `[data-rookery="footnotes"]` ancestor is itself `display: none` on
  // an own card — an ancestor's `display: none` empties every descendant's
  // box, `getComputedStyle` on the descendant itself notwithstanding, so
  // both are excluded here by ancestor rather than by any property of the
  // note itself.
  const notes = [...box.querySelectorAll('[data-rookery="sidenote"]')]
    .filter(n => !n.closest('[data-rookery="window"]'))
    .filter(n => !n.closest('[data-rookery="footnotes"]'))
    .filter(n => n.parentElement.closest('[data-rookery="sidenote"]') === null)
    .map(n => {
      const nr = r(n);
      const p = r(n.parentElement);
      return {left: nr.left, right: nr.right, top: nr.top, bottom: nr.bottom, parentRight: p.right};
    });
  const dateEl = box.querySelector('[data-rookery="date"]');
  // The own card's References block, and its citation margin note if it has
  // one — `display-bibliography`'s effect and `citations: "horizontal"`'s
  // margin note are independent, so with-bib needs both checked together.
  const refs = box.querySelector('[data-rookery="references"]');
  const citeNote = box.querySelector('[data-rookery="sidenote"][data-rookery-cite]');
  return {
    right: b.right,
    width: b.width,
    paddingRight: parseFloat(getComputedStyle(box).paddingRight),
    notes,
    hasFootnotes: !!box.querySelector('[data-rookery="footnotes"]'),
    paragraphRight: firstParagraphRight(box),
    dateRight: dateEl ? r(dateEl).right : null,
    referencesDisplay: refs ? getComputedStyle(refs).display : null,
    citeNoteDisplay: citeNote ? getComputedStyle(citeNote).display : null,
  };
};

// `host-note`'s `#window` transclusion of `margin-note`: a transcluded body
// never splits, so its paragraphs span its own body's full content width —
// no gutter reserved, whatever the document's mode.
const windowBody = document.querySelector('[data-rookery="window-body"]');
const windowMeasure = () => {
  const b = r(windowBody);
  return {right: b.right, paragraphRight: firstParagraphRight(windowBody)};
};

// The blockquote inside `margin-note`'s own card, and a link-deadness probe
// on a footnote marker there (own card, always dead) and inside host-note's
// window (never dead — a window keeps its blocks visible, see core.css).
const marginNoteBox = byIdea("margin-note");
const cardFnRefLink = marginNoteBox.querySelector('[data-rookery="fn-ref"] a');
const windowFnRefLink = windowBody.querySelector('[data-rookery="fn-ref"] a');
const linkProbe = a => a && {
  pointerEvents: getComputedStyle(a).pointerEvents,
  textDecorationLine: getComputedStyle(a).textDecorationLine,
};
const blockquoteMeasure = box => {
  const bq = box.querySelector('blockquote');
  return bq ? r(bq).right : null;
};

document.body.dataset.out = JSON.stringify({
  marginNote: measure(byIdea("margin-note")),
  plainWide: measure(byIdea("plain-wide")),
  forcedGutter: measure(byIdea("forced-gutter")),
  noGutter: measure(byIdea("no-gutter")),
  withBib: measure(byIdea("with-bib")),
  noBib: measure(byIdea("no-bib")),
  window: windowMeasure(),
  blockquoteRight: blockquoteMeasure(marginNoteBox),
  cardFnRef: linkProbe(cardFnRefLink),
  windowFnRef: linkProbe(windowFnRefLink),
});
JS

cat > "$BLOCKS_JS" <<'JS'
const r = el => el.getBoundingClientRect();
const byIdea = name => document.getElementById("idea:" + name).closest('[data-rookery="box"]');
// The page-level block is the one `[data-rookery="gutter"]` with no card
// ancestor; `content/blocks.typ` writes exactly one.
const pageGutter = [...document.querySelectorAll('[data-rookery="gutter"]')]
  .find(g => !g.closest('[data-rookery="box"]'));
const afterPanel = byIdea("after-panel");
const ownBlock = byIdea("own-block");
const ownGutter = ownBlock.querySelector('[data-rookery="gutter"]');
const firstSidenote = box => box.querySelector('[data-rookery="sidenote"]');

const before = {
  pageGutter: r(pageGutter),
  afterPanel: r(afterPanel),
  afterPanelNote: r(firstSidenote(afterPanel)),
  ownBlock: r(ownBlock),
  ownGutter: r(ownGutter),
  ownGutterNote: r(firstSidenote(ownBlock)),
};

window.scrollTo(0, 1500);
before.stickyTop = r(pageGutter).top;
// The cover strip is the pinned block's own `::before`, growing up from its
// top edge — its computed height should track `--idea-gutter-top`, and its
// own top edge (the block's top minus that height) should sit at the
// viewport top once the block is pinned there.
before.coverHeight = parseFloat(getComputedStyle(pageGutter, '::before').height);

document.body.dataset.out = JSON.stringify(before);
JS

cat > "$MARGIN_PAGE_JS" <<'JS'
// Same probe as `INDEX_JS`'s `measure`, run against the minted page's
// `[data-rookery="page-body"]` instead of an idea's `[data-rookery="box"]` —
// the wrapper that gives a minted page the same "own card" standing.
const r = el => el.getBoundingClientRect();
const pageBody = document.querySelector('[data-rookery="page-body"]');
const firstParagraphRight = box => {
  const p = box.querySelector(':scope > p');
  return p ? r(p).right : null;
};
// FOOTNOTE notes only (`:not([data-rookery-cite])`) — a minted page's own
// citation notes are excluded here because `.marrow.typ` reads
// `_citation-mode.final()` (state.typ), the PROJECT'S last vertebra to
// apply `#show: rookery`, which this project's `content/mixed.typ` sets to
// "vertical" — so every minted page's own citation notes, margin-note's
// included, follow THAT, independently of margin-note's own
// footnotes:"horizontal" vertebra. check.sh's (d)/(e) probes citations only
// on the two vertebrae that emit their own marker directly (index.html,
// mixed.html), never a minted page, for the same reason.
const notes = [...pageBody.querySelectorAll('[data-rookery="sidenote"]:not([data-rookery-cite])')]
  .filter(n => !n.closest('[data-rookery="footnotes"]'))
  .filter(n => n.parentElement.closest('[data-rookery="sidenote"]') === null)
  .map(n => ({right: r(n).right}));
const bq = pageBody.querySelector('blockquote');
const sidenoteSample = pageBody.querySelector('[data-rookery="sidenote"]:not([data-rookery-cite])');
const footnotesBlock = pageBody.querySelector('[data-rookery="footnotes"]');
const fnRefLink = pageBody.querySelector('[data-rookery="fn-ref"] a');

// The head and the footer are the page body's SIBLINGS (`.marrow.typ`), not
// its descendants, so their own right edges have to be probed separately —
// the split reaching them at all is exactly what core.css's sibling-combinator
// rules are for.
const h1 = document.querySelector('[data-rookery="head"] > h1');
const dateEl = document.querySelector('[data-rookery="head"] [data-rookery="date"]');
const footer = document.querySelector('[data-rookery="footer"]');
const footerContentRight = footer
  ? r(footer).right - parseFloat(getComputedStyle(footer).paddingRight)
  : null;

// The theme (`content/lib.typ`'s `theme: (border-color: ..)`) reaches this
// sidenote only if `.marrow.typ` themes the page body itself — its border
// falls back to core's own default otherwise, whatever the project sets.
const sidenoteBorderColor = sidenoteSample
  ? getComputedStyle(sidenoteSample).borderLeftColor
  : null;
const pageBodyBorderColorVar = getComputedStyle(pageBody)
  .getPropertyValue('--idea-border-color')
  .trim();

document.body.dataset.out = JSON.stringify({
  right: r(pageBody).right,
  paddingRight: parseFloat(getComputedStyle(pageBody).paddingRight),
  notes,
  blockquoteRight: bq ? r(bq).right : null,
  textColumnRight: firstParagraphRight(pageBody),
  sidenoteDisplay: sidenoteSample ? getComputedStyle(sidenoteSample).display : null,
  footnotesDisplay: footnotesBlock ? getComputedStyle(footnotesBlock).display : null,
  fnRefPointerEvents: fnRefLink ? getComputedStyle(fnRefLink).pointerEvents : null,
  fnRefTextDecorationLine: fnRefLink ? getComputedStyle(fnRefLink).textDecorationLine : null,
  h1Right: h1 ? r(h1).right : null,
  dateRight: dateEl ? r(dateEl).right : null,
  footerContentRight,
  sidenoteBorderColor,
  pageBodyBorderColorVar,
});
JS

# `content/mixed.typ`'s own vertebra — `footnotes: "horizontal"` (the
# project default) but `citations: "vertical"` (its own override), so its
# footnote note shows and its citation note does not, the reverse of the
# References/Footnotes pair below it, and its citation link stays live
# (core.css's dead-link rule keys on `citations:`, not `footnotes:`).
cat > "$MIXED_JS" <<'JS'
const box = document.getElementById("idea:mixed-note").closest('[data-rookery="box"]');
const footnoteNote = box.querySelector('[data-rookery="sidenote"]:not([data-rookery-cite])');
const citeNote = box.querySelector('[data-rookery="sidenote"][data-rookery-cite]');
const referencesBlock = box.querySelector('[data-rookery="references"]');
const footnotesBlock = box.querySelector('[data-rookery="footnotes"]');
const citeLink = box.querySelector('a[role="doc-biblioref"]');

document.body.dataset.out = JSON.stringify({
  footnoteNoteDisplay: footnoteNote ? getComputedStyle(footnoteNote).display : null,
  citeNoteDisplay: citeNote ? getComputedStyle(citeNote).display : null,
  referencesDisplay: referencesBlock ? getComputedStyle(referencesBlock).display : null,
  footnotesDisplay: footnotesBlock ? getComputedStyle(footnotesBlock).display : null,
  citeLinkPointerEvents: citeLink ? getComputedStyle(citeLink).pointerEvents : null,
});
JS

cat > "$PREVIEW_JS" <<'JS'
const el = document.querySelector('[data-rookery="page-body"]');
document.body.dataset.out = JSON.stringify({
  paddingRight: el ? getComputedStyle(el).paddingRight : null,
});
JS

PREVIEW_OUT="$(measure _preview-fixture "$PREVIEW_JS" "_preview-fixture.html")" || { echo "demo/sidenotes geom FAILED"; exit 1; }
INDEX_OUT="$(measure index "$INDEX_JS" "index.html")" || { echo "demo/sidenotes geom FAILED"; exit 1; }
BLOCKS_OUT="$(measure blocks "$BLOCKS_JS" "blocks.html")" || { echo "demo/sidenotes geom FAILED"; exit 1; }
MARGIN_PAGE_OUT="$(measure ideas/margin-note "$MARGIN_PAGE_JS" "ideas/margin-note.html")" || { echo "demo/sidenotes geom FAILED"; exit 1; }
PLAIN_WIDE_PAGE_OUT="$(measure ideas/plain-wide "$MARGIN_PAGE_JS" "ideas/plain-wide.html")" || { echo "demo/sidenotes geom FAILED"; exit 1; }
NO_GUTTER_PAGE_OUT="$(measure ideas/no-gutter "$MARGIN_PAGE_JS" "ideas/no-gutter.html")" || { echo "demo/sidenotes geom FAILED"; exit 1; }
MIXED_OUT="$(measure mixed "$MIXED_JS" "mixed.html")" || { echo "demo/sidenotes geom FAILED"; exit 1; }
# Below the 769px breakpoint (core.css) every idea reverts to vertical, whatever
# footnotes:/citations: say — phone (375px) and tablet portrait (700px, still
# under 769px) both check this.
INDEX_NARROW_PHONE_OUT="$(measure index "$INDEX_JS" "index.html (375px)" 375,800)" || { echo "demo/sidenotes geom FAILED"; exit 1; }
INDEX_NARROW_TABLET_OUT="$(measure index "$INDEX_JS" "index.html (700px)" 700,900)" || { echo "demo/sidenotes geom FAILED"; exit 1; }

python3 - "$INDEX_OUT" "$BLOCKS_OUT" "$MARGIN_PAGE_OUT" "$PLAIN_WIDE_PAGE_OUT" "$NO_GUTTER_PAGE_OUT" "$MIXED_OUT" "$INDEX_NARROW_PHONE_OUT" "$INDEX_NARROW_TABLET_OUT" "$PREVIEW_OUT" <<'PY'
import json, sys

d = json.loads(sys.argv[1])
b = json.loads(sys.argv[2])
m = json.loads(sys.argv[3])
pwp = json.loads(sys.argv[4])
ngp = json.loads(sys.argv[5])
mx = json.loads(sys.argv[6])
d_phone = json.loads(sys.argv[7])
d_tablet = json.loads(sys.argv[8])
pv = json.loads(sys.argv[9])
TOL = 1
bad = []

def close(a, c, tol=TOL):
    return abs(a - c) <= tol

mn = d["marginNote"]
for n in mn["notes"]:
    if not close(n["right"], mn["right"]):
        bad.append(f"margin-note sidenote right {n['right']} != card right {mn['right']}")
    if n["left"] < n["parentRight"] - TOL:
        bad.append(f"margin-note sidenote left {n['left']} < paragraph right {n['parentRight']}")
if not close(mn["paddingRight"], 0.4 * mn["width"]):
    bad.append(f"margin-note padding-right {mn['paddingRight']} != 0.4 * width {mn['width']}")

# (c) The hat's date ends at the text column's right edge — the card's own
# content-box right edge, i.e. its border-box right minus its own
# padding-right, the same split that makes room for the margin notes.
mn_content_right = mn["right"] - mn["paddingRight"]
if mn["dateRight"] is None or not close(mn["dateRight"], mn_content_right):
    bad.append(f"margin-note card date right {mn['dateRight']} != content-box right {mn_content_right}")

# The blockquote is exactly as wide as the text column (its first plain
# paragraph's own right edge) — at most that edge, 1px tolerance either way.
if mn["paragraphRight"] is not None and d["blockquoteRight"] is not None:
    if d["blockquoteRight"] > mn["paragraphRight"] + TOL:
        bad.append(
            f"margin-note blockquote right {d['blockquoteRight']} > text column right "
            f"{mn['paragraphRight']}"
        )

# A footnote marker's link is dead on the card (nothing to click, its
# Footnotes block is hidden) and live inside host-note's window (its own
# Footnotes block stays visible — see core.css).
cfr = d["cardFnRef"]
if cfr is None or cfr["pointerEvents"] != "none" or cfr["textDecorationLine"] != "none":
    bad.append(f"margin-note card fn-ref link computes {cfr}, expected pointer-events/text-decoration none")
wfr = d["windowFnRef"]
if wfr is None or wfr["pointerEvents"] != "auto":
    bad.append(f"host-note window fn-ref link computes {wfr}, expected pointer-events auto")

# `plain-wide` has no footnotes or citations of its own, but the project
# sets `display-right-gutter: true` (content/lib.typ) with no per-note
# override, so it resolves "on" exactly as `forced-gutter` does explicitly —
# `_display-final`'s document-wide fallback (state.typ) reaches a note with
# no margin notes just as readily as one with them.
pw = d["plainWide"]
if not close(pw["paddingRight"], 0.4 * pw["width"]):
    bad.append(f"plain-wide padding-right {pw['paddingRight']} != 0.4 * width {pw['width']} — should split under the project's display-right-gutter: true")

# `no-gutter`'s body is a single paragraph, so Typst emits no <p> to probe —
# checked directly via padding-right instead, the mechanism the split
# itself is built on.
ng = d["noGutter"]
if not close(ng["paddingRight"], 0):
    bad.append(f"no-gutter padding-right {ng['paddingRight']} != 0 — should not split")
if not ng["hasFootnotes"]:
    bad.append("no-gutter card has no data-rookery=\"footnotes\" block")

fg = d["forcedGutter"]
if not close(fg["paddingRight"], 0.4 * fg["width"]):
    bad.append(f"forced-gutter padding-right {fg['paddingRight']} != 0.4 * width {fg['width']}")

# `display-bibliography` is independent of the split: with-bib's References
# block stays visible under citations: "horizontal" (its own override) while
# its citation margin note shows too, same as any other citing card;
# no-bib's and margin-note's References stay hidden under the same mode,
# margin-note carrying no override at all (`auto` following the mode).
wb = d["withBib"]
if wb["referencesDisplay"] == "none":
    bad.append("with-bib References block computes display: none, expected visible")
if wb["citeNoteDisplay"] != "block":
    bad.append(f"with-bib citation sidenote computes display: {wb['citeNoteDisplay']}, expected block")

nb = d["noBib"]
if nb["referencesDisplay"] != "none":
    bad.append(f"no-bib References block computes display: {nb['referencesDisplay']}, expected none")

if mn["referencesDisplay"] != "none":
    bad.append(f"margin-note References block computes display: {mn['referencesDisplay']}, expected none")

win = d["window"]
if win["paragraphRight"] is None or not close(win["paragraphRight"], win["right"]):
    bad.append(
        f"window paragraph right {win['paragraphRight']} != window body right "
        f"{win['right']} — a transcluded body must span its full content width"
    )

# The margin-note card's second and third footnotes sit on the same line
# (index.typ) — same-line markers stack their sidenotes rather than
# overlapping them.
notes = mn["notes"]
if len(notes) >= 3 and notes[2]["top"] < notes[1]["bottom"] - TOL:
    bad.append(
        f"same-line notes overlap: second top {notes[2]['top']} < "
        f"first bottom {notes[1]['bottom']}"
    )

# (a) The page-level gutter block's right edge equals after-panel's card's
# right edge — both read the same column.
pg = b["pageGutter"]
ap = b["afterPanel"]
if not close(pg["right"], ap["right"]):
    bad.append(f"blocks: page-level gutter right {pg['right']} != after-panel card right {ap['right']}")

# (b) after-panel's first sidenote is displaced below the page-level block.
apn = b["afterPanelNote"]
if apn["top"] < pg["bottom"] - TOL:
    bad.append(f"blocks: after-panel's sidenote top {apn['top']} < page-level gutter bottom {pg['bottom']}")

# (c) own-block's own gutter block matches its card's right edge, and its
# sidenote is displaced below that gutter block.
ob = b["ownBlock"]
og = b["ownGutter"]
ogn = b["ownGutterNote"]
if not close(og["right"], ob["right"]):
    bad.append(f"blocks: own-block's gutter right {og['right']} != card right {ob['right']}")
if ogn["top"] < og["bottom"] - TOL:
    bad.append(f"blocks: own-block's sidenote top {ogn['top']} < own gutter bottom {og['bottom']}")

# (d) After scrolling, the sticky block holds at `--idea-gutter-top`
# (content/demo.css sets it to 4rem == 64px), not the viewport top itself —
# that gap is exactly what the cover strip below has to span.
if not close(b["stickyTop"], 64):
    bad.append(f"blocks: sticky gutter top after scroll {b['stickyTop']} != 64 (--idea-gutter-top: 4rem)")

# (e) The cover strip (`::before`) spans exactly the gap `--idea-gutter-top`
# leaves above the pinned block — its height tracks that variable
# (content/demo.css sets it to 4rem == 64px at the default font size), and
# its own top edge (the block's top minus its height) sits at the viewport
# top once the block is pinned there.
if not close(b["coverHeight"], 64):
    bad.append(f"blocks: sticky gutter cover height {b['coverHeight']} != 64 (--idea-gutter-top: 4rem)")
if not close(b["stickyTop"] - b["coverHeight"], 0):
    bad.append(
        f"blocks: sticky gutter cover top {b['stickyTop'] - b['coverHeight']} != 0 "
        f"(block top {b['stickyTop']} minus cover height {b['coverHeight']})"
    )

# The minted `ideas/margin-note.html` page: its `[data-rookery="page-body"]`
# behaves exactly like the vertebra's own card above — every sidenote
# (including the blockquote's and the list item's) flush on the page body's
# right edge, the blockquote no wider than the text column, sidenotes
# visible and the Footnotes block hidden, and a dead fn-ref link — because
# it is the SAME "own card" standing core.css grants a page body.
for n in m["notes"]:
    if not close(n["right"], m["right"]):
        bad.append(f"minted margin-note page sidenote right {n['right']} != page-body right {m['right']}")
if m["textColumnRight"] is not None and m["blockquoteRight"] is not None:
    if m["blockquoteRight"] > m["textColumnRight"] + TOL:
        bad.append(
            f"minted margin-note page blockquote right {m['blockquoteRight']} > text column right "
            f"{m['textColumnRight']}"
        )
if m["sidenoteDisplay"] != "block":
    bad.append(f"minted margin-note page sidenote computes display: {m['sidenoteDisplay']}, expected block")
if m["footnotesDisplay"] != "none":
    bad.append(f"minted margin-note page Footnotes block computes display: {m['footnotesDisplay']}, expected none")
if m["fnRefPointerEvents"] != "none" or m["fnRefTextDecorationLine"] != "none":
    bad.append(
        f"minted margin-note page fn-ref link computes pointer-events: {m['fnRefPointerEvents']}, "
        f"text-decoration-line: {m['fnRefTextDecorationLine']}, expected none/none"
    )

# (a) The head (the tab and the <h1>) and the footer are SIBLINGS of the
# page body (`.marrow.typ`), not descendants of it, so the text column's
# right edge has to be computed off the page body itself: its border-box
# right minus its own computed padding-right.
m_text_col = m["right"] - m["paddingRight"]
if m["h1Right"] is None or m["h1Right"] > m_text_col + TOL:
    bad.append(f"minted margin-note page h1 right {m['h1Right']} > text column right {m_text_col}")
if m["footerContentRight"] is None or m["footerContentRight"] > m_text_col + TOL:
    bad.append(f"minted margin-note page footer content right {m['footerContentRight']} > text column right {m_text_col}")

# (b) The hat's date ends exactly at the text column's right edge, the same
# alignment the card wears (assertion (c) on margin-note's own card, above).
if m["dateRight"] is None or not close(m["dateRight"], m_text_col):
    bad.append(f"minted margin-note page date right {m['dateRight']} != text column right {m_text_col}")

# (d) A minted page's own `data-rookery-gutter` (`.marrow.typ`) drives the
# same split its card gets: `plain-wide` resolves "on" from the project's
# `display-right-gutter: true` and reserves a non-zero gutter; `no-gutter`
# resolves "off" from its own `display-right-gutter: false` override and
# reserves none. check.sh checks the attribute itself; this checks what it
# does to the layout.
if close(pwp["paddingRight"], 0):
    bad.append(f"minted plain-wide page padding-right {pwp['paddingRight']} == 0, expected a reserved gutter")
if not close(ngp["paddingRight"], 0):
    bad.append(f"minted no-gutter page padding-right {ngp['paddingRight']} != 0")

# (e) The theme (content/lib.typ's `theme: (border-color: rgb("#cc3300"))`)
# reaches the minted page body: a visible sidenote's border-left picks it up,
# and the page body itself carries a non-empty `--idea-border-color`.
if m["sidenoteBorderColor"] != "rgb(204, 51, 0)":
    bad.append(
        f"minted margin-note page sidenote border-left-color {m['sidenoteBorderColor']} "
        f"!= rgb(204, 51, 0) — theme not reaching the page body"
    )
if not m["pageBodyBorderColorVar"]:
    bad.append("minted margin-note page body's own --idea-border-color is empty")

# `mixed.html` (`content/mixed.typ`): `citations: "vertical"` overrides the
# project's `footnotes: "horizontal"` default, so the two modes land on
# opposite sides of the split — a footnote note shows and a citation note
# does not, a References block shows and the Footnotes block does not, and
# the citation link stays live rather than going dead.
if mx["footnoteNoteDisplay"] != "block":
    bad.append(f"mixed-note footnote sidenote computes display: {mx['footnoteNoteDisplay']}, expected block")
if mx["citeNoteDisplay"] != "none":
    bad.append(f"mixed-note citation sidenote computes display: {mx['citeNoteDisplay']}, expected none")
if mx["referencesDisplay"] == "none":
    bad.append("mixed-note References block computes display: none, expected visible")
if mx["footnotesDisplay"] != "none":
    bad.append(f"mixed-note Footnotes block computes display: {mx['footnotesDisplay']}, expected none")
if mx["citeLinkPointerEvents"] != "auto":
    bad.append(
        f"mixed-note doc-biblioref link computes pointer-events: {mx['citeLinkPointerEvents']}, expected auto"
    )

# Below core.css's 769px breakpoint, margin-note's sidenotes and its
# Footnotes block revert to vertical, whatever `footnotes: "horizontal"`
# says — at both phone (375px) and tablet portrait (700px) widths.
#
# margin-note's own padding-right is NOT part of this check: this project
# sets `display-right-gutter: true` (content/lib.typ) for every idea, so
# margin-note's own `data-rookery-gutter` resolves the same concrete "on"
# `forced-gutter` gets from an explicit override, and core.css's Non-goal
# keeps that unconditional split reserved at every width. So padding-right
# stays 0.4 of the card's width below 769px too — checked here as a
# regression guard, not as something this bird reverts.
#
# `notes` still returns 8 elements below 769px — `display: none` collapses
# a box's geometry to zero rather than removing it from `querySelectorAll`,
# so a hidden sidenote is checked by its collapsed rect, not by the array's
# length.
for label, dn in (("phone (375px)", d_phone), ("tablet (700px)", d_tablet)):
    mn_n = dn["marginNote"]
    if not close(mn_n["paddingRight"], 0.4 * mn_n["width"]):
        bad.append(
            f"margin-note {label} padding-right {mn_n['paddingRight']} != 0.4 * width "
            f"{mn_n['width']} — the forced data-rookery-gutter=\"on\" split should stay reserved"
        )
    for n in mn_n["notes"]:
        if not (close(n["left"], 0) and close(n["right"], 0) and close(n["top"], 0) and close(n["bottom"], 0)):
            bad.append(f"margin-note {label} sidenote {n} is not collapsed, expected display: none below 769px")
    if not mn_n["hasFootnotes"]:
        bad.append(f"margin-note {label} has no data-rookery=\"footnotes\" block, expected the vertical fallback")

# The search preview pane (search/0.1.1/src/preview.js) re-parents a fetched
# page's own [data-rookery="page-body"] inside a [data-rookery="window"] it
# builds by hand — this fixture reproduces that shape directly. A page-body
# nested in a window must never reserve a right-gutter split, however its
# mode marker reads.
if pv["paddingRight"] != "0px":
    bad.append(f"page-body nested in a window computes padding-right: {pv['paddingRight']}, expected 0px")

if bad:
    for line in bad:
        print("FAIL: " + line)
    sys.exit(1)

print(
    "  geom: margin-note's sidenotes sit flush on the card's right edge clear of "
    "its text, its padding-right is 0.4 of its width, its date ends at the text "
    "column's right edge, plain-wide now splits under the project's "
    "display-right-gutter: true and no-gutter still overrides back to unsplit, "
    "no-gutter keeps a Footnotes block, forced-gutter splits with no note, the "
    "two same-line notes stack, the blockquote stays within the text column, and "
    "a footnote link is dead on the card and live inside a window"
)
print(
    "  geom: blocks.html's page-level gutter block aligns with after-panel's "
    "card and displaces its sidenote, own-block's gutter block aligns with its "
    "own card and displaces its sidenote, and the sticky block holds at the "
    "viewport top after scrolling"
)
print(
    "  geom: the minted margin-note page's page-body carries the same own-card "
    "standing — its sidenotes align, its blockquote stays in the text column, "
    "sidenotes show, the Footnotes block hides, and its fn-ref links are dead; "
    "its head and footer, siblings of the body, split with it too, keeping the "
    "<h1>, the footer and the hat's date inside the text column; and plain-wide's "
    "minted page reserves a gutter while no-gutter's reserves none, matching "
    "each one's own `data-rookery-gutter` attribute"
)
print(
    "  geom: mixed.html's footnote note shows and citation note hides under its "
    "citations: \"vertical\" override, its References block shows and its "
    "Footnotes block hides, and its citation link stays live"
)
PY

status=$?
if [ "$status" -ne 0 ] || [ "$fail" -ne 0 ]; then
  echo "demo/sidenotes geom FAILED"
  exit 1
fi
echo "demo/sidenotes geom OK"
