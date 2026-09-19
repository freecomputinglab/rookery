---
id: rk-gives-window-a-display-dictionary-25e5104a
short-id: '25'
title: 'Gives #window a display dictionary'
priority: 3
labels:
- feat-display-dict
deps:
- blocked-by:rk-gives-idea-a-display-dictionary-3c9c7f11
closed: false
---
Touches: core/0.1.0/src/window.typ, core/0.1.0/src/transclusion.typ, core/0.1.0/src/permalink.typ

Give `#window` the same `display:` dictionary treatment `#idea` has: replace its six
`show-*` arguments with `display:` plus six `display-*` overrides, carry the resolved
dictionary on the window marker, and take it as one argument in `_window-content`.

BREAKING rename — `show-*` is removed, not aliased.

## Prerequisites

- `_resolve-display(dict, flags, where)` in `core/0.1.0/src/pure.typ`
  (`rg -n -F '#let _resolve-display' /home/lox/code/_fcl/rookery`). Nine keys —
  `context`, `backlinks`, `background`, `date`, `frame`, `id`, `label`, `tags`,
  `title`. Precedence: flag when not `auto`, else dictionary, else `auto`.
- `#idea` already uses it, and the IK show rule already reads a `display` dictionary
  off the IK payload (`rg -n -F 'v.at("display"'
  /home/lox/code/_fcl/rookery/core/0.1.0/src/transclusion.typ`). Follow that shape.

`#window` uses six of the nine keys: `date`, `frame`, `id`, `tags`, `label`,
`background`. The other three are `#idea`'s; they ride along in the resolved
dictionary and `#window` ignores them. Do not strip them.

`foldable:` and `reserve-title:` are NOT `show-*` arguments and are NOT renamed. Leave
both exactly as they are, as ordinary named parameters.

## Steps

1. Find `#window`'s signature:

   ```
   rg -n -F 'show-background: true,' /home/lox/code/_fcl/rookery/core/0.1.0/src/window.typ
   ```

   In `core/0.1.0/src/window.typ` (the six `show-*` parameters sit around lines 66-96
   as of filing). Replace `show-date`, `show-tags`, `show-frame`, `show-id`,
   `show-label`, `show-background` with `display: (:)` plus `display-date`,
   `display-tags`, `display-frame`, `display-id`, `display-label`,
   `display-background`, all defaulting to `auto`.

   Every `display-*` defaults to `auto` so that "an explicit flag beats the dictionary"
   is expressible at all — an unpassed flag must be distinguishable from one passed as
   `false`. Built-in defaults are applied in step 2.

2. Resolve near the existing assertions, then apply `#window`'s built-in defaults so no
   render-time key is left `auto`:

   ```typ
   let display = _resolve-display(
     display,
     (
       date: display-date, tags: display-tags, frame: display-frame,
       id: display-id, label: display-label, background: display-background,
     ),
     "#window's",
   )
   let display = display + (
     date: if display.date == auto { false } else { display.date },
     tags: if display.tags == auto { false } else { display.tags },
     frame: if display.frame == auto { true } else { display.frame },
     id: if display.id == auto { true } else { display.id },
     label: if display.label == auto { true } else { display.label },
     background: if display.background == auto { true } else { display.background },
   )
   ```

   These six defaults match `#window`'s current ones. Verify each against the signature
   you just replaced rather than trusting this list, and report any that differ.

3. Delete the now-dead per-argument type assertions for the six renamed parameters.
   Find one:

   ```
   rg -n -F "#window's `show-background` must be a bool" /home/lox/code/_fcl/rookery
   ```

   One hit, `window.typ` (line 132 as of filing). `_resolve-display` already rejects a
   non-boolean dictionary value with its own message, so these become redundant for the
   dictionary path. Remove the six `show-*` assertions; do NOT remove assertions for
   any other parameter.

4. Change `_window-content` to take the dictionary instead of six parameters:

   ```
   rg -n -F '#let _window-content(id, rec, shown, folded' /home/lox/code/_fcl/rookery
   ```

   One hit, `core/0.1.0/src/transclusion.typ` (line 97 as of filing). Its signature
   currently ends with `show-date, show-tags, show-frame: true, show-id: true,
   show-label: true, foldable: true, reserve-title: true, show-background: true,
   windows-claim: false`. Replace the six `show-*` with a single required
   `display` parameter; keep `folded`, `foldable`, `reserve-title` and `windows-claim`.

   Update its body — `show-date`, `show-tags`, `show-frame`, `show-label`,
   `show-background` are read at roughly lines 103, 183, 243 as of filing. Find them
   all with `rg -n 'show-' core/0.1.0/src/transclusion.typ` and read from `display.*`.

   `_window-content` passes `show-id:` on to `_permalink-tab`. Rename that helper's
   parameter to `display-id` too — it is private, it exists only for this, and leaving
   it is the sort of half-rename that confuses the next reader:

   ```
   rg -n -F 'show-id: true)' /home/lox/code/_fcl/rookery/core/0.1.0/src/permalink.typ
   ```

   Then fix `_permalink-tab`'s other callers:

   ```
   rg -n --hidden 'show-id:' /home/lox/code/_fcl/rookery/core/0.1.0
   ```

   `idea.typ` is one of them and you MAY edit that single call's keyword — it is the
   only change this bird makes to that file.

5. Update both `_window-content` call sites to pass `display`:

   ```
   rg -n -F '#marker#_window-content(id, rec, shown, folded' /home/lox/code/_fcl/rookery
   rg -n -F 'show-frame: v.at("show-frame", default: true)' /home/lox/code/_fcl/rookery
   ```

   One hit each: `window.typ` (line 331 as of filing) and the WK show rule in
   `transclusion.typ` (line 450 as of filing). The WK rule reads the six values off the
   window marker `v` — replace those reads with one, keeping the `.at` default so an
   older marker still works:

   ```typ
   display: v.at("display", default: (:)),
   ```

   and have `_window-content` fill any missing key from its own defaults.

6. Change what `#window` puts on the marker so it carries `display` rather than the six
   separate keys. Find the marker construction in `window.typ` near the
   `_window-content` call and update it to match what step 5 reads back.

## Non-goals

- Do NOT rename `foldable:` or `reserve-title:`.
- Do NOT touch `core/0.1.0/src/template.typ`, `state.typ` or `ideate.typ`.
- Do NOT touch `idea.typ` beyond the single `_permalink-tab` call keyword in step 4.
- Do NOT touch the readme, the demos, or any other package.
- Do NOT keep `show-*` as aliases.

## VERIFY

From `core/0.1.0`:

1. `just test` exits 0 and prints `units OK`.
2. `(cd demo/pure && just build)` exits 0 and ends with `demo/pure OK`. That
   recipe compiles `root.typ`, `root-prefix.typ` and `excluded.typ` and runs its own
   `check` — it is the pure-Typst demo's real entrypoint.
   Core must be GREEN at the end of this bird.
3. `rg -n 'show-(date|tags|frame|id|label|background)' src/window.typ src/transclusion.typ src/permalink.typ`
   returns no hits.
4. `rg -n -F 'display-background: auto' src/window.typ` returns exactly one hit, in the
   signature.
5. `rg -n -F 'foldable:' src/window.typ` still returns hits — that parameter survived.
