---
id: rk-comment-diet-meetings-lib-typ-and-css-89e89c42
short-id: '89'
title: 'Comment diet: meetings'' lib.typ and CSS'
priority: 3
labels:
- chore-meetings-review
deps:
- blocked-by:rk-hoist-meetings-css-safe-regex-to-module-c2b9e625
closed: false
---
/home/lox/code/_fcl/rookery/meetings/0.1.0/src/lib.typ is 253 lines, 134 of
them (53%) comments, and /home/lox/code/_fcl/rookery/meetings/0.1.0/src/meetings.css
(93 lines) runs just as dense. Nearly every comment block in both files opens
with an ALL-CAPS emphasis phrase, several of them arguing against a rejected
alternative design nobody proposed. Per this repo's own CLAUDE.md ("Comment
style"): "Emphasis capitals are for the one claim in a block that carries it,
not for every second clause, and a comment should not argue with mistakes its
reader has not made yet."

Touches: /home/lox/code/_fcl/rookery/meetings/0.1.0/src/lib.typ,
/home/lox/code/_fcl/rookery/meetings/0.1.0/src/meetings.css

## The pattern, with line numbers (lib.typ)

Every one of these opens its comment block in all caps; trim the capitalized
lead-in and keep only the substantive constraint the block is making:

- line 14: "TWO ALIASED IMPORTS, and the aliases are load-bearing rather than
  tidy." — keep the load-bearing-import-order constraint, drop the caps lead.
- line 27: "WHO WAS IN THE ROOM, as idea NAMES" — keep what the value holds,
  drop the caps.
- line 32: "THE NAMES ARE MEANT TO BE PEOPLE and are not required to be."
- line 37: "A TAG PER PERSON IS THE OTHER DESIGN AND IS WORSE." — this whole
  paragraph (through line 42) argues against a design nobody chose; cut it to
  the one sentence that states the actual constraint (a tag key becomes a CSS
  class fragment, so it must stay identifier-safe), drop the "OTHER DESIGN...
  WORSE" framing entirely.
- line 45: "THE STAGE `on:` WRITES into @rookery/timeline's log."
- line 76: "EACH NAME AS ITS OWN `ref`, which does two things no written link
  can."
- line 82: "THE HEADER A MEETING OPENS WITH: a labelled row, not a sentence."
- line 87: "A DIV, NOT A HEADING, for the label" — keep the outline-pollution
  reason, drop the "NOT A HEADING" contrast framing.
- line 91: "HTML ONLY, in the sense that..."
- line 98: "COMMA-JOINED, not one per line"
- line 109: "PLURAL IS THE FACTORY, singular the note."
- line 115: "`today:` IS HERE BECAUSE TYPST HAS NO CLOCK."
- line 153 area: "ONE DATE, ONE SPELLING." — the two asserts right below
  already enforce this; the comment can state the constraint without a
  slogan line.
- line 190: "THE NAME AN UNTITLED MEETING GETS"
- line 198: "REFS, not the names as text"
- line 204: "THE DATE IS @rookery/timeline'S OWN SHORT FORM"
- line 220: "THE RECORD OPENS THE NOTE"
- line 226: "`(:)` AS THE ENTRY, not the note's own row"
- line 235: "`on:` SETS `created:`"
- line 241: "TWO BRANCHES because..."

## The pattern, with line numbers (meetings.css)

- line 7: "THE LAYER, and it is not optional."
- line 13: "THE PROPERTIES."
- line 23: "THE GUTTER MATCHES @rookery/timeline'S RAIL"
- line 29: "THE SAME MARKUP @rookery/bibtex GIVES A CITATION"
- line 44: "TWO COLUMNS"
- line 58: "THE RULES BETWEEN FIELDS"
- line 82: "A RAIL FOLLOWING THE RECORD"

## Steps

1. Work through each location above in both files. For each: keep the
   substantive constraint or contract the comment states (why the code must be
   shaped this way), rewritten as a plain declarative sentence with no
   all-caps lead-in.
2. Where a comment's main content is arguing against a rejected alternative
   (lines 37-42 of lib.typ is the clearest case), cut the argument down to the
   one fact a future editor needs — what the constraint actually is — and drop
   the rest.
3. Do not remove a comment's substantive content — the constraints described
   (import shadowing order, why a div not a heading, why refs not plain names,
   the CSS layer rule, the shared-gutter measurement) are real and worth
   keeping; only the emphasis style and the alternative-arguing framing are
   the finding.
4. Preserve every parity/counterpart note and every numeric justification
   (7.5em gutter match, etc.) as-is — those are not part of this finding.

## Do NOT

- Do not change any code — this bird is comments only, in both files.
- Do not touch `test/units.typ` or `test/view.typ`.
- Do not remove a comment's constraint or reasoning entirely — the finding is
  the ALL-CAPS/argumentative delivery, not the presence of a rationale.

## VERIFY

    cd /home/lox/code/_fcl/rookery/meetings/0.1.0 && just test

Expect the same output as before: `units OK` then `view OK`. Then re-run the
ratio check and confirm the comment count dropped without any assertion
failures:

    cd /home/lox/code/_fcl/rookery/meetings/0.1.0/src && for f in *.typ; do echo "$f $(grep -c '^[[:space:]]*//' $f)/$(wc -l < $f)"; done