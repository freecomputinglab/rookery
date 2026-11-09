#!/usr/bin/env bash
# Asserts on this demo's output — the fixture for `citations: "notes"`
# (template.typ). Greps/python, no test framework, for the same reason
# `demo/sidenotes/check.sh` gives.
set -euo pipefail
cd "$(dirname "$0")"
H=build/html
fail=0
note() { echo "FAIL: $*"; fail=1; }

[ -f "$H/index.html" ] || note "no $H/index.html"
[ -f "$H/ideas/citing-note.html" ] || note "no $H/ideas/citing-note.html"

python3 - "$H/index.html" "$H/ideas/citing-note.html" <<'NOTES' || fail=1
import re, sys
bad = 0

def extract_span(h, start):
    # A balanced-tag scan for one `<span>`, borrowed from
    # `demo/sidenotes/check.sh`: a sidenote nests a number span and, for a
    # promoted citation, the reference link, so a plain non-greedy regex
    # stops at the first nested `</span>` instead of the sidenote's own.
    i = h.index(">", start) + 1
    depth = 1
    j = i
    while depth > 0:
        nxt_open = h.find("<span", j)
        nxt_close = h.find("</span>", j)
        if nxt_close == -1:
            break
        if nxt_open != -1 and nxt_open < nxt_close:
            depth += 1
            j = nxt_open + 5
        else:
            depth -= 1
            j = nxt_close + 7
    return h[start:j]

def sidenotes_in(h):
    return [
        extract_span(h, m.start())
        for m in re.finditer(r'<span class="idea-sidenote" id="sn-\d+-\d+" data-rookery="sidenote">', h)
    ]

for path in sys.argv[1:]:
    h = open(path).read()

    # (a) No native Typst footnote anywhere — the whole point of promoting a
    # citation is that it never mints one of these under a note-class CSL.
    if 'role="doc-noteref"' in h:
        print(f"FAIL: {path} carries a role=\"doc-noteref\" — a citation minted "
              f"a native footnote instead of being promoted")
        bad = 1
    if 'role="doc-endnotes"' in h:
        print(f"FAIL: {path} carries a role=\"doc-endnotes\" section")
        bad = 1

    # (b) The mode marker names "notes" — `citations: auto` resolved through
    # the built-in note-style list (template.typ).
    modes = re.findall(r'data-rookery-citations="(\w+)"', h)
    if modes != ["notes"]:
        print(f"FAIL: {path} has data-rookery-citations={modes!r}, expected exactly [\"notes\"]")
        bad = 1

    # (c) Every fn-ref sits immediately before its own sidenote — the same
    # structural check `demo/sidenotes/check.sh` makes.
    fn_refs = re.findall(r'<sup class="idea-fn-ref" id="fnref-(\d+-\d+)"', h)
    pairs = re.findall(
        r'<sup class="idea-fn-ref" id="fnref-(\d+-\d+)" data-rookery="fn-ref">'
        r'<a href="#fn-\1">\w+</a></sup>'
        r'<span class="idea-sidenote" id="sn-\1" data-rookery="sidenote">',
        h,
    )
    if len(pairs) != len(fn_refs):
        print(f"FAIL: {path} has {len(fn_refs)} fn-ref marker(s) but only {len(pairs)} sit "
              f"immediately before their own sidenote")
        bad = 1

    # (e) No `sidenote-refs` span anywhere — a promoted citation footnote
    # already IS the full reference, so it gets no trailing block of its own.
    if 'data-rookery="sidenote-refs"' in h:
        print(f"FAIL: {path} carries a data-rookery=\"sidenote-refs\" span, expected none "
              f"under citations: \"notes\"")
        bad = 1

# (c continued) citing-note's sidenotes: two fn-ref/sidenote pairs, one of
# them naming Smith (the promoted citation), the plain footnote untouched.
citing = open("build/html/ideas/citing-note.html").read()
sidenotes = sidenotes_in(citing)
if len(sidenotes) != 2:
    print(f"FAIL: citing-note.html has {len(sidenotes)} sidenote(s), expected 2")
    bad = 1
elif sum("Smith" in s for s in sidenotes) != 1:
    print("FAIL: citing-note.html's sidenotes do not carry exactly one mention of Smith")
    bad = 1

# (d) supplement-note's sidenote carries the supplement.
index = open("build/html/index.html").read()
supp_start = index.find('id="idea:supplement-note"')
supp_html = index[supp_start:index.find("</figure>", supp_start)]
if re.search(r"p\.\s*9", supp_html) is None:
    print("FAIL: supplement-note's sidenote does not carry the \"p. 9\" supplement")
    bad = 1

# (e continued) footnote-cite-note's sidenote carries Smith exactly once —
# its own footnote's inline citation, rendered full-form with no extra
# trailing references block.
fc_start = index.find('id="idea:footnote-cite-note"')
fc_html = index[fc_start:index.find("</figure>", fc_start)]
fc_sidenotes = sidenotes_in(fc_html)
if len(fc_sidenotes) != 1 or fc_sidenotes[0].count("Smith") != 1:
    print(f"FAIL: footnote-cite-note's sidenote does not name Smith exactly once")
    bad = 1

if not bad:
    print("  notes: no native footnote or endnotes section survives, every page's mode marker "
          "names \"notes\", every fn-ref sits beside its own sidenote, no sidenote-refs span "
          "appears, a supplement rides through to its footnote, and a citation inside an "
          "author's own footnote renders full-form exactly once with no promotion of its own")
sys.exit(bad)
NOTES

if [ "$fail" -ne 0 ]; then
    echo "demo/notes FAILED"
    exit 1
fi
echo "demo/notes OK"
