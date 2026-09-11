---
id: rk-hoist-the-order-array-position-lookup-cc62b00f
short-id: cc6
title: Hoist the order-array position lookup
priority: 4
labels:
- chore-slipshow-review
deps: []
closed: false
---
Fix a quadratic scan in `@rookery/slipshow`'s `_sort-rows`: ordering a deck by
an explicit `order:` array of note names/ids calls `array.position()` once
PER ROW, and `.position()` itself walks the WHOLE `order` array looking for a
match. For a deck of N slips ordered by an array of length M, this is
O(N x M) instead of O(N + M). The same file already solves an equivalent
problem the right way two functions below — `_slip-lookup()` builds one
name/id -> row dictionary in a single pass — so the fix is to do the same
thing here. This bird also adds the test coverage this branch currently
lacks, since `test/units.typ` today never exercises `order:` as a plain
array — only `order: "created"` and `order:` as a function.

Touches: /home/lox/code/_fcl/rookery/slipshow/0.1.0/src/select.typ, /home/lox/code/_fcl/rookery/slipshow/0.1.0/test/units.typ

## Where

`/home/lox/code/_fcl/rookery/slipshow/0.1.0/src/select.typ`, function
`_sort-rows`, the `type(order) == array` branch, lines 129-139:

```typ
#let _sort-rows(rows, order, reverse) = {
  if type(order) == array {
    // Position in `order`, matched against either `name` or `id` so a caller
    // may write whichever form is at hand; a row named nowhere in `order`
    // is unkeyed (`position` already returns `none`), which keeps unnamed
    // rows after every named one and in their incoming (id) order among
    // themselves.
    _sort-pairs(
      rows.map(row => (key: order.position(n => n == row.name or n == row.id), row: row)),
      reverse,
    )
  } else if order == "created" {
```

`order.position(n => n == row.name or n == row.id)` runs once per row in
`rows`, and each call itself scans every element of `order` until it finds a
match (or exhausts the array). A deck built from a large `order:` array pays
the full cross-product.

## Decisions already made — do not re-derive

- The fix is a dictionary built ONCE, mapping every name/id in `order` to its
  position, then a single `.at(.., default: none)` lookup per row — the exact
  shape `_slip-lookup()` (same file, lines 268-275) already uses to solve the
  identical "avoid rescanning a whole list per item" problem:

  ```typ
  #let _slip-lookup() = {
    let by-key = (:)
    for row in ideas(values: true) {
      by-key.insert(row.name, row)
      by-key.insert(row.id, row)
    }
    by-key
  }
  ```

- Build the position map from `order` with BOTH keys per entry, matched to
  `str()` — `order` entries may be strings already, but comparing via
  `str(n)` on both sides keeps the lookup exactly as permissive as
  `.position()`'s `n == row.name or n == row.id` was.
- A row that matches NOTHING in `order` must still sort last, in id order,
  exactly as today — `_sort-pairs` already implements that for any `key:
  none`, so the fix only has to make an unmatched row produce `key: none`,
  the same as `.position()` does when it finds nothing.
- Preference order when a row matches on both `name` and `id` (which cannot
  normally happen for the same row, but preserve the existing precedence
  anyway): try `row.name` first, `row.id` second — matching `.position()`'s
  `n == row.name or n == row.id`, which prefers `name`.

## Steps

1. In `_sort-rows`, replace the array branch's body. Before the
   `_sort-pairs` call, build the lookup once:

   ```typ
   let positions = (:)
   for (i, n) in order.enumerate() {
     positions.insert(str(n), i)
   }
   ```

2. Replace the `.map()` call's `key:` expression from
   `order.position(n => n == row.name or n == row.id)` to:

   ```typ
   key: positions.at(row.name, default: positions.at(row.id, default: none)),
   ```

3. Update the comment above the branch (it currently describes
   `.position()`'s behaviour) to describe the dictionary lookup instead —
   keep the same present-tense explanation of WHY both `name` and `id` are
   tried (a caller may write whichever is at hand) and WHY an unmatched row
   sorts last (it produces `key: none`, which `_sort-pairs` already sorts
   after every keyed row), phrased for the new code rather than for
   `.position()`.

4. Add the missing test coverage. `/home/lox/code/_fcl/rookery/slipshow/0.1.0/test/units.typ`
   registers three notes tagged `slip` for `order:`'s key-function tests —
   `ord-p`, `ord-q`, `ord-r` (lines 181-183) — and a fourth, `slot-a` (line
   229), used by the `slips:` NAME route tests. All four are already placed
   in the document by the time any `#context` block resolves (Typst's
   `.final()`, which `ideas()` uses under the hood, sees every registration
   in the file regardless of source order), so a new test can reuse them
   with NO new `#slip(..)` calls — which matters, because line 69 of this
   file asserts an exact running total of tagged notes
   (`assert.eq(rows.filter(r => "slip" in r.tags-dict).len(), 24)`) and
   registering even one more `#slip(..)` anywhere in the file would break
   that count and require updating both the assertion and the prose above it
   explaining what makes up 24. Reusing existing notes avoids all of that.

   Insert this new top-level `#context` block right after line 255 (the
   closing `}` of the `slips:` NAME route's own context block, which ends
   with the `mixed.at(1).row.name` assertion) and before the `row:` section
   comment at line 257:

   ```typ
   // `order:` also accepts a plain ARRAY of note names, sorting registry rows
   // by position in it rather than by any field on the row. Reuses
   // `ord-p`/`ord-q`/`ord-r` (registered above for the key-function tests)
   // plus `slot-a` (registered above for the `slips:` NAME route tests) — no
   // new notes, so the running total on line 69 does not change. `slot-a` is
   // not named in `order:` below, so it must sort last regardless of the
   // order the other three are given in.
   #context {
     let names = resolve-slips(
       tags: "slip",
       where: r => r.name in ("ord-p", "ord-q", "ord-r", "slot-a"),
       order: ("ord-r", "ord-q", "ord-p"),
     ).map(e => e.row.name)
     assert.eq(names, ("ord-r", "ord-q", "ord-p", "slot-a"))
   }
   ```

## Do NOT

- Do not touch `_slip-lookup()`, `_sort-pairs()`, or the other three branches
  of `_sort-rows` (`"created"`, `"slip-order"`, the function branch) — none
  of them have this problem.
- Do not change `_sort-pairs`' sorting/reversal behaviour.
- Do not add any new `#slip(..)`/`#idea(..)` registrations to
  `test/units.typ` — reuse the four notes named above. If you find yourself
  needing a new registration, stop and reconsider: the existing four are
  enough to prove the fix.
- Do not touch the running-total assertion on line 69 — this bird's test
  addition must not require changing it.

## VERIFY

1. Typst suite green, including the new case:

   ```sh
   cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just test
   ```

   Expect `units OK`. If the running-total assertion
   (`rows.filter(r => "slip" in r.tags-dict).len()`) fails, a new
   registration was added somewhere it should not have been — reuse the
   existing four notes instead.

2. Negative suite unaffected (this bird does not touch anything the panic
   suite exercises, but it must stay green):

   ```sh
   cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && bash test/panics.sh
   ```

3. Full build check:

   ```sh
   cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just check
   ```

   Expect `demo/rheo OK`.