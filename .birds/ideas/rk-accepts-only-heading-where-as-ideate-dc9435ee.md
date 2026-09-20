---
id: rk-accepts-only-heading-where-as-ideate-dc9435ee
short-id: dc
title: Accepts only heading.where as ideate separator
priority: 3
labels:
- ideate-separator
deps: []
closed: true
---
Touches: core/0.1.0/src/ideate.typ, core/0.1.0/readme.md, core/0.1.0/test/units.typ

`#ideate` (in `@rookery/core`) accepts its `separator:` argument in five
spellings. Two of them name a heading level: the selector
`heading.where(level: 2)` and the element `heading(level: 2)[]`. Drop the
element form. After this bird the only heading spelling accepted is
`heading.where(level: N)`, for ANY N — not just 2 — and the element form
raises `#ideate`'s own panic instead of being honoured.

Why the element form goes: it exists only because `heading(level: 2)` bare is
illegal Typst (`error: missing argument: body`, since `heading` takes its body
positionally), so the element form has to carry a pointless `[]` to be written
at all. That is a trap dressed as a convenience — the selector spelling is
Typst's own idiom for naming a heading level, needs no empty body, and already
works. One accepted spelling is better than two when one of them is a
footgun.

`heading.where(depth: N)` must KEEP working — it is a second field spelling of
the same selector, already accepted, and nothing here changes that.

## Where the code is

All in `core/0.1.0/src/ideate.typ`. Run every `rg` from the repository root
(`/home/lox/code/_fcl/rookery`) so a moved file still resolves.

1. The classification block inside the `ideate` function.

   ```
   rg -n 'let heading-elem = type\(separator\)' core/0.1.0
   ```

   One hit, `src/ideate.typ:357` as of filing, inside `#let ideate(..)`. The
   three lines there are:

   - `let heading-elem = type(separator) == content and separator.func() == heading`
   - `let heading-sel = type(separator) == selector`
   - `let heading-mode = heading-elem or heading-sel`

2. The level-resolution line, immediately after the validation panic.

   ```
   rg -n 'let want = if heading-elem' core/0.1.0
   ```

   One hit, `src/ideate.typ:373` as of filing, inside `#let ideate(..)`. It
   reads `let want = if heading-elem { _level-of(separator) } else if heading-sel { _sel-level(separator) }`.

3. The validation panic message listing the accepted spellings.

   ```
   rg -n 'must be one of `par`' core/0.1.0
   ```

   One hit, `src/ideate.typ:363` as of filing, inside `#let ideate(..)`. The
   message runs from line 362 to line 371 and ends `+ repr(separator),`.

4. The file-header comment block documenting the spellings.

   ```
   rg -n 'the same, as an element' core/0.1.0
   ```

   Two hits, one per file — `src/ideate.typ:37` (the five-row list under the
   comment heading `// ---- Choosing what starts a note: \`separator:\` ----`)
   and `readme.md:597` (a table row). Both are the element form's own
   documentation and both go.

5. The readme prose asserting the element form is supported.

   ```
   rg -n 'stays supported and needs no string' core/0.1.0/readme.md
   ```

   One hit, `readme.md:632` as of filing, in the section headed
   `### Choosing what starts a note`.

   ```
   rg -n 'naming both accepted forms' core/0.1.0/readme.md
   ```

   One hit, `readme.md:658` as of filing, same section. It says the panic names
   "both accepted forms" — after this bird there is one.

Anchors 4 and 5 are on text this bird DELETES. They stop matching once the step
lands, which is expected and is why they must not appear in VERIFY. If an
anchor does not hit at the start, widen the search to the repository root; if it
is still gone, stop and report the miss rather than guessing where the text
went.

## Steps

1. In `src/ideate.typ`, delete the `heading-elem` binding and rewrite
   `heading-mode` to be `heading-sel` alone. Keep the `heading-mode` NAME — it
   is read in four places further down (the `if not (none-mode or heading-mode
   or par-mode)` gate, the group-splitting `is-separator` branch, the
   `lead-i` position lookup, and the title/name/tags-function guard) and none of
   those need to change.

2. Rewrite `let want = ...` to call `_sel-level(separator)` when `heading-mode`,
   with no `heading-elem` branch.

