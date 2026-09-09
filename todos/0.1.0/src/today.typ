// `#today-panel` — a day view over `@rookery/todos`, the same widget as
// `#todo-table` over a much smaller selection.
//
// `#todo-table` lists EVERYTHING open, ordered by date — the right shape for
// a worklist and the wrong shape for the question a person asks at the start
// of a day: what is on for today, and what is the most important thing
// outstanding regardless of its date. Those are two different questions that
// get asked together, and this file is nothing but the SELECTION that
// answers both at once. The projection, the pills, the date-cell ramp and the
// row rendering all stay `#todo-table`'s; this file draws nothing of its own.

#import "table.typ": *
#import "graph.typ": *
#import "@rookery/timeline:0.1.0": is-overdue, is-scheduled-now, is-upcoming

// THE BAND THE PRIORITY HALF OF THE SELECTION DRAWS FROM: the highest
// priority actually carried by the rows this panel is choosing FROM — its
// open corpus, not the "on today" list the selection is about to produce,
// which would make the band depend on its own result. Deliberately NOT
// `priority-scale()` (`graph.typ`), which walks the WHOLE rookery including
// closed todos: a closed todo at priority 9 would then set a band no open
// row could ever reach, and the priority half of the panel would come out
// silently empty even on a site with plenty of important open work.
#let _top-priority(rows) = {
  let ps = rows.map(r => r.priority).filter(p => p > 0)
  if ps.len() == 0 { none } else { calc.max(..ps) }
}

// IS THIS ROW ON FOR TODAY. Five independent reasons, ORed together, and a
// row needs only one: `also` (a reason only the calling site can know),
// `is-upcoming` (a deadline landing within `horizon` days), `is-overdue`
// (gated by `overdue`), `is-scheduled-now` (a scheduled date that has
// arrived, however long ago), or a priority at or above `top`. `top: none`
// turns that last clause off outright rather than comparing a real priority
// against nothing.
#let _on-today(row, today: none, horizon: 0, overdue: true, top: none, also: none) = {
  let t = row.tags-dict
  ((also != none and also(row))
    or is-upcoming(t, today: today, within: horizon)
    or (overdue and is-overdue(t, today: today))
    or is-scheduled-now(t, today: today)
    or (top != none and row.priority >= top))
}

#let today-panel(
  // Pre-computed rows, in `todos()` shape — the same meaning `#todo-table`'s
  // own `rows:` carries. `none` (the default) walks the registry itself,
  // which is what a page wanting "today, across every open todo there is"
  // means.
  rows: none,
  // The reference date `is-upcoming`/`is-overdue`/`is-scheduled-now` (and
  // `#todo-table` underneath) resolve "today" against. NOTHING IN THIS
  // PACKAGE MAY CALL `datetime.today()` — it returns 1980-01-01 under a
  // reproducible build and does not error while doing it — so with no
  // `today:` these predicates fall back to the document's own date and
  // panic where there is neither, which makes `today:` effectively
  // required for a day view to mean anything.
  today: none,
  // WHICH TODOS EXIST FOR THIS PANEL, before the day's question is even
  // asked — open, not answered, whatever the site means by "still live".
  // The default drops closed todos, the only default that is ever right: a
  // closed todo is not outstanding work. It applies to EVERY row this panel
  // could show, including the ones `also:` brings in below — `also:` can
  // only choose among the rows `filter:` left standing, never resurrect one
  // it already dropped.
  filter: none,
  // A predicate over a row that ORs INTO the day's selection, where
  // `filter:` narrows it instead. It is the one hole this package cannot
  // fill for itself: a site may have a reason a todo belongs on today's
  // list that no date or priority captures — a hand-set tag meaning "on for
  // today whatever the dates say", say — and every other argument here can
  // only ever REMOVE rows from the selection. `none` (the default) adds
  // none.
  also: none,
  // How many days past today still count as "for today", passed straight to
  // `is-upcoming`'s `within:`. `0` (the default) is due today exactly; a
  // site that plans in two-day chunks passes `2`. It reaches only the dated
  // half of the selection and does not widen the scheduled or priority
  // halves.
  horizon: 0,
  // Whether a deadline already behind you is listed at all. `true` (the
  // default) lists it, and `#todo-table` paints its date cell the overdue
  // band underneath; `false` drops it from the selection outright. On by
  // default: a day view that silently hides what is already late is worse
  // than no day view.
  overdue: true,
  // Which todos join the list on importance alone, regardless of date.
  // `auto` (the default) is the topmost priority actually in use among the
  // rows this panel is choosing from — see `_top-priority`. An integer
  // floors it explicitly: every row at that priority or above joins,
  // whatever `auto` would have picked. `none` turns the priority half off
  // entirely, leaving a plain "dated for today" list.
  priority: auto,
  // `#todo-table`'s own knobs from here down, forwarded unchanged — same
  // names, same defaults, same meaning. A day view changes nothing about
  // how a row is projected or drawn, only which rows reach it; see
  // `table.typ` for what each one draws and why its default is its default.
  facets: ("epic", "tag", "state", "priority"),
  tag-filter: none,
  pill-rows: (
    (label: [epic:], facets: ("epic",)),
    (facets: ("tag",)),
    (label: [todo states:], facets: ("state", "priority")),
  ),
  when: none,
  order: "soonest",
  countdown: true,
  undated-priority: true,
  // `none` here, where `#todo-table` defaults to `8`: a day view is meant to
  // be read whole, not scrolled — a box over a list of six rows hides the
  // sixth behind a gesture nothing on the page advertises.
  visible: none,
  placeholder: "Filter today",
  noun: "todos",
  empty: [Nothing for today.],
  haystack: none,
  render: none,
) = context {
  let all = if rows != none { rows } else { todos() }
  let keep = if filter != none { filter } else { r => not r.closed }
  let open = all.filter(keep)
  let top = if priority == none { none } else if priority == auto {
    _top-priority(open)
  } else { priority }
  todo-table(
    rows: open.filter(r => _on-today(
      r, today: today, horizon: horizon, overdue: overdue, top: top, also: also,
    )),
    // THE GRAPH IS BUILT FROM `all`, not from the day's narrow selection:
    // `#todo-table` builds the dependency graph from whatever `corpus:` it
    // is given, and a graph built from a handful of rows cannot see a
    // blocker sitting outside them — which `is-blocked` reads as "not
    // blocking", quietly promoting a blocked todo to ready.
    corpus: all,
    // THE SELECTION HAS ALREADY HAPPENED ABOVE, in `rows:`. `#todo-table`'s
    // own `filter:` defaults to dropping closed rows, and letting it run
    // again here would apply this file's own question — which todos are
    // "on for today" — a second time, against rows that already answered
    // it.
    filter: r => true,
    today: today,
    facets: facets,
    tag-filter: tag-filter,
    pill-rows: pill-rows,
    when: when,
    order: order,
    countdown: countdown,
    overdue: overdue,
    undated-priority: undated-priority,
    visible: visible,
    placeholder: placeholder,
    noun: noun,
    empty: empty,
    haystack: haystack,
    render: render,
  )
}
