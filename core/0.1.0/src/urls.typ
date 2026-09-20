// Where a note's page lives, spelled three ways: the file rookery mints, the
// href from HERE, and the path from the SITE ROOT. `#idea-href` and
// `#idea-path` are the public pair, kept with the private helpers they wrap.

#import "base.typ": *
#import "state.typ": *

// `.marrow.typ` mints one page per note through this same function, so the
// two sides cannot drift. The extension is literally "html" even under
// EPUB (`ext` is "xhtml" there): `.marrow.typ` passes `document()` that
// literal path regardless of format. `_dir()` (state.typ) keeps
// `<dir>/<slug>.html` and `<dir>:<slug>` mirrors of each other.
#let _note-file(id) = _dir() + "/" + id.trim(_pfx(), at: start) + ".html"

// Must be called from inside `context`: `_pfx` reads the prefix state.
#let _note-page(id) = {
  let slug = id.trim(_pfx(), at: start)
  (slug: slug, file: _note-file(id), handle: _dir() + ":" + slug)
}

// Depth-relative href from the CURRENT page to a note's page, or `none` when
// none is minted (plain `typst compile`, or rheo's combined-PDF target) —
// callers then fall back to `#link(label(id))`. Mirrors rheo's cross-vertebra
// rule: the handle comes from `state("rheo-handle")`, each `:` level costs
// one `../`. `handle: auto` reads that state itself; a caller that already
// resolved its own handle passes it through instead — MEASURED:
// `state("rheo-handle")` was reported unstable on a second same-context read
// once two auto-numbered notes shared a vertebra.
#let _note-href(id, handle: auto) = {
  let c = _rheo-ctx()
  if c == none or c.at("ext", default: none) == none { return none }
  let h = if handle != auto { handle } else { state("rheo-handle").get() }
  if type(h) != str { return none }
  _rel-prefix(h) + _note-file(id)
}

// Shared href resolution: `hyperlink-target-minted: true` prefers the note's
// minted page, falling back to the Typst label when none is minted; `false`
// forces that fallback always. Handed to rheo UNRESOLVED, as
// `rheo-page:<handle>`, because a note body is REPLAYED onto every
// transcluding `#window` and its own minted page — where `_note-href`'s
// per-context read would collapse to one shared value on a non-converging
// document — and a show rule on the enclosing `#document` re-applies
// correctly per realization instead. A STRING, not a label: Typst 0.15
// attaches labels syntactically, so only rheo, synthesizing bundle source in
// Rust, can mint the real anchor. REQUIRES the rheo that rewrites this
// scheme; an older rheo ships the literal `rheo-page:…` string.
#let _resolve-dest(id, hyperlink-target-minted) = {
  if not hyperlink-target-minted { return label(id) }
  let c = _rheo-ctx()
  if c == none or c.at("ext", default: none) == none { return label(id) }
  "rheo-page:" + _dir() + ":" + id.trim(_pfx(), at: start)
}
//   #context idea-href("etal")   // -> "../ideas/etal.html", or none
// Public because `@rookery/search` builds links to minted pages. RELATIVE TO
// WHERE IT IS CALLED — a caller must not cache the result across pages.
#let idea-href(name) = _note-href(_pfx() + _norm(name))

//   #context idea-path("etal")   // -> "ideas/etal.html", or none
// The same page, from the site root — for a caller with none of its own.
#let _note-path(id) = {
  let c = _rheo-ctx()
  if c == none or c.at("ext", default: none) == none { return none }
  _note-file(id)
}
#let idea-path(name) = _note-path(_pfx() + _norm(name))
