// The tag mapping: how `#slip`'s presentation options become keys in
// rookery's tag dictionary. `tags` is the only extensible field on a rookery
// record (see `@rookery/core`'s `idea.typ`), so an option that must survive a
// tag-query-defined slipshow — one that only ever sees a record, never the
// call site — has to live here rather than as an ordinary function argument.
//
// Three surfaces, as in `@rookery/todos`:
// 1. FLAT, key encodes the value (`slip`, `slip-fullscreen`,
//    `slip-enter-<name>`) — value `none`, renders a pill, filterable by
//    `#ideas(tags:)` and by `@rookery/search`'s query language.
// 2. VALUED (`slip-background`, `slip-order`, `slip-class`) — no pill, but
//    still presence-filterable by key.
// 3. The caller's own `tags:` — plain, unnamespaced, merged LAST so a caller
//    naming one of our keys wins outright.

// The base key every slip carries.
#let SLIP-KEY = "slip"

// The camera action set, verbatim: the same five names `src/camera.js`'s
// `targetFor` accepts. One vocabulary spans this file, the `data-enter`
// attribute and the engine, which is why the controller can pass the
// attribute straight through with no translation table. There is no
// `transition:`/`duration:` in this package — the camera is the only motion.
#let ENTERS = ("scroll", "up", "down", "center", "focus")

// The valued keys. Namespaced with a `slip-` prefix per rookery's convention:
// a key becomes a CSS class fragment, and a bare `background` is generic
// enough that two packages could both claim it.
#let BACKGROUND-KEY = "slip-background"
#let ORDER-KEY = "slip-order"
#let CLASS-KEY = "slip-class"

// A local copy of rookery's four-form tag normalizer, so this module stays a
// pure function of its arguments. Deliberately NOT an import of core's
// private `_norm-tags`: this is six lines, and reaching into another
// package's underscore names is a dependency on an internal that can move
// without notice.
//
// Defined ABOVE its caller because a `#let` closure captures the scope
// visible AT DEFINITION time — a helper defined further down is invisible.
#let _norm-tags-local(v) = {
  if v == none {
    (:)
  } else if std.type(v) == str {
    ((v): none)
  } else if std.type(v) == dictionary {
    v
  } else {
    v.fold((:), (d, t) => { d.insert(t, none); d })
  }
}

// `#slip`'s presentation options, folded into one tag dictionary.
//
// EMPTY MEANS ABSENT for every optional key, flat or valued: a key present
// with an empty or `false` value would read as an assertion about the note —
// `slip-fullscreen: false` would mark every ordinary slip as fullscreen to
// anything testing for the key, including core's own `tags:` filter.
//
// `tags` is the caller's own and is merged LAST so a caller naming one of our
// keys wins outright: Typst dictionary `+` is right-wins, which is exactly the
// precedence wanted.
#let slip-tags(
  tags: none,
  fullscreen: false,
  background: none,
  enter: none,
  order: none,
  class: none,
) = {
  let out = ((SLIP-KEY): none)

  assert(
    type(fullscreen) == bool,
    message: "@rookery/slipshow: `fullscreen` must be a bool — got " + repr(fullscreen),
  )
  if fullscreen == true { out.insert("slip-fullscreen", none) }

  if enter != none {
    assert(
      enter in ENTERS,
      message: "@rookery/slipshow: `enter` must be one of "
        + ENTERS.join(", ") + " — got " + repr(enter),
    )
    out.insert("slip-enter-" + enter, none)
  }

  // Untouched: `background` is an arbitrary Typst value — a colour, a
  // gradient, an image — and this file has no business interpreting it.
  if background != none { out.insert(BACKGROUND-KEY, background) }

  if order != none {
    assert(
      type(order) == int,
      message: "@rookery/slipshow: `order` must be an integer — got " + repr(order),
    )
    out.insert(ORDER-KEY, order)
  }

  if class != none {
    assert(
      type(class) == str,
      message: "@rookery/slipshow: `class` must be a string — got " + repr(class),
    )
    out.insert(CLASS-KEY, class)
  }

  out + _norm-tags-local(tags)
}

// The readers below take the DICT — what `ideas(values: true)` hands back per
// note as `tags-dict` — rather than a note name, so they stay pure and a
// caller walking the corpus pays one registry read for everything rather than
// one per note per question.

// Is this note a slip at all?
#let is-slip(tags) = SLIP-KEY in tags

#let is-fullscreen(tags) = "slip-fullscreen" in tags

// Decoded from the key, not stored a second time: the entered name and the
// filterable flat key cannot disagree if there is only one of them.
#let enter-of(tags) = ENTERS.find(name => ("slip-enter-" + name) in tags)

#let background-of(tags) = tags.at(BACKGROUND-KEY, default: none)
#let order-of(tags) = tags.at(ORDER-KEY, default: none)
#let class-of(tags) = tags.at(CLASS-KEY, default: none)
