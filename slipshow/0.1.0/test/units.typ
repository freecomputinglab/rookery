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
// interpreting a colour, gradient, or image.
#assert.eq(slip-tags(background: red).at("slip-background"), red)

// The caller's own `tags:` win outright on a collision.
#assert.eq(slip-tags(tags: (slip: "mine")).at("slip"), "mine")

// `enter-of` decodes from the key rather than storing the name a second time.
#assert.eq(enter-of(slip-tags(enter: "focus")), "focus")
#assert.eq(enter-of((:)), none)

// Reading a registered note's tags back needs the registry, hence the
// `#context` below; `ideas(values: true)` is what hands back a `tags-dict`
// per row.
#slip("intro", fullscreen: true)[Body]
#slip[Body]
#slip("x", tags: ("draft",))[Body]
#idea("plain")[Body]

#context {
  let rows = ideas(values: true)
  let by-name = name => rows.find(r => r.name == name)

  // A named slip carries both the base key and its own presentation option.
  let intro = by-name("intro")
  assert("slip" in intro.tags-dict)
  assert("slip-fullscreen" in intro.tags-dict)

  // Four slips registered here: three named by nothing but their auto id or
  // an explicit name, plus `meta-check` below — the positional sink is
  // forwarded. Four more join them further down, for `resolve-slips`'s own
  // tests, bringing the total to eight.
  assert.eq(rows.filter(r => "slip" in r.tags-dict).len(), 8)

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
  assert.eq(names, ("meta-check", "intro"))
}

// `order: "created"`: a note with no `created:` sorts after one that has one.
#slip("sel-dated", created: datetime(year: 2020, month: 1, day: 1))[Dated]
#slip("sel-undated")[Undated]

#context {
  let names = resolve-slips(tags: "slip", order: "created").map(e => e.row.name)
  assert(names.position(n => n == "sel-dated") < names.position(n => n == "sel-undated"))
}
