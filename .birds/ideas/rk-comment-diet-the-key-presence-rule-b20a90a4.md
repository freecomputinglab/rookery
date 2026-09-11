---
id: rk-comment-diet-the-key-presence-rule-b20a90a4
short-id: b20
title: 'Comment diet: the key-presence rule'
priority: 3
labels:
- chore-slipshow-review
deps:
- blocked-by:rk-hoist-the-order-array-position-lookup-cc62b00f
- blocked-by:rk-compute-entry-class-once-destructure-0c6f310e
closed: false
---
Trim a fact restated three times across two files of `@rookery/slipshow`,
against this repo's own comment rubric (`/home/lox/code/_fcl/rookery/CLAUDE.md`,
"Comment style" section: "the same fact stated twice in one file or across
two" is a finding). Comment text only — no code, no behaviour, changes.

Touches: /home/lox/code/_fcl/rookery/slipshow/0.1.0/src/select.typ, /home/lox/code/_fcl/rookery/slipshow/0.1.0/src/slipshow.typ

## The fact, restated three times

The rule "a computed value of `none` still counts as having run, and is told
apart from 'nothing computed at all' by whether the KEY is present on the
entry — never by the key's value" is fully spelled out, independently, in
three places:

1. `select.typ`, the comment above `_apply-row` (the CANONICAL statement —
   leave this one alone), lines 187-195:

   ```typ
   // Runs `row` once per `"row"`-kind entry and attaches its result as
   // `computed-row` — present ONLY on the entries the function actually ran on.
   // A `"content"` entry never gets the key at all, and neither does any entry
   // when `row` itself is `none`: `#slipshow`'s `_row-runs` (`slipshow.typ`)
   // tells "no computed row, fall back to the note's own `slip-row` tag" apart
   // from "computed as `none`, this slip joins no row" by that key's presence,
   // not by its value — collapsing the two would make a function that groups
   // most notes but deliberately excludes some indistinguishable from a
   // function never having run on them at all.
   #let _apply-row(entries, row) = {
   ```

2. `select.typ`, the comment above `_apply-class`, lines 211-216 — restates
   the same rule in full, despite opening by pointing back at `_apply-row`:

   ```typ
   // `class:`'s counterpart to `_apply-row` above, same shape and same
   // key-presence rule: `computed-class` lands ONLY on the entries the function
   // ran on, so `#slipshow`'s `_entry-class` (`slipshow.typ`) can tell "no
   // computed class, fall back to the note's own `slip-class` tag" apart from
   // "computed as `none`, this slip gets no class at all" by that key's
   // presence rather than its value.
   #let _apply-class(entries, class) = {
   ```

3. `slipshow.typ`, the comment above `_entry-class`, lines 293-301 —
   restates the same rule again, this time also naming `_entry-row` as
   carrying it a fourth time (see below):

   ```typ
   // An entry's class for `_slip-attrs` below: `computed-class` (`select.typ`'s
   // `_apply-class`) when `class:` ran on this entry, else its own `slip-class`
   // tag. Told apart by the KEY's presence, not its value, the same rule
   // `_entry-row` further down applies to `computed-row`: a `class:` function
   // that computed `none` for this entry still counts as having run, so that
   // entry gets no class rather than falling back to a tag it might still
   // carry. Defined here, ahead of `_slip-attrs`, rather than beside
   // `_entry-row`, because a Typst closure only sees names bound above it.
   #let _entry-class(e) = if "computed-class" in e { e.computed-class } else { class-of(e.tags) }
   ```

`slipshow.typ`'s `_entry-row` (lines 342-348) restates it a FOURTH time, but
is the more natural home for the full statement in that file (it is the
`row`/`computed-row` counterpart to `select.typ`'s own canonical `_apply-row`
statement), so it is left untouched — see "Do NOT" below.

## Decisions already made — do not re-derive

- Keep the FULL rule spelled out in exactly two places, one per file:
  `_apply-row` (`select.typ`) and `_entry-row` (`slipshow.typ`). Every other
  comment that currently restates it in full instead points at one of those
  two.
- `_apply-row` stays completely unchanged — it is the first and most
  detailed statement in the file where the pattern originates.
- `_entry-row` (`slipshow.typ`, lines 342-348) stays completely unchanged —
  it is the natural anchor in that file, and `_entry-class`'s current
  comment already points forward to it ("the same rule `_entry-row` further
  down applies to `computed-row`"), so keeping the full statement there
  matches what the pointer promises.

## Steps

1. In `select.typ`, replace the `_apply-class` comment (lines 211-216) with
   a short pointer back to `_apply-row`, keeping only what is specific to
   `class:` (the names `computed-class`/`_entry-class`/`slip-class`) rather
   than re-deriving the rule itself:

   ```typ
   // `class:`'s counterpart to `_apply-row` above: `computed-class` lands
   // ONLY on the entries `class` ran on, told apart from "no `class:`, fall
   // back to the note's own `slip-class` tag" by the same key-presence rule
   // `_apply-row` explains in full.
   #let _apply-class(entries, class) = {
   ```

2. In `slipshow.typ`, replace the `_entry-class` comment (lines 293-301)
   with a short pointer to `_entry-row`, keeping what is specific to
   `_entry-class` (why it is defined ahead of `_slip-attrs` rather than
   beside `_entry-row` — that reasoning is unique to this function and
   stays):

   ```typ
   // An entry's class for `_slip-attrs` below: `computed-class` (`select.typ`'s
   // `_apply-class`) when `class:` ran on this entry, else its own `slip-class`
   // tag — told apart by the same key-presence rule `_entry-row` explains in
   // full, further down. Defined here, ahead of `_slip-attrs`, rather than
   // beside `_entry-row`, because a Typst closure only sees names bound above
   // it.
   #let _entry-class(e) = if "computed-class" in e { e.computed-class } else { class-of(e.tags) }
   ```

## Do NOT

- Do not touch `_apply-row` (`select.typ`, lines 187-195) or `_entry-row`
  (`slipshow.typ`, lines 342-348) — both keep their full statement of the
  rule, unchanged, as the two anchors every shortened comment now points to.
- Do not touch `_apply-edges` (`select.typ`, lines 231-242) — its comment
  explains the OPPOSITE case (no key-presence rule at all for
  `computed-edges`), which is a real contrast worth keeping in full, not a
  restatement of the same fact.
- Do not touch `resolve-slips`'s own header comment (`select.typ`, lines
  330-339, mentioning "key-presence guessing") or `slipshow.typ`'s file
  header (lines 62-67, mentioning "KEY PRESENCE, not value") — both are
  brief, single-clause mentions inside a broader overview a reader skims
  top-to-bottom, not a full restatement of the rule, and shortening them
  further would leave the overview unable to stand on its own.
- Do not change any code — `_apply-class` and `_entry-class`'s bodies
  (the `#let` line itself) are unaffected; only the comment text above each
  changes.

## VERIFY

1. Typst suite green (comment-only change, but confirm nothing else broke):

   ```sh
   cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just test
   ```

   Expect `units OK`.

2. Negative suite unaffected:

   ```sh
   cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && bash test/panics.sh
   ```

3. Full build check:

   ```sh
   cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just check
   ```

   Expect `demo/rheo OK`.