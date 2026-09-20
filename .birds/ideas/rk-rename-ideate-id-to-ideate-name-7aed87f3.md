---
id: rk-rename-ideate-id-to-ideate-name-7aed87f3
short-id: 7a
title: 'Rename #ideate-id to #ideate-name'
priority: 2
labels:
- fix-idea-name-terminology
deps: []
closed: true
---
Touches: core/0.1.0/src/pure.typ, core/0.1.0/src/ideate.typ, core/0.1.0/test/units.typ, core/0.1.0/demo/rheo/content/ideated-id.typ, core/0.1.0/demo/rheo/check.sh, core/0.1.0/readme.md

## Why

`@rookery/core` is settling on one word for the thing that names a note. The
author-facing surface already says **name** nearly everywhere — `#idea("etal")`
takes a name (its own panic message reads `#idea takes an optional name and an
optional body`), `#ideate(name: ..)` is called `name:`, and `#idea-href(name)`,
`#idea-path(name)` and `#idea-body(name)` all take a name. The word *id*
survives only in a handful of older identifiers, and each one now reads as a
second concept where there is only one.

`#ideate-id` is the clearest of those leftovers: it is the naming beacon for
`#ideate`, the exact analogue of `#ideate-tag`, and it sits beside an `#ideate`
parameter already spelled `name:`. Renaming it to `#ideate-name` is a pure
rename — no behaviour changes.

