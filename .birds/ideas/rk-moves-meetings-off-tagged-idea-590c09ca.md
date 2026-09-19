---
id: rk-moves-meetings-off-tagged-idea-590c09ca
short-id: '59'
title: Moves meetings off tagged-idea
priority: 3
labels:
- migrate-tagged-idea
deps:
- blocked-by:rk-adds-tag-and-base-tags-to-idea-9960f68e
closed: false
---
Touches: meetings/0.1.0/src/lib.typ

Migrate `@rookery/meetings` off `@rookery/core`'s `tagged-idea` factory onto
an explicit composing call to core's `idea`.

## Why

`@rookery/core`'s `#idea` now takes two MERGING tag arguments — `tag:` (one tag
name, string only) and `base-tags:` (none, a string, an array of strings, or a
dictionary binding a value per tag) — which a caller's own `tags:` is merged ON
TOP OF rather than replacing. That makes `idea.with(..)` a safe way to build a
note constructor, which is the one thing `tagged-idea` existed to provide.
`tagged-idea` is deleted from core by a later bird; this bird moves meetings
off it first.

This is the smallest of the migration birds: TWO adjacent lines, in one file.

**DO NOT reach for `idea.with(base-tags: MEETING-KEY)` here.** It looks like the
obvious translation and it is not safe for a package's exported constructor.
MEASURED on this machine: a spread argument OVERRIDES an explicitly named one
at the same call, with no duplicate-argument error —

    #let g(tags: none) = repr(tags)
    #let h(..args) = g(tags: "fixed", ..args)
    #h(tags: "caller")     // -> "caller", not "fixed"

— so anything a wrapper binds and does not NAME IN ITS OWN SIGNATURE can be
silently replaced by the caller. `#meeting` is a published surface and must not lose
its own tag that way.

The safe shape is an explicit composing call, which this package is already
most of the way to: `#meeting` names `tags:` in its own parameter list and already
builds the dictionary it hands to `#idea`. All that changes is calling core's
`idea` directly and merging `MEETING-KEY` UNDER that built value. A caller who
additionally writes `base-tags:` or `tag:` reaches core through `..args`, where
both merge BELOW the computed `tags:` — so the package's key survives either
way.

Merge with core's `_merge-base-tags`, not with `+`. Typst's `+` on an array is
NOT a general merge: `("x",) + "draft"` and `("x",) + (draft: 1)` both error
outright, and `tags:` accepts a string and a dictionary among its four shapes.
`_merge-base-tags(base, tags)` normalizes both sides and gives the right-hand
side precedence per key, which is exactly the rule wanted here.

**A note on how `@rookery/core` resolves here:** it comes from the Typst
package cache, which on this machine symlinks
`~/.cache/typst/packages/rookery/core/0.1.0` to the repository's own
`core/0.1.0`. You are therefore compiling against the core in the MAIN
checkout, not a copy inside this flight — which is correct, and is why this
bird could not run before core's own bird landed. If `just test` fails with
`unknown named argument: base-tags`, that landing has not happened; STOP and
report it rather than working around it.

## Where

Run the anchor command from the FLIGHT ROOT (the directory containing `core/`,
`meetings/`, `todos/` …). It was run before filing and printed exactly ONE
hit.

**Site 1 — the minting call,** inside the meeting-constructor factory in
`meetings/0.1.0/src/lib.typ` (around line 132 as of filing). It sits two lines
below the comment "Captured under its own name so the closure's `today:`
parameter can default to the factory's".

    rg -Fn 'let mint = core.tagged-idea(MEETING-KEY)' meetings/

If the anchor does not resolve, widen the `rg` to the flight root. If it is
still gone, STOP and report the miss naming the landmark (the factory in
`lib.typ` that binds `factory-today` and `mint`) rather than guessing or
recreating text.

## Steps

