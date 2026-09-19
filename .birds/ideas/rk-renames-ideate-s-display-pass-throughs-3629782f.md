---
id: rk-renames-ideate-s-display-pass-throughs-3629782f
short-id: '36'
title: 'Renames #ideate''s display pass-throughs'
priority: 2
labels:
- feat-display-dict
deps:
- blocked-by:rk-gives-idea-a-display-dictionary-3c9c7f11
closed: true
---
Touches: core/0.1.0/src/ideate.typ

Rename `#ideate`'s two `show-*` pass-through arguments to `display-*`, following the
rename already applied to `#idea`.

BREAKING rename — `show-*` is removed, not aliased.

## Context

`#ideate` mints notes by calling `#idea`, and re-exposes two of its display arguments
with INVERTED defaults: `show-frame: false, show-id: false`, because an ideated section
is a bare note rather than a card. `#idea` now takes `display: (:)` plus `display-*`
overrides, all defaulting to `auto`, so these two forwards no longer compile as
written.

## Steps

1. Find the signature:

   ```
   rg -n -F '#let ideate(body, separator: none' /home/lox/code/_fcl/rookery
   ```

   One hit, `core/0.1.0/src/ideate.typ` (line 330 as of filing). Replace
   `show-frame: false, show-id: false` with `display-frame: false, display-id: false`.

   **Keep the `false` defaults** — do NOT change them to `auto`. `#idea`'s parameters
   default to `auto` because it is the bottom of the override stack; `#ideate` is a
   CALLER expressing a real opinion, and `auto` here would silently restore the card
   and the permalink on every ideated note. This is the one place in the rename where a
   non-`auto` default is correct.

   Consider also accepting a `display: (:)` dictionary and forwarding it, for parity
   with `#idea`. If you do, forward it as `display: display` and let `#idea`'s own
   `_resolve-display` handle precedence — the explicit `display-frame`/`display-id`
   arguments will correctly win over it, which is the documented order. If that proves
   awkward, leave it out and say so in your report; it is optional here.

2. Find the two forwards into `idea(..)`:

   ```
   rg -n 'show-(frame|id)' /home/lox/code/_fcl/rookery/core/0.1.0/src/ideate.typ
   ```

   Hits around lines 437-438 as of filing, plus the signature from step 1 and any
   comments. Rename every one; rewrite comments to describe the present shape
   (`CLAUDE.md`, "Comment style").

## Non-goals

- Do NOT change the inverted `false` defaults to `auto`.
- Do NOT touch `idea.typ`, `window.typ`, `template.typ`, `state.typ`,
  `transclusion.typ` or `permalink.typ`.
- Do NOT change `#ideate`'s id derivation, its heading separator, or its duplicate-slug
  panics.
- Do NOT touch the readme (it documents `#ideate`'s signature; a separate bird updates
  it), the demos, or any other package.

## VERIFY

From `core/0.1.0`:

1. `just test` exits 0 and prints `units OK`.
2. `(cd demo/pure && just build)` exits 0 and ends with `demo/pure OK`. That
   recipe compiles `root.typ`, `root-prefix.typ` and `excluded.typ` and runs its own
   `check` — it is the pure-Typst demo's real entrypoint.
   what you used.
3. `rg -n 'show-(frame|id)' src/ideate.typ` returns no hits.
4. `rg -n -F 'display-frame: false' src/ideate.typ` returns exactly one hit — the
   inverted default survived the rename.