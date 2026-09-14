// @rookery/cfps — a venue and its calls: a durable place things are heard from,
// and one round of it, with a deadline, a portal, and what happened when it was
// answered.
//
// A VENUE is what recurs — a programme, a conference series, a journal. A CFP is
// one round of it: a call for papers/applications, folded together with its own
// answer, so one note carries both what was sent and what came back. Two rounds
// of one programme are two cfps sharing one venue.
//
//   #let (venue, cfp, cfp-state) = cfps(kinds: (
//     postdoc: (sort: "job", ladder: (transit: ("submitted",), terminal: ("offered", "rejected"))),
//   ))
//   #venue("acme", title: [Acme University])[..]
//   #cfp("acme-postdoc-26", venue: <acme>, kind: "postdoc", deadline: d)[..]
//
// `kind`/`ladder` ARE CALLER CONFIGURATION, not a vocabulary this package owns.
// `accepted` ends a conference submission and is the middle of a journal's; a
// package cannot know that, the same reason @rookery/timeline's own
// `is-settled`/`rung`/`next-stage` take a ladder as a parameter rather than a
// constant. So `cfps(kinds:)` is a FACTORY, bound to a caller's vocabulary once,
// the same shape @rookery/meetings' `meetings(..)` and @rookery/bibtex's
// `bibtex(..)` already take.
//
// `#cfp` IS A SKIN ON @rookery/todos' `#todo`, not a hand-rolled closing flag.
// It closes through `done:` — a real date folded into the shared
// @rookery/timeline log — so `is-closed`/the flat `todo-closed` marker/
// `priority`'s worklist behaviour all come free and correct: `todo(..)` derives
// its flat marker FROM the same log entry `done:` writes, so the two can never
// disagree.

#import "@rookery/core:0.1.0": tagged-idea, _norm
#import "@rookery/todos:0.1.0": todo
#import "@rookery/timeline:0.1.0": (
  CLOSED-STAGE, DEADLINE-STAGE, SCHEDULED-STAGE, entries, is-settled, stage-of, timeline-of, timeline-view,
)

// ---- Tag keys ---------------------------------------------------------------
//
// Ported from the reference site's own `_lib/template.typ`, minus `CITATION-KEY`
// — that one belongs to a site's own bibliography, not to a venue/cfp pair.

#let VENUE-KEY = "venue"
#let VENUE-CALL-KEY = "venue-call"
// Host institution(s), as idea NAMES — an array, for a joint programme.
#let SCHOOL-KEY = "venue-school"
#let CFP-KEY = "cfp"
// The venue a call comes from, as a venue idea NAME. Optional: a call can be
// recorded before anything is written about the place it came from.
#let CFP-VENUE-KEY = "cfp-venue"
// A call's own name, carried as a valued tag purely so a tag-only filter can
// identify the row it is looking at.
#let CFP-ID-KEY = "cfp-id"
// THIS ROUND's portal, distinct from the venue's `call:` — a venue's `call:` is
// the standing submissions page; `apply:` is the instance, reissued every cycle.
#let APPLY-KEY = "submission-apply"
#let WORK-KEY = "submission-work"
// Marks a cfp's body as carried over from a past cycle's call rather than read
// off this round's own.
#let ESTIMATED-KEY = "submission-estimated"

// A local copy of rookery's four-form tag normalizer (none, string, array,
// dictionary), so this module stays a pure function of its arguments rather
// than reaching into a private core name — the same choice @rookery/todos'
// `tags.typ` makes for the same reason.
#let _norm-tags-local(v) = {
  if v == none {
    (:)
  } else if type(v) == str {
    ((v): none)
  } else if type(v) == dictionary {
    v
  } else {
    v.fold((:), (acc, t) => acc + ((t): none))
  }
}

// ---- The two-column metadata table -------------------------------------------
//
// Both `venue`/`cfp` open their body with this — a venue's `call:`, a cfp's
// `work:` — styled the same as @rookery/meetings' own `.meeting-fields`.
// `none`-valued rows drop out; an empty table draws nothing.
#let _opportunity-table(pairs) = {
  let pairs = pairs.filter(p => p.at(1) != none)
  if pairs.len() == 0 { return [] }
  html.elem("dl", attrs: (class: "opportunity-meta"), {
    for (term, value, how) in pairs {
      html.elem("dt", term)
      html.elem("dd", if how == "url" {
        link(value, value)
      } else if how == "path" {
        raw(value)
      } else {
        value.replace("-", " ")
      })
    }
  })
}

