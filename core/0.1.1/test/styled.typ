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

// A NAMED body whose only authored child is a `context`, under a `#set` scope:
// the shape of a document wrapped by a site helper that adds
// `set heading(offset: 1)` and then branches on `target()`. The `context`
// spreads out as `styled(context)`, which `_inert` reads as postamble; the
// `#ideate-name` beacon must still mint it.
#ideate(separator: none, title: [Named context],
  ideate-name("named-context") + {
    set heading(offset: 1)
    [#context if target() == "paged" [paged body] else [web body]]
  },
)

#context {
  let ids = query(figure.where(kind: "rheo-idea")).len()
  assert.eq(ids, 8, message: "expected eight notes, got " + str(ids))
  assert.eq(query(<idea:named-context>).len(), 1,
    message: "a named body holding only a context was not minted")
}
