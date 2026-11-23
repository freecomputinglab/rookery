#!/usr/bin/env bash
# Asserts on this example's OUTPUT: that all three routes into a mixed
# #idea/#slip deck actually produce a mixed deck, not merely that the build
# succeeds — a deck silently missing every plain idea compiles just as clean
# as one that has them.
#
# Run through `just examples` at the package root, which builds first.
set -euo pipefail
cd "$(dirname "$0")"
H=build/html
fail=0
note() { echo "FAIL: $*"; fail=1; }

idx="$H/index.html"
tagged="$H/tagged.html"
inline="$H/inline.html"
pred="$H/predicate.html"
for f in "$idx" "$tagged" "$inline" "$pred"; do
  [ -f "$f" ] || note "no page at $f"
done

# 1. index.html: the explicit `slips:` array names four notes, two #slip and
#    two plain #idea — assert the id SEQUENCE, since the array route's whole
#    promise is the order, not just which four notes showed up.
python3 - "$idx" <<'PY' || fail=1
import re, sys
h = open(sys.argv[1]).read()
ids = re.findall(r'<section class="slip[^"]*" id="([^"]+)"', h)
want = ["slip-idea:opening", "slip-idea:background-note", "slip-idea:plain-context", "slip-idea:closing"]
if ids != want:
    print(f"FAIL: index.html section id order {ids}, want {want}")
    sys.exit(1)
print(f"  index: {len(ids)} sections in authored order")
PY

# 2. tagged.html: one section per note tagged `talk` in corpus.typ — ten of
#    them, five #idea and five #slip. `#slipshow(tags: "talk")` sees the
#    whole project-wide registry, not just this page, which is why this
#    count is ten and not some page-local subset.
n=$(grep -o '<section class="slip' "$tagged" | wc -l)
[ "$n" -eq 10 ] || note "tagged.html: expected 10 sections (corpus.typ tags ten notes 'talk'), found $n"

# 3. tagged.html holds STRICTLY MORE sections than `tags: "slip"` would
#    select. Core's #window — what a "row" entry (every note resolved BY
#    NAME, which is every note a tag query pulls in) renders through — now
#    puts its note's own visible tags on the window's wrapper, the same
#    `data-rookery-tags` a card carries (`@rookery/core`'s readme, "Tags").
#    That makes a #slip's raw "slip" tag a DIRECT DOM signal on the section
#    that windows it, not an inference from a presentation option reaching
#    the <section> the way `fullscreen: true`'s `slip-fullscreen` class used
#    to be the only proxy for it. Counting `data-rookery-tags` for the exact
#    tag "slip" (not merely containing it, so "slip-order"/"slip-background"
#    don't fool a substring match) gives the exact count of #slip-authored
#    sections — five, out of corpus.typ's ten "talk"-tagged notes — and five
#    of ten is still strictly fewer than the total, which is what proves this
#    "talk"-tagged deck holds more sections than a "tags: slip" deck would.
python3 - "$tagged" <<'PY' || fail=1
import re, sys
h = open(sys.argv[1]).read()
tag_lists = re.findall(r'data-rookery-tags="([^"]*)"', h)
total = len(tag_lists)
slip = sum(1 for tags in tag_lists if "slip" in tags.split())
if slip != 5:
    print(f"FAIL: tagged.html: expected exactly 5 sections carrying the 'slip' tag via data-rookery-tags, found {slip}")
    sys.exit(1)
if not (slip < total):
    print(f"FAIL: tagged.html: slip-tagged sections ({slip}) is not fewer than the total ({total})")
    sys.exit(1)
print(f"  tagged: {slip} of {total} sections carry the slip tag through data-rookery-tags")
PY

# 4. inline.html: three sections from ideas written inline in `slips:` rather
#    than named, and the one authored `fullscreen: true` still carries
#    `slip-fullscreen` — proving an option survives being read back off
#    rendered content (`marker.typ`'s `slip-tags-of`) as well as off a
#    registry row.
n=$(grep -o '<section class="slip' "$inline" | wc -l)
[ "$n" -eq 3 ] || note "inline.html: expected 3 sections, found $n"
grep -q '<section class="slip slip-fullscreen" id="slip-0"' "$inline" ||
  note "inline.html: the first section (fullscreen: true) is missing slip-fullscreen"

# 5. predicate.html: non-empty, and every note it selected has a label
#    starting with "Method" — an empty deck is this page's silent failure
#    mode, since `where:` needing no tag means it also has no cheap filter to
#    fall back on if the predicate matches nothing.
python3 - "$pred" <<'PY' || fail=1
import re, sys
h = open(sys.argv[1]).read()
titles = re.findall(r'data-rookery="window-title">([^<]*)</span>', h)
if len(titles) == 0:
    print("FAIL: predicate.html selected no notes at all")
    sys.exit(1)
bad = [t for t in titles if not t.startswith("Method")]
if bad:
    print(f"FAIL: predicate.html selected a note not labelled 'Method...': {bad}")
    sys.exit(1)
print(f"  predicate: {len(titles)} notes, all labelled 'Method...'")
PY

if [ "$fail" -eq 0 ]; then echo "examples/mixed OK"; else echo "examples/mixed FAILED"; exit 1; fi
