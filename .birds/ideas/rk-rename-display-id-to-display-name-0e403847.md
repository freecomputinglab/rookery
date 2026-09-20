---
id: rk-rename-display-id-to-display-name-0e403847
short-id: '0e40'
title: Rename display-id to display-name
priority: 2
labels:
- fix-idea-name-terminology
deps:
- blocked-by:rk-rename-ideate-id-to-ideate-name-7aed87f3
closed: true
---
Touches: core/0.1.0/src/idea.typ, core/0.1.0/src/window.typ, core/0.1.0/src/ideate.typ, core/0.1.0/src/template.typ, core/0.1.0/src/state.typ, core/0.1.0/src/permalink.typ, core/0.1.0/src/transclusion.typ, core/0.1.0/src/core.css, core/0.1.0/demo/pure/display-parity.typ, core/0.1.0/readme.md, slipshow/0.1.0/src/slipshow.typ, slipshow/0.1.0/src/slip.typ, slipshow/0.1.0/src/slipshow.css, slipshow/0.1.0/readme.md

## Why

`@rookery/core` is settling on one word for the thing that names a note:
**name**. `#idea("etal")` takes a name, `#ideate(name: ..)` is spelled `name:`,
and `#idea-href(name)`, `#idea-path(name)` and `#idea-body(name)` all take a
name. The word *id* survives in a few older identifiers and reads as a second
concept where there is only one.

The display flag is the widest of those leftovers. `display-id:` and the
matching `display: (id: ..)` key control whether a note shows its own
`[idea:etal]` permalink tab — that permalink IS the note's name, so the flag
should be `display-name:` / `display: (name: ..)`.

The `display` dictionary has nine keys — `background`, `backlinks`, `context`,
`date`, `frame`, `id`, `label`, `tags`, `title` — and `name` collides with none
of them. `label` is a different thing (it controls the authored title in the
hat), so `display-name` cannot be folded into it.

