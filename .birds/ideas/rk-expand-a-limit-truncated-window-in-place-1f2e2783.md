---
id: rk-expand-a-limit-truncated-window-in-place-1f2e2783
short-id: 1f2
title: Expand a limit-truncated window in place
priority: 3
labels:
- feat-window-expand-in-place
deps: []
closed: false
---
A `#window(.., limit: n)` truncates the transcluded body to its first `n`
blocks, appends a grey ` ... `, and throws the rest away. A reader who wants the
whole note has to leave for the note's own page. Make the truncated window
expandable where it stands: the shown blocks become the click target of a second
disclosure nested inside the window body, and clicking them — or the ellipsis —
unfurls the remainder in place.

The motivating site is `rookery.ohrg.org`'s package shelf
(`content/packages/index.typ`), which windows nine package notes with `limit: 1`
so each reads as a name plus a one-sentence overview.

Touches: core/0.1.0/src/pure.typ, core/0.1.0/src/window.typ, core/0.1.0/src/transclusion.typ, core/0.1.0/src/core.css, core/0.1.0/test/units.typ, core/0.1.0/demo/rheo/check.sh

All paths below are relative to the REPO ROOT and resolve inside your flight
path, not the nest. Run every `rg` from the flight root.

## Decisions already made — do not re-derive

**Native `<details>`, no JavaScript.** `core` is one of the five pure-Typst
packages in this repo (no `package.json`, no build step), and the window
disclosure it already draws is a native `<details>`/`<summary>` pair. The
expansion is a SECOND `<details>`, nested inside the window body. There is no
nested-`<details>` precedent in `src/` today — `rg -F '"details"' core/0.1.0/src`
has exactly one hit — so you are adding the first.

**The preview goes inside the new `<summary>`.** That is what makes "click
anywhere in the shown body" work with no script: a `<summary>` is the only
element a `<details>` toggles from. HTML's content model for `<summary>` is
phrasing content, and paragraphs inside one are tolerated by every current
browser as long as the summary itself is `display: block` (step 5), which is why
that rule is not optional. An `<a>` inside a `<summary>` still navigates on its
own click rather than toggling, so links in the preview keep working — the same
property the window's outer summary already relies on for its permalink.

**Truncation must now yield BOTH halves.** `_truncate` currently returns only
the kept blocks with the ellipsis already baked in, so the tail is unrecoverable
by the time any renderer sees it. Add one splitting helper and express
`_truncate` in terms of it, rather than slicing blocks in two places — the
comment above `_truncate` says in as many words that it exists so the three call
sites cannot drift.

**`#idea-body` is NOT in scope.** It renders a note's body with no chrome by
design (no summary, no disclosure) for consumers such as `@rookery/search`'s
preview pane, and it must keep truncating exactly as it does today.

**Paged targets keep the hard truncation.** `readme.md` promises `limit:`
truncates "in every target, not just HTML", and a paged target has nothing to
click. The paged arm therefore renders the shown blocks plus the same grey
ellipsis it renders now, and never the tail.

**The partially-expanded window keeps the folded background.** Today the fold
tint (`--idea-fold-color`) is painted on the summary of a CLOSED window only. A
window showing a preview is in the same "there is more behind this" state, so it
carries the same tint, and loses it once expanded (step 6).

## Steps

Every site is found by its anchor; the line numbers are where each stood when
this was filed, and a site that has moved a few lines is the expected case, not
a broken bird. If an anchor prints nothing, widen to `rg -Fn '<anchor>'` at the
repo root, and report upward rather than guessing if it is still gone.

1. **Split the truncation.** `rg -Fn '#let _truncate(body, limit)'
   core/0.1.0/src` — one hit, `src/pure.typ:756`. Immediately above it sits the
   comment block headed "The ONE `limit:` truncation". Add a new helper beside
   it, `_truncate-split(body, limit)`, returning a dictionary
   `(shown: <content>, rest: <content or none>)`:
   - `limit == none` → `(shown: body, rest: none)`.
   - otherwise `let bs = _blocks(body)`; if `bs.len() <= limit` →
     `(shown: body, rest: none)`.
   - otherwise → `(shown: bs.slice(0, limit).join(parbreak()), rest:
     bs.slice(limit).join(parbreak()))`.
   `shown` carries NO ellipsis: the ellipsis is now the caller's affordance.
   Then rewrite `_truncate` itself as a thin wrapper over it — take the split,
   return `shown` when `rest == none`, else `shown + [#text(gray)[ ... ]]` — so
   one implementation slices blocks and `_truncate`'s existing behaviour is
   bit-for-bit what it was. `_truncate-split` must be defined BEFORE `_truncate`
   in the file: a `#let` closure captures the scope visible at definition time,
   which the header comment of `pure.typ` spells out.

