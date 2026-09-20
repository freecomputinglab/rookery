---
id: rk-hoist-regex-state-reads-out-of-core-s-a04eea8f
short-id: a04
title: Hoist regex/state reads out of core's loops
priority: 3
labels:
- chore-core-review
deps: []
closed: false
---
Two independent hoisting fixes: a regex literal rebuilt on every loop
iteration in `pure.typ`, and a document-wide state resolved fresh inside a
loop in `outline.typ` instead of once before it. Both are the "rebuild inside
a loop what only needs building once" pattern this package's own review
convention treats as a defect (see the retired `rk-cache-bib-keys-drop-dead-cite-walk`
bird for the same category of fix in this same package).

Touches: /home/lox/code/_fcl/rookery/core/0.1.0/src/pure.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/src/outline.typ

## What is wrong

### 1. `_bib-keys-of` rebuilds its regex once per bibliography source

`src/pure.typ:186-204`:

```typ
#let _bib-keys-of(cfg) = {
  if cfg == none { return () }
  let src = cfg.pos().first()
  let sources = if type(src) == array { src } else { (src,) }
  let keys = ()
  for s in sources {
    let text = str(s)
    let entries = text.matches(regex("@\\w+\\s*\\{\\s*([^,\\s]+)\\s*,"))
    ...
```

`regex("@\\w+\\s*\\{\\s*([^,\\s]+)\\s*,")` (line 196) is a fresh regex literal
compiled on every iteration of `for s in sources`. A project can pass several
bibliography sources at once (`bibliography(bytes(a), bytes(b), ...)`, see
`_bib`'s own banner in `src/state.typ`), so this recompiles the same pattern
once per source. The cost is small in absolute terms — `_bib-keys-of` runs at
most once per document build, via `_bib-key-cache` (`src/state.typ`), not once
per note — but it is still the literal "regex built inside a loop" defect this
package's own review rubric names as a performance smell, and the fix is a
one-line hoist with no behaviour change.

### 2. `_page-links` re-resolves the registry once per tag-selected window marker

`src/outline.typ:119-171` (`_page-links`), inside its outer loop:

```typ
  for el in query(<rookery-window-mark>) {
    let v = el.value
    ...
    if not v.at("filtered", default: false) {
      let tagged = v.at("tagged", default: none)
      if tagged != none {
        let pred = _tag-pred(tagged, v.at("match", default: "any"))
        if pred != none {
          for (id, rec) in _registry.final() {
```

The `_registry.final()` call at line 162 sits inside the `for el in
query(<rookery-window-mark>)` loop (starting line 137), and runs again for
EVERY marker in that query result whose `#window` used `tagged:` with no
`filter:`. A page with several `#window(tagged: ..)` calls therefore resolves
the whole document-wide registry once per such call instead of once for the
whole `_page-links` pass. The same file already does this correctly
elsewhere — `_ideas-outline-data` (line 300) hoists
`let ref-text = _ref-text(_registry.final())` once, before its own loop, with
a comment explaining exactly why ("resolved before the loop rather than per
entry"). `_page-links` should follow the same shape.

## Decisions already made — do not re-derive

- **Neither fix changes output.** Both are pure hoists: the same value is
  computed the same way, just once instead of N times. `just test` and the two
  demo suites must produce byte-identical output.
- **Hoist `_registry.final()` to a single `let reg = ...` bound once, before
  the `for el in query(<rookery-window-mark>)` loop**, and replace the inner
  `_registry.final()` call with a reference to that binding. Do not memoize it
  any other way (no extra state, no closure trick) — a plain local `let` is
  the same pattern `_ideas-outline-data` already uses in this file.
- **Hoist the regex in `_bib-keys-of` to a module-level `#let` constant**,
  named `_BIB-ENTRY-RE` (matching this file's existing naming convention for
  module-level constants, e.g. `_ROW-FIELDS` in `data.typ`, `_B36-DIGITS` in
  this same file), defined immediately above `_bib-keys-of`. Reference it
  inside the loop instead of calling `regex(..)` there.

## Steps

1. In `/home/lox/code/_fcl/rookery/core/0.1.0/src/pure.typ`, immediately above
   the `#let _bib-keys-of(cfg) = {` line (currently line 186), add:

   ```typ
   // The BibTeX entry-header pattern `_bib-keys-of` matches against — bound
   // once rather than rebuilt per bibliography source.
   #let _BIB-ENTRY-RE = regex("@\\w+\\s*\\{\\s*([^,\\s]+)\\s*,")
   ```

   Then change line 196 from:

   ```typ
     let entries = text.matches(regex("@\\w+\\s*\\{\\s*([^,\\s]+)\\s*,"))
   ```

   to:

   ```typ
     let entries = text.matches(_BIB-ENTRY-RE)
   ```

   Leave the existing comment on lines 192-194 ("Format is detected from the
   CONTENT, ...") exactly where it is, directly above the `let entries` line.

2. In `/home/lox/code/_fcl/rookery/core/0.1.0/src/outline.typ`, inside
   `_page-links` (currently starting line 119), add one line right after
   `let out = (:)` (currently line 120):

   ```typ
   #let _page-links() = {
     let out = (:)
     let reg = _registry.final()
   ```

   Then, inside the loop, replace the `for (id, rec) in _registry.final() {`
   at line 162 with:

   ```typ
           for (id, rec) in reg {
   ```

   Leave every surrounding comment (the block starting "The one reader that
   CAN resolve a tag selection", lines 150-157) unchanged — it still describes
   the same logic, just reading `reg` instead of calling `.final()` directly.

## Do NOT

- Do not touch `_ideas-outline-data` (`src/outline.typ:269-408`) — it already
  hoists its own `_registry.final()` call correctly and is the model this fix
  copies, not a second target.
- Do not change `_bib-keys-of`'s signature, return shape, or its caller
  `_bib-keys()` (`src/state.typ`).
- Do not touch the `for (id, rec) in _registry.final()` pattern anywhere else
  in the package (e.g. `data.typ`'s `tag-data()`) — those are single reads
  outside a loop already and are out of scope here.
- Do not reword any comment beyond what step 1/2 explicitly show. Comment
  prose cleanup in these two files is covered by separate birds.

## VERIFY

```sh
cd /home/lox/code/_fcl/rookery/core/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/pure && just build
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check-typst
```

Expected last lines: `units OK`, `demo/pure OK`, `demo/rheo OK`, `demo/rheo
(native) OK` — all four green today, and this change must not alter any of
that output, since both fixes are pure hoists with no behaviour change.

Also confirm the regex is no longer rebuilt inline:

```sh
cd /home/lox/code/_fcl/rookery/core/0.1.0 && grep -n 'regex("@' src/pure.typ
```

Expected: exactly one hit, on the new `_BIB-ENTRY-RE` definition line — none
inside `_bib-keys-of` itself.