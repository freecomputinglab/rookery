// The hand-written half of the bibliography: this note's body is authored,
// not swept — `index.typ`'s `all()` mints every OTHER entry with the empty
// body a swept note always gets. A hand-written `#citation` for a key always
// wins over `all()`, no matter where the two calls sit relative to each
// other.
#import "lib.typ": demo, refs

#show: demo

= A cited entry

#(refs.citation)("okafor2019")[
  Cited directly, because its accounting of responsiveness as a budget spent
  reframes what the rest of this bibliography treats as measured only after
  the fact.
]
