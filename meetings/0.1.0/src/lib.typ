// @rookery/meetings — a meeting: who was in the room, when it happened, what was
// said.
//
// A meeting is the smallest note family in this repo and the only one with no
// lifecycle: it is over the moment it happened. What makes it worth a package is
// the two things a plain `#idea` cannot say — WHO it was with, and WHEN it took
// place — and the fact that both are askable across a whole rookery once they are
// stored rather than written into prose.
//
//   #import "@rookery/meetings:0.1.0": meeting
//   #meeting(<doshi-velez-26-9-10>, with: <doshi-velez-finale>,
//            on: datetime(year: 2026, month: 9, day: 10), today: TODAY)[..]
//
// Both imports are aliased, and the aliases are load-bearing rather than tidy. A
// Typst module re-exports every top-level binding it holds, star-imported ones
// included, so `#import "@rookery/core:0.1.0": *` here would make this package a
// second source of `idea`, `window` and `rookery` — and a consumer star-importing
// several rookery packages resolves those names by import order, so an undecorated
// `window` arriving from here would silently shadow @rookery/todos' skinned one.
// Aliased, this module exports its own five names and nothing else.
#import "@rookery/core:0.1.0" as core
#import "@rookery/timeline:0.1.0" as tl

// The flat tag every meeting carries, so `tags:meeting` is askable corpus-wide.
#let MEETING-KEY = "meeting"

// Who was in the room, as idea names — `("hagen-blix", "ed-ongweso")`. A reference
// to other ideas, which is what earns it a key of its own rather than a place in
// the flat tag list. An array, since a meeting is a thing that happens between
// several.
//
// The names are meant to be people and are not required to be. Nothing here
// checks: the key names the relation rather than a family, so whatever the target
// note turns out to be — a person, a lab, a reading group — "this meeting was with
// that" is the same fact.
//
// A tag key is interpolated into an `idea-tag-<key>` class, so it must stay
// CSS-safe — the reason `with:` lands in a valued key rather than a tag per
// person.
#let MEETING-WITH-KEY = "meeting-with"

// The stage `on:` writes into @rookery/timeline's log. Not one of that package's
// three reserved names (`scheduled`, `deadline`, `closed`) — those are plans and a
// closing, and this is the event itself.
#let OCCURRED-STAGE = "occurred"

// Readers, for a consumer building a view over meetings. Both take the tag
// DICTIONARY — `tag-data()`'s per-note value, or an `ideas(values: true)` row's
// `tags-dict` — so neither needs a registry read of its own.
#let meeting-with-of(tags) = tags.at(MEETING-WITH-KEY, default: ())
#let occurred-of(tags) = tl.stage-date(tags, OCCURRED-STAGE)

// A page tag about to be interpolated into an `idea-tag-<key>` class. Rejected
// here rather than in a stylesheet, where the only symptom is a rule that silently
// never matches.
#let _CSS-SAFE-RE = regex("^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$")
#let _css-safe(name) = assert(
  type(name) == str and name.match(_CSS-SAFE-RE) != none,
  message: "@rookery/meetings: the page tag "
    + repr(name)
    + " is not usable as a CSS class fragment. Use alphanumerics and interior hyphens only.",
)

// `with:` takes either spelling a rookery reference does — a LABEL
// (`<hagen-blix>`, the form to prefer, since it reads as the reference it is) or a
// bare string — and one name needs no array ceremony. `core._norm` flattens all of
// them, a full `idea:x` included, to the one name the tag stores.
#let _who(with) = {
  if with == none { return () }
  let given = if type(with) == array { with } else { (with,) }
  given.map(core._norm)
}

// Each name becomes its own `ref`, which does two things no written link can. It
// takes the resolved title of the note it points at (rookery's `show ref:
// hyperlink` rule), so a person's name is typed once, on their own note; and it
// earns them a backlink, so their page lists every meeting they were in.
#let _refs(who) = who.map(n => ref(label("idea:" + n))).join(", ")

