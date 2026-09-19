---
id: rk-moves-bibtex-off-tagged-idea-d2589b6e
short-id: d2
title: Moves bibtex off tagged-idea
priority: 3
labels:
- migrate-tagged-idea
deps:
- blocked-by:rk-adds-tag-and-base-tags-to-idea-9960f68e
- blocked-by:rk-moves-timeline-off-tagged-idea-0bec4286
closed: true
---
Touches: bibtex/0.1.0/src/lib.typ, bibtex/0.1.0/typst.toml, bibtex/0.1.0/readme.md

Migrate `@rookery/bibtex` off `@rookery/core`'s `tagged-idea` factory, renaming
its injectable `tagged-idea:` parameter to `mint:`, which takes a note
CONSTRUCTOR rather than a factory.

## Why

`@rookery/core`'s `#idea` now takes two MERGING tag arguments — `tag:` (one tag
name, string only) and `base-tags:` (none, a string, an array of strings, or a
dictionary binding a value per tag) — which a caller's own `tags:` is merged ON
TOP OF rather than replacing. That makes `idea.with(..)` a safe way to build a
note constructor, which is the one thing `tagged-idea` existed to provide.
`tagged-idea` is deleted from core by a later bird; this bird moves bibtex off
it first.

This package is the only one whose PUBLIC SURFACE names the factory: `bibtex`
takes `tagged-idea:` so a project on `@rookery/timeline` or `@rookery/todos`
can inject that package's own decorated version. That injection point must
survive — it is the whole reason a citation minted inside a todos project
carries todo arguments — but what gets injected is now a constructor, so the
parameter is renamed to `mint:` to say so.

This bird depends on the `@rookery/timeline` migration having landed, because
the readme's worked example imports `tagged-idea` FROM timeline, and timeline
drops that export.

**A note on how `@rookery/core` resolves here:** it comes from the Typst
package cache, which on this machine symlinks
`~/.cache/typst/packages/rookery/core/0.1.0` to the repository's own
`core/0.1.0`. You are therefore compiling against the core in the MAIN
checkout, not a copy inside this flight — which is correct, and is why this
bird could not run before core's own bird landed. If `just test` fails with
`unknown named argument: base-tags`, that landing has not happened; STOP and
report it rather than working around it.

## Where

Run the anchor commands from the FLIGHT ROOT (the directory containing
`core/`, `bibtex/`, `timeline/` …). Each was run before filing and printed
exactly ONE hit.

**Site 1 — the core import,** in `bibtex/0.1.0/src/lib.typ` (around line 30 as
of filing).

    rg -Fn 'tagged-idea as _core-tagged-idea, tag-data, _norm-tags' bibtex/

**Site 2 — the `bibtex(..)` parameter,** same file (around line 68).

    rg -Fn '  tagged-idea: _core-tagged-idea,' bibtex/

**Site 3 — the note constructor and the comment above it,** same file (around
lines 126-130). The comment's last sentence reads "The package's own `tag` is
then dedup'd on top by `tagged-idea` exactly as it was before this merge
existed."

    rg -Fn 'known: none, ..args) => (tagged-idea(tag))(' bibtex/

**Site 4 — the manifest's `min_version` comment,** in `bibtex/0.1.0/typst.toml`
(around line 12).

    rg -Fn '# notes through core' bibtex/

**Site 5 — the readme's signature heading** (around line 24).

    rg -Fn '## `bibtex(src, tagged-idea:, tag:, keywords:, show-fields:, only:)`' bibtex/

**Site 6 — the readme's injection paragraph and its example** (around lines
96-105).

    rg -Fn "\`tagged-idea:\` defaults to \`@rookery/core\`'s own, which is what you want on" bibtex/

**Site 7 — the readme's Requirements sentence** (around line 218).

    rg -Fn '`@rookery/core` 0.1.0 for `tagged-idea`; nothing else here imports it.' bibtex/

If an anchor does not resolve, widen the `rg` to the flight root. If it is
still gone, STOP and report the miss naming the landmark (the `bibtex`
function, the readme heading, the manifest comment) rather than guessing or
recreating text.

## Steps

1. **Site 1 — change the import** so it brings in core's `idea` under a
   private alias instead of the factory, and adds the merge helper:

       #import "@rookery/core:0.1.0": idea as _core-idea, tag-data, _merge-base-tags, _norm-tags

   Keep `tag-data` and `_norm-tags` exactly as they are.

2. **Site 2 — rename the parameter.** In `bibtex`'s parameter list, replace

         tagged-idea: _core-tagged-idea,

   with

         mint: _core-idea,

   Leave its POSITION in the list unchanged (it stays between `src` and
   `tag:`), and leave every other parameter alone.

