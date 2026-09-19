---
id: rk-updates-cfps-for-the-display-rename-d6fc34a0
short-id: d6
title: Updates cfps for the display rename
priority: 2
labels:
- feat-display-dict
deps:
- blocked-by:rk-gives-idea-a-display-dictionary-3c9c7f11
closed: false
---
Touches: cfps/0.1.0/src/cfp.typ

Update `@rookery/cfps` for core's `show-*` to `display-*` rename.

## What changed in core

`#idea` no longer takes `show-tags:`. It takes `display: (:)` plus individual
`display-*` arguments, all defaulting to `auto`; the tags one is now `display-tags`,
and the dictionary key is `tags` without the prefix.

`@rookery/todos`'s `#todo` forwards unknown named arguments straight through to `#idea`
via an argument sink, so it needs no change of its own — but that means a
`display-tags:` passed to `#todo` reaches `#idea` under the new name, and a
`show-tags:` would reach it under a name it no longer has.

## Steps

1. `#venue` and `#cfp` both declare and forward `show-tags`:

   ```
   rg -n 'show-tags' /home/lox/code/_fcl/rookery/cfps/0.1.0/src/cfp.typ
   ```

   Four hits as of filing: `#venue`'s declaration at line 140 (`show-tags: true`) and
   its forward into `idea(..)` at 158; `#cfp`'s declaration at line 245
   (`show-tags: true`) and its forward into `todo(..)` at 356. Rename every one to
   `display-tags`.

   **Keep the `true` defaults.** Do NOT change them to `auto`: a venue and a cfp show
   their tags deliberately, and `auto` would fall through to core's default of `false`
   and silently stop showing them.

2. Check for any other display argument this package forwards:

   ```
   rg -n 'show-' /home/lox/code/_fcl/rookery/cfps/0.1.0/src/
   ```

   Rename any further hits on the same rules, and report what you found.

## Non-goals

- Do NOT change the `true` defaults.
- Do NOT touch `todos/0.1.0/` — it forwards via an argument sink and needs no change.
- Do NOT touch `core/0.1.0/` or any other package.
- Do NOT add a `display:` dictionary parameter unless forwarding one is trivial; if you
  skip it, say so in your report.

## VERIFY

From `cfps/0.1.0`:

1. `just test` exits 0. Report what the recipe actually ran.
2. `rg -n 'show-' src/` returns no hits.
3. `rg -n -F 'display-tags: true' src/cfp.typ` returns exactly two hits — both defaults
   survived.
4. This package resolves `@rookery/core` and `@rookery/todos` through the Typst package
   cache, so whether a compile tests the NEW core depends on what
   `~/.cache/typst/packages/rookery/core/0.1.0` points at. Check with
   `ls -la ~/.cache/typst/packages/rookery/core/` and report whether it is a symlink
   into this checkout (testing new core) or a real directory (testing a published
   release, in which case the compile is NOT evidence about this rename).