// @rookery/cfps — the rounds table: one row per call, `when | title | school |
// verdict`, in date order.
//
// Ported from the reference site's own `#cfps` panel, minus the vocabulary that
// belongs to that SITE rather than to a venue/cfp pair: no `sort:` (the site's own
// job/conference/journal split), no `cycle:` (a caller's own tagging convention,
// reached instead through `tags:` below), and no `HIDDEN-STAGES` filtering (that
// belongs to `@rookery/todos`' `#window`, a different package).
//
// `CFP-KEY` IS THE ROW FILTER — the bare marker `#cfp` stamps on every note it
// mints (`cfp.typ`'s `own`). It cannot come from an `idea(CFP-KEY)` call, since
// a cfp mints through @rookery/todos' `todo(..)`, so the two halves of this
// package meet on that one key.

#import "cfp.typ": *
#import "@rookery/core:0.1.0": ideas
#import "@rookery/timeline:0.1.0": deadline-of, scheduled-of
#import "@rookery/todos:0.1.0": priority-of, priority-rung

// The reference date is always an explicit `today:` argument (a private copy of
// `cfp.typ`'s own `_resolve-today` — Typst has no wall clock, so there is nothing
// to fall back to).
#let _resolve-today(today) = {
  assert(
    type(today) == datetime,
    message: "@rookery/cfps: #panel needs a reference date — pass one explicitly, "
      + "e.g. `today: datetime(year: 2026, month: 8, day: 25)`. Got " + repr(today),
  )
  today
}

// `tags:` narrows a panel to whatever grouping the CALLER's site wants (a cycle, a
// kind not already filtered by `state:`, anything else its own tagging convention
// names) — `none`, one tag name, or an array of them, the same three forms
// `#ideas`' own `tags:` accepts.
#let _as-tag-array(tags) = {
  if tags == none {
    ()
  } else if type(tags) == str {
    (tags,)
  } else if type(tags) == array {
    tags
  } else {
    panic("@rookery/cfps: panel's `tags:` must be none, a string, or an array of tag names — got " + repr(tags))
  }
}

// THE NEXT THING DUE on a note's own log, whatever rung it sits on — the date a
// round row shows once something has answered its call. A call's own deadline is
// the useful date right up until a submission exists; after that it is what the
// attempt itself still waits on (a revision, a resubmission, a booked interview),
// which is why this asks the whole log for its next unpassed entry rather than
// naming one stage. `none` where nothing is still ahead — a settled attempt has
// nothing outstanding, which is the honest reading.
#let _next-open-date(tags, today: none) = {
  if today == none { return none }
  let ahead = timeline-of(tags).filter(e => e.timestamp > today)
  if ahead.len() == 0 { none } else { ahead.first().timestamp }
}

#let _fmt-date(d) = d.display("[day padding:none] [month repr:short] [year]")

// A venue's title/href and its schools' labels, by venue NAME — one pass over
// `ideas(values: true)`, cached in a dictionary, rather than a lookup per row.
// The join this package owns is cfp -> venue -> schools; kind/sort/dates stay on
// the cfp's own row, exactly as the ontology already splits them.
#let _venue-index(all) = {
  let by-name = all.map(r => (r.name, r)).to-dict()
  let school-of(name) = {
    let s = by-name.at(name, default: none)
    if s == none { none } else { (label: s.label, href: s.href) }
  }
  name => {
    let v = by-name.at(name, default: none)
    if v == none {
      (title: none, href: none, schools: ())
    } else {
      (
        title: v.label,
        href: v.href,
        schools: v.tags-dict.at(SCHOOL-KEY, default: ()).map(school-of).filter(x => x != none),
      )
    }
  }
}

