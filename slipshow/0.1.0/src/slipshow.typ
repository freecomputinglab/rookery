// `#slipshow` — the deck container. It resolves a slip list (`select.typ`)
// and renders it as the presentation DOM `src/slipshow.css` and
// `src/slipshow.js` are both pinned to. Nothing downstream can change these
// names without changing all three together.
//
//   <div class="slipshow" data-enter="scroll">
//     <section class="slip [slip-fullscreen] [<slip-class>]"
//              id="slip-<id>" data-index="0" [data-enter="focus"]
//              [style="background: #f00" | style="background: linear-gradient(..)"]>
//       [<div class="slip-bg"><img src="data:image/..;base64,.."></div>]
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
//   class list; a background is never a class. A `color` becomes
//   `background: <hex>` via `.to-hex()`; a `gradient` becomes
//   `background: <css-gradient-function>` (`_gradient-css`); either is an
//   inline `style` attribute on the `<section>`. `image(..)` content instead
//   becomes `div.slip-bg` below — an inline `style` cannot carry an `<img>`,
//   and typst's own HTML export already turns an `#image(..)` element into a
//   self-contained base64 `data:` URI with no path for this package to
//   resolve or rewrite. Any other `slip-background` value panics.
// - `div.slip-bg`: a slip's background LAYER rather than declaration, present
//   only when `slip-background` is an image, and always the section's first
//   child — `src/slipshow.css` is pinned to that position. Absent for a
//   colour, a gradient, or no background at all.
// - Exactly one `div.slipshow` is expected per page. Nothing here enforces
//   that — a page with two decks is an authoring mistake, not a case this
//   container guards against — and the controller (`src/slipshow.js`) uses
//   the first one it finds and ignores the rest.
//
// On a paged target the presentation is entirely an HTML concern: `#slipshow`
// renders the resolved ideas in order with no wrapper element, no page break
// and no chrome of its own, exactly as if they had been written straight into
// the document — no background of any kind, image included, is emitted for
// that target at all.

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

// A degree value as a bare CSS number (no unit): `str()` on a negative
// number spells its sign with Unicode's proper minus (U+2212), which a CSS
// `<angle>` does not accept — only the ASCII hyphen does — so it is swapped
// back before the value ever reaches a `style` attribute.
#let _css-num(x) = str(x).replace("\u{2212}", "-")

// A Typst `gradient` as a CSS gradient function string, for use inside an
// inline `background` declaration. `src/tags.typ` never interprets
// `background`, so this is the one place a `gradient` becomes something a
// browser understands.
#let _gradient-css(g) = {
  let stops = g.stops().map(p => p.at(0).to-hex() + " " + repr(p.at(1))).join(", ")

  // CSS interpolates a gradient in sRGB unless told otherwise; Typst
  // defaults to Oklab. These four Typst colour-space functions share a name
  // with a CSS `<color-interpolation-method>` keyword (Typst's `rgb` is
  // CSS's `srgb`) — anything else (`cmyk`, `hsv`, `linear-rgb`, ..) has no
  // CSS equivalent and is left to fall back to sRGB rather than resampled
  // to fake it.
  let space = g.space()
  let css-space = if space == oklab { "oklab" } else if space == oklch { "oklch" }
    else if space == rgb { "srgb" } else if space == hsl { "hsl" } else { none }
  let space-suffix = if css-space == none { "" } else { " in " + css-space }

  if g.kind() == gradient.linear {
    // Typst's `angle: 0deg` runs left-to-right; CSS's `linear-gradient(0deg,
    // ..)` runs bottom-to-top and its `90deg` runs left-to-right — the two
    // scales sit 90 degrees apart. Skipping this rotates the gradient a
    // quarter turn from what the Typst side asked for.
    "linear-gradient(" + _css-num(g.angle().deg() + 90) + "deg" + space-suffix + ", " + stops + ")"
  } else if g.kind() == gradient.radial {
    // Typst's focal point (`.focal-center()`/`.focal-radius()`) has no
    // single-declaration CSS equivalent and is dropped rather than
    // approximated.
    let center = g.center().map(repr).join(" ")
    "radial-gradient(circle " + repr(g.radius()) + " at " + center + space-suffix + ", " + stops + ")"
  } else {
    // conic, the only kind left. Both Typst and CSS sweep conic stops
    // clockwise as the ratio increases, but Typst's `angle: 0deg` starts the
    // sweep due LEFT while CSS's `from 0deg` starts it due UP — a quarter
    // turn short of the linear correction above, so this is `-90` rather
    // than `+90`.
    let center = g.center().map(repr).join(" ")
    "conic-gradient(from " + _css-num(g.angle().deg() - 90) + "deg at " + center + space-suffix + ", " + stops + ")"
  }
}

// Fails a `slip-background` value that is none of the three accepted forms —
// most often a bare path string where `image(..)` content was meant.
#let _check-background(bg) = {
  if type(bg) not in (color, gradient) and not (type(bg) == content and bg.func() == image) {
    let hint = if type(bg) == str {
      " Write `background: image(\"" + bg + "\")`, not `background: " + repr(bg) + "`."
    } else { "" }
    panic(
      "@rookery/slipshow: `background` must be a color, a gradient, or "
        + "image content — got " + repr(bg) + "." + hint,
    )
  }
}

// A `color`/`gradient` background as an inline CSS `style` string. `none`
// when the slip carries no `slip-background`, or when its value is an image
// (rendered as a `div.slip-bg` child instead — see `_background-child`).
#let _background-style(tags) = {
  let bg = background-of(tags)
  if bg == none {
    none
  } else {
    _check-background(bg)
    if type(bg) == color {
      "background: " + bg.to-hex()
    } else if type(bg) == gradient {
      "background: " + _gradient-css(bg)
    } else {
      none
    }
  }
}

// The image form of `slip-background`, wrapped in a `div.slip-bg` — the
// section's first child (see `slipshow`'s HTML branch below). A wrapper
// rather than styling the `<img>` directly: typst's own HTML export emits
// that element, so this package controls none of its attributes, only
// something of its own. `none` when the slip carries no `slip-background`,
// or when its value is a colour/gradient (rendered as a `style` instead —
// see `_background-style`).
#let _background-child(tags) = {
  let bg = background-of(tags)
  if bg == none {
    none
  } else {
    _check-background(bg)
    if type(bg) == content and bg.func() == image {
      html.elem("div", attrs: (class: "slip-bg"), bg)
    } else {
      none
    }
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
        html.elem("section", attrs: _slip-attrs(e, i), {
          let bg = _background-child(e.tags)
          if bg != none { bg }
          _render-slip(e)
        })
      }
    },
  )
}
