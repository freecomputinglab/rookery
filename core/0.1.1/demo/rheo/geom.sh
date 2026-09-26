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
echo "geom OK"