// The reference date, most specific first: the explicit `today:` argument, then
// the document's own `#set document(date:)`, then a panic — the exact fallback
// pattern @rookery/timeline's own `when.typ` uses. `document.date` yields `auto`
// on a document with no date set, not `none`, so both are tested for.
#let _resolve-today(today) = {
  if today != none {
    assert(
      type(today) == datetime,
      message: "@rookery/cfps: `today` must be a datetime — got " + repr(today),
    )
    return today
  }
  let d = document.date
  if d != auto and d != none { return d }
  panic(
    "@rookery/cfps: #cfp needs a reference date and there is none. Typst has no "
      + "wall clock, so pass one explicitly — `today: datetime(year: 2026, month: 8, "
      + "day: 25)` — or set the document's own date with `#set document(date: ..)`.",
  )
}

// ---- `kinds:` validation ------------------------------------------------------
//
// Eager, at factory-construction time, mirroring the shape @rookery/timeline's
// own `_assert-ladder` checks — a bad `kinds:` fails as soon as it is given, not
// on whichever `#cfp` call happens to hit the bad kind first.
#let _assert-kinds(kinds) = {
  assert(
    type(kinds) == dictionary,
    message: "@rookery/cfps: `kinds:` must be a dictionary of kind name -> "
      + "(sort: <string>, ladder: (transit: (..), terminal: (..))) — got "
      + repr(kinds),
  )
  for (name, spec) in kinds.pairs() {
    assert(
      type(spec) == dictionary and "sort" in spec and "ladder" in spec,
      message: "@rookery/cfps: kind " + repr(name) + " must be a dictionary with "
        + "`sort:` (a string) and `ladder:` (a @rookery/timeline ladder) — got "
        + repr(spec),
    )
    assert(
      type(spec.sort) == str,
      message: "@rookery/cfps: kind " + repr(name) + "'s `sort:` must be a string — got " + repr(spec.sort),
    )
    let ladder = spec.ladder
    assert(
      ladder != none and type(ladder) == dictionary and "transit" in ladder and "terminal" in ladder,
      message: "@rookery/cfps: kind " + repr(name) + "'s `ladder:` must be a dictionary with `transit:` "
        + "and `terminal:` arrays of stage names — got " + repr(ladder),
    )
    for k in ("transit", "terminal") {
      assert(
        type(ladder.at(k)) == array and ladder.at(k).all(n => type(n) == str),
        message: "@rookery/cfps: kind " + repr(name) + "'s ladder `" + k
          + ":` must be an array of strings — got " + repr(ladder.at(k)),
      )
    }
  }
}

// Every stage any configured kind's ladder names, so `#cfp` can reject a typo in
// `timeline:` at the call site rather than rendering a row that cannot be
// placed. The shape of the reference's `STAGES`/`SETTLED-STAGES`, folded over
// `kinds.values()` instead of a hardcoded `LADDERS`.
#let _stages(kinds) = {
  let all = ()
  for (_, spec) in kinds.pairs() { all += spec.ladder.transit + spec.ladder.terminal }
  all.dedup()
}

// ---- `venue` ------------------------------------------------------------------
//
// A venue is what durably exists: a programme, a conference series, a journal.
// It carries no dates and is not a todo — the one constructor here `#cfp`'s
// closing mechanism does not touch.
#let venue(name, title: auto, call: none, school: none, tags: none, show-tags: true, ..args) = {
  let own = (:)
  if call != none { own.insert(VENUE-CALL-KEY, call) }
  if school != none {
    own.insert(SCHOOL-KEY, if type(school) == array { school } else { (school,) })
  }
  let pos = args.pos()
  let body = if pos.len() == 0 { [] } else { pos.at(0) }
  let full = {
    _opportunity-table((("Call", call, "url"),))
    body
  }
  (tagged-idea(VENUE-KEY))(
    name,
    title: title,
    tags: own + _norm-tags-local(tags),
    show-tags: show-tags,
    ..args.named(),
    full,
  )
}