2. **Thread the tail through `#window`.** `rg -Fn 'let shown = _truncate(body,
   limit)' core/0.1.0/src` — TWO hits, and only the first is yours:
   `src/window.typ:339`, inside `#window`'s per-id loop, is the one to change;
   `src/window.typ:444`, inside `#idea-body`, must be left exactly as it is.
   Replace the first with a call to `_truncate-split`, and pass the tail to
   `_window-content` as a new named argument `rest:`. The call to change is two
   lines below, anchor `rg -Fn '#marker#_window-content(id, rec, shown'
   core/0.1.0/src` — one hit.

3. **Thread it through the nested-window rebuild too.** `rg -Fn 'let shown =
   _truncate(inner, v.limit)' core/0.1.0/src` — one hit,
   `src/transclusion.typ:452`, inside the `show figure.where(kind: WK)` rule
   that rebuilds a window nested in a transcluded body from its marker. Same
   change: `_truncate-split`, and pass `rest:` into the `_window-content(...)`
   call just below it (around line 457). A nested truncated window must be
   expandable on exactly the same terms as a top-level one.

4. **Render the expansion.** `rg -Fn '#let _window-content(id, rec, shown'
   core/0.1.0/src` — one hit, `src/transclusion.typ:103`. Add a named parameter
   `rest: none` to its signature. In the HTML/EPUB arm, the body div is built at
   the anchor `rg -Fn '_c("window-body")' core/0.1.0/src` — two hits, and yours
   is the one in `src/transclusion.typ` (around line 261), NOT the one in
   `src/window.typ` (that is `#idea-body`). Leave that div's contents exactly as
   they are when `rest == none`. When `rest != none`, its contents become a
   nested disclosure instead:
   - `<details>` with `class: _c("window-more")` and `data-rookery:
     "window-more"`.
   - Its first child a `<summary>` with `class: _c("window-more-summary")` and
     `data-rookery: "window-more-summary"`, containing `_footnoted(shown)`
     followed by a `<span>` with `class: _c("window-ellipsis")` and
     `data-rookery: "window-ellipsis"` whose text is `…`.
   - After the summary, `_footnoted(rest)`, then the references block.
   Build the references block over the WHOLE body, not over each half:
   `_refs-block(_own-cited-keys(shown + rest, windows-claim: windows-claim))`,
   placed last, inside the `<details>` so it appears with the tail. The existing
   untruncated path calls it with `shown` alone — anchor `rg -Fn
   '_own-cited-keys(shown, windows-claim: windows-claim)' core/0.1.0/src`, two
   hits, both in `src/transclusion.typ` (the HTML arm around 262 and the paged
   arm around 278). UNVERIFIED, so check it in the demo: calling `_footnoted`
   twice over disjoint halves of one body is expected to number the footnotes of
   each half correctly, but nothing in the tree does it today. If the demo shows
   duplicated or misnumbered footnotes, fall back to `_footnoted(shown + rest)`
   rendered whole inside the `<details>` with the summary carrying the plain
   `shown`, and say so in your report.

5. **Keep the paged arm truncating.** Anchor `rg -Fn 'No disclosure in a paged
   target' core/0.1.0/src` — one hit, `src/transclusion.typ:264`, the comment
   opening the `else` arm. Because `shown` no longer carries an ellipsis, that
   arm must append one itself when `rest != none`: render `shown` followed by
   `text(gray)[ ... ]`, exactly the string `_truncate` used to add, and never
   render `rest`. A paged window that was truncated must look precisely as it
   does today.

6. **Style the new disclosure.** `core/0.1.0/src/core.css`, which is unlayered
   throughout and keys every rule off `[data-rookery="…"]` attributes rather
   than the `_c()` classes — follow that. Add, near the existing window-details
   rules:
   - `[data-rookery="window-more-summary"] { display: block; cursor: pointer;
     list-style: none; }` — `display: block` is what makes paragraphs inside a
     summary lay out normally rather than collapsing onto the marker line.
   - Marker suppression for it, matching the existing pair: anchor `rg -Fn
     '::-webkit-details-marker' core/0.1.0/src/core.css` — two hits, one in a
     comment around line 845 and the rule itself at line 1015. Add
     `[data-rookery="window-more-summary"]::marker` and
     `[data-rookery="window-more-summary"]::-webkit-details-marker` to that
     rule's selector list.
   - `[data-rookery="window-ellipsis"] { color: gray; }` — the ellipsis used to
     be grey because `_truncate` wrapped it in Typst's `text(gray)`, and it must
     still read as grey now that it is an HTML span.
   - `[data-rookery="window-more"][open] [data-rookery="window-ellipsis"] {
     display: none; }` — nothing is elided once the tail is showing.

