#!/usr/bin/env bash
# Asserts the RIGHT GUTTER SPLIT's geometry — `check.sh` covers what markup
# gets emitted, this covers where it lands on screen, at right-gutter: 40%
# (`content/index.typ`). Headless Chromium measures the built page after
# layout; no JS ships in the package itself, this is a test tool only.
set -euo pipefail
cd "$(dirname "$0")"
H=build/html
GEOM="$H/_geom.html"
fail=0
note() { echo "FAIL: $*"; fail=1; }

[ -f "$H/index.html" ] || { note "no $H/index.html"; echo "demo/sidenotes geom FAILED"; exit 1; }

# Copied NEXT TO the original so its relative stylesheet link still resolves.
cp "$H/index.html" "$GEOM"
python3 - "$GEOM" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
js = """<script>
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
  stackFirst: r(document.getElementById("fn-1-2")),
  stackSecond: r(document.getElementById("fn-1-3")),
});
</script>"""
open(p, "w").write(s.replace("</body>", js + "</body>"))
PY

OUT=$(timeout 60 chromium --headless=new --disable-gpu --no-sandbox --window-size=1400,900 \
  --dump-dom "$GEOM" 2>/dev/null \
  | grep -o 'data-out="[^"]*"' | sed 's/&quot;/"/g; s/^data-out="//; s/"$//')

if [ -z "$OUT" ]; then
  note "chromium produced no data-out attribute"
  echo "demo/sidenotes geom FAILED"
  exit 1
fi

python3 - "$OUT" <<'PY'
import json, sys

d = json.loads(sys.argv[1])
TOL = 1
bad = []

def close(a, b, tol=TOL):
    return abs(a - b) <= tol

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

if d["stackSecond"]["top"] < d["stackFirst"]["bottom"] - TOL:
    bad.append(
        f"same-line notes overlap: second top {d['stackSecond']['top']} < "
        f"first bottom {d['stackFirst']['bottom']}"
    )

if bad:
    for b in bad:
        print("FAIL: " + b)
    sys.exit(1)

print(
    "  geom: margin-note's sidenotes sit flush on the card's right edge clear of "
    "its text, its padding-right is 0.4 of its width, plain-wide and no-gutter "
    "stay unsplit, no-gutter keeps a Footnotes block, forced-gutter splits with "
    "no note, and the two same-line notes stack"
)
PY

status=$?
if [ "$status" -ne 0 ] || [ "$fail" -ne 0 ]; then
  echo "demo/sidenotes geom FAILED"
  exit 1
fi
echo "demo/sidenotes geom OK"
