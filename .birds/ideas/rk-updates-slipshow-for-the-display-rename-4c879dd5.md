---
id: rk-updates-slipshow-for-the-display-rename-4c879dd5
short-id: 4c
title: Updates slipshow for the display rename
priority: 2
labels:
- feat-display-dict
deps:
- blocked-by:rk-gives-window-a-display-dictionary-25e5104a
closed: true
---
Touches: slipshow/0.1.0/src/slip.typ, slipshow/0.1.0/src/slipshow.typ, slipshow/0.1.0/src/slipshow.css, slipshow/0.1.0/readme.md

Update `@rookery/slipshow` for core's `show-*` to `display-*` rename. This is the
heaviest downstream package: it forwards core's display arguments through two of its
own public functions with inverted defaults.

## What changed in core

`#idea` and `#window` no longer take `show-*` arguments. Both now take a `display:`
dictionary plus individual `display-*` overrides, all defaulting to `auto`:

- `#idea`: `display-context`, `display-backlinks`, `display-date`, `display-frame`,
  `display-id`, `display-tags`, `display-title`
- `#window`: `display-background`, `display-date`, `display-frame`, `display-id`,
  `display-label`, `display-tags`

`foldable:` and `reserve-title:` are NOT renamed in core and keep their names here too.

**`show-label` IS core's, not slipshow's.** It is `#window`'s parameter, forwarded by
this package, and core renamed it to `display-label`. Rename it here as well.

Dictionary keys drop the prefix: `display: (frame: false, id: false)`.

## Steps

1. `#slip` forwards two arguments into `idea(..)`:

   ```
   rg -n -F 'show-frame: false,' /home/lox/code/_fcl/rookery/slipshow/0.1.0/src/slip.typ
   ```

   `slip.typ` declares `show-frame: false, show-id: false` (lines 53-54 as of filing)
   and forwards both (lines 58-59). Rename to `display-frame` / `display-id`.

   **Keep the inverted `false` defaults.** Do NOT change them to `auto`: a slip is
   deliberately a bare note with no card and no permalink, and `auto` would restore
   both. This is a caller with a real opinion, not the bottom of the override stack.

   The comment just above (around line 47 as of filing, mentioning
   `#slip("x", show-frame: true)`) names the old argument — update it.

2. `_render-slip` and `#slipshow` in `slipshow.typ` do the same:

   ```
   rg -n 'show-(frame|id|label|date|tags|background)' /home/lox/code/_fcl/rookery/slipshow/0.1.0/src/slipshow.typ
   ```

   Hits around lines 31 (a comment), 152-153 and 384-385 (declarations, with
   `show-id: true` in one and `show-id: false` in the other — preserve each exactly),
   and 164-165, 486-487, 519-520 (forwards). Rename every one and keep every default.

   `_render-slip` forwards into `window(..)`, not `idea(..)`, so its arguments must
   match `#window`'s new names.

3. `slipshow.css` carries one comment naming the old argument:

   ```
   rg -n -F 'show-id' /home/lox/code/_fcl/rookery/slipshow/0.1.0/src/slipshow.css
   ```

   One hit (line 224 as of filing). Update the comment text only. Do NOT rename any CSS
   class or `data-rookery-*` attribute — none of them changed.

4. Update the readme:

   ```
   rg -n 'show-(frame|id|label|date|tags|background)' /home/lox/code/_fcl/rookery/slipshow/0.1.0/readme.md
   ```

   Around 17 hits as of filing, including a passage listing
   "`show-frame:`, `show-id:`, `show-label:`, `foldable:` and `reserve-title:`" — in
   that list the first three rename and the last two do not, so do not rewrite it
   mechanically. Check the surrounding prose still reads correctly.

   One passage argues that `show-id: false` leaves no ids a reader can copy into a
   `#window`. Keep the argument, rename the parameter.

## Non-goals

- Do NOT rename `foldable:` or `reserve-title:`.
- Do NOT rename any CSS class or `data-rookery-*` attribute.
- Do NOT change any default value, including the inverted `false` ones.
- Do NOT touch `core/0.1.0/` or any other package.
- Do NOT add a `display:` dictionary parameter to `#slip` or `#slipshow` unless
  forwarding one is trivial; if you skip it, say so in your report.

## VERIFY

From `slipshow/0.1.0`:

1. `just check` exits 0. If that recipe does not exist, run `just test`, and report
   which recipes the Justfile actually has.
2. `rg -n 'show-(frame|id|label|date|tags|background)' src/ readme.md` returns no hits.
3. `rg -n -F 'display-frame: false' src/slip.typ` returns exactly one hit — the
   inverted default survived.
4. `rg -n -F 'foldable' src/slipshow.typ` still returns hits under that name.
5. `@rookery/core` resolves through `~/.cache/typst/packages/rookery/core/0.1.0`,
   which is a SYMLINK into this checkout — so this package compiles against the live,
   already-renamed core. That makes step 1 a real signal, not a formality:
   **slipshow's suite currently FAILS** against the renamed core, and this bird is what
   makes it pass. A green `just test` is the proof the bird worked; if it is still red,
   report the failing assertion rather than declaring success.