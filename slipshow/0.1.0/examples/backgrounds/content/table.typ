// A borderless `table` over a gradient background. Typst's HTML export
// silently drops `grid` — a slip built with one compiles clean, renders
// correctly in the PDF branch, and is empty in the browser — which is a
// constraint no assertion in this package's own code can express. `table`
// is the safe choice for tabular layout inside a slip, and this project
// builds both formats specifically so the trap is reachable here rather
// than only documented.
#import "lib.typ": template
#import "@rookery/slipshow:0.1.0": slip, slipshow
#show: template

= A table over a gradient

#slip(
  "table-over-gradient",
  title: [Three camera actions, over a gradient],
  background: gradient.linear(rgb("#0f2027"), rgb("#2c5364"), angle: 90deg),
  tags: ("bg-table",),
)[
  #table(
    columns: 2,
    stroke: none,
    [*Action*], [*What it moves*],
    [`scroll`], [Brings the slip fully into view when it fits.],
    [`focus`], [Centers the slip on both axes and zooms to fill the viewport.],
    [`left`], [Aligns the slip's left edge to the viewport's left edge.],
  )
]

#slipshow(tags: ("slip", "bg-table"), match: "all")
