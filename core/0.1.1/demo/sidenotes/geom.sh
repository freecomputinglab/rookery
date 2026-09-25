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
  local page="$1" script="$2" label="$3"
  local geom="$H/_geom-$page.html"
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
  out=$(timeout 60 chromium --headless=new --disable-gpu --no-sandbox --window-size=1400,900 \
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
trap 'rm -f "$INDEX_JS" "$BLOCKS_JS"' EXIT

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
  const notes = [...box.querySelectorAll('[data-rookery="sidenote"]')]
    .filter(n => !n.closest('[data-rookery="window"]'))
    .map(n => {
      const nr = r(n);
      const p = r(n.parentElement);
      return {left: nr.left, right: nr.right, top: nr.top, bottom: nr.bottom, parentRight: p.right};
    });
  return {
    right: b.right,
    width: b.width,
    paddingRight: parseFloat(getComputedStyle(box).paddingRight),
    notes,
    hasFootnotes: !!box.querySelector('[data-rookery="footnotes"]'),
    paragraphRight: firstParagraphRight(box),
  };
};

document.body.dataset.out = JSON.stringify({
  marginNote: measure(byIdea("margin-note")),
  plainWide: measure(byIdea("plain-wide")),
  forcedGutter: measure(byIdea("forced-gutter")),
  noGutter: measure(byIdea("no-gutter")),
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

document.body.dataset.out = JSON.stringify(before);
JS

INDEX_OUT="$(measure index "$INDEX_JS" "index.html")" || { echo "demo/sidenotes geom FAILED"; exit 1; }
BLOCKS_OUT="$(measure blocks "$BLOCKS_JS" "blocks.html")" || { echo "demo/sidenotes geom FAILED"; exit 1; }

python3 - "$INDEX_OUT" "$BLOCKS_OUT" <<'PY'
import json, sys

d = json.loads(sys.argv[1])
b = json.loads(sys.argv[2])
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

pw = d["plainWide"]
if pw["paragraphRight"] is None or not close(pw["paragraphRight"], pw["right"]):
    bad.append(f"plain-wide paragraph right {pw['paragraphRight']} != card right {pw['right']} — should not split")

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

# (d) After scrolling, the sticky block holds at the viewport top.
if not close(b["stickyTop"], 0):
    bad.append(f"blocks: sticky gutter top after scroll {b['stickyTop']} != 0")

if bad:
    for line in bad:
        print("FAIL: " + line)
    sys.exit(1)

print(
    "  geom: margin-note's sidenotes sit flush on the card's right edge clear of "
    "its text, its padding-right is 0.4 of its width, plain-wide and no-gutter "
    "stay unsplit, no-gutter keeps a Footnotes block, forced-gutter splits with "
    "no note, and the two same-line notes stack"
)
print(
    "  geom: blocks.html's page-level gutter block aligns with after-panel's "
    "card and displaces its sidenote, own-block's gutter block aligns with its "
    "own card and displaces its sidenote, and the sticky block holds at the "
    "viewport top after scrolling"
)
PY

status=$?
if [ "$status" -ne 0 ] || [ "$fail" -ne 0 ]; then
  echo "demo/sidenotes geom FAILED"
  exit 1
fi
echo "demo/sidenotes geom OK"
