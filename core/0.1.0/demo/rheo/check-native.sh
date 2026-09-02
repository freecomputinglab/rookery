#!/usr/bin/env bash
# Asserts on `build/native.html` — the SAME rookery `check.sh` asserts on, compiled
# the other way, plain `typst compile` with no rheo. A second script rather than a
# mode flag on `check.sh`: the two builds claim DIFFERENT things about the same
# content (one has minted pages and depth-relative hrefs, the other has neither),
# so a single script branching on which half to run would spend most of its lines
# deciding that rather than asserting. Run it through `just check-typst`, which
# compiles first.
set -euo pipefail
cd "$(dirname "$0")"
N=build/native.html
fail=0
note() { echo "FAIL: $*"; fail=1; }

# 1. The package's core apparatus still renders with no rheo at all — cards,
#    transclusion, per-note footnotes and per-note references — which is
#    `demo/pure`'s whole claim, now made over this rookery's actual content
#    rather than a smaller standalone fixture.
for class in idea-box idea-window idea-footnotes idea-references; do
  rg -q "$class" "$N" || note "build/native.html has no $class — the core apparatus did not render"
done

# 2. NO minted-page href anywhere. Without rheo there are no pages to link to,
#    so every row that would otherwise point at one degrades to unlinked text
#    or an in-page fragment instead.
if rg -q 'ideas/[a-zA-Z0-9_-]+\.html' "$N"; then
  note "build/native.html links a minted note page — there should be none without rheo"
fi

# 3. The cycle cases still terminate, and still render their own card exactly
#    once — the same bounded-render guarantee `check.sh` pins under rheo,
#    proven again here because `_flatten`'s depth budget is per-CALL, not
#    per-build, so nothing about rheo's own page-per-vertebra split is what
#    makes it hold.
for id in self-loop cycle-a cycle-b; do
  n=$(grep -o "id=\"idea:$id\" class=\"idea\"" "$N" | wc -l)
  [ "$n" -eq 1 ] ||
    note "build/native.html renders idea:$id's card $n times, expected exactly 1"
done

# 4. Exclusion and tag invisibility hold with no rheo involved either — both
#    are plain Typst-side filtering, so nothing here is rheo-specific, but a
#    regression in either would be just as invisible to a reader without this.
if grep -q -e 'PRIVATEBODY' -e 'private-note' "$N"; then
  note "build/native.html leaks the excluded note"
fi
if grep -q 'idea-tag-secret' "$N"; then
  note "build/native.html leaks the invisible tag as a class"
fi
grep -q 'idea-tag-note' "$N" ||
  note "build/native.html lost the visible 'note' tag class — the control for the invisible-tag checks above"

# 5. The `vertebra-link` guard (`content/lib.typ`): a page-handle link keeps its
#    sentence's words and loses its `<a>` under a native compile, rather than
#    failing to compile on a `label` that only rheo publishes.
for phrase in "the nested vertebra" "the root vertebra"; do
  grep -q "$phrase" "$N" ||
    note "build/native.html is missing the vertebra-link guard text '$phrase'"
  if grep -q "<a[^>]*>$phrase" "$N"; then
    note "build/native.html links '$phrase' — vertebra-link should degrade to plain text without rheo"
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "demo/rheo (native): FAILED"
  exit 1
fi
echo "demo/rheo (native) OK"