7. **Paint the partial state.** Same file. The fold tint today is painted by the
   rule at anchor `rg -Fn '[data-rookery="window-details"]:not([open]) >'
   core/0.1.0/src/core.css` — one hit, around line 990. Leave it alone and add a
   rule of your own:
   ```css
   [data-rookery="window"]:not([data-rookery-no-bg]):has([data-rookery="window-more"]:not([open])) {
     background-color: var(--idea-fold-color, rgba(0, 100, 255, 0.05));
   }
   ```
   so a window showing only its preview wears the same tint as a folded one, and
   drops it when the tail unfurls. The `:not([data-rookery-no-bg])` is
   `#window`'s `display-background: false` opt-out, and the rule is wrong
   without it — the existing hover rule at anchor `rg -Fn
   ':not([data-rookery-no-bg]):hover' core/0.1.0/src/core.css` (one hit, around
   line 784) is the precedent to copy. Write a comment above it in this file's
   register, saying why the partial state and the folded state share a tint.

8. **Unit-test the split.** `rg -Fn '_truncate — the ONE' core/0.1.0/test` — one
   hit, `test/units.typ:299`, heading the existing `_truncate` assertions (which
   must stay green, unchanged). Below them, add assertions for
   `_truncate-split`: that `limit: none` gives `rest: none`; that a limit at or
   above the block count gives `rest: none`; that a limit below it gives a
   `shown` of exactly that many blocks and a `rest` holding the remainder; and
   that `shown` contains no ellipsis. Use the same style as the block-counting
   assertions above them (`_blocks(..).len()`, `_body-plain`). Import
   `_truncate-split` alongside `_blocks` and `_truncate` in the import list at
   the top of the file — anchor `rg -Fn '_project, _split-tag-list'
   core/0.1.0/test/units.typ`, one hit.

9. **Assert the markup in the rheo demo.** `core/0.1.0/demo/rheo/` already
   exercises a truncated window: `rg -Fn '#window("w-outer", limit: 2)'
   core/0.1.0/demo` — one hit, `demo/rheo/content/sub/deeper/page.typ:44`. Add
   two greps to `demo/rheo/check.sh`, in that file's existing numbered-comment
   style, against `build/html/sub/deeper/page.html`: one asserting
   `data-rookery="window-more"` is present, one asserting
   `data-rookery="window-ellipsis"` is present.

## Do NOT

- Do NOT add JavaScript, or a `package.json`, to `core`. The mechanism is
  `<details>` and CSS or it is not this bird.
- Do NOT change `#idea-body` (`src/window.typ` around 424-466), its `_truncate`
  call, or its no-chrome rendering.
- Do NOT change what `_truncate` returns. Its three existing assertions in
  `test/units.typ` must pass untouched.
- Do NOT change `_blocks`, or how a body is divided into blocks. A preview that
  cuts mid-sentence at an apostrophe or an `@idea:` reference is a real and
  separate defect in `_blocks`'s inline classification; it is not this bird.
- Do NOT touch `readme.md`. Documenting this belongs to the bird that depends on
  this one.
- Do NOT add a new `#window` parameter. The expansion is how `limit:` renders in
  HTML and EPUB from now on, not an opt-in.

## VERIFY

1. `cd core/0.1.0 && just test` — both fixtures compile, prints `units OK`.
2. `cd core/0.1.0/demo/rheo && just check` — builds with `rheo compile .` and
   the assertion script passes, including the two new greps.
3. `rg -c 'data-rookery="window-more"'
   core/0.1.0/demo/rheo/build/html/sub/deeper/page.html` prints a non-zero
   count, and `rg -F 'idea-window-ellipsis'` on the same file hits.
4. `rg -F 'data-rookery="window-more-summary"' core/0.1.0/src/core.css` hits in
   both the display rule and the marker-suppression rule, and `rg -F
   ':has([data-rookery="window-more"]:not([open]))' core/0.1.0/src/core.css`
   hits once.
5. Open `core/0.1.0/demo/rheo/build/html/sub/deeper/page.html` in a browser:
   the `w-outer` window shows two blocks and a grey ellipsis on the fold tint;
   clicking the shown text (not only the ellipsis) unfurls the rest; the tint
   goes when it does; the ellipsis disappears; the window's own outer fold still
   toggles from its title row. Report what you saw — this is the assertion that
   matters and no grep makes it.