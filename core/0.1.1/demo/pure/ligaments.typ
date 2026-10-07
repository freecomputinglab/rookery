// LIGAMENTS (rheo's generic dependency-graph protocol,
// docs/contract.md's "Ligaments" in the rheo repository): proves the
// `idea:`/`idea-body:`/`tag:`/`backlinks:`/"ideas" shapes `_idea-ligaments`
// (state.typ) attaches and binds for a registry record.
//
// NOT `#idea` itself, any more. It WAS registered in-flow, same `#context`
// as the hidden anchor — but ANY added per-note element there, even a
// content-free dummy `#metadata(..)`, MEASURED broke Typst's 5-pass
// introspection convergence: first on `demo/notes` (note-style citations),
// then confirmed on the real waterline build (1767 pages). So emission
// moved to `.marrow.typ`, bundle root, off the FINAL registry — which is
// itself only spliced in by an actual rheo compile, so a plain `typst
// compile` fixture can no longer observe it by writing `#idea[..]` and
// querying afterward (that was this file's ORIGINAL shape; it broke the
// moment emission left idea.typ).
//
// So this tests `_idea-ligaments` DIRECTLY instead: two hand-built records,
// shaped exactly like `#idea`'s own registry entry (title, label, raw,
// body, created, origin, links, tag-links, tags, display — see idea.typ's
// `rec` literal), fed straight to the one function `.marrow.typ` calls per
// record. This is the real logic, not a second copy of it: marrow.typ's
// own per-record loop is now just `_idea-ligaments(id, rec)`.
//
// NOT COVERED HERE, because testing them needs an actual multi-vertebra
// rheo bundle that this package has no automated way to run and inspect
// (rheo's own ligament harvest is Rust-side only, no CLI dump):
// `.marrow.typ`'s vertebra-level `_page-links()` bind loop and its
// tag-link-expansion match loop (the `idea-body:<id>` bind on a matched
// note). Both were verified by hand against a real rheo compile instead.
//
// Build (HTML only — this fixture asserts on the query results, not on
// output):
//   typst compile --features html --format html --root ../.. ligaments.typ build/ligaments.html

#import "../../src/lib.typ": _idea-ligaments

#let etal = (
  title: [Etal],
  label: "etal",
  raw: [Etal body text.],
  body: [Etal body text.],
  created: none,
  origin: "page-a",
  links: (),
  tag-links: (),
  tags: (post: none),
  display: (:),
)

#let cites-etal = (
  title: [Cites],
  label: "cites-etal",
  raw: [See Etal.],
  body: [See Etal.],
  created: none,
  origin: "page-b",
  links: ("idea:etal",),
  tag-links: ((tagged: "post", match: "any"),),
  tags: (draft: none),
  display: (:),
)

// No handle to simulate and no registration to run — `_idea-ligaments`
// always passes `page:` explicitly (never `auto`), so these calls need no
// `#context` of their own; only the `query()` below does.
#_idea-ligaments("idea:etal", etal)
#_idea-ligaments("idea:cites-etal", cites-etal)

// The note with NO origin (plain `typst compile`, or a caller that never
// bound `handle:`) emits nothing at all — asserted below by its absence
// from every query, rather than by a separate case.
#_idea-ligaments("idea:no-origin", (..etal, origin: none))

#context {
  let attaches = query(<rheo-ligament:attach>).map(e => e.value)
  let binds = query(<rheo-ligament:bind>).map(e => e.value)
  let by-key(arr, k) = arr.filter(x => x.key == k)

  // `idea:<id>` attach, on the note's OWNING page, carrying an explicit `id`
  // and never the body/raw content.
  let idea-etal = by-key(attaches, "idea:idea:etal")
  assert.eq(idea-etal.len(), 1, message: "expected exactly one idea:idea:etal attach")
  assert.eq(idea-etal.first().page, "page-a")
  assert.eq(idea-etal.first().value.id, "idea:etal")
  assert("body" not in idea-etal.first().value, message: "idea: attach must not carry body")
  assert("raw" not in idea-etal.first().value, message: "idea: attach must not carry raw")

  // The flat `"ideas"` aggregate: every note (with an origin) attaches
  // under it, each on its own owning page — the only way to enumerate
  // every note id in the corpus. `idea:no-origin` must NOT be among them.
  let ideas-agg = by-key(attaches, "ideas")
  assert.eq(ideas-agg.len(), 2, message: "expected one ideas attach per originated note")
  assert.eq(
    ideas-agg.map(x => x.value.id).sorted(),
    ("idea:cites-etal", "idea:etal"),
  )

  // `idea-body:<id>` is its OWN key, separate from `idea:<id>` — a prose-only
  // edit changes this value, not the record `idea:<id>`/`ideas` carry.
  let body-etal = by-key(attaches, "idea-body:idea:etal")
  assert.eq(body-etal.len(), 1)
  assert.eq(type(body-etal.first().value), content)

  // One `tag:<t>` attach per tag a note carries, valued with the note's id.
  assert.eq(by-key(attaches, "tag:post").len(), 1)
  assert.eq(by-key(attaches, "tag:post").first().value, "idea:etal")
  assert.eq(by-key(attaches, "tag:draft").len(), 1)
  assert.eq(by-key(attaches, "tag:draft").first().value, "idea:cites-etal")

  // `backlinks:<x>` — the forward half of a backlink — attached on the
  // LINKING note's own page (cites-etal, on page-b), valued with the
  // linking note's id.
  let bl = by-key(attaches, "backlinks:idea:etal")
  assert.eq(bl.len(), 1)
  assert.eq(bl.first().page, "page-b")
  assert.eq(bl.first().value, "idea:cites-etal")

  // BINDS, on page-b (cites-etal), which links to etal (over-bound
  // regardless, since `_outbound` cannot cheaply tell a transclusion from
  // a plain link/ref apart) and selects it again via a tag-selector:
  assert.eq(binds.filter(x => x.key == "idea:idea:etal" and x.page == "page-b").len(), 1)
  assert.eq(binds.filter(x => x.key == "idea-body:idea:etal" and x.page == "page-b").len(), 1)
  assert.eq(binds.filter(x => x.key == "tag:post" and x.page == "page-b").len(), 1)

  // Every note's own minted page binds its own backlinks, attributed to
  // its OWNING VERTEBRA — never a minted page's own handle, which is not a
  // member of rheo's `known_handles` (see `.marrow.typ`'s own banner).
  assert.eq(binds.filter(x => x.key == "backlinks:idea:etal" and x.page == "page-a").len(), 1)
  assert.eq(binds.filter(x => x.key == "backlinks:idea:cites-etal" and x.page == "page-b").len(), 1)

  // page-a (etal) has no outbound links or tag-selectors of its own beyond
  // its own backlinks bind just asserted above.
  assert.eq(binds.filter(x => x.page == "page-a").len(), 1)

  // The no-origin note contributes nothing anywhere.
  assert.eq(attaches.filter(x => "idea:no-origin" in repr(x)).len(), 0)
  assert.eq(binds.filter(x => "idea:no-origin" in repr(x)).len(), 0)

  [ligaments: #attaches.len() attach(es), #binds.len() bind(s)]
}
