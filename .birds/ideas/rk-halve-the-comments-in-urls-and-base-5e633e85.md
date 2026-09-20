---
id: rk-halve-the-comments-in-urls-and-base-5e633e85
short-id: 5e
title: Halve the comments in urls and base
priority: 1
labels:
- cut-comment-volume
deps:
- blocked-by:rk-correct-six-wrong-comments-in-src-6e39825c
closed: true
---
This project's `CLAUDE.md` ends its comment rules with: "Aim for files where
comments are a minority of the lines." Every file in `core/0.1.0/src/` fails
that, and two fail it badly enough that reading them is reading an essay with
code attached:

- `src/urls.typ` — 78% comment lines (152 lines total)
- `src/base.typ` — 77% comment lines (236 lines total)

Bring those two files back under half. This is a judgement-heavy edit and the
operator will read the result closely, so the rules below are about what must
SURVIVE at least as much as what goes.

Touches: core/0.1.0/src/urls.typ, core/0.1.0/src/base.typ

## Measure before and after

```
for f in /home/lox/code/_fcl/rookery/core/0.1.0/src/urls.typ /home/lox/code/_fcl/rookery/core/0.1.0/src/base.typ; do
  total=$(wc -l < "$f"); comments=$(grep -c '^\s*//' "$f")
  echo "$f: $comments/$total"
done
```

As of filing: `urls.typ` 119/152, `base.typ` 182/236.

## What must survive — do not cut these

The volume is the problem, not the substance. Four kinds of comment earn their
place and must still be there afterwards:

1. **A constraint the code cannot express.** An import order a closure makes
   load-bearing; a rheo behaviour the function depends on; a Typst rule about
   when `context` is or is not known.
2. **A contract a caller would otherwise get wrong.** What a function returns
   when rheo is absent; which of two similar functions to reach for.
3. **A measurement that justifies a constant** — a number, and what it buys.
   Keep the number and the one sentence that makes it a number rather than a
   guess. Drop the machine, the date, and the alternatives that lost.
4. **A parity note** naming a counterpart in another language or file. This
   project's rules make this the explicit exception.

Each file's HEADER — the block at the top saying what the file is — stays. It
may be shortened, but it does not go.

## What to cut

1. **Restatement.** A comment that says in prose what the line under it says in
   code earns nothing.
2. **The lab notebook.** Narration of how a conclusion was reached: what was
   tried, what was ruled out, what a previous attempt did. Keep the conclusion.
3. **Argument with mistakes the reader has not made.** Several blocks here
   pre-emptively rebut a wrong approach at paragraph length. One sentence, or
   nothing.
4. **Repetition across blocks.** Where three comments in a file each re-explain
   the same underlying fact, state it once — in the header if it governs the
   whole file — and let the other two refer to it in a clause.

## Steps

1. Read `src/urls.typ` in full before editing a line of it. It is 152 lines and
   the comments are interdependent — several blocks explain one mechanism
   between them.
2. Cut it to comments at or below 50% of its lines, applying the two lists
   above.
3. Do the same for `src/base.typ`.
4. Re-run the measurement command and confirm both are at or below 50%.
5. Run the tests and the pure demo (see VERIFY). Both files are heavily depended
   on — `base.typ` re-exports `pure.typ` to the whole package — so a stray
   deletion inside a `#let` shows up immediately.

## Non-goals

- Do NOT change any code. Not a `#let`, not an expression, not an import, not
  a whitespace-significant line inside a function body. If a comment cannot be
  removed without touching code, leave it.
- Do NOT touch the other 17 files in `src/`. They have the same problem to a
  lesser degree, and doing all nineteen at once produces a change nobody can
  review.
- Do NOT remove the `MEASURED:` annotations that carry a real number. Shorten
  them; do not delete the measurement.
- Do NOT remove section-divider comments as a separate goal — a different bird
  owns those and may already have landed. If any remain in these two files,
  removing them is fine and counts toward the target.
- Do NOT move commentary into the readme as a way of hitting the number. The
  readme is already 3000 lines and has its own bird for being too long.

## VERIFY

1. The measurement command above prints a ratio at or below 50% for both files.
2. From `core/0.1.0`, `just test` passes (prints `units OK`).
3. From `core/0.1.0/demo/pure`, `just build` passes (prints `demo/pure OK`).
4. From `core/0.1.0/demo/rheo`, `./check.sh` passes. If `rheo` is not on the
   path inside the flight, say so in the flight report rather than skipping it
   silently — steps 2 and 3 are the ones that must pass.
5. `rg -n '#let ' /home/lox/code/_fcl/rookery/core/0.1.0/src/urls.typ` prints
   the same number of hits as before the change — no binding was lost.