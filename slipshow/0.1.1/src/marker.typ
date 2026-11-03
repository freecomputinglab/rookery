// Reads a `#slip`'s own options back out of a content VALUE — a variable
// holding a `#slip`/`#idea` call's return, not yet placed in any document —
// for a slipshow defined as an explicit ordered array rather than a tag
// query over the registry. The array holds content, not registry records,
// so the `slip-*` options an idea carries are not otherwise reachable
// from it.
//
// This cannot walk `#idea`'s own marker (a `figure(kind: IK)`, core's
// `idea.typ`): `#idea` resolves a note's id and registers it from inside a
// `context` block, so its return value is itself a `context` node, and a
// Typst `context` node's body is opaque to `.fields()` until Typst actually
// realizes it — which reading an unplaced content value never does. `#slip`
// (`slip.typ`) therefore emits a second, PLAIN `#metadata` marker of its
// own, a sibling to the deferred `#idea` call rather than nested inside it,
// carrying exactly the payload this file needs: title, level and the
// resolved tags dictionary. That marker is what `slip-meta` looks for.
#let _SLIP-META = "rookery-slip-meta"

#let _slip-marker(payload) = [#metadata(((_SLIP-META): payload))]

// The `#slip` payload dictionary buried in `it` (a `#slip`'s return value,
// or any content containing one), or `none` if there is none. `it` walks
// generically over `.fields()`, the same way `_outbound` (core's
// `links.typ`) finds a link buried at any depth without special-casing
// `body`/`child`/`children` by name — a `#slip` marker can sit at any depth
// once folded into a bigger tree, such as a `+`-joined sequence.
#let slip-meta(it) = {
  if type(it) == array {
    for item in it {
      let found = slip-meta(item)
      if found != none { return found }
    }
    return none
  }
  if type(it) != content { return none }
  if it.func() == metadata and type(it.value) == dictionary and _SLIP-META in it.value {
    return it.value.at(_SLIP-META)
  }
  for (_, v) in it.fields() {
    let found = slip-meta(v)
    if found != none { return found }
  }
  none
}

// Just the tag dictionary out of `it` — what a `#slipshow` slip reads its
// options from. `(:)` both when `it` carries no `#slip` marker at all and
// when it does but the idea has no tags: neither is an error, since a slip
// with no options simply takes the deck's defaults.
#let slip-tags-of(it) = {
  let m = slip-meta(it)
  if m == none { (:) } else { m.at("tags", default: (:)) }
}
