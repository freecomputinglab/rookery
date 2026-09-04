// `#slipshow` — the deck container. It resolves a slip list (`select.typ`)
// and renders it as the presentation DOM `src/slipshow.css` and
// `src/slipshow.js` are both pinned to. Nothing downstream can change these
// names without changing all three together.
//
//   <div class="slipshow" data-enter="scroll" data-reveal="progressive">
//     [<div class="slip-row" [data-row="0"]>]
//       <section class="slip [slip-fullscreen] [<slip-class>]"
//                id="slip-<id>" data-index="0" [data-enter="focus"]
//                [style="background: #f00; max-width: 45%"]>
//         [<div class="slip-bg"><img src="data:image/..;base64,.."></div>]
//         ...the idea, rendered in full...
//       </section>
//     [</div>]
//     ...
//   </div>
//
// - `data-reveal` on the root is `"progressive"` (the default) or `"all"`,
//   from `#slipshow`'s own `reveal:` argument, and is always present. Under
//   `"progressive"` the controller hides every slip the reader has not
//   reached yet — the deck opens EMPTY and each advance brings one more slip
//   into the page. The hiding is done with two classes the controller adds at
//   runtime, `slipshow-revealing` on the root and `slip-revealed` on each
//   slip up to the current one, and NOT by this file: a deck must render its
//   whole content for a reader whose JavaScript never ran, so the markup here
//   is identical under either value and only the attribute differs. See
//   `src/slipshow.css`'s reveal section for the pair of rules, and
//   `src/slipshow.js`'s `syncReveal`.
// - A QUERIED SLIP IS TRANSCLUDED WITH CORE'S CHROME OFF. `#slipshow`'s
//   `show-frame:`, `show-id:` and `show-label:` all default to `false` here,
//   inverting `@rookery/core`'s own defaults, and are passed straight to the
//   `#window` each queried slip is rendered by. So the markup inside a
//   `<section class="slip">` is a `[data-rookery="window"]` carrying
//   `data-rookery-bare`, with an empty `[data-rookery="tab"]` and a summary
//   holding a title only where the note's author wrote one. Nothing in THIS
//   package draws or hides any of that — the attributes and the rules that act
//   on them are core's, and a deck passing `true` gets core's ordinary card
//   back. An explicit-array entry is already-rendered content and is not
//   reachable from here; it carries whatever its own `#slip(..)` asked for.
// - A QUERIED SLIP ALSO ANNOUNCES NOTHING. `backlink:` defaults to `false` and
//   rides the same route, so a deck contributes nothing to the backlinks graph:
//   the notes it shows do not list this page among their Backlinks. Nothing is
//   visible in the markup either way — the flag travels inside the announce
//   marker `#window` emits, which is emitted whatever its value (see
//   `@rookery/core`'s `window.typ` for why).
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
// - `slip-max-width` (a length, ratio, or raw-CSS string) becomes a
//   `max-width: <v>` declaration in the same `style` attribute as the
//   background, joined with `; ` when both are present — never `width:`, so
//   a slip narrower than its cap stays narrow instead of being stretched to
//   fill it.
// - `div.slip-row[data-row]` wraps one RUN of consecutive resolved entries
//   sharing the same row value — the deck's own `row:` key function
//   (`select.typ`'s `_apply-row`) when it ran on that entry, else the note's
//   own `slip-row` tag (`row-of`, `tags.typ`) — so a stylesheet can lay a run
//   out as a flex row instead of the deck's default vertical stack.
//   CONSECUTIVE, NOT A GROUP-BY: grouping walks the resolved
//   order and never reorders it, so two slips both tagged `row: 1` with
//   something else between them produce TWO separate
//   `div.slip-row[data-row="1"]` wrappers, not one — ordering is `order:`'s
//   business, and a renderer that silently coalesced same-numbered rows to
//   make them contiguous would override a caller's explicit sequence. A
//   caller wanting one row per index orders so its members sit adjacent. A
//   run of exactly one slip carrying NO `slip-row` tag (row `none`) gets no
//   wrapper at all — its `section.slip` sits as a direct child of
//   `div.slipshow`, exactly as it does with no `row:` in the deck at all,
//   which is what keeps a deck using no `row:` anywhere byte-identical to
//   its output before this wrapper existed. A run of one slip that DOES
//   carry a row value is still wrapped. Two `none`-row slips can never share
//   a wrapper-free run: an entry with no row is always its own run, even
//   sitting next to another one.
// - Exactly one `div.slipshow` is expected per page. Nothing here enforces
//   that — a page with two decks is an authoring mistake, not a case this
//   container guards against — and the controller (`src/slipshow.js`) uses
//   the first one it finds and ignores the rest.
//
// On a paged target the presentation is entirely an HTML concern: `#slipshow`
// renders the resolved ideas in order with no wrapper element, no page break
// and no chrome of its own, exactly as if they had been written straight into
// the document — no background, row grouping, or max-width, of any kind, is
// emitted for that target at all. A row is a screen-layout fact and a PDF
// has no screen. Progressive reveal is the same kind of fact and goes the
// same way: a PDF prints every slip, `reveal:` or not, since there is no
// camera there to have arrived at one.

