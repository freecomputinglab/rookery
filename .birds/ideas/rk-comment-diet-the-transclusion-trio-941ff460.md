---
id: rk-comment-diet-the-transclusion-trio-941ff460
short-id: '94'
title: 'Comment diet: the transclusion trio'
priority: 3
labels:
- chore-core-review
deps:
- blocked-by:rk-query-outline-edges-by-label-682d6913
- blocked-by:rk-destructure-pair-maps-across-core-de56c4bd
closed: false
---
`transclusion.typ`, `window.typ` and `outline.typ` are 1606 lines, 1047 of them
comment lines — and three of those stories are told twice, in two files each.
Cut all three files to present-tense description without losing a constraint.

Touches: /home/lox/code/_fcl/rookery/core/0.1.0/src/transclusion.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/src/window.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/src/outline.typ

## The rubric

`/home/lox/code/_fcl/rookery/CLAUDE.md`, the section headed "Comment style", is
the standard. Read it before editing. Restated so this bird stands alone:

- **Describe the present.** What the code is and why it is that way. Never what
  it used to be, what moved where, which release changed it, or that something
  "is gone".
- **No issue ids**, bookmark names or branch names.
- **Keep the measurement, drop the lab notebook.** A number that justifies a
  constant stays and says what it buys; the machine, the date, the baseline it
  beat and the alternatives that lost go — unless a future reader would
  otherwise retune the number, and then one sentence.
- **One header per file, no interior banners** restating it.
- **Comment the non-obvious.** What earns a line: a constraint the code cannot
  express, a contract a caller would otherwise get wrong, a rule shared with
  another language. Not a restatement of the line below it.
- **Declarative and concise, present tense.** Emphasis capitals for the one
  claim in a block that carries it. Comments should be a minority of the lines.

**A `REJECTED`/`REFUTED`/`REVERTED` block is not automatically deletable.** Keep
the RULE it contains as one or two present-tense sentences; delete the
narrative. For example, replace

> Reading `.get()` from inside the context instead was tried and REVERTED —
> MEASURED, it made a document with minted pages fail to converge in five
> attempts, cycling `none -> "rheo" -> "ideas:index" -> "ideas:author-cleanup"`.

with

> The page a marker sits on is resolved positionally, with
> `state("rheo-handle").at(el.location())`. A `.get()` from inside the window's
> own context is not convergent: with minted pages in the document the value
> observed depends on where the surrounding layout has got to.

## The three duplicated stories — keep one copy of each

Line numbers are as of filing; match the quoted text if they have shifted.

1. **The positional-handle-read story** is at `window.typ:196-204` and again at
   `outline.typ:143-148`. Keep one full statement in `outline.typ`, where the
   positional read actually lives (`outline.typ:157`), and reduce `window.typ`'s
   copy to the fact its own code needs: the announce marker stays OUTSIDE the
   context block below it, because `_page-links` resolves which page it sits on
   from the marker's own location.
2. **"Excluded is not missing"** is argued at `window.typ:227-253` (27 lines)
   and again at `window.typ:443-447`. Keep the full statement once — a note
   dropped for its tags is deliberately absent, a `#window` on it renders
   nothing, a typo still panics, and the `@idea:x` markup form cannot be rescued
   because it is a Typst `ref` to a label that was never minted. Reduce the
   second to a clause. (The same argument also appears in `hyperlink.typ` and
   `state.typ`; those belong to other birds — do not edit them here.)
3. **The page-links sweep-to-beacon story** at `outline.typ:26-52` (27 lines of
   relayout-cap archaeology, an 82-note site, 72 dead links) reduces to the
   present-tense rules, all of which matter: each vertebra scans its own content
   with a plain content walk and publishes one labelled beacon; `_page-links`
   reads `query(<rookery-page-links>)`, a selector a minted page never
   contributes to, which is what keeps the query's input from growing as marrow
   mints; `#show: rookery` is what emits it, which is what scopes it to
   vertebrae. Keep the relayout cap as one clause with its number
   (`MAX_ITERS = 5`), because that is the constraint the shape exists to respect.

