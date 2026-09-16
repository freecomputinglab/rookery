---
id: rk-stop-the-search-list-scrolling-sideways-7b3de613
short-id: 7b3
title: Stop the search list scrolling sideways
priority: 3
labels:
- fix-search-list-overflow
deps: []
closed: true
---
Touches: search/0.1.0/src/search.css, search/0.1.0/test/browser/modal.mjs

The search modal (`@rookery/search`) is a two-pane dialog: a scrollable list of
hits on the left, a preview of the selected hit on the right. The left pane,
`.rookery-search-list`, can end up **horizontally scrollable** when a hit has a
long title, a long bracketed id, or a long tag name. It should never scroll
sideways — the pane is a fixed grid track and its content must be contained
inside it.

## Why it happens

At `search/0.1.0/src/search.css:460-466`, `.rookery-search-list` sets
`overflow-y: auto` and nothing else about overflow. There is no `overflow-x`
and no wrapping rule, so a run of content wider than the track produces a
horizontal scrollbar instead of wrapping or being clipped.

The content inside a row cannot shrink on its own:

- `search/0.1.0/src/row.js:36-126` builds each row as
  `<a class="rookery-search-row">` containing `<span class="rookery-search-title">`,
  a `<wbr>`, `<span class="rookery-search-id">`, and optionally
  `<span class="rookery-search-tags">` holding `.rookery-search-tag` chips.
- `.rookery-search-id` is `white-space: nowrap` (`search.css:241-245`) and is
  joined to the title with no space, only a `<wbr>`. So the title+id run has
  exactly one break opportunity.
- `.rookery-search-tag` chips are `white-space: nowrap` (`search.css:327-337`).
  `.rookery-search-tags` is `flex-wrap: wrap` (`search.css:270-275`), which
  lets a chip move to the next line but does not stop one over-wide chip from
  stretching the row.
- `.rookery-search-row` is `display: block` (`search.css:217-222`) with no
  overflow or wrapping rule.
- Nothing between the row and the list clamps width.

The grid parent is already correct and must not be changed:
`.rookery-search-panes` at `search.css:449-458` uses
`grid-template-columns: minmax(0, 2fr) minmax(0, 3fr)` precisely so a long
token cannot widen a track. That containment stops at the pane; it is not
carried down inside the list.

The right-hand pane already solves the same problem the way this bird should:
`.rookery-search-preview` (`search.css:468-479`) sets
`overflow-wrap: anywhere`. Apply the equivalent treatment to the list.

## Approach, already decided

Break long content rather than clipping it. `text-overflow: ellipsis` was
considered and rejected: it requires `white-space: nowrap` plus
`overflow: hidden` on a single-line box, which would hide the second line of
tags and conflict with `.rookery-search-tags`'s wrapping, and it would silently
truncate the match-highlighted part of a title that the user is scanning for.
Wrapping matches what `.rookery-search-preview` already does and keeps every
character visible.

## Steps

1. In `search/0.1.0/src/search.css`, in the `.rookery-search-list` rule at
   lines 460-466, add `overflow-x: hidden;` alongside the existing
   `overflow-y: auto;`. This is the backstop: even if some future row content
   is unbreakable, the pane cannot scroll sideways.

2. In the same file, in the `.rookery-search-row` rule at lines 217-222, add
   `overflow-wrap: anywhere;`. This makes a long unbroken title word or a long
   id break inside itself instead of forcing the row wide, mirroring
   `.rookery-search-preview` at line 475.

3. In the same file, in the `.rookery-search-tag` rule at lines 327-337, keep
   `white-space: nowrap` but add `max-width: 100%;` and
   `overflow-wrap: anywhere;` so a single over-long tag name breaks rather than
   stretching its row. Do NOT remove the `nowrap`: the comment at lines 631-641
   explains it exists so a hyphenated or dotted tag term reads as one unit, and
   `max-width: 100%` with `overflow-wrap: anywhere` is what lets an
   exceptionally long chip still fit.

4. Add a comment to the `.rookery-search-list` rule, in the register the rest
   of the file uses: say why the pane scrolls vertically only, and cross-
   reference `.rookery-search-panes`'s `minmax(0, …)` tracks as the outer half
   of the same containment. Follow `CLAUDE.md`'s comment rules — present tense,
   no history, no bird id, and no comment that merely restates the property
   under it.

5. Add a regression assertion to `search/0.1.0/test/browser/modal.mjs`. Open
   the modal, type a query that yields at least one hit, then assert the list
   pane does not overflow horizontally:

   ```js
   const overflows = await page.evaluate(() => {
     const list = document.querySelector(".rookery-search-list");
     return list.scrollWidth > list.clientWidth;
   });
   ```

   and fail if `overflows` is true. Match the file's existing helper and
   assertion style — read the surrounding cases first and reuse whatever they
   use to open the dialog and wait for rendered rows; do not introduce a new
   test helper or a new assertion library. No existing test in `modal.mjs` or
   `search/0.1.0/test/selection.test.mjs` touches layout or scroll, so nothing
   currently passing should break.

   Note: the page in this suite is the built demo, and its fixture notes may
   not contain a title or tag long enough to have triggered the bug. If the
   assertion passes before the CSS change too, that is expected — keep it as a
   regression guard and say so in the report; do not fabricate a fixture note
   just to make it fail first.

## Non-goals

- Do not change `.rookery-search-panes` (`search.css:449-458`). Its grid track
  sizing is already correct and load-bearing.
- Do not change the DOM that `search/0.1.0/src/row.js` builds — no new wrapper
  elements, no truncating the title in JS, no removing the `<wbr>`.
- Do not touch the dropdown variant's rules (`.rookery-search-tags` at
  `search.css:262-264` is `display: none` there); this is about the modal's
  list pane only.
- Do not add `text-overflow: ellipsis` anywhere.
- Do not create a new version directory. This is a fix to the shipped
  `search/0.1.0`.
- Do not add a changelog entry — the package has none.

## VERIFY

1. The package builds: `cd search/0.1.0 && just build`
2. Build the demo the browser suite needs:
   `cd search/0.1.0/demo/rheo && just check`
3. The modal browser suite passes, including the new assertion:
   `node search/0.1.0/test/browser/modal.mjs`
4. The selection unit test still passes:
   `node search/0.1.0/test/selection.test.mjs`
5. `search/0.1.0/src/search.css` contains `overflow-x: hidden` inside the
   `.rookery-search-list` rule and `overflow-wrap: anywhere` inside the
   `.rookery-search-row` rule.