---
id: rk-document-tagged-window-backlinks-fbd47327
short-id: fbd
title: Document tagged-window backlinks
priority: 2
labels:
- fix-tag-window-backlinks
deps:
- blocked-by:rk-backlink-tag-selected-windows-per-page-e99edead
- blocked-by:rk-backlink-tag-selected-windows-per-note-9f632f19
closed: true
---
`core/0.1.0/readme.md` never documents how a tag-selected `#window` behaves in
the backlink graph, even though `src/window.typ` claims it does. Two sibling
birds have just changed that behaviour, so the readme has to state the new rule —
and the false cross-reference has to go either way.

Touches: core/0.1.0/readme.md

## The false claim, and why it is worth fixing

```
rg -n --fixed-strings 'That asymmetry is documented in the readme' /home/lox/code/_fcl/rookery/core
```

One hit as of filing, in `src/window.typ` (around line 225, inside the long
comment above the `<rookery-window-mark>` marker). It points a reader at a readme
section that does not exist:

```bash
grep -n -i 'tag' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md | grep -i backlink
```

prints nothing as of filing. A comment that sends a reader to documentation that
was never written costs more than no comment at all.

NOTE: the sibling bird that changed `src/window.typ` was asked to rewrite that
whole paragraph, including this sentence. If the anchor above returns no hit,
that bird already removed it — that is the expected case, not a problem. Check
what the paragraph says now and make the readme agree with it; do not restore the
sentence.

## What is true after the sibling birds land

Both siblings are prerequisites of this bird, so both have landed when it flies.
The rule to document, in full:

- `#window(<named>)` counts as a link to `named`, as it always has.
- `#window(tagged: "phd")` NOW counts as a link to every note the selection
  matched — from the page the window sits on, and from the enclosing note when
  the window is written inside one.
- `#window(tagged: "phd", filter: ..)` counts as a link to NOTHING, and neither
  does `#window(filter: ..)` on its own. `filter:` is a function; no marker can
  carry one, and `tagged:` and `filter:` are ANDed — so resolving the tag half
  alone would announce backlinks from notes the window never showed. A missing
  backlink is a smaller wrong than a fabricated one.
- `backlink: false` still suppresses all of it, tag selection included.

## Steps

1. Document the rule in the `backlink:` section.

   ```
   rg -n --fixed-strings 'What it does NOT do: stop the marker being emitted' /home/lox/code/_fcl/rookery/core
   ```

   One hit, `readme.md:641` as of filing, inside the section headed
   `### `backlink:` — a view is not a reference` (that heading is the landmark).
   Add a short subsection there — three or four sentences plus a small example —
   stating the four bullets above. Keep the existing reader table intact; it is
   still correct.

   Say WHY `filter:` is excluded, not merely that it is. A reader who does not
   know that `tagged:` and `filter:` are ANDed will read the exclusion as an
   oversight and file it as a bug.

2. Cross-reference it from the `tagged:`/`filter:` argument documentation.

   ```
   rg -n --fixed-strings 'Tag and filter selection are always rookery-wide' /home/lox/code/_fcl/rookery/core
   ```

   One hit, `readme.md:1242` as of filing, in the `#window` argument reference,
   two paragraphs below the `filter:` description. Add one sentence after that
   paragraph pointing at the section from step 1 — a reader deciding between
   `tagged:` and `filter:` should learn there that the choice also decides whether
   the window registers a backlink.

3. Make `src/window.typ`'s comment and the readme agree.

   Read the paragraph above the marker in `src/window.typ` (search for
   `rookery-window-mark`). If it still contains a sentence claiming the asymmetry
   is documented in the readme, replace that sentence with an accurate pointer to
   the section you wrote in step 1. If the sibling bird already rewrote it,
   change nothing in that file and say so in your report.

## Non-goals

- Do NOT change any behaviour, in any `.typ` file. This bird is prose, plus at
  most one sentence of comment in `src/window.typ`.
- Do NOT document a way to make `filter:` windows backlink. There isn't one.
- Do NOT rewrite the `backlink:` section's existing reader table or its
  `_page-outbound` paragraph — both are still accurate.
- Do NOT bump the package version or add a changelog entry unless the repo
  already keeps one for prose changes; check before assuming.

## VERIFY

1. The readme states the new rule. Grep a short fragment, not a sentence — a
   sentence may be correctly re-wrapped across two lines:

   ```bash
   grep -n -i 'filter' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md | grep -i backlink
   ```

   Must print at least one line, in the `backlink:` section.

2. The package still compiles — prose changes should not break it, and this
   proves nothing was edited by accident:

   ```bash
   cd /home/lox/code/_fcl/rookery/core/0.1.0 && just test
   ```

   Expect `units OK`.

3. No dangling claim remains:

   ```bash
   rg -n --fixed-strings 'That asymmetry is documented in the readme' /home/lox/code/_fcl/rookery/core
   ```

   Must print nothing.