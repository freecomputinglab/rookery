// The permalink: the one navigational affordance every note carries, as a tab
// above its heading and as the id on its own page.

#import "base.typ": *
#import "state.typ": *
#import "theme.typ": *
#import "urls.typ": *

// `[idea:etal]`, rendered beside a note's title (or alone, where there is no
// title) by BOTH `#idea` and `#window`. Shared so the two cannot drift: it is
// the same affordance meaning the same thing in both places — "this is the
// note's id, and it goes to the note's own page".
//
// Nothing else in this package is a link. A transcluded body is NOT wrapped
// in an anchor and no trailing arrow is appended (both were tried; see
// `#window`), so the reader's click budget is unambiguous: the permalink
// navigates, everything else folds.
//
// It goes to the note's standalone page when one is minted, and only falls
// back to the same-page `#id` fragment when there is not (plain `typst
// compile`, or the combined PDF). For `#idea`, that fragment points at the
// very heading the reader just clicked — a no-op — which is why the minted
// page is preferred whenever it exists.
// `href: auto` resolves the destination as described above. `.marrow.typ`
// passes an explicit one instead: on a note's OWN minted page the permalink
// must stay a same-page fragment rather than link the page to itself, and
// `_note-href` would happily compute the latter. Routing that case through
// here anyway is what keeps every permalink in the output identical.
//
// Carries no theme properties of its own: it is always emitted inside a
// container that does (`.idea-box`, `.idea-window`, a minted page's `<h1>`), and
// custom properties inherit.
// `href: auto` resolves through `_resolve-dest(id, true)` rather than a
// direct `_note-href(id)` call, and that indirection matters: a REPLAY of
// this note (a `#window`, a minted page, a nested transclusion re-placing
// its stored body elsewhere) shares one Typst context read across every
// copy, so a `#context` read of `state("rheo-handle")` taken here would come
// out right on at most one of the pages the note appears on.
// `_resolve-dest(id, true)` instead hands the destination to rheo's own
// per-`#document` link rule, unresolved, as a plain `link()` — that rule
// applies afresh at each realization, so every copy gets the right
// destination (see `_resolve-dest`'s own banner, urls.typ). An explicit
// `href:` still bypasses this entirely: a caller passing one already knows
// its own destination and needs no help resolving it.
//
// `link()` renders as a bare `<a href="..">`, with none of this element's own
// attributes — VERIFIED empirically, not assumed. They move onto a wrapping
// `<span>` instead of the anchor itself; core.css's `[data-rookery="label"]`
// rule carries a matching `> a` rule, so the bare anchor inherits the look
// through that selector rather than carrying the class itself.
#let _permalink(id, href: auto) = {
  let dest = if href != auto { href } else { _resolve-dest(id, true) }
  // An explicit `href:` is always a plain string (a same-page fragment or an
  // already-resolved relative path — see `.marrow.typ` and `#idea`'s own
  // `own-href`). `_resolve-dest`'s fallback, taken only where no rheo context
  // mints pages at all, is a Typst `label` rather than a string — either way,
  // "same page" is exactly the label case plus the fragment-string case.
  let same-page = if type(dest) == str { dest.starts-with("#") } else { true }
  html.elem(
    "span",
    attrs: (
      class: _c("label"),
      title: if same-page { "Link to this note" } else { "Open this note's page" },
      data-rookery: "label",
    ),
    // TWO SPANS FOR ONE ID, and the closing bracket is the whole reason. On a
    // column too narrow for it the id is clipped with an ellipsis (see the tab
    // rules in core.css), and `text-overflow` eats the END of the text — which
    // is the `]`, leaving `[idea:26w29-typst-…` hanging open. Held in its own
    // element the bracket is outside the clipped box, so what the reader sees
    // is `[idea:26w29-typst-…]`: a truncated id that still looks like an id.
    //
    // Both halves are real text, not generated content, so selecting the
    // permalink still copies `[idea:26w29-typst-limited-form]` in full —
    // which is the thing a reader is copying it FOR, to paste into a
    // `#window("...")`.
    link(dest, {
      html.elem(
        "span",
        attrs: (class: _c("label-id"), data-rookery: "label-id"),
        "[" + id,
      )
      html.elem(
        "span",
        attrs: (class: _c("label-close"), data-rookery: "label-close"),
        "]",
      )
    }),
  )
}

