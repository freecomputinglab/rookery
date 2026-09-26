// `#slip` — the package's primitive, an `#idea` variant carrying slipshow
// presentation options. A plain `#idea` remains perfectly usable inside a
// slipshow too — it just arrives with no `slip-*` keys and takes the deck's
// defaults; `#slip` is for a note that wants presentation options of its own.
//
//   #slip("intro", fullscreen: true)[The opening.]
//   #slip(background: blue)[A slip with an auto id.]
//   #slip(<intro>)[..]
//
// `#slip` names `tags:` in its own signature, so it captures a caller's tags
// rather than letting them pass straight through to `#idea`, and merges
// `SLIP-KEY` UNDER whatever the caller passed before calling `#idea` itself.
// That order is why `#slip("x", tags: ("draft",))` keeps the `slip` tag
// instead of losing it: the caller's tags win per key, but the package's own
// key is always present to begin with. `exclude-tags:` is likewise named on
// `#slip`'s own signature rather than left to `..args`, because `#slip` binds
// core's `idea` from package scope — a project's own
// `#let idea = idea.with(exclude-tags: E)` would not otherwise reach it.
#import "@rookery/core:0.1.1": idea, _merge-base-tags
#import "marker.typ": _slip-marker
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
  // matches nothing reaches the sink. So `#slip("x", display-frame: true)` binds
  // the parameter and wins over the default, exactly as it should.
  //
  // TWO, NOT THREE. `display-label` is a `#window` argument and has nothing to do
  // here: a card already prints the authored title alone (`@rookery/core`'s
  // `idea.typ`), so there is no derived label for a `#slip` to suppress.
  display-frame: false,
  display-name: false,
  ..args,
) = {
  // `SLIP-KEY` merges UNDER everything `slip-tags` built, so a call site
  // naming `slip` itself (as an explicit tag or through `base-tags:`) keeps
  // its own value rather than losing it to the package's key.
  let resolved-tags = _merge-base-tags(SLIP-KEY, slip-tags(
    tags: tags,
    fullscreen: fullscreen,
    background: background,
    enter: enter,
    order: order,
    class: class,
    row: row,
    max-width: max-width,
  ))
  // A PLAIN sibling marker, not nested inside `#idea`'s own — see
  // `marker.typ` for why a caller reading this note's options back from an
  // unplaced content value has to find them here rather than inside the
  // deferred `#idea` call below. `title`/`level` come off `..args` since
  // `#slip` does not name either on its own signature.
  _slip-marker((
    title: args.named().at("title", default: none),
    level: args.named().at("level", default: 1),
    tags: resolved-tags,
  ))
  idea(
    exclude-tags: exclude-tags,
    display-frame: display-frame,
    display-name: display-name,
    tags: resolved-tags,
    ..args,
  )
}
