---
id: rk-moves-todos-off-tagged-idea-01567b4a
short-id: '015'
title: Moves todos off tagged-idea
priority: 3
labels:
- migrate-tagged-idea
deps:
- blocked-by:rk-adds-tag-and-base-tags-to-idea-9960f68e
closed: true
---
Touches: todos/0.1.0/src/todo.typ, todos/0.1.0/src/skin.typ

Migrate `@rookery/todos` off `@rookery/core`'s `tagged-idea` factory onto
`idea.with(base-tags: ..)`.

## Why

`@rookery/core`'s `#idea` now takes two MERGING tag arguments — `tag:` (one tag
name, string only) and `base-tags:` (none, a string, an array of strings, or a
dictionary binding a value per tag) — which a caller's own `tags:` is merged ON
TOP OF rather than replacing. That makes `idea.with(..)` a safe way to build a
note constructor, which is the one thing `tagged-idea` existed to provide.
`tagged-idea` is deleted from core by a later bird; this bird moves todos off
it first.

**DO NOT reach for `idea.with(base-tags: TODO-KEY)` here.** It looks like the
obvious translation and it is not safe for a package's exported constructor.
MEASURED on this machine: a spread argument OVERRIDES an explicitly named one
at the same call, with no duplicate-argument error —

    #let g(tags: none) = repr(tags)
    #let h(..args) = g(tags: "fixed", ..args)
    #h(tags: "caller")     // -> "caller", not "fixed"

— so anything a wrapper binds and does not NAME IN ITS OWN SIGNATURE can be
silently replaced by the caller. `#todo` is a published surface and must not
lose its `todo` tag that way.

The safe shape is an explicit composing wrapper: `#todo` already names `tags:`
in its own parameter list, so it captures the caller's tags, merges its own key
UNDER them, and passes the result on as `tags:`. A caller who additionally
writes `base-tags:` or `tag:` reaches core through `..args`, where both merge
BELOW the computed `tags:` — so the package's key survives either way.

Merge with core's `_merge-base-tags`, not with `+`. Typst's `+` on an array is
NOT a general merge: `("todo",) + "draft"` and `("todo",) + (draft: 1)` both
error outright, and `tags:` accepts a string and a dictionary among its four
shapes. `_merge-base-tags(base, tags)` normalizes both sides and gives the
right-hand side precedence per key, which is exactly the rule wanted here.

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
`core/`, `todos/`, `timeline/` …). Each was run before filing and printed
exactly ONE hit.

**Site 1 — the core import,** at the top of `todos/0.1.0/src/todo.typ` (around
line 3 as of filing).

    rg -Fn '#import "@rookery/core:0.1.0": tagged-idea, _norm' todos/

**Site 2 — the minting call,** inside the `#todo` function in the same file
(around line 191).

    rg -Fn 'let mint = dated(tagged-idea(TODO-KEY))' todos/

**Site 3 — `#epic`'s banner comment,** same file (around line 243), in the
paragraph beginning "A FACTORY, not a function taking a list".

    rg -Fn "one more application of rookery's \`tagged-idea\` composition" todos/

**Site 4 — the skin's pass-through comment,** in `todos/0.1.0/src/skin.typ`
(around line 16).

    rg -Fn 'WHAT IS OVERRIDDEN HERE: `window` alone' todos/

