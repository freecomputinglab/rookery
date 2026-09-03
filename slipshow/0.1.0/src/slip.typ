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
  ..args,
) = (tagged-idea(SLIP-KEY, exclude-tags: exclude-tags))(
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
