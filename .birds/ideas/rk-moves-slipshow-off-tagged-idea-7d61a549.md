---
id: rk-moves-slipshow-off-tagged-idea-7d61a549
short-id: 7d6
title: Moves slipshow off tagged-idea
priority: 3
labels:
- migrate-tagged-idea
deps:
- blocked-by:rk-adds-tag-and-base-tags-to-idea-9960f68e
closed: false
---
Touches: slipshow/0.1.0/src/slip.typ, slipshow/0.1.0/test/units.typ, slipshow/0.1.0/readme.md

Migrate `@rookery/slipshow` off `@rookery/core`'s `tagged-idea` factory onto
an explicit composing call to core's `idea`.

## Why

`@rookery/core`'s `#idea` now takes two MERGING tag arguments — `tag:` (one tag
name, string only) and `base-tags:` (none, a string, an array of strings, or a
dictionary binding a value per tag) — which a caller's own `tags:` is merged ON
TOP OF rather than replacing. That makes `idea.with(..)` a safe way to build a
note constructor, which is the one thing `tagged-idea` existed to provide.
`tagged-idea` is deleted from core by a later bird; this bird moves slipshow
off it first.

This package's own comments are the sharpest statement of the old rule
anywhere in the family — `slip.typ` explains that it is "Built on `tagged-idea`
rather than `idea.with(tags: (slip: none))`" precisely because `.with()` could
not merge. That reasoning is now obsolete, and those comments are part of this
bird's work rather than incidental to it.

**DO NOT reach for `idea.with(base-tags: SLIP-KEY)` here.** It looks like the
obvious translation and it is not safe for a package's exported constructor.
MEASURED on this machine: a spread argument OVERRIDES an explicitly named one
at the same call, with no duplicate-argument error —

    #let g(tags: none) = repr(tags)
    #let h(..args) = g(tags: "fixed", ..args)
    #h(tags: "caller")     // -> "caller", not "fixed"

— so anything a wrapper binds and does not NAME IN ITS OWN SIGNATURE can be
silently replaced by the caller. `#slip` is a published surface and must not
lose its own tag that way.

The safe shape is an explicit composing call, which `#slip` is already most of
the way to: it names `tags:` and `exclude-tags:` in its own parameter list, so
it captures both, and it already hands `#idea` a fully built `tags:` through
`slip-tags(..)`. All that changes is calling core's `idea` directly and merging
`SLIP-KEY` UNDER that built value. A caller who additionally writes
`base-tags:` or `tag:` reaches core through `..args`, where both merge BELOW
the computed `tags:` — so the package's key survives either way.

Merge with core's `_merge-base-tags`, not with `+`. Typst's `+` on an array is
NOT a general merge: `("slip",) + "draft"` and `("slip",) + (draft: 1)` both
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
`core/`, `slipshow/`, `todos/` …). Each was run before filing and printed
exactly ONE hit.

**Site 1 — `#slip`'s banner comment,** in `slipshow/0.1.0/src/slip.typ`
(around line 10 as of filing). This is the doomed text itself, so it stops
matching once the step lands and must not appear in VERIFY.

    rg -Fn 'Built on `tagged-idea` rather than' slipshow/

**Site 2 — the core import,** same file (around line 18).

    rg -Fn '#import "@rookery/core:0.1.0": tagged-idea' slipshow/

**Site 3 — the minting call,** same file (around line 55), the line that closes
`#slip`'s parameter list and opens the call.

    rg -Fn ') = (tagged-idea(SLIP-KEY, exclude-tags: exclude-tags))(' slipshow/

**Site 4 — the units fixture's comment,** in `slipshow/0.1.0/test/units.typ`
(around line 74).

    rg -Fn '// `tagged-idea`.' slipshow/

**Site 5 — the readme's `exclude-tags` paragraph** (around lines 159-162).

    rg -Fn '`exclude-tags:` list, for the reason core' slipshow/

