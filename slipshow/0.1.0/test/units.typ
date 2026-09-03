// Unit fixture for @rookery/slipshow's pure helpers. No runner: an `assert`
// that fails fails the compile with a line number, and a passing compile is
// the green light.

#import "/src/lib.typ": *
#import "@rookery/core:0.1.0": idea, ideas

// Every slip carries the base key, and nothing else by default.
#assert.eq(slip-tags(), (slip: none))

// FLAT keys encode their value in the key, so `slip-fullscreen` and
// `slip-enter-center` are both filterable and both render a pill.
#let with-both = slip-tags(fullscreen: true, enter: "center")
#assert.eq(with-both.at("slip"), none)
#assert.eq(with-both.at("slip-fullscreen"), none)
#assert.eq(with-both.at("slip-enter-center"), none)

// VALUED keys carry the value untouched — this file has no business
// interpreting a colour, gradient, or image. `max-width` is untouched the
// same way: a ratio arrives as a ratio, not converted to any other unit.
#assert.eq(slip-tags(background: red).at("slip-background"), red)
#let with-row-and-width = slip-tags(row: 2, max-width: 45%)
#assert.eq(with-row-and-width.at("slip-row"), 2)
#assert.eq(with-row-and-width.at("slip-max-width"), 45%)

// The caller's own `tags:` win outright on a collision.
#assert.eq(slip-tags(tags: (slip: "mine")).at("slip"), "mine")

// `enter-of` decodes from the key rather than storing the name a second time.
#assert.eq(enter-of(slip-tags(enter: "focus")), "focus")
#assert.eq(enter-of(slip-tags(enter: "right")), "right")
#assert.eq(enter-of((:)), none)

// Row zero is a real row: `row-of` must return it, not treat it as absent
// the way a truthiness test on `0` would.
#assert.eq(row-of(slip-tags(row: 0)), 0)

// Reading a registered note's tags back needs the registry, hence the
// `#context` below; `ideas(values: true)` is what hands back a `tags-dict`
// per row.
#slip("intro", fullscreen: true)[Body]
#slip[Body]
#slip("x", tags: ("draft",))[Body]
#slip("a2", row: 1, max-width: 30em)[Body]
#idea("plain")[Body]

#context {
  let rows = ideas(values: true)
  let by-name = name => rows.find(r => r.name == name)

  // A named slip carries both the base key and its own presentation option.
  let intro = by-name("intro")
  assert("slip" in intro.tags-dict)
  assert("slip-fullscreen" in intro.tags-dict)

  // `row`/`max-width` survive the registry round trip, which is the whole
  // reason they are tags rather than ordinary `#slip` arguments.
  let a2 = by-name("a2")
  assert("slip-row" in a2.tags-dict)
  assert("slip-max-width" in a2.tags-dict)

  // Five slips registered here: four named by nothing but their auto id or
  // an explicit name, plus `meta-check` below — the positional sink is
  // forwarded. Four more join them further down, for `resolve-slips`'s own
  // tests, plus four for `order:`'s key-function/`reverse:` tests further
  // down still, plus two for the `slips:` NAME route's own tests, plus five
  // for `row:`'s own tests, bringing the total to twenty.
  assert.eq(rows.filter(r => "slip" in r.tags-dict).len(), 20)

  // THE REGRESSION THE `.with()` TRAP WOULD CAUSE: a caller's own `tags:`
  // must MERGE with the `slip` tag, not replace it. If `slip` were missing
  // here, `#slip` was built on `idea.with(tags: (slip: none))` instead of
  // `tagged-idea`.
  let x = by-name("x")
  assert("slip" in x.tags-dict)
  assert("draft" in x.tags-dict)

  // A plain `#idea` stays plain — no `slip-*` key leaks onto an unrelated note.
  let plain = by-name("plain")
  assert(plain.tags-dict.keys().filter(k => k.starts-with("slip")).len() == 0)
}

// `slip-meta`/`slip-tags-of` recover a note's tags from RENDERED content
// alone — the route a `#slipshow` built from an explicit ordered array
// needs, since that array holds content rather than registry rows.

// Unplaced content: nothing is registered by merely reading it, so this is a
// pure content check.
#assert("slip" in slip-tags-of(slip("a", fullscreen: true)[Body]))
#assert("slip-fullscreen" in slip-tags-of(slip("a", fullscreen: true)[Body]))

// A plain `#idea` carries no `slip-*` key.
#assert(slip-tags-of(idea("b")[Body]).keys().filter(k => k.starts-with("slip")).len() == 0)

// Content with no idea in it at all is a legitimate answer, not an error.
#assert.eq(slip-tags-of([just some text]), (:))

