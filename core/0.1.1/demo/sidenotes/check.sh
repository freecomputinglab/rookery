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

# (a) `margin-note`'s own card lands on index.html with exactly one sidenote
# block, carrying the four FOOTNOTE sidenotes 1, 2, 3, 4 (the fourth's body
# itself cites @lamport1994) — the fixture for the "which rendering is this
# footnote's" ambiguity a shared counter would get wrong.
#
# (b) Every `<sup ... data-rookery="fn-ref">` is IMMEDIATELY followed by its
# `data-rookery="sidenote"` span — checked by requiring the SAME ids appear
# back to back in one match, not just present somewhere on the page.
#
# (c) `data-rookery="footnotes"` (the vertical block) appears nowhere except
# the `no-gutter` card and `host-note`'s `#window` transclusion of
# `margin-note` — the two places horizontal mode falls back to it on purpose.
#
# (d) `host-note`'s `#window` transclusion carries NO sidenote at all, a
# `data-rookery="footnotes"` block with the same four items as margin-note's
# own card, and a VISIBLE `data-rookery="references"` div — a transcluded
# body always renders vertically, whatever the document's mode.
#
# (e) A margin CITATION note (`data-rookery-cite="cite"`) exists and names
# Knuth — the third paragraph's bare `@knuth1984`.
#
# (f) No margin citation note names Lamport: `@lamport1994` is cited inside
# the fourth footnote, so its full reference sits inline in that footnote's
# own sidenote rather than spawning a second, separate margin note.
#
# (g) A `data-rookery="references"` div carries `hidden` — the block Typst's
# positional partitioning still requires is present but not shown — for
# margin-note's OWN card, unlike the window's.
python3 - "$H/index.html" "$H/ideas/margin-note.html" "$H/ideas/host-note.html" <<'SIDENOTES' || fail=1
import re, sys
bad = 0

def extract_div(h, start):
    # A naive balanced-tag scan: counts nested "<div" against "</div>" from
    # the opening tag's own ">" to find where IT closes, good enough for this
    # fixture's markup (no "<div" text appears inside an attribute value).
    i = h.index(">", start) + 1
    depth = 1
    j = i
    while depth > 0:
        nxt_open = h.find("<div", j)
        nxt_close = h.find("</div>", j)
        if nxt_close == -1:
            break
        if nxt_open != -1 and nxt_open < nxt_close:
            depth += 1
            j = nxt_open + 4
        else:
            depth -= 1
            j = nxt_close + 6
    return h[start:j]

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
        if sorted(ns) != [1, 2, 3, 4]:
            print(f"FAIL: {path} block {b} has sidenotes numbered {sorted(ns)}, expected [1, 2, 3, 4]")
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

    # A `data-rookery="footnotes"` block is legitimate in two places: the
    # `no-gutter` card (`display-right-gutter: false` falls it back to the
    # vertical block on purpose) and a `data-rookery="window"` transclusion
    # (always vertical regardless of the document's mode). Every other
    # occurrence is the bug this mode exists to avoid — checked by walking
    # backward from each hit to the nearest enclosing opening tag, box or
    # window, and requiring that ancestor to be one of the two.
    box_open = list(re.finditer(r'<div class="idea-box[^>]*data-rookery="box"[^>]*>', h))
    window_open = list(re.finditer(r'<div class="[^"]*"[^>]*data-rookery="window"[^>]*>', h))
    for m in re.finditer(r'data-rookery="footnotes"', h):
        card = None
        for b in box_open:
            if b.start() <= m.start():
                card = b
            else:
                break
        win = None
        for w in window_open:
            if w.start() <= m.start():
                win = w
            else:
                break
        in_window = win is not None and (card is None or win.start() > card.start())
        if in_window:
            continue
        if card is None or 'data-rookery-gutter="off"' not in card.group(0):
            print(f"FAIL: {path} carries a data-rookery=\"footnotes\" block outside the "
                  f"no-gutter card or a window — horizontal mode must not emit one anywhere else")
            bad = 1

    if path.endswith("/index.html"):
        # `host-note`'s window transclusion of `margin-note`: no sidenote,
        # its own vertical Footnotes block matching margin-note's four
        # footnotes, and a References div that is NOT hidden — the opposite
        # of margin-note's own card, checked below.
        win_m = re.search(r'<div class="[^"]*"[^>]*data-rookery="window"[^>]*>', h)
        if win_m is None:
            print(f"FAIL: {path} has no data-rookery=\"window\" element for host-note's transclusion")
            bad = 1
        else:
            window_html = extract_div(h, win_m.start())
            if 'data-rookery="sidenote"' in window_html:
                print(f"FAIL: {path}'s window transclusion carries a sidenote — "
                      f"a transcluded body must render vertically")
                bad = 1
            fn_items = re.findall(r'data-rookery="footnote"', window_html)
            if len(fn_items) != 4:
                print(f"FAIL: {path}'s window transclusion has {len(fn_items)} Footnotes "
                      f"list item(s), expected 4")
                bad = 1
            win_refs = re.search(
                r'<div (?=[^>]*data-rookery="references")[^>]*>', window_html,
            )
            if win_refs is None:
                print(f"FAIL: {path}'s window transclusion has no data-rookery=\"references\" div")
                bad = 1
            elif 'hidden="hidden"' in win_refs.group(0):
                print(f"FAIL: {path}'s window transclusion's References div is hidden — "
                      f"it should be the only visible one on the page")
                bad = 1

        if len(blocks) != 1:
            print(f"FAIL: {path} has {len(blocks)} sidenote block(s), expected exactly "
                  f"margin-note's own card — its #window transclusion carries no sidenote at all")
            bad = 1

        cite_spans = re.findall(
            r'<span class="[^"]*" data-rookery="sidenote" data-rookery-cite="cite">(.*?)</span>', h, re.S,
        )
        if not any("Knuth" in s for s in cite_spans):
            print(f"FAIL: {path} has no margin citation note naming Knuth")
            bad = 1
        if any("Lamport" in s for s in cite_spans):
            print(f"FAIL: {path} has a margin citation note naming Lamport — it should stay inline "
                  f"inside its footnote's own sidenote instead")
            bad = 1

        # Attribute order aside, require BOTH `data-rookery="references"` and
        # `hidden="hidden"` on the same div — margin-note's OWN card's block,
        # distinct from the window's (checked visible, above).
        refs_hidden = re.search(
            r'<div (?=[^>]*data-rookery="references")(?=[^>]*hidden="hidden")[^>]*>', h,
        )
        if refs_hidden is None:
            print(f"FAIL: {path} has no hidden data-rookery=\"references\" div")
            bad = 1
if not bad:
    print("  sidenotes: margin-note's card carries four sidenotes each immediately after its own "
          "marker, plus a Knuth margin citation, no Lamport margin citation, and a hidden References "
          "block; host-note's #window of it carries no sidenote, its own vertical Footnotes block, "
          "and a visible References div; no Footnotes block appears anywhere else")
sys.exit(bad)
SIDENOTES

if [ "$fail" -ne 0 ]; then
    echo "demo/sidenotes FAILED"
    exit 1
fi
echo "demo/sidenotes OK"
