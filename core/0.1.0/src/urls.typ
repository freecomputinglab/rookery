// Where a note's page lives, spelled three ways: the file rookery mints, the
// href from HERE, and the path from the SITE ROOT.
//
// `#idea-href` and `#idea-path` are the public pair and sit with the private
// helpers they wrap, because the whole point of both is that minting and
// linking cannot disagree — keeping them in one file is what makes that
// checkable by reading.

#import "base.typ": *
#import "state.typ": *

// ---- Note page URLs -------------------------------------------------------
//
// `.marrow.typ` mints one standalone page per note (see that file). Links
// here must agree with what it mints, so BOTH sides build the path with
// `_note-file` — never spell it out twice.
//
// The extension is literally "html" even under EPUB, where rheo-context's
// `ext` is "xhtml": `.marrow.typ` passes `document()` a literal path, so the
// minted file is `.html` whatever the format. Matching that literal is what
// keeps the href resolvable.
//
// The directory is ONE function, `_dir()` (state.typ), because the path and
// the handle mirror each other — `<dir>/<slug>.html` <-> `<dir>:<slug>` — and
// only the path was ever built from `_note-file`; `.marrow.typ` spelled the
// handle's half out by hand. Two literals that must agree, in two files, is a
// drift waiting to happen, so both now read this.
#let _note-file(id) = _dir() + "/" + id.trim(_pfx(), at: start) + ".html"

// The three halves of one note page, in one place: the slug, the file
// `.marrow.typ` mints it to, and the handle it mints it under. The mirror the
// comment above worries about — path and handle staying in sync — lives in
// this one function, and `.marrow.typ` reads it rather than deriving the
// slug, the path and the handle itself.
//
// Must be called from inside `context`: `_pfx` reads the prefix state.
#let _note-page(id) = {
  let slug = id.trim(_pfx(), at: start)
  (slug: slug, file: _note-file(id), handle: _dir() + ":" + slug)
}

// Depth-relative href from the CURRENT page to a note's standalone page, or
// `none` when no such page exists to link to:
//   - plain `typst compile` with no rheo — nothing mints per-note pages;
//   - rheo with no `ext` in its context — the combined PDF target, where
//     `.marrow.typ` is skipped outright.
// Both fall back to a `#link(label(id))` at the call site, which still lands
// on the note's anchor wherever it was written.
//
// Mirrors rheo's own cross-vertebra link rule (crates/core/src/typ/rheo.typ):
// the current page's handle comes from `state("rheo-handle")`, published per
// #document by the bundle source, and each `:` level costs one `../`. This is
// why `.marrow.typ` mints via `rheo-document` with an explicit handle — a
// bare `document()` inherits the previous page's handle and every href
// computed on a minted page comes out at the wrong depth.
//
// `handle: auto` reads `state("rheo-handle").get()` itself, as always. A
// caller that ALREADY resolved this page's own handle a moment earlier — as
// `#idea`'s own card-rendering context does, to store `origin` on the
// registry record — passes it straight through instead: one fewer read of
// the same state from a second source position in the same context, which
// is one fewer thing for Typst's convergence loop to reconcile. MEASURED:
// this second read is exactly the site `state("rheo-handle")` was reported
// unstable at once two auto-numbered notes shared a vertebra, even after
// `_scope` itself (state.typ) settled in one attempt — the id was never the
// problem here, a second read of an already-known value was.
#let _note-href(id, handle: auto) = {
  let c = _rheo-ctx()
  if c == none or c.at("ext", default: none) == none { return none }
  let h = if handle != auto { handle } else { state("rheo-handle").get() }
  if type(h) != str { return none }
  _rel-prefix(h) + _note-file(id)
}