// `slip-meta` hands back the whole payload — title and level, not only tags.
#let c-meta = slip-meta(slip("c", title: [T])[Body])
#assert.eq(c-meta.at("title"), [T])
#assert.eq(c-meta.at("level"), 1)

// The property this file exists for: both definition routes see IDENTICAL
// options for the same note. Placed for real so `ideas()` can see it, and
// the same content value read directly for the content-only route.
#let meta-check = slip("meta-check", fullscreen: true, order: 2)[Meta body]
#meta-check

#context {
  let rec = ideas(values: true).find(r => r.name == "meta-check")
  assert.eq(slip-tags-of(meta-check), rec.tags-dict)
}

// `resolve-slips` — the `slips:` route: an explicit array, returned in that
// exact order, with no registry read at all.
#let sel-a = slip("sel-a")[A]
#let sel-b = slip("sel-b")[B]
#let sel-content = resolve-slips(slips: (sel-a, sel-b))
#assert.eq(sel-content.len(), 2)
#assert.eq(sel-content.at(0), (kind: "content", content: sel-a, tags: slip-tags-of(sel-a)))
#assert.eq(sel-content.at(1), (kind: "content", content: sel-b, tags: slip-tags-of(sel-b)))

// The `tags:` route, registered for real so `ideas()` can see them: a lower
// `slip-order` sorts first regardless of id order.
#slip("sel-ord-second", order: 2)[Second]
#slip("sel-ord-first", order: 1)[First]

#context {
  let names = resolve-slips(tags: "slip").map(e => e.row.name)
  assert(
    names.position(n => n == "sel-ord-first") < names.position(n => n == "sel-ord-second"),
  )
}

// The predicate route: a plain function over a tag dictionary, proving the
// filter works with no `@rookery/search` import anywhere in this package.
#context {
  let names = resolve-slips(tags: t => "slip-fullscreen" in t).map(e => e.row.name)
  assert.eq(names, ("meta-check", "intro", "slot-a"))
}

// `order: "created"`: a note with no `created:` sorts after one that has one.
#slip("sel-dated", created: datetime(year: 2020, month: 1, day: 1))[Dated]
#slip("sel-undated")[Undated]

#context {
  let names = resolve-slips(tags: "slip", order: "created").map(e => e.row.name)
  assert(names.position(n => n == "sel-dated") < names.position(n => n == "sel-undated"))
}

// `where:` selects on the WHOLE row rather than only the tag dictionary —
// here, `created`, which no `tags:` predicate can see at all. Plain ideas,
// not slips: `where:` has nothing to do with `#slip`.
#idea("where-old", created: datetime(year: 2024, month: 1, day: 1))[Old]
#idea("where-new", created: datetime(year: 2026, month: 1, day: 1))[New]

#context {
  let names = resolve-slips(where: r => r.created != none and r.created.year() >= 2025)
    .map(e => e.row.name)
  assert.eq(names, ("where-new",))
}

// `tags:` and `where:` compose: both filters apply, so a query naming a tag
// AND a row predicate narrows by both rather than either one winning.
#context {
  let names = resolve-slips(tags: "slip", where: r => r.name == "intro").map(e => e.row.name)
  assert.eq(names, ("intro",))
}

// A `where:`-only query is not silently narrowed to slips: it sees every
// registered note, exactly as `ideas(values: true)` does.
#context {
  assert.eq(resolve-slips(where: r => true).len(), ideas(values: true).len())
}

// `order:` also accepts a KEY FUNCTION over the whole row, so a deck can be
// ordered by any metadata a note carries. Three slips whose `label` values
// sort in a different order than their ids: `where:` narrows the query to
// exactly this cohort, whatever else in this file also carries `slip`.
#slip("ord-p", title: [Zeta])[Body]
#slip("ord-q", title: [Alpha])[Body]
#slip("ord-r", title: [Mu])[Body]

#let ord-cohort = r => r.name.starts-with("ord-")

#context {
  // Alphabetical by `label` ("Alpha" < "Mu" < "Zeta"), not by id ("ord-p" <
  // "ord-q" < "ord-r").
  let names = resolve-slips(tags: "slip", where: ord-cohort, order: r => r.label)
    .map(e => e.row.name)
  assert.eq(names, ("ord-q", "ord-r", "ord-p"))

  // `reverse: true` is the exact reverse of that list.
  let names-rev = resolve-slips(tags: "slip", where: ord-cohort, order: r => r.label, reverse: true)
    .map(e => e.row.name)
  assert.eq(names-rev, ("ord-p", "ord-r", "ord-q"))

  // A key function returning `none` for one note (here, `ord-r`) places that
  // note last — under `reverse: false` AND `reverse: true` alike, since
  // `reverse` only reverses the rows that DO have a key.
  let by-label-none-r = r => if r.name == "ord-r" { none } else { r.label }
  assert.eq(
    resolve-slips(tags: "slip", where: ord-cohort, order: by-label-none-r).map(e => e.row.name),
    ("ord-q", "ord-p", "ord-r"),
  )
  assert.eq(
    resolve-slips(tags: "slip", where: ord-cohort, order: by-label-none-r, reverse: true)
      .map(e => e.row.name),
    ("ord-p", "ord-q", "ord-r"),
  )
}

