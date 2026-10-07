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

#import "../../src/lib.typ": _idea-ligaments, _reg-final, _reg-merge, _ligament-rec, _ligament-body, _body-at, _page-links, _label-exists, _window-content, idea

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

// ---- THE READ SIDE: `_reg-final()` / `_reg-merge()` (src/state.typ) -------
//
// Everything above is the WRITE side. Below proves `_reg-final()` and the
// small helpers it is built from — the functions every real reader in this
// package now calls instead of `_registry.final()` (see `rg --hidden
// --no-ignore -c '_registry\.final\(\)' src/state.typ` — exactly one hit,
// `_reg-final`'s own no-ligaments fallback).
//
// `_reg-final()` ITSELF takes no argument — every production call site
// (window.typ, data.typ, outline.typ, transclusion.typ, idea.typ,
// hyperlink.typ, permalink.typ, .marrow.typ) calls it bare, reading the real
// `sys.inputs.rheo-ligaments`. `_reg-merge(ligaments)` is the pure merge
// logic underneath it, taking an already-resolved ligaments value directly —
// a NATIVE Typst dictionary, never through `--input` (rejected outright for
// `rheo-ligaments`, and `--input` is strings-only regardless — see
// state.typ's own banner above `_ligaments`) and never round-tripped through
// `json.encode`/`json(bytes(..))` — a hand-built value matching the shape
// `_reg-merge` expects, standing in for what a real `rheo watch` harvest
// would otherwise feed through `sys.inputs`.
#idea("a", title: [Fresh A])[Fresh A body, registered live in THIS compile.]
// A real anchor for `idea:ligament-note`, purely so this fixture's own
// `_permalink`/`_resolve-dest` (which fall back to `label(id)` with no rheo
// context) have a label to resolve — `_window-content` is called directly,
// further down, with a DIFFERENT, hand-built ligament-style record and body
// for this same id, which is what actually exercises the heading/label
// collision when a transcluded body defines its own label matching a live
// one.
#idea("ligament-note")[Placeholder.]

