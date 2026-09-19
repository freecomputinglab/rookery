---
id: rk-updates-bibtex-for-the-display-rename-bd005ea1
short-id: bd
title: Updates bibtex for the display rename
priority: 2
labels:
- feat-display-dict
deps:
- blocked-by:rk-gives-idea-a-display-dictionary-3c9c7f11
closed: false
---
Touches: bibtex/0.1.0/src/lib.typ, bibtex/0.1.0/readme.md

Update `@rookery/bibtex` for core's `show-*` to `display-*` rename.

## What changed in core

`#idea` no longer takes `show-tags:`. It takes `display: (:)` plus individual
`display-*` arguments, all defaulting to `auto`; the tags one is now `display-tags`,
and the dictionary key is `tags` without the prefix.

## Steps

1. `#citation` and its inner `note` constructor both declare and forward `show-tags`:

   ```
   rg -n 'show-tags' /home/lox/code/_fcl/rookery/bibtex/0.1.0/src/lib.typ
   ```

   Six hits as of filing: declarations at lines 131 and 148 (`show-tags: true` in
   both), forwards at 135, 152 and 154, and a signature comment at line 12. Rename
   every one to `display-tags`.

   **Keep the `true` defaults.** Do NOT change them to `auto`: `@rookery/bibtex` shows
   a citation's tags deliberately, and `auto` would fall through to core's default of
   `false` and silently stop showing them. This package is a caller with an opinion,
   not the bottom of the override stack.

   `show-fields` is this package's OWN parameter and never reaches core. Do NOT rename
   it.

2. Update the readme:

   ```
   rg -n 'show-tags' /home/lox/code/_fcl/rookery/bibtex/0.1.0/readme.md
   ```

   One hit as of filing (line 55), in a signature table row for `citation(..)`. Rename
   it and check the row still reads correctly.

## Non-goals

- Do NOT rename `show-fields` — it is this package's own and never reaches core.
- Do NOT change the `true` defaults.
- Do NOT touch `core/0.1.0/` or any other package.
- Do NOT add a `display:` dictionary parameter unless forwarding one is trivial; if you
  skip it, say so in your report.

## VERIFY

From `bibtex/0.1.0`:

1. `just test` exits 0. Report what the recipe actually ran.
2. `rg -n 'show-tags' src/ readme.md` returns no hits.
3. `rg -n -F 'display-tags: true' src/lib.typ` returns exactly two hits — both
   defaults survived.
4. `rg -n 'show-fields' src/` still returns hits under that name.
5. This package resolves `@rookery/core` through the Typst package cache, so whether a
   compile tests the NEW core depends on what
   `~/.cache/typst/packages/rookery/core/0.1.0` points at. Check with
   `ls -la ~/.cache/typst/packages/rookery/core/` and report whether it is a symlink
   into this checkout (testing new core) or a real directory (testing a published
   release, in which case the compile is NOT evidence about this rename).