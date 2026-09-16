---
id: rk-let-ideate-s-separator-carry-an-id-like-f291ab24
short-id: f2
title: Let ideate's separator carry an id, like it can carry tags
priority: 1
labels:
- ideate
deps: []
closed: false
---
## Problem

`#ideate` (`/home/lox/code/_fcl/rookery/core/0.1.0/src/ideate.typ`, function
starting at line 286) can already give each split-off note a custom *tag* from
inline markup, via the `#ideate-tag(...)` beacon (`pure.typ` line 771) — you
drop `#ideate-tag((foo: "bar"))` anywhere inside a group's body and it works
under **every** `separator:` mode (par, heading, none). There is no equivalent
for a note's **id**. The only way to give a note a fixed id today is:

- `name:` as a function of `(content, labels)` — but per the validation at
  ideate.typ lines ~348-355, this is refused unless `separator:` is
  `heading.where(...)`/`heading(...)`, because the function reads the
  section's own leading heading. In `separator: par` or `separator: none`
  there is no heading to read one off, so the caller cannot set a per-section
  id at all short of restructuring the body into headings just to get a label
  to hang the id off.
- Concretely: a single-note body (`separator: none`) has **no way** to get a
  fixed id via `#ideate` — `name:` must stay `auto` in that mode (see the
  panic message at ideate.typ ~349-354: "must be `auto` (the package counter
  — the default) or a function of `(content, labels)`..."). The only escape
  hatch today is to bypass `#ideate` entirely and call `#idea("fixed-id", ...)`
  directly — but `#idea` has no paged-target passthrough the way `#ideate`
  does (see "PDF has no per-vertebra metadata" / the paged branch at the top
  of `ideate`, ideate.typ ~286-295: `if not (_target() == "html" or
  _target() == "epub") { return body }`), so a caller doing this has to
  reimplement that passthrough by hand to avoid a hard "pagebreaks are not
  allowed inside of containers" error the moment the body contains a
  `pagebreak()` inside a `heading` show rule (`#idea` always wraps its body in
  a `figure()`, even on a paged target — see idea.typ line ~290 onward, no
  `_target()` early-return there at all).

## Fix: an `#ideate-id(...)` beacon, mirroring `#ideate-tag(...)`

Add a public beacon function next to `ideate-tag` in
`/home/lox/code/_fcl/rookery/core/0.1.0/src/pure.typ` (put it directly after
the `ideate-tag` definition at line 771):

```typst
// Public metadata beacon for a fixed ideate id: wrap a string to name a
// section's note explicitly, overriding the `auto` counter (or a `name:`
// function's derived slug) for that one section. Place inline within a
// paragraph, or anywhere in a section's body under any separator — unlike
// `name:` as a function, this beacon does not require `separator: heading`,
// since it carries its own value rather than reading one off a heading.
#let ideate-id(id) = [#metadata((rookery-ideate-id: id))]
```

Add a matching scanner in `/home/lox/code/_fcl/rookery/core/0.1.0/src/ideate.typ`
right after `_ideate-tag-value` (defined at lines 187-192 of that file):

```typst
// Extract the id value from an `#ideate-id` metadata beacon, or `none` if
// this child is not one. Mirrors `_ideate-tag-value` exactly.
#let _ideate-id-value(c) = {
  if c.func() != metadata { return none }
  if type(c.value) != dictionary { return none }
  if "rookery-ideate-id" not in c.value { return none }
  c.value.rookery-ideate-id
}
```

Wire it into the emit loop (ideate.typ, inside the `for group in groups {
... }` loop, same place the existing tag-beacon fold lives — grep
`beacon-tags` around line 507-517):

1. After the existing `let beacon-tags = group.fold(...)` block, add:
   ```typst
   let beacon-ids = group.fold((), (acc, c) => {
     let v = _ideate-id-value(c)
     if v == none { acc } else { acc + (v,) }
   })
   if beacon-ids.len() > 1 {
     panic(
       "ideate: more than one #ideate-id beacon in one section — got "
         + repr(beacon-ids) + ". Only one id per note.",
     )
   }
   let beacon-id = beacon-ids.at(0, default: none)
   ```
2. `_strip-beacons` (pure.typ / ideate.typ line 196:
   `#let _strip-beacons(children) = children.filter(c => _ideate-tag-value(c)
   == none)`) currently only strips tag beacons. Change its filter so it also
   drops an id beacon: `children.filter(c => _ideate-tag-value(c) == none and
   _ideate-id-value(c) == none)`. Otherwise `#ideate-id(...)` renders a stray
   empty `metadata` element into the note's body — harmless visually but
   pointless to leave in.
