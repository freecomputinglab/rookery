---
id: rk-removes-tagged-idea-from-core-01fd8890
short-id: 01fd
title: Removes tagged-idea from core
priority: 3
labels:
- migrate-tagged-idea
deps:
- blocked-by:rk-moves-timeline-off-tagged-idea-0bec4286
- blocked-by:rk-moves-bibtex-off-tagged-idea-d2589b6e
- blocked-by:rk-moves-todos-off-tagged-idea-01567b4a
- blocked-by:rk-moves-slipshow-off-tagged-idea-7d61a549
- blocked-by:rk-moves-meetings-off-tagged-idea-590c09ca
- blocked-by:rk-moves-cfps-off-tagged-idea-cdba0e98
- blocked-by:rk-moves-search-demo-off-tagged-idea-eb41beb8
closed: false
---
Touches: core/0.1.0/src/idea.typ, core/0.1.0/src/pure.typ, core/0.1.0/src/base.typ, core/0.1.0/readme.md, core/0.1.0/demo/pure/excluded.typ, core/0.1.0/demo/pure/Justfile, core/0.1.0/demo/rheo/content/lib.typ, core/0.1.0/demo/rheo/content/tags.typ, core/0.1.0/demo/rheo/check.sh

Delete the `tagged-idea` factory from `@rookery/core`, and move this package's
own demos and prose onto `idea.with(..)`.

## Why

`#idea` now takes two MERGING tag arguments — `tag:` (one tag name, string
only) and `base-tags:` (none, a string, an array of strings, or a dictionary
binding a value per tag) — which a caller's own `tags:` is merged ON TOP OF
rather than replacing. `idea.with(tag: "note")` is therefore a safe note
constructor, which is the only thing `tagged-idea` ever provided, and the
factory has been a thin wrapper over `base-tags:` since that bird landed.

`.with()` also fixes the factory's worst wart. `tagged-idea` returned a closure
calling the `idea` captured in PACKAGE scope, so a project writing `#let idea =
idea.with(exclude-tags: EX)` did NOT thereby reach a constructor built with the
factory — the project had to name `EX` twice, once on each binding, and
forgetting the second silently published notes it had asked to exclude.
`.with()` chains off whatever it is applied to, so

    #let idea = _idea.with(exclude-tags: EX)
    #let note = idea.with(tag: "note")

inherits the exclusion with nothing named twice. This bird's demo changes are
where that shows up, and the comment explaining the old two-binding
requirement goes with it.

THIS BIRD FLIES LAST. Every other package — `timeline`, `todos`, `slipshow`,
`meetings`, `cfps`, `bibtex` — and `search`'s demo have their own birds moving
them off the factory first. If `rg -Fn 'tagged-idea' .` from the repository
root still shows hits OUTSIDE `core/` when you start, STOP and report it: a
landing is missing and deleting the export now breaks those packages.

## Where

Run the anchor commands from the FLIGHT ROOT (the directory containing
`core/`, `todos/`, `timeline/` …). Each was run before filing and printed
exactly ONE hit at that time. Several sit in text this bird deletes, so they
stop matching once their step lands and must not appear in VERIFY.

**Site 1 — the factory itself and its banner comment,** in
`core/0.1.0/src/idea.typ`. The banner begins at the `#tagged-idea / #tags-of /
#tag-value` header and the definition is below it.

    rg -Fn '#let tagged-idea(..own, value: none, exclude-tags: ()) = {' core/

**Site 2 — `_dedup-tag`'s comments,** in `core/0.1.0/src/pure.typ`, which name
the factory twice ("Defined before the `tagged-idea` factory that calls it" and
"`value:` is the default a factory binds for the tag it prepends (see
`tagged-idea`)").

    rg -Fn 'Defined before the `tagged-idea` factory that calls' core/

**Site 3 — `base.typ`'s exclusion comment** (around line 183).

    rg -Fn 'declared half of the list is a plain ARGUMENT on `#idea` and `#tagged-idea`' core/

**Site 4 — the readme's `tagged-idea` section heading** (around line 1756).

    rg -Fn '### `tagged-idea` — build your own constructors' core/

**Site 5 — the readme's package-scope-capture paragraph** (around line 1897).

    rg -Fn '`tagged-idea` returns a closure that calls the `idea` captured in PACKAGE scope,' core/

**Site 6 — the rheo demo's project-side bindings,** in
`core/0.1.0/demo/rheo/content/lib.typ`, under the banner "THE PROJECT-SIDE
EXCLUSION PATTERN, and why it is TWO bindings".

    rg -Fn '#let tagged-idea = _tagged-idea.with(exclude-tags: EX)' core/

**Site 7 — the rheo demo's tag families,** in
`core/0.1.0/demo/rheo/content/tags.typ` (a `#todo`, a `#person` and a
`#participant`).

    rg -Fn '#let participant = tagged-idea("person", "participant")' core/0.1.0/demo/

