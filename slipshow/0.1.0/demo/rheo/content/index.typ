// The TAG-QUERY route: `#slipshow(tags: ..)` reads its slip list out of the
// registry via `ideas(values: true)` (`select.typ`'s `_slip-rows-from-query`),
// rather than from an explicit array — the code path `explicit.typ` does not
// exercise at all.
#import "lib.typ": demo
#import "@rookery/core:0.1.0": idea
#import "@rookery/slipshow:0.1.0": slip, slipshow
#show: demo

= Deck built from a tag query

The five notes below are ordinary `@rookery/core` ideas, authored right here
on this page. `#slipshow` at the bottom re-resolves them by tag and renders
them again, in `slip-order`, inside its own deck.

#slip("opener", title: [Selected by tag], fullscreen: true, tags: ("demo-index",))[
  A fullscreen slip. `#slipshow` picks this note up because it carries the
  `slip` tag, not because it is written near the call below — the two have no
  positional relationship at all.
]

#slip("with-background", title: [A background of its own], background: rgb("#f4ede1"), tags: ("demo-index",))[
  `background:` becomes an inline `style="background: ..."` on this slip's
  `<section>`, computed from the colour's own hex form.
]

#slip("with-enter", title: [A different camera action], enter: "focus", tags: ("demo-index",))[
  This slip overrides the deck's default `scroll` entry with `focus`, so its
  `<section>` carries its own `data-enter` attribute rather than relying on
  the one set on `div.slipshow`.
]

#slip("with-order", title: [Pinned ahead of the rest], order: 3, tags: ("demo-index",))[
  An explicit `slip-order` sorts before every slip that has none, regardless
  of the position either was written in.
]

#idea("plain-note", title: [No slip options at all], tags: ("slip": none, "demo-index": none))[
  A bare `#idea`, tagged `slip` by hand rather than through `#slip` — it
  carries none of `#slip`'s presentation keys. The deck still has to resolve
  and render it under its own defaults.
]

// `ideas()` reads the whole project's registry, not just this page
// (`@rookery/core`'s `data.typ`; `state.typ`'s own comment on `_registry`:
// "a note may be excluded in one file and linked from another, and `.final()`
// is what makes every reader agree"). A bare `tags: "slip"` here would also
// pull in the slips authored on `explicit.typ`, `predicate.typ` and
// `deck.typ`. `demo-index` scopes the query to the five notes above, the same
// way `@rookery/search`'s own demo scopes its fixture tags away from the rest
// of its page.
//
// Every slip above also renders once already, at its own authored position —
// that copy is an ordinary note, exactly like a bare `#idea`. The deck below
// is a SECOND view of the same five notes, transcluded through `#window`
// (`select.typ`'s `kind: "row"` route): a tag-queried deck is always an
// additional view onto content that already lives somewhere, never its only
// home. `explicit.typ` is the route for a deck that should have no such
// twin.
#slipshow(tags: ("slip", "demo-index"), match: "all")