3. Where the emit loop currently decides between `mint(...)` with or without
   a `name:` (ideate.typ, the `if not (title-fn or name-fn) or lead-heading ==
   none { ... } else { ... }` branch and the `name-value` computation inside
   it, roughly lines 516-545): `beacon-id`, when present, must win over both
   `auto` and any `name:` function — it is the one mechanism that also works
   in `par` and `none` mode, where there is no heading to feed a `name:`
   function at all. Concretely: compute `beacon-id` **before** checking
   `name-fn`/`heading-mode`, and if `beacon-id != none`, call `mint(rest-or-group,
   ..title-arg, tags: group-tags)` with that id passed through however
   `#idea`'s own positional `name` argument is threaded (see how `mint =
   idea.with(...)` is built around line 386, and how a name currently reaches
   `idea(...)` — trace `name-value` to its call site to find the exact
   positional-argument plumbing).
4. `none`-mode currently short-circuits before the per-group loop even
   builds (`if none-mode { (body.children,) }` at ideate.typ ~410, and
   `# `none` MODE NEVER ENTERS THE LOOP` comment above it, ~397-402) — no,
   correction: read that comment again before implementing. It says none-mode
   builds ONE group holding every child and DOES still go through the same
   `for group in groups` emit loop below (the comment says "one group with
   content in it is minted, which is the whole of what `none` means" — it
   never enters the *splitting* loop that watches for a separator, but it
   does still hit the per-group scan/mint code). So a `#ideate-id(...)` beacon
   dropped anywhere in a `separator: none` body should already be scannable
   by the same `group.fold` used for tags, once wired per step 1 above — this
   is the case that matters most, since it is the one with no other fix.

## Non-goals

- Do not change `#idea`'s own signature or add a `#idea`-level beacon — this
  is purely an `#ideate`-level convenience, since `#idea` already takes a
  literal id as a plain positional argument.
- Do not touch the `name:` function path's existing behaviour (heading-mode,
  `str(label)`) — it already works (verified in a real project, `waterline`,
  by hand) and this bird only adds a second, independent way to name a note
  that also works outside heading-mode.
- Do not attempt to also add an inline title/label-setting beacon in this
  bird — only id. (A parallel `#ideate-title(...)` may be worth a separate
  bird later; out of scope here.)

## VERIFY

From `/home/lox/code/_fcl/rookery`, add a case to whatever test suite already
exercises `ideate` (grep `test/` for existing `ideate` test files first —
there is a `test/units.typ` referenced in ideate.typ's own comments, line
~256, that is the most likely home) covering:

1. `separator: none` with a single `#ideate-id("fixed-name")` beacon anywhere
   in the body mints a note whose id is `fixed-name`, not an auto-generated
   counter value.
2. `separator: par` with two paragraphs, one carrying `#ideate-id("second")`,
   produces one auto-named note and one named `second`.
3. Two `#ideate-id(...)` beacons inside the same section is a build error
   naming both ids (per the panic added in step 1 above).

Run whatever command the project's own `README.md` or `Justfile` names for
its Typst test suite (check for a `just test` recipe or a `typst-test`/`tt`
invocation before guessing) and confirm the new cases pass and no existing
`ideate` test regresses.