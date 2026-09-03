// Resolves a slipshow's slip list and its order, from either definition
// route — an explicit array of already-rendered ideas, or a tag query over
// the registry. Renders nothing.
//
// `ideas()` sorts its rows by id (`@rookery/core`'s `data.typ`), which is
// almost never presentation order, so the query route sorts explicitly here —
// `slip-order` (see `tags.typ`) is the default.
//
// `tags:` also accepts a PREDICATE — a function from a tag dictionary to a
// bool — as the extension point for a full boolean grammar
// (`@rookery/search`'s `a&b`) with no dependency on search: a caller builds
// the predicate itself with `eval-tag-query(parse-tag-query("a&b").rpn, ..)`
// and hands it straight to `tags:`.
//
// `where:` is the row-shaped counterpart: a predicate over the WHOLE
// registry row rather than only its tag dictionary, for a selection `tags:`
// cannot express — by `created`, `page`, `name`, `title`, or `body`. A row
// (`ideas(values: true)`, `@rookery/core`'s `data.typ`) carries `id`, `name`,
// `title`, `text`, `label`, `tags` (a flat array of key names), `tags-dict`
// (the full dictionary, values included), `body`, `href`, `page`, and
// `created`. `tags:` keeps its narrower one-argument shape — that is what
// lets `@rookery/search`'s `eval-tag-query` plug into it with no adapter —
// so a query needing a field off the row reaches for `where:` instead. The
// two compose: `tags:` runs first, since it is core's own cheap filter, and
// `where:` narrows whatever survives it.

#import "@rookery/core:0.1.0": ideas
#import "tags.typ": *
#import "marker.typ": *

// The registry rows a tag query resolves to, unsorted. Must be called INSIDE
// a `#context` block (it reads the registry via `ideas`); it is not itself a
// context function, because a context function may only return content and
// the whole point here is to return data — the same discipline `ideas()`
// itself follows.
//
// A function `tags` is the predicate route: `ideas()`'s own `tags:`/`match:`
// have no boolean operators, so a predicate instead walks every row's
// `tags-dict` itself. Otherwise `tags`/`match` pass straight to `ideas()`,
// which validates them — duplicating `_assert-tags`/`_assert-match` here
// would just be a second copy of the same message. `tags: none` still goes
// through `ideas()`, which is what makes a `where:`-only query see the whole
// corpus rather than an empty one.
//
// `where` filters the survivors by the WHOLE row, after `tags`, so its type
// is checked up front — before either `ideas()` branch runs — so a bad
// `where:` panics with this message even when the call has no surrounding
// `#context` to satisfy `ideas()`'s own registry read.
#let _slip-rows-from-query(tags, match, where) = {
  assert(
    where == none or type(where) == function,
    message: "@rookery/slipshow: `where` must be a function taking a "
      + "registry row and returning a bool — got " + repr(where),
  )
  let rows = if type(tags) == function {
    ideas(values: true).filter(r => tags(r.tags-dict))
  } else {
    ideas(tags: tags, match: match, values: true)
  }
  if where == none { rows } else { rows.filter(r => where(r)) }
}

// The three accepted `order` forms, each sorted by a COMPOUND key — the real
// key, then the row's `id` — rather than relying on `.sorted()`'s stability:
// a tie keeps id order, a reader can check that directly, and the build stays
// reproducible whatever Typst's sort does with equal keys.
#let _sort-rows(rows, order) = {
  if type(order) == array {
    // Position in `order`, matched against either `name` or `id` so a caller
    // may write whichever form is at hand; a row named nowhere in `order`
    // gets the sentinel `order.len()`, which sorts after every named
    // position and keeps unnamed rows in their incoming (id) order among
    // themselves.
    rows.sorted(key: row => {
      let pos = order.position(n => n == row.name or n == row.id)
      (if pos == none { order.len() } else { pos }, row.id)
    })
  } else if order == "created" {
    // `c == none` first, so an undated row sorts last and its placeholder
    // never has to compare against a real date. `[year][month][day]` and no
    // time fields: `display()` errors on a field the datetime was not
    // constructed with, and this shape sorts in date order as a plain string.
    rows.sorted(key: row => {
      let c = row.created
      (c == none, if c == none { "" } else { c.display("[year][month][day]") }, row.id)
    })
  } else if order == "slip-order" {
    rows.sorted(key: row => {
      let o = order-of(row.tags-dict)
      (o == none, if o == none { 0 } else { o }, row.id)
    })
  } else {
    panic(
      "@rookery/slipshow: `order` must be an array of note names/ids, "
        + "\"created\", or \"slip-order\" (the default) — got " + repr(order),
    )
  }
}

// Resolves a slipshow's slip list, from either definition route:
//
//   #context resolve-slips(tags: "slip")                    // a tag query
//   #context resolve-slips(where: r => r.page == "methods")  // a row query
//   resolve-slips(slips: (slip("a")[..], slip("b")[..]))     // an explicit array
//
// The two routes return differently shaped entries on purpose — a `"content"`
// entry is rendered inline, a `"row"` entry via `#window` — so the renderer
// needs no key-presence guessing to tell them apart:
//
//   (kind: "content", content: <item>, tags: <dict>)   // from `slips:`
//   (kind: "row", row: <ideas() row>, tags: <dict>)     // from `tags:`/`where:`
//
// The query route needs `#context` (it calls `ideas()` through
// `_slip-rows-from-query`); `slips:` does not, since it only reads tags back
// out of content already in hand. `tags:` and `where:` compose — both may be
// given together — but `slips:` is exclusive with either, since an explicit
// array has nothing left to filter.
#let resolve-slips(slips: none, tags: none, where: none, match: "any", order: "slip-order") = {
  let slips-given = slips != none
  let query-given = tags != none or where != none
  assert(
    slips-given != query-given,
    message: "@rookery/slipshow: resolve-slips needs exactly one of `slips`, "
      + "`tags`, or `where` — got "
      + (if slips == none and tags == none and where == none {
        "none of them"
      } else {
        "`slips` together with `tags`/`where`, which conflict"
      })
      + ". Pass `slips:` for an explicit ordered array of ideas, or `tags:` "
      + "and/or `where:` to query the registry.",
  )

  if slips != none {
    assert(
      type(slips) == array,
      message: "@rookery/slipshow: `slips` must be an array of already-rendered "
        + "ideas — got " + repr(slips),
    )
    // An explicit array is already ordered by construction; re-sorting it
    // would be surprising, so `order:` is refused rather than silently
    // ignored.
    assert(
      order == "slip-order",
      message: "@rookery/slipshow: `order` and `slips:` conflict — an explicit "
        + "array is already in the order it was written, so `order:` has "
        + "nothing to do. Drop `order:`, or use `tags:` instead of `slips:`.",
    )
    return slips.map(item => (kind: "content", content: item, tags: slip-tags-of(item)))
  }

  let rows = _sort-rows(_slip-rows-from-query(tags, match, where), order)
  rows.map(row => (kind: "row", row: row, tags: row.tags-dict))
}
