// The ten notes every other page in this example reaches into, five written
// as `#idea` and five as `#slip`, all sharing one `talk` tag. Every name is
// PINNED, never an auto id: `index.typ`'s `slips:` array and
// `predicate.typ`'s `where:` both address these notes by name/label, and
// core's unnamed-note ids shift whenever an earlier note is inserted (see
// `#idea`'s own header, `@rookery/core`'s `idea.typ`), which would silently
// repoint either.
//
// The `slip`-authored half carries a deliberate spread of options — one
// `fullscreen`, one `background`, one non-default `enter`, one explicit
// `order` — so `index.typ`, `tagged.typ`, and `inline.typ` each have
// something besides the tag to show. The `idea`-authored half carries no
// `slip-*` option at all, which is the whole point of this example: a plain
// note is not a lesser slide, it is a slide that took the deck's defaults.
#import "lib.typ": template
#import "@rookery/core:0.1.0": idea
#import "@rookery/slipshow:0.1.0": slip
#show: template

= The corpus

Ten notes, read by name or by tag from every other page in this project —
never rendered as a deck here. This page just proves they exist and reads
like an ordinary rookery in the process.

#slip("opening", title: [Welcomes the room], fullscreen: true, tags: "talk")[
  This talk is itself a mixed deck: some slides are plain notes, some are
  `#slip`s with staging of their own. Nobody in the room needs to know which
  is which — that is the whole point.
]

#idea("intro-question", title: [The question this talk answers], tags: "talk")[
  Can a presentation slide be an ordinary note in disguise? Yes — and this
  deck is the proof, walking through the three ways to reach one.
]

#slip(
  "background-note",
  title: [Where this project came from],
  background: rgb("#eaf2ff"),
  tags: "talk",
)[
  A rookery starts as a folder of atomic ideas nobody presents.
  `@rookery/slipshow` turns the same ideas into a deck without asking the
  author to duplicate a single sentence of them.
]

#idea("plain-context", title: [Context a plain idea is happy to carry], tags: "talk")[
  This slide carries no `slip-*` options at all — no fullscreen, no
  background, no custom entrance. It simply takes whatever the deck around it
  already decided.
]

#slip(
  "method-overview",
  title: [Method: how the study was run],
  enter: "focus",
  tags: "talk",
)[
  Ten notes, five written as `#idea`, five as `#slip`, all sharing one tag.
  The camera focuses in on this slide rather than scrolling to it — the
  deck's one non-default entrance.
]

#idea("method-detail", title: [Method: the specific measurements taken], tags: "talk")[
  What actually gets checked: section counts, id order, and whether options
  survive being rendered as raw content instead of looked up by name.
]

#slip(
  "order-example",
  title: [Pinned mid-deck by an explicit order],
  order: 5,
  tags: "talk",
)[
  A `slip-order` tag of 5 puts this note here regardless of when it was
  written — useful whenever presentation order and authoring order diverge.
]

#idea("discussion", title: [What the results might mean], tags: "talk")[
  If a plain note can sit in a deck unmodified, a rookery never has to choose
  between being a knowledge base and being a talk.
]

#slip("results", title: [The headline result], tags: "talk")[
  Three routes into a mixed deck, one honest caveat about `tags: "slip"`, and
  not a single sentence duplicated between the notes and the slides.
]

#idea("closing", title: [Thanks and questions], tags: "talk")[
  That's the deck. Ask about the `where:` route if you want the one nobody
  guesses first.
]
