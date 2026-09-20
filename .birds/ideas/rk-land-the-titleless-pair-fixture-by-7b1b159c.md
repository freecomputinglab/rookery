---
id: rk-land-the-titleless-pair-fixture-by-7b1b159c
short-id: 7b1
title: Land the titleless-pair fixture by settling the permalink read
priority: 3
labels:
- fix-permalink-replay-convergence
deps: []
closed: true
---
Touches: core/0.1.0/src/urls.typ, core/0.1.0/src/transclusion.typ, core/0.1.0/src/core.css, core/0.1.0/demo/rheo/content/titleless-pair.typ, core/0.1.0/demo/rheo/check.sh

Two titleless notes on one vertebra of a multi-vertebra spine now mint correct,
distinct ids — but the demo still cannot build that case at full scale, so the
fixture proving it was held back and core ships the fix with no regression test.
This bird lands the fixture by removing the last thing stopping it.

## What already happened

A previous bird scoped the titleless-note container ordinal to its own vertebra
and cut several redundant `state("rheo-handle")` reads. Its own VERIFY passed:
`just test`, `just check` and `just check-versions` are green, and the
two-titleless-note case compiles cleanly in an isolated two-vertebra project.

What it could NOT do was add its own fixture. Dropping
`demo/rheo/content/titleless-pair.typ` into the full demo pushes that document
back over Typst's five-attempt budget, so the fixture AND its `check.sh`
assertion were both withheld. They are the deliverable here.

## The remaining cause, as measured

`_permalink` re-reads `state("rheo-handle")` every time a note's card is
replayed somewhere other than its authoring site — that is, whenever a
`#window` or a transclusion renders it. Anchors:

```
rg -n '_permalink' /home/lox/code/_fcl/rookery/core
```

names both the definition in `core/0.1.0/src/urls.typ` and its callers; the two
replay callers are `_window-content` and `_flatten`'s IK rule, both in
`core/0.1.0/src/transclusion.typ`. `urls.typ`'s own comment already documents
this class of instability — a context read replayed across the spine — as a
known characteristic.

The intended mechanism for fixing it is rheo's per-`#document` link rule, which
rewrites a native Typst `link()` context-free: it takes the page handle as a
plain argument and already handles both label links and the `rheo-page:` URL
scheme. That was confirmed against rheo's own `docs/link-rule.md` and
`crates/core/src/typ/rheo.typ`.

## Why this is not a one-line change

`link()` renders as a bare `<a href="..">` with NO attributes. This was verified
empirically, not assumed. `_permalink` today emits a classed anchor carrying
`class="idea-label"`, `data-rookery` and `title`, and those attributes are
styled and queried elsewhere. Preserving them means restructuring the DOM — the
attributes move onto a wrapping inner element — and that ripple reaches
`core.css` and every package that renders a note's card: `search`, `todos`,
`timeline`, `meetings`, `pinboard`, `slipshow`.

**That ripple is the reason this bird exists as its own bird**, and it is also
the reason for the hard scope rule below.

## Steps

1. Reproduce the limit first, before changing anything. Write
   `core/0.1.0/demo/rheo/content/titleless-pair.typ`: two titleless, unnamed,
   untitled notes on one vertebra, each body carrying a distinctive grep marker
   in the shape the existing fixtures use (`TITLELESSONEBODY`,
   `TITLELESSTWOBODY`). From `core/0.1.0/demo/rheo/`, run `rheo compile .` and
   record exactly what it prints. Quote that output in your report — it is the
   baseline every later step is measured against.

2. Change `_permalink` in `core/0.1.0/src/urls.typ` to emit a native `link()`
   so rheo's link rule can rewrite it without a context read. Keep the
   `handle:` parameter route that already exists for callers who know their
   handle.

3. Restore the attributes by wrapping, not by reaching for a classed anchor
   again: put `class="idea-label"`, `data-rookery` and `title` on an element
   inside or around the link, whichever keeps the rendered card visually
   identical. Update `core/0.1.0/src/core.css` to match the new nesting.

4. Re-run step 1's command. State plainly whether the `did not converge`
   warning is gone. If it is not, STOP — do not proceed to step 5, and report
   what you measured, because the fixture cannot land while the demo cannot
   build it.

5. Only once step 4 is clean: add the assertion block to
   `core/0.1.0/demo/rheo/check.sh`, appended after the last numbered block and
   before the `if [ "$fail" -ne 0 ]` summary (anchor:
   `rg -n 'demo/rheo: FAILED' /home/lox/code/_fcl/rookery/core`, one hit).
   Assert that both notes minted a page of their own under `ideas/`, that the
   two page names differ, that neither is a bare number, and that each page
   renders its own marker. Follow the surrounding style — a
   `[ -f ... ] || note "..."` per assertion, no test framework.

6. Comment the fixture with why it exists: two titleless notes on one vertebra
   of a multi-vertebra spine is the case that did not converge, so nobody
   collapses it back to one note.

## Non-goals

- **Do not edit any package other than `core`.** If your DOM restructuring
  would break `search`, `todos`, `timeline`, `meetings`, `pinboard` or
  `slipshow`, that is a finding to REPORT, not a licence to edit them. Say
  which package, which selector, and what would have to change. A follow-up
  bird will carry it.
- **Do not change how any id is derived.** Ids are settled; this is about how
  a link to one is rendered.
- **Do not make the card look different.** The rendered result should be
  visually identical — this is a change of markup, not of design.
- **Do not delete or weaken the fixture to get a green run.** If it cannot
  converge, the honest outcome is step 4's STOP, with the measurement.
- **Do not edit anything in `/home/lox/code/waterline`.**

## Uncertainty, and the fallback

It is NOT certain that `_permalink` is the last cause. The previous bird
narrowed the failure to it by elimination and could not attribute the residual
to any single other call site, but the demo is large (60+ notes, heavy
`#window` nesting in `content/sub/deeper/page.typ`) and more than one thing may
be spending attempts. If step 4 shows improvement but not a clean run, say how
far it moved — the number of attempts, or which state the warning now names —
so the next bird starts from a measurement rather than a guess.

If the attribute-preserving wrap in step 3 turns out to be impossible without
touching other packages, stop at step 4's measurement and report. Landing a
converging demo with a visually broken card is not an acceptable trade.

## VERIFY

1. From `core/0.1.0/demo/rheo/`, `rheo compile .` prints no line containing
   `did not converge`, with `titleless-pair.typ` present.
2. From `core/0.1.0/demo/rheo/`, `just check` passes and prints `demo/rheo OK`,
   including the new assertion block.
3. `ls build/html/ideas/` after that build lists two distinct pages for the two
   titleless notes, and neither is named by a bare number.
4. From `core/0.1.0/`, `just test` passes.
5. From `core/0.1.0/demo/pure/`, that demo's own check still passes — the
   permalink must still render with no rheo present.
6. From the repository root, `just check-versions` still prints its OK line.