(Scoped to `demo/` deliberately: the same text also appears as an EXAMPLE in
`src/idea.typ`'s factory banner, which step 1 deletes. A repo-wide `rg` finds
two hits; the one under `demo/` is this site.)

**Site 8 — the pure demo's exclusion fixture,** in
`core/0.1.0/demo/pure/excluded.typ`.

    rg -Fn '#let note = tagged-idea("note", exclude-tags: EX)' core/0.1.0/demo/

(Scoped to `demo/` for the same reason: `src/idea.typ`'s banner carries the
same line as an example and step 1 deletes it.)

**Site 9 — the pure demo's Justfile comment** (around line 56).

    rg -Fn 'Covers the plain form, a `tagged-idea` wrapper, and a' core/

**Site 10 — `check.sh`'s two comments,** in `core/0.1.0/demo/rheo/check.sh`
(around lines 238 and 506).

    rg -Fn 'exclude-tags: ("private",)` on both `idea` and `tagged-idea`.' core/
    rg -Fn '#participant = tagged-idea("person", "participant")`; the narrower' core/

If an anchor does not resolve, widen the `rg` to the flight root. If it is
still gone, STOP and report the miss naming the landmark (the function, the
readme heading, the demo file) rather than guessing or recreating text.

## Steps

1. **Site 1 — delete `#let tagged-idea(..own, value: none, exclude-tags: ())`
   entirely**, including its whole body and every assert inside it.

   Its banner comment covers three functions — `#tagged-idea`, `#tags-of` and
   `#tag-value`. Keep the parts describing `tags-of` and `tag-value`, delete
   the parts describing the factory, and retitle the header so it names only
   the two that remain.

   The MATERIAL in that banner worth preserving lands on `#idea`'s own `tag:` /
   `base-tags:` comment instead, if it is not already there: that several tags
   make a family a narrowing of a broader one (so a `#window(tags: "person")`
   sees the narrower family too), and that a caller's own value for a tag wins
   outright with no deep merge.

   `lib.typ` re-exports with `#import "idea.typ": *`, so deleting the binding
   removes the export. Do NOT edit `lib.typ`.

2. **Site 2 — fix `_dedup-tag`'s two comments.** `_dedup-tag` STAYS — it is
   what `_merge-base-tags` folds with, and `test/units.typ` pins it. Only the
   sentences naming the factory change: the "Defined before the `tagged-idea`
   factory that calls it" ordering note now concerns `_merge-base-tags`, and
   the `value:` paragraph now describes the default `_merge-base-tags` passes
   per key from a dictionary `base-tags:`.

3. **Site 3 — fix `base.typ`'s exclusion comment** so it names `#idea` alone
   where it currently names "`#idea` and `#tagged-idea`". The rest of that
   comment — why the declared half is an argument rather than a state — is
   unchanged and must survive.

