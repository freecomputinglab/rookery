---
id: rk-names-a-derived-vs-pinned-id-clash-in-351726a8
short-id: '35'
title: Names a derived-vs-pinned id clash in the panic
priority: 2
labels:
- feat-title-derived-ids
deps:
- blocked-by:rk-derives-an-unnamed-idea-s-id-from-its-ac04e549
closed: false
---
Touches: core/0.1.0/src/idea.typ

Improve the duplicate-note-id panic so it names the case that a title-derived id makes
newly reachable: a note whose id was DERIVED from its title colliding with a note whose
id was PINNED by name.

## Context

An unnamed `#idea` with a `title:` now takes a slug of that title as its id, probing a
shared taken-ids set for the first free `<slug>`, `<slug>-1`, `<slug>-2`. The probe sees
only ids claimed EARLIER in the document, so this still collides:

```typ
#idea(title: [My Title])[derived, mints idea:my-title]
#idea(<my-title>)[pinned, wants idea:my-title, collides]
```

There is no second pass that could avoid it, so the collision is meant to surface as a
build error. The current message does not help, because it assumes both ids were pinned
by hand.

## Steps

1. Find the panic:

   ```
   rg -n -F 'A pinned id must be unique across the whole rookery' /home/lox/code/_fcl/rookery
   ```

   One hit, `core/0.1.0/src/idea.typ` (line 332 as of filing), inside the
   `_registry.update(r => { .. })` closure. The panic begins
   `"@rookery/core: duplicate note id "`.

2. Rewrite the message so it covers both cases. It must still name the id and both
   origins (the existing message already interpolates `existing.origin` and `origin` —
   keep that). Add a sentence saying the id may have come from a `title:` rather than a
   name, and that the fix is to retitle one note, rename one note, or pin the derived
   one explicitly with `#idea(<some-name>, title: [..])`.

   Keep it to the shape of this package's other messages: prefixed `@rookery/core: `,
   plain sentences, the concrete fix named. Do not make it more than about four lines
   of prose.

3. Add a comment above the `_registry.update` call recording why titled notes still
   step the `_seq` counter even though they no longer use its value: if the counter
   stepped only for untitled notes, adding a title to one note would renumber every
   later untitled note and change their permalinks and minted-page filenames. This is
   the same argument the exclusion-gate comment already makes for excluded notes — find
   it with `rg -n -F 'THE COUNTER STILL STEPS' /home/lox/code/_fcl/rookery` — so keep
   the new comment short and do not restate it at length.

   Follow `CLAUDE.md`'s "Comment style": present tense, describe the current shape, no
   history, no issue ids.

## Non-goals

- Do NOT change WHEN the panic fires, or the `existing != rec` condition that triggers
  it. This bird changes the message and adds a comment; behaviour is unchanged.
- Do NOT touch `_taken-ids`, the probe loop, or `_id-slug`.
- Do NOT touch any other file.

## VERIFY

From `core/0.1.0`:

1. `just test` exits 0 and prints `units OK`.
2. `rg -n -F '@rookery/core: duplicate note id' src/idea.typ` returns exactly one hit.
3. `rg -i -F 'title' src/idea.typ | rg -i 'duplicate|collide'` shows the new message
   mentions a title-derived id. (Grep a short fragment; do not assert on a whole
   sentence, which may be correctly re-wrapped.)
4. `typst compile --features html --root ../.. --format pdf demo/pure/main.typ /dev/null`
   exits 0. If that path is wrong, find the entrypoint with `ls demo/pure` and report
   the command you used.