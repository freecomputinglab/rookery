---
id: rk-repairs-the-readme-s-dead-ideate-typ-80905735
short-id: '80'
title: Repairs the readme's dead ideate.typ line reference
priority: 2
labels:
- readme-xref
deps: []
closed: false
---
Touches: core/0.1.0/readme.md

`core/0.1.0/readme.md` sends a reader to a comment in `src/ideate.typ` that is
not there. Repair the cross-reference, or drop it.

## The site

```
rg -n 'own comments at line' core/0.1.0
```

One hit, `readme.md:826` as of filing, in the paragraph beginning **A `#ref`
inside the heading contributes nothing to the lambda's input**, under the
heading `### Naming sections with a custom function`. The sentence reads:

> Read `ideate.typ`'s own comments at line 460 for the measured failure, and do
> not attempt it unless you have a very specific reason.

The "measured failure" it promises is about resolving a `#ref` inside a
`name:`/`title:` lambda that is itself about to add to the note registry: the
registry's value can then depend on the node's own output, which breaks
`#ideate`'s convergence.

## Why it is wrong

No such comment exists in `src/ideate.typ`. Confirmed by searching the whole
file for every candidate:

```
rg -n 'MEASURED|converge|convergence' core/0.1.0/src/ideate.typ
```

Six hits as of filing. Five are about other things entirely — the content tree
it walks, a spurious note minted from a lone `parbreak`, the two fields a
heading's level lives in, the reference value for the `context` element, and
the `repr` parse behind `_sel-level`. The sixth, in the comment block directly
above `#let ideate(..)`, says the `context` wrapper introduces no convergence
risk OF ITS OWN — the opposite subject. A whole-directory search finds
`convergence` in only one other file, `src/outline.typ`, which is unrelated.

A bare line number is also the wrong shape for a cross-reference in this
repository even when it resolves: line numbers move on every edit, and this one
has moved several times.

## Steps

1. Search `core/0.1.0/src/` for a comment that genuinely documents the measured
   convergence failure the readme describes — a registry value depending on the
   node's own output. `rg -n 'registry' core/0.1.0/src/*.typ` is the widest
   useful net.
2. If such a comment exists, rewrite the readme sentence to name the FILE and
   the enclosing function or comment block rather than a line number — e.g.
   "see `ideate.typ`'s comment on `_flatten`" — so the reference survives the
   next edit.
3. If it does not exist, the readme is promising an explanation nobody wrote.
   Delete the "Read `ideate.typ`'s own comments at line 460 for the measured
   failure, and" clause and keep the warning that follows it, so the paragraph
   still says do not attempt this without a specific reason. Do NOT invent the
   missing comment in `src/ideate.typ` to make the reference true — if the
   measurement is not recorded anywhere, it is not a fact this repository holds.
4. Check whether any other line-number cross-reference in the same readme has
   gone stale the same way: `rg -n 'at line [0-9]|line [0-9]+ of' core/0.1.0`.
   Repair any hit by the same rule — name the landmark, not the number. Report
   what you found either way.

## What NOT to do

- Do NOT change any behaviour. This is a documentation repair; `src/ideate.typ`
  should come out unmodified unless step 2 finds a comment worth renaming.
- Do NOT add a new line-number reference anywhere.
- Do NOT touch any package other than `core/0.1.0`.

## VERIFY

Run from `core/0.1.0/`:

1. `rg -n 'at line 460' core/0.1.0` returns nothing.
2. `just test` exits 0 and prints `units OK` — unchanged, since no source moved.
3. The paragraph under `### Naming sections with a custom function` still warns
   a reader off resolving a `#ref` inside a registry-adding lambda: `rg -n
   'very specific reason' core/0.1.0/readme.md` still hits.