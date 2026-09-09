---
id: rk-add-today-panel-a-day-view-over-todos-4803a6b6
short-id: '480'
title: 'Add #today-panel, a day view over todos'
priority: 3
labels:
- today-panel
- type:feature
deps:
- blocked-by:rk-rename-filter-panel-to-todo-table-9971e639
- blocked-by:rookery-priority-tests-hax
closed: false
---
`@rookery/todos` has one view, `#todo-table`, and it lists EVERYTHING open, ordered by date. That is the right shape for a worklist and the wrong shape for the question a person asks at the start of a day: what is on for today, and what is the most important thing outstanding. Answering it today means reading a list of several hundred rows.

Add `#today-panel` — the same table, over a much smaller selection: the todos dated for today, plus the todos at the site's topmost priority whatever their date.

It is a SELECTION and nothing else. The projection, the pills, the date-cell ramp and the row rendering all come from `#todo-table`, which is `@rookery/todos`' existing view — renamed from `#filter-panel` and given a `corpus:` argument by bird rk-rename-filter-panel-to-todo-table-9971e639 ("Rename #filter-panel to #todo-table"). After that bird it lives in `/home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ` and takes `rows:` (the rows to list), `corpus:` (every todo, so the dependency graph can resolve a closed blocker), `filter:`, `today:`, and the panel knobs `facets`, `tag-filter`, `pill-rows`, `when`, `order`, `countdown`, `overdue`, `undated-priority`, `visible`, `placeholder`, `noun`, `empty`, `haystack`, `render`.

All paths are under `/home/lox/code/_fcl/rookery/todos/0.1.0/`.

## The facts you need, restated so you need no other file

**The priority scale.** `priority:` is a non-negative integer with NO upper bound. A BIGGER number is MORE important. An absent priority decodes to `0`, meaning unprioritised — `priority-of` (`src/tags.typ:251`) never returns `none`, and every row from `todos()` (`src/graph.typ:30-48`) carries an integer `priority` field. So "the topmost priority" is the MAXIMUM priority in use, and `0` is never a top priority.

**The three date predicates already exist**, in `@rookery/timeline`'s `src/when.typ`, and this bird writes no new date logic:

- `is-upcoming(tags, today: none, within: 7)` (when.typ:69) — has a deadline falling from `today` up to and including `within` days later. `within: 0` asks "due today". An already-overdue deadline is NOT upcoming.
- `is-overdue(tags, today: none)` (when.typ:59) — has a deadline STRICTLY before `today`. A deadline falling on `today` is due, not overdue.
- `is-scheduled-now(tags, today: none)` (when.typ:90) — is scheduled, and that date has arrived, on or before `today`. This is the "may I start" question. It deliberately covers a todo scheduled last Tuesday and never done, which is exactly right for a day view: an old scheduled date does not stop being today's problem.

All three take the note's tag dictionary, which every `todos()` row carries as `r.tags-dict`.

**They need a reference date.** Nothing in this stack may call `datetime.today()` — it returns 1980-01-01 under a reproducible build and does not error. These predicates fall back to the document's own date and PANIC when there is neither, so `today:` is effectively required.

## Steps

1. Create `src/today.typ` with a file header in this repo's comment style — present tense, describing what the file is, one header and no interior banners, no issue ids (see `/home/lox/code/_fcl/rookery/CLAUDE.md`). What it says: the day view is a SELECTION over `#todo-table`, and the questions it unions — what is dated for today, and what is most important — are different questions that a person starting a day asks together.

2. Import what it needs: `#import "table.typ": *`, `#import "graph.typ": *` (for `todos`), and `#import "@rookery/timeline:0.1.0": is-overdue, is-scheduled-now, is-upcoming`.

3. Define the two PURE helpers first, so the selection is testable without rendering anything:

   ```
   #let _top-priority(rows) = {
     let ps = rows.map(r => r.priority).filter(p => p > 0)
     if ps.len() == 0 { none } else { calc.max(..ps) }
   }

   #let _on-today(row, today: none, horizon: 0, overdue: true, top: none, also: none) = {
     let t = row.tags-dict
     ((also != none and also(row))
       or is-upcoming(t, today: today, within: horizon)
       or (overdue and is-overdue(t, today: today))
       or is-scheduled-now(t, today: today)
       or (top != none and row.priority >= top))
   }
   ```

   Comment `_top-priority` with the decision behind it: the band is derived from the rows the panel is ABOUT TO LIST, not from the whole rookery, because a closed todo at priority 9 would otherwise set a band that no open row can reach and the priority half of the panel would come out empty.

