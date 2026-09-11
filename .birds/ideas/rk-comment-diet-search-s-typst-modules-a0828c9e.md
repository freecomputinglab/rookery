---
id: rk-comment-diet-search-s-typst-modules-a0828c9e
short-id: a0
title: 'Comment diet: search''s Typst modules'
priority: 3
labels:
- chore-search-review
deps:
- blocked-by:rk-bucket-the-browse-listing-s-date-sort-7bb3bde1
- blocked-by:rk-stamp-and-tag-filter-panel-rows-once-b74611b3
- blocked-by:rk-hoist-the-tokenizer-s-two-regexes-3455a62d
- blocked-by:rk-fix-three-small-search-inconsistencies-a6e60962
closed: false
---
`@rookery/search`'s eleven Typst modules are 2525 lines, 1434 of them comment
lines. The prose is in much better shape than `@rookery/core`'s — almost no
version history and no tracker ids — so this is a narrow pass: one measurement
stated three times, a handful of sentences describing what the code replaced, and
some argument documentation that argues with its reader.

Touches: /home/lox/code/_fcl/rookery/search/0.1.0/src/base.typ,
/home/lox/code/_fcl/rookery/search/0.1.0/src/compress.typ,
/home/lox/code/_fcl/rookery/search/0.1.0/src/corpus.typ,
/home/lox/code/_fcl/rookery/search/0.1.0/src/filter-panel.typ,
/home/lox/code/_fcl/rookery/search/0.1.0/src/lib.typ,
/home/lox/code/_fcl/rookery/search/0.1.0/src/lookup.typ,
/home/lox/code/_fcl/rookery/search/0.1.0/src/panel.typ,
/home/lox/code/_fcl/rookery/search/0.1.0/src/rank.typ,
/home/lox/code/_fcl/rookery/search/0.1.0/src/score.typ,
/home/lox/code/_fcl/rookery/search/0.1.0/src/tagquery.typ,
/home/lox/code/_fcl/rookery/search/0.1.0/src/ui.typ

## The rubric

`/home/lox/code/_fcl/rookery/CLAUDE.md`, the section headed "Comment style", is
the standard. Read it before editing. Restated so this bird stands alone:

- **Describe the present.** What the code is and why it is that way. Never what
  it used to be, what moved where, which release changed it, or that something
  "is gone".
- **No issue ids**, bookmark names or branch names.
- **Keep the measurement, drop the lab notebook.** A number that justifies a
  constant or a default stays, and says what it buys. The machine, the date, the
  site, the baseline it beat and the alternatives that lost go — unless a future
  reader would otherwise retune the number, and then one sentence.
- **One header per file, no interior banners** restating it.
- **Comment the non-obvious.** What earns a line: a constraint the code cannot
  express, a contract a caller would otherwise get wrong, a rule shared with
  another language. Not a restatement of the line below it.
- **Declarative and concise, present tense.** Emphasis capitals for the one
  claim in a block that carries it, not every second clause, "and a comment
  should not argue with mistakes its reader has not made yet".

**The parity exception applies here more than anywhere in this repo and is not
optional.** A comment naming its counterpart in the other language —
`score.typ` naming `src/score.js`, `tagquery.typ` naming `src/tagquery.js`,
either naming `just parity` as what pins them — is a present-tense fact about
how the code is arranged, and the two halves cannot be changed apart. Keep every
one of those, and keep every sentence that explains WHY a rule is spelled the way
it is on both sides (the `lower` vs `_fold` split in `score.typ:83-87`, the
literal-space split at `:89-94`, the `c.trim() == ""` whitespace test in
`tagquery.typ:81-86`). Those are the most valuable comments in the package.

## The specific work

Line numbers are as of filing; match the quoted text if they have shifted.

