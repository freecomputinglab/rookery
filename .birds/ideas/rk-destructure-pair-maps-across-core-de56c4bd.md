---
id: rk-destructure-pair-maps-across-core-de56c4bd
short-id: de5
title: Destructure pair maps across core
priority: 2
labels:
- chore-core-review
deps:
- blocked-by:rk-resolve-visible-tags-once-in-idea-0c57019f
- blocked-by:rk-query-outline-edges-by-label-682d6913
- blocked-by:rk-move-config-helpers-out-of-data-typ-2d9d7cdd
closed: false
---
Nine closures in this package index into a `(key, value)` pair with `.at(0)` /
`.at(1)` instead of destructuring it. The package already uses the destructuring
form in four places, so this is one convention written two ways.

Touches: /home/lox/code/_fcl/rookery/core/0.1.0/src/data.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/src/idea.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/src/transclusion.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/src/theme.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/src/window.typ

## What is wrong

Typst destructures a closure parameter with a parenthesised pattern, and this
package already relies on it: `src/theme.typ:99` and `src/theme.typ:100` use
`((key, prop)) => ..`, `src/theme.typ:165` uses `((tag, def)) => ..`, and
`src/state.typ:410` uses `((i, body)) => ..`. The placeholder `_` in a pattern
is likewise already used, at `src/links.typ:88` (`for (_, v) in node.fields()`).

Elsewhere the same shape is spelled positionally, which reads worse and hides
what the two halves are. Every site, as of filing:

1. `src/data.typ:190` — `.map(p => (p.at(0), _project-one(p.at(0), p.at(1), tags)))`
2. `src/data.typ:309` — `.sorted(key: p => p.at(0))`
3. `src/data.typ:310` — `.filter(p => keep == none or keep(p.at(1).at("tags", default: (:))))`
4. `src/data.typ:311-312` — `.map(p => { let (id, rec) = p` — destructures, but in the body rather than the parameter
5. `src/data.typ:401` — `.map(p => (p.at(0), p.at(1).at("tags", default: (:))))`
6. `src/idea.typ:368` — `tags.pairs().filter(p => p.at(1) == none).map(p => p.at(0))`
7. `src/transclusion.typ:200` — the same `flat tags` expression as (6)
8. `src/theme.typ:162` — `.filter(p => p.at(0) in visible)`
9. `src/window.typ:268-269` — `.filter(p => pred(p.at(1).at("tags", default: (:)))).map(p => p.at(0))`

One extra thing in the same region of `data.typ`: `_project` (lines 181-192) is
called once per row from inside `ideas()`'s `.map`, and its first statement
after the `none` short-circuit is an `assert` that the index is a value built by
`tag-index(..)` (lines 184-186). That check is about the INDEX, not about the
row, so it fires once per note for one answer. `tag-index` already validates the
spec itself (lines 146-177); this assert exists to catch a caller who passed a
bare dictionary instead, which is knowable before the walk starts.

Line numbers are as of filing. If they have shifted, match the quoted text.

## Steps

Rewrite each site to destructure in the parameter. Behaviour must not change at
any of them.

1. `src/data.typ:190` →
   `.map(((field, spec)) => (field, _project-one(field, spec, tags)))`
2. `src/data.typ:309` → `.sorted(key: ((id, _)) => id)`
3. `src/data.typ:310` →
   `.filter(((_, rec)) => keep == none or keep(rec.at("tags", default: (:))))`
4. `src/data.typ:311` → `.map(((id, rec)) => {` and delete the now-redundant
   `let (id, rec) = p` line inside the body
5. `src/data.typ:401` →
   `.map(((id, rec)) => (id, rec.at("tags", default: (:))))`
6. `src/idea.typ:368` →
   `let flat-tags = tags.pairs().filter(((_, v)) => v == none).map(((k, _)) => k)`
7. `src/transclusion.typ:200` — the same rewrite as (6), applied to
   `rec.at("tags", default: (:)).pairs()`
8. `src/theme.typ:162` → `.filter(((tag, _)) => tag in visible)`
9. `src/window.typ:268-269` →
   `.filter(((_, rec)) => pred(rec.at("tags", default: (:))))` and
   `.map(((id, _)) => id)`

10. Hoist `_project`'s index check out of the per-row path. In `src/data.typ`,
    move the `assert(type(index) == dictionary and "rookery-tag-index" in index, ..)`
    block (lines 184-186) out of `_project` and into `ideas()` (line 298
    onwards), beside the existing `_assert-tags`/`_assert-match` calls at lines
    299-300, guarded so it only runs when an index was given:

    ```typ
      if index != none {
        assert(
          type(index) == dictionary and "rookery-tag-index" in index,
          message: "@rookery/core: `index:` must be a value built by `tag-index(..)` — got " + repr(index),
        )
      }
    ```

    Keep the message string byte for byte. `_project` keeps its
    `if index == none { return (:) }` short-circuit and loses only the assert.
    Add one sentence to `_project`'s comment saying the shape of `index` is
    checked once by `ideas()` before the walk.

## Do NOT

- Do not change any behaviour, message, ordering or field name.
- Do not "simplify" any of the pipelines further — no merging a `.filter` into a
  `.map`, no replacing `.pairs()` with anything else.
- Do not touch the four sites that already destructure (`src/theme.typ:99`,
  `:100`, `:165`, `src/state.typ:410`).
- Do not reword comments beyond the one sentence in step 10. Separate birds
  cover the comment prose in these files.
- Do not edit `test/units.typ`.

## VERIFY

```sh
cd /home/lox/code/_fcl/rookery/core/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/pure && just build
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check-typst
```

Expected last lines: `units OK`, `demo/pure OK`, `demo/rheo OK`,
`demo/rheo (native) OK`. All four are green today. `just test` covers `_project`
and `tag-index` directly (both are in `test/units.typ`'s import list), and
`demo/rheo`'s `check.sh` asserts the tag pills, tag classes and tag-themed CSS
that sites (6), (7) and (8) emit.

Then confirm no positional pair indexing is left in these five files:

```sh
cd /home/lox/code/_fcl/rookery/core/0.1.0/src && grep -n "p.at(0)\|p.at(1)" data.typ idea.typ transclusion.typ theme.typ window.typ
```

Expected: no output.