1. **Site 1 — change the minting call** from

       let mint = core.tagged-idea(MEETING-KEY)

   to

       let mint = core.idea

   Change nothing else on that line's neighbours: the `let factory-today =
   today` line above it, the returned closure's whole parameter list below it,
   and every argument that closure forwards to `mint` stay exactly as they
   are.

   `core` is this file's existing module-style import of `@rookery/core`; do
   not add a new import or change the existing one.

2. **Site 2 — merge `MEETING-KEY` under the tags the closure already builds.**
   Inside that returned closure (around line 184 as of filing), it binds

       let all-tags = core._norm-tags(tags) + core._norm-tags(tag) + own

   Find it with, expecting ONE hit:

       rg -Fn 'let all-tags = core._norm-tags(tags) + core._norm-tags(tag) + own' meetings/

   Wrap the right-hand side so the package's key merges underneath it:

       let all-tags = core._merge-base-tags(
         MEETING-KEY,
         core._norm-tags(tags) + core._norm-tags(tag) + own,
       )

   Leave the two lines after it — the `if who.len() > 0 { .. }` insert and the
   `all-tags += tl.timeline-tags(..)` line — exactly as they are, and leave the
   comment above it in place; its point about caller-first ordering still
   holds.

   Add one sentence to that comment saying the package's own key sits UNDER
   all of them, so a call site naming it keeps its own value.

3. **Sweep the package.** Run

       rg -Fn 'tagged-idea' meetings/

   and resolve every remaining hit — prose and comments included — so the
   count reaches ZERO. At filing there was exactly one hit, the line above; if
   others have appeared, each is either an example to rewrite as a composing
   call to core's `idea`, or a sentence whose claim is now false and must state
   what is there.

Follow the repository `CLAUDE.md`'s comment style: present tense, describe
what is there, no "used to", no issue ids, no interior section banners.

## Non-goals

- **Do NOT touch any package outside `meetings/0.1.0/`.** Not `core`, not
  `timeline` — they have birds of their own.
- Do not change the factory's signature, `MEETING-KEY`, `_who`, `_css-safe`,
  the `names.pos()` fold above the anchor, or any date handling.
- **Do not bind `base-tags:` or `tag:` on `#meeting`'s behalf**, by `.with()` or
  otherwise. Those are for a PROJECT to use on core's `idea`; a package's
  exported constructor composes explicitly instead, for the spread-overrides
  reason given above.
- Do not add `base-tags:` or `tag:` to `#meeting`'s own signature. A caller naming
  either reaches core through `..args` and merges below the computed `tags:`,
  which is already correct.
- **Do not rename or repurpose this package's OWN `tag:` parameter.** The
  returned closure already has one, and it is unrelated to core's new `tag:`
  argument — the closure names it, so it never reaches core. Leave it and its
  `core._norm-tags(tag)` use alone.
- Do not add a compatibility shim or alias for `tagged-idea`.

## VERIFY

Run from `<flight>/meetings/0.1.0/`.

1. The unit fixture compiles, which is this package's whole harness:

       just test

   Expect it to end with `units OK`.

2. No mention of the removed factory survives. From the flight root:

       rg -Fn 'tagged-idea' meetings/

   Expect ZERO hits.

3. A meeting still carries the package's key when the call site names tags of
   its own. Create `_migrate_check.typ` INSIDE `meetings/0.1.0/`:

       #import "/src/lib.typ": meeting
       #import "@rookery/core:0.1.0": rookery, tags-of
       #show: rookery
       #meeting(<m>, tags: ("draft",))[body]
       #context { assert.eq("draft" in tags-of("m"), true) }

   Compile it:

       typst compile --features html --root . --format html _migrate_check.typ /dev/null

   Expect exit 0 (an `html export is under active development` warning is
   normal). `#meeting` is a factory in this package — if `meeting` is not
   directly callable, read `src/lib.typ` for the exported name and build the
   constructor the readme's own example builds, then keep the `tags-of`
   assertion unchanged; it is the actual test.

   DELETE `_migrate_check.typ` afterwards — it must not be left in the tree.