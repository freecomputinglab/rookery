#!/usr/bin/env bash
# Asserts on this demo's output — the fixture for `footnotes: "horizontal"`.
# `demo/rheo/check.sh` covers the vertical default; this covers the margin
# mode only, on its own small project. Greps/python, no test framework, for
# the same reason `demo/rheo/check.sh` gives.
set -euo pipefail
cd "$(dirname "$0")"
H=build/html
fail=0
note() { echo "FAIL: $*"; fail=1; }

[ -f "$H/index.html" ] || note "no $H/index.html"

# (a)/(d) `margin-note`'s own card and `host-note`'s `#window` transclusion
# of it both land on index.html, each under its own block number — the
# fixture for the "which rendering is this footnote's" ambiguity a shared
# counter would get wrong. Each block carries exactly the three sidenotes
# 1, 2, 3, and there are at least two distinct blocks.
#
# (b) Every `<sup ... data-rookery="fn-ref">` is IMMEDIATELY followed by its
# `data-rookery="sidenote"` span — checked by requiring the SAME ids appear
# back to back in one match, not just present somewhere on the page.
#
# (c) `data-rookery="footnotes"` (the vertical block) appears nowhere: this
# mode never emits it.
python3 - "$H/index.html" "$H/ideas/margin-note.html" "$H/ideas/host-note.html" <<'SIDENOTES' || fail=1
import re, sys
bad = 0
for path in sys.argv[1:]:
    try:
        h = open(path).read()
    except FileNotFoundError:
        continue

    sidenotes = re.findall(
        r'<span class="idea-sidenote" id="fn-(\d+)-(\d+)" data-rookery="sidenote">', h,
    )
    blocks = {}
    for b, n in sidenotes:
        blocks.setdefault(b, []).append(int(n))
    for b, ns in blocks.items():
        if sorted(ns) != [1, 2, 3]:
            print(f"FAIL: {path} block {b} has sidenotes numbered {sorted(ns)}, expected [1, 2, 3]")
            bad = 1

    pairs = re.findall(
        r'<sup class="idea-fn-ref" id="fnref-(\d+)-(\d+)" data-rookery="fn-ref">'
        r'<a href="#fn-\1-\2">\2</a></sup>'
        r'<span class="idea-sidenote" id="fn-\1-\2" data-rookery="sidenote">',
        h,
    )
    if len(pairs) != len(sidenotes):
        print(f"FAIL: {path} has {len(sidenotes)} sidenotes but only {len(pairs)} sit "
              f"immediately after their own fn-ref marker")
        bad = 1

    if 'data-rookery="footnotes"' in h:
        print(f"FAIL: {path} carries a data-rookery=\"footnotes\" block — horizontal mode must not emit one")
        bad = 1

    if path.endswith("/index.html"):
        if len(blocks) < 2:
            print(f"FAIL: {path} has only {len(blocks)} sidenote block(s), expected margin-note's "
                  f"own card and host-note's #window of it under different block numbers")
            bad = 1
if not bad:
    print("  sidenotes: margin-note's card and its #window replay both carry three sidenotes each, "
          "each immediately after its own marker, no Footnotes block anywhere")
sys.exit(bad)
SIDENOTES

if [ "$fail" -ne 0 ]; then
    echo "demo/sidenotes FAILED"
    exit 1
fi
echo "demo/sidenotes OK"