#import "@rookery/core:0.1.0": window
#import "tags.typ": *
#import "select.typ": *

// One entry's idea, rendered: an array entry is already-rendered content, a
// query entry transcludes its registry row through `#window`. No `folded:`
// argument — `#window`'s own default (`false`) is already `<details open>`
// (`core/0.1.0/src/window.typ`/`transclusion.typ`) — and no `depth:` beyond
// its `auto` default (1): show this note, collapse anything windowed inside
// it to a permalink.
//
// EVERY CHROME FLAG DEFAULTS TO CORE'S OWN VALUE HERE, not to the deck's,
// so a call that forgets to pass one renders a plain `@rookery/core` window
// rather than silently inheriting a presentation decision from a deck that is
// not in scope. `#slipshow` passes its own at both call sites.
//
// They reach the QUERY route only. An array entry is content that was rendered
// at its own `#slip(..)` call site, long before this deck existed, so there is
// nothing left here to configure — see the readme's note under `slips:`.
#let _render-slip(
  e,
  show-frame: true,
  show-id: true,
  show-label: true,
  foldable: true,
  reserve-title: true,
  backlink: true,
) = {
  if e.kind == "content" {
    e.content
  } else {
    window(
      e.row.id,
      show-frame: show-frame,
      show-id: show-id,
      show-label: show-label,
      foldable: foldable,
      reserve-title: reserve-title,
      backlink: backlink,
    )
  }
}

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

// `slip-max-width` as a CSS declaration, joined into the same inline `style`
// as `_background-style`. A `length`/`ratio` serializes with `repr()`
// (`22em`, `45%`); a `str` is the raw-CSS escape hatch (`tags.typ`'s
// `max-width` docstring) and passes through verbatim. `repr()` already
// spells a negative number with the ASCII hyphen CSS requires, unlike
// `str()` — see `_css-num` above — so no extra sanitizing is needed here.
// `none` when the slip carries no `slip-max-width`.
#let _max-width-style(tags) = {
  let mw = max-width-of(tags)
  if mw == none {
    none
  } else if type(mw) == str {
    "max-width: " + mw
  } else {
    "max-width: " + repr(mw)
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
  let decls = (_background-style(e.tags), _max-width-style(e.tags)).filter(d => d != none)
  if decls.len() > 0 { attrs.insert("style", decls.join("; ")) }
  attrs
}

// An entry's row for grouping purposes: `computed-row` (`select.typ`'s
// `_apply-row`) when `row:` ran on this entry, else its own `slip-row` tag.
// The two are told apart by the KEY's presence, not its value — a `row:`
// function that computed `none` for this entry still counts as having run,
// so that entry joins no row rather than falling back to a tag it might
// still carry.
#let _entry-row(e) = if "computed-row" in e { e.computed-row } else { row-of(e.tags) }

// Groups resolved entries into RUNS of consecutive entries sharing the same
// row value (`_entry-row`), keeping each entry's original index (`i`)
// alongside it for `_slip-attrs`/`id="slip-<n>"`. `none` never merges with a
// neighbouring `none`: unlike two equal row numbers, two unrowed slips are
// not one run of two — see the file header — so an entry whose row is
// `none` always starts a fresh run of its own.
#let _row-runs(entries) = {
  let runs = ()
  let current = ()
  let current-row = none
  for (i, e) in entries.enumerate() {
    let r = _entry-row(e)
    if current.len() == 0 or r == none or r != current-row {
      if current.len() > 0 { runs.push(current) }
      current = ()
    }
    current.push((i: i, e: e))
    current-row = r
  }
  if current.len() > 0 { runs.push(current) }
  runs
}