If an anchor does not resolve, widen the `rg` to the flight root. If it is
still gone, STOP and report the miss naming the landmark (the `#slip`
function, the units fixture, the readme's `exclude-tags` discussion) rather
than guessing or recreating text.

## Steps

1. **Site 2 — change the import** from `tagged-idea` to
   `idea, _merge-base-tags`. If other names are on that same import line, keep
   them.

2. **Site 3 — change the minting call** from

       ) = (tagged-idea(SLIP-KEY, exclude-tags: exclude-tags))(

   to

       ) = idea(
         exclude-tags: exclude-tags,

   keeping every argument that already follows on the lines below
   (`show-frame:`, `show-id:`, the `tags: slip-tags(..)` block, `..args`) and
   the call's closing `)`.

   `exclude-tags:` moves from the factory call onto the `#idea` call itself.
   It is already a named parameter of `#slip`, so a caller who passes it binds
   that parameter and it reaches `#idea` here — the same behaviour the factory
   provided.

3. **Site 3a — merge `SLIP-KEY` under the built tags.** In the same call, the
   `tags:` argument currently reads

       tags: slip-tags(

   Wrap that whole `slip-tags(..)` call so it becomes

       tags: _merge-base-tags(SLIP-KEY, slip-tags(

   with a matching extra `)` after `slip-tags`'s own closing paren. Every
   argument inside `slip-tags(..)` — `tags:`, `fullscreen:`, `background:`,
   `enter:`, `order:`, `class:`, `row:`, `max-width:` — stays exactly as it
   is.

   Add a one-sentence comment above it saying the package's key merges UNDER
   everything `slip-tags` built, so a call site naming `slip` itself keeps its
   own value.

4. **Site 1 — rewrite `#slip`'s banner comment.** It currently argues that
   `#slip` is built on `tagged-idea` rather than `idea.with(tags: (slip:
   none))` because the latter lets a caller's `tags:` replace the tag the
   wrapper exists to add. The trap is real and still worth stating; what
   changed is the remedy. Rewrite the paragraph so it says that `#slip` names
   `tags:` in its own signature and merges `SLIP-KEY` UNDER whatever the caller
   passed, so the caller's tags survive and the package's key cannot be
   displaced. Keep the paragraph's point about the caller's own tags
   surviving.

5. **Site 4 — update the units fixture's comment** so it names `#slip`'s own
   composition of core's `idea` instead of `tagged-idea`. Do not change any
   assertion in that file unless step 8's sweep shows one naming the
   factory.

6. **Site 5 — rewrite the readme's `exclude-tags` paragraph.** It currently
   explains that `tagged-idea` returns a closure calling the `idea` captured in
   PACKAGE scope, so a project's own `idea.with(exclude-tags: ..)` rebinding
   does not reach a wrapper built with it. State what holds now:
   `#slip` binds core's `idea` from package scope, so a project rebinding its
   own `idea` still does not reach it, and `exclude-tags:` must therefore be
   passed to `#slip` as well. The CONCLUSION for a reader is unchanged — pass
   the list — so keep that, and keep any example showing it.

7. **Site 5 follow-on — check the surrounding lines.** The two lines after the
   anchor also name `tagged-idea`; rewrite them as part of the same paragraph
   rather than leaving a half-migrated sentence.

8. **Sweep the package.** Run

       rg -Fn 'tagged-idea' slipshow/

   and resolve every remaining hit — prose included — so the count reaches
   ZERO.

Follow the repository `CLAUDE.md`'s comment style throughout: present tense,
describe what is there, no "used to", no issue ids, no interior section
banners.

## Non-goals

- **Do NOT touch any package outside `slipshow/0.1.0/`.** Not `core`, not
  `todos` — they have birds of their own.
- Do not change `#slip`'s signature, `slip-tags`, `SLIP-KEY`, the deck
  machinery in `deck.typ`, or any of the slipshow JavaScript.
- **Do not bind `base-tags:` or `tag:` on `#slip`'s behalf**, by `.with()` or
  otherwise. Those are for a PROJECT to use on core's `idea`; a package's
  exported constructor composes explicitly instead, for the spread-overrides
  reason given above.
- Do not add `base-tags:` or `tag:` to `#slip`'s own signature. A caller
  naming either reaches core through `..args` and merges below the computed
  `tags:`, which is already correct.
- Do not add a compatibility shim or alias for `tagged-idea`.
- Do not run `pnpm install`/`pnpm run build` or touch `package.json` — the JS
  half of this package is untouched.

## VERIFY

Run from `<flight>/slipshow/0.1.0/`.

1. The unit fixture and the panic fixture both pass — this package's whole
   Typst harness:

       just test

   Expect it to end with `units OK`.

2. No mention of the removed factory survives. From the flight root:

       rg -Fn 'tagged-idea' slipshow/

   Expect ZERO hits.

3. A slip still carries its own tag when the call site names tags of its own,
   which is the exact regression `base-tags:` exists to prevent. Create
   `_migrate_check.typ` INSIDE `slipshow/0.1.0/`:

       #import "/src/lib.typ": slip
       #import "@rookery/core:0.1.0": rookery, tags-of
       #show: rookery
       #slip("s", tags: ("draft",))[body]
       #slip("u", base-tags: "other")[body]
       #context {
         assert.eq("draft" in tags-of("s"), true)
         // A caller naming `base-tags:` must NOT displace the package's key.
         assert.eq("other" in tags-of("u"), true)
       }

   Compile it:

       typst compile --features html --root . --format html _migrate_check.typ /dev/null

   Expect exit 0 (an `html export is under active development` warning is
   normal). If `#slip`'s own tag key is not literally `"slip"`, do not guess
   at it — the assertion above deliberately checks the CALLER's tag, which is
   the half that `base-tags:` protects.

   DELETE `_migrate_check.typ` afterwards — it must not be left in the tree.