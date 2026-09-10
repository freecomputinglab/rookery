---
id: rk-document-and-demo-today-panel-64f66afe
short-id: '6'
title: 'Document and demo #today-panel'
priority: 2
labels:
- today-panel
- type:task
deps:
- blocked-by:rk-add-today-panel-a-day-view-over-todos-4803a6b6
- blocked-by:rookery-priority-docs-dnu
closed: true
---
`#today-panel` is added to `@rookery/todos` by bird rk-add-today-panel-a-day-view-over-todos-4803a6b6 ("Add #today-panel, a day view over todos") and is undocumented and undemoed when that bird lands. This bird gives it a readme section, a worked demo, and an output assertion — the three things every other view in this package has.

`#today-panel` lists a much smaller set than `#todo-table`, the package's general view: the todos dated for today, plus the todos at the site's topmost priority whatever their date. Its own arguments are `horizon:` (how many days past today still count as today, `0` by default, meaning due today exactly), `overdue:` (whether a deadline already behind you is listed, `true` by default), `priority:` (`auto` for the topmost priority actually in use among the listed rows, an integer for "that priority or above", `none` to turn the priority half off), and `also:` (a predicate that ORs extra rows IN, where `filter:` narrows). It takes `today:`, `rows:`, `filter:` and the same panel knobs `#todo-table` takes, and it renders through `#todo-table` itself, so it wears the same classes and needs no new CSS.

All paths are under `/home/lox/code/_fcl/rookery/todos/0.1.0/`.

## Steps

1. `readme.md`. The general view is documented in one block — it was `#filter-panel`'s section at lines 333-453 before bird rk-rename-filter-panel-to-todo-table-9971e639 renamed the view to `#todo-table`, and that bird rewrote the section in place, so find it by searching for `todo-table` rather than by line number. Its shape is: intro and example, then pill groups, then the tag group, then `tag-filter:`, then the `tags:` query, then the date column, then `facets:`/`pill-rows:`.

   Add a `#today-panel` section immediately AFTER that block, in the same register — prose saying what the view answers before it says what the arguments are. Cover, at minimum:
   - what it selects, as the union of four questions: a deadline falling today, a deadline already behind today, a scheduled date that has arrived, and the topmost priority in use. Say that the overdue half is included by default because a day view that hides what is late is worse than none.
   - that `is-scheduled-now` semantics mean a todo scheduled last week and still open is on today's list. This surprises people and the readme is where it stops surprising them.
   - the four own arguments, `horizon:`, `overdue:`, `priority:` and `also:`, each with the reason for its default — and in particular that `filter:` narrows the panel while `also:` widens it, which is the pair a reader will otherwise confuse.
   - that everything else — the pills, the date-cell ramp, the row shape — is `#todo-table`'s, because this view IS a selection handed to that one.
   - a worked call, matching the demo you write in step 2.

   Do not restructure or renumber the `#todo-table` section; add after it.

2. `demo/rheo/content/index.typ`. The demo's reference date is `TODAY = datetime(year: 2026, month: 8, day: 25)`, defined in `demo/rheo/content/lib.typ`. The existing corpus has an overdue todo (`invoice`, deadline 2026-08-04), a future deadline (`audit`, 2026-09-15) and a future scheduled date (`retro`, 2026-12-01) — but NOTHING dated today and nothing scheduled in the past, so a day view over it would demonstrate only half of itself. Add two todos near the others, each with the one-paragraph explanation the surrounding content uses:
   - one with a deadline of exactly `datetime(year: 2026, month: 8, day: 25)`, which is the `horizon: 0` case;
   - one with `tags: entries(scheduled: datetime(year: 2026, month: 7, day: 1))`, open — the todo whose scheduled date arrived weeks ago and which is therefore still today's problem.

   Give both a priority BELOW the corpus's top, so the priority half of the panel stays visibly distinct from the dated half.

   Then add a `== Today — #today-panel` section after the existing section that demonstrates `#todo-table` (it ends with a `#todo-table(today: TODAY, visible: 6, noun: "open todos")` call). Explain the union in prose, then call `#today-panel(today: TODAY, noun: "todos")`. Add `today-panel` to the import list at the top of the file, which is alphabetical.

3. `demo/rheo/check.sh`. That script asserts on the built OUTPUT, not merely that the build succeeded, and it greps rather than using a framework. Add one assertion in the same style: the built `build/html/index.html` contains a row for the todo dated today and does NOT contain a row for `retro` inside the today panel. The simplest honest form, given the page holds several panels, is to isolate the panel first — follow whatever selector the existing `python3` blocks in that file use to isolate a widget. If the panels cannot be told apart in the markup, fall back to asserting that the built page contains the today panel's `placeholder` string (`Filter today`), and say in the commit message that the assertion is weaker than intended.

## Do NOT

- Do not change `src/` at all. If a readme sentence cannot be made true without a code change, leave the sentence and say which one in the commit message.
- Do not reword or restructure the existing `#todo-table` documentation, and do not touch the existing demo sections or their fixture todos other than to add the two new ones.
- Do not add a screenshot, a table of every argument, or a changelog entry — none of those exist in this readme.

## VERIFY

From `/home/lox/code/_fcl/rookery/todos/0.1.0`:

1. `just check` passes — it builds, runs `rheo compile demo/rheo`, then runs `./demo/rheo/check.sh`, which now includes the new assertion.
2. `rg -n 'today-panel' readme.md demo/rheo/content/index.typ` shows the view named in both.
3. On the built page at `demo/rheo/build/html/index.html`, the today panel lists the new due-today todo, the new past-scheduled todo, the overdue `invoice`, and the corpus's top-priority todos — and does not list `retro`, whose scheduled date is in December.
