---
id: rk-number-a-note-s-footnotes-from-the-note-6e93f2c0
short-id: 6e
title: Number a note's footnotes from the note, not a counter
priority: 3
labels:
- fix-footnote-counter-replay
deps:
- blocked-by:rk-land-the-titleless-pair-fixture-by-7b1b159c
closed: true
---
Touches: core/0.1.0/src/bib.typ, core/0.1.0/src/state.typ, core/0.1.0/demo/rheo/check.sh

A note's footnote numbering is read back out of a document-wide counter from
inside a show rule, so a note replayed into a `#window` steps that counter a
second time and the numbers a reader sees are whatever the run happened to
settle on. On a real site it does not settle at all.

## The defect, measured

Building the site at `/home/lox/code/waterline` (which is 60+ vertebrae with
heavy `#window` nesting) against this package prints, among other
non-convergence warnings:

```
warning: value of `counter("rheo-idea-fn")` did not converge
    ┌─ @rookery/core:0.1.0/src/bib.typ:174:28
    │
174 │         context _fn-ref(b, _fn-seq.get().first())
    = hint: the following values were observed:
      - run 1: 0
      - run 2: 5
      - run 3: 5
      - run 4: 5
      - run 5: 5
      - final: 1
```

Read the last two lines: the value used through four attempts was `5`, and the
value it finished on was `1`. Those are footnote NUMBERS. A reader gets
whichever the run stopped at.

Three other states fail to converge in that same build, in `urls.typ`,
`outline.typ` and `state.typ`. They are a separate defect about the page
handle and are being fixed by another bird — this one is NOT about them, and
the two do not share a line of code.

## Why it happens

Anchor, one hit:

```
rg -n '_fn-seq.get\(\).first\(\)' /home/lox/code/_fcl/rookery/core
```

printed `core/0.1.0/src/bib.typ:171` (the warning above reports 174 because it
counts the package's own preamble; the anchor is authoritative). The landmark
is `_footnoted`, and the whole shape is:

```typ
_fn-block.step()
context {
  let b = _fn-block.get().first()
  _fn-seq.update(0)
  {
    show FNK: it => {
      _fn-seq.step()
      context _fn-ref(b, _fn-seq.get().first())
    }
    body
  }
  _fn-block-html(notes, b)
}
```

`_fn-seq` is a document-wide counter (`core/0.1.0/src/state.typ:532`,
`#let _fn-seq = counter("rheo-idea-fn")`). Resetting it per note and stepping
it per footnote is correct ONLY if a note's body renders exactly once. It does
not: `@rookery/core`'s own transclusion replays a note's body wherever a
`#window` places it, so the same footnotes step the same counter again in a
different document position, and a `.get()` inside the show rule sees a
different number depending on where in the pass it is read.

## The direction

The sequence number a footnote needs is its index among THAT note's own
footnotes, which this function already computes before the show rule runs:
`let notes = _footnotes(body)` (anchor: `rg -n 'let notes = _footnotes'`, one
hit, same file). An index into a list the function already holds is intrinsic
to the note and identical on every replay, where a counter is a property of
the document position.

So: derive each footnote's number from its position in `notes`, and stop
reading `_fn-seq` inside the show rule.

**This is a direction, not a solved design.** The obvious implementation —
`notes.position(n => n == it)` — is wrong where one note carries two identical
footnotes, because equal content compares equal and both would take the first
index. Decide how to tell two equal footnotes apart before you write the fix,
and state in your report what you chose. If you cannot make it reproducible
without the counter, STOP and report that with your evidence rather than
landing something that merely converges on the demo; a wrong footnote number
that is stable is worse than one that warns.

Whether `_fn-seq` can then be deleted from `state.typ` depends on your
implementation — remove it only if nothing else reads it (`rg -n '_fn-seq'`,
which today prints only this file and its definition). `_fn-block` is a
different counter, numbering the BLOCKS rather than the footnotes within one;
leave it alone.

## Non-goals

- **Do not touch `urls.typ`, `outline.typ` or `state.typ`'s
  `rookery-idea-scope` machinery.** Another bird owns the handle
  non-convergence. Editing those files here will collide in the nest.
- **Do not change the rendered footnote markup or its CSS.** The numbers must
  become stable; how a footnote looks must not change.
- **Do not "fix" this by removing footnote numbering**, or by numbering
  footnotes document-wide instead of per note. Per-note numbering is the
  intended behaviour.
- **Do not edit anything in `/home/lox/code/waterline`.** It is the
  reproduction, not part of this change.

## Uncertainty

It is not established that this is the ONLY thing keeping `rheo-idea-fn`
unstable, only that it is where the warning points. If your fix removes the
read and the warning persists in some other form, report the new measurement
rather than chasing it into another file.

## VERIFY

1. From `core/0.1.0/`, `just test` passes.
2. From `core/0.1.0/demo/rheo/`, `just check` passes and prints `demo/rheo OK`.
3. From `core/0.1.0/demo/rheo/`, `rheo compile .` prints no line containing
   `counter("rheo-idea-fn")`.
4. Add a fixture exercising the real case if the demo does not already have
   one: a note carrying two or more footnotes, transcluded into a `#window` on
   another vertebra, with an assertion in `check.sh` that the footnote
   references on BOTH the note's own page and the window's page read 1 and 2
   and not some other pair. Say in your report whether such a fixture already
   existed or you added it.
5. From `core/0.1.0/demo/pure/`, that demo's own check still passes — this
   must work with no rheo present.
6. From the repository root, `just check-versions` still prints its OK line.