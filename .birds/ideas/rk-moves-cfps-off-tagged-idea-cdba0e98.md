---
id: rk-moves-cfps-off-tagged-idea-cdba0e98
short-id: cd
title: Moves cfps off tagged-idea
priority: 3
labels:
- migrate-tagged-idea
deps:
- blocked-by:rk-adds-tag-and-base-tags-to-idea-9960f68e
closed: false
---
Touches: cfps/0.1.0/src/cfp.typ, cfps/0.1.0/src/lib.typ, cfps/0.1.0/src/panel.typ, cfps/0.1.0/readme.md

Migrate `@rookery/cfps` off `@rookery/core`'s `tagged-idea` factory onto an
explicit composing call to core's `idea`.

## Why

`@rookery/core`'s `#idea` now takes two MERGING tag arguments — `tag:` (one tag
name, string only) and `base-tags:` (none, a string, an array of strings, or a
dictionary binding a value per tag) — which a caller's own `tags:` is merged ON
TOP OF rather than replacing. That makes `idea.with(..)` a safe way to build a
note constructor, which is the one thing `tagged-idea` existed to provide.
`tagged-idea` is deleted from core by a later bird; this bird moves cfps off it
first.

Only ONE of this package's two constructors uses the factory. `#venue` mints
through it; `#cfp` mints through `@rookery/todos`' `#todo` and is untouched by
this bird except where its prose names the factory.

**DO NOT reach for `idea.with(base-tags: VENUE-KEY)` here.** It looks like the
obvious translation and it is not safe for a package's exported constructor.
MEASURED on this machine: a spread argument OVERRIDES an explicitly named one
at the same call, with no duplicate-argument error —

    #let g(tags: none) = repr(tags)
    #let h(..args) = g(tags: "fixed", ..args)
    #h(tags: "caller")     // -> "caller", not "fixed"

— so anything a wrapper binds and does not NAME IN ITS OWN SIGNATURE can be
silently replaced by the caller. `#venue` is a published surface and must not lose
its own tag that way.

The safe shape is an explicit composing call, which this package is already
most of the way to: `#venue` names `tags:` in its own parameter list and already
builds the dictionary it hands to `#idea`. All that changes is calling core's
`idea` directly and merging `VENUE-KEY` UNDER that built value. A caller who
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

Run the anchor commands from the FLIGHT ROOT (the directory containing
`core/`, `cfps/`, `todos/` …). Each was run before filing and printed exactly
ONE hit.

**Site 1 — the core import,** at the top of `cfps/0.1.0/src/cfp.typ` (around
line 31 as of filing).

    rg -Fn '#import "@rookery/core:0.1.0": tagged-idea, _norm' cfps/

**Site 2 — the minting call,** inside `#venue` in the same file (around line
152).

    rg -Fn '(tagged-idea(VENUE-KEY))(' cfps/

**Site 3 — `lib.typ`'s header comment,** in `cfps/0.1.0/src/lib.typ` (around
line 13).

    rg -Fn '// `idea`/`tagged-idea`.' cfps/

**Site 4 — `panel.typ`'s header comment,** in `cfps/0.1.0/src/panel.typ`
(around line 11).

    rg -Fn '// mints (`cfp.typ`' cfps/

**Site 5 — the readme's paragraph on `#cfp`'s own tags** (around line 209).

    rg -Fn "\`#cfp\`'s own tags rather than through a \`tagged-idea(..)\` call, since" cfps/

If an anchor does not resolve, widen the `rg` to the flight root. If it is
still gone, STOP and report the miss naming the landmark (the `#venue`
function, `lib.typ`'s header, `panel.typ`'s header, the readme section) rather
than guessing or recreating text.

## Steps

1. **Site 1 — change the import** from `tagged-idea, _norm` to
   `idea, _merge-base-tags, _norm`. Keep the two `@rookery/timeline` and
   `@rookery/todos` imports on the neighbouring lines untouched.

