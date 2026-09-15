// The explicit-array route: a deck built by naming notes, not by querying
// them. See `content/corpus.typ` for the ten notes it draws from.
#import "lib.typ": template
#import "@rookery/slipshow:0.1.0": slipshow
#show: template

= A deck built by naming notes

An explicit `slips:` array selects by construction — every element is already
a decision about what belongs, so a plain `#idea` needs no tag to be included
here, only its name. The array is also the presentation order: `order:`
has nothing left to do once the sequence is written out by hand, and
`#slipshow` refuses it alongside `slips:` for exactly that reason.

Two of the four notes below are `#slip`s, two are plain `#idea`s, mixed by
name in one sequence — the array does not care which kind a name resolves
to.

#slipshow(slips: ("opening", "background-note", "plain-context", "closing"))
