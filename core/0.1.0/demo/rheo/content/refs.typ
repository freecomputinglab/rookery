#import "lib.typ": demo, idea
#import "@rookery/core:0.1.0": footnote

#show: demo

= Citation positions and derived labels

// A citation in ordinary page prose, BEFORE a note — unclaimed until the
// next note's own unconditional sweep block claims it, so it does not leak
// into that note's own References list.
Some prose citing Knuth directly: @knuth1984.

#idea("cited-note", title: [Cited note])[
  This note cites Lamport @lamport1994 in its own body, producing its own
  References block.
]

// A rookery `#footnote` written OUTSIDE any note — no enclosing Footnotes
// block to claim it, so it falls to `#show: rookery`'s document-wide
// fallback: page-wide numbering, body in the page's own endnote section,
// same as `plain-note`'s footnote (`content/index.typ`) is scoped to that
// note's own block instead.
A page-level claim#footnote[Falls back to Typst's own footnote mechanism.]
made outside any note.

// Trailing prose citation — AFTER the last note on the page, with nothing
// following to claim it. Claimed by the document-wide trailing block
// `#show: rookery` emits only when something is actually left over.
A trailing citation with nothing after it: @knuth1984.

== Derived labels

// Under the limit: verbatim, no ellipsis. A NAMED slug — unlike
// `demo/pure/titles.typ`'s equivalent — so `check.sh` has a stable path to
// grep; the derivation itself only cares that `title:` is absent, not that
// the id is. The long/truncating case already lives on the root vertebra as
// `derived-note` (`content/index.typ`) and stays there.
#idea("dt-short")[DTSHORT and this body is well under the limit.]

// Nothing to derive from, so this one stays untitled — and must not gain an
// empty title span.
#idea("dt-empty")[]
