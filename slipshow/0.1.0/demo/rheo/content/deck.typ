// The realistic presentation: a dozen slips with titles, prose, a table and
// fullscreen bookends — the shape this package exists for, not three-word
// placeholders. Built on the EXPLICIT-ARRAY route (`slips: ..`), not a tag
// query: a tag-queried deck transcludes notes that are ALSO rendered at their
// own authored position (see `index.typ`'s comment on that), which for a
// dozen real slides would print the whole deck twice on this one page — once
// as loose notes, once inside `div.slipshow`. Writing the ideas inline in the
// `slips:` array means each one is placed exactly once, inside its own
// `<section>`, which is what a reader opening this page should see.
#import "lib.typ": demo
#import "@rookery/slipshow:0.1.0": slip, slipshow
#show: demo

= Notes on rookery, as a deck

#slipshow(slips: (
  slip("opening", title: [An endlessly scrolling presentation], fullscreen: true)[
    This deck is a dozen `@rookery/core` ideas, laid out by
    `@rookery/slipshow` as one continuously scrollable page. Every slide
    below is a note first and a slide second.
  ],

  slip("why-a-slide-is-a-note", title: [Why a slide is a note])[
    A rookery already stores atomic, interlinked ideas. `#slip` adds nothing
    to that model but a handful of presentation options — `fullscreen`,
    `background`, `enter`, `order`, `class`, `max-width` — so a slip can be
    windowed, searched, and linked exactly like any other idea, and a deck is
    just one more way of looking at notes that already exist.
  ],

  slip("two-primitives", title: [Two primitives])[
    `#idea` registers a note. `#slip` is an `#idea` variant that also tags
    the note `slip` and folds its presentation options into the same tag
    dictionary, because `tags` is the only field on a rookery record
    extensible enough to carry them through to a tag-queried deck.
  ],

  slip("the-camera", title: [The camera, not a transition], enter: "focus")[
    This slip overrides the deck's default `scroll` entry with `focus`,
    which centers it on both axes and zooms it to fill the viewport. There
    is no `transition:` or `duration:` anywhere in this package — the camera
    is the only motion a slip has.
  ],

  slip("camera-actions", title: [Eight actions])[
    #table(
      columns: 2,
      stroke: none,
      [*Action*], [*What it moves*],
      [`scroll`], [Brings the slip fully into view when it fits; otherwise scrolls to its top.],
      [`up`], [Aligns the slip's top edge to the viewport's top edge.],
      [`down`], [Aligns the slip's bottom edge to the viewport's bottom edge.],
      [`center`], [Centers the slip vertically.],
      [`focus`], [Centers the slip on both axes and zooms it to fill the viewport.],
      [`left`], [Aligns the slip's left edge to the viewport's left edge.],
      [`right`], [Aligns the slip's right edge to the viewport's right edge.],
      [`center-x`], [Centers the slip horizontally.],
    )
  ],

  slip("a-background-of-its-own", title: [Backgrounds are inline style], background: rgb("#eef4ea"))[
    A `color` tag value becomes `background: <hex>` on this slip's own
    `<section>`. Any other value is assumed to be an image path or URL and
    becomes a `background-image` instead — a Typst gradient has no CSS
    serialization this package can produce, so `background:` only ever
    carries a colour or an image.
  ],

  slip("options-are-tags", title: [Presentation options are tags])[
    `fullscreen` and `enter` are FLAT tags — the key alone encodes the
    value, like `slip-fullscreen` or `slip-enter-focus` — so either is a pill
    a filter can press. `background`, `order`, `class`, `row` and
    `max-width` are VALUED tags: present-filterable, but the value itself is
    for `#slipshow` alone to read.
  ],

  slip("two-routes", title: [Two ways to build a deck])[
    A deck can query the registry by tag, or take an explicit ordered array
    of already-rendered ideas. The two read their options back from
    different places — a tag-queried deck from `ideas(values: true)`, an
    explicit-array deck from the rendered content itself — and either can
    work while the other is broken. This deck uses the array; the array's
    sibling fixture uses the tag query.
  ],

  slip("transparent-on-paper", title: [Transparent on a paged target])[
    On a PDF build there is no camera and no deck wrapper: the ideas render
    in their resolved order exactly as if they had been written straight
    into the document, with no `div.slipshow` and no `section.slip`
    anywhere in the output.
  ],

  slip("a-grid-vanishes-in-html", title: [A grid vanishes in HTML])[
    The table two slides back is a `table`, not a `grid`: Typst's HTML
    export silently drops a `grid` element, which would leave this slide
    correct in the PDF build and empty in the browser. A borderless `table`
    is the layout choice here for exactly that reason, not for its rules.
  ],

  slip("takeaways", title: [What to remember])[
    - A slip is a note with presentation options.
    - The camera moves; nothing transitions or times out.
    - A deck can be built by query or by array — pick whichever the content
      already looks like.
  ],

  slip("closing", title: [End of the deck], fullscreen: true)[
    That is the whole surface: `#slip`, `#slipshow`, and eight camera
    actions between them.
  ],
))