#context {
  // (a) EQUIVALENCE: ligaments supplied but describing no notes at all must
  // leave an ordinary build completely unaffected — the branch every
  // existing full build takes, now reached via an explicit (rather than
  // absent) ligaments value instead of `sys.inputs`' real absence.
  let reg-no-ligaments = _reg-final()
  let reg-empty-ligaments = _reg-merge((attaches: (ideas: ())))
  assert.eq(
    reg-empty-ligaments,
    reg-no-ligaments,
    message: "ligaments supplied but empty must equal the no-ligaments registry",
  )

  // (b) MERGE, NOT SWAP: a ligament set describing a STALE "a" (this
  // compile's own vertebra just re-registered it, fresher) plus a
  // ligament-ONLY "b" (a note whose vertebra did not run this pass at all).
  // `_reg-final()` must return the LIVE "a" and the ligament "b" — never only
  // one of the two, and never the stale ligament "a".
  let stale-a = (
    title: [Stale A — from a compile before this one],
    label: "a",
    created: none,
    origin: "other-vertebra",
    links: (),
    tags: (:),
    tag-links: (),
    display: (:),
    id: "idea:a",
  )
  let ligament-b = (
    title: [B, known only to ligaments],
    label: "b",
    created: none,
    origin: "other-vertebra",
    links: (),
    tags: (post: none),
    tag-links: (),
    display: (:),
    id: "idea:b",
  )
  let ligaments = (
    attaches: (
      ideas: (
        (page: "other-vertebra", value: stale-a),
        (page: "other-vertebra", value: ligament-b),
      ),
      "idea-body:idea:b": ((page: "other-vertebra", value: [B's flattened body.]),),
    ),
  )
  let merged = _reg-merge(ligaments)
  assert(
    merged.at("idea:a").title == [Fresh A],
    message: "the LIVE idea:a must win over a same-id ligament entry, not the stale ligament title",
  )
  assert("idea:b" in merged, message: "a ligament-only note must be present in the merge")
  assert.eq(merged.at("idea:b").title, [B, known only to ligaments])
  // `_ligament-rec` strips the `id` field `_idea-ligaments`'s `lig-rec` added
  // for `"ideas"` enumeration — a reconstructed record must not be tellable
  // apart from a live one by key set alone.
  assert("id" not in merged.at("idea:b"), message: "_ligament-rec must strip the id field back out")
  // Neither `raw` nor `body` ship through ligaments (see state.typ's own
  // banner on `_ligament-rec`) — a reconstructed record carries neither key
  // at all, until a caller that actually needs the body fetches it.
  assert("body" not in merged.at("idea:b"))
  assert("raw" not in merged.at("idea:b"))

  // `_ligament-body` — fetched SEPARATELY, only when asked for.
  assert.eq(_ligament-body("idea:b", override: ligaments), [B's flattened body.])
  assert.eq(
    _ligament-body("idea:nowhere", override: ligaments),
    none,
    message: "a key ligaments carry nothing under must answer none, not panic or ()",
  )

  // `_body-at` — the one place that actually fetches a ligament-sourced
  // body, and only there. `depth <= 1` returns it as-is; `depth > 1` has no
  // `raw` to re-`_flatten` for a ligament-sourced note (ligaments never
  // carry it), so it falls back to the SAME flattened body rather than
  // crashing — this package's one accepted limitation for a note
  // transcluded from a vertebra that did not run this pass: that note's OWN
  // nested windows do not unfurl any further than depth 1.
  let rec-no-body = merged.at("idea:b")
  assert.eq(_body-at("idea:b", rec-no-body, depth: 1, ligaments: ligaments), [B's flattened body.])
  assert.eq(
    _body-at("idea:b", rec-no-body, depth: 3, ligaments: ligaments),
    [B's flattened body.],
    message: "depth > 1 with no ligament-carried raw must fall back to the flattened body, not panic",
  )
  // A LIVE record (body/raw both present, from `#idea` above) is completely
  // unaffected by any of this — the ligament fallback is never reached.
  let live-a = reg-no-ligaments.at("idea:a")
  assert.eq(_body-at("idea:a", live-a, depth: 1), live-a.body)

  // `_page-links()`: on a narrowed compile the live beacon/mark
  // queries see only THIS pass's own vertebra, so a page-level outbound edge
  // from any other vertebra has to come from `backlinks:<x>` ligament
  // attaches instead. No live window/beacon exists in this plain-compile
  // fixture at all, so every edge below is necessarily ligament-sourced —
  // proving the branch runs, not that it coexists with a live edge (that
  // coexistence is exercised end-to-end only by a real rheo watch session,
  // same caveat this file's WRITE-side tests already carry for
  // `.marrow.typ`'s own page-links bind loop).
  let backlink-ligaments = (
    attaches: (
      ideas: ((page: "other-vertebra", value: stale-a),),
      "backlinks:idea:a": (
        (page: "linking-vertebra-1", value: "idea:elsewhere"),
        (page: "linking-vertebra-2", value: "idea:elsewhere-too"),
      ),
    ),
  )
  let links = _page-links(ligaments: backlink-ligaments)
  assert("idea:a" in links.at("linking-vertebra-1", default: ()))
  assert("idea:a" in links.at("linking-vertebra-2", default: ()))

  // `_label-exists` — the safe existence test hyperlink.typ's href
  // resolution is built on: `query(label(..))` for a label genuinely present
  // in THIS compile, and no panic for one absent, unlike touching
  // `it.element` or laying out `link(label(..))` directly.
  assert(_label-exists("idea:a"), message: "idea:a's own hidden anchor exists in this compile")
  assert(
    not _label-exists("idea:nothing-minted-this-label-anywhere"),
    message: "a label nothing in this compile carries must answer false, not panic",
  )

  // (c) A TRANSCLUDED BODY CARRYING ITS OWN HEADING AND LABEL, reconstructed
  // from ligaments (no `raw`, only a flattened `body`) and rendered through
  // `_window-content` exactly as a real `#window` on a ligament-only note
  // would — alongside ANOTHER heading alias sharing the same label name, to
  // provoke the heading/label collision directly rather than assume its
  // behavior. REPORTED, not asserted: see the paragraph following this
  // block for what was actually observed.
  let collide-rec = (
    title: [Ligament Note With A Heading],
    label: "ligament-note",
    created: none,
    origin: "other-vertebra",
    links: (),
    tags: (:),
    tag-links: (),
    display: (:),
  )
  let collide-body = [
    = Nested Heading <dup-heading-label>
    Prose transcluded from a vertebra that did not run this pass.
  ]
  _window-content("idea:ligament-note", collide-rec, collide-body, false, (:))

  [read-side ligament tests: OK]
}

// A second, real heading sharing the SAME label name as the transcluded
// one above — set up to observe Typst's actual behavior on the collision
// rather than assume it.
//
// OBSERVED (compile this file with `typst compile --features html --format
// html --root ../.. ligaments.typ /dev/null` to reproduce): the compile
// completes cleanly. Typst permits two elements to share one label text —
// it is only a `@ref`/`link(label(..))` TO that label that becomes
// ambiguous ("label occurs multiple times"), and this fixture never
// references `<dup-heading-label>` by name. Nothing here misnumbers either:
// the transcluded heading renders as its own, independent `<h1>`/heading
// element, carrying no shared counter with the page's own headings — this
// package's own heading numbering (where it has any, on the paged target)
// is per-idea, not a single document-wide sequence, so a reconstructed body
// from an unvisited vertebra introducing a heading does not perturb the
// hosting page's own. The one untested edge, flagged rather than silently
// assumed clean: an actual `@dup-heading-label` reference written somewhere
// in the hosting page's own prose WOULD panic "label occurs multiple
// times, which Typst cannot resolve" — the same ambiguity two ordinary,
// non-transcluded headings sharing a label would already cause with no
// ligaments involved at all, so this is an existing Typst constraint, not a
// new failure mode introduced by transclusion from ligaments.
= Nested Heading <dup-heading-label>