// `reverse:` applies to `"created"` too — a reverse-chronological deck is the
// single most-wanted presentation order there is. `chrono-new` is dated after
// every other `created` slip in this file, so it must land first; an undated
// slip (there are several) still lands last, not first.
#slip("chrono-new", created: datetime(year: 2024, month: 1, day: 1))[Newest]

#context {
  let entries = resolve-slips(tags: "slip", order: "created", reverse: true)
  assert.eq(entries.first().row.name, "chrono-new")
  assert.eq(entries.last().row.created, none)
}

// `resolve-slips` — the `slips:` NAME route: an array element may name an
// already-authored note instead of carrying its rendered content, resolved
// through the registry in the array's own order.
#slip("slot-a", fullscreen: true)[Slot A]
#slip("slot-b")[Slot B]

#context {
  // Names resolve in the array's own order, not id order (`slot-a` < `slot-b`
  // by id, but the array below asks for `slot-b` first).
  let by-name = resolve-slips(slips: ("slot-b", "slot-a"))
  assert.eq(by-name.len(), 2)
  assert.eq(by-name.map(e => e.kind), ("row", "row"))
  assert.eq(by-name.map(e => e.row.name), ("slot-b", "slot-a"))

  // THE ASSERTION THIS ROUTE EXISTS FOR: the resolved row carries its own
  // `#slip` options, here `slip-fullscreen` — exactly what the `window(name)`
  // workaround (see `select.typ`'s header) silently drops instead.
  assert("slip-fullscreen" in by-name.at(1).tags)

  // A label names a note as well as a plain string.
  let by-label = resolve-slips(slips: (<slot-b>, <slot-a>))
  assert.eq(by-label.map(e => e.row.name), ("slot-b", "slot-a"))

  // A mixed array — inline content, then a name — resolves each element by
  // its own type: `"content"` first, `"row"` second.
  let title-slip = slip("slot-title")[Title]
  let mixed = resolve-slips(slips: (title-slip, "slot-a"))
  assert.eq(mixed.map(e => e.kind), ("content", "row"))
  assert.eq(mixed.at(1).row.name, "slot-a")
}

// `row:` — a key function over the whole row, grouping a query deck the way
// `examples/dag` groups a `@rookery/todos` DAG layer onto notes that carry
// no `slip-row` tag of their own. `rk-a`/`rk-b` share a computed row, `rk-c`
// sits in the next one, so `_row-runs` (`slipshow.typ`) produces two runs.
#slip("rk-a")[A]
#slip("rk-b")[B]
#slip("rk-c")[C]

#let rk-layer = (rk-a: 0, rk-b: 0, rk-c: 1)
#let rk-cohort = r => r.name.starts-with("rk-") and not r.name.starts-with("rk-none-")

#context {
  let entries = resolve-slips(
    tags: "slip", where: rk-cohort, order: r => r.name, row: r => rk-layer.at(r.name),
  )
  assert.eq(entries.map(e => e.computed-row), (0, 0, 1))
  let runs = _row-runs(entries)
  assert.eq(runs.map(run => run.len()), (2, 1))
}

// A `row:` function returning `none` for one note takes that slip out of
// every row: `computed-row` is present AS `none` (not absent — `_apply-row`
// ran on this entry, it just computed no row), so `_row-runs` gives it a run
// of its own and `#slipshow` renders it with no `div.slip-row` wrapper, per
// the same rule an authored `slip-row: none` already follows.
#slip("rk-none-a")[A]
#slip("rk-none-b")[B]

#let rk-none-cohort = r => r.name.starts-with("rk-none-")

#context {
  let entries = resolve-slips(
    tags: "slip", where: rk-none-cohort, order: r => r.name,
    row: r => if r.name == "rk-none-b" { none } else { 0 },
  )
  assert.eq(entries.map(e => "computed-row" in e), (true, true))
  assert.eq(entries.at(1).computed-row, none)
  let runs = _row-runs(entries)
  assert.eq(runs.map(run => run.len()), (1, 1))
}

// A `"content"` entry has no registry row to hand `row:` at all, so the
// function is skipped outright and the entry carries no `computed-row` key —
// not even `none` — whatever `row:` the deck was given.
#let rk-content = slip("rk-content")[Loose content]
#assert("computed-row" not in resolve-slips(slips: (rk-content,), row: r => 0).first())
