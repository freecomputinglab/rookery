---
id: rk-resolves-venue-s-auto-title-1ef1520e
short-id: 1e
title: Resolves venue's auto title
priority: 3
labels:
- fix-venue-auto-title
deps: []
closed: true
---
Touches: cfps/0.1.0/src/cfp.typ, cfps/0.1.0/test/units.typ

`#venue` in `@rookery/cfps` crashes the compile when called without an
explicit `title:` — which is its own documented default.

## The failure

`#venue` declares `title: auto` and passes that value straight through to
`@rookery/core`'s `#idea`. `#idea` guards only against `none`:

    if title == none { [] } else {
      html.elem("span", attrs: (..), title)
    }

so `auto` arrives as `html.elem`'s content positional, which rejects it.
MEASURED on this machine (typst 0.15.1), from `cfps/0.1.0/`:

    #import "/src/lib.typ": venue
    #import "@rookery/core:0.1.0": rookery
    #show: rookery
    #venue("v")[body]

    error: unexpected argument
        ┌─ @rookery/core:0.1.0/src/idea.typ:384:84
        │
    384 │  html.elem("span", attrs: (class: _c("title"), ..), title)
        │                                                     ^^^^^

Adding `title: none` (or any content) makes the same file compile cleanly, so
the note machinery is fine — only the unresolved `auto` is not.

This is NOT a core bug and core must not change. `#idea`'s `title:` takes
content or `none`; `auto` is not in its vocabulary. Resolving `auto` is the
caller's job, and `#cfp` IN THIS SAME FILE already does it.

Nothing caught this because every `#venue` call in the readme and in
`test/units.typ` passes an explicit `title:`.

## Where

Run the anchor commands from the FLIGHT ROOT (the directory containing
`core/`, `cfps/`, `todos/` …). Each was run before filing and printed exactly
ONE hit.

**Site 1 — `#venue`'s signature,** in `cfps/0.1.0/src/cfp.typ` (around line
140 as of filing), under the `---- venue ----` banner.

    rg -Fn '#let venue(name, title: auto, call: none, school: none, tags: none, show-tags: true, ..args) = {' cfps/

**Site 2 — `#cfp`'s existing resolution,** same file (around line 282). This
is the PRECEDENT to copy, not a site to change.

    rg -Fn 'let title = if title != auto { title } else if venue == none { none } else { raw(venue) }' cfps/

**Site 3 — the readme's first `#venue` example** (around line 17), for the
documentation step.

    rg -Fn '#venue("acme", title: [Acme University])[A programme that runs every year.]' cfps/

If an anchor does not resolve, widen the `rg` to the flight root. If it is
still gone, STOP and report the miss naming the landmark (the `#venue`
function, `#cfp`'s title resolution, the readme's venue example) rather than
guessing.

## Steps

1. **Site 1 — resolve `auto` inside `#venue`, before the `idea(..)` call.**
   Near the top of the function body, alongside the existing `let own = (:)`
   and `let pos = args.pos()` bindings, add:

       // `auto` titles a venue by its own id, the same resolution `#cfp` makes
       // for the venue it names. `#idea` takes content or `none` and has no
       // `auto`, so this cannot be left for it to sort out.
       let title = if title != auto { title } else { raw(_norm(name)) }

   `_norm` is already imported in this file from `@rookery/core` — confirm
   with `rg -Fn '_norm' cfps/0.1.0/src/cfp.typ` and do NOT add a second
   import. `_norm` is what turns a bare name, an `idea:x` id or a label `<x>`
   into the one string, so `#venue(<acme>)` and `#venue("acme")` title
   identically.

   Leave the `title: title,` argument in the `idea(..)` call below exactly as
   it is — it now receives the resolved value.

   **WHY `raw(<the venue's own id>)` and not `none`:** `#cfp` resolves its own
   `auto` to `raw(venue)`, the id of the venue it names, so a cfp with no
   authored title is called by the venue it belongs to. Titling a venue by its
   own id is the same rule applied one level up, and it keeps the two
   constructors in this file answering `auto` the same way. The alternative —
   defaulting to `none` and letting core derive a title from the body's first
   sixty characters — was considered and rejected: for a venue, that is the
   first sentence of a description rather than a name.

2. **Site 3 and the rest of the readme — document the default.** Add one
   sentence near the first `#venue` example saying that `title:` defaults to
   `auto`, which titles the venue by its own id, and that an authored title
   overrides it. Do not remove the explicit titles from the existing examples;
   they are still what a real venue wants.

3. **Add a regression case to `cfps/0.1.0/test/units.typ`.** Find the file's
   existing `#context { .. }` fixture block or add one in the same style as
   its neighbours, and cover BOTH the crash and the resolution:

       // `#venue`'s own default must not reach `#idea` unresolved — `auto` is
       // not a title `#idea` accepts, and reaching it there fails the compile.
       #context {
         assert.eq(tags-of("units-venue-auto"), ("venue",))
       }

   with the note itself minted above the block as

       #venue("units-venue-auto")[A venue with no authored title.]

   Reaching that assertion at all is the regression: before this fix the
   compile failed outright, so a passing `just test` is the whole test. Import
   whatever the fixture needs (`venue`, `tags-of`) the way the file's existing
   imports do — do NOT restructure its import block.

## Non-goals

- **Do NOT touch `@rookery/core`.** `#idea`'s `title:` contract is content or
  `none`, and teaching it `auto` would put a cfps-shaped decision in core.
- **Do NOT change `#cfp`'s own title resolution** at site 2. It is correct and
  is only the precedent being followed.
- Do not change `#venue`'s other parameters, `VENUE-KEY`, the
  `_merge-base-tags` call, `_opportunity-table`, or the panel.
- Do not change the existing readme examples' explicit titles.
- Do not add a demo project or a demo file.

## VERIFY

Run 1 and 3 from `<flight>/cfps/0.1.0/`.

1. The package's own suite still passes:

       just test

   Expect it to end with `bad-kind OK` (its last check), having printed
   `units OK` and `view OK` before that.

2. The reported failure is actually gone. Create `_venue_check.typ` INSIDE
   `cfps/0.1.0/`:

       #import "/src/lib.typ": venue
       #import "@rookery/core:0.1.0": rookery, tags-of
       #show: rookery
       #venue("v")[body]
       #venue("w", tags: ("draft",))[body]
       #venue("x", title: [Authored])[body]
       #context {
         assert.eq(tags-of("v"), ("venue",))
         assert.eq(tags-of("w"), ("venue", "draft"))
         assert.eq(tags-of("x"), ("venue",))
       }

   Compile it:

       typst compile --features html --root . --format html _venue_check.typ /dev/null

   Expect exit 0, with only the `html export is under active development`
   warning. Before this bird's fix the first `#venue` call alone fails the
   compile with `unexpected argument`, so a clean exit IS the test.

   DELETE `_venue_check.typ` afterwards — it must not be left in the tree.

3. The readme states the default:

       rg -Fn 'auto' readme.md

   Expect at least one hit describing `#venue`'s `title:` default.