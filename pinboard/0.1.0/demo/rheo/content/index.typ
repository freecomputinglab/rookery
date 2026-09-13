#import "@rookery/core:0.1.0": idea, rookery
#import "@rookery/pinboard:0.1.0": pinboard

// A THEMED project, deliberately: a card is a `#window`, so the properties
// set here reach the cards on the board exactly as they reach the notes on
// the page, and the demo would not show that with the defaults.
#show: rookery.with(border-color: rgb("#3366ff"), rule-width: "3px")

= `@rookery/pinboard` demo

A handful of notes, laid out as a board below — each card a window on its
note, draggable by the row carrying its id and openable by clicking it, while
the prose underneath goes on changing.

#idea("outline", title: [Outline])[
  The shape of the piece: three acts, with the turn landing in the second.
]

#idea("interview", title: [The interview])[
  What the source actually said, before it was smoothed into prose.
]

#idea("scene-one", title: [Opening scene])[
  Where the reader is standing when the piece begins.
]

#idea("counterargument", title: [The counterargument])[
  What a skeptical reader would say, and the answer to it.
]

#pinboard()
