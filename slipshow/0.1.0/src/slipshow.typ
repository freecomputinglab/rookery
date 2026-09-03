// `#slipshow` — the deck container. It resolves a slip list (`select.typ`)
// and renders it as the presentation DOM `src/slipshow.css` and
// `src/slipshow.js` are both pinned to. Nothing downstream can change these
// names without changing all three together.
//
//   <div class="slipshow" data-enter="scroll">
//     <section class="slip [slip-fullscreen] [<slip-class>]"
//              id="slip-<id>" data-index="0" [data-enter="focus"]
//              [style="background: #f00" | style="background-image: url(bg.jpg)"]>
//       ...the idea, rendered in full...
//     </section>
//     ...
//   </div>
//
// - `data-enter` on the root is the DECK-WIDE default, taken from
//   `#slipshow`'s own `enter:` argument, and is always present. A `<section>`
//   carries `data-enter` of its own ONLY when that slip's `#slip(enter: ..)`
//   overrides the default — its absence is what lets the engine tell "unset,
//   use the deck default" apart from "set to the same value the deck already
//   has". There is no `data-transition`/`data-duration` anywhere: the camera
//   is the only motion this package has, and `ENTERS` (`tags.typ`) is its
//   whole vocabulary.
// - `id="slip-<id>"`: for a `kind: "row"` entry (a tag query) `<id>` is the
//   note's own registry id, prefix included (`row.id`, e.g. `idea:intro` ->
//   `slip-idea:intro`) — the same id `#window` transcludes by. For a
//   `kind: "content"` entry (an explicit array) there is no registry row to
//   name it by, and `select.typ`'s array route hands back only rendered
//   `content` plus `tags` — no label or base — so `<id>` falls back to the
//   slip's position instead: `slip-<n>`.
// - `slip-fullscreen` and a `slip-class` value are appended to the section's
//   class list; a background is an inline `style` attribute, never a class.
//   A `color` tag value becomes `background: <hex>` via `.to-hex()`; any
//   other value is assumed to be an image path/URL and becomes
//   `background-image: url(<value>)` — a Typst `gradient` has no CSS
//   serialization this package can produce, so `background:` only ever
//   carries a colour.
// - Exactly one `div.slipshow` is expected per page. Nothing here enforces
//   that — a page with two decks is an authoring mistake, not a case this
//   container guards against — and the controller (`src/slipshow.js`) uses
//   the first one it finds and ignores the rest.
//
// On a paged target the presentation is entirely an HTML concern: `#slipshow`
// renders the resolved ideas in order with no wrapper element, no page break
// and no chrome of its own, exactly as if they had been written straight into
// the document.

#import "@rookery/core:0.1.0": window
#import "tags.typ": *
#import "select.typ": *

// One entry's idea, rendered: an array entry is already-rendered content, a
// query entry transcludes its registry row through `#window`. No `folded:`
// argument — `#window`'s own default (`false`) is already `<details open>`
// (`core/0.1.0/src/window.typ`/`transclusion.typ`) — and no `depth:` beyond
// its `auto` default (1): show this note, collapse anything windowed inside
// it to a permalink.
#let _render-slip(e) = if e.kind == "content" { e.content } else { window(e.row.id) }

// A background tag value as an inline CSS `style` string, or `none` when the
// slip carries no `slip-background`.
#let _background-style(tags) = {
  let bg = background-of(tags)
  if bg == none { none } else if type(bg) == color {
    "background: " + bg.to-hex()
  } else {
    "background-image: url(" + bg + ")"
  }
}

// One entry's `<section>` attributes: id, index, class list, and the two
// optional presentation attributes a slip may override.
#let _slip-attrs(e, i) = {
  let id = if e.kind == "row" { "slip-" + e.row.id } else { "slip-" + str(i) }
  let cls = (
    "slip",
    ..if is-fullscreen(e.tags) { ("slip-fullscreen",) } else { () },
    ..if class-of(e.tags) != none { (class-of(e.tags),) } else { () },
  )
  let attrs = (class: cls.join(" "), id: id, "data-index": str(i))
  let ent = enter-of(e.tags)
  if ent != none { attrs.insert("data-enter", ent) }
  let style = _background-style(e.tags)
  if style != none { attrs.insert("style", style) }
  attrs
}

#let slipshow(
  slips: none,
  tags: none,
  where: none,
  match: "any",
  order: "slip-order",
  reverse: false,
  enter: "scroll",
) = context {
  assert(
    enter in ENTERS,
    message: "@rookery/slipshow: `enter` must be one of "
      + ENTERS.join(", ") + " — got " + repr(enter),
  )

  // `resolve-slips` validates `slips`/`tags`/`where`/`order` itself (see
  // `select.typ`) — duplicating those asserts here would just be a second
  // copy of the same message.
  let entries = resolve-slips(
    slips: slips,
    tags: tags,
    where: where,
    match: match,
    order: order,
    reverse: reverse,
  )

  if target() != "html" {
    // PAGED (PDF): no camera, no deck, nothing to click — the ideas render
    // exactly as they would outside a slipshow, in the resolved order.
    // `target()` reports EPUB as "html", so an EPUB build takes the deck
    // branch below like a real HTML build does, not this one.
    for e in entries { _render-slip(e) }
    return
  }

  html.elem(
    "div",
    attrs: (class: "slipshow", "data-enter": enter),
    {
      for (i, e) in entries.enumerate() {
        html.elem("section", attrs: _slip-attrs(e, i), _render-slip(e))
      }
    },
  )
}
