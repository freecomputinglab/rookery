---
id: rk-stamp-and-tag-filter-panel-rows-once-b74611b3
short-id: b7
title: Stamp and tag filter-panel rows once
priority: 4
labels:
- chore-search-review
deps: []
closed: false
---
`#filter-panel` formats each row's date three times to sort once, and then asks
"does any row carry this tag" by rebuilding every row's tag list once per pill.
On the site its own comments cite — 47 derived pills — that second one is tens of
thousands of redundant dictionary walks per page.

Touches: /home/lox/code/_fcl/rookery/search/0.1.0/src/filter-panel.typ

## What is wrong

### The date, computed three times per row

`/home/lox/code/_fcl/rookery/search/0.1.0/src/filter-panel.typ` lines 237-241:

```typ
  let stamp = r => _date-stamp(when(r))
  let asc = rows.filter(r => stamp(r) != none).sorted(key: stamp)
  let dated = if order == "soonest" { asc } else { asc.rev() }
  let undated = rows.filter(r => stamp(r) == none)
  let rows = dated + undated
```

`stamp` calls the caller's own `when:` adapter AND `_date-stamp`
(`src/base.typ:91`, a `datetime.display`). It runs once per row in the first
filter, once per row in the second, and again for every sort-key read. The
`when:` adapter is arbitrary caller code — `@rookery/timeline` passes one that
derives a date from a dated log — so this is not merely a formatting call.

### The carried-tag test, O(pills x rows)

Line 258:

```typ
  let carried = named.filter(t => rows.any(r => _row-tags(r).contains(t)))
```

`_row-tags` (`src/base.typ:72-77`) reads `tags-dict` and calls `.keys()`, or
falls back to `tags`. This rebuilds that array for every (pill, row) pair. With
`pills: auto` the pill list is derived from the rows themselves — the comment at
lines 52-53 cites a real site with 47 auto-derived pills — so a few hundred rows
times 47 pills is over ten thousand dictionary walks, per panel, per page.

`_row-tags(r)` is also called three more times per row inside `draw` (lines 272,
273, 279) and `_flat-tags-of(r)` once per row at line 247.

Line numbers are as of filing. If they have shifted, match the quoted text.

## Decisions already made — do not re-derive

- **Keep the partition, not a `.rev()` of one sorted list.** The `order:`
  argument's own comment (lines 167-180) records why: reversed, the undated rows
  would land at the TOP. Undated last in both orders is the contract.
- **The carried test becomes a membership test against a set built in one pass
  over the rows.** A Typst dictionary is the set: `t in seen` is a key test,
  which is the same device `_stopwords` in `src/compress.typ:34-36` uses and for
  the same reason.
- **`carried` must keep `named`'s order.** An authored `pills:` list keeps the
  caller's order and a derived one is sorted; filtering `named` preserves
  whichever it was. Do not rebuild `carried` from the rows' own tag order.

## Steps

1. Replace the sort block (lines 237-241) with one pass that computes each
   row's stamp once:

   ```typ
     // One `when(r)` and one `display()` per row: the adapter is caller code and
     // the stamp is a datetime format, and both were being redone per filter and
     // per sort-key read.
     let stamped = rows.map(r => (row: r, stamp: _date-stamp(when(r))))
     let asc = stamped.filter(e => e.stamp != none).sorted(key: e => e.stamp)
     let dated = (if order == "soonest" { asc } else { asc.rev() }).map(e => e.row)
     let undated = stamped.filter(e => e.stamp == none).map(e => e.row)
     let rows = dated + undated
   ```

   Keep the comment above it (lines 233-236) — every claim in it stays true.

2. Replace line 258's `carried` with a one-pass set:

   ```typ
     // ONE PASS OVER THE ROWS, not one per pill: `pills: auto` derives its list
     // from the rows themselves, so a per-pill scan is quadratic in exactly the
     // case the mode exists for. A dictionary key test answers the same question.
     let seen = (:)
     for r in rows {
       for t in _row-tags(r) { seen.insert(t, true) }
     }
     let carried = named.filter(t => t in seen)
   ```

   Keep the existing comment above it (lines 254-257), which says what `carried`
   is for; add nothing about what it used to be.

3. Hoist the repeated `_row-tags(r)` inside `draw` (the closure beginning at
   line 265). Bind it once at the top of that closure —
   `let row-tags = _row-tags(r)` — and use it at lines 272, 273 and 279 in place
   of the three separate calls.

## Do NOT

- Do not change the row order, the pill order, the chip order, or which pills
  and chips appear.
- Do not change `_row-tags`, `_flat-tags-of` or `_date-stamp` themselves — they
  are in `src/base.typ`, which this bird does not touch.
- Do not touch `src/panel.typ`'s `_panel-shell` or `#panel`.
- Do not reword comments beyond what steps 1-3 say — a separate bird covers this
  package's comment prose.
- Do not edit anything under `test/`.

## VERIFY

All three are green today and must stay green:

```sh
cd /home/lox/code/_fcl/rookery/search/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/search/0.1.0 && just parity
cd /home/lox/code/_fcl/rookery/search/0.1.0/demo/rheo && just check
```

Expected: `pass 123` / `fail 0`; six `OK` lines from parity; `demo/rheo OK`.

The demo is the decisive one here, and it covers both halves directly. Its
`check.sh` prints, among its assertions:

```
auto pills: ['auto-x', 'auto-y'], chips ['auto-x'], 2 rows, query tags [...]
query channel: 18/18 rows carry data-panel-all-tags
```

The first is `pills: auto` end to end — the derived list, the `tag-filter:`
narrowing, `carried`, and the chip vocabulary — and the second is the row
attributes `draw` emits. A wrong `carried` changes the pill array in that line;
a wrong sort changes the row order in the built HTML.