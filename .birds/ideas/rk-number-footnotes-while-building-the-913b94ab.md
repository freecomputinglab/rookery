---
id: rk-number-footnotes-while-building-the-913b94ab
short-id: '91'
title: Number footnotes while building the body, not while laying it out
priority: 4
labels:
- fix-footnote-number-at-construction
deps: []
closed: false
---
Touches: core/0.1.0/src/bib.typ, core/0.1.0/src/pure.typ, core/0.1.0/src/state.typ, core/0.1.0/demo/rheo/check.sh

A note's footnotes are numbered by a counter read during layout, so the
numbers are only correct once the document settles — and on a real site the
document never settles, leaving 47 counters that read `0` on every attempt.
Number them while the body is being built instead.

## The defect, measured

Building `/home/lox/code/waterline` prints 47 warnings of this shape, one per
rendering that carries footnotes:

```
warning: value of `counter("rheo-idea-fn-65")` did not converge
    ┌─ @rookery/core:0.1.0/src/bib.typ:199:28
    │
199 │         context _fn-ref(b, seq.get().first())
      - run 1: 0
      - run 2: 0
      - run 3: 0
      - run 4: 0
      - run 5: 0
      - final: 1
```

Every attempt reads `0`; the true value appears only at final resolution.

## How it got here

The original code shared ONE document-wide counter (`counter("rheo-idea-fn")`),
reset per note and stepped per footnote inside a show rule. That was unstable
for the usual reason — a note's body is replayed wherever a `#window` places
it, so the counter was stepped again somewhere else — and produced
`5,5,5,5 → 1` on this site.

The current code gives each rendering its own counter, named after the
per-rendering block number. Anchor:

```
rg -n 'let seq = counter' /home/lox/code/_fcl/rookery/core
```

one hit, `core/0.1.0/src/bib.typ:195`, inside `_footnoted` (anchor
`rg -n 'let _footnoted'`, one hit, `bib.typ:189`). The whole function is:

```typ
#let _footnoted(body) = {
  let notes = _footnotes(body)
  if notes.len() == 0 { return body }
  _fn-block.step()
  context {
    let b = _fn-block.get().first()
    let seq = counter("rheo-idea-fn-" + str(b))
    {
      show FNK: _ => {
        seq.step()
        context _fn-ref(b, seq.get().first())
      }
      body
    }
    _fn-block-html(notes, b)
  }
}
```

That numbers correctly — its demo assertion, three footnotes of which two are
byte-identical numbering 1, 2, 3 on both a note's own page and inside a
`#window`, genuinely passes — but it cannot converge. A counter whose NAME is
minted fresh has no value carried from the previous attempt, so every attempt
starts from `0`.

## The fix

Number at construction, not at render. The number a footnote needs is its
position among that note's own footnotes, which is knowable the moment the
body is in hand — no counter, no show rule, no layout.

`_footnotes` already performs exactly the right walk. Anchor:

```
rg -n 'let _footnotes' /home/lox/code/_fcl/rookery/core
```

one hit, `core/0.1.0/src/pure.typ:601`, a pure recursive walk collecting
footnote nodes in document order. Add a sibling walk in the same file that
rebuilds the body with each footnote element replaced by its reference already
carrying its index — so `_footnoted` places a body whose numbers are literal
content, and the `show FNK:` rule and `seq` counter both disappear.

Because the walk visits each node once, in order, two identical footnotes are
numbered correctly by construction. That is the advantage over matching an
element against a precomputed list: `notes.position(n => n == it)` returns the
first index for both and numbers them `1, 2, 2` — this was confirmed by a
negative test, do not reach for it.

Keep `_fn-block` and `_fn-ref` as they are (anchors: `rg -n 'let _fn-block =|let _fn-ref'`
printed two hits in `core/0.1.0/src/state.typ`, near its middle). The block number `b` is
still needed by `_fn-block-html` and by `_fn-ref`'s own markup; only the
per-footnote sequence changes. Remove `seq` entirely once nothing reads it.

## The hazard, and the STOP

Rebuilding content is not free. A naive rebuild can drop element fields,
styling or attached metadata that the original body carried, and the damage
may not be visible in a small fixture. Before landing, compare a rendered page
built the old way and the new way and confirm the markup is equivalent apart
from the footnote numbers.

If the rebuild cannot preserve the body faithfully — for instance if some
element cannot be reconstructed from what the walk can see — **STOP and report
with the evidence** rather than landing a lossy rewrite. Wrong markup that
converges is worse than correct markup that warns.

## Non-goals

- **Do not touch how a note is NAMED.** `core/0.1.0/src/idea.typ` derives a
  name from the note's own title or body plus a three-character digest, and
  `_slug-count` numbers a repeated title slug. Neither has anything to do with
  footnote numbering, and both are already stable. There is no container
  ordinal and no `_scope` state — if you find a comment referring to either,
  it is stale.
- **Do not change how footnotes RENDER** — the block at the foot of a note,
  its markup and its CSS all stay as they are. Only where the number comes
  from changes.
- **Do not number footnotes document-wide.** Per-note numbering is intended.
- **Do not edit anything in `/home/lox/code/waterline`.** You may READ it and
  BUILD it as a diagnostic (VERIFY 4), nothing more.

## VERIFY

1. From `core/0.1.0/`, `just test` passes.
2. From `core/0.1.0/demo/rheo/`, `just check` passes and prints `demo/rheo OK`,
   including the existing assertion that three footnotes — two of them
   identical — number 1, 2, 3 on both `ideas/plain-note.html` and the
   `#window` that transcludes it. That assertion already exists; it must keep
   passing unchanged.
3. From `core/0.1.0/demo/rheo/`, `rheo compile .` prints no line containing
   `rheo-idea-fn`.
4. Build the site as a diagnostic: copy
   `/home/lox/code/waterline/rookery/rheo.toml` to a scratch config INSIDE that
   repository (e.g. `rookery/.checkfn.toml`), replace the `repo =`/`branch =`
   pair in `[packages.rookery]` with `path = "<your flight path>"`, run
   `rheo compile rookery --config rookery/.checkfn.toml --html --build-dir <a scratchpad dir> --input today=2026-09-20`,
   and DELETE the scratch config afterwards. That build must print ZERO
   `counter("rheo-idea-fn-...")` warnings, down from 47. Report what remains;
   the document may still fail to converge for the container-ordinal reason,
   which is acceptable.
5. From `core/0.1.0/demo/pure/`, `just build` prints `demo/pure OK`.
6. From the repository root, `just check-versions` still prints its OK line.