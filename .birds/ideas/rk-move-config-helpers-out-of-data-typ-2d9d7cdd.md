---
id: rk-move-config-helpers-out-of-data-typ-2d9d7cdd
short-id: 2d9
title: Move config helpers out of data.typ
priority: 2
labels:
- chore-core-review
deps:
- blocked-by:rk-cache-bib-keys-drop-dead-cite-walk-871b6099
closed: false
---
Nearly half of `data.typ` is the template's argument validation and theme
resolution, which belongs with the template that is their only caller. Move
them, and fix the duplicated import and the two `assert(false, ..)` idioms that
come with them.

Touches: /home/lox/code/_fcl/rookery/core/0.1.0/src/data.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/src/template.typ

## What is wrong

`/home/lox/code/_fcl/rookery/core/0.1.0/src/data.typ` opens by declaring what
it is: "`#ideas` — every registered note as plain data, which is the supported
way to build anything this package does not". Its last 316 lines are none of
that. They are:

- `_validate-config` (lines 405-544) — the twenty asserts over
  `#show: rookery`'s arguments.
- `_resolve-tags-color` (lines 546-627) — normalising `theme: (tags-color: ..)`.
- `_resolve-theme` (lines 629-720) — turning the theme dictionary and the nine
  granular arguments into CSS strings.

Each has exactly one caller, and it is the same one: `rookery()` in
`/home/lox/code/_fcl/rookery/core/0.1.0/src/template.typ`, at lines 133 and 150.
A reader looking for what `#show: rookery` validates has to know to look in the
data-accessor module, and a reader of `data.typ` has to scroll past the whole
validation wall to reach `tag-data`.

Two smaller things in the same region:

- `/home/lox/code/_fcl/rookery/core/0.1.0/src/template.typ` imports `data.typ`
  twice, at line 20 and again at line 22.
- `_resolve-tags-color` reports two of its errors with `assert(false, message: ..)`
  — the `else` branch of its inner `_css-color` helper (lines 561-567) and its
  own final `else` (lines 617-624). Typst has `panic(..)` for exactly this, and
  this package already uses it wherever the condition is not a boolean test:
  `src/data.typ:102` in `_project-one`, `src/base.typ`'s rheo guard,
  `src/ideate.typ:250` and `src/ideate.typ:320`.

Line numbers are as of filing. If they have shifted, match the quoted text.

## Decisions already made — do not re-derive

- **They move to `template.typ`, not to `theme.typ`.** `template.typ` is their
  only caller and is last in the import order, so nothing can be broken by
  depending on it. `theme.typ` sits low in that order precisely because
  everything renders through `_themed`, and `_validate-config` is not about the
  theme at all.
- **The names stay exported.** `test/units.typ` imports `_resolve-tags-color`
  from `/src/lib.typ` (its import list, lines 19-27) and asserts on it.
  `lib.typ:60` imports `template.typ` with `*`, which re-exports transitively —
  the same mechanism that already makes `pure.typ`'s private names importable —
  so moving the function into `template.typ` keeps that import working. Do not
  rename anything and do not add an export list anywhere.
- **`_THEME-KEYS` resolves fine after the move.** `_validate-config` (line 484)
  and `_resolve-theme` (line 695) read it; it is defined in
  `src/theme.typ:80-90`, and `template.typ` imports `theme.typ` directly at line
  10. Today they reach it only transitively, through `data.typ`'s import of
  `idea.typ`.
- **The move is verbatim.** Copy the three functions and all their comment
  blocks exactly, including the banners above each. Rewording them is a separate
  bird's job.

## Steps

1. In `/home/lox/code/_fcl/rookery/core/0.1.0/src/template.typ`, delete the
   duplicate `#import "data.typ": *` — keep line 20, delete line 22.

2. Cut lines 405-720 of `/home/lox/code/_fcl/rookery/core/0.1.0/src/data.typ`
   — from the comment line beginning
   `// The 20 knobs \`#show: rookery\` accepts` through the closing `}` of
   `_resolve-theme` at line 720 — and paste them into
   `src/template.typ` immediately after the import block and before the
   `// ---- #show: rookery — the setup, and the knobs ----` banner (currently
   line 23). Keep the three functions in the same relative order:
   `_validate-config`, `_resolve-tags-color`, `_resolve-theme`.

3. `data.typ` now ends with `tag-data` (its closing `}` at line 403). Check
   that its own header (lines 1-4) is still true of what remains, and if it
   names anything that has moved, say what the file now holds instead. Do not
   otherwise touch the header.

4. In the moved `_resolve-tags-color`, replace both `assert(false, message: M)`
   calls with `panic(M)`, keeping each message string exactly as it is,
   including its line breaks and its `@rookery/core: ` prefix. The first is the
   `else` of the inner `let _css-color(key, value) = ...` chain; the second is
   the final `else` of the `for (tag, value) in tags-color` loop body.

5. Leave `data.typ`'s import block (lines 6-12) alone even if an import is now
   unused. That list is ordered deliberately and pruning it is out of scope for
   this bird.

## Do NOT

- Do not change any assert condition, any message text, any parameter name or
  any parameter order — this is a move, not a rewrite.
- Do not touch `ideas`, `tag-index`, `_project`, `_project-one`, `_ROW-FIELDS`
  or `tag-data`, which all stay in `data.typ`.
- Do not change how `rookery()` calls the three functions (lines 133 and 150
  before the edit).
- Do not reword or shorten any comment beyond step 3's single check. Separate
  birds cover the comment prose in both files.
- Do not edit `test/units.typ`.

## VERIFY

```sh
cd /home/lox/code/_fcl/rookery/core/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/pure && just build
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check-typst
```

Expected last lines: `units OK`, `demo/pure OK`, `demo/rheo OK`,
`demo/rheo (native) OK`. All four are green today. The first proves
`_resolve-tags-color` is still importable from `/src/lib.typ` and still
behaves; the third configures a theme with `tags-color` and asserts the
generated `.idea-tag-<tag>` CSS rules in the built HTML, which is
`_resolve-theme`'s and `_resolve-tags-color`'s output end to end.

Then confirm the validation still fires. In a scratch directory, compile a file
that sets a bad theme key and check the build FAILS with the package's own
message:

```sh
cd /tmp && printf '#import "@rookery/core:0.1.0": rookery\n#show: rookery.with(theme: (nope: red))\n= x\n' > bad-theme.typ \
  && typst compile --features html --format html bad-theme.typ /dev/null
```

Expected: a non-zero exit with `unknown theme key` in the message. (This relies
on `@rookery/core:0.1.0` resolving from the Typst package cache to this
checkout, which is how the demos already build. If that import does not
resolve, skip this step and say so in the flight.)