// ---- Reading what actually happened, net of `deadline`/`scheduled` ----------
//
// A cfp's own combined log also carries `deadline`/`scheduled` — the two
// reserved stage names @rookery/timeline folds into every dated note's log
// alongside whatever a call's own answer adds. Read raw, a lapsed deadline with
// nothing sent yet is the LATEST reached entry, so anything asking "what stage
// is this at" off the raw log risks reading an overdue-but-unanswered call as
// answered, or reading a real terminal stage dated BEFORE its own deadline (a
// call dropped early) as still "deadline". So the reserved names are stripped
// first, and only what is left — an actual application stage — answers either
// question.
//
// `CLOSED-STAGE` IS IN THE EXCLUSION TUPLE FROM THE START, unlike the reference
// this was ported from: this package's `#cfp` closes through the log itself
// (see `cfp` below), so its own `closed` entry would otherwise read back as the
// note's current stage, and every settled cfp would report itself "closed"
// instead of whatever it actually settled at.
#let _real-tags(tags) = {
  let real = (:)
  for e in timeline-of(tags) {
    if e.stage not in (DEADLINE-STAGE, SCHEDULED-STAGE, CLOSED-STAGE) { real.insert(e.stage, e.timestamp) }
  }
  entries(timeline: real)
}

// The stage ACTUALLY reached, net of `deadline`/`scheduled`/`closed`. `none`
// where nothing real has happened yet, whether because the log is empty or
// because only its reserved entries have been reached.
#let real-stage-of(tags, today: none) = stage-of(_real-tags(tags), today: today)

// Four states, all derived from the (stripped) timeline:
//
//   watching   the raw log is empty; nothing announced yet
//   open       every real entry is still in the future (or there are none)
//   in-flight  the latest real entry that has happened is a transit stage
//   settled    that entry is a terminal one
#let cfp-state(tags, ladder: none, today: none) = {
  if timeline-of(tags).len() == 0 { return "watching" }
  let real-tags = _real-tags(tags)
  if timeline-of(real-tags).len() == 0 { return "open" }
  let s = stage-of(real-tags, today: today)
  if s == none { return "open" }
  if ladder != none and is-settled(real-tags, ladder: ladder, today: today) { return "settled" }
  "in-flight"
}

