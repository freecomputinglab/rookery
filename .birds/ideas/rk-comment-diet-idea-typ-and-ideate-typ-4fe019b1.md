---
id: rk-comment-diet-idea-typ-and-ideate-typ-4fe019b1
short-id: 4f
title: 'Comment diet: idea.typ and ideate.typ'
priority: 3
labels:
- chore-core-review
deps:
- blocked-by:rk-resolve-visible-tags-once-in-idea-0c57019f
- blocked-by:rk-destructure-pair-maps-across-core-de56c4bd
- blocked-by:rk-name-the-note-sequence-counter-dd93145f
closed: false
---
`idea.typ` and `ideate.typ` are 1051 lines, 763 of them comment lines.
`idea.typ` litigates two removed features and cites a private downstream
project; `ideate.typ` states the same three measured facts twice each. Cut both
to present-tense description without losing a constraint.

Touches: /home/lox/code/_fcl/rookery/core/0.1.0/src/idea.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/src/ideate.typ

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

A `REJECTED`/`REFUTED`/`THE TRAP` block is not automatically deletable: keep the
RULE as one or two present-tense sentences, delete the narrative.

## The specific work

Line numbers are as of filing; match the quoted text if they have shifted.

### `idea.typ`

1. **Delete the `updated:` litigation** at lines 226-236 (`// \`created\`, and
   ONLY \`created\`. There used to be an \`updated:\` beside it...` through
   "...`_window-content` reads the same field off the registry record."). Replace
   the whole passage with at most two sentences of present tense: `#idea`
   resolves one date, `created`, from the explicit argument then the document's
   own `#set document(date:)`; a note's lifecycle is `@rookery/timeline`'s
   subject. Keep the sentence above it about `show-date` gating display only,
   and keep the `auto`-is-not-`none` fact at lines 210-213, which is a real
   Typst constraint.
2. **The title-vs-label banner** (129-174) is 46 lines. Keep: the two-name
   distinction and what each is for; that a derived name is only useful where
   the body is absent; that `label` is a `str`; and — most important — the
   shadowing trap, that a local `let label = ..` shadows Typst's built-in
   `label()` and breaks the anchor further down, which is why the local is
   `note-label`. Drop: the named downstream project, the pasted HTML showing the
   body printed twice (one clause does it), and "THAT THE LABEL IS WANTED is not
   in doubt... hand-rolls... in eight places".
3. **The `tagged-idea` banner** (472-540) is 68 lines. Keep: what the factory
   is and the positional-several-tags rule; the `.with()` trap, that an explicit
   `tags:` at the call site overrides a `.with()`-bound value, which is why this
   is a closure; that `exclude-tags:` must be passed to the factory because the
   returned closure calls the package-scope `idea`, plus the two-binding project
   pattern; and the one-tag rule for `value:`. Drop "REPLACES the hardcoded
   `note`/`todo` this package exported through 0.4.1" and any other version
   reference.
4. **The exclusion gate** (66-127) stays in substance — the gate must sit above
   the `figure(kind: IK)` because five walks find notes by that marker
   structurally, the decision therefore cannot read state, the counter still
   steps for an excluded unnamed note so ids do not shift between builds, and
   `counter.step()` returns content. Compress the prose around those four
   points; drop "MEASURED here: `#window`'s own `_excluded-ids.final()` was the
   reader that tripped it".
5. Remaining version references to remove, keeping each surrounding rule:
   lines 186 and 296 ("as of 0.5.0"), 232 ("as of 0.6.0"), 302 ("no longer
   collide"), 352 ("as it did before 0.6.0"), 383 ("no longer a second child of
   the heading"), 431 ("exactly the markup it emitted before this argument
   existed" — keep the rule: the attribute is emitted only when the frame is
   off, because an attribute present with a falsy value still matches the
   selector).

### `ideate.typ`

6. **Three facts are stated twice each. Keep one copy of each, at the code that
   depends on it, and delete the other.**
   - The heading-level field table (`level` vs `depth`) appears in the file
     header at lines 69-82 and again above `_level-of` at lines 204-220. Keep
     the one above `_level-of`, which is the function it explains.
   - The five accepted `separator:` spellings appear at lines 31-38 and again
     inside `ideate` at lines 285-291. Keep the one in the file header, which is
     where a reader looks for the surface, and reduce the in-function copy to a
     pointer-free single line if anything is needed there at all.
   - The "`heading(level: 2)` bare is illegal Typst / cannot be fixed by
     exporting our own `heading`" argument appears at lines 55-67 and again at
     301-309. Keep one.
   - "Classified ONCE, before even the single-paragraph early return" appears at
     lines 281-284 and again at 311-313. Keep one.
7. Keep in full, because they are constraints the code cannot express: the
   measured content-tree shape and the four facts drawn from it (lines 96-134),
   `_ctx-fn`'s reason for existing (`context` is a keyword, so the element
   function can only be obtained from a built piece of content), `_sel-level`'s
   `repr`-parsing justification and the refused forms, and the order of the
   three group tests in the emit loop.
8. Compress fact 5 (lines 128-134 and its restatement at 179-190, which names a
   private project's file): state once that a body handed to `#ideate` as a
   document show rule under rheo ends with a trailing `context` child — rheo's
   page postamble — which is neither authored content nor whitespace, so such a
   group is emitted unwrapped rather than minted or dropped.

## Do NOT

- **Do not change one token of code.** Not a rename, not a reformat. Comments
  only.
- Do not delete a comment that states a constraint, a caller contract, a
  measured number that justifies a constant, or a parity link.
- Do not add a claim you have not verified in the code in front of you.
- Do not touch any file outside the two named above.

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
cd /home/lox/code/_fcl/rookery/core/0.1.0/src && grep -nE "phdash|as of 0\.[0-9]|through 0\.[0-9]|before 0\.[0-9]|used to|no longer" idea.typ ideate.typ
cd /home/lox/code/_fcl/rookery/core/0.1.0/src && for f in idea.typ ideate.typ; do echo "$f $(grep -c '^[[:space:]]*//' $f)/$(wc -l < $f)"; done
```

The first must print nothing, with one honest exception: `used to` also spells
the ordinary present-tense "X is used to build Y". A hit of that kind is fine —
say so in the flight rather than rewording a correct sentence. Every hit that
narrates the past has to go.

The second prints `453/639` and `310/412` today;
land it at roughly 270/idea and 200/ideate or below. The count is guidance, not
a gate — losing a constraint to hit a number is the one failure this bird
cannot accept.