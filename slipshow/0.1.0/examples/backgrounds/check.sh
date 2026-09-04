#!/usr/bin/env bash
# Asserts on this example's OUTPUT, not merely that the build succeeded — a
# dropped CSS declaration, a mis-converted gradient angle, or an image
# referenced the wrong way all compile clean and none of them fails a build.
#
# Run through `just examples` at the package root, which builds first.
set -euo pipefail
cd "$(dirname "$0")"
H=build/html
P=build/pdf
fail=0
note() { echo "FAIL: $*"; fail=1; }

idx="$H/index.html"
fs="$H/fullscreen.html"
deep="$H/nested/deep.html"
tbl="$H/table.html"
for f in "$idx" "$fs" "$deep" "$tbl"; do
  [ -f "$f" ] || note "no page at $f"
done

# 1. Every gradient kind reached the markup, and the default linear gradient
#    carries the +90 correction (`_gradient-css`, `src/slipshow.typ`) rather
#    than Typst's own raw 0deg.
for kind in "linear-gradient(" "radial-gradient(" "conic-gradient("; do
  grep -qF "$kind" "$idx" || note "index.html: missing $kind"
done
grep -q 'linear-gradient(90deg' "$idx" ||
  note "index.html: the default linear gradient did not carry the +90 correction (want 90deg)"
grep -q 'linear-gradient(0deg' "$idx" &&
  note "index.html: the default linear gradient emitted Typst's raw 0deg, uncorrected"

# 2. The eight-digit alpha hex reaches the markup unmodified — no special
#    handling anywhere in this package, so a regression here is a regression
#    in `.to-hex()` itself, not in this package's own code.
grep -q '#ff000080' "$idx" || note "index.html: missing the alpha colour's #ff000080"

# 3. fullscreen.html: exactly two fullscreen sections, each carrying either
#    an image layer (`div.slip-bg`) or an inline gradient declaration.
full=$(grep -o 'class="slip slip-fullscreen' "$fs" | wc -l)
[ "$full" -eq 2 ] || note "fullscreen.html: expected 2 fullscreen slips, found $full"
python3 - "$fs" <<'PY' || fail=1
import re, sys
h = open(sys.argv[1]).read()
secs = re.findall(r'<section class="slip[^"]*slip-fullscreen[^"]*"[^>]*>.*?(?=<section class="slip|$)', h, re.S)
if len(secs) != 2:
    print(f"FAIL: expected 2 fullscreen sections, found {len(secs)}"); sys.exit(1)
for i, s in enumerate(secs):
    has_bg = '<div class="slip-bg"' in s
    has_gradient = re.search(r'background: (linear|radial|conic)-gradient\(', s) is not None
    if not (has_bg or has_gradient):
        print(f"FAIL: fullscreen section {i} has neither a div.slip-bg nor an inline gradient"); sys.exit(1)
print("  fullscreen: 2 sections, each carrying a background layer or a gradient")
PY

# 4. Both image formats reach the markup as `data:` URIs, and a
#    `background-image: url(..)` never does — this package copies no image
#    and rewrites no stylesheet, so a `url(` anywhere would mean an image
#    background regressed to a path-based one.
grep -rq 'data:image/png;base64,' "$H" || note "no PNG data: URI anywhere in build/html"
grep -rq 'data:image/jpeg;base64,' "$H" || note "no JPEG data: URI anywhere in build/html"
if find "$H" -name '*.html' -print0 | xargs -0 grep -l 'url(' >/dev/null 2>&1; then
  note "found a literal url( in the built HTML — an image background must be a data: URI"
fi

# 5. THE DEPTH ASSERTION: nested/deep.html embeds the byte-identical PNG
#    payload as fullscreen.html's own root-level image slip. A
#    `url(pattern.png)` would have resolved against a different directory at
#    each depth and broken one of the two; the data: URI does not care.
python3 - "$fs" "$deep" <<'PY' || fail=1
import re, sys
fs_html = open(sys.argv[1]).read()
deep_html = open(sys.argv[2]).read()
m1 = re.search(r'data:image/png;base64,[A-Za-z0-9+/=]+', fs_html)
m2 = re.search(r'data:image/png;base64,[A-Za-z0-9+/=]+', deep_html)
if not m1:
    print("FAIL: fullscreen.html carries no PNG data: URI"); sys.exit(1)
if not m2:
    print("FAIL: nested/deep.html carries no PNG data: URI"); sys.exit(1)
if m1.group(0) != m2.group(0):
    print("FAIL: fullscreen.html and nested/deep.html embed different PNG payloads for the same source image")
    sys.exit(1)
print("  depth: nested/deep.html embeds a byte-identical PNG payload to the root page")
PY

# 6. The PDF build exists and is transparent (`src/slipshow.typ`: "no
#    camera, no deck, nothing to click"): no HTML/slipshow wrapper artefact
#    ever enters a PDF-targeted compile, the note bodies are all present, and
#    the table's rows print in order — the one assertion that catches the
#    grid-in-HTML trap this package cannot express as code (see table.typ).
pdf=$(find "$P" -name '*.pdf' | head -1)
[ -n "$pdf" ] && [ -f "$pdf" ] || note "no PDF built under $P"
if [ -n "${pdf:-}" ] && [ -f "$pdf" ]; then
  txt=$(pdftotext "$pdf" - 2>/dev/null)
  [ -n "$(echo "$txt" | tr -d '[:space:]')" ] || note "pdftotext produced no text at all"
  # `[idea:<name>]` is the tag-query route's own second reference (`#window`'s
  # paged rendering, see `demo/rheo/check.sh`'s identical comment) — a real
  # feature of this route, not the leak this line guards against.
  echo "$txt" | grep -qE '<section class=|<div class=|id="slip-|data-index="|class="slipshow' &&
    note "an HTML/slipshow wrapper artefact leaked into the PDF text"
  echo "$txt" | grep -q "Read this paragraph against whatever the pattern draws behind it" ||
    note "pdf: fs-opening's body is missing"
  echo "$txt" | grep -q "this is genuinely the end of the deck rather than an arbitrary stopping point" ||
    note "pdf: fs-closing's long body is missing"
  echo "$txt" | grep -q "A radial gradient has no angle" ||
    note "pdf: the radial gradient slip's body is missing"
  for row in "Brings the slip fully into view" "Centers the slip on both axes" "Aligns the slip.s left edge"; do
    echo "$txt" | grep -q "$row" || note "pdf: table row missing: $row"
  done
  l1=$(echo "$txt" | grep -n "Brings the slip fully into view" | head -1 | cut -d: -f1)
  l2=$(echo "$txt" | grep -n "Centers the slip on both axes" | head -1 | cut -d: -f1)
  l3=$(echo "$txt" | grep -n "Aligns the slip.s left edge" | head -1 | cut -d: -f1)
  if [ -z "$l1" ] || [ -z "$l2" ] || [ -z "$l3" ] || [ "$l1" -ge "$l2" ] || [ "$l2" -ge "$l3" ]; then
    note "pdf: table rows are not in order (scroll, focus, left)"
  fi
fi

if [ "$fail" -eq 0 ]; then echo "examples/backgrounds OK"; else echo "examples/backgrounds FAILED"; exit 1; fi