3. Rewrite the validation panic message to name FOUR spellings, not five:
   `par` (every paragraph becomes a note), `parbreak` (the same thing),
   `heading.where(level: 2)` (every heading of that level starts a note — any
   level, and `depth:` works in place of `level:`), and `none` (nothing splits
   — the whole body is one note). Add one sentence telling a caller who wrote
   `heading(level: 2)[]` to write `heading.where(level: 2)` instead. Keep the
   trailing `+ repr(separator),` so the panic still shows what it got. Do NOT
   describe `par` as "the default" in the new message — a sibling bird is
   changing that default, and a message asserting it will be wrong.

4. Update the file-header comment block: the five-row list becomes four rows
   (drop the `heading(level: 2)[]` row). Leave the `(the default)` annotation
   where it is, on the `par` row — it is still true, and a sibling bird moves
   it. The block further down headed
   `// \`heading(level: 2)\` BARE IS ILLEGAL TYPST` currently explains why the
   element form exists and why the bare form cannot be caught here; replace it
   with at most three lines saying that `heading(level: 2)` and
   `heading(level: 2)[]` are both refused, the first by Typst's own compiler
   before this function is reached and the second by the panic above, and that
   `heading.where(level: 2)` is the spelling to use. Follow the project comment
   style in `CLAUDE.md`: describe the present, no history, no "used to".

5. Update `readme.md` in the section headed `### Choosing what starts a note`:
   delete the element-form table row, delete the paragraph anchored by "stays
   supported and needs no string", and reword the "both accepted forms"
   sentence to the singular. The prose anchored by "on its own is illegal
   Typst" should stay in some form but shrink — the bare form is still a thing
   a reader will try — and must no longer present the element form as the
   remedy. Say `heading.where(level: 2)` is the remedy.

6. In `core/0.1.0/test/units.typ`, find the `_level-of` assertions:

   ```
   rg -n '_level-of\(heading\(level: 2\)\[\]\)' core/0.1.0/test/units.typ
   ```

   One hit, `test/units.typ:639` as of filing, in the section headed
   `// ---- #ideate's three pure predicates ----`. `_level-of` itself is NOT
   being removed — it is still called on markup headings found in a body, which
   carry `depth` rather than `level` — so keep the assertions as tests of that
   helper. Add one assertion beside the existing `_sel-level` ones proving a
   level OTHER than 2 resolves, e.g. `#assert.eq(_sel-level(heading.where(level: 1)), 1)`,
   since "any level works" is the claim this bird makes and nothing currently
   pins level 1.

## What NOT to do

- Do NOT remove `_level-of`. It is load-bearing for reading markup headings out
  of the body being split.
- Do NOT change `_sel-level`, its `repr`-parsing regex, or its panic. They
  already accept any level and both field spellings.
- Do NOT change the DEFAULT value of `separator:`. It stays `par` in this bird;
  a separate bird changes it.
- Do NOT add a `title:`/`document.title` behaviour. A separate bird does that.
- Do NOT export a `heading` of your own, or shadow the `heading` element, to
  make the bare form work. That breaks every consumer's `#show heading:` rule
  outright (`error: only element functions can be used as selectors`).
- Do NOT touch any package other than `core/0.1.0`. A repository-wide search
  for `ideate` and `separator:` found no hits outside it.

## VERIFY

Run from `core/0.1.0/`:

1. `just test` exits 0 and prints `units OK`.
2. `cd demo/rheo && just check` exits 0 and prints its own OK line. The demos
   at `demo/rheo/content/ideated.typ` and `demo/rheo/content/ideated-named.typ`
   already use the selector spelling, so they must keep passing untouched.
3. `cd demo/rheo && just check-typst` exits 0.
4. The element form now panics. Write a scratch file OUTSIDE the repository,
   e.g. `/tmp/sep.typ`:

   ```typ
   #import "@rookery/core:0.1.0": ideate
   #ideate(separator: heading(level: 2)[])[== A

   body]
   ```

   and compile it with
   `typst compile --features html --format html /tmp/sep.typ /tmp/sep.html`.
   It must FAIL with `#ideate`'s own `separator:` panic naming
   `heading.where(level: 2)`. Typst has no way to assert a panic inside
   `test/units.typ`, which is why this is a manual step rather than a unit
   assertion. Note that this scratch compile resolves `@rookery/core` through
   the machine's package cache rather than the flight; if it picks up different
   code, say so in the landing message instead of treating it as a failure.
5. `rg -n 'heading.where\(level: 1\)' core/0.1.0/test/units.typ` hits, showing
   the any-level assertion was added.