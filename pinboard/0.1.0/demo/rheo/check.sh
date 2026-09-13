#!/usr/bin/env bash
# Asserts on this demo's OUTPUT: the board rendered, and got exactly one card
# per note this fixture declares. Neither is visible from a Typst-only
# check — a compile succeeding proves nothing about what rheo actually wrote
# to disk.
#
# Run through `just check`, which builds first.
set -euo pipefail
cd "$(dirname "$0")"
H=build/html
fail=0
note() { echo "FAIL: $*"; fail=1; }

[ -f "$H/index.html" ] || note "no page at index.html"

want=$(grep -c '#idea(' content/index.typ)
got=$(grep -o 'data-pinboard-id' "$H/index.html" 2>/dev/null | wc -l | tr -d ' ')

grep -q 'data-pinboard=' "$H/index.html" || note "index.html carries no data-pinboard container"

if [ "$got" -ne "$want" ]; then
  note "index.html carries $got data-pinboard-id attributes, wanted $want (one per #idea() note in content/index.typ)"
fi

if [ "$fail" -eq 0 ]; then
  echo "  pinboard: $got cards, one per note"
  echo "demo/rheo OK"
else
  echo "demo/rheo FAILED"
  exit 1
fi