## The rest of the work

4. `transclusion.typ`'s `_window-content` banner (16-97): keep the click-budget
   contract (the summary folds, the permalink navigates, nothing else is a
   link), the reason an outer `<a>` around the body is invalid, that the
   disclosure is native `<details>`/`<summary>` because this package ships no
   JS, and that an `<a>` inside `<summary>` does not break the toggle. The
   Forester reference may stay as one clause. Drop "Both were tried and
   removed".
5. `transclusion.typ`'s `_flatten` banner (287-310): keep the termination
   argument, which is the closure-captured constant — each expansion recurses
   with `depth - 1` baked into a fresh scope, so a cycle bottoms out — and the
   inner-rule-wins fact, which is why a generated WK figure is always claimed by
   a strictly smaller budget. Compress the measured reproduction to a clause.
6. `transclusion.typ`: remove the version and history references at lines 101
   ("Core no longer answers that" — keep the rule, that the hat shows `created`
   and a lifecycle belongs to `@rookery/timeline`), 359 ("as of 0.6.0"), 410
   ("the bare id it used to carry"), 448 and 462 ("minted before this bead",
   "before this key existed" — keep the rule, that each marker field is read
   with a default and which way each default points).
7. `window.typ`: compress the `#window` parameter comments (62-116) — they are
   good but several restate each other; and at line 430, "Both asserts are
   copied verbatim from `#window`" becomes the rule it is there for: the two
   functions take the same two parameters with the same meaning, so the messages
   have to agree.
8. `outline.typ`: the `_ideas-outline-data` banner (184-273) is 90 comment lines
   for one function. Keep the four constraints — a show rule does not remove a
   figure from `query()`, which is why two depths are tracked; the rookery-wide
   form's vertebra filter and why minted pages would otherwise double-list; the
   `multi-page` gate and why the guard must not apply to the combined PDF; and
   that the two forms agree on a single-page target. Drop the reproduction
   narratives and "The second used to be an early `return ()`" (lines 258-262).
   At line 334, "This used to skip every titleless note on the reasoning that
   there was nothing to label them with; there is now" becomes the present rule:
   an outline entry names a note, so it takes the note's name, and the skip
   survives only for a note with no name at all.

## Do NOT

- **Do not change one token of code.** Not a rename, not a reformat. Comments
  only.
- Do not delete a comment that states a constraint, a caller contract, a
  measured number that justifies a constant, or a parity link.
- Do not add a claim you have not verified in the code in front of you.
- Do not touch any file outside the three named above — in particular not
  `hyperlink.typ`, `state.typ`, `urls.typ` or `template.typ`, which carry
  related passages and belong to other birds.

## VERIFY

A comment edit that swallows a line of code fails these, so all four must still
be green:

```sh
cd /home/lox/code/_fcl/rookery/core/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/pure && just build
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check-typst
```

Expected last lines: `units OK`, `demo/pure OK`, `demo/rheo OK`,
`demo/rheo (native) OK`.

Then the checks specific to this bird:

```sh
cd /home/lox/code/_fcl/rookery/core/0.1.0/src && grep -nE "this bead|as of 0\.[0-9]|82-note|used to|was tried" transclusion.typ window.typ outline.typ
cd /home/lox/code/_fcl/rookery/core/0.1.0/src && for f in transclusion.typ window.typ outline.typ; do echo "$f $(grep -c '^[[:space:]]*//' $f)/$(wc -l < $f)"; done
```

The first must print nothing, with one honest exception: `used to` also spells
the ordinary present-tense "X is used to build Y". A hit of that kind is fine —
say so in the flight rather than rewording a correct sentence. Every hit that
narrates the past has to go.

The second prints `344/497`, `301/473` and `402/636` today; land each at roughly
60% of that or below. The count is guidance, not a gate — losing a constraint to
hit a number is the one failure this bird cannot accept.