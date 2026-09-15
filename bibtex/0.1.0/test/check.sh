#!/usr/bin/env bash
# Asserts on `test/sweep.typ`'s rendered OUTPUT, not merely that it compiled.
# `units.typ` covers `bibtex(..)`'s pure logic; this covers what `all()`
# actually registers — one note per bibliography key not already claimed by a
# hand-written `#citation`, each keyed by its BibTeX key rather than by the
# unnamed-note counter.
set -euo pipefail
cd "$(dirname "$0")/.."
S=test/build/sweep.html
fail=0
note() { echo "FAIL: $*"; fail=1; }

[ -f "$S" ] || { echo "FAIL: no $S — run 'just test' first"; exit 1; }

python3 - "$S" <<'PY' || fail=1
import re, sys
h = open(sys.argv[1]).read()

def txt(s):
    return " ".join(re.sub(r"<[^>]+>", " ", s).split())

# Each row is a `<div class="sweep-row">` holding one `<span class="sweep-id">`
# and one `<span class="sweep-body">` — separate elements rather than a single
# text-joined string, so the empty-body row cannot be mangled by HTML's own
# whitespace collapsing. One row per note `ideas()` found registered — a
# faithful count of the registry, not of what the fixture merely asked to mint.
rows = re.findall(r'<div class="sweep-row">(.*?)</div>', h, re.S)
if len(rows) != 2:
    print(f"FAIL: expected 2 registered notes, found {len(rows)}: {rows}"); sys.exit(1)

def cell(row, cls):
    m = re.search(rf'<span class="{cls}">(.*?)</span>', row, re.S)
    return txt(m.group(1)) if m else None

pairs = [(cell(r, "sweep-id"), cell(r, "sweep-body")) for r in rows]
ids = sorted(p[0] for p in pairs)
if ids != ["idea:badiou2002", "idea:smith2020"]:
    print(f"FAIL: registered ids are {ids}, wanted idea:badiou2002 and idea:smith2020")
    sys.exit(1)

# NEITHER named `1`: the whole defect this design exists to avoid is `all()`
# reading a single-argument mint as an unnamed note, landing it on the
# sequence counter as `idea:1` instead of under its own key.
if any(p[0] == "idea:1" for p in pairs):
    print(f"FAIL: a note minted as the unnamed counter's `idea:1`: {rows}"); sys.exit(1)

by_id = dict(pairs)
if by_id["idea:badiou2002"] != "A hand-written body.":
    print(f"FAIL: the hand-written citation's body is {by_id['idea:badiou2002']!r}, "
          f"wanted 'A hand-written body.'")
    sys.exit(1)
if by_id["idea:smith2020"] != "":
    print(f"FAIL: the swept note's body is {by_id['idea:smith2020']!r}, wanted empty")
    sys.exit(1)

print(f"  all(): 2 notes registered — {rows}")
PY

FL=test/build/fields.html
[ -f "$FL" ] || { echo "FAIL: no $FL — run 'just test' first"; exit 1; }

# `fields.typ` hides `doi` and `urldate` via the factory's own `show-fields:` —
# their `<dt>` rows must be entirely absent, and a field the entry carries but
# the dictionary doesn't name (`author`) must still be there.
python3 - "$FL" <<'PY' || fail=1
import re, sys
h = open(sys.argv[1]).read()

if "<dt>DOI</dt>" in h:
    print("FAIL: show-fields hid \"doi\" but <dt>DOI</dt> is still rendered")
    sys.exit(1)
if "<dt>Accessed</dt>" in h:
    print("FAIL: show-fields hid \"urldate\" but <dt>Accessed</dt> is still rendered")
    sys.exit(1)
if "<dt>Author</dt>" not in h:
    print("FAIL: show-fields did not name \"author\" but its <dt>Author</dt> is missing")
    sys.exit(1)
print("  show-fields: doi and urldate absent, author present")
PY

EX=test/build/sweep-existing.html
AL=test/build/sweep-all.html
[ -f "$EX" ] || { echo "FAIL: no $EX — run 'just test' first"; exit 1; }
[ -f "$AL" ] || { echo "FAIL: no $AL — run 'just test' first"; exit 1; }