// The header a meeting opens with is a labelled row, not a sentence. "With Hagen
// Blix" as a paragraph reads as the note's first thought; a labelled row reads as
// the note's record, which is what it is — and what a body full of what was
// actually said should not have to open by restating.
//
// The label is a div rather than a heading: it names the block under it, and a
// meeting's body carries real headings, so a heading here would claim a place in
// the page's outline above them.
//
// HTML only: `html.elem` contributes nothing at all on a paged target — element
// and children alike. A meeting's prose still renders there; its record does not.
// That is the same trade every view in this family makes.
#let _fields(who) = {
  html.elem("div", attrs: (class: "meeting-fields-head"), "Meeting")
  html.elem("dl", attrs: (class: "meeting-fields"), {
    html.elem("dt", "With")
    // Comma-joined rather than one per line: a person's name carries no commas of
    // its own, so a row of them reads as a list without needing a column.
    html.elem("dd", _refs(who))
  })
}

// `#meetings(..)` -> a `#meeting` factory carrying a page's own tags:
//
//   #let meeting = meetings("digital-theory-lab", today: TODAY)
//   #meeting(<blix-27-8-26>, with: <hagen-blix>, on: d)[..]
//
// The plural is the factory, the singular the note. Each positional argument takes
// any shape a rookery `tags:` does (a string, an array, a dictionary), variadic so
// that `meetings()` is a legal call — a page collecting meetings under no subject
// of its own wants exactly that, and a required parameter would force it to write
// `meetings(none)`.
//
// `today:` is here because Typst has no clock. The rail below is drawn by
// @rookery/timeline's `#timeline-view`, which needs a reference date to tell what
// has happened from what is booked; that package refuses to guess one and panics
// with a message naming the fix. A project stamps its build date in as an input and
// passes it once, here — a per-call `today:` overrides it for one meeting. A
// document that sets its own `#set document(date:)` needs neither.
#let meetings(..names, today: none) = {
  assert(
    names.named().len() == 0,
    message: "@rookery/meetings: #meetings takes the page's tags POSITIONALLY — "
      + "`meetings(TAG_NAME, today: ..)`. Got the named argument(s) "
      + names.named().keys().join(", ")
      + ", which would be silently dropped.",
  )
  let own = names.pos().fold((:), (acc, t) => acc + core._norm-tags(t))
  for (k, _) in own.pairs() { _css-safe(k) }
  // Captured under its own name so the closure's `today:` parameter can default to
  // the factory's without shadowing the value it falls back to.
  let factory-today = today
  let mint = core.idea
  (
    tags: none,
    tag: none,
    with: none,
    on: none,
    today: factory-today,
    created: none,
    scheduled: none,
    deadline: none,
    timeline: none,
    ..args,
  ) => {
    let who = _who(with)
    assert(
      on == none or type(on) == datetime,
      message: "@rookery/meetings: `on:` is when the meeting happened and must be a "
        + "datetime — got " + repr(on) + ".",
    )
    // `on:` sets rookery's own `created:` (see below), so giving both is two
    // answers to when this meeting was — and picking one silently would put a date
    // nobody wrote on the record.
    assert(
      not (on != none and created != none),
      message: "@rookery/meetings: `on:` and `created:` are the same date for a "
        + "meeting — `on:` sets `created:` itself. Give one of them.",
    )
    let log = if timeline == none { (:) } else { timeline }
    if on != none {
      assert(
        OCCURRED-STAGE not in log,
        message: "@rookery/meetings: `on:` writes the `" + OCCURRED-STAGE
          + "` log entry, and `timeline:` already names it. Give one of them.",
      )
      log.insert(OCCURRED-STAGE, on)
    }
    // `#idea`'s OWN POSITIONAL CONTRACT, restated here because the header has to
    // land BEFORE the body and so cannot ride through `..args` blind: one
    // positional is the body, two are the name and the body.
    let pos = args.pos()
    assert(
      pos.len() == 1 or pos.len() == 2,
      message: "@rookery/meetings: #meeting takes a body, optionally preceded by a "
        + "name — `#meeting(<x>)[..]` or `#meeting[..]` — got "
        + str(pos.len())
        + " positional argument(s).",
    )
    let name = if pos.len() == 2 { pos.at(0) } else { none }
    let body = pos.last()
    // Caller's tags first, the page's own on the right — the order that lets a
    // meeting say something the page did not. The two derived keys land on top of
    // both: neither is the caller's free tags nor the page's subject, and nothing
    // else can be writing them. `MEETING-KEY` merges in UNDER all of them, so a
    // call site naming it keeps its own value.
    let all-tags = core._merge-base-tags(
      MEETING-KEY,
      core._norm-tags(tags) + core._norm-tags(tag) + own,
    )
    if who.len() > 0 { all-tags.insert(MEETING-WITH-KEY, who) }
    all-tags += tl.timeline-tags(scheduled: scheduled, deadline: deadline, timeline: log)
    // The name an untitled meeting gets: `with:`/`on:` are the whole reason it can
    // have one. "Meeting with Finale Doshi-Velez on 10.9.26" is what the note is,
    // and it is the one thing this factory knows that `#idea`'s own fallback cannot
    // reach — without it a titleless meeting is called by the first sixty
    // characters of its body wherever it is named rather than rendered, which for a
    // meeting is the first thing that happened to come up in it. A meeting that
    // titles itself keeps its own title; nothing here overrides an author.
    //
    // Refs, not the names as text, for `_fields`' first reason: a person's name is
    // typed once, on their own note, and a title built from it by hand would drift
    // the moment that note is renamed. The plain-text projection follows the
    // reference — @rookery/core's `_ref-text` resolves one to the target's own name
    // — so the search index reads "Meeting with Finale Doshi-Velez on 10.9.26".
    //
    // The date uses @rookery/timeline's own short form, `tl._fmt-day`, rather than
    // a format spelled out here: the rail under the header writes its dates that
    // way, and a title disagreeing with the rail two lines below it would be this
    // package holding two answers to how it writes a date.
    let stamp = if on == none { none } else { tl._fmt-day(on) }
    let derived = if "title" in args.named() {
      (:)
    } else if who.len() > 0 and stamp != none {
      (title: [Meeting with #_refs(who) on #stamp])
    } else if who.len() > 0 {
      (title: [Meeting with #_refs(who)])
    } else if stamp != none {
      (title: [Meeting on #stamp])
    } else {
      (:)
    }
    // The record opens the note, above the prose: who was there, then when. It
    // lives in the body rather than in a page template for the reason
    // @rookery/core's transclusion forces — a `#window` renders the body and knows
    // nothing about the consuming project's page chrome, so a rail drawn by a
    // template exists on the note's own page and nowhere else.
    //
    // `(:)` is the entry passed, not the note's own row, and that is what keeps the
    // rail one line: `tl.timeline` prepends rookery's `created` to a note's log,
    // and `on:` has just set `created` to the very date the `occurred` entry
    // carries — so passing the row would draw the same day twice.
    let full = {
      if who.len() > 0 { _fields(who) }
      tl.timeline-view((:), all-tags, today: today)
      body
    }
    // `on:` sets `created:`, which is what makes a meeting's date free to filter
    // and sort by: rookery keeps `created` a row field on every `ideas()` row,
    // where a tag value — the log included — costs a `tag-data()` walk to reach.
    // The log entry is what makes the date a timeline event; the row field is what
    // makes it a date. One value, two channels, and no way for them to disagree.
    let resolved-created = if created != none { created } else { on }
    // Two branches because a name is positional and Typst has no way to pass "no
    // positional argument here": an unnamed meeting must be called with the body
    // alone, not with `none` in front of it, which `#idea` would read as the name.
    if name == none {
      mint(tags: all-tags, created: resolved-created, ..derived, ..args.named(), full)
    } else {
      mint(name, tags: all-tags, created: resolved-created, ..derived, ..args.named(), full)
    }
  }
}

// The bare form, for a project with no page tags to fold in. `today:` per call.
#let meeting = meetings()
