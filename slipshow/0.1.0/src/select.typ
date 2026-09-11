// Resolves a slipshow's slip list and its order, from either definition
// route — an explicit array (content, note names, or a mix), or a tag query
// over the registry. Renders nothing.
//
// A `slips:` array element is dispatched by Typst TYPE, not guessed: a `str`
// or `label` is a NAME, resolved against the registry and returned as a
// `"row"` entry, exactly like the query route below; anything else is
// already-rendered CONTENT, read directly. This is what lets a computed deck
// — most importantly one ordered by `@rookery/search`'s ranking, which hands
// back rows and therefore only names, never rendered content — be expressed
// as an explicit, exactly-ordered list of notes authored elsewhere.
//
// THE NAME ROUTE EXISTS BECAUSE `window(name)` IN THE CONTENT POSITION DOES
// NOT WORK, and this is worth recording so nobody re-discovers it the hard
// way: `#window` wraps its whole body in a `context { .. }` block
// (`core/0.1.0/src/window.typ` line 148), and a Typst `context` block's
// content is opaque until it is evaluated. `slip-tags-of` (`marker.typ`)
// walks rendered content looking for a `figure(kind: IK)` marker, finds
// nothing inside the unevaluated context, and returns `(:)` — so
// `#slipshow(slips: names.map(n => window(n)))` compiles and renders fine,
// but every `#slip` option (fullscreen, background, enter, ...) is silently
// dropped rather than erroring. Passing the bare NAME instead defers
// rendering — and therefore context evaluation — to `_render-slip`
// (`slipshow.typ`), by which point the options are read off the registry row
// directly rather than sniffed out of content.
//
// `ideas()` sorts its rows by id (`@rookery/core`'s `data.typ`), which is
// almost never presentation order, so the query route sorts explicitly here —
// `slip-order` (see `tags.typ`) is the default.
//
// `tags:` also accepts a PREDICATE — a function from a tag dictionary to a
// bool — as the extension point for a full boolean grammar
// (`@rookery/search`'s `a&b`) with no dependency on search: a caller builds
// the predicate itself with
// `t => eval-tag-query(parse-tag-query("a&b").rpn, t.keys())` and hands it
// straight to `tags:`. `t.keys()` because the predicate is handed the tag
// DICTIONARY while `eval-tag-query` walks an array of tag names.
//
// `where:` is the row-shaped counterpart: a predicate over the WHOLE
// registry row rather than only its tag dictionary, for a selection `tags:`
// cannot express — by `created`, `page`, `name`, `title`, or `body`. A row
// (`ideas(values: true)`, `@rookery/core`'s `data.typ`) carries `id`, `name`,
// `title`, `text`, `label`, `tags` (a flat array of key names), `tags-dict`
// (the full dictionary, values included), `body`, `href`, `page`, and
// `created`. `tags:` keeps its narrower one-argument shape — a tag query
// needs nothing off the row, and the narrow shape is what a grammar like
// search's slots into — so a query needing a field off the row reaches for
// `where:` instead. The
// two compose: `tags:` runs first, since it is core's own cheap filter, and
// `where:` narrows whatever survives it.
//
// `row:` is `order:`'s key-function shape put to a different use: grouping
// rather than sorting. A function is called once per `"row"`-kind entry,
// over the WHOLE registry row, and its result — an `int` or `none` — travels
// on the entry as `computed-row`, read by `#slipshow`'s `_row-runs`
// (`slipshow.typ`) ahead of that note's own `slip-row` tag. A `"content"`
// entry has no registry row to hand the function, so it is skipped entirely
// and that entry's row stays whatever `slip-tags-of` found on its body.
// `row:` never reorders anything — see `slipshow.typ`'s header for the
// consecutive-runs rule it feeds.

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