// The `panel:` method `cfps(kinds:)` returns — bound to the SAME `kinds`/ladder
// configuration the factory's `cfp` resolves against, so a row's ladder never
// disagrees with the note it was minted with.
#let _make-panel(kinds) = {
  let panel(tags: none, state: "open", countdown: false, empty: [Nothing here.], today: none) = context {
    let resolved-today = _resolve-today(today)
    let want-state = if type(state) == array { state } else { (state,) }
    let want = (CFP-KEY,) + _as-tag-array(tags)

    let all = ideas(values: true)
    let venue-of = _venue-index(all)

    let words(s) = s.replace("-", " ")

    let rows = ideas(tags: want, match: "all", values: true)
      .map(r => {
        let t = r.tags-dict
        let kind = kinds.keys().find(k => (VENUE-KEY + "-" + k) in t)
        let ladder = if kind == none { none } else { kinds.at(kind).ladder }
        let dl = deadline-of(t)
        let sch = scheduled-of(t)
        // WHAT HAS ACTUALLY BEEN ANSWERED, net of the reserved stage names — see
        // `real-stage-of`'s own comment in `cfp.typ` for why the raw log cannot
        // answer this.
        let rs = real-stage-of(t, today: resolved-today)
        let answered = rs != none
        let nxt = _next-open-date(t, today: resolved-today)
        let st = cfp-state(t, ladder: ladder, today: resolved-today)
        let venue-name = t.at(CFP-VENUE-KEY, default: none)
        let v = if venue-name == none { (title: none, href: none, schools: ()) } else { venue-of(venue-name) }
        (
          label: r.label,
          target: r.href,
          schools: v.schools,
          kind: kind,
          stage: rs,
          // The call's own priority — how much it matters, unchanged by what has
          // been sent.
          priority: priority-of(t),
          // Unanswered: the call's own wire. Answered: only what is still
          // outstanding.
          when: if answered { nxt } else if dl != none { dl } else { sch },
          firm: if answered { nxt != none } else { dl != none },
          state: st,
          settled-stage: if st == "settled" { rs } else { none },
          transit-stage: if st == "in-flight" { rs } else { none },
          tags-dict: t,
          work: t.at(WORK-KEY, default: none),
        )
      })
      .filter(r => want-state.contains(r.state))

    // A plain string sort in date order, undated rows falling to the end.
    let dated = rows.filter(r => r.when != none)
    let undated = rows.filter(r => r.when == none)
    let rows = dated.sorted(key: r => r.when) + undated

    // The rung ramp is relative to what's actually on THIS page: the distinct
    // non-zero priorities among these rows, largest (most important) first.
    let scale = rows.map(r => r.priority).filter(p => p > 0).dedup().sorted().rev()

    // PAGED: no anchor to click and no grid to align, so the rows become a plain
    // Typst list.
    if target() != "html" {
      if rows.len() == 0 { return text(gray, emph(empty)) }
      return list(
        ..rows.map(r => {
          let d = r.when
          if d != none { [#_fmt-date(d)#if not r.firm { [ (expected)] } — ] }
          r.label
          if r.schools.len() > 0 { [ #text(gray, "[" + r.schools.map(s => s.label).join(", ") + "]")] }
          let parts = (r.kind, r.stage).filter(s => s != none).map(words)
          if parts.len() > 0 { [ #text(gray, "(" + parts.join(", ") + ")")] }
          if r.work != none { [ #text(gray, "→ " + r.work)] }
        }),
      )
    }

    if rows.len() == 0 {
      return html.elem("p", attrs: (class: "round-empty"), empty)
    }

    // The state rides on the list because one rule needs it: the first row's date
    // is lit only in the open group, where the top row is either next or already
    // overdue.
    let list-cls = (("round-list",) + want-state.map(s => "round-list-" + s)).join(" ")
    html.elem(
      "ul",
      attrs: (class: list-cls),
      rows
        .map(r => html.elem(
          "li",
          attrs: (
            // `submission-estimated` is what dims a row, read straight off the
            // call's own tags. The kind rides on the CHIP rather than the row,
            // because a themed tag's colour is a custom property and a custom
            // property inherits — with the kind's class on the row, a rejected
            // chip would come out tenure-track orange.
            class: (("round-row",) + r.tags-dict.keys().map(k => "idea-tag-" + k)).join(" "),
          ),
          {
            let d = r.when
            // THE COUNTDOWN IS THE DATE CELL, not a fifth thing beside it — see
            // `cfps.css`'s own comment on `.round-when[data-countdown]` for why.
            // Three weeks, seven steps, two per hue past the overdue one.
            let band = if not countdown or d == none { none } else {
              let days = (d - resolved-today).days()
              if days < 0 { "overdue" } else if days <= 3 { "imminent" } else if days <= 7 { "urgent" } else if (
                days <= 11
              ) { "soon" } else if days <= 14 { "near" } else if days <= 18 { "approaching" } else if days <= 21 {
                "distant"
              } else { none }
            }
            let phrase = if band == none { none } else {
              let days = (d - resolved-today).days()
              if days == -1 { "yesterday" } else if days < 0 { str(-days) + " days ago" } else if days == 0 {
                "today"
              } else if days == 1 { "tomorrow" } else { "in " + str(days) + " days" }
            }
            // PRIORITY, only where the countdown has nothing to say — a call
            // three weeks or more out never earns a band above, so this closes
            // that gap on the same date cell rather than a second one.
            let rung = priority-rung(r.priority, scale, rungs: 5)
            let pri-band = if band != none or d == none or rung == none { none } else {
              "rung-" + str(rung)
            }
            let phrase = if phrase != none { phrase } else if pri-band == none { none } else {
              "priority " + str(r.priority)
            }
            let when-cls = (
              ("round-when",)
                + (if r.firm { () } else { ("soft",) })
                + (
                  if band != none { ("round-when-" + band,) } else if pri-band != none {
                    ("round-when-" + pri-band,)
                  } else { () }
                )
            ).join(" ")
            let when-attrs = if phrase == none { (:) } else {
              (
                "data-countdown": phrase,
                "aria-label": _fmt-date(d) + ", " + phrase,
                "tabindex": "0",
              )
            }
            html.elem(
              "span",
              attrs: (class: when-cls) + when-attrs,
              if d == none { [—] } else {
                html.elem("time", attrs: (datetime: d.display("[year]-[month]-[day]")), _fmt-date(d))
              },
            )
            html.elem("span", attrs: (class: "round-title"), {
              if r.target == none { r.label } else {
                html.elem("a", attrs: (href: r.target), r.label)
              }
            })
            // Its own column: a school is a fact a reader scans down for, not a
            // clause folded into the title.
            html.elem(
              "span",
              attrs: (class: "round-school"),
              r
                .schools
                .map(s => if s.href == none { s.label } else { html.elem("a", attrs: (href: s.href), s.label) })
                .join([ \/ ]),
            )
            // The verdict cell: a stage and an outcome are one vocabulary split
            // by the ladder — the transit rung is the qualifier, the terminal one
            // the answer. Each badge is a rookery tag chip (`idea-tag` +
            // `idea-tag-<name>`), so a themed name colours itself the same way
            // any other pill on a note's hat does.
            if r.kind != none or r.stage != none {
              html.elem("span", attrs: (class: "round-verdict"), {
                if r.kind != none {
                  html.elem(
                    "span",
                    attrs: (class: "round-badge idea-tag idea-tag-" + VENUE-KEY + "-" + r.kind),
                    r.kind,
                  )
                }
                if r.transit-stage != none {
                  html.elem(
                    "span",
                    attrs: (class: "round-badge round-badge-stage idea-tag idea-tag-" + r.transit-stage),
                    words(r.transit-stage),
                  )
                }
                if r.settled-stage != none {
                  html.elem(
                    "span",
                    attrs: (class: "round-badge round-badge-outcome idea-tag idea-tag-" + r.settled-stage),
                    words(r.settled-stage),
                  )
                }
              })
            }
            if r.work != none {
              html.elem("span", attrs: (class: "round-match"), raw(r.work))
            }
          },
        ))
        .join(),
    )
  }
  panel
}