#let slipshow(
  slips: none,
  tags: none,
  where: none,
  match: "any",
  order: "slip-order",
  reverse: false,
  row: none,
  enter: "scroll",
  reveal: true,
  show-frame: false,
  show-id: false,
  show-label: false,
  // A slide is READ, not scanned, and both of these invert core's default for
  // that reason. `foldable: false` because a stray click that folded a slide
  // shut would be a bug and never an intention; `reserve-title: false` because
  // this deck also sets `show-label: false`, so a TITLELESS note's summary
  // genuinely has no title and the line core reserves for one is dead space
  // above the body. A note that HAS a title still shows it, with the ordinary
  // spacing, and is still not foldable.
  foldable: false,
  reserve-title: false,
  // NO `show-background` HERE, deliberately. Core's default is `true` and a
  // slide wants the tint — it is how the slide answers a pointer, and it is
  // independent of `show-frame`, which this deck does turn off. A pass-through
  // whose only value is the default would be a knob with nothing behind it.
  backlink: false,
) = context {
  assert(
    enter in ENTERS,
    message: "@rookery/slipshow: `enter` must be one of "
      + ENTERS.join(", ") + " — got " + repr(enter),
  )

  // A BOOL RATHER THAN THE TWO ATTRIBUTE SPELLINGS, because there are exactly
  // two states and `reveal: false` reads better at a call site than
  // `reveal: "all"`. The attribute keeps the words: `data-reveal="all"` says
  // what it means in a DOM inspector, where a bare `data-reveal="false"`
  // would leave a reader wondering what was false about it.
  assert(
    type(reveal) == bool,
    message: "@rookery/slipshow: `reveal` must be a bool — got " + repr(reveal),
  )

  // THE CHROME FLAGS, all `false` where `@rookery/core`'s own defaults are
  // `true`. That inversion is the whole argument: a slip's `<section>` is
  // already the visual unit, so the note's card frame inside it reads as a frame
  // around a frame; the `[idea:47]` permalink above every slide is machinery a
  // reader of a deck has no use for; a note with no authored title has its
  // own first line derived into a label and printed directly above that same
  // first line; a slide that folds shut under a stray click is never what the
  // click meant; and the line core reserves for a missing title is dead space
  // once `show-label: false` has left the summary genuinely titleless. A deck
  // that wants any of them back passes `true`.
  assert(
    type(show-frame) == bool,
    message: "@rookery/slipshow: `show-frame` must be a bool — got " + repr(show-frame),
  )
  assert(
    type(show-id) == bool,
    message: "@rookery/slipshow: `show-id` must be a bool — got " + repr(show-id),
  )
  assert(
    type(show-label) == bool,
    message: "@rookery/slipshow: `show-label` must be a bool — got " + repr(show-label),
  )
  assert(
    type(foldable) == bool,
    message: "@rookery/slipshow: `foldable` must be a bool — got " + repr(foldable),
  )
  assert(
    type(reserve-title) == bool,
    message: "@rookery/slipshow: `reserve-title` must be a bool — got "
      + repr(reserve-title),
  )

  // `backlink: false` BY DEFAULT, inverting core's own. A deck is a VIEW of
  // notes that already live somewhere else — `demo/rheo/content/index.typ` says
  // as much about the tag-query route: "always an additional view onto content
  // that already lives somewhere, never its only home" — so nobody wrote a link
  // here, and letting a deck announce puts a page nobody linked from into the
  // Backlinks of every note it shows. A deck whose whole point IS to point at
  // those notes passes `true`.
  assert(
    type(backlink) == bool,
    message: "@rookery/slipshow: `backlink` must be a bool — got " + repr(backlink),
  )

  // `resolve-slips` validates `slips`/`tags`/`where`/`order`/`row` itself
  // (see `select.typ`) — duplicating those asserts here would just be a
  // second copy of the same message.
  let entries = resolve-slips(
    slips: slips,
    tags: tags,
    where: where,
    match: match,
    order: order,
    reverse: reverse,
    row: row,
  )

  if target() != "html" {
    // PAGED (PDF): no camera, no deck, nothing to click — the ideas render
    // exactly as they would outside a slipshow, in the resolved order.
    // `target()` reports EPUB as "html", so an EPUB build takes the deck
    // branch below like a real HTML build does, not this one.
    for e in entries {
      _render-slip(
        e,
        show-frame: show-frame,
        show-id: show-id,
        show-label: show-label,
        foldable: foldable,
        reserve-title: reserve-title,
        backlink: backlink,
      )
    }
    return
  }

  html.elem(
    "div",
    attrs: (
      class: "slipshow",
      "data-enter": enter,
      "data-reveal": if reveal { "progressive" } else { "all" },
    ),
    {
      let render-section(pair) = html.elem("section", attrs: _slip-attrs(pair.e, pair.i), {
        let bg = _background-child(pair.e.tags)
        if bg != none { bg }
        _render-slip(
          pair.e,
          show-frame: show-frame,
          show-id: show-id,
          show-label: show-label,
          foldable: foldable,
          reserve-title: reserve-title,
          backlink: backlink,
        )
      })
      for run in _row-runs(entries) {
        let r = _entry-row(run.first().e)
        if run.len() == 1 and r == none {
          // The wrapper-free case (file header): a lone unrowed slip is a
          // direct child of `div.slipshow`, exactly as every slip was before
          // `slip-row` existed.
          render-section(run.first())
        } else {
          let attrs = (class: "slip-row")
          if r != none { attrs.insert("data-row", repr(r)) }
          html.elem("div", attrs: attrs, { for pair in run { render-section(pair) } })
        }
      }
    },
  )
}
