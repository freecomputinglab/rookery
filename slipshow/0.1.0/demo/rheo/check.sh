#!/usr/bin/env bash
# Asserts on this fixture's OUTPUT, not merely that the build succeeded — the
# DOM `src/slipshow.typ` renders only exists after a real rheo build, and
# nothing in `test/units.typ` (a paged, no-render compile) can see it.
#
# Run through `just check`, which builds first.
set -euo pipefail
cd "$(dirname "$0")"
H=build/html
P=build/pdf
fail=0
note() { echo "FAIL: $*"; fail=1; }

# 1. Every page the spine mints, at the HTML depth; the PDF format lays every
#    vertebra into ONE combined document rather than one file per page
#    (`SpineLayout::SingleCombined`, rheo core's `reticulate/spine.rs`), named
#    from this fixture's own directory rather than per page.
for f in index explicit predicate deck; do
  [ -f "$H/$f.html" ] || note "no page at $H/$f.html"
done
pdf="$P/rheo.pdf"
[ -f "$pdf" ] || note "no combined PDF at $pdf"

# 2. Exactly one deck wrapper per page, and one <section class="slip" per
#    authored note on it. The two definition routes (`index.typ`'s tag query,
#    `explicit.typ`'s array, `predicate.typ`'s predicate, `deck.typ`'s array)
#    all have to produce this same DOM shape (`src/slipshow.typ`'s header).
#    The third argument is the deck's `data-reveal` — always present on the
#    root, `progressive` unless the page passed `reveal: false`. Asserting it
#    HERE and not only that the attribute exists is what pins the default:
#    the reveal is otherwise invisible to a check on markup, since the hiding
#    itself is two runtime classes (`src/slipshow.js`'s `syncReveal`) and no
#    slip is rendered any differently for it.
check_page() {
  local file=$1 want=$2 reveal=${3:-progressive}
  local path="$H/$file.html"
  local divs secs
  divs=$(grep -o '<div class="slipshow"' "$path" | wc -l)
  [ "$divs" -eq 1 ] || note "$file.html: expected 1 div.slipshow, found $divs"
  secs=$(grep -o '<section class="slip' "$path" | wc -l)
  [ "$secs" -eq "$want" ] || note "$file.html: expected $want section.slip, found $secs"
  grep -q "data-reveal=\"$reveal\"" "$path" ||
    note "$file.html: expected the deck to carry data-reveal=\"$reveal\""
}

check_page index 5
check_page explicit 3 all
check_page predicate 2
check_page deck 12

# 2b. A QUERIED SLIP WEARS NO CARD CHROME. `#slipshow`'s `show-frame`/`show-id`/
#     `show-label` all default to false, so every slip the tag-query route
#     resolves is transcluded through a `#window` carrying `data-rookery-bare`,
#     and no `[idea:` permalink survives INSIDE the deck. Scoped to the deck and
#     not to the page: `index.typ` also authors those five notes inline, and
#     those copies are ordinary cards that keep their permalinks.
deck_chrome() {
  local file=$1 want=$2
  local path="$H/$file.html"
  local deck bare perms
  deck=$(sed 's/.*<div class="slipshow"/<div class="slipshow"/' "$path")
  # `|| true` on both: this script runs under `set -o pipefail`, and `grep`
  # exits 1 when it matches nothing — which for the permalink count is the
  # PASSING case, so without it a correct deck aborts the whole check.
  bare=$(printf '%s' "$deck" | grep -o 'data-rookery-bare' | wc -l || true)
  [ "$bare" -eq "$want" ] || note "$file.html: expected $want bare wrappers in the deck, found $bare"
  perms=$(printf '%s' "$deck" | grep -o 'idea-label' | wc -l || true)
  [ "$perms" -eq 0 ] || note "$file.html: expected no permalink inside the deck, found $perms"
}

deck_chrome index 5
deck_chrome predicate 2
# The ARRAY route reaches the same shape by the other half of the mechanism:
# `#slip` binds those defaults at its own call site, because its slips were
# rendered before any deck existed and nothing downstream can reach inside them.
deck_chrome explicit 3

# 3. deck.html carries exactly two fullscreen bookends — the opening and
#    closing slips, and nothing else on that page.
full=$(grep -o 'class="slip slip-fullscreen' "$H/deck.html" | wc -l)
[ "$full" -eq 2 ] || note "deck.html: expected 2 fullscreen slips, found $full"

# 4. The table slide's rows are PRESENT in the HTML output. This is the one
#    assertion that catches the grid-in-HTML trap (see deck.typ's own
#    "a-grid-vanishes-in-html" slip): a `grid` compiles clean and renders
#    correctly in the PDF, and is silently empty in the browser, so a check
#    on the PDF alone would pass while the page a reader opens is broken.
grep -q '<table' "$H/deck.html" || note "deck.html: no <table> element at all"
for row in "Aligns the slip" "Centers the slip" "Brings the slip fully into view"; do
  grep -q "$row" "$H/deck.html" || note "deck.html: table row missing: $row"
done

# 5. The background and non-default enter reach the markup as inline
#    attributes on the SECTION, never as a class.
grep -qi 'style="background: #eef4ea"' "$H/deck.html" ||
  note "deck.html: the background slip did not get an inline style"
grep -q 'data-enter="focus"' "$H/deck.html" ||
  note "deck.html: the enter:focus slip did not carry data-enter"

# 6. The PDF branch is transparent (`src/slipshow.typ`: "no camera, no deck,
#    nothing to click"): `deck.typ`'s slips show up as plain text, in
#    reading order, with no HTML tag ever entering a PDF-targeted compile at
#    all. Checked against `deck.typ`'s own slides only, not the other three
#    pages sharing this PDF: `index.typ`'s and `predicate.typ`'s tag-queried
#    decks legitimately print each transcluded note a second time, bracketed
#    "[idea:<name>]" by `#window`'s own paged rendering — a real feature of
#    the tag-query route, not the artefact this check is guarding against.
txt=$(pdftotext "$pdf" - 2>/dev/null)
[ -n "$(echo "$txt" | tr -d '[:space:]')" ] || note "rheo.pdf: pdftotext produced no text at all"
# A NARROW pattern, deliberately: several slides' own prose describes the
# HTML this package renders (`<section>`, `style="background: ..."`) as
# plain text, which a broader match on "<section" or "style=" would wrongly
# flag as a leak.
echo "$txt" | grep -qE '<section class=|<div class=|id="slip-|data-index="' &&
  note "rheo.pdf: an HTML tag leaked into the PDF text"
echo "$txt" | grep -q "endlessly scrolling presentation" ||
  note "rheo.pdf: deck.typ's opening slide is missing"
echo "$txt" | grep -q "End of the deck" ||
  note "rheo.pdf: deck.typ's closing slide is missing"
open_line=$(echo "$txt" | grep -n "endlessly scrolling presentation" | head -1 | cut -d: -f1)
close_line=$(echo "$txt" | grep -n "End of the deck" | head -1 | cut -d: -f1)
if [ -z "$open_line" ] || [ -z "$close_line" ] || [ "$open_line" -ge "$close_line" ]; then
  note "rheo.pdf: deck.typ's opening slide does not precede its closing slide"
fi

if [ "$fail" -eq 0 ]; then echo "demo/rheo OK"; else echo "demo/rheo FAILED"; exit 1; fi
