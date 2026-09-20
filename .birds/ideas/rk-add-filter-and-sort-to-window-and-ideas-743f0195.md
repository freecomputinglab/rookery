---
id: rk-add-filter-and-sort-to-window-and-ideas-743f0195
short-id: '743'
title: Add filter and sort to window and ideas
priority: 3
labels:
- feat-selection-arg-parity
deps:
- blocked-by:rk-add-outline-target-idea-front-door-52bfc795
closed: true
---
Touches: core/0.1.0/src/window.typ, core/0.1.0/src/data.typ, core/0.1.0/test/units.typ, core/0.1.0/readme.md

Three functions in `@rookery/core` select ideas, and each offers a different slice of one query
language:

| | `tags` | `match` | `filter` | `sort` |
| --- | --- | --- | --- | --- |
| `#window` | yes | yes | **no** | yes |
| `ideas()` | yes | yes | **no** | **no** |
| `#ideas-outline` | yes | yes | yes | no (and must not — see the non-goals) |

`filter:` is the one that matters. `tags:`/`match:` can say "any of these" and "all of these"
and nothing else, so `draft but not phd`, or `(phd and draft) or todo`, is unexpressible — the
author drops out of `#window` entirely and hand-rolls a loop over `ideas()`. The packages built
on core already treat the trio as one vocabulary: `todos-list(tags, match, filter, ..)`
(`todos/0.1.0/src/views.typ` line 188 as of filing) and
`timeline-upcoming(tags, match, filter, ..)` (`timeline/0.1.0/src/upcoming.typ` line 270) both
carry all three. Core is the layer that does not.

The machinery is already in place. `_tag-pred(tags, match, filter: none)`
(`core/0.1.0/src/pure.typ` line 150 as of filing) takes the caller's predicate and ANDs it with
the tag test, and `#ideas-outline` already passes one through. This bird gives the other two
callers the same argument, and gives `ideas()` the `sort:` that `#window` already has.

## Steps

1. **`#window` — add the argument.** Find its selection arguments:

   ```
   rg -n 'match: "any",' /home/lox/code/_fcl/rookery/core/0.1.0/src/window.typ
   ```

   One hit as of filing, line 112, near the end of the multi-line `#let window(..)` parameter
   list (`tags: none,` above it, `sort: auto,` below). Add `filter: none,` to that group. Give
   it a short comment in the file's style saying it is a predicate over the idea's tag
   DICTIONARY, ANDed with `tags:`/`match:` rather than replacing them, and that it is what
   expresses a selection those two cannot — exclusion, or an OR of ANDs.

2. **`#window` — assert it.** The function's other asserts sit together just below the
   signature:

   ```
   rg -n '_assert-match\(match, "#window' /home/lox/code/_fcl/rookery/core/0.1.0/src/window.typ
   ```

   One hit as of filing, line 126. Add a `filter` assert beside it, worded like the one
   `#ideas-outline` already carries (`rg -n 'filter. must be none or a' core/0.1.0/src/outline.typ`,
   one hit, line 471 as of filing):

   ```typ
   assert(
     filter == none or type(filter) == function,
     message: "@rookery/core: #window's `filter` must be none or a function taking the "
       + "idea's tag dictionary — got " + repr(filter),
   )
   ```

3. **`#window` — plumb it through.** The one place the predicate is built:

   ```
   rg -n 'let pred = _tag-pred\(tags, match\)' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   One hit as of filing, `window.typ` line 264, inside the `context` block that selects the
   tagged ideas. Change it to `_tag-pred(tags, match, filter: filter)`.

   **Read the four lines around it before editing.** The branch reads
   `if pred == none { () } else { .. }` — `_tag-pred` returns `none` when there is nothing to
   filter by, and with a `filter:` and no `tags:` it now returns a predicate where it used to
   return `none`. That is correct and is what makes `#window(filter: ..)` with no `tags:` work,
   but check the surrounding `if tags == none { () }` guard on the line above: as of filing
   the tagged branch is skipped entirely when `tags == none`, so a filter-only window would
   select nothing. Change that guard to run whenever `tags != none or filter != none`.

4. **`ideas()` — add both arguments.** Find the signature:

   ```
   rg -n 'let ideas\(tags: none' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   One hit as of filing, `data.typ` line 273:
   `#let ideas(tags: none, match: "any", index: none, values: false)`. Add `filter: none` and
   `sort: auto`, keeping `index:`/`values:` last. Assert both — the `filter` assert exactly as
   in step 2 with `#ideas'` as the subject, and the `sort` assert modelled on `#window`'s
   (`rg -n 'sort. must be auto' core/0.1.0/src/window.typ`, one hit, line 137 as of filing),
   naming the same three legal values.

