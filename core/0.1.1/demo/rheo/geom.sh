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
echo "geom OK"