1. **One measurement, stated three times.** The 320-note/360-page
   inline-versus-asset comparison appears in `corpus.typ` at lines 9-13 (the
   `_corpus-cache` banner), again at lines 40-46 (the `_rows-cache` banner), and
   again at lines 126-132 (inside `#search-index`'s own documentation) — with a
   fourth partial restatement in `lookup.typ:74-81`. Keep ONE full statement, in
   `#search-index`'s documentation where a reader choosing `mode:` will find it,
   because that is the decision the numbers exist to settle. Reduce the two cache
   banners to what each cache IS, what keys it, and the one sentence that says
   why it exists (a bundle-root pass the per-page path reads back). Do not delete
   the numbers from the copy you keep — they are exactly the measurement the
   rubric says to keep.
2. **Sentences describing what the code replaced.** Rewrite each as the present
   rule:
   - `corpus.typ:49` and `:118` — "as it always did" / "derives its rows as it
     always did".
   - `panel.typ:63` — "since it shipped"; `:266` and `:568` — "as it always
     did".
   - `filter-panel.typ:69` — "which WAS the difference from `#panel`'s facets";
     `:267` — "and they were one until `chips:` could differ from `pills:`".
     Both keep their point: the first that this widget's pills are authored or
     derived from tag NAMES while `#panel`'s are projected field values, the
     second that `pressable` is the pill set the script matches and `shown` is
     what the reader sees, and collapsing them would print the corpus's tags onto
     every row.
3. **Argument documentation that argues.** `panel.typ`'s `union:` (lines
   265-294) and `multi:` (249-263) run to 46 comment lines between them, much of
   it addressing a reader who might merge the two groups or infer `multi` from a
   type. Keep: what each argument declares; that `multi` cannot be inferred
   because a facet of single-element arrays would silently switch predicates and
   the JS half must be told which attributes to tokenize; that `union` groups OR
   with each other while every other group ANDs; that a single pressed union
   group is a no-op. Drop the paragraphs headed "WHY NOT MERGE THE GROUPS
   INSTEAD" and "NOT A REPLACEMENT FOR `multi:`" down to a clause each.
   `filter-panel.typ`'s own header (lines 1-22) and its `pills:`/`chips:`/
   `tag-filter:` blocks get the same treatment: keep the rule and the one fact
   that justifies it (the `#idea-row` grid is why a derived list must not reach
   the badge strip; the 47-pills-six-valued-keys measurement is why `auto`
   derives flat tags only), drop the rest of the justification.
4. `lib.typ` (31 comment lines of 43) is a manifest and its comments are its
   content — the import order and why it is load-bearing. Leave it as it is
   apart from anything that stops being true.
5. Leave `score.typ`, `tagquery.typ`, `rank.typ` and `base.typ` close to as they
   are. Their comments are the parity contract and the measured reasons behind
   it; trim only a sentence that repeats the block above it.

## Do NOT

- **Do not change one token of code.** Not a rename, not a reformat. Comments
  only.
- Do not delete a comment that states a constraint, a caller contract, a
  measured number that justifies a constant or a default, or a parity link to
  the JavaScript side.
- Do not touch any `.js` file. The JavaScript comments in this package are
  present-tense and carry the other half of the parity contract; they are not in
  scope and there is no sibling bird for them.
- Do not add a claim you have not verified in the code in front of you.
- Do not edit anything under `test/` or in `demo/`.

## VERIFY

A comment edit that swallows a line of code fails these, so all three must still
be green:

```sh
cd /home/lox/code/_fcl/rookery/search/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/search/0.1.0 && just parity
cd /home/lox/code/_fcl/rookery/search/0.1.0/demo/rheo && just check
```

Expected: `pass 123` / `fail 0`; six `OK` lines from parity; `demo/rheo OK`.

Then the checks specific to this bird:

```sh
cd /home/lox/code/_fcl/rookery/search/0.1.0/src && grep -nE "always did|since it shipped|WAS the difference|were one until" *.typ
cd /home/lox/code/_fcl/rookery/search/0.1.0/src && grep -c "320-note" *.typ
cd /home/lox/code/_fcl/rookery/search/0.1.0/src && for f in *.typ; do echo "$f $(grep -c '^[[:space:]]*//' $f)/$(wc -l < $f)"; done
```

The first must print nothing. The second must show the measurement surviving in
exactly one file. The third prints today's counts — `base.typ 70/131`,
`compress.typ 114/191`, `corpus.typ 251/366`, `filter-panel.typ 212/346`,
`lib.typ 31/43`, `lookup.typ 96/128`, `panel.typ 290/580`, `rank.typ 62/107`,
`score.typ 66/119`, `tagquery.typ 106/201`, `ui.typ 136/313` — and the three
files this bird actually cuts are `corpus.typ`, `panel.typ` and
`filter-panel.typ`; landing those near 150, 200 and 140 would be a good pass.
The count is guidance, not a gate: losing a constraint or a parity note to hit a
number is the one failure this bird cannot accept.