3. **Site 3 — change the note constructor** from

       let note = (key, title: auto, tags: none, show-tags: true, known: none, ..args) => (tagged-idea(tag))(

   to

       let note = (key, title: auto, tags: none, show-tags: true, known: none, ..args) => mint(

   **Do NOT write `mint.with(base-tags: tag)` here.** It looks like the obvious
   translation and it is not safe. MEASURED on this machine: a spread argument
   OVERRIDES an explicitly named one at the same call, with no
   duplicate-argument error —

       #let g(tags: none) = repr(tags)
       #let h(..args) = g(tags: "fixed", ..args)
       #h(tags: "caller")     // -> "caller", not "fixed"

   — so anything bound by `.with()` and not named in this closure's own
   signature can be silently replaced by a caller through `..args`. The
   package's `tag` must not be losable that way.

4. **Site 3a — merge `tag` under the tags the closure already builds.** Inside
   the same call, the `tags:` argument reads

       tags: kw-tags-for(key, known: known) + _norm-tags(tags),

   Find it with, expecting ONE hit:

       rg -Fn 'tags: kw-tags-for(key, known: known) + _norm-tags(tags),' bibtex/

   Change it to

       tags: _merge-base-tags(tag, kw-tags-for(key, known: known) + _norm-tags(tags)),

   and add `_merge-base-tags` to the core import edited in step 1. Every other
   argument in the call (`key`, `title:`, `show-tags:`, `..args`) stays exactly
   as it is.

   Then fix the comment directly above it: its closing sentence says the
   package's own `tag` is "dedup'd on top by `tagged-idea`". Rewrite that
   clause to name the merge that is actually there, and say the package's key
   sits UNDER both the keyword tags and the caller's own. Keep the sentences
   before it about keyword tags merging UNDER the caller's `tags:` — that
   behaviour is unchanged.

5. **Site 4 — update the manifest comment.** It says this package "mints notes
   through core's `tagged-idea`". Change that clause to name core's `idea`. Do NOT change `min_version`, the subtable below
   it, or the ordering warning in the rest of that comment.

6. **Site 5 — update the readme's signature heading** to
   `## \`bibtex(src, mint:, tag:, keywords:, show-fields:, only:)\``. If that
   heading is linked to from a table of contents or another heading reference
   in the same file, update those too — find them with
   `rg -Fn 'bibtex(src,' bibtex/0.1.0/readme.md`.

7. **Site 6 — rewrite the readme's injection paragraph and its example.** The
   argument is unchanged and must survive: the default is core's own
   constructor, which is what a plain rookery project wants, and a project on
   `@rookery/timeline` or `@rookery/todos` should pass THAT package's
   constructor instead, because a citation minted through core's undecorated
   one would not carry its date or todo arguments. Only the name and the
   example change. The example becomes:

       #import "@rookery/timeline:0.1.0": idea
       #let refs = bibtex(read("refs.bib"), mint: idea)

   **`@rookery/timeline` no longer exports `tagged-idea`** — its `idea` is the
   decorated constructor, and that is what goes in `mint:`. If the timeline
   migration has not landed and that package still exports a factory, STOP and
   report it rather than writing an example against a surface that is about to
   change.

8. **Site 7 — update the readme's Requirements sentence** so it names `idea`
   rather than `tagged-idea`.

9. **Sweep the package.** Run

       rg -Fn 'tagged-idea' bibtex/

   and resolve every remaining hit — prose included — so the count reaches
   ZERO.

Follow the repository `CLAUDE.md`'s comment style throughout: present tense,
describe what is there, no "used to", no issue ids, no interior section
banners.

## Non-goals

- **Do NOT touch any package outside `bibtex/0.1.0/`.** Not `core`, not
  `timeline` — they have birds of their own.
- **Do NOT remove the injection point.** `mint:` must stay a parameter with a
  default; collapsing it to always use core's `idea` breaks every project on
  timeline or todos.
- Do not change `tag:`'s meaning here. `bibtex`'s own `tag:` parameter names
  the tag a citation note carries (`"citation"` by default) and is unrelated
  to core's new `tag:` argument; it keeps its name and its default.
- Do not change `keywords:`, `show-fields:`, `only:`, the parser, or anything
  in `test/large.typ`.
- Do not add a compatibility shim or alias for the old `tagged-idea:`
  parameter name.
- **Do not bind `base-tags:` or `tag:` on the note closure's behalf**, by
  `.with()` or otherwise, for the spread-overrides reason given in step 3.

## VERIFY

Run from `<flight>/bibtex/0.1.0/`.

1. Both fixtures compile — this package's whole harness:

       just test

   Expect it to end with `units OK` and the second `typst compile` (of
   `test/large.typ`) to succeed.

2. No mention of the removed factory survives. From the flight root:

       rg -Fn 'tagged-idea' bibtex/

   Expect ZERO hits.

3. The renamed parameter is actually wired up, default and injected alike.
   Create `_migrate_check.typ` INSIDE `bibtex/0.1.0/`:

       #import "/src/lib.typ": bibtex
       #import "@rookery/core:0.1.0": idea, rookery, tags-of
       #show: rookery
       #let src = "@article{k1, title = {A Title}, author = {X}, year = {2020}}"
       #let refs = bibtex(src)
       #let injected = bibtex(src, mint: idea)
       #refs.citation("k1", tags: ("draft",))
       #context {
         assert.eq("draft" in tags-of("k1"), true)
         assert.eq("citation" in tags-of("k1"), true)
       }

   Compile it:

       typst compile --features html --root . --format html _migrate_check.typ /dev/null

   Expect exit 0 (an `html export is under active development` warning is
   normal). If `citation` is not the accessor's name on the returned
   dictionary, read the `bibtex(..)` return value in `src/lib.typ` and use the
   right one — do not change the `tags-of` assertion, which is the actual
   test.

   DELETE `_migrate_check.typ` afterwards — it must not be left in the tree.

4. The readme's example uses the new surface:

       rg -Fn 'mint: idea' readme.md

   Expect at least one hit.