// Whether two different notes ever resolved to the same id — the one check
// content-derived naming cannot make for itself. A note's id is a pure
// function of its own content (`idea.typ`), so nothing else confirms that
// two notes sharing a name are the same note replayed rather than a
// collision.
//
// Typst's own duplicate-label error does not cover this: it fires only for a
// label something happens to `#link`/`#ref`, and when it fires it names that
// reference, not either note. This module instead groups every note marker
// in the bundle by its resolved id and compares the PAYLOAD under each id —
// the dictionary `#idea` stores at registration (`idea.typ`'s `metadata`
// call, read back the same way `transclusion.typ`'s IK rule reads it).
// Two DISTINCT payloads sharing an id are a real collision; one payload
// repeated under an id is the ordinary case — a note replayed by its
// authoring vertebra, a minted page, and every `#window` transcluding it all
// carry the identical payload.

#import "base.typ": *
#import "state.typ": *

// Names a note for the panic message below: its title where it has one,
// otherwise the opening of its body, capped to keep the message short.
#let _describe(v) = {
  let t = _plain(v.title)
  let s = if t.trim() != "" { t } else { _plain(v.body) }
  s = s.trim()
  if s.len() > 60 { s.slice(0, 60) + "…" } else { s }
}

// Panics naming both notes when two distinct payloads resolved to the same
// id. Walks every note marker in the whole bundle exactly once, which is why
// it belongs at bundle root and has exactly two callers: `.marrow.typ` (under
// rheo, where marrow itself is that root) and `template.typ` (without rheo,
// guarded there so it does not also run once per vertebra under rheo).
#let _assert-unique-names() = context {
  let by-id = (:)
  for el in query(figure.where(kind: IK)) {
    // Defensive, unlike the IK rule this mirrors (`transclusion.typ`): a
    // figure body built somewhere this module cannot see could in principle
    // be a single element rather than a sequence, and a single element has
    // no `children`.
    let ch = if el.body.has("children") { el.body.children } else { (el.body,) }
    let m = ch.find(c => c.func() == metadata)
    if m == none { continue }
    let v = m.value
    // Mirrors `transclusion.typ`'s IK rule: the id rides on the payload,
    // resolved once at the note's original site rather than recomputed here.
    let id = v.at("id", default: if v.named { _pfx() + v.base } else { none })
    if id == none { continue }
    let seen = by-id.at(id, default: ())
    if seen.find(p => p == v) == none {
      by-id.insert(id, seen + (v,))
    }
  }
  for (id, payloads) in by-id {
    if payloads.len() > 1 {
      panic(
        "@rookery/core: two different notes both resolved to the name `" + id + "`.\n"
          + "  1. " + _describe(payloads.at(0)) + "\n"
          + "  2. " + _describe(payloads.at(1)) + "\n"
          + "Give one of them an explicit name — `#idea(<some-name>, ..)` — or a "
          + "distinct `title:`.",
      )
    }
  }
}
