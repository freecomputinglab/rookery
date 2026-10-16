#!/usr/bin/env bash
# Asserts the HAT stays flush with the box/window/page-row's own left edge
# at every device-pixel ratio, fractional ones included — the bug this
# covers only shows on DPR 1.25 and 1.75 (Windows 125%/175% scaling, or
# browser zoom at those factors), where Chromium snaps a rendered border
# width down to a whole device pixel while the hat's own `margin-left` calc
# subtracts the unsnapped CSS value. check.sh covers markup; this covers
# where it lands on screen after layout. No JS ships in the package itself,
# this is a test tool only.
set -euo pipefail
cd "$(dirname "$0")"
H=build/html
fail=0

JS="$(mktemp)"
GEOM="$H/_geom-index.html"
trap 'rm -f "$JS" "$GEOM"' EXIT

cat > "$JS" <<'JS'
const r = el => el.getBoundingClientRect();
const hosts = [...document.querySelectorAll(
  '[data-rookery="box"], [data-rookery="window"], [data-rookery="page-row"]'
)];
const out = hosts.map(host => {
  const tab = host.querySelector('[data-rookery="tab"]');
  if (!tab) return null;
  return {
    selector: host.getAttribute('data-rookery'),
    hostLeft: r(host).left,
    tabLeft: r(tab).left,
  };
}).filter(x => x !== null);
document.body.dataset.out = JSON.stringify(out);
JS

# Copied next to the original so its relative stylesheet link still
# resolves, then the probe is injected before `</body>`.
[ -f "$H/index.html" ] || { echo "FAIL: no $H/index.html"; exit 1; }
cp "$H/index.html" "$GEOM"
python3 - "$GEOM" "$JS" <<'PY'
import sys
p, script_path = sys.argv[1], sys.argv[2]
s = open(p).read()
js = "<script>" + open(script_path).read() + "</script>"
open(p, "w").write(s.replace("</body>", js + "</body>"))
PY

for dpr in 1 1.25 1.5 1.75 2; do
  out=$(timeout 60 chromium --headless=new --disable-gpu --no-sandbox \
    --window-size=1400,900 --force-device-scale-factor="$dpr" \
    --dump-dom "$GEOM" 2>/dev/null \
    | grep -o 'data-out="[^"]*"' | sed 's/&quot;/"/g; s/^data-out="//; s/"$//')
  if [ -z "$out" ]; then
    echo "FAIL: dpr=$dpr: chromium produced no data-out attribute"
    fail=1
    continue
  fi
  if ! python3 - "$dpr" "$out" <<'PY'
import json, sys
dpr, out = sys.argv[1], sys.argv[2]
rows = json.loads(out)
bad = False
for row in rows:
    diff = abs(row["hostLeft"] - row["tabLeft"])
    if diff > 0.01:
        print(f"FAIL: {dpr} {row['selector']} host={row['hostLeft']} tab={row['tabLeft']}")
        bad = True
sys.exit(1 if bad else 0)
PY
  then
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  exit 1
fi

# Second check: a window's summary is the same height open and closed, so the
# header row does not jump when a window is toggled.
SUM_JS="$(mktemp)"
trap 'rm -f "$JS" "$GEOM" "$SUM_JS"' EXIT

cat > "$SUM_JS" <<'JS'
const details = [...document.querySelectorAll('[data-rookery="window-details"]')];
const out = details.map(d => {
  const w = d.closest('[data-rookery="window"]');
  const s = d.querySelector(':scope > summary[data-rookery="window-summary"]');
  if (!w || !s) return null;
  const wasOpen = d.open;
  d.open = false;
  // `w.clientHeight` (an integer, per CSSOM) rounds off a subpixel remainder
  // that `getBoundingClientRect` keeps — comparing the two below would flag
  // that rounding as a real mismatch. Reading the closed height the same
  // fractional way `open` is read (the window's own rect, minus its floor
  // `border-bottom`, with no border-top to subtract) keeps both sides on the
  // same footing.
  const closedBorderBottom = parseFloat(getComputedStyle(w).borderBottomWidth);
  const closed = w.getBoundingClientRect().height - closedBorderBottom;
  d.open = true;
  const open = s.getBoundingClientRect().bottom - w.getBoundingClientRect().top;
  d.open = wasOpen;
  return { closed, open };
}).filter(x => x !== null);
document.body.dataset.out = JSON.stringify(out);
JS

for page in index.html relations.html tags.html; do
  SUM_GEOM="$H/_geom-summary-$page"
  [ -f "$H/$page" ] || { echo "FAIL: no $H/$page"; fail=1; continue; }
  cp "$H/$page" "$SUM_GEOM"
  python3 - "$SUM_GEOM" "$SUM_JS" <<'PY'
