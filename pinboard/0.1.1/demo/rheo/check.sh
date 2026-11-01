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
windows=$(grep -o 'data-rookery="window-details"' "$H/index.html" 2>/dev/null | wc -l | tr -d ' ')
hats=$(grep -o 'data-rookery="tab"' "$H/index.html" 2>/dev/null | wc -l | tr -d ' ')
themed=$(grep -o 'data-pinboard-id="[^"]*"><figure><div [^>]*--idea-border-color' "$H/index.html" 2>/dev/null | wc -l | tr -d ' ')

grep -q 'data-pinboard=' "$H/index.html" || note "index.html carries no data-pinboard container"

if [ "$got" -ne "$want" ]; then
  note "index.html carries $got data-pinboard-id attributes, wanted $want (one per #idea() note in content/index.typ)"
fi

# A card IS a core #window: the disclosure is what opens it with no JavaScript
# at all, and the hat is what carries the note's id across its top rule.
if [ "$windows" -ne "$want" ]; then
  note "index.html carries $windows window disclosures, wanted $want (one per card, so every card opens without JavaScript)"
fi

# One hat per card, plus the one each #idea() note wears where it was written.
if [ "$hats" -ne $((want * 2)) ]; then
  note "index.html carries $hats hats, wanted $((want * 2)) (one per card and one per note on the page)"
fi

# The theme this fixture sets reaches the board for free, because core writes a
# project's properties onto the window a card is built from.
if [ "$themed" -ne "$want" ]; then
  note "$themed of $want cards carry the project's --idea-border-color"
fi

if [ "$fail" -eq 0 ]; then
  echo "  pinboard: $got cards, one per note"
  echo "demo/rheo OK"
else
  echo "demo/rheo FAILED"
  exit 1
fi