// The four accepted `order` forms, all sorted through `_sort-pairs`:
//
//   - an ARRAY of note names/ids — sort by position in that array;
//   - `"created"` — ascending by the row's `created` field;
//   - `"slip-order"` (the default) — ascending by the note's `slip-order` tag;
//   - a FUNCTION — ascending by `order(row)`, over the WHOLE row (the same
//     shape `where:` sees), so a deck can be ordered by title, priority,
//     page, body length, a computed score, or any composite of those.
//
// A key function and not a comparator, because Typst has no comparator
// anywhere: `array.sorted` takes only `key:`. `reverse:` is how descending
// order is reached.
//
// Every form treats "no key" — an unmatched array position, no `created`, no
// `slip-order` tag, a key function returning `none` — the same way: that row
// sorts LAST, in id order, regardless of `reverse`. `reverse` therefore
// reverses only the KEYED rows: an undated note is not "first" in a
// reverse-chronological deck, it is still the note with no date.
#let _sort-pairs(pairs, reverse) = {
  // Sort the keyed rows by a COMPOUND key — the real key, then the row's
  // `id` — rather than relying on `.sorted()`'s stability: a tie keeps id
  // order, a reader can check that directly, and the build stays
  // reproducible whatever Typst's sort does with equal keys.
  let keyed = pairs
    .filter(p => p.key != none)
    .sorted(key: p => (p.key, p.row.id))
    .map(p => p.row)
  if reverse { keyed = keyed.rev() }
  keyed + pairs.filter(p => p.key == none).map(p => p.row).sorted(key: row => row.id)
}

#let _sort-rows(rows, order, reverse) = {
  if type(order) == array {
    // Position in `order`, matched against either `name` or `id` so a caller
    // may write whichever form is at hand; a row named nowhere in `order`
    // is unkeyed (`position` already returns `none`), which keeps unnamed
    // rows after every named one and in their incoming (id) order among
    // themselves.
    _sort-pairs(
      rows.map(row => (key: order.position(n => n == row.name or n == row.id), row: row)),
      reverse,
    )
  } else if order == "created" {
    // `[year][month][day]` and no time fields: `display()` errors on a field
    // the datetime was not constructed with, and this shape sorts in date
    // order as a plain string.
    _sort-pairs(
      rows.map(row => (
        key: if row.created == none { none } else { row.created.display("[year][month][day]") },
        row: row,
      )),
      reverse,
    )
  } else if order == "slip-order" {
    _sort-pairs(rows.map(row => (key: order-of(row.tags-dict), row: row)), reverse)
  } else if type(order) == function {
    // Call the key function ONCE per row — an author's key function may walk
    // the note's body — and keep the pair `(key, row)`, rather than sorting a
    // single compound key that folds `none`-ness into it: Typst cannot
    // compare values of different types, so a `.sorted()` over a mix of
    // `none` and a real key would error out rather than merely order oddly.
    // Partitioning on `none` (in `_sort-pairs`) makes that mixed comparison
    // impossible instead of merely unlikely.
    let pairs = rows.map(row => (key: order(row), row: row))
    let kinds = pairs.map(p => p.key).filter(k => k != none).map(type).dedup()
    assert(
      kinds.len() <= 1,
      message: "@rookery/slipshow: `order`'s key function must return the same "
        + "type for every note — got " + kinds.map(repr).join(" and ")
        + ". Typst cannot compare values of different types.",
    )
    if kinds.len() == 1 {
      assert(
        kinds.at(0) in (int, float, str, datetime),
        message: "@rookery/slipshow: `order`'s key function must return an "
          + "int, float, str, or datetime — got " + repr(kinds.at(0))
          + ". `r.title` is content and cannot be compared this way — use a "
          + "string field like `r.label` or `r.text` instead.",
      )
    }
    _sort-pairs(pairs, reverse)
  } else {
    panic(
      "@rookery/slipshow: `order` must be an array of note names/ids, "
        + "\"created\", \"slip-order\" (the default), or a function from a "
        + "registry row to a comparable value — got " + repr(order),
    )
  }
}

// Runs `row` once per `"row"`-kind entry and attaches its result as
// `computed-row` — present ONLY on the entries the function actually ran on.
// A `"content"` entry never gets the key at all, and neither does any entry
// when `row` itself is `none`: `#slipshow`'s `_row-runs` (`slipshow.typ`)
// tells "no computed row, fall back to the note's own `slip-row` tag" apart
// from "computed as `none`, this slip joins no row" by that key's presence,
// not by its value — collapsing the two would make a function that groups
// most notes but deliberately excludes some indistinguishable from a
// function never having run on them at all.
#let _apply-row(entries, row) = {
  if row == none { return entries }
  entries.map(e => {
    if e.kind != "row" { return e }
    let computed = row(e.row)
    assert(
      computed == none or type(computed) == int,
      message: "@rookery/slipshow: `row`'s key function must return an "
        + "int or `none` — got " + repr(computed),
    )
    e + (computed-row: computed)
  })
}

