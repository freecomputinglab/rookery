// `#ideate` and `limit:` across `styled` scopes: a `#set`/`#show` rule wraps
// everything after it in one `styled` node, and both splits must look inside.
#import "/src/lib.typ": *
#show: rookery

// A rule mid-section: `== Two` sits inside the rule's scope and still splits.
#ideate(separator: heading.where(level: 2))[
  == One
  alpha

  #set text(red)

  beta

  == Two
  gamma
]

#ideate(separator: heading.where(level: 2))[
  == Three
  delta

  #show strong: emph

  *epsilon*

  == Four
  zeta
]

// Rule-only preambles: emitted bare, never minted as a nameless note.
#ideate(separator: heading.where(level: 2))[
  #let x = [DEF]

  == Five
  eta
]

#ideate(separator: heading.where(level: 2))[
  #set text(red)

  == Six
  theta
]

#idea("src")[
  #set text(red)

  first paragraph

  second paragraph

  third paragraph
]

#window("src", limit: 1)

#context {
  let ids = query(figure.where(kind: "rheo-idea")).len()
  assert.eq(ids, 7, message: "expected seven notes, got " + str(ids))
}