import sys
p, script_path = sys.argv[1], sys.argv[2]
s = open(p).read()
js = "<script>" + open(script_path).read() + "</script>"
open(p, "w").write(s.replace("</body>", js + "</body>"))
PY

  for dpr in 1 1.25; do
    out=$(timeout 60 chromium --headless=new --disable-gpu --no-sandbox \
      --window-size=1400,900 --force-device-scale-factor="$dpr" \
      --dump-dom "$SUM_GEOM" 2>/dev/null \
      | grep -o 'data-out="[^"]*"' | sed 's/&quot;/"/g; s/^data-out="//; s/"$//')
    if [ -z "$out" ]; then
      echo "FAIL: summary $page $dpr: chromium produced no data-out attribute"
      fail=1
      continue
    fi
    if ! python3 - "$page" "$dpr" "$out" <<'PY'
import json, sys
page, dpr, out = sys.argv[1], sys.argv[2], sys.argv[3]
rows = json.loads(out)
bad = False
for row in rows:
    c, o = row["closed"], row["open"]
    if abs(c - o) > 0.01:
        print(f"FAIL: summary {page} {dpr} closed={c} open={o}")
        bad = True
sys.exit(1 if bad else 0)
PY
    then
      fail=1
    fi
  done
  rm -f "$SUM_GEOM"
done

if [ "$fail" -ne 0 ]; then
  exit 1
fi

# Third check: a page row reads at the size of the prose it sits in, not the
# root size. On $H/index.html (which has unfurl:0 rows), pin :root to 16px and
# the row's nearest figure ancestor to 20px, then assert each row's computed
# size matches its parent list's. On a minted idea page with a footer, assert
# a footer page-row matches the size of whatever sits around the footer, since
# the footer itself reads smaller.
ROW_JS="$(mktemp)"
ROW_GEOM="$H/_geom-rowsize.html"
trap 'rm -f "$JS" "$GEOM" "$SUM_JS" "$ROW_JS" "$ROW_GEOM"' EXIT

cat > "$ROW_JS" <<'JS'
document.documentElement.style.fontSize = "16px";
const rows = [...document.querySelectorAll(
  'li[data-rookery="page-row"][data-rookery-window-link]'
)];
for (const row of rows) {
  const fig = row.closest("figure");
  if (fig) fig.style.fontSize = "20px";
}
const out = rows.map(row => ({
  row: getComputedStyle(row).fontSize,
  parent: getComputedStyle(row.parentElement).fontSize,
}));
document.body.dataset.out = JSON.stringify(out);
JS

[ -f "$H/index.html" ] || { echo "FAIL: no $H/index.html"; exit 1; }
cp "$H/index.html" "$ROW_GEOM"
python3 - "$ROW_GEOM" "$ROW_JS" <<'PY'
import sys
p, script_path = sys.argv[1], sys.argv[2]
s = open(p).read()
js = "<script>" + open(script_path).read() + "</script>"
open(p, "w").write(s.replace("</body>", js + "</body>"))
PY

out=$(timeout 60 chromium --headless=new --disable-gpu --no-sandbox \
  --window-size=1400,900 --dump-dom "$ROW_GEOM" 2>/dev/null \
  | grep -o 'data-out="[^"]*"' | sed 's/&quot;/"/g; s/^data-out="//; s/"$//')
if [ -z "$out" ]; then
  echo "FAIL: rowsize: chromium produced no data-out attribute"
  fail=1
elif ! python3 - "$out" <<'PY'
import json, sys
out = sys.argv[1]
rows = json.loads(out)
bad = False
for row in rows:
    if row["row"] != "20px" or row["row"] != row["parent"]:
        print(f"FAIL: rowsize index row={row['row']} parent={row['parent']}")
        bad = True
sys.exit(1 if bad else 0)
PY
then
  fail=1
fi
rm -f "$ROW_GEOM"

FOOTER_JS="$(mktemp)"
FOOTER_GEOM="$H/_geom-footerrowsize.html"
trap 'rm -f "$JS" "$GEOM" "$SUM_JS" "$ROW_JS" "$FOOTER_JS" "$FOOTER_GEOM"' EXIT

