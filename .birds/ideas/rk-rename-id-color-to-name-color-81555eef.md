---
id: rk-rename-id-color-to-name-color-81555eef
short-id: '815'
title: Rename id-color to name-color
priority: 2
labels:
- fix-idea-name-terminology
deps:
- blocked-by:rk-rename-display-id-to-display-name-0e403847
closed: true
---
Touches: core/0.1.0/src/theme.typ, core/0.1.0/src/template.typ, core/0.1.0/src/core.css, core/0.1.0/demo/pure/root-prefix.typ, core/0.1.0/readme.md, todos/0.1.0/src/todos.css, cfps/0.1.0/src/cfps.css, pinboard/0.1.0/src/pinboard.css, search/0.1.0/src/search.css, search/0.1.0/readme.md

## Why

`@rookery/core` is settling on one word for the thing that names a note:
**name**. `#idea("etal")` takes a name, `#ideate(name: ..)` is spelled `name:`,
and `#idea-href(name)`, `#idea-path(name)` and `#idea-body(name)` all take a
name. The word *id* survives in a few older identifiers and reads as a second
concept where there is only one.

Two of those leftovers are presentational, and they move together because one
is defined in terms of the other: the theme key `id-color` and the CSS custom
property it publishes, `--idea-id-color`. Both colour the `[idea:etal]`
permalink text — which is the note's name — so they become `name-color` and
`--idea-name-color`.

`--idea-id-color` is a **published** custom property: four other packages in
this repo fall back to it, and downstream sites set it directly. It is
therefore the widest-reaching rename in this set, and the one where an
incomplete sweep degrades silently — a `var(--idea-id-color, gray)` left
behind after the publisher is renamed simply resolves to `gray` and nothing
errors.

