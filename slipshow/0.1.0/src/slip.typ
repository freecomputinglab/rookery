// `#slip` — the package's primitive, an `#idea` variant carrying slipshow
// presentation options. A plain `#idea` remains perfectly usable inside a
// slipshow too — it just arrives with no `slip-*` keys and takes the deck's
// defaults; `#slip` is for a note that wants presentation options of its own.
//
//   #slip("intro", fullscreen: true)[The opening.]
//   #slip(background: blue)[A slip with an auto id.]
//   #slip(<intro>)[..]
//
// Built on `tagged-idea` rather than `idea.with(tags: (slip: none))`: an
// explicit `tags:` at the call site OVERRIDES a value bound by `.with()`, so
// `#slip("x", tags: ("draft",))` would silently drop the `slip` tag — exactly
// the tag `#slip` exists to add. `tagged-idea`'s returned closure merges
// instead. `exclude-tags:` is threaded through for the same reason: that
// closure calls the `idea` captured in core's package scope, so a project's
// own `#let idea = idea.with(exclude-tags: E)` would not otherwise reach
// `#slip` at all.
#import "@rookery/core:0.1.0": tagged-idea
#import "tags.typ": *

#let slip(
  fullscreen: false,
  background: none,
  enter: none,
  order: none,
  class: none,
  row: none,
  max-width: none,
  tags: none,
  exclude-tags: (),
  // CORE'S OWN TWO CHROME SWITCHES, with their defaults INVERTED here — the
  // same inversion `#slipshow` makes for a queried slip, and it has to be made
  // twice because the two routes render at different times. `#slipshow` renders
  // a QUERIED slip itself and can pass whatever it likes; an explicit-array slip
  // was already rendered at THIS call site, long before any deck saw it, so
  // nothing downstream can reach inside it. Setting the default here is what
  // makes the array route agree with the query route.
  //
  // It also settles the double render: a `#slip` written on a page appears
  // twice in the common fixture — once inline where it was authored, once
  // inside the deck that queries it back — and binding the defaults on the
  // constructor makes those two copies look the same.
  //
  // NO DUPLICATE-ARGUMENT HAZARD from passing these alongside `..args`: Typst
  // binds a named argument to a matching named PARAMETER first, and only what
  // matches nothing reaches the sink. So `#slip("x", show-frame: true)` binds
  // the parameter and wins over the default, exactly as it should.
  //
  // TWO, NOT THREE. `show-label` is a `#window` argument and has nothing to do
  // here: a card already prints the authored title alone (`@rookery/core`'s
  // `idea.typ`), so there is no derived label for a `#slip` to suppress.
  show-frame: false,
  show-id: false,
  ..args,
) = (tagged-idea(SLIP-KEY, exclude-tags: exclude-tags))(
  show-frame: show-frame,
  show-id: show-id,
  tags: slip-tags(
    tags: tags,
    fullscreen: fullscreen,
    background: background,
    enter: enter,
    order: order,
    class: class,
    row: row,
    max-width: max-width,
  ),
  ..args,
)