This is a **breaking rename with no alias**. `@rookery` coordinates never
change (see this repo's `CLAUDE.md`), the package is pre-release `0.x`, and
`#idea`'s own unknown-named-argument assertion turns a stale `display-id:` into
a clear compile-time panic rather than a silent no-op — which is a better
migration than a shim. Do not add a compatibility alias.

## Scope, measured before filing

```
rg -c 'display-id' /home/lox/code/_fcl/rookery
```

At the time of filing: `core/0.1.0/readme.md` 20, `core/0.1.0/src/template.typ`
6, `src/idea.typ` 5, `src/ideate.typ` 4, `src/permalink.typ` 3,
`src/window.typ` 3, `src/state.typ` 2, `src/transclusion.typ` 2,
`src/core.css` 1, `demo/pure/display-parity.typ` 2, plus
`slipshow/0.1.0/readme.md` 8, `slipshow/0.1.0/src/slipshow.typ` 8,
`slipshow/0.1.0/src/slip.typ` 2, `slipshow/0.1.0/src/slipshow.css` 1.

**`slipshow` must move in the same flight as `core`.** It passes `display-id:`
straight through to `#idea` (see `slipshow/0.1.0/src/slipshow.typ` around lines
487 and 520), so renaming core alone leaves slipshow calling core with an
argument core no longer accepts — which `#idea`'s unknown-argument assertion
turns into a panic on every slide.

## Steps

1. Rename the declared parameter everywhere it is declared or validated in
   `core`. Anchor:

   ```
   rg -n 'display-id' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   Rename `display-id` to `display-name` at every hit. The ones that are
   load-bearing rather than cosmetic, as of filing:

   - `src/idea.typ` line 59 — `#idea`'s parameter list.
   - `src/idea.typ` line 97 — where it is folded into the display dict as
     `id: display-id`; this becomes `name: display-name`.
   - `src/idea.typ` line 114 — the unknown-named-argument panic message, which
     lists the display flags by name. The list must name `display-name`.
   - `src/window.typ` lines 86, 168 and 194 — the same three shapes for
     `#window`.
   - `src/ideate.typ` lines 333 and 445 — `#ideate`'s parameter and pass-through.
   - `src/template.typ` lines 39, 157-158, 465 and 489 — the `#rookery`
     parameter, its boolean assertion (`message:` string included), and the
     fold into the display dict.
   - `src/permalink.typ` line 120 — `_permalink-tab`'s own `display-id:`
     parameter, and its call site at `src/idea.typ` line 504.
   - `src/transclusion.typ` lines 199 and 411 — `display-id: display.id` and
     `display-id: rd.id`, both of which become `display-name: display.name`
     and `display-name: rd.name`.

2. Rename the `display` dictionary key from `id` to `name`. Anchor:

   ```
   rg -n '_display-final|rdisplay\.id|display\.id' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   Every `display.id` / `rdisplay.id` read becomes `display.name` /
   `rdisplay.name`, and the string `"id"` in any `_display-final(..)` key list
   becomes `"name"` — `src/idea.typ` around line 317 has one such list,
   `("date", "tags", "frame", "id")`.

   `src/template.typ` line 505 reads
   `id: if display.id == auto { true } else { display.id },` — rename both the
   key and the reads.

3. Rename the document-wide state binding and its key string. Anchor:

   ```
   rg -n 'rheo-idea-show-id' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   One hit, `src/state.typ` line 236:
   `#let _display-id = state("rheo-idea-show-id", true)`. Rename the binding to
   `_display-name` and the state key string to `"rheo-idea-show-name"`, then
   fix the two readers — `src/state.typ` line 249 (`id: _display-id,`, which
   becomes `name: _display-name,`) and `src/template.typ` line 581
   (`_display-id.update(display.id)`).

   The state key is a plain string with no external consumer, so renaming it is
   safe **provided the binding and the key move together** — a state written
   under one key and read under another silently reverts to its default and no
   test catches it.

4. Update core's CSS comment and the pure demo. Anchors:

   ```
   rg -n 'display-id' /home/lox/code/_fcl/rookery/core/0.1.0/src/core.css
   rg -n 'display-id' /home/lox/code/_fcl/rookery/core/0.1.0/demo
   ```

   One hit in `core.css` (line 369, a comment reading
   `(`display-id: false` drops it)`) and two in
   `demo/pure/display-parity.typ` (lines 18 and 25, real call sites). No CSS
   selector or variable changes in this step.

5. Update `slipshow` in the same flight. Anchor:

   ```
   rg -n 'display-id' /home/lox/code/_fcl/rookery/slipshow/0.1.0
   ```

   Rename at every hit: `src/slipshow.typ` (its own `display-id:` parameters at
   lines 153 and 385, the boolean assertion and message at lines 433-434, the
   pass-throughs at 165, 487 and 520, and the comment at line 31),
   `src/slip.typ` (lines 55 and 84), `src/slipshow.css` (a comment at line
   224), and `readme.md`.

6. Update core's readme and add a migration note. Anchor:

   ```
   rg -n 'display-id' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   20 hits as of filing, including the section heading
   `### `display-id:` — and the whole hat with it` at line 506. Rename the flag
   at every hit, heading included, and say **name** rather than **id** for the
   value the flag shows where the surrounding sentence calls for it.

   Then add the rename to the readme's existing migration material — the readme
   already carries `### Migrating from the alpha lineage` and
   `### Migrating from `show-*` arguments` under `## 0.1.0`:

   ```
   rg -n '^### Migrating' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   Add a sibling section, one short paragraph: `display-id:` is now
   `display-name:` and the `display` dictionary's `id` key is now `name`; there
   is no alias, and a stale `display-id:` is caught by `#idea`'s
   unknown-named-argument panic rather than being silently ignored.

## NON-GOALS

- **Do not add a deprecated `display-id:` alias** or an accept-both path. The
  unknown-argument panic is the migration.
- **Do not rename the theme key `id-color` or the CSS variable
  `--idea-id-color`.** They are their own bird, they touch `core.css` and four
  other packages' stylesheets, and moving them here produces a conflicted nest.
- **Do not rename the `.id` field on `ideas()` rows**, and do not touch
  `idea-page-template(id: ..)`. Both are separate decisions with their own
  birds.
- **Do not sweep core's prose for the word "id" generally.** That is a separate
  bird that flies after this one.
- Do not touch `bibtex`, `cfps`, `meetings`, `pinboard`, `search`, `timeline`
  or `todos` — none of them pass `display-id:`. Confirm with
  `rg -n 'display-id' <package>` before concluding otherwise, and if one does
  turn up, say so in the flight report rather than widening the change.
- Do not touch `/home/lox/code/_fcl/rookery.ohrg.org`; that site has its own
  tracker and its own bird for this.

## VERIFY

1. The old flag and the old dictionary key are gone from both packages. This
   must print nothing:

   ```
   rg -n 'display-id|rheo-idea-show-id' /home/lox/code/_fcl/rookery/core/0.1.0 /home/lox/code/_fcl/rookery/slipshow/0.1.0
   ```

2. The new flag is declared on all four public functions. Each of these must
   print at least one hit:

   ```
   rg -n 'display-name' /home/lox/code/_fcl/rookery/core/0.1.0/src/idea.typ
   rg -n 'display-name' /home/lox/code/_fcl/rookery/core/0.1.0/src/window.typ
   rg -n 'display-name' /home/lox/code/_fcl/rookery/core/0.1.0/src/ideate.typ
   rg -n 'display-name' /home/lox/code/_fcl/rookery/core/0.1.0/src/template.typ
   ```

3. Core's tests pass. From `/home/lox/code/_fcl/rookery/core/0.1.0`:

   ```
   just test
   ```

   If that recipe does not exist, run what the package's `Justfile` does define
   for tests — read it with `rg -n '^[a-z-]+:' Justfile` — and report which
   recipe you ran.

4. The rheo demo still builds and its permalink cases still hold. From
   `/home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo`:

   ```
   ./check.sh 2>&1 | tail -20
   ```

   No case may report a missing or unexpected permalink tab.

5. Slipshow still compiles against the renamed core. From
   `/home/lox/code/_fcl/rookery/slipshow/0.1.0`:

   ```
   just test
   ```

   or, where that recipe is absent, the test recipe its `Justfile` does define.
   A panic mentioning `unknown named argument(s) ("display-id",)` means step 5
   was incomplete.

6. Both readmes describe the new flag:

   ```
   rg -n 'display-name' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   rg -n 'display-name' /home/lox/code/_fcl/rookery/slipshow/0.1.0/readme.md
   ```