---
id: rk-document-the-expandable-truncated-window-e845287b
short-id: e8
title: Document the expandable truncated window
priority: 2
labels:
- feat-window-expand-in-place
deps:
- blocked-by:rk-expand-a-limit-truncated-window-in-place-1f2e2783
closed: false
---
The bird this one depends on changes what `limit:` renders: in HTML and EPUB a
truncated `#window` becomes expandable where it stands — the shown blocks and
the ellipsis are the click target of a second disclosure nested inside the
window body, and clicking them unfurls the rest of the note without leaving the
page. `readme.md` still describes the old behaviour, in which the tail was
simply discarded. Bring the readme up to what the package does.

Touches: core/0.1.0/readme.md

Paths are relative to the REPO ROOT and resolve inside your flight path, not the
nest. Run every `rg` from the flight root.

## What actually changed, so you need not read the source

1. In HTML and EPUB, a `#window(.., limit: n)` renders the first `n` blocks
   followed by a grey ellipsis, all of it inside a `<summary>`, with the
   remaining blocks inside the `<details>` it opens. Clicking anywhere in the
   shown blocks, or on the ellipsis, unfurls the rest in place. The ellipsis
   disappears once it has.
2. This nests INSIDE the window's own fold. A folded window still opens from its
   title row to reveal the preview; the preview then opens to reveal the rest.
   `folded:` and `limit:` stay orthogonal, exactly as the readme already says.
3. While a window is showing only its preview it keeps the fold tint
   (`--idea-fold-color`) it wears when closed, and loses it when the tail
   unfurls. `display-background: false` opts out of both, as it already does.
4. Paged targets are unchanged: the first `n` blocks plus a grey ellipsis, tail
   discarded, nothing to click.
5. `#idea-body(.., limit: n)` is unchanged — it has no chrome by design, so it
   truncates and stops, in every target.
6. Links inside the preview still navigate rather than toggling the disclosure.

## Steps

1. The `limit:` paragraph. `rg -Fn 'truncates the body to the first'
   core/0.1.0/readme.md` — one hit, around line 1065, inside the `## Referencing
   a note` section's `#window` bullet. The clause ending "plus \"…\", in every
   target, not just HTML" is now only half true and is the text you are
   replacing, so do not use it as a locator afterwards. Rewrite the sentence so
   it says what each target does: the first `n` content-level blocks plus an
   ellipsis everywhere, and in HTML and EPUB the shown blocks are themselves the
   control that unfurls the remainder in place. Keep the `limit: 0` rejection
   sentence that follows it exactly as it is.

2. The block-boundary paragraph. `rg -Fn 'A limit can no longer land
   mid-paragraph' core/0.1.0/readme.md` — one hit, around line 1071. Leave this
   paragraph's claim alone; it is still true.

3. Add a short paragraph after it, in the readme's own register (prose, not
   bullets, explaining the mechanism rather than selling it), covering points
   1, 3 and 4 above: what the reader clicks, that the preview carries the folded
   tint until it is opened, that the fold and the expansion are two disclosures
   one inside the other, and that a paged target keeps the hard truncation
   because there is nothing there to click.

4. `#idea-body`'s own section. `rg -Fn 'idea-body' core/0.1.0/readme.md` and
   find where its `limit:` is documented. State there, in one sentence, that its
   truncation is NOT expandable — it renders a body with no chrome, so there is
   no disclosure to hang the tail on.

## Do NOT

- Do NOT edit anything under `core/0.1.0/src/`, `test/` or `demo/`. This bird is
  the readme and nothing else.
- Do NOT document the CSS attribute names (`window-more`, `window-ellipsis`) as
  public API. The readme documents author-facing behaviour; the attributes are
  core.css's business and a project restyling them is out of scope here.
- Do NOT touch the `## Derived labels` section's 60-character `limit`, around
  line 2219 — a different, unrelated limit that is not configurable.

## VERIFY

1. `rg -F 'not just HTML' core/0.1.0/readme.md` returns nothing: the old
   half-truth is gone.
2. `rg -Fn 'unfurl' core/0.1.0/readme.md` (or whatever verb the new prose uses
   for opening the remainder) hits in the `## Referencing a note` section.
3. `rg -Fn 'A limit can no longer land mid-paragraph' core/0.1.0/readme.md`
   still hits once — that paragraph was to be left alone.
4. `cd core/0.1.0 && just test` still prints `units OK`. Nothing here should
   affect it; if it fails, something outside the readme was edited.