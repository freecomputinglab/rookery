// LIGAMENTS: `_outline-merge` (outline.typ) — the narrowed `#ideas-outline`'s
// spine-ordered merge of this compile's live entries with every other
// vertebra's `outline` attach. Two fed pages (`page-a`, `page-c`) around one
// live page (`page-b`), plus a stale fed run for `page-b` that must lose to
// its live entries, and a fed id missing from the registry that must drop.
//
// Build (HTML only — asserts on values, renders nothing):
//   typst compile --features html --format html --root ../.. outline-merge.typ build/outline-merge.html

#import "../../src/lib.typ": _outline-merge

#let reg = (
  "idea:a1": (title: [A one], label: "a1", tags: (post: none)),
  "idea:a2": (title: none, label: "a2", tags: (:)),
  "idea:c1": (title: [C one], label: "c1", tags: (:)),
)
#let ref-text = it => none
#let live = (
  (depth: 0, title: "B one", loc: none, handle: "page-b", tags: (:), id: "idea:b1"),
)
#let fed = (
  (page: "page-c", value: ((id: "idea:c1", depth: 0), (id: "idea:gone", depth: 1))),
  (page: "page-a", value: ((id: "idea:a1", depth: 0), (id: "idea:a2", depth: 1))),
  (page: "page-b", value: ((id: "idea:stale", depth: 0),)),
)

#let merged = _outline-merge(("index", "page-a", "page-b", "page-c"), live, ("page-b",), fed, reg, ref-text)
#assert.eq(merged.map(e => e.id), ("idea:a1", "idea:a2", "idea:b1", "idea:c1"))
#assert.eq(merged.map(e => e.depth), (0, 1, 0, 0))
#assert.eq(merged.map(e => e.handle), ("page-a", "page-a", "page-b", "page-c"))
#assert.eq(merged.at(0).title, "A one")
// Title-less: named by its label, as a live payload (no `raw`) would be.
#assert.eq(merged.at(1).title, "a2")
#assert.eq(merged.at(0).tags, (post: none))

// No ligaments (`fed: none`, a full build): live entries alone, bucketed.
#assert.eq(_outline-merge(("page-a", "page-b"), live, (), none, (:), ref-text).map(e => e.id), ("idea:b1",))

outline-merge OK