If an anchor does not resolve, widen the `rg` to the flight root. If it is
still gone, STOP and report the miss naming the landmark (the `#todo`
function, the `#epic` comment, `skin.typ`'s banner) rather than guessing or
recreating text.

## Steps

1. **Site 1 — change the import** from `tagged-idea, _norm` to
   `idea, _merge-base-tags, _norm`. Keep the other imports on the following
   lines untouched.

2. **Site 2 — change the minting call** from

       let mint = dated(tagged-idea(TODO-KEY))

   to

       let mint = dated(idea)

3. **Site 2a — fold `TODO-KEY` into the tags `#todo` already computes.** A few
   lines above the minting call, `#todo` binds

       let all-tags = todo-tags(
         tags: tags,
         ...
       )

   (around line 142 as of filing; find it with
   `rg -Fn 'let all-tags = todo-tags(' todos/`, one hit). Leave that call
   exactly as it is and add ONE line directly after its closing `)`:

       let all-tags = _merge-base-tags(TODO-KEY, all-tags)

   That is what puts the package's own key under everything the caller and
   `todo-tags` produced. The two `mint(..)` branches below already pass
   `tags: all-tags` and need no change at all.

   Add a one-sentence comment above it saying that the package's key merges
   UNDER the caller's tags, so a call site naming `todo` itself keeps its own
   value.

4. **Site 3 — update `#epic`'s comment** so the sentence naming "rookery's
   `tagged-idea` composition" names what is actually there: `#todo`'s own
   composition of core's `idea`. Keep the rest of the paragraph, including its
   point that the factory shape keeps `#todo`'s entire call surface with no
   argument forwarding to reimplement, and the rejected-alternative sentence
   after it.

5. **Site 4 — update `skin.typ`'s comment.** It says "`idea` and `tagged-idea`
   pass through already-decorated from the timeline skin". Only `idea` passes
   through now. Rewrite that sentence accordingly, and keep the rest of the
   block (what IS overridden — `window` alone — and the closing "everything
   else is rookery's, untouched").

6. **Sweep the package.** Run

       rg -Fn 'tagged-idea' todos/

   and resolve every remaining hit — prose included — so the count reaches
   ZERO. Each is either an example to rewrite in the `idea.with(base-tags: ..)`
   shape, or a sentence whose claim is now false and must state what is there.

Follow the repository `CLAUDE.md`'s comment style throughout: present tense,
describe what is there, no "used to", no issue ids, no interior section
banners.

## Non-goals

- **Do NOT touch any package outside `todos/0.1.0/`.** Not `core`, not
  `timeline` — they have birds of their own.
- Do not change `#todo`'s or `#epic`'s signature, their tag keys, the todo
  graph, `todo-tags`, or anything in `table.typ`, `graph.typ`, `views.typ`.
- **Do not bind `base-tags:` or `tag:` on `#todo`'s behalf**, by `.with()` or
  by passing them to `mint`. Those are for a PROJECT to use on core's `idea`;
  a package's exported constructor composes explicitly instead, for the
  spread-overrides reason given above.
- Do not add `base-tags:` or `tag:` to `#todo`'s own signature. A caller
  naming either reaches core through `..args` and merges below the computed
  `tags:`, which is already correct.
- Do not add a compatibility shim or alias for `tagged-idea`.
- Do not run `pnpm install`/`pnpm run build` or touch `package.json` — the JS
  half of this package is untouched.

## VERIFY

Run from `<flight>/todos/0.1.0/`.

1. The unit fixture and the panic fixture both pass — this package's whole
   Typst harness:

       just test

   Expect it to end with `units OK`.

2. No mention of the removed factory survives. From the flight root:

       rg -Fn 'tagged-idea' todos/

   Expect ZERO hits.

3. A todo still carries its own tag when the call site names tags of its own,
   which is the exact regression `base-tags:` exists to prevent. Create
   `_migrate_check.typ` INSIDE `todos/0.1.0/`:

       #import "/src/lib.typ": todo, rookery
       #import "@rookery/core:0.1.0": tags-of
       #show: rookery
       #todo("t", tags: ("draft",))[body]
       #todo("u", base-tags: "other")[body]
       #context {
         assert.eq("todo" in tags-of("t"), true)
         assert.eq("draft" in tags-of("t"), true)
         // A caller naming `base-tags:` must NOT displace the package's key.
         assert.eq("todo" in tags-of("u"), true)
         assert.eq("other" in tags-of("u"), true)
       }

   Compile it:

       typst compile --features html --root . --format html _migrate_check.typ /dev/null

   Expect exit 0 (an `html export is under active development` warning is
   normal). DELETE `_migrate_check.typ` afterwards — it must not be left in
   the tree.