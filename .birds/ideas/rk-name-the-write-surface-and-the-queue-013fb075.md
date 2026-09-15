---
id: rk-name-the-write-surface-and-the-queue-013fb075
short-id: '01'
title: Name the write surface and the queue after the package
priority: 2
labels:
- chore-timeline-api
deps:
- blocked-by:rk-rename-timeline-to-history-of-take-a-row-939e1b42
closed: false
---
Two of this package's three most-used exports are named as though nothing else
shared the namespace they land in.

`entries()` (`/home/lox/code/_fcl/rookery/timeline/0.1.0/src/fragment.typ:217`) is
the write surface — and the most generic identifier exported by any package in
this repo. `lib.typ` star-re-exports `@rookery/core`, so a project importing this
package gets `entries` injected alongside every rookery name. The family already
has a convention for exactly this function: `@rookery/todos`' tag fragment builder
is `todo-tags(..)` (`todos/0.1.0/src/tags.typ:148`), and `@rookery/meetings`'
readers are `meeting-with-of`, `occurred-of`.

`upcoming` / `upcoming-rows` (`timeline/0.1.0/src/upcoming.typ:304, 209`) are the
only views in the family not named after their package: the others are
`timeline-view`, `todos-list`, `todos-ready`, `todos-blocked`, `todos-stale`,
`todo-table`, `todo-graph-view`, `todos-search`, `meetings`.

Rename both to the convention. There is no deprecation alias: this repo renamed
the whole package at 0.1.0 and documented the move in a table, which is the right
precedent for a family of packages nothing outside this repo consumes yet.

```
entries(..)      -> timeline-tags(..)
upcoming(..)     -> timeline-upcoming(..)
upcoming-rows(..) -> timeline-upcoming-rows(..)
```

The blast radius is real and is listed below — roughly 30 call sites across five
packages, their tests, their demos and their readmes, plus two in the
`/home/lox/code/waterline` site. All of it is mechanical.

WATERLINE IS A SEPARATE REPOSITORY and needs its own commit. It resolves
`@rookery/timeline` through the cache symlink at
`~/.cache/typst/packages/rookery/timeline/0.1.0`, which points at this checkout,
so the site breaks the moment this lands. Land both together; the user pushes
each repo themselves.

Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/src/fragment.typ
Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/src/upcoming.typ
Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/src/index.typ
Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/readme.md
Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/test/units.typ
Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/test/upcoming.typ
Touches: /home/lox/code/_fcl/rookery/cfps/0.1.0/src/cfp.typ
Touches: /home/lox/code/_fcl/rookery/cfps/0.1.0/test/units.typ
Touches: /home/lox/code/_fcl/rookery/meetings/0.1.0/src/lib.typ
Touches: /home/lox/code/_fcl/rookery/todos/0.1.0/src/todo.typ
Touches: /home/lox/code/_fcl/rookery/todos/0.1.0/src/views.typ
Touches: /home/lox/code/_fcl/rookery/todos/0.1.0/test/units.typ
Touches: /home/lox/code/_fcl/rookery/todos/0.1.0/demo/rheo/content/index.typ
Touches: /home/lox/code/waterline/rookery/_lib/template.typ (separate repo)
Touches: /home/lox/code/waterline/rookery/_lib/lib.typ (separate repo)
Touches: /home/lox/code/waterline/rookery/grad/cycle-26-27.typ (separate repo)

## Steps

1. In `fragment.typ`, rename `entries` (217) to `timeline-tags`. Its own asserts
   name the package already; update the two messages that say "#upcoming" or
   "`entries()`" in prose. The internal caller is `dated` (289).
2. In `upcoming.typ`, rename `upcoming-rows` (209) to `timeline-upcoming-rows`
   and `upcoming` (304) to `timeline-upcoming`. `_require-today`'s message (line
   ~124) names both functions — update it. The CSS class names
   (`.upcoming`, `.upcoming-list`, `.upcoming-title`, `.upcoming-empty`,
   `.upcoming-row`) DO NOT CHANGE: they are a published contract with the
   stylesheet and with any project theming a row, and `test/check.sh` asserts on
   them.
3. Update every in-repo call site. The full list, from
   `rg -n '\bentries\(|\bupcoming(-rows)?\('`:
   - `cfps/0.1.0/src/cfp.typ:229, 345`
   - `cfps/0.1.0/test/units.typ:32 (prose), 38, 48`
   - `meetings/0.1.0/src/lib.typ:187` (called as `tl.entries(..)`)
   - `todos/0.1.0/src/todo.typ:58` (prose), `todos/0.1.0/src/views.typ:21`
     (import)
   - `todos/0.1.0/test/units.typ:105, 108, 137, 138, 140, 141, 151, 152, 228
     (prose), 231, 233, 282, 294, 298, 302, 306, 426`
   - `todos/0.1.0/demo/rheo/content/index.typ:11 (import), 80, 91, 100, 111, 122,
     133`
   - `timeline/0.1.0/test/units.typ` and `test/upcoming.typ` throughout
4. In `/home/lox/code/waterline`, update:
   - `rookery/_lib/template.typ:763` (a real call) and the `entries` name in the
     `rookery.typ` import list at lines 15-18;
   - `rookery/_lib/lib.typ:144` (a real call);
   - the prose naming `entries()` at `rookery/_lib/template.typ:745`,
     `rookery/_lib/lib.typ:136` and `rookery/grad/cycle-26-27.typ:801`;
   - the prose naming `#upcoming` at `rookery/_lib/template.typ:2, 140, 270,
     1014`. Waterline calls `#upcoming` nowhere — its worklists are its own
     `#cfps` and `#todo-slipshow` — so these are comments only, but a comment
     naming a function that no longer exists is the thing this repo's comment
     rubric forbids.
5. Grep the readmes too — `timeline`, `todos`, `cfps`, `meetings` and
   `core/0.1.0/readme.md` all name `entries` or `#upcoming` in prose or examples.
6. Add the three renames to `timeline/0.1.0/readme.md`'s migration table and
   remove `entries` from the "everything else keeps its name" list.

## Non-goals

- **No deprecation aliases.** One name per function.
- **Do not rename the CSS classes, the `timeline-log` tag key, the three reserved
  stage constants, or `.upcoming-row`.** A class is a contract with a stylesheet
  and with `test/check.sh`; the key is a contract with every note already written.
- **Do not rename `timeline-view`.** It already follows the convention.
- **Do not touch `dated`, `idea`, `tagged-idea`** or any reader.
- **Do not change any behaviour.** This bird is a rename and nothing else: no
  argument added, removed, reordered or redefaulted.

## VERIFY

1. `rg -n '\bentries\(|\bupcoming\(|\bupcoming-rows\('
   /home/lox/code/_fcl/rookery --glob '!**/dist/**'` returns nothing.
2. `cd /home/lox/code/_fcl/rookery/timeline/0.1.0 && just test` — `units OK`,
   `views OK` (the view check counts four upcoming lists and asserts the class
   names, so a renamed class fails here).
3. `cd /home/lox/code/_fcl/rookery/cfps/0.1.0 && just test` passes.
4. `cd /home/lox/code/_fcl/rookery/meetings/0.1.0 && just test` passes.
5. `cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just check` passes, and
   `rheo compile demo/rheo` succeeds.
6. `cd /home/lox/code/_fcl/rookery && just build && just check-versions` pass.
7. `cd /home/lox/code/waterline && just build` succeeds.