# `keywords: "existing"` keeps a keyword only where it already matches a tag
# elsewhere in the rookery (`liminal`, seeded by the hand-written `seed`
# note); `keywords: "all"` keeps every keyword regardless. Both fixtures mint
# the same three bibliography entries, so the two `kw-row` scans below are
# directly comparable — the only thing that differs is which keywords
# survive.
python3 - "$EX" "$AL" <<'PY' || fail=1
import re, sys

def txt(s):
    return " ".join(re.sub(r"<[^>]+>", " ", s).split())

def rows(path):
    h = open(path).read()
    out = {}
    for row in re.findall(r'<div class="kw-row">(.*?)</div>', h, re.S):
        m_id = re.search(r'<span class="kw-id">(.*?)</span>', row, re.S)
        m_tags = re.search(r'<span class="kw-tags">(.*?)</span>', row, re.S)
        out[txt(m_id.group(1))] = txt(m_tags.group(1)) if m_tags else ""
    return out

existing = rows(sys.argv[1])
all_mode = rows(sys.argv[2])

want_existing = {
    "idea:aaa": "citation,liminal",
    "idea:bbb": "citation",
    "idea:ccc": "citation",
    "idea:seed": "liminal",
}
want_all = {
    "idea:aaa": "brandnew,citation,liminal",
    "idea:bbb": "brandnew,citation",
    "idea:ccc": "citation,digital-humanities",
    "idea:seed": "liminal",
}

ok = True
if existing != want_existing:
    print(f"FAIL: keywords=\"existing\" tags are {existing}, wanted {want_existing}")
    ok = False
if all_mode != want_all:
    print(f"FAIL: keywords=\"all\" tags are {all_mode}, wanted {want_all}")
    ok = False

def fmt(d):
    ids = ("idea:aaa", "idea:bbb", "idea:ccc", "idea:seed")
    return " | ".join(f"{k.split(':')[1]}={d[k].replace(',', '+')}" for k in ids)

print(f'  existing: {fmt(existing)}')
print(f'  all:      {fmt(all_mode)}')

if not ok: sys.exit(1)
PY

# Every `class="..."` a note carries is `idea`, `idea-box`, `idea-tag` (the
# permalink pill's own shape hook) or `idea-tag-<slug>`, where `<slug>` is
# what `keyword-tags` produces (lowercase, hyphen-separated). A raw
# multi-word keyword that skipped slugifying would split into a bogus
# `idea-tag-<word>` token PLUS a stray bare word carrying no `idea-tag-`
# prefix at all — a broken two-class attribute, invisible in a passing
# compile. Scanned across every rendered fixture, not just the keyword ones,
# so this also guards `sweep.html` and any future one.
python3 - test/build/*.html <<'PY' || fail=1
import re, sys

allowed = re.compile(r'^(idea|idea-box|idea-tag|idea-tag-[a-z0-9]+(-[a-z0-9]+)*)$')
bad = []
for path in sys.argv[1:]:
    h = open(path).read()
    for m in re.finditer(r'class="([^"]*)"', h):
        tokens = m.group(1).split()
        # Only an attribute that is ALREADY one of a note's own class lists —
        # `class="idea idea-tag-.."`, `class="idea-box idea-tag-.."`,
        # `class="idea-tag idea-tag-.."` (a permalink pill) — is in scope; an
        # unrelated attribute (this fixture's own `kw-row` spans, say) never
        # carries an `idea`/`idea-tag`/`idea-tag-` token at all.
        if not any(t in ("idea", "idea-box", "idea-tag") or t.startswith("idea-tag-") for t in tokens):
            continue
        for token in tokens:
            if not allowed.match(token):
                bad.append((path, m.group(1), token))

if bad:
    for path, cls, token in bad:
        print(f'FAIL: {path}: stray class token {token!r} in class="{cls}" — '
              f'a keyword with a space that was not slugified splits an '
              f'`idea-tag-` class exactly like this')
    sys.exit(1)
print("  no stray idea-tag- class tokens")
PY

if [ "$fail" -eq 0 ]; then echo "sweep OK"; else echo "sweep FAILED"; exit 1; fi
