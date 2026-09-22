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
//
// A REPEATED payload still has two shapes underneath, though: the ordinary
// replay above, and two SEPARATE authored notes that happen to be
// byte-identical (the same reading-list line written twice), which collide
// on the same derived id and therefore also carry the same payload. Nothing
// in the payload tells these apart — the split is `figure(kind: IK)`
// PLACEMENTS versus `<rookery-replay>` STAMPS. `_flatten`'s IK rule
// (transclusion.typ) rebuilds a note's card every time it finds one nested
// inside a body it is re-placing — a window, a minted page — and stamps the
// id it rebuilt; a note's own direct rendering, at its one true call site,
// is never rebuilt and so is never stamped. `placements - stamps` is
// therefore the number of genuine call sites under that id: 1 for an
// ordinary replayed note, 2 or more only when two authored calls actually
// landed on the same name.

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
// id; otherwise, for an id whose one repeated payload turns out to have two
// or more genuine call sites (see the banner above), returns a warning
// record for it instead of failing the build — two identical notes still
// merge into one name, which is a fact for the author to notice, not an
// error. Returns an array of `(id: str, message: str)` records, one per
// such id, empty when there is nothing to warn about.
//
// Walks every note marker in the whole bundle exactly once, which is why it
// belongs at bundle root and has exactly two callers: `.marrow.typ` (under
// rheo, where marrow itself is that root) and `template.typ` (without rheo,
// guarded there so it does not also run once per vertebra under rheo).
// Each caller decides where its warnings are safe to show — bundle-root
// content under rheo cannot carry visible output of its own (`text is not
// allowed at the top-level in bundle export`), so this function only ever
// hands back data, never content.
//
// PLAIN, not `context { .. }`, unlike its own name might suggest: a
// `context` expression always evaluates to contextual content, even called
// from inside an enclosing context, so wrapping it here would hand every
// caller content instead of the array they iterate — `.marrow.typ` calls
// this bare, already inside its own bundle-root `#context`, and
// `template.typ` wraps the call itself in `context { .. }` (the same
// pattern `_page-links`/`_page-links-beacon` already use). `query()` below
// is what actually needs context, supplied by whichever caller reaches it.
#let _assert-unique-names() = {
  let by-id = (:)
  let placements = (:)
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
    placements.insert(id, placements.at(id, default: 0) + 1)
    let seen = by-id.at(id, default: ())
    if seen.find(p => p == v) == none {
      by-id.insert(id, seen + (v,))
    }
  }
  let stamps = (:)
  for el in query(<rookery-replay>) {
    let id = el.value.at("rookery-replay", default: none)
    if id == none { continue }
    stamps.insert(id, stamps.at(id, default: 0) + 1)
  }
  let warnings = ()
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
    let genuine = placements.at(id, default: 0) - stamps.at(id, default: 0)
    if payloads.len() == 1 and genuine >= 2 {
      warnings.push((
        id: id,
        message: "@rookery/core: " + str(genuine) + " identical notes all resolved to "
          + "the name `" + id + "` — " + _describe(payloads.at(0)) + ". They have "
          + "merged into one note under that name; pin a name on one of them — "
          + "`#idea(<some-name>, ..)` — or give it a distinct `title:` to tell them "
          + "apart.",
      ))
    }
  }
  warnings
}

// Renders one `_assert-unique-names` warning record as visible content — the
// channel this package uses for a build-time notice that must not fail the
// build, Typst having no `warning()` of its own. A caller places this
// wherever is safe for it: inline, for `template.typ`'s per-vertebra call
// (an ordinary page, where visible content is always allowed), or on the
// affected note's own minted page, for `.marrow.typ`'s bundle-root call
// (bundle-root content itself is not — a bare paragraph there hard-errors
// with "text is not allowed at the top-level in bundle export").
#let _dup-warning-content(w) = if _target() == "html" or _target() == "epub" {
  html.elem("p", attrs: (class: _c("dup-warning"), data-rookery: "dup-warning"), "⚠ " + w.message)
} else {
  block(text(fill: red, "⚠ " + w.message))
}