This is a **breaking rename with no alias**. `@rookery` coordinates never
change (see this repo's `CLAUDE.md`) and the package is pre-release `0.x`.

## Scope, measured before filing

```
rg -n 'id-color' /home/lox/code/_fcl/rookery
```

30 hits at the time of filing. By file: `core/0.1.0/src/template.typ` 4,
`core/0.1.0/src/core.css` 5, `core/0.1.0/src/theme.typ` 1,
`core/0.1.0/demo/pure/root-prefix.typ` 1, `core/0.1.0/readme.md` 2,
`todos/0.1.0/src/todos.css` 10, `search/0.1.0/src/search.css` 3,
`search/0.1.0/readme.md` 3, `cfps/0.1.0/src/cfps.css` 1,
`pinboard/0.1.0/src/pinboard.css` 1.

**Every package listed must move in the same flight.** Their stylesheets read
`var(--idea-id-color, ..)` as a fallback; once core publishes
`--idea-name-color` instead, a package left unchanged loses the theme colour
without any error.

There is also **one known consumer outside this repo**:
`/home/lox/code/_fcl/rookery.ohrg.org/style.css` line 338 sets
`--rookery-search-id-color`. That site has its own tracker and its own bird
for this — do not edit it from this flight, but do mention it in the flight
report so the operator can sequence the two.

## Steps

1. Rename the theme key and the property it publishes. Anchor:

   ```
   rg -n '"id-color"' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   One hit, `src/theme.typ` line 80:
   `"id-color": "--idea-id-color",`. This single line is the join between the
   Typst-side theme key and the CSS-side custom property; both halves change
   together:

   ```
   "name-color": "--idea-name-color",
   ```

   Keep the entry in whatever order the surrounding table uses — if the keys
   are listed alphabetically, move it to where `name-color` sorts.

2. Rename the `#rookery` parameter. Anchor:

   ```
   rg -n 'id-color' /home/lox/code/_fcl/rookery/core/0.1.0/src/template.typ
   ```

   Four hits as of filing — lines 274, 343, 448 and 537: the parameter in a
   destructuring list, the `id-color: id-color,` fold into the theme
   dictionary, the `id-color: none,` default in `#rookery`'s signature, and a
   second destructuring. Rename all four to `name-color`.

3. Rename every use of the custom property in core's stylesheet. Anchor:

   ```
   rg -n 'idea-id-color' /home/lox/code/_fcl/rookery/core/0.1.0/src/core.css
   ```

   Five hits as of filing — the variable table comment at line 30, and four
   `var(--idea-id-color, ..)` reads at lines 105, 442, 1181 and 1465. Rename
   the property in the comment table too, including the theme-key column
   beside it (`--idea-id-color     id-color`).

4. Update core's pure demo. Anchor:

   ```
   rg -n 'id-color' /home/lox/code/_fcl/rookery/core/0.1.0/demo
   ```

   One hit, `demo/pure/root-prefix.typ` line 17, a real call site:
   `id-color: rgb("#888888"),`.

5. Rename the fallback reads in the four dependent packages. Anchor:

   ```
   rg -n 'idea-id-color' /home/lox/code/_fcl/rookery/todos /home/lox/code/_fcl/rookery/cfps /home/lox/code/_fcl/rookery/pinboard /home/lox/code/_fcl/rookery/search
   ```

   As of filing: `todos/0.1.0/src/todos.css` 10 hits, all of the shape
   `var(--todo-muted-color, var(--idea-id-color, gray))`;
   `cfps/0.1.0/src/cfps.css` 1; `pinboard/0.1.0/src/pinboard.css` 1, which
   *sets* the property rather than reading it
   (`--idea-id-color: var(--pinboard-select-fg, #fff);`);
   `search/0.1.0/src/search.css` 2 reads.

   A plain textual rename of `--idea-id-color` to `--idea-name-color` is
   correct at all of these, the pinboard setter included.

6. Rename `search`'s own parallel property. Anchor:

   ```
   rg -n 'rookery-search-id-color' /home/lox/code/_fcl/rookery/search
   ```

   `src/search.css` lines 35, 247 and 344, and `readme.md` lines 954, 1126 and
   1147. Rename `--rookery-search-id-color` to `--rookery-search-name-color`
   throughout, and in `src/search.css` line 35's comment say "the `idea:etal`
   name beside a row's title" rather than "id".

   Note in the flight report that this one is set by at least one downstream
   site (`rookery.ohrg.org/style.css`), so its rename needs sequencing there.

7. Update core's readme and add a migration note. Anchor:

   ```
   rg -n 'id-color' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   Two hits as of filing — line 345, the theme table row
   `| `id-color` | the `[idea:etal]` permalink's text | `gray` |`, and line
   1990, `| `--idea-tag-color` | the pill's text colour | `--idea-id-color`
   (`gray`) |`. Rename both, and say the permalink shows the note's **name**.

   Then add the rename to the readme's existing migration material — the
   readme already carries `### Migrating from the alpha lineage` and
   `### Migrating from `show-*` arguments` under `## 0.1.0`:

   ```
   rg -n '^### Migrating' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   Add a sibling section, one short paragraph: the theme key `id-color` is now
   `name-color` and the custom property `--idea-id-color` is now
   `--idea-name-color`; there is no alias, and because CSS custom properties
   fail silently, a site that sets the old property will simply lose the
   colour rather than error.

   Also update `search/0.1.0/readme.md` in the same flight, where its three
   hits live.

## NON-GOALS

- **Do not add an alias** — neither a Typst-side `id-color` key that forwards
  to `name-color`, nor a CSS line republishing `--idea-id-color` from
  `--idea-name-color`.
- **Do not rename any other CSS custom property or class.** `--idea-tag-color`,
  `--idea-external-color`, `.idea-box`, `.idea-head`, `.idea-tab` and the rest
  of the `idea-`/`--idea-` family keep their names: `idea` is the note itself,
  which is not what this bird is renaming.
- **Do not rename `display-id:`, the `display: (id: ..)` key, `#ideate-id`,
  the `.id` field on `ideas()` rows, or `idea-page-template(id: ..)`.** Each is
  its own bird; touching them here produces a conflicted nest.
- **Do not sweep core's prose for the word "id" generally.** That is a separate
  bird that flies after this one.
- Do not edit `/home/lox/code/_fcl/rookery.ohrg.org`, even though its
  `style.css` sets `--rookery-search-id-color`. It has its own tracker.

## VERIFY

1. Neither old spelling survives anywhere in the repo. This must print nothing:

   ```
   rg -n 'idea-id-color|rookery-search-id-color|\bid-color\b' /home/lox/code/_fcl/rookery
   ```

2. The theme key and the custom property are joined under their new names.
   This must print one hit reading `"name-color": "--idea-name-color",`:

   ```
   rg -n 'name-color.*--idea-name-color' /home/lox/code/_fcl/rookery/core/0.1.0/src/theme.typ
   ```

3. Every dependent stylesheet reads the new property. Each must print at least
   one hit:

   ```
   rg -n 'idea-name-color' /home/lox/code/_fcl/rookery/todos/0.1.0/src/todos.css
   rg -n 'idea-name-color' /home/lox/code/_fcl/rookery/cfps/0.1.0/src/cfps.css
   rg -n 'idea-name-color' /home/lox/code/_fcl/rookery/pinboard/0.1.0/src/pinboard.css
   rg -n 'idea-name-color' /home/lox/code/_fcl/rookery/search/0.1.0/src/search.css
   ```

4. Core's tests pass. From `/home/lox/code/_fcl/rookery/core/0.1.0`:

   ```
   just test
   ```

   If that recipe does not exist, run what the package's `Justfile` does define
   for tests — read it with `rg -n '^[a-z-]+:' Justfile` — and report which
   recipe you ran. A panic naming an unknown theme key `id-color` means step 4
   was missed.

5. The rheo demo still builds. From
   `/home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo`:

   ```
   ./check.sh 2>&1 | tail -20
   ```

6. Both readmes describe the new names:

   ```
   rg -n 'name-color' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   rg -n 'rookery-search-name-color' /home/lox/code/_fcl/rookery/search/0.1.0/readme.md
   ```