// The permalink as a card's TOP RULE rather than as a word in its heading:
// `.idea-tab` draws the rule (see core.css) and this is the id that
// straddles it. Used by every site that renders a note's HEADER — `#idea`, a
// transcluded `#idea`, a `#window` summary, a minted page's `<h1>` — and by
// nothing else: a bare permalink standing in prose (a depth-exhausted nested
// window, below) keeps `_permalink` itself, because a rule across the top of it
// would be a rule across the top of nothing.
//
// `span`, NOT `div`: this goes inside `<summary>` on the window path, whose
// content model is phrasing content, and EPUB output is XHTML, where that
// distinction is enforced rather than merely stated. `display: flex` in the
// stylesheet is what makes it behave as a block.
//
// Carries no theme properties of its own, for the same reason `_permalink`
// does not: it is always emitted inside a container that does — `.idea-box`,
// `.idea-window-summary`, or (on a minted page) the `.idea-head` wrapper — and
// custom properties inherit.
// `date` IS THE HAT'S OTHER END, emitted LAST and pushed to the far right of
// the rule by `margin-left: auto` in the stylesheet, so the hat reads
// id-on-the-left, date-on-the-right with the frame's top edge between them.
// Both `#idea`'s heading and `#window`'s summary row pass it here rather than
// rendering their own copy, so one piece of metadata gets one class in one
// place.
//
// A STRING, already formatted, not a `datetime`: the two call sites resolve which
// date to show and how to display it (`#idea` from `created`/the
// document's own, `_window-content` from the registry record), and the paged
// branches need the same string without a hat to hang it on. Formatting here would
// put that decision in a third place.
// `tags:` renders each tag as a VISIBLE PILL, between the id and the date —
// opt-in per call site (`#idea`/`#window`'s `display.tags`, off by default,
// same mechanism as `date:` above), and empty when the note carries none
// either way (an empty `tags` array maps to no output).
//
// TWO classes per pill, on purpose: `idea-tag` is the pill's own shape hook
// (see `.idea-tab > .idea-tag` in core.css); `idea-tag-<tag>` is the SAME
// class this package already puts on the card and the heading (`_flatten`'s
// IK rule, `#idea` below), and the same class `@rookery/search` puts on
// its own chips — so one project rule (`.idea-tag-draft { ... }`) now styles
// a tag everywhere it appears, including this pill. A project stylesheet
// that only meant to style the card is affected too — that is the intent of
// sharing the class, not an accident.
//
// CLASSES ONLY, no `style` attribute: a `theme: (tags-color: ..)` colour
// reaches this pill as a generated `.idea-tag-<tag>` rule (`_tags-color-rules`,
// theme.typ), carried by the class this element already wears. Wearing the
// class is the only thing this function does for theming — which is exactly
// why the theme also reaches surfaces this function never touches.
// INVISIBLE TAGS ARE DROPPED HERE, at the one funnel every pill goes through —
// `#idea`'s hat, `_window-content`'s summary hat and a minted note page's hat all
// call this function, so filtering once covers all three and they cannot drift
// about which tags are invisible. See `_invisible-tags` (state.typ) for what
// makes a tag invisible and why it is presentation-only.
//
// The callers still pass FLAT tags only (those whose value is `none`) — that is a
// separate and older rule, and this does not replace it: a valued tag's name
// alone says nothing useful in a pill.
//
// `_visible-tags` needs `#context`, and this function is always called from
// inside one (every caller reads the registry or the prefix to get here).
//
// `display-name: false` DROPS THE PERMALINK and leaves the `<span>` standing. The
// span has to survive: it is still what holds the pills and the date when
// either of those is on, and it is the element every tab rule in `core.css` is
// written against. When the permalink was the only thing in it the tab comes
// out EMPTY, and `[data-rookery="tab"]:empty` in that stylesheet is what stops
// an empty one taking up a line — the same trick `h*.idea:empty` plays for a
// titleless note's heading.
#let _permalink-tab(id, href: auto, tags: (), date: none, display-name: true) = html.elem(
  "span",
  attrs: (class: _c("tab"), data-rookery: "tab"),
  {
    // ONE PARENTHESISED expression, not three lines of `+ ...`. In a Typst CODE
    // block each line is a statement, so a leading `+` is parsed as UNARY plus
    // and fails with "cannot apply unary '+' to content". The parens make the
    // whole thing one expression.
    let shown = _visible-tags(tags)
    (
      (if display-name { _permalink(id, href: href) } else { [] })
        + (if shown.len() == 0 { [] } else {
          shown.map(t => html.elem(
            "span",
            attrs: (class: _c("tag") + " " + _c("tag-" + t), data-rookery: "tag") + _tags-attr((t,)),
            t,
          )).join()
        })
        + (if date == none { [] } else { html.elem("span", attrs: (class: _c("date"), data-rookery: "date"), date) })
    )
  },
)

