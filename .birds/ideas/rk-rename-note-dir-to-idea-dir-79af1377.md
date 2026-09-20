---
id: rk-rename-note-dir-to-idea-dir-79af1377
short-id: 79a
title: Rename note-dir to idea-dir
priority: 4
labels:
- rename-note-dir-to-idea-dir
deps: []
closed: false
---
`@rookery/core`'s public vocabulary is **idea** and **name**. One user-facing
configuration argument still says "note": `#rookery(note-dir: ..)`, the
directory minted idea pages are written to. It is the last piece of retired
vocabulary on the public API surface, and after 0.1.0 is published it cannot be
renamed without a breaking change.

Rename it to `idea-dir`. This is a rename only — no behaviour changes, no new
argument, no deprecation alias.

Touches: core/0.1.0/src/template.typ, core/0.1.0/src/state.typ, core/0.1.0/readme.md

## Why `idea-dir` and not something else

The package already names its other public config arguments after the concept
they configure in the package's own vocabulary — `prefix`, `css-prefix`,
`idea-page-template`, `window-unfurl`. `idea-dir` is the only spelling
consistent with `idea-page-template`, which configures the same minted pages
this argument places.

## Scope: the public argument, not every internal

The **public argument name** must change. The **internal state binding**
`_note-dir` and its state key string may change too and it is tidier if they
do, but they are read by nothing outside this package. Rename them for
consistency; do not chase every internal that says "note" elsewhere in `src/` —
that is a much larger sweep and is not this bird.

## Steps

1. Find the public parameter. Anchor — one hit, in `core/0.1.0/src/template.typ`
   (line 441 as of filing), inside the `#let rookery(` signature:

   ```
   rg -n 'note-dir: none,' /home/lox/code/_fcl/rookery/core
   ```

   Rename the parameter to `idea-dir`.

2. Find every other reference and rename each. Anchor — several hits, all in
   `core/0.1.0/src/template.typ` (lines 26, 57-65, 367, 513, 549 as of filing),
   spread across the `_validate-config` helper, the `#let rookery` body, and one
   explanatory comment:

   ```
   rg -n 'note-dir' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   Sites to expect: the `_validate-config` parameter list and its assert body;
   the assert's own message text, which spells the argument name back to the
   author and MUST say `idea-dir` after this change; the comment at line 367
   beginning "publishes `prefix`"; the positional argument passed at line 513;
   and the `_note-dir.update(..)` call at line 549.

3. In `core/0.1.0/src/state.typ`, rename the internal binding and its state key
   for consistency. Anchor — one hit, in `core/0.1.0/src/state.typ` (line 44 as
   of filing), just under the comment beginning "The minted-page directory":

   ```
   rg -n 'rheo-idea-note-dir' /home/lox/code/_fcl/rookery/core
   ```

   Rename the binding `_note-dir` to `_idea-dir` and the key string
   `"rheo-idea-note-dir"` to `"rheo-idea-dir"`. Update the comment above it,
   which names the argument as `note-dir:` — it must say `idea-dir:`.

4. Update the readme. Anchor — one hit, in `core/0.1.0/readme.md` (line 2644 as
   of filing), a section heading:

   ```
   rg -n 'Where pages are minted' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   Rename every mention of the argument in that section and anywhere else in the
   readme:

   ```
   rg -n 'note-dir' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   13 hits as of filing. The section heading itself contains the argument name
   and must be renamed along with the prose.

5. Confirm nothing under `core/0.1.0/` still says `note-dir`:

   ```
   rg -n 'note-dir' /home/lox/code/_fcl/rookery/core
   ```

   This must print nothing.

## Non-goals

- Do NOT add a `note-dir` alias, a deprecation warning, or any back-compat
  shim. The package has no public release yet; nothing outside this machine
  consumes the old name.
- Do NOT rename `prefix`, `css-prefix`, or any other configuration argument.
- Do NOT sweep "note" out of comments, internal helper names, or CSS classes
  elsewhere in `src/`. That is a separate, much larger change.
- Do NOT edit anything outside `core/0.1.0/`. One sibling package,
  `slipshow/0.1.0/examples/ordering/content/functions.typ`, mentions `note-dir`
  in an example; leave it, and see the follow-up below.

## Follow-ups for the human, NOT part of this bird

Two consumers outside this package name the old argument and cannot be reached
from inside this flight:

- `slipshow/0.1.0/examples/ordering/content/functions.typ` (1 hit).
- The documentation site repo at `/home/lox/code/_fcl/rookery.ohrg.org`, whose
  `content/reference.typ` documents `note-dir` in its site-configuration table.
  That repo pins `@rookery/core` by remote ref in its own `rheo.toml`
  (a `[packages.rookery]` table naming `branch = "dev"`), so it reads a fixed
  remote ref and NOTHING done inside this flight can reach it. It must be
  updated separately after this lands and that ref moves.

## VERIFY

1. `rg -n 'note-dir' /home/lox/code/_fcl/rookery/core` prints nothing.
2. `rg -n 'idea-dir: none,' /home/lox/code/_fcl/rookery/core/0.1.0/src/template.typ`
   prints one hit.
3. From `core/0.1.0`, `just test` passes (prints `units OK`).
4. From `core/0.1.0/demo/pure`, `just build` passes (prints `demo/pure OK`).