// `class:`'s counterpart to `_apply-row` above, same shape and same
// key-presence rule: `computed-class` lands ONLY on the entries the function
// ran on, so `#slipshow`'s `_entry-class` (`slipshow.typ`) can tell "no
// computed class, fall back to the note's own `slip-class` tag" apart from
// "computed as `none`, this slip gets no class at all" by that key's
// presence rather than its value.
#let _apply-class(entries, class) = {
  if class == none { return entries }
  entries.map(e => {
    if e.kind != "row" { return e }
    let computed = class(e.row)
    assert(
      computed == none or type(computed) == str,
      message: "@rookery/slipshow: `class`'s key function must return a str or "
        + "`none` — got " + repr(computed),
    )
    e + (computed-class: computed)
  })
}

// `edges:`'s counterpart to the two above, and the only one of the three
// whose result is a LIST: the note names this slip points at, attached as
// `computed-edges` and read by `#slipshow`'s `_edge-ids` (`slipshow.typ`).
// A `label` is normalized to its string form here, exactly as
// `_resolve-slip-item` does, so what travels on the entry is always an array
// of plain names.
//
// NO KEY-PRESENCE RULE, unlike `computed-row`/`computed-class`: a computed
// `none` is stored as the empty array rather than kept distinct, because
// there is no `slip-edges` tag for an entry to fall back to. "Points at
// nothing" and "computed no edges" are the same claim, so they get the same
// value.
#let _apply-edges(entries, edges) = {
  if edges == none { return entries }
  entries.map(e => {
    if e.kind != "row" { return e }
    let computed = edges(e.row)
    let bad = (
      "@rookery/slipshow: `edges`'s key function must return an array of "
        + "note names (as a string or label), or `none` — got " + repr(computed)
    )
    assert(computed == none or type(computed) == array, message: bad)
    let names = if computed == none { () } else {
      assert(computed.all(n => type(n) in (str, label)), message: bad)
      computed.map(n => if type(n) == label { str(n) } else { n })
    }
    e + (computed-edges: names)
  })
}

// A registry lookup keyed by both `name` and `id`, built from ONE
// `ideas(values: true)` call — resolving each `slips:` name against a fresh
// query would pay that walk once per slip instead of once per deck (`ideas()`
// resolves the whole registry per call; see its own header, `@rookery/core`'s
// `data.typ`, line 290). Keyed by both forms so a caller may write whichever
// is at hand, exactly as `order:`'s array route already allows (`_sort-rows`
// above).
#let _slip-lookup() = {
  let by-key = (:)
  for row in ideas(values: true) {
    by-key.insert(row.name, row)
    by-key.insert(row.id, row)
  }
  by-key
}

// One `slips:` array element, dispatched by Typst type: `str`/`label` is a
// NAME, resolved through `lookup` into the same shape the query route
// returns; anything else is CONTENT, read directly as it always has been.
// `lookup` is `(:)` when the caller's array holds no name at all — see
// `resolve-slips` below, which then skips the registry read entirely.
//
// A name resolving to nothing PANICS rather than being skipped: unlike a
// dangling `#window` reference (which core answers emptily), a named slip is
// an assertion about what the presentation contains, and a deck that loses a
// slide silently is worse than a build that stops.
#let _resolve-slip-item(item, lookup) = {
  if type(item) in (str, label) {
    let n = if type(item) == label { str(item) } else { item }
    let row = lookup.at(n, default: none)
    if row == none {
      panic(
        "@rookery/slipshow: #slipshow's `slips:` names \"" + n + "\", which is not "
          + "a registered note. Either the name is misspelled, or the note is "
          + "authored on a page the spine does not include.",
      )
    }
    (kind: "row", row: row, tags: row.tags-dict)
  } else {
    (kind: "content", content: item, tags: slip-tags-of(item))
  }
}