// Shared href resolution for the two destinations a note link has:
// `hyperlink-target-minted: true` prefers the note's own minted page, falling
// back to the in-context Typst label when none is minted (plain `typst
// compile`, the combined-PDF target); `false` forces that fallback
// unconditionally, landing on the note where it was hatched. Used by
// `_permalink-paged` (always `true`) and by `#hyperlink` (both its
// explicit-call and `show ref:` forms), so the two cannot drift on what
// either mode means.
// HANDED TO RHEO UNRESOLVED, as `rheo-page:<handle>`, rather than resolved here —
// and the split from `_note-href` above is the whole point of the shape.
//
// Reading `state("rheo-handle")` is correct when it happens in a page's OWN
// context, which is where `idea-href()`'s data consumers call it from:
// `@rookery/search`'s corpus bakes the result into a per-page JSON index that
// is right today and that no show rule could reach. So `_note-href` stays exactly
// as it is.
//
// Inside a note body it is a different question, because a body is REPLAYED —
// onto the vertebra that authored it, into every `#window` transcluding it,
// and onto its own minted page — and a non-converging document collapses
// every copy of a replayed `context` read to ONE shared value.
//
// A show rule installed by the enclosing #document has no such failure mode: it
// applies afresh at each realization, which is why rheo's own cross-vertebra links
// are always right on transcluded content where this is not. So hand the dest
// over and let rheo's per-#document rule answer per page. A note link is then
// correct even while something else in the stack fails to converge, instead of only
// when everything behaves.
//
// A STRING, not a label: Typst 0.15 attaches labels syntactically, so a computed
// `<ideas:slug>` does not exist and `#link(label(..))` fails with "label does not
// exist in the document" before any show rule can run. Only rheo, synthesizing
// bundle source in Rust, can mint a labelled anchor, so a reserved URL scheme is
// the only channel a package has.
//
// REQUIRES the rheo that rewrites the scheme. An older rheo passes it straight
// through and the href ships as a literal `rheo-page:…`, so this is a hard floor,
// not a graceful degradation. `hyperlink-target-minted: false` and every
// non-rheo target still fall back to the label.
#let _resolve-dest(id, hyperlink-target-minted) = {
  if not hyperlink-target-minted { return label(id) }
  let c = _rheo-ctx()
  if c == none or c.at("ext", default: none) == none { return label(id) }
  "rheo-page:" + _dir() + ":" + id.trim(_pfx(), at: start)
}
// ---- #idea-href — where a note's minted page lives, from here -------------
//
//   #context idea-href("etal")   // -> "../ideas/etal.html", or none
//
// Public because another package (`@rookery/search`) has to build links
// to minted pages, and the depth arithmetic is not something a consumer should
// reimplement. Takes a bare name, a full id or a label — whatever `_norm`
// accepts. `none` wherever no page is minted: plain `typst compile` with no
// rheo, and the combined PDF target.
//
// RELATIVE TO WHERE IT IS CALLED. `_note-href` measures depth from
// `state("rheo-handle")`, so the same note yields a different string on a
// nested vertebra than on the root one. That is the point, and it is why a
// caller must not cache the result across pages.
#let idea-href(name) = _note-href(_pfx() + _norm(name))

// ---- #idea-path — where a note's minted page lives, from the SITE ROOT -----
//
//   #context idea-path("etal")   // -> "ideas/etal.html", or none
//
// `#idea-href` above is relative to the page it is called from — right for a
// link written inline in a vertebra's own prose. `#idea-path` is the SAME
// page, but from the site root, for a caller with no page of its own to
// measure depth from — a feed config or sitemap invoked once from shared
// code, not from a vertebra. It reuses `_note-file` directly, skipping
// `_note-href`'s depth arithmetic entirely, and copies its unminted guard:
// `none` under the same two conditions `#idea-href` is — plain
// `typst compile` with no rheo, and the combined PDF target.
#let _note-path(id) = {
  let c = _rheo-ctx()
  if c == none or c.at("ext", default: none) == none { return none }
  _note-file(id)
}
#let idea-path(name) = _note-path(_pfx() + _norm(name))
