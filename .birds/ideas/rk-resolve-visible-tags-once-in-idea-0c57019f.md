---
id: rk-resolve-visible-tags-once-in-idea-0c57019f
short-id: 0c
title: 'Resolve visible tags once in #idea'
priority: 4
labels:
- chore-core-review
deps: []
closed: false
---
`#idea` resolves the same visible-tag list four times per note, and binds the
authored title to a second name for nothing. Both are in one function and one
region of one file.

Touches: /home/lox/code/_fcl/rookery/core/0.1.0/src/idea.typ

## What is wrong

`_visible-tags(names)` (`/home/lox/code/_fcl/rookery/core/0.1.0/src/state.typ`
lines 325-328) reads `_invisible-tags.final()` — a document-wide state
resolution — and then filters the array it was handed. `#idea`'s HTML branch
calls it four separate times with the identical argument
`tags.keys()`:

- `src/idea.typ:363` — `let cls = (_c(""),) + _visible-tags(tags.keys()).map(l => _c("tag-" + l))`
- `src/idea.typ:399` — `+ _tags-attr(_visible-tags(tags.keys())),`
- `src/idea.typ:410` — `let box-cls = (_c("box"),) + _visible-tags(tags.keys()).map(l => _c("tag-" + l))`
- `src/idea.typ:435` — `+ _tags-attr(_visible-tags(tags.keys())),`

So every note on every output page pays four state resolutions and four array
filters where one answer serves all four call sites. The sibling code already
does it the intended way: `_window-content` in
`/home/lox/code/_fcl/rookery/core/0.1.0/src/transclusion.typ:165` binds
`let visible = _visible-tags(rec.at("tags", default: (:)).keys())` once and
reuses it for the class list, the box class list and the `data-rookery-tags`
attribute.

Separately, `src/idea.typ:355` is `let ttl = if title == none { none } else { title }`
— an identity: it binds `title` to a second name and nothing else. `ttl` is
read twice, at `src/idea.typ:400` (`if ttl == none { [] } else { ... ttl }`)
and at `src/idea.typ:463` (`if ttl != none { heading(depth: level, ttl) }`).

Line numbers are as of filing. If they have shifted, match the quoted text.

## Steps

1. In `/home/lox/code/_fcl/rookery/core/0.1.0/src/idea.typ`, immediately above
   the `let cls = ...` line (line 363, inside the `#context {` block that opens
   at line 201), insert:

   ```typ
   let visible = _visible-tags(tags.keys())
   ```

   Keep the existing explanatory comment block above `let cls` where it is.

2. Rewrite the four call sites to read `visible` instead of calling again:
   - line 363 becomes `let cls = (_c(""),) + visible.map(l => _c("tag-" + l))`
   - line 399 becomes `+ _tags-attr(visible),`
   - line 410 becomes `let box-cls = (_c("box"),) + visible.map(l => _c("tag-" + l))`
   - line 435 becomes `+ _tags-attr(visible),`

3. Delete the `let ttl = if title == none { none } else { title }` line (355)
   and use `title` directly at both read sites: line 400 becomes
   `if title == none { [] } else { ... }` with `ttl` inside it replaced by
   `title`, and line 463 becomes `if title != none { heading(depth: level, title) }`.
   Leave the comment block above the deleted line (lines 351-354, "THE AUTHORED
   TITLE ONLY. ...") in place — it explains the two read sites, which are still
   there.

## Do NOT

- Do not change `_visible-tags` itself, or anything in `state.typ`.
- Do not touch `_window-content` in `transclusion.typ`; it is already correct.
- Do not hoist anything else out of the `if _target() == "html"` branch, and do
  not move `cls`/`box-cls`.
- Do not reword, shorten or delete comments beyond the one instruction in step
  3. A separate bird covers `idea.typ`'s comment prose; two flights editing the
  same comments is a conflicted nest.
- Do not rename `tags`, `cls`, `box-cls` or any other existing binding.

## VERIFY

All four of these are green today, so each must stay green. Run them in order:

```sh
cd /home/lox/code/_fcl/rookery/core/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/pure && just build
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check-typst
```

Expected last lines: `units OK`, `demo/pure OK`, `demo/rheo OK`,
`demo/rheo (native) OK`. The third is the one that matters most here: its
`check.sh` asserts the `idea-tag-<tag>` classes and the `data-rookery-tags`
attribute on cards, and that an invisible tag leaves no trace — which is
exactly what the four hoisted call sites emit.

Then confirm the bird is what you worked: `bd show <this bird's id>`.