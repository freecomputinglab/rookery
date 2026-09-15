---
id: rk-export-normalize-tags-drop-the-cfps-copy-9663704b
short-id: '96'
title: Export normalize-tags, drop the cfps copy
priority: 3
labels:
- chore-timeline-api
deps: []
closed: false
---
`_norm-tags` (`/home/lox/code/_fcl/rookery/timeline/0.1.0/src/fragment.typ:273`)
normalizes the four shapes rookery accepts for `tags:` — `none`, a bare string, an
array of strings, a dictionary — into a dictionary. Any package building a
constructor over `#idea` needs exactly that, and because it is private
`@rookery/cfps` carries a copy: `_norm-tags-local` in
`/home/lox/code/_fcl/rookery/cfps/0.1.0/src/cfp.typ`, whose own comment cites the
ladder match rule as precedent for copying.

It is the same fact about `@rookery/core`'s surface in both places, and if core
ever accepts a fifth shape the copy is the one that goes stale silently.

There is a THIRD copy, in a different repository:
`/home/lox/code/waterline/rookery/_lib/lib.typ:52`, exported as `norm-tags` and
called all over that site. It differs in its fallthrough — where this package
panics on a shape rookery does not accept, waterline's returns the value
untouched. Switching it over is worth doing and is a step below, but it is a
BEHAVIOUR change for that site (a bad `tags:` starts failing loudly), so it lands
as its own commit in that repo and the user decides whether to take it.

Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/src/fragment.typ
Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/readme.md
Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/test/units.typ
Touches: /home/lox/code/_fcl/rookery/cfps/0.1.0/src/cfp.typ

## Steps

1. In `timeline/0.1.0/src/fragment.typ`, rename `_norm-tags` (line 273) to
   `normalize-tags` and update its one internal caller, `dated` (line 289).
   `normalize-tags`, not `norm-tags`: this name enters every consuming project's
   namespace through `lib.typ`'s star re-export of core, so it should read as a
   sentence rather than as an abbreviation.
2. Keep the panic message exactly as it is — it names the four shapes, which is
   the whole value of the function to a caller who passed a fifth thing.
3. In `cfps/0.1.0/src/cfp.typ`, import `normalize-tags` from
   `@rookery/timeline:0.1.0`, delete `_norm-tags-local`, and point its call sites
   at the import.
4. Add two assertions to `timeline/0.1.0/test/units.typ` covering the shapes the
   existing tests do not: `normalize-tags(none)` is `(:)` and
   `normalize-tags(("a", "b"))` is `(a: none, b: none)`.
5. One line in `timeline/0.1.0/readme.md`, in the section describing `dated`,
   saying the normalizer is public and why a consumer would want it.
6. OPTIONAL, and a separate commit in a separate repository: in
   `/home/lox/code/waterline`, replace `norm-tags` in `rookery/_lib/lib.typ:52`
   with the import, keeping `tags-with` (line 66) built on top of it. Every
   call site keeps its name if the import is aliased — `normalize-tags as
   norm-tags` — which is the smallest possible diff for that site. Verify with
   `cd /home/lox/code/waterline && just build`. If the build turns up a call
   passing something the strict version rejects, that is a real bug in the site
   and is worth a bird of its own rather than a widened normalizer here.

## Non-goals

- **Do not move it out of `fragment.typ`.** `dated` is its only internal caller
  and they belong together.
- **Do not widen what it accepts.** Four shapes, because those are the four
  `#idea(tags:)` takes — not a fifth of this package's invention.
- **Do not touch the ladder helpers** — a separate bird exports those.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery/timeline/0.1.0 && just test` — `units OK`,
   `views OK`.
2. `cd /home/lox/code/_fcl/rookery/cfps/0.1.0 && just test` passes.
3. `rg -n '_norm-tags' /home/lox/code/_fcl/rookery` returns nothing.
4. `cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just check` passes.