// Reads a note's tags back out of ALREADY-RENDERED content, for a slipshow
// defined as an explicit ordered array of ideas rather than a tag query over
// the registry — the array holds rendered content, not registry records, so
// the `slip-*` options an idea carries are not otherwise reachable from it.
//
// This works because `#idea` (core's `idea.typ`) wraps every note in a
// `figure(kind: IK)` marker whose body carries a `#metadata((.., tags: ..))`
// payload — the same one `_flatten`'s IK rule (`transclusion.typ`) reads to
// rebuild a transcluded note. Reading it back here costs nothing structural:
// no re-registration, no counter step, no rendering.
#import "@rookery/core:0.1.0": IK

// The metadata payload of the first `figure(kind: IK)` marker found in `it`,
// or `none` if there is none. `it` is either the marker itself (an `#idea`'s
// return value, undecorated) or a piece of content that contains one
// somewhere inside it — so both cases walk `.fields()` generically, the same
// way `_outbound` (core's `links.typ`) finds a link buried at any depth
// without special-casing `body`/`child`/`children` by name.
#let slip-meta(it) = {
  if type(it) == array {
    for item in it {
      let found = slip-meta(item)
      if found != none { return found }
    }
    return none
  }
  if type(it) != content { return none }
  if it.func() == figure and it.at("kind", default: none) == IK {
    let m = it.body.children.find(c => c.func() == metadata)
    return if m == none { none } else { m.value }
  }
  for (_, v) in it.fields() {
    let found = slip-meta(v)
    if found != none { return found }
  }
  none
}

// Just the tag dictionary out of `it` — what a `#slipshow` slip reads its
// options from. `(:)` both when `it` carries no idea at all and when it does
// but the idea has no tags: neither is an error, since a slip with no
// options simply takes the deck's defaults.
#let slip-tags-of(it) = {
  let m = slip-meta(it)
  if m == none { (:) } else { m.at("tags", default: (:)) }
}