// The tab and the heading as ONE element, wherever a note wears a header.
//
// NOT two loose siblings. Typst's HTML export wraps a LEADING INLINE run in a
// `<p>` of its own depending on what follows it, and it is not decidable per
// call site — the same construct comes out wrapped or bare depending on the
// body. Every stylesheet rule that positions the tab against its heading
// (`.idea-tab + h*.idea`) silently stops matching in the wrapped form.
//
// Inside one `html.elem` the two are always real siblings. `.idea-head` is also
// the theme container on a minted note page, where there is no `.idea-box` to be
// one — see `.marrow.typ`, which passes `_themed((:))` here.
//
// `#window`'s summary needs none of this: its tab is a direct child of
// `<summary>`, whose content is inline throughout, so no `<p>` ever appears
// there.
#let _head(tab, heading, attrs: (:)) = html.elem(
  "div",
  attrs: attrs + (class: _c("head"), data-rookery: "head"),
  tab + heading,
)

// Paged counterpart: no `html.elem`, and the fallback is the Typst label
// rather than an HTML fragment.
#let _permalink-paged(id) = {
  link(_resolve-dest(id, true), text(gray, raw("[" + id + "]")))
}

// THE ONE BOTTOM-OUT RENDERING. A `#window` that has no recursion budget left emits
// this, wherever it ran out: `#window` itself at depth 0, and `_flatten`'s WK arm for
// a window nested past the budget. ONE rendering serves both call sites, so a
// bottomed-out window looks like the same KIND of object regardless of why it
// bottomed out — the shared `_permalink`/`_note-file`/`_truncate` helpers exist
// to keep it that way.
//
// The note's TITLE, linked to its own page, in the row shape a page backlink uses
// (`.idea-page-row` gives it the frame's bar and indent at body size). A TITLELESS
// note falls back to its permalink — there is nothing else to name it by.
//
// Defined HERE, above `_flatten`, for the reason `_blocks` and `_truncate` are: a
// `#let` closure captures the scope visible AT DEFINITION time, and `_flatten` is one
// of the two callers.
//
// `display` is the window's own dictionary, resolved here against the document
// the way `_window-content` resolves it. `date` and `tags` put a tab above the
// link — the same `_permalink-tab` a window's summary carries, pills then date —
// so a list of links can say when each note was written and what it is filed
// under. `name` is inert on this row: the title below IS the link to the note's
// page, and an `[idea:x]` beside it would be a second link to the same place.
#let _window-link(id, rec, display: (:)) = {
  let display = _display-final(display, ("date", "tags", "background"))
  // A LABEL, not the authored title: this row shows a name AS A LINK with no body
  // under it, so it names rather than headings (see `#idea`'s title-vs-label
  // banner). A bottomed-out window therefore names the note instead of showing a
  // bare id — which is what the row shape was always for.
  //
  // THROUGH `_rec-label` (pure.typ) rather than off the record's own field, so a
  // title that references another note reads as that note's name here too: a
  // registration-time `label` cannot resolve a reference, there being no registry
  // yet when it is computed. `none` only for a note with no name at all — an
  // empty body and no title — which the `id` branch below still covers.
  let name = _rec-label(rec, _ref-text(_registry.final()))
  let row = link(_resolve-dest(id, true), if name == none { id } else { name })
  if _target() == "html" or _target() == "epub" {
    let date = if display.date and rec.at("created", default: none) != none {
      rec.created.display("[year]-[month]-[day]")
    } else { none }
    // Flat tags only, as in `_window-content`'s summary.
    let tags = if display.tags {
      rec.at("tags", default: (:)).pairs().filter(((_, v)) => v == none).map(((k, _)) => k)
    } else { () }
    let tab = if date == none and _visible-tags(tags).len() == 0 { [] } else {
      _permalink-tab(id, tags: tags, date: date, display-name: false)
    }
    // A window's row carries the note's tag data and a marker of its own
    // (`data-rookery-window-link`) so it can be styled to react like a folded
    // window's box — hover tint, whole-row click — without also catching the
    // Context/Backlinks rows `.marrow.typ` emits with the same
    // `data-rookery="page-row"`, which carry no such marker.
    let visible = _visible-tags(rec.at("tags", default: (:)).keys())
    let li-cls = (_c("page-row"),) + visible.map(t => _c("tag-" + t))
    html.elem(
      "ul",
      attrs: _themed((class: _c("page-list"), data-rookery: "page-list")),
      html.elem(
        "li",
        attrs: (class: li-cls.join(" "), data-rookery: "page-row", data-rookery-window-link: "link")
          + (if display.background { (:) } else { ("data-rookery-no-bg": "none") })
          + _tags-attr(visible),
        tab + row,
      ),
    )
  } else {
    // `align(start)` for the reason `_window-content`'s paged branch uses it: a
    // Typst figure centres its body.
    align(start, block(row))
  }
}