FOOTER_PAGE=$(grep -l 'data-rookery="footer"' "$H"/ideas/*.html 2>/dev/null | head -n1 || true)
if [ -z "$FOOTER_PAGE" ]; then
  echo "FAIL: rowsize: no minted idea page under $H/ideas has a footer"
  fail=1
else
  cat > "$FOOTER_JS" <<'JS'
const footer = document.querySelector('[data-rookery="footer"]');
const row = footer ? footer.querySelector('[data-rookery="page-row"]') : null;
const out = (footer && row) ? {
  row: getComputedStyle(row).fontSize,
  parent: getComputedStyle(footer.parentElement).fontSize,
} : null;
document.body.dataset.out = JSON.stringify(out);
JS

  cp "$FOOTER_PAGE" "$FOOTER_GEOM"
  python3 - "$FOOTER_GEOM" "$FOOTER_JS" <<'PY'
import sys
p, script_path = sys.argv[1], sys.argv[2]
s = open(p).read()
js = "<script>" + open(script_path).read() + "</script>"
open(p, "w").write(s.replace("</body>", js + "</body>"))
PY

  out=$(timeout 60 chromium --headless=new --disable-gpu --no-sandbox \
    --window-size=1400,900 --dump-dom "$FOOTER_GEOM" 2>/dev/null \
    | grep -o 'data-out="[^"]*"' | sed 's/&quot;/"/g; s/^data-out="//; s/"$//')
  if [ -z "$out" ] || [ "$out" = "null" ]; then
    echo "FAIL: rowsize footer: no footer page-row found on $FOOTER_PAGE"
    fail=1
  elif ! python3 - "$out" <<'PY'
import json, sys
row = json.loads(sys.argv[1])
r = float(row["row"].removesuffix("px"))
p = float(row["parent"].removesuffix("px"))
if abs(r - p) > 0.01:
    print(f"FAIL: rowsize footer row={row['row']} parent={row['parent']}")
    sys.exit(1)
PY
  then
    fail=1
  fi
  rm -f "$FOOTER_GEOM"
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

# Fourth check: on a minted idea page's footer, a Backlinks page row answers
# the pointer over its whole row (cursor: pointer, and a point 90% across the
# row resolves to the row's own anchor), while a Context page row does not
# (plain cursor, and the same point resolves to no anchor at all) — showing
# Context is untouched by this bird.
TAGHAT="$H/ideas/tag-hat.html"
[ -f "$TAGHAT" ] || { echo "FAIL: backlinkrow: no $TAGHAT"; exit 1; }

BLROW_JS="$(mktemp)"
BLROW_GEOM="$H/ideas/_geom-backlinkrow.html"
trap 'rm -f "$JS" "$GEOM" "$SUM_JS" "$ROW_JS" "$BLROW_JS" "$BLROW_GEOM"' EXIT

cat > "$BLROW_JS" <<'JS'
function probe(row) {
  if (!row) return null;
  const r = row.getBoundingClientRect();
  const x = r.left + r.width * 0.9;
  const y = r.top + r.height / 2;
  const el = document.elementFromPoint(x, y);
  const anchor = el ? el.closest('a') : null;
  const rowAnchor = row.querySelector(':scope > a');
  return {
    cursor: getComputedStyle(row).cursor,
    hitOwnAnchor: anchor !== null && anchor === rowAnchor,
  };
}
const backlinksRow = document.querySelector(
  '[data-rookery="backlinks"] li[data-rookery="page-row"]'
);
const contextRow = document.querySelector(
  '[data-rookery="context"] li[data-rookery="page-row"]'
);
document.body.dataset.out = JSON.stringify({
  backlinks: probe(backlinksRow),
  context: probe(contextRow),
});
JS

cp "$TAGHAT" "$BLROW_GEOM"
python3 - "$BLROW_GEOM" "$BLROW_JS" <<'PY'
import sys
p, script_path = sys.argv[1], sys.argv[2]
s = open(p).read()
js = "<script>" + open(script_path).read() + "</script>"
open(p, "w").write(s.replace("</body>", js + "</body>"))
PY

out=$(timeout 60 chromium --headless=new --disable-gpu --no-sandbox \
  --window-size=1400,900 --force-device-scale-factor=1 \
  --dump-dom "$BLROW_GEOM" 2>/dev/null \
  | grep -o 'data-out="[^"]*"' | sed 's/&quot;/"/g; s/^data-out="//; s/"$//')
if [ -z "$out" ]; then
  echo "FAIL: backlinkrow: chromium produced no data-out attribute"
  fail=1
elif ! python3 - "$out" <<'PY'
import json, sys
out = json.loads(sys.argv[1])
bad = False
bl = out.get("backlinks")
ctx = out.get("context")
if bl is None:
    print("FAIL: backlinkrow: no Backlinks page row found")
    bad = True
else:
    if bl["cursor"] != "pointer":
        print(f"FAIL: backlinkrow: cursor={bl['cursor']} want pointer")
        bad = True
    if not bl["hitOwnAnchor"]:
        print("FAIL: backlinkrow: 90% point did not resolve to the row's own anchor")
        bad = True
if ctx is None:
    print("FAIL: backlinkrow: no Context page row found")
    bad = True
else:
    if ctx["cursor"] == "pointer":
        print(f"FAIL: backlinkrow: context cursor={ctx['cursor']} want not pointer")
        bad = True
    if ctx["hitOwnAnchor"]:
        print("FAIL: backlinkrow: context 90% point unexpectedly resolved to an anchor")
        bad = True
sys.exit(1 if bad else 0)
PY
then
  fail=1
fi
rm -f "$BLROW_GEOM"

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "geom OK"