5. **`ideas()` — plumb the filter.** In the same function:

   ```
   rg -n 'let keep = _tag-pred\(tags, match\)' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   One hit as of filing, `data.typ` line 287. Change it to
   `_tag-pred(tags, match, filter: filter)`. The `.filter(..)` call below it already handles a
   `none` predicate (`keep == none or keep(..)`), so nothing else on that chain changes.

6. **`ideas()` — plumb the sort.** Directly below, the chain opens
   `.sorted(key: ((id, _)) => id)` (line 289 as of filing), which is the id order this function
   has always published. Reuse the existing helper rather than writing a second ordering:

   ```
   rg -n 'let _sort-ids' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   One hit as of filing, `pure.typ` line 262 — `_sort-ids(ids, reg, sort)`, which returns
   id-ascending for anything but `"date"` and date-descending with id-ascending ties for
   `"date"`. Filter first, then order the surviving ids through it, then map. `auto` and
   `"lexicographic"` both mean the id order this function already published, so only `"date"`
   changes anything; say that in the comment, because a reader will otherwise expect `auto` to
   mean something separate.

7. **Unit asserts.** `core/0.1.0/test/units.typ` already exercises `_tag-pred` — find the
   block:

   ```
   rg -n '_tag-pred\(\(draft: none\), "any"\)' /home/lox/code/_fcl/rookery/core/0.1.0/test/units.typ
   ```

   One hit as of filing, line 316, inside the `_tag-pred` section. Add asserts beside it for
   the combination this bird makes reachable from two more callers: a `filter:` with no
   `tags:` returns a predicate rather than `none`; a `filter:` AND a `tags:` is an AND, not an
   OR (a tag match that fails the filter is rejected, and vice versa). `_sort-ids` needs no new
   assert — it is unchanged.

8. **Readme — document the two new arguments** where `#window` and `#ideas()` are documented,
   in the same register as `#ideas-outline`'s existing `filter:` paragraph
   (`rg -n 'ideas-outline\(filter:\). receives the tag DICTIONARY' core/0.1.0/readme.md`, one
   hit, line 127 as of filing). State once, for all three, that `filter:` takes the tag
   DICTIONARY — `t => "phd" in t` tests keys, and `t.any(..)`/`t.all(..)`/`t.at(0)` are not
   available on a dictionary.

9. **Readme — fix a phantom argument.** One passage documents an argument that does not exist:

   ```
   rg -n 'ideas-outline\(sort: "date"\)' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   One hit as of filing, line 114, in the `minted` → `created` migration note: "the same
   date-descending sort behind `#ideas-outline(sort: "date")`". `#ideas-outline` has no `sort`
   argument and is not getting one (see the non-goals). The function that does is `#window` —
   correct the spelling to `#window(sort: "date")`, leaving the rest of the sentence intact.

## Non-goals

- **Do not give `#ideas-outline` a `sort:` argument.** An outline is a TREE whose nesting is
  each idea's literal containment depth, built by `_nest-outline` from a flat run in document
  order. Reordering that run by date would reparent entries under whatever preceded them. If a
  date-ordered list of ideas is wanted, that is `ideas(sort: "date")`, which this bird adds.
- **Do not add `scope:` to `#window` or `ideas()`.** Both read the whole registry and have no
  page notion to narrow to.
- **Do not unify `limit:`.** `#window`'s `limit:` truncates ONE idea's body to a number of
  blocks; `todos-list`'s truncates a number of ROWS. Same word, different units, deliberately
  untouched here.
- **Do not change `_tag-pred` or `_sort-ids`.** Both already do what these callers need; this
  bird is wiring, not new machinery.
- **Do not change any existing default.** `#window` and `ideas()` with no new argument must
  render exactly what they render today — that is what VERIFY's demo checks are for.

## VERIFY

1. `cd core/0.1.0 && just test` — prints `units OK`, including the new `_tag-pred` asserts.
2. `cd core/0.1.0/demo/pure && just build` — succeeds, output unchanged.
3. `cd core/0.1.0/demo/rheo && just check` — succeeds. (Needs the `rheo` binary, present at
   `~/.cargo/bin/rheo` when this bird was filed; if it is genuinely missing, say so in the
   report rather than skipping quietly.)
4. A filter-only window selects. From `core/0.1.0`:

   ```
   mkdir -p demo/pure/build
   printf '#import "/src/lib.typ": *\n#show: rookery\n#idea(<a>, tags: "keep")[AAA]\n#idea(<b>, tags: "drop")[BBB]\n#window(filter: t => "keep" in t)\n' > demo/pure/build/filter-only.typ
   typst compile --features html --format html --root . demo/pure/build/filter-only.typ demo/pure/build/filter-only.html
   grep -c AAA demo/pure/build/filter-only.html
   grep -c BBB demo/pure/build/filter-only.html
   ```

   The first grep must print a non-zero count and the second must print `0`. Then remove both
   scratch files.
5. `rg -n 'ideas-outline\(sort:' core/0.1.0/readme.md` returns nothing.
6. `bd status <this bird's id>` reports `retired` after the flight lands.