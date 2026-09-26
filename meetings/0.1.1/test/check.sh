#!/usr/bin/env bash
# Asserts on the rendered fixture's OUTPUT, not merely that it compiled.
# `units.typ` covers every value; this covers the markup and, above all, the
# ORDER of the three blocks a meeting's card holds: record, rail, prose.
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

held = card("held")
# 1. THE RECORD IS THERE, with the person as a resolved ref.
if 'class="meeting-fields-head"' not in held or 'class="meeting-fields"' not in held:
    note("held: no record block")
if "Finale Doshi-Velez" not in held:
    note("held: the with: ref did not resolve to the target's title")

# 2. THE ORDER IS RECORD, RAIL, PROSE — the whole point of the block living in
#    the body rather than in a page template.
o_head = held.find('class="meeting-fields-head"')
o_dl = held.find('class="meeting-fields"')
o_rail = held.find('<ol class="timeline">')
o_body = held.find("What was said")
if not (0 < o_head < o_dl < o_rail < o_body):
    note("held: blocks out of order (head %d, dl %d, rail %d, body %d)"
         % (o_head, o_dl, o_rail, o_body))

# 3. ONE ROW, past and current, carrying the date in timeline's short form and
#    the `occurred` stage — and no `created` row doubling the same day.
rows = re.findall(r'<li class="timeline-event ([a-z- ]+)">(.*?)</li>', held, re.S)
if [c for c, _ in rows] != ["timeline-past timeline-current"]:
    note("held: rail rows are %r" % [c for c, _ in rows])
if rows and ("10.9.26" not in rows[0][1] or "occurred" not in rows[0][1]):
    note("held: rail row reads %r" % rows[0][1])

# 4. A MEETING STILL AHEAD is drawn as booked, which is what a reference date buys.
booked = card("booked")
if "timeline-future" not in booked:
    note("booked: a future meeting is not drawn as a future row")

# 5. NEITHER ARGUMENT, NEITHER BLOCK: no record, no rail, no empty apparatus.
bare = card("bare")
if "meeting-fields" in bare or '<ol class="timeline">' in bare:
    note("bare: a meeting with no with:/on: drew a record block anyway")

sys.exit(fail)
PY
echo "view OK"