4. Define `#today-panel`. Document every parameter in the style `#todo-table` uses (`src/table.typ`, the parameter list running from its `#let` down to its `) = context {`) — a paragraph per argument saying what it does and why the default is the default, not a one-line gloss:

   ```
   #let today-panel(
     rows: none,
     today: none,
     filter: none,
     also: none,
     horizon: 0,
     overdue: true,
     priority: auto,
     facets: ("epic", "tag", "state", "priority"),
     tag-filter: none,
     pill-rows: <the same default literal #todo-table declares>,
     when: none,
     order: "soonest",
     countdown: true,
     undated-priority: true,
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
       corpus: all,
       filter: r => true,
       today: today,
       overdue: overdue,
       ..<every remaining knob, passed straight through>
     )
   }
   ```

   Two of those arguments need a comment where they are passed, because both look redundant and neither is:

   - `corpus: all` — `#todo-table` builds the dependency graph from what it is given, and a graph built from the day's handful of rows cannot see their blockers, which `is-blocked` reads as "not blocking". Without this every row in the panel would come out `ready`.
   - `filter: r => true` — the selection has already happened above. `#todo-table`'s own `filter:` defaults to dropping closed rows, and letting it run again would apply the site's question twice.

   The four arguments that are this function's own, and what their documentation must say:

   - `horizon: 0` — how many days past today still count as "for today", passed to `is-upcoming`'s `within:`. `0` is due today exactly. A site that plans in two-day chunks passes `2`. It does NOT affect the scheduled or priority halves.
   - `overdue: true` — whether a deadline already behind you is listed. `true` lists it, and `#todo-table` paints its date cell the overdue band. `false` drops it. On by default: a day view that silently hides what is late is worse than no day view.
   - `priority: auto` — which todos join the list on importance alone, regardless of date. `auto` (the default) is the topmost priority actually in use among the listed rows. An integer is a floor: every row at that priority or above. `none` turns the priority half off entirely, leaving a plain "dated for today" list.
   - `also: none` — a predicate over a row that ORs INTO the day's selection, where `filter:` narrows it. It is what lets a site put a todo on today's list for a reason this package cannot know: the consuming site `/home/lox/code/waterline` has a hand-set `today` tag (`_lib/template.typ:36`) meaning "this is on for today whatever its dates say", and without `also:` there is no way to honour it — every other argument here can only ever remove rows. `none` is no extra rows.

   `filter:` and `also:` are not the same knob in two directions and the documentation must say so: `filter:` decides which todos EXIST for this panel (open, not answered, whatever the site means by live), and it applies to every row including the ones `also:` brings in.

   `visible: none` rather than `#todo-table`'s `8`: a day view is meant to be read whole, and a scroll box over a list of six rows hides the sixth behind a gesture nothing advertises.

5. Add `#import "today.typ": *` to `src/lib.typ`, immediately after the `#import "table.typ": *` line, with a short comment in that file's own idiom saying it comes after the module it projects, for the same dependency-order reason the rest of that list is ordered. Do not disturb the existing order — `skin.typ` must stay LAST, because it is what shadows `window`.

6. Add assertions to `test/units.typ`, beside the other pure-helper fixtures. Test `_top-priority` and `_on-today` — not the panel, which needs a rendering context. You will need to reach the two helpers; `test/units.typ` already imports this package's internals, so follow whatever import form the file uses for `_state-of` or another underscore-prefixed helper. Cases:

   - `_top-priority(())` is `none`.
   - `_top-priority` over rows with priorities `(0, 0)` is `none` — unprioritised is not a top priority.
   - `_top-priority` over `(0, 3, 7, 3)` is `7`.
   - `_on-today` is `true` for a row whose deadline IS today, with `horizon: 0`.
   - `_on-today` is `false` for a row whose deadline is tomorrow, with `horizon: 0`, and `true` for the same row with `horizon: 1`.
   - `_on-today` is `true` for a row with a deadline a week behind today when `overdue: true`, and `false` for that same row when `overdue: false` and it has nothing else qualifying it.
   - `_on-today` is `true` for a row scheduled a month ago and still open.
   - `_on-today` is `false` for a row scheduled next month with no deadline and a priority below `top`.
   - `_on-today` is `true` for an undated row whose priority equals `top`, and `false` for an undated row one below `top`.
   - `_on-today` is `true` for an undated, unprioritised row when `also:` returns `true` for it, and `false` for that same row when `also:` is `none`.

   Build the fixture rows the way the existing fixtures in that file build theirs — a dictionary with `tags-dict` and `priority` is all `_on-today` reads. Dates come from `@rookery/timeline`'s `entries(deadline: ..)` / `entries(scheduled: ..)`, which is how the demo content writes them.

## Do NOT

- Do not write any new date arithmetic. The three predicates above are the whole of it, and a second copy of "is this today" is exactly how two surfaces drift apart.
- Do not change `src/table.typ`, `src/views.typ`, `src/graph.typ` or `src/todos.css`. `#today-panel` reuses the table's existing classes (`todo-when-overdue`, the countdown bands, the priority label cell) and needs no new CSS.
- Do not add a heading, a count line, or any chrome of its own. `#todo-table` renders the whole widget.
- Do not use `priority-scale()` from `src/graph.typ` even though it computes a similar list. It walks the WHOLE rookery including closed todos, and this panel's band must come from the rows it is listing — see the comment step 3 asks for.
- Do not touch `readme.md` or the demo. Documenting and demoing `#today-panel` is a separate bird.

## VERIFY

From `/home/lox/code/_fcl/rookery/todos/0.1.0`:

1. `just test` passes, with the new assertions in it. An `assert` that fails fails the compile with a line number, so a clean compile is the green light.
2. `just check` passes.
3. In a scratch `.typ` file compiled against this package, `#today-panel(today: datetime(year: 2026, month: 8, day: 25))` over the demo's own corpus renders a panel containing the overdue `invoice` todo and NOT the `retro` todo, which is scheduled for December.
4. The same call with `priority: none` renders a strictly smaller list than with `priority: auto`, and with `overdue: false` drops the `invoice` row.
5. In that same scratch file, a todo BLOCKED by an open dependency shows the `blocked` state pill in the today panel, not `ready`. That is `corpus:` doing its job — if every row reads `ready`, it is not being passed.
