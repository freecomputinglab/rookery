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

# Typst emits the SAME shape in every mode now (bib.typ/state.typ): a
# margin note beside every marker AND the bottom Footnotes block, on EVERY
# card that has footnotes — no card is special-cased to one or the other in
# the markup any more. What differs page to page is only which pair a
# reader sees, and that is core.css's call, keyed on the one
# `data-rookery="mode"` marker each page carries. So this script checks
# structure only — both blocks present and in step with each other, ids in
# the right namespace, no `hidden` attribute anywhere, one mode marker per
# page — never which one a browser would paint, which is `geom.sh`'s job.
#
# (a) Every `<sup ... data-rookery="fn-ref">` is IMMEDIATELY followed by its
# `data-rookery="sidenote"` span — checked by requiring the SAME ids appear
# back to back in one match, not just present somewhere on the page.
# Sidenote ids carry a `sn-` prefix; the Footnotes list's own `<li>` ids stay
# `fn-`, since the two must stay distinct now that both are always present.
#
# (b) For every block number found among the sidenotes, the SAME numbers
# appear in that block's Footnotes list, and vice versa — the two are
# always emitted together, so neither can drift from the other.
#
# (c) `host-note`'s `#window` transclusion of `margin-note` carries its own
# sidenotes, its own Footnotes list matching them, and a References div —
# same shape as any other card, since a window is no longer special-cased
# in the markup either (core.css hides its sidenotes and shows its blocks).
#
# (d) A margin CITATION note (`data-rookery-cite="cite"`) exists and names
# Knuth — the third paragraph's bare `@knuth1984` AND the blockquote's own
# bare `@knuth1984`, twice per rendering of margin-note's body (its own
# card, and again inside host-note's `#window` of it: 4 on index.html).
# Lamport (`@lamport1994`) is cited INSIDE the fourth footnote's own body,
# so it appears twice per rendering — once in that footnote's sidenote, once
# more where the Footnotes list repeats the same footnote body — 4 on
# index.html, none of them a second, SEPARATE margin note spawned outside
# the footnote's own.
#
# (e) No `data-rookery="references"` div anywhere carries `hidden` — Typst
# never sets it now; only core.css ever hides that block.
#
# (f) Exactly one `data-rookery="mode"` marker per page, naming this
# project's `data-rookery-footnotes="horizontal"` choice.
python3 - "$H/index.html" "$H/ideas/margin-note.html" "$H/ideas/host-note.html" "$H/ideas/no-gutter.html" <<'SIDENOTES' || fail=1
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
        r'<span class="idea-sidenote" id="sn-(\d+)-(\d+)" data-rookery="sidenote">', h,
    )
    sn_blocks = {}
    for b, n in sidenotes:
        sn_blocks.setdefault(b, []).append(int(n))

    fn_items = re.findall(
        r'<li class="idea-footnote" id="fn-(\d+)-(\d+)" data-rookery="footnote">', h,
    )
    fn_blocks = {}
    for b, n in fn_items:
        fn_blocks.setdefault(b, []).append(int(n))

    # (b) Every sidenote block has a matching Footnotes list, and vice versa.
    if {k: sorted(v) for k, v in sn_blocks.items()} != {k: sorted(v) for k, v in fn_blocks.items()}:
        print(f"FAIL: {path} sidenote blocks {sn_blocks} do not match Footnotes-list blocks {fn_blocks}")
        bad = 1

    # (a) Every fn-ref sits immediately before its own sidenote.
    pairs = re.findall(
        r'<sup class="idea-fn-ref" id="fnref-(\d+)-(\d+)" data-rookery="fn-ref">'
        r'<a href="#fn-\1-\2">\2</a></sup>'
        r'<span class="idea-sidenote" id="sn-\1-\2" data-rookery="sidenote">',
        h,
    )
    if len(pairs) != len(sidenotes):
        print(f"FAIL: {path} has {len(sidenotes)} sidenotes but only {len(pairs)} sit "
              f"immediately after their own fn-ref marker")
        bad = 1

    # (e) No hidden References div anywhere.
    for m in re.finditer(r'<div [^>]*data-rookery="references"[^>]*>', h):
        if 'hidden="hidden"' in m.group(0):
            print(f"FAIL: {path} has a hidden data-rookery=\"references\" div — "
                  f"Typst must never set `hidden` now, only core.css")
            bad = 1

    # (f) Exactly one mode marker, naming horizontal.
    modes = re.findall(r'<div data-rookery="mode" data-rookery-footnotes="(\w+)" hidden="hidden">', h)
    if len(modes) != 1:
        print(f"FAIL: {path} has {len(modes)} data-rookery=\"mode\" marker(s), expected exactly 1")
        bad = 1
    elif modes[0] != "horizontal":
        print(f"FAIL: {path}'s mode marker says {modes[0]!r}, expected \"horizontal\"")
        bad = 1

    # (g) A minted note page (`ideas/<slug>.html`) wraps its body and its
    # own References block in exactly one `[data-rookery="page-body"]`
    # element, and that element's Footnotes block is INSIDE it — the own
    # card standing core.css needs to show margin notes on the page at all.
    if path.endswith("/ideas/margin-note.html"):
        page_body_ms = list(re.finditer(r'<div class="[^"]*" data-rookery="page-body">', h))
        if len(page_body_ms) != 1:
            print(f"FAIL: {path} has {len(page_body_ms)} data-rookery=\"page-body\" element(s), "
                  f"expected exactly 1")
            bad = 1
        else:
            page_body_html = extract_div(h, page_body_ms[0].start())
            if 'data-rookery="footnotes"' not in page_body_html:
                print(f"FAIL: {path}'s data-rookery=\"page-body\" element carries no "
                      f"data-rookery=\"footnotes\" block")
                bad = 1

    if path.endswith("/index.html"):
        # (c) `host-note`'s window transclusion of `margin-note`: its own
        # sidenotes, its own Footnotes list matching them, and a References
        # div — the same shape any other card gets now.
        win_m = re.search(r'<div class="[^"]*"[^>]*data-rookery="window"[^>]*>', h)
        if win_m is None:
            print(f"FAIL: {path} has no data-rookery=\"window\" element for host-note's transclusion")
            bad = 1
        else:
            window_html = extract_div(h, win_m.start())
            if 'data-rookery="sidenote"' not in window_html:
                print(f"FAIL: {path}'s window transclusion carries no sidenote")
                bad = 1
            win_fn_items = re.findall(r'data-rookery="footnote"', window_html)
            if len(win_fn_items) != 6:
                print(f"FAIL: {path}'s window transclusion has {len(win_fn_items)} Footnotes "
                      f"list item(s), expected 6")
                bad = 1
            if 'data-rookery="references"' not in window_html:
                print(f"FAIL: {path}'s window transclusion has no data-rookery=\"references\" div")
                bad = 1

        # `index.html` carries three blocks with footnotes — margin-note's
        # own card, host-note's window transclusion of it, and no-gutter's
        # card — two matching margin-note's four notes and one matching
        # no-gutter's single note. Which block number lands on which is an
        # implementation detail of a document-wide counter, so this checks
        # the multiset of shapes rather than a specific id.
        shapes = sorted(sorted(v) for v in sn_blocks.values())
        if shapes != [[1], [1, 2, 3, 4, 5, 6], [1, 2, 3, 4, 5, 6]]:
            print(f"FAIL: {path} has sidenote blocks shaped {shapes}, expected one "
                  f"single-note block (no-gutter) and two six-note blocks "
                  f"(margin-note's own card and host-note's window transclusion of it, each "
                  f"carrying the blockquote's and the list item's own footnotes too)")
            bad = 1

        cite_spans = re.findall(
            r'<span class="[^"]*" data-rookery="sidenote" data-rookery-cite="cite">(.*?)</span>', h, re.S,
        )
        knuth = [s for s in cite_spans if "Knuth" in s]
        if len(knuth) != 4:
            print(f"FAIL: {path} has {len(knuth)} margin citation note(s) naming Knuth, expected 4 "
                  f"— two per rendering of margin-note's body (the bare citation and the "
                  f"blockquote's), across its own card and host-note's #window")
            bad = 1
        lamport = [s for s in cite_spans if "Lamport" in s]
        if len(lamport) != 4:
            print(f"FAIL: {path} has {len(lamport)} margin citation note(s) naming Lamport, expected 4 "
                  f"— two per rendering (the fourth footnote's own sidenote, and its repeat in that "
                  f"rendering's Footnotes list)")
            bad = 1
if not bad:
    print("  sidenotes: every sidenote block matches its Footnotes list, sidenotes sit immediately "
          "after their own marker, host-note's #window of margin-note carries its own sidenotes and "
          "Footnotes list, the Knuth and Lamport margin citations appear the right number of times per "
          "margin-note's body with Lamport's nested inside its footnote, no References div is ever "
          "hidden, every page carries exactly one horizontal mode marker, and the minted margin-note "
          "page wraps its body and Footnotes block in exactly one data-rookery=\"page-body\" element")
sys.exit(bad)
SIDENOTES

if [ "$fail" -ne 0 ]; then
    echo "demo/sidenotes FAILED"
    exit 1
fi
echo "demo/sidenotes OK"
