#import "../../lib.typ": demo, idea
#import "@rookery/core:0.1.0": window, ideas-outline, idea-body
#show: demo

= A vertebra two levels deep

This page's handle is `sub:deeper:page`, two levels down, so every href it
computes to a minted note page or another vertebra costs two `../` — the
depth-2 case a root-only and a one-level spine cannot catch.

== Window depths

#idea("w-inner", title: [Inner], created: datetime(year: 2024, month: 1, day: 5))[
  The innermost note, unfurled only when a window's depth budget reaches it.
]

#idea("w-outer", title: [Outer], created: datetime(year: 2024, month: 6, day: 1))[
  First block of Outer's body.

  Second block, with #window("w-inner") transcluded one level down.

  Third block — at depth 1 (the document default) the nested window above
  collapses to a bare permalink instead of re-expanding; at depth 2 it
  unfurls as a real window.

  Fourth block, so `limit:` below has something to truncate.
]

#idea("w-early", title: [Early], created: datetime(year: 2023, month: 3, day: 1))[
  An early note, for `sort: "date"` to place ahead of Outer/Inner.
]

// depth: 0 — a LINK to the note's page, no body at all.
#window("w-outer", depth: 0)

// depth: 1 (auto/default) — renders Outer once, collapsing its own nested
// #window("w-inner") to a bare permalink.
#window("w-outer", depth: 1)

// depth: 2 — unfurls the nested #window("w-inner") as a real window too.
#window("w-outer", depth: 2)

// limit: 2 — only Outer's first two blocks, then a grey ellipsis.
#window("w-outer", limit: 2)

// folded: true — same block, `<details>` starts closed.
#window("w-outer", folded: true)

// show-date: true — the resolved `created` date appears at the right-hand
// end of the hat, regardless of whether `#idea` itself was told to show one.
#window("w-outer", show-date: true)

// sort: "date" — naming a sort orders the WHOLE selection (oldest first),
// unlike the default `auto`, which keeps call-site order.
#window(("w-outer", "w-early", "w-inner"), sort: "date")

// sort: "lexicographic" — orders by id text instead.
#window(("w-outer", "w-early", "w-inner"), sort: "lexicographic")

// `#idea-body` resolves a name against this document's configured prefix
// (default `idea:`), so it reaches "w-outer" above with no `ctx:` and no
// import from `lib.typ` — the pure accessor `@rookery/search`'s preview pane
// is built on.
#context [
  w-outer's body in full, all four blocks: #idea-body("w-outer")

  w-outer's body, truncated to its first two blocks: #idea-body("w-outer", limit: 2)
]

== Cycles

The package's termination claim: a self-window or an A-windows-B/B-windows-A
cycle bottoms out at the depth asked for instead of re-expanding forever.

#idea("self-loop", title: [Self-loop])[
  This note windows itself: #window("self-loop") — at the document default
  depth (1) that nested window collapses to a bare permalink rather than
  re-expanding.
]

#idea("cycle-a", title: [Cycle A])[
  Cycle A windows Cycle B: #window("cycle-b")
]
#idea("cycle-b", title: [Cycle B])[
  Cycle B windows Cycle A: #window("cycle-a")
]

// Rendering either at the top level must terminate at whatever depth is
// asked for rather than looping.
#window("self-loop")
#window("cycle-a")
#window("cycle-a", depth: 3)

== A tag window written inside a tagged note

A regression fixture: a `#window(tags: ..)` written inside a note carrying
that same tag must transclude every note carrying the tag, INCLUDING the
window's own ancestors — being an ancestor of the window does not exempt a
note from it.

#idea("wt-one", title: [WT one], tags: "wt")[First.]
#idea("wt-two", title: [WT two], tags: "wt")[Second.]

#idea("wt-outer", title: [WT outer], tags: "wt")[
  An outer note, itself tagged `wt`, holding a nested note that holds the
  window.

  #idea("wt-inner", title: [WT inner], tags: "wt")[
    The window lives here, and selects the tag its own ancestors carry.

    #window(tags: "wt", folded: true)
  ]
]

#idea("wt-three", title: [WT three], tags: "wt")[Third, written after the window.]

== Outline forms

#idea(title: [Outline root])[
  An outlined parent.

  #idea("outline-child", title: [Outline child], tags: ("draft",))[
    A nested, titled child — shows one level deep in the outline.
  ]
]

// The page form — this PAGE's own ideas only, per `state("rheo-handle")`.
// Under rheo, unlike under a native compile, this genuinely differs from the
// rookery-wide form below: every other note on this page belongs to this
// vertebra, but so does every note elsewhere in the rookery, and only the
// rookery-wide form lists those too.
#ideas-outline(title: [This page's ideas])

// `rookery-wide: true` — every note in the rookery, not only this page's.
#ideas-outline(title: [Whole rookery], rookery-wide: true)

// `depth: 1` — caps to the top level only, dropping "Outline child".
#ideas-outline(title: [Depth-capped], rookery-wide: true, depth: 1)

// `title: none` — omits the heading entirely; the list still renders.
#ideas-outline(title: none, rookery-wide: true)
