---
id: rk-comment-diet-pure-typ-and-state-typ-624678ea
short-id: '62'
title: 'Comment diet: pure.typ and state.typ'
priority: 3
labels:
- chore-core-review
deps:
- blocked-by:rk-cache-bib-keys-drop-dead-cite-walk-871b6099
- blocked-by:rk-stamp-each-id-once-in-sort-ids-ef520fb1
- blocked-by:rk-name-the-note-sequence-counter-dd93145f
closed: false
---
`pure.typ` and `state.typ` are 1211 lines, 815 of them comment lines. Much of
that is version history, migration notes, tracker ids wearing a version's
clothes, and one wrapper-discipline paragraph copied seven times. Cut it to
present-tense description without losing a single constraint.

Touches: /home/lox/code/_fcl/rookery/core/0.1.0/src/pure.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/src/state.typ

## The rubric

`/home/lox/code/_fcl/rookery/CLAUDE.md`, the section headed "Comment style", is
the standard. Read it before editing. Restated so this bird stands alone:

- **Describe the present.** What the code is and why it is that way. Never what
  it used to be, what moved where, which release changed it, or that something
  "is gone".
- **No issue ids**, bookmark names or branch names. The argument for a line has
  to stand on its own.
- **Keep the measurement, drop the lab notebook.** A number that justifies a
  constant stays, and says what it buys. The machine it was measured on, the
  date, the baseline it beat and the alternatives that lost do not — unless a
  future reader would otherwise retune the number, and then one sentence.
- **One header per file, no interior banners.** A `// ---- Section ----` divider
  restating the file header is forbidden.
- **Comment the non-obvious.** A comment restating the line under it earns
  nothing. What earns its place: a constraint the code cannot express, a
  contract a caller would otherwise get wrong, a rule shared with another
  language.
- **Declarative and concise, present tense.** Emphasis capitals for the one
  claim in a block that carries it, not every second clause. Comments should be
  a minority of a file's lines.

**A `REJECTED`/`REFUTED`/`REVERTED` block is not automatically deletable.** Keep
the RULE it contains as one or two present-tense sentences; delete the
narrative. For example, replace

> REFUTED APPROACH, do not reintroduce: a `state` depth counter around the
> expansion. Measured failing on typst 0.14.2 AND 0.15.1 — a self-window still
> fails identically, because typst hits its nesting cap before the state
> timeline converges.

with

> The budget is a closure-captured constant, not a state: a state timeline does
> not converge before Typst hits its show-rule nesting cap, so a self-window
> would fail outright.

## The specific work

Line numbers are as of filing; match the quoted text if they have shifted.

### `state.typ`

1. **Seven copies of one rule.** The wrapper discipline —
   `.update(value)` for a plain value, `.update(_ => f)` only because
   `state.update` treats a function argument as an updater — is written out
   again on `_syndicate` (lines 204-207), `_index-page` (210-213),
   `_show-context` (220-223), `_show-backlinks` (229-232), `_show-title`
   (236-238), `_page-titles` (247-249) and `_invisible-tags` (303-307), after
   being stated in full on `_idea-page-template` (194-197). State it once, on
   `_idea-page-template`, and delete the six repeats. Keep everything else each
   of those comments says about its own state (what marrow does with it, which
   way its default points and why).
2. **Delete the migration note** at lines 89-95 ("MIGRATION off the old scale,
   where `0` was the default... A project that set `window-depth: 2` wants
   `3`."). The scale itself is documented directly above it and stays.
3. Compress the `_idea-page-template` banner (160-197): keep why a state is the
   only channel from a vertebra to the bundle root, and the
   named-function-not-a-closure requirement. Drop "VERIFIED on typst 0.15.1 that
   a state can hold a function, that `.final()` returns it callable, and that
   the document still converges".
4. Compress the `_excluded-ids` banner (341-368) to what it is for — telling a
   note the build removed on purpose from a note that never existed — plus the
   strings-only and unnamed-notes-cannot-be-here rules.

### `pure.typ`

5. **`v6y.7` is a tracker id, not a version**, and it appears twice: line 423
   ("Every registry body has been through `_flatten` since v6y.7") and line 620
   ("since v6y.7, which wraps it in a `show`-rule scope"). Both must lose it and
   state the present fact: a registry body has been through `_flatten`, which
   wraps it in a show-rule scope that Typst represents as a `styled` node
   hanging off `.child`, so the walk unwraps that first.
6. **Version history goes**: "as of 0.5.0" at lines 51 and 131, and the
   "BREAKING for a 0.4.1 predicate written against the array" paragraph at
   136-139. Keep the RULE underneath the last one — a `filter:` predicate is
   handed the tag DICTIONARY, so `.map`, `.any`, `.all` and `.at(0)` are not
   available on it and `"phd" in t` tests keys.
7. Compress `_blocks` (its comment runs 594-661, about seventy lines for a
   thirty-five line function). Keep, because each is a constraint the code
   cannot express: a `space` between two `item`s is list punctuation while a
   `parbreak` ends the run; `item` covers all three list kinds; a `styled` node
   has to be unwrapped; inline and block are told apart by name because Typst
   exposes no predicate, with `raw`/`quote`/`equation` asked for their own
   `block` field; unknown names default to block, so a gap in the list leaves a
   dropped space rather than merging two real blocks. Drop the
   rookery.ohrg.org anecdotes, "MEASURED REGRESSION FIX", and the closing
   paragraph about what could not ship before.
8. Compress the smartquote banners (315-343 and 454-458). Keep the ASCII
   decision and its reason (`double: bool` is the element's only field, so which
   curly form it renders as is not knowable here) and that the second copy is
   the same branch for the same reason. Drop the tree-shape dump and the
   "`Read Anils Rumour is the exploit`" anecdote — one clause, that an
   apostrophe has to survive into a title's and a body's plain text, carries it.
9. Compress `_derived-title` (470-503): keep the `.clusters()` rule (Typst's
   `str.slice` takes byte offsets and panics inside a multi-byte character) and
   the empty-body-derives-nothing rule. Drop "WHY IT EXISTS" and the
   before-and-after account.
10. Compress the shared-validator banner (739-757): keep the `where` contract
    (pass the caller's own possessive exactly) and the reason `depth` is not
    here. Drop "MEASURED at 0.4.0: 32 assert blocks in `lib.typ`".

Both file headers (pure.typ 1-25, state.typ 1-9) are good as they are — they
describe the present. Keep them, minus any sentence that stops being true.

## Do NOT

- **Do not change one token of code.** Not a rename, not a reformat, not a
  reordering. This bird edits comments only.
- Do not delete a comment that states a constraint, a caller contract, a
  measured number that justifies a constant, or a parity link to another
  language's file.
- Do not add a claim you have not verified in the code in front of you.
- Do not touch any file outside the two named above.
- Do not remove the `// ---- ... ----` section dividers wholesale in these two
  files; several genuinely separate a file into its parts. Remove only one that
  restates the file header.

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

Then the two checks that are specific to this bird:

```sh
cd /home/lox/code/_fcl/rookery/core/0.1.0/src && grep -nE "v6y|as of 0\.[0-9]|MIGRATION|BREAKING for" pure.typ state.typ
cd /home/lox/code/_fcl/rookery/core/0.1.0/src && for f in pure.typ state.typ; do echo "$f $(grep -c '^[[:space:]]*//' $f)/$(wc -l < $f)"; done
```

The first must print nothing. The second prints `502/779` and `313/432` today;
land it at roughly 300/pure and 190/state or below. The count is guidance, not
a gate — losing a constraint to hit a number is the one failure this bird
cannot accept.