// Resolves a slipshow's slip list, from either definition route:
//
//   #context resolve-slips(tags: "slip")                    // a tag query
//   #context resolve-slips(where: r => r.page == "methods")  // a row query
//   resolve-slips(slips: (slip("a")[..], slip("b")[..]))     // content only
//   #context resolve-slips(slips: ("a", <b>))                // names only
//   #context resolve-slips(slips: (slip("title")[..], "a"))  // a mix
//
// Every route returns entries in one of two shapes — a `"content"` entry is
// rendered inline, a `"row"` entry via `#window` — so the renderer needs no
// key-presence guessing to tell them apart:
//
//   (kind: "content", content: <item>, tags: <dict>)   // rendered content
//   (kind: "row", row: <ideas() row>, tags: <dict>)     // a registry row
//
// `slips:` produces both shapes, per element (see `_resolve-slip-item`); the
// query route (`tags:`/`where:`) produces only `"row"`. `#context` is
// required whenever a registry read happens: always for the query route, and
// for `slips:` only when its array contains at least one name — a
// content-only array reads no registry and needs none. `tags:` and `where:`
// compose — both may be given together — but `slips:` is exclusive with
// either, since an explicit array has nothing left to filter. `order:`/
// `reverse:` sort the query route's rows (see `_sort-rows`); both are refused
// alongside `slips:` for the same reason — the array IS the order, whatever
// mix of content and names it holds.
//
// `row:`, unlike `order:`/`reverse:`, is NOT refused alongside `slips:` — it
// groups, it does not reorder, so it composes with either route the same
// way (`_apply-row`). A `"row"`-kind entry gains `computed-row` when `row:`
// runs on it; a `"content"` entry never does. `class:` composes with either
// route for the same reason — it neither selects nor reorders — and gains
// `computed-class` on the same `"row"`-only terms (`_apply-class`).
// `edges:` is the third of them and composes the same way, gaining
// `computed-edges` on the same `"row"`-only terms (`_apply-edges`): it names
// the slips a slip points at, which is a fact about a graph only the deck's
// caller knows, and it neither selects nor reorders either.
#let resolve-slips(
  slips: none,
  tags: none,
  where: none,
  match: "any",
  order: "slip-order",
  reverse: false,
  row: none,
  class: none,
  edges: none,
) = {
  assert(
    type(reverse) == bool,
    message: "@rookery/slipshow: `reverse` must be a bool — got " + repr(reverse),
  )
  assert(
    row == none or type(row) == function,
    message: "@rookery/slipshow: `row` must be a function taking a registry "
      + "row and returning an int or `none` — got " + repr(row),
  )
  assert(
    class == none or type(class) == function,
    message: "@rookery/slipshow: `class` must be a function taking a registry "
      + "row and returning a str or `none` — got " + repr(class),
  )
  assert(
    edges == none or type(edges) == function,
    message: "@rookery/slipshow: `edges` must be a function taking a registry "
      + "row and returning an array of note names — got " + repr(edges),
  )
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
        + "ideas and/or note names (as a string or label) — got " + repr(slips),
    )
    // An explicit array is already ordered by construction; re-sorting it (or
    // reversing that order) would be surprising, so `order:`/`reverse:` are
    // refused rather than silently ignored.
    assert(
      order == "slip-order",
      message: "@rookery/slipshow: `order` and `slips:` conflict — an explicit "
        + "array is already in the order it was written, so `order:` has "
        + "nothing to do. Drop `order:`, or use `tags:` instead of `slips:`.",
    )
    assert(
      reverse == false,
      message: "@rookery/slipshow: `reverse` and `slips:` conflict — an explicit "
        + "array is already in the order it was written, so `reverse:` has "
        + "nothing to do. Drop `reverse:`, or use `tags:` instead of `slips:`.",
    )
    // The registry read is lazy: only when the array actually names a note,
    // so a content-only array stays exactly as cheap as it was before names
    // existed, and keeps working with no registry (and no `#context`) at all.
    let lookup = if slips.any(item => type(item) in (str, label)) { _slip-lookup() } else { (:) }
    let entries = slips.map(item => _resolve-slip-item(item, lookup))
    return _apply-edges(_apply-class(_apply-row(entries, row), class), edges)
  }

  let rows = _sort-rows(_slip-rows-from-query(tags, match, where), order, reverse)
  let entries = rows.map(row => (kind: "row", row: row, tags: row.tags-dict))
  _apply-edges(_apply-class(_apply-row(entries, row), class), edges)
}