4. **Sites 4 and 5 — rewrite the readme.** The `### tagged-idea — build your
   own constructors` section is replaced by one on building constructors with
   `idea.with(..)`. It must carry, in prose:

   - the three tag arguments and their precedence (`tags:` replaces and is the
     call site's; `base-tags:` and `tag:` merge under it and are a
     constructor's, `tag:` lowest and string-only);
   - the three factory shapes as `.with()` spellings —
     `idea.with(tag: "note")`, `idea.with(base-tags: ("person",
     "participant"))`, `idea.with(base-tags: (todo: (state: "open")))`;
   - why a call site's own `tags:` cannot displace a constructor's tag;
   - the EXCLUSION pattern, rewritten: `.with()` composes, so
     `#let idea = idea.with(exclude-tags: EX)` followed by
     `#let note = idea.with(tag: "note")` inherits `EX` with nothing named
     twice. Site 5's paragraph explains the OPPOSITE — that the factory
     captured `idea` in package scope and so did not inherit — and that
     paragraph goes.

   Then sweep the whole readme: `rg -Fn 'tagged-idea' core/0.1.0/readme.md`
   must reach ZERO, and each remaining hit is either an example to rewrite or a
   claim that is now false.

   **A caveat worth keeping, reworded:** a constructor built from core's
   package-scope `idea` still does not see a project's rebinding. What changed
   is that a project now builds its own constructors off its OWN bound `idea`,
   so the hazard only remains for a constructor a PACKAGE exports — which is
   why `@rookery/slipshow`'s `#slip` still asks for `exclude-tags:` explicitly.

5. **Site 6 — collapse the rheo demo's bindings.** The file currently reads:

       #import "@rookery/core:0.1.0": idea as _idea, tagged-idea as _tagged-idea
       ...
       #let EX = ("private",)
       #let idea = _idea.with(exclude-tags: EX)
       #let tagged-idea = _tagged-idea.with(exclude-tags: EX)
       #let note = _tagged-idea("note", exclude-tags: EX)

   Make it:

       #import "@rookery/core:0.1.0": idea as _idea
       ...
       #let EX = ("private",)
       #let idea = _idea.with(exclude-tags: EX)
       #let note = idea.with(tag: "note")

   Note `note` now chains off the BOUND `idea`, not `_idea`. Replace the
   "BOTH LINES ARE REQUIRED" banner with one saying the opposite and why: a
   constructor built with `.with()` off the project's own bound `idea`
   inherits its `exclude-tags`, so the list is named once. Keep the paragraph
   above it about `exclude-tags` being an argument rather than a
   `rookery.with()` knob — that reasoning is unchanged.

   The `as _idea` aliasing stays: it is what lets the bound name take the
   obvious spelling without shadowing its own right-hand side.

6. **Site 7 — rewrite the rheo demo's tag families** in `tags.typ`:

       #let todo = idea.with(tag: "todo")
       #let person = idea.with(tag: "person")
       #let participant = idea.with(base-tags: ("person", "participant"))

   and drop `tagged-idea` from that file's `#import "lib.typ": ..` line, whose
   remaining names stay. Update the two comments there that name the factory —
   one saying `#todo` is not a package export (still true, reword the
   mechanism) and one near the bottom mentioning "a factory naming both".

   **The families must keep the same tag names and the same order**, because
   `check.sh` asserts on `data-rookery-tags` for `tag-p-person`,
   `tag-p-participant` and `tag-p-both`, and the attribute's order follows the
   constructor.

7. **Site 8 — rewrite the pure demo's exclusion fixture.** `#let note =
   tagged-idea("note", exclude-tags: EX)` becomes a `.with()` chain off the
   demo's own bound `idea`, matching step 5's shape. Update that file's header
   comment (line 1 names `#tagged-idea`), its import line, and the comment
   explaining that the wrapper calls the `idea` captured in package scope —
   which is no longer the mechanism being demonstrated.

8. **Site 9 — update the pure demo's Justfile comment** so "a `tagged-idea`
   wrapper" names a `.with()` constructor. Do NOT change the recipe itself.

9. **Site 10 — update `check.sh`'s two comments.** Both are explanatory only:
   one says `content/lib.typ` binds `exclude-tags` "on both `idea` and
   `tagged-idea`" (now one binding, inherited), the other names
   `#participant = tagged-idea("person", "participant")`. **Do NOT change a
   single assertion, `grep` pattern, slug or `note` call in that file** — the
   behaviour under test is unchanged and the script is the demo's whole
   harness.

Follow the repository `CLAUDE.md`'s comment style throughout: present tense,
describe what is there, no "used to", no issue ids, no interior section
banners.

## Non-goals

- **Do NOT touch any package outside `core/0.1.0/`.** Every other package has
  its own migration bird, which lands before this one.
- **Do not delete `_dedup-tag`.** `_merge-base-tags` folds with it and
  `test/units.typ` pins it.
- Do not remove or change `tag:`, `base-tags:`, `tags:`, `exclude-tags:` or
  any other `#idea` argument. This bird deletes one function and updates
  prose.
- Do not add a deprecation stub, alias, or `panic`-ing shim named
  `tagged-idea`. It goes.
- Do not change `#tags-of` or `#tag-value`, which share the deleted function's
  banner comment but are otherwise untouched.
- Do not change any assertion in `check.sh`, `test/units.typ` or
  `test/inputs.typ`.

## VERIFY

Run 1 and 2 from `<flight>/core/0.1.0/`, 3 from `<flight>/core/0.1.0/demo/pure/`,
4 from `<flight>/core/0.1.0/`, and 5 from the flight root.

1. The unit fixtures compile, which is the package's whole Typst harness:

       just test

   Expect it to end with `units OK`.

2. Nothing can still import the deleted name. Create `_gone_check.typ` INSIDE
   `core/0.1.0/`:

       #import "/src/lib.typ": tagged-idea

   Compile it:

       typst compile --features html --root . --format html _gone_check.typ /dev/null

   Expect it to FAIL, with an error naming `tagged-idea` as unknown. A
   SUCCESSFUL compile here means the export survives and the bird is not done.
   DELETE `_gone_check.typ` afterwards — it must not be left in the tree.

3. The pure demo still builds, exclusion fixture included:

       just build

   Expect it to end with `demo/pure OK`.

4. The rheo demo still builds and passes its checks — this is what proves the
   collapsed exclusion binding still excludes, and that the tag families still
   carry the tags `check.sh` asserts on:

       rheo compile demo/rheo
       ./demo/rheo/check.sh

   Expect `rheo compile` to succeed and `check.sh` to report no failures.
   `rheo` is on PATH on this machine (0.6.3 at filing), clearing the package's
   declared 0.6.2 floor. If it is NOT found, say so in your report and note
   that check 4 could not run — do not edit the demo to work around it.

5. The name is gone from the WHOLE repository, not just this package:

       rg -Fn 'tagged-idea' .

   Expect ZERO hits. A hit outside `core/` means a sibling package's migration
   bird has not landed; report it rather than editing that package here.