2. **Site 2 — change the minting call** from

       (tagged-idea(VENUE-KEY))(

   to

       idea(

   Every argument below it (`name`, `title:`, `tags:`, `show-tags:`,
   `..args.named()`, `full`) stays in place; only the `tags:` line changes, in
   the next step.

3. **Site 2a — merge `VENUE-KEY` under `#venue`'s built tags.** Three lines
   below the anchor above, inside the SAME call, sits

       tags: own + normalize-tags(tags),

   Change it to

       tags: _merge-base-tags(VENUE-KEY, own + normalize-tags(tags)),

   **THERE ARE TWO LINES IN THIS FILE WITH THAT EXACT TEXT** (the other around
   line 353, as of filing). Change ONLY the one inside `#venue` — the one
   within the call you just edited in step 2. The other is inside `#cfp`,
   which mints through `@rookery/todos`' `#todo` and is explicitly out of scope
   (see the non-goals). After editing, confirm with

       rg -Fn 'tags: _merge-base-tags(VENUE-KEY,' cfps/

   expecting exactly ONE hit.

   Add a one-sentence comment above it saying the package's key merges UNDER
   the caller's tags, so a call site naming it keeps its own value.

4. **Sites 3, 4 and 5 — update the three prose mentions** so each names core's
   `idea` where it currently names `tagged-idea`. Preserve each one's actual
   argument:

   - `lib.typ`'s header is describing which core names this package builds on.
   - `panel.typ`'s header explains that the panel's tag data cannot come from a
     `tagged-idea(CFP-KEY)` call, because `#cfp` mints through
     `@rookery/todos`' `#todo` instead. That point still holds and must
     survive; only the spelling of the constructor changes.
   - The readme paragraph explains that `#cfp` carries its own tags rather
     than minting through a factory call. Same: the argument holds, the
     spelling changes.

5. **Sweep the package.** Run

       rg -Fn 'tagged-idea' cfps/

   and resolve every remaining hit — prose included — so the count reaches
   ZERO.

Follow the repository `CLAUDE.md`'s comment style throughout: present tense,
describe what is there, no "used to", no issue ids, no interior section
banners.

## Non-goals

- **Do NOT touch any package outside `cfps/0.1.0/`.** Not `core`, not `todos`,
  not `timeline` — they have birds of their own.
- **Do NOT change how `#cfp` mints.** It goes through `@rookery/todos`'
  `#todo(..)` deliberately, so that closedness, priority and the dated log all
  come from the packages that define them. Only `#venue`'s minting call
  changes here.
- Do not change `#venue`'s or `#cfp`'s signature, `VENUE-KEY`, `CFP-KEY`, the
  opportunity table, or the panel's rendering.
- **Do not bind `base-tags:` or `tag:` on `#venue`'s behalf**, by `.with()` or
  otherwise. Those are for a PROJECT to use on core's `idea`; a package's
  exported constructor composes explicitly instead, for the spread-overrides
  reason given above.
- Do not add `base-tags:` or `tag:` to `#venue`'s own signature. A caller naming
  either reaches core through `..args` and merges below the computed `tags:`,
  which is already correct.
- Do not add a compatibility shim or alias for `tagged-idea`.

## VERIFY

Run from `<flight>/cfps/0.1.0/`.

1. The unit fixture compiles, which is this package's whole harness:

       just test

   Expect it to end with `units OK`.

2. No mention of the removed factory survives. From the flight root:

       rg -Fn 'tagged-idea' cfps/

   Expect ZERO hits.

3. A venue still carries its own tag when the call site names tags of its own,
   which is the exact regression `base-tags:` exists to prevent. Create
   `_migrate_check.typ` INSIDE `cfps/0.1.0/`:

       #import "/src/lib.typ": venue
       #import "@rookery/core:0.1.0": rookery, tags-of
       #show: rookery
       #venue("v", tags: ("draft",))[body]
       #venue("u", base-tags: "other")[body]
       #context {
         assert.eq("draft" in tags-of("v"), true)
         // A caller naming `base-tags:` must NOT displace the package's key.
         assert.eq("other" in tags-of("u"), true)
       }

   Compile it:

       typst compile --features html --root . --format html _migrate_check.typ /dev/null

   Expect exit 0 (an `html export is under active development` warning is
   normal). If `#venue`'s required arguments differ from the above and the
   compile fails on a MISSING ARGUMENT rather than on tags, add what it asks
   for and re-run — do not change the `tags-of` assertion, which is the actual
   test.

   DELETE `_migrate_check.typ` afterwards — it must not be left in the tree.