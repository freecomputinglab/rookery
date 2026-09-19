---
id: rk-moves-search-demo-off-tagged-idea-eb41beb8
short-id: eb
title: Moves search demo off tagged-idea
priority: 3
labels:
- migrate-tagged-idea
deps:
- blocked-by:rk-adds-tag-and-base-tags-to-idea-9960f68e
closed: false
---
Touches: search/0.1.0/demo/rheo/content/index.typ

Migrate `@rookery/search`'s demo project off `@rookery/core`'s `tagged-idea`
factory onto `idea.with(base-tags: ..)`.

## Why

`@rookery/core`'s `#idea` now takes two MERGING tag arguments — `tag:` (one tag
name, string only) and `base-tags:` (none, a string, an array of strings, or a
dictionary binding a value per tag) — which a caller's own `tags:` is merged ON
TOP OF rather than replacing. That makes `idea.with(..)` a safe way to build a
note constructor, which is the one thing `tagged-idea` existed to provide.
`tagged-idea` is deleted from core by a later bird; this bird moves search's
demo off it first.

`search`'s own source imports nothing from core but `ideas()` and
`note-href()`, so this is the demo project alone — ONE file, two lines. It
still has to happen before core can drop the factory, because the demo is
compiled by `rheo compile` and would otherwise fail on an unknown import.

**A note on how `@rookery/core` resolves here:** it comes from the Typst
package cache, which on this machine symlinks
`~/.cache/typst/packages/rookery/core/0.1.0` to the repository's own
`core/0.1.0`. You are therefore compiling against the core in the MAIN
checkout, not a copy inside this flight — which is correct, and is why this
bird could not run before core's own bird landed.

## Where

Run the anchor commands from the FLIGHT ROOT (the directory containing
`core/`, `search/`, `todos/` …). Each was run before filing and printed
exactly ONE hit.

**Site 1 — the core import,** at the top of
`search/0.1.0/demo/rheo/content/index.typ` (line 2 as of filing).

    rg -Fn '#import "@rookery/core:0.1.0": footnote, idea, ideas-outline, tagged-idea, window' search/

**Site 2 — the project-local `#note` binding,** four lines below it (line 5 as
of filing), under the comment "`#note` is a project-local two-liner as of
0.5.0, not a package export."

    rg -Fn '#let note = tagged-idea("note")' search/

If an anchor does not resolve, widen the `rg` to the flight root. If it is
still gone, STOP and report the miss naming the landmark (the demo's
`index.typ` and its `#note` binding) rather than guessing or recreating text.

## Steps

1. **Site 1 — drop `tagged-idea` from the import list.** `idea` is already on
   that line, so the result is:

       #import "@rookery/core:0.1.0": footnote, idea, ideas-outline, window

2. **Site 2 — change the binding** from

       #let note = tagged-idea("note")

   to

       #let note = idea.with(base-tags: "note")

   Leave the comment above it in place, but check its wording still reads
   true — it says `#note` is a project-local two-liner rather than a package
   export, which is still exactly the point being made, so it most likely
   needs no change at all.

3. **Sweep the package.** Run

       rg -Fn 'tagged-idea' search/

   and resolve every remaining hit — prose included — so the count reaches
   ZERO.

Follow the repository `CLAUDE.md`'s comment style: present tense, describe
what is there, no "used to", no issue ids.

## Non-goals

- **Do NOT touch any package outside `search/0.1.0/`.** Not `core` — it has a
  bird of its own.
- Do not touch `search/0.1.0/src/` at all. This package's source imports only
  `ideas()` and `note-href()` from core and is unaffected.
- Do not run `pnpm install`/`pnpm run build`, touch `package.json`, or change
  the JavaScript.
- Do not switch `"note"` to `tag:` instead of `base-tags:`. Either would work
  for a single tag, but `base-tags:` is what the rest of this migration uses
  and keeps the packages spelled alike.

## VERIFY

1. No mention of the removed factory survives. From the flight root:

       rg -Fn 'tagged-idea' search/

   Expect ZERO hits.

2. The demo still compiles. From `<flight>/search/0.1.0/`:

       rheo compile demo/rheo

   Expect it to succeed. `rheo` is on PATH on this machine (0.6.3 at filing),
   which clears the package's declared 0.6.2 floor. If `rheo` is NOT found,
   say so in your report and fall back to a plain Typst parse of the one
   changed file:

       typst compile --features html --root demo/rheo --format html demo/rheo/content/index.typ /dev/null

   That fallback may fail on rheo-only constructs elsewhere in the file rather
   than on your change; if it does, report exactly what it said rather than
   editing the demo to make it pass.