This is a **breaking rename with no alias**. `@rookery` coordinates never
change (see this repo's `CLAUDE.md`), the package is pre-release `0.x`, and a
deprecated alias for a beacon nobody outside this repo and
`rookery.ohrg.org` calls is more surface than it is worth. Do not add a
compatibility shim.

## Scope, measured before filing

```
rg -n 'ideate-id' /home/lox/code/_fcl/rookery
```

33 hits at the time of filing, spread over: `src/pure.typ` (the definition),
`src/ideate.typ` (the private reader and its call sites), `test/units.typ`,
the rheo demo (`demo/rheo/content/ideated-id.typ` and `demo/rheo/check.sh`),
and one line of `readme.md`. Expect roughly that many; a handful either way is
the file having moved on, not a broken bird.

## Steps

1. Rename the public constructor and the metadata key it writes. Anchor:

   ```
   rg -n 'rookery-ideate-id' /home/lox/code/_fcl/rookery/core/0.1.0
   ```

   Three hits as of filing — `src/pure.typ` line 971 (the definition,
   `#let ideate-id(id) = [#metadata((rookery-ideate-id: id))]`) and
   `src/ideate.typ` lines 254-255, inside `_ideate-id-value`, which reads the
   key back. Rename all three together:

   - `#let ideate-id(id)` becomes `#let ideate-name(name)`
   - the metadata key `rookery-ideate-id` becomes `rookery-ideate-name`
   - the private reader `_ideate-id-value` becomes `_ideate-name-value`

   The key and the reader must move in lockstep with the constructor — a
   beacon written under one key and read under another silently stops working
   and no test catches it except the demo check in step 5.

2. Update every remaining call site and comment in `src/ideate.typ`. Anchor:

   ```
   rg -n 'ideate-id|_ideate-id-value' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   As of filing this includes the section banner
   `// ---- Naming a note explicitly: `#ideate-id` ---` around line 84, the
   prose at line 88 (`#ideate-id(id)` is the id analogue of `#ideate-tag`),
   the example at line 94, `_strip-beacons` at line 260, and the two panic
   messages at lines 566 and 595:

   - line 566: `"@rookery/core: #ideate-id inside a heading is never read — move it to "`
   - line 595: `"ideate: more than one #ideate-id beacon in one section — got "`

   Both panic strings must name `#ideate-name`, since an author reading the
   panic will go looking for the function it names.

   While in these comments, say **name** rather than **id** for the value the
   beacon carries — `the id analogue of #ideate-tag` becomes `the name
   analogue of #ideate-tag`. Do NOT reword anything else in this file; a
   whole-file prose sweep is a separate bird.

3. Update the unit tests. Anchor:

   ```
   rg -n '_ideate-id-value' /home/lox/code/_fcl/rookery/core/0.1.0/test/units.typ
   ```

   Hits at lines 23 (the import list), 796 (the section banner), and 799-807
   (the assertions, which construct
   `[#metadata((rookery-ideate-id: "fixed-name"))]` directly). Rename the
   symbol in the import list, the banner, and every metadata key in the
   assertion bodies.

4. Update the rheo demo content. Anchor:

   ```
   rg -n 'ideate-id' /home/lox/code/_fcl/rookery/core/0.1.0/demo
   ```

   `demo/rheo/content/ideated-id.typ` imports `ideate-id` on line 2 and calls
   it on lines 14 and 26. Rename the import and both calls. **Leave the file
   itself named `ideated-id.typ`** and leave the minted note names
   (`fixed-id-note`, `second-para-note`) exactly as they are — `check.sh`
   asserts on the paths those names produce, and renaming them turns a
   two-line change into a demo rewrite.

5. Update the demo check script's messages. Anchor:

   ```
   rg -n 'ideate-id' /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo/check.sh
   ```

   Four hits as of filing — the case banner at line 646, two failure messages
   at lines 651 and 659, and a comment at line 672. These are message strings
   and comments only; the paths they check
   (`ideas/fixed-id-note.html`, `ideas/second-para-note.html`) do not change.

6. Update the one readme mention and add a migration note. Anchor:

   ```
   rg -n 'still wins the id outright' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   One hit, line 780 as of filing:
   `this, and `#ideate-id` still wins the id outright. With no document title`.
   Rename the function and say **name** rather than **id** for the value:
   ``and `#ideate-name` still wins the name outright``.

   Then add the rename to the readme's existing migration material. The readme
   already carries `### Migrating from the alpha lineage` and
   `### Migrating from `show-*` arguments` under `## 0.1.0` — find them with:

   ```
   rg -n '^### Migrating' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   Add a sibling `### Migrating from `#ideate-id`` section next to them, one
   short paragraph: `#ideate-id` is now `#ideate-name`, there is no alias, and
   a call to the old name is an unknown-variable error at compile time rather
   than a silent no-op.

## NON-GOALS

- **Do not add a deprecated `ideate-id` alias**, a shim, or a warning path.
  The rename is meant to be total.
- **Do not rename anything else that contains `id`.** `display-id:`, the
  `display: (id: ..)` key, the theme key `id-color`, the CSS variable
  `--idea-id-color`, the `.id` field on `ideas()` rows, and
  `idea-page-template(id: ..)` are each their own bird. Touching them here
  produces a conflicted nest.
- **Do not sweep core's prose for the word "id" generally.** That is a
  separate bird that flies after this one.
- Do not touch any package other than `core` — `bibtex`, `cfps`, `meetings`,
  `pinboard`, `search`, `slipshow`, `timeline` and `todos` do not call
  `#ideate-id`.
- Do not touch `/home/lox/code/_fcl/rookery.ohrg.org`; that site has its own
  tracker and its own bird for this.

## VERIFY

1. The old name is gone from the package, in code and in prose. This must
   print nothing:

   ```
   rg -n 'ideate-id|rookery-ideate-id|_ideate-id-value' /home/lox/code/_fcl/rookery/core/0.1.0
   ```

   The one permitted exception is the demo file's own *filename*,
   `demo/rheo/content/ideated-id.typ`, which `rg -n` does not print as a match.

2. The new name is present in all three places it has to be — definition,
   reader, and metadata key:

   ```
   rg -n 'ideate-name\(name\)|_ideate-name-value|rookery-ideate-name' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   Expect hits in both `src/pure.typ` and `src/ideate.typ`.

3. The package's own tests pass. From `/home/lox/code/_fcl/rookery/core/0.1.0`:

   ```
   just test
   ```

   If that recipe does not exist, run what the package's `Justfile` does
   define for tests — read it with `rg -n '^[a-z-]+:' Justfile` — and report
   which recipe you ran.

4. The rheo demo still mints both beaconed notes. From
   `/home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo`:

   ```
   ./check.sh 2>&1 | tail -20
   ```

   Case 27 (`#ideate-id` names a note explicitly under any separator, now
   named for `#ideate-name`) must not report a missing page at
   `ideas/fixed-id-note.html` or `ideas/second-para-note.html`.

5. The readme explains the rename. This must print at least one hit:

   ```
   rg -n 'ideate-name' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```