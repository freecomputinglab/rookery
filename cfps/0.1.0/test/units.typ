// Unit fixture: every VALUE `@rookery/cfps` derives — `cfp-state`/`real-stage-of`'s
// four-state ladder logic against hand-built tag dictionaries, the tags `#cfp`
// stamps in its own `own` dictionary, and that closing goes through the shared
// timeline log rather than a flat flag. No runner: an `assert` failing fails the
// compile with a line number, and a passing compile is the green light. The
// MARKUP `#cfp`/`#venue`/`panel:` draw is `test/view.typ`'s business, which needs
// an HTML target this one does not.
//
// One case from the list below is NOT here: "a `kind:` outside `kinds:` fails
// loudly" cannot be asserted inside this file, because a failing `assert`/`panic`
// aborts the whole compile rather than being catchable — Typst has no try/catch.
// `test/check.sh` covers it instead, as a second `typst compile` invocation this
// package EXPECTS to fail, with its stderr checked for the valid-kinds message.
#import "/src/lib.typ": *
#import "@rookery/core:0.1.0": rookery, tag-data
#import "@rookery/timeline:0.1.0": CLOSED-STAGE, entries, has-stage

#show: rookery

#let TODAY = datetime(year: 2026, month: 6, day: 15)
#let day(n) = datetime(year: 2026, month: 1, day: n)

#let JOB-LADDER = (transit: ("submitted", "interview"), terminal: ("offered", "rejected"))
#let JOURNAL-LADDER = (transit: ("submitted", "review-*"), terminal: ("accepted", "desk-rejected"))
#let KINDS = (
  job: (sort: "job", ladder: JOB-LADDER),
  journal: (sort: "journal", ladder: JOURNAL-LADDER),
)

// `cfp-state`/`real-stage-of` are pure functions of a tag dictionary and a
// ladder — neither needs a `#cfp` mint, so the four cases below build the log
// straight with `entries()`, the way `cfp.typ`'s own header worked out the bug
// each one guards.

// 1. A lapsed, unanswered call reads as "open", never "in-flight" — reading the
//    RAW log would call this "in-flight" because the deadline is the latest
//    reached entry and belongs to no ladder's terminal list.
#let lapsed-tags = entries(deadline: day(1))
#assert.eq(
  cfp-state(lapsed-tags, ladder: JOB-LADDER, today: TODAY),
  "open",
  message: "a lapsed, unanswered call did not read as open",
)

// 2. A stage dated BEFORE the deadline is still detected. Raw `stage-of` would
//    pick the deadline itself, at day 10 — the latest entry that has passed —
//    and silently mask the real answer dated day 5.
#let early-answer-tags = entries(deadline: day(10), timeline: (dropped: day(5)))
#assert.eq(
  real-stage-of(early-answer-tags, today: day(15)),
  "dropped",
  message: "a real answer dated before the deadline was masked by it",
)

// 3. `venue:` is optional on `#cfp` — a cfp naming no venue still builds
//    successfully (the assertions below would not run at all had minting
//    panicked) and stamps no `CFP-VENUE-KEY`, rather than crashing reading a
//    `none` venue as a title fallback.
#let cfp = cfps(kinds: KINDS).cfp
#cfp("no-venue-unit", kind: "job", deadline: day(20), today: TODAY)[No venue named.]
#context {
  let t = tag-data().at("idea:no-venue-unit")
  assert(CFP-VENUE-KEY not in t, message: "a cfp with no venue stamped a venue key anyway")
}

// 4. See the file header: a bad `kind:` is `test/check.sh`'s job, not this
//    file's — it cannot be asserted inside a compile it would abort.

// 5. Every stage in every configured kind's ladder is standardized. For EACH
//    name in EACH kind's `transit`/`terminal` (a `-*` family rung expanded to a
//    concrete instance, e.g. `review-1`), mint a `#cfp` whose `timeline:` uses
//    only that stage and check it does not raise (the mint itself is the check —
//    a stage the `stage in STAGES` guard rejects would panic here) and that
//    `cfp-state` reads it as the right half of the ladder. This is what would
//    catch a stage falling through to some path other than `@rookery/timeline`'s
//    own — a per-kind flat tag, a bespoke `outcome:` argument, anything that
//    records a stage somewhere other than the shared log.
#let expand(pattern) = if pattern.ends-with("-*") { pattern.slice(0, pattern.len() - 1) + "1" } else { pattern }

#for (kind-name, spec) in KINDS.pairs() {
  for (bucket, want-state) in (("transit", "in-flight"), ("terminal", "settled")) {
    for pattern in spec.ladder.at(bucket) {
      let stage = expand(pattern)
      let name = "ladder-" + kind-name + "-" + stage
      let tl = (:)
      tl.insert(stage, day(1))
      cfp(name, kind: kind-name, timeline: tl, today: day(1))[Ladder coverage.]
      context {
        let t = tag-data().at("idea:" + name)
        assert.eq(
          cfp-state(t, ladder: spec.ladder, today: day(1)),
          want-state,
          message: "stage " + repr(stage) + " of " + repr(kind-name) + "'s " + bucket + " did not read as " + want-state,
        )
      }
    }
  }
}

// 6. Closing is real, not a flag — both a settled cfp and a merely-lapsed one
//    (deadline behind us, nothing ever sent) must show `has-stage(.., CLOSED-STAGE)`
//    true on their OWN minted tags, because `@rookery/todos`' `is-closed` (and
//    everything built on it, like a consumer's `today-panel`) reads exactly that
//    entry, not a flat boolean this package could get away with faking.
#cfp(
  "closing-settled",
  kind: "job",
  deadline: day(1),
  timeline: (submitted: datetime(year: 2025, month: 12, day: 1), offered: day(10)),
  today: TODAY,
)[Answered and settled.]
#cfp("closing-lapsed", kind: "job", deadline: day(1), today: TODAY)[Lapsed, nothing sent.]
#context {
  for name in ("closing-settled", "closing-lapsed") {
    let t = tag-data().at("idea:" + name)
    assert(
      has-stage(t, CLOSED-STAGE),
      message: name + " did not close through the shared timeline log",
    )
  }
}