// ---- `cfps(kinds:)` — the factory ---------------------------------------------
//
// `kinds`: kind name -> (sort: <string>, ladder: (transit: (..), terminal: (..))).
// Validated eagerly here, once, rather than on whichever `#cfp` call happens to
// hit a bad kind first.
#let cfps(kinds: (:)) = {
  _assert-kinds(kinds)
  let stages = _stages(kinds)

  // ---- `cfp` — one call, and what became of it -------------------------------
  //
  // Built on @rookery/todos' `todo(..)` rather than on bare `tagged-idea`: that
  // package already forwards `deadline:`/`scheduled:`/`timeline:` to the shared
  // log exactly as this needs, and adds `done:` — a real closing date, folded
  // into the log as a `CLOSED-STAGE` entry — and `priority:`, which this
  // constructor exposes directly rather than banning.
  //
  // `deps:`/`metadata:`/`active:`/`status:`/`type:` are deliberately NOT
  // parameters here: `todo(..)` accepts all of them, but nothing about a cfp
  // asks for @rookery/todos' dependency graph or its own todo-kind vocabulary.
  // Left at `todo(..)`'s own defaults.
  let cfp(
    name,
    venue: none,
    title: auto,
    kind: none,
    deadline: none,
    scheduled: none,
    apply: none,
    priority: none,
    timeline: none,
    work: none,
    estimated: false,
    today: none,
    tags: none,
    show-tags: true,
    ..args,
  ) = {
    assert(
      kind != none,
      message: "@rookery/cfps: #cfp(" + repr(name) + ") needs a `kind:`, one of "
        + repr(kinds.keys()) + ". Without one the call has no sort, so no ladder can "
        + "say which of its answer's stages are final — they would read as in flight "
        + "forever.",
    )
    assert(
      kind in kinds,
      message: "@rookery/cfps: #cfp's `kind` must be one of " + repr(kinds.keys())
        + " — got " + repr(kind) + ".",
    )

    let log-stages = if timeline == none { (:) } else { timeline }
    for (stage, _) in log-stages.pairs() {
      assert(
        stage in stages,
        message: "@rookery/cfps: #cfp(" + repr(name) + ")'s `timeline:` names the stage "
          + repr(stage) + ", which no configured kind's ladder carries. Add the rung to "
          + "the right kind's ladder rather than inventing one here: a stage no ladder "
          + "names renders but cannot be placed.",
      )
    }

    // `CFP-KEY` is stamped here rather than arriving from a
    // `tagged-idea(CFP-KEY)` call: this `cfp` mints through @rookery/todos'
    // `todo(..)`, which tags the note `todo`, so the bare "this is a cfp"
    // marker every consumer filters on has to be part of `own` itself.
    let own = ((VENUE-KEY + "-" + kind): none, (CFP-KEY): none)
    let venue = if venue == none { none } else { _norm(venue) }

    // THE TITLE IS COMPOSED from the venue's id, the way the reference's own
    // `#cfp` does — minus the `cycle:` half, which is not this package's
    // business (a caller builds its own cycle-aware wrapper on top of this).
    let title = if title != auto { title } else if venue == none { none } else { raw(venue) }

    own.insert(CFP-ID-KEY, name)
    if venue != none { own.insert(CFP-VENUE-KEY, venue) }
    if apply != none { own.insert(APPLY-KEY, apply) }
    if work != none { own.insert(WORK-KEY, work) }
    if estimated { own.insert(ESTIMATED-KEY, none) }

    let ladder = kinds.at(kind).ladder
    let pos = args.pos()
    let body = if pos.len() == 0 { [] } else { pos.at(0) }

    // `today:` resolves HERE, inside the one `context` block this note needs —
    // for `target()`, exactly as the reference's own rail does — rather than a
    // second one. `close-on` is computed in the same block, since it also needs
    // a "now" to test `lapsed` against, and the whole note is minted from inside
    // it so that `done:` carries the resolved value rather than an unresolved
    // fallback.
    context {
      let resolved-today = _resolve-today(today)
      let t = entries(deadline: deadline, scheduled: scheduled, timeline: timeline)

      // THE CLOSE DATE, not a bool. The earliest REAL (non-reserved) answer if
      // one exists — the day applying stopped being outstanding work — else the
      // deadline itself if that has lapsed with nothing sent, else `none` (still
      // open work).
      let lapsed = deadline != none and resolved-today > deadline
      let real-dates = log-stages
        .pairs()
        .map(p => {
          let v = p.at(1)
          if type(v) == datetime { v } else { v.at("timestamp", default: none) }
        })
        .filter(d => d != none)
      let close-on = if real-dates.len() > 0 {
        real-dates.sorted().first()
      } else if lapsed {
        deadline
      } else { none }

      // THE RAIL — the WHOLE combined log, `deadline`/`scheduled` included, in
      // the order it actually happened, rather than treating the wire as a fact
      // stated elsewhere. HTML only: `html.elem` means nothing on a paged
      // target, where `timeline-view` renders its own list.
      let rail = {
        if target() == "html" and timeline-of(t).len() > 0 {
          html.elem("p", attrs: (class: "idea-timeline-head"), "Timeline")
        }
        timeline-view((:), t, today: resolved-today, ladder: ladder)
      }

      // ORDER: the table, then the rail, then the prose, then the venue
      // backlink — the fixed facts first, the story of what happened next,
      // then the commentary on both.
      let full = {
        _opportunity-table((("Work", work, "path"),))
        rail
        parbreak()
        body
        if venue != none {
          parbreak()
          ref(label("idea:" + venue))
        }
      }

      todo(
        name,
        title: title,
        deadline: deadline,
        scheduled: scheduled,
        timeline: timeline,
        done: close-on,
        priority: priority,
        tags: own + _norm-tags-local(tags),
        show-tags: show-tags,
        ..args.named(),
        full,
      )
    }
  }

  (venue: venue, cfp: cfp, cfp-state: cfp-state)
}
