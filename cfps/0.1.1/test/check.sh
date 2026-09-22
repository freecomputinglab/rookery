#!/usr/bin/env bash
# Asserts on the rendered fixture's OUTPUT, not merely that it compiled.
# `units.typ` covers every value; this covers the markup — that a rail draws
# from `deadline:` alone, that the opportunity table sits between the title and
# the rail, that a venue backlink is present only where `venue:` was given, and
# that `panel:`'s rows carry the right classes for settled/open/watching — plus
# one thing neither fixture can check: that a bad `kind:` fails LOUDLY, which
# needs its own `typst compile` this script expects to fail.
set -euo pipefail
cd "$(dirname "$0")/.."
H=test/build/view.html
[ -f "$H" ] || { echo "FAIL: no $H — run 'just test' first"; exit 1; }

python3 - "$H" <<'PY'
import re, sys
h = open(sys.argv[1]).read()
fail = 0
def note(msg):
    global fail
    print("FAIL:", msg); fail = 1

# One card per note, sliced on the note's own anchor id.
def card(name):
    i = h.find('id="idea:%s"' % name)
    if i < 0:
        note("no card for %s" % name); return ""
    j = h.find('</figure>', i)
    return h[i:j]

deadline_only = card("acme-deadline-only")
settled = card("acme-settled")
watching = card("no-venue-watching")

# 1. THE RAIL DRAWS FROM `deadline:` ALONE — no `timeline:` was given here, and
#    the rail is the whole point of a call whose only fact so far is its wire.
if '<ol class="timeline">' not in deadline_only:
    note("deadline-only: no rail drawn from deadline: alone")
if "idea-timeline-head" not in deadline_only:
    note("deadline-only: no 'Timeline' head above the rail")

# 2. ORDER: opportunity table, then the rail, then the prose, then the venue
#    backlink — `acme-settled` is the one fixture carrying `work:`, so the
#    table actually renders and its position can be checked.
o_dl = settled.find('class="opportunity-meta"')
o_rail = settled.find('class="idea-timeline-head"')
o_body = settled.find("Answered and settled")
o_ref = settled.find('class="idea-ref"')
if not (0 < o_dl < o_rail < o_body < o_ref):
    note("settled: blocks out of order (table %d, rail head %d, body %d, ref %d)"
         % (o_dl, o_rail, o_body, o_ref))
if "<dt>Work</dt>" not in settled:
    note("settled: opportunity table missing its Work row")

# 3. A VENUE BACKLINK appears only where `venue:` was given.
if "Acme University" not in deadline_only or "Acme University" not in settled:
    note("a cfp naming a venue drew no backlink to it")
if "Acme University" in watching or "idea-ref" in watching:
    note("a cfp naming no venue drew a backlink anyway")

# 4. `panel:`'s rows carry the right classes for settled / open / watching.
def round_list(state):
    m = re.search(r'<ul class="round-list round-list-%s">(.*?)</ul>' % state, h, re.S)
    return m.group(1) if m else None

settled_row = round_list("settled")
if settled_row is None:
    note("no round-list-settled panel rendered")
elif "round-badge-outcome" not in settled_row or "idea-tag-offered" not in settled_row:
    note("settled row: no terminal-stage outcome badge")

open_row = round_list("open")
if open_row is None:
    note("no round-list-open panel rendered")
elif "round-when soft" in open_row or "<time" not in open_row:
    note("open row: a firm deadline did not render as a firm, dated cell")

watching_row = round_list("watching")
if watching_row is None:
    note("no round-list-watching panel rendered")
elif "round-when soft" not in watching_row or ">—<" not in watching_row:
    note("watching row: a call with no wire at all did not render as undated/soft")

# 5. THE EMPTY STATE: nothing in this fixture ever reaches "in-flight".
if 'class="round-empty"' not in h:
    note("no empty-panel state rendered for the state nothing in this fixture reaches")

sys.exit(fail)
PY
echo "view OK"

# 6. A `kind:` outside `kinds:` fails LOUDLY — cannot be asserted inside
#    units.typ, since a failing assert aborts that whole compile rather than
#    being catchable. So this compiles a small standalone fixture EXPECTED to
#    fail, and checks the error names the valid kinds rather than crashing
#    somewhere unrecognisable.
BAD=test/build/bad-kind.typ
cat > "$BAD" <<'TYP'
#import "/src/lib.typ": cfps
#let cfp = cfps(kinds: (
  postdoc: (sort: "job", ladder: (transit: ("submitted",), terminal: ("offered",))),
)).cfp
#cfp("bad-kind", kind: "not-a-real-kind", today: datetime(year: 2026, month: 1, day: 1))[Bad.]
TYP
if OUT=$(typst compile --features html --root . --format html "$BAD" test/build/bad-kind.html 2>&1); then
  echo "FAIL: a bad kind: compiled instead of failing loudly"
  exit 1
fi
if ! echo "$OUT" | grep -q "postdoc"; then
  echo "FAIL: the bad-kind error does not name the valid kinds:"
  echo "$OUT"
  exit 1
fi
echo "bad-kind OK"
