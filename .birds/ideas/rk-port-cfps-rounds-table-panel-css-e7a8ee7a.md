---
id: rk-port-cfps-rounds-table-panel-css-e7a8ee7a
short-id: e7
title: Port cfps rounds-table panel + CSS
priority: 2
labels:
- feat-cfps-package
deps:
- blocked-by:rk-scaffold-rookery-cfps-package-260c3227
closed: false
---
## What this is

Depends on `cfps-scaffold` (the bird that creates `/home/lox/code/_fcl/rookery/cfps/0.1.0/` with `src/cfp.typ` exporting a `cfps(kinds:)` factory returning `(venue:, cfp:, cfp-state:)`, `cfp-state` already carrying the fix for the "deadline/scheduled/closed mask the real answer" bug — see that bird's own description for the mechanism, `_real-tags`/`real-stage-of`. This bird adds the second half: a rounds-table view — one row per call, `when | title | school | verdict` — and its CSS, ported from the reference site. It CONSUMES `cfp-state`/`real-stage-of` by importing them from `cfp.typ`; it does not re-derive or re-port either.

## Reference implementation to port (read, do not edit, this file)

All in `/home/lox/code/waterline/rookery/_lib/template.typ` unless noted:

- Lines 938–~1180 (`#let cfps(sort: none, cycle: none, state: "open",
  countdown: false, empty: [Nothing here.]) = context { .. }`, the whole
  function): this is the view to port. Read the WHOLE function, including
  its HTML-rendering half (the `html.elem("ul", .. )` block with per-row
  `<li>` markup, the countdown-band logic, the priority-ramp fallback, the
  paged/non-HTML branch near its top) — do not stop at the row-mapping half.
- `real-stage-of(tags, today:)` — DO NOT port this; `cfps-scaffold` already
  put it in `src/cfp.typ` (it needs to exist before `#cfp` does, to exclude
  the same reserved stage names from state derivation). Import it from
  `cfp.typ` instead. It is what tells a row whether it has been answered at
  all (`real-stage-of(..) != none`) and what rung to badge.
- `/home/lox/code/waterline/rookery/_lib/lib.typ`'s `next-open-date(tags,
  today:)` (its tail function, no reserved-stage concerns of its own): DO
  port this one — into `src/panel.typ` itself, as a private helper, since
  nothing else in `cfp.typ` needs it. It is what a row still waits on once
  it has been answered.
- Waterline's `_cfp-index()` (template.typ lines ~298–376, private) does a
  venue/school JOIN this package's `cfp`/`venue` already make unnecessary to
  reimplement in full — venue title, href and schools are already reachable
  off the cfp's own `venue-` labelled ref via ordinary rookery `ideas()`/
  `tag-data()` calls, the same way any other rookery view reaches a
  reference. Re-derive the JOIN this package needs (cfp → venue → schools)
  directly against `@rookery/core`'s `ideas()`, rather than porting
  waterline's version verbatim — it is entangled with `SORT-DIRS`/
  `SORT-LABELS`, which this package does not have.
- The CSS: `/home/lox/code/waterline/rookery/style.css` lines 507–800
  (`.round-list`, `.round-row`, `.round-when*`, `.round-title`,
  `.round-school`, `.round-badge*`, `.round-verdict`, `.round-match`,
  `.round-empty`) and lines 1425–1450 (the same classes' responsive/narrow
  rules). Re-check these ranges with `grep -n` first — the file has moved
  since these were recorded.
- DO port `.opportunity-meta`'s own grid (currently lines 1145–1170:
  `.opportunity-meta { display: grid; .. }`,
  `.opportunity-meta dt, .opportunity-meta dd { .. }`,
  `.opportunity-meta dt { .. }`, `.opportunity-meta dd { .. }`) — `#cfp`'s
  `_opportunity-table` (ported by `cfps-scaffold`) emits exactly this class,
  so this package's own CSS has to style it; it is not available from
  `@rookery/timeline` or any other existing package, being site-local in the
  reference for the same reason `_opportunity-table` itself is (see
  `cfps-scaffold`'s own note on why `idea-page` cannot draw this block).
  Generalize per the color rule below — the reference already uses only
  `var(--edge)`/`var(--muted-color)`/`var(--timeline-gutter, 7.5em)`, all of
  which need a `--cfps-*`-prefixed custom property with the same literal as
  fallback instead of reaching for a site variable that will not exist in a
  consumer's stylesheet.
- Do NOT port the `.timeline { --timeline-gutter: 7.5em; .. }` rule right
  after it, or `.idea-timeline-head` — those belong to `@rookery/timeline`'s
  own rail and this site's generic note-page chrome, not to this panel, and
  are already available to a consumer through that package's own stylesheet.
- Color: do NOT port any color values. Waterline's `THEME.tags-color` dict
  (template.typ line 64 area) is that SITE's own palette choice, fed into
  `@rookery/core`'s existing generic mechanism that colors every
  `idea-tag-<key>` chip from a theme a consuming project supplies (see
  `/home/lox/code/_fcl/rookery/core/0.1.0/src/theme.typ` for how that
  mechanism works before writing any color rule). This package's CSS should
  be structural only — layout, spacing, the countdown bands as CSS custom
  properties a theme can override — exactly the pattern
  `timeline/0.1.0/src/timeline.css` and `todos/0.1.0/src/todos.css` already
  follow for their own `.timeline-*`/todo classes. If a ported rule
  hardcodes a color (grep the ported range for `rgb(`/`#` hex literals/
  named colors before finishing), replace it with a CSS custom property
  (`var(--cfps-<name>, <fallback>)`) instead of copying the literal.

## Steps

1. Add `src/panel.typ` to `cfps/0.1.0/`, importing from `cfp.typ` (the
   constants: `VENUE-KEY`, `CFP-KEY`, `CFP-VENUE-KEY`, `SCHOOL-KEY`,
   `WORK-KEY`, `APPLY-KEY`) and from `@rookery/core`/`@rookery/timeline` as
   needed (`ideas`, `tag-data`, `timeline-of`, `priority-of`,
   `priority-rung` — check these last two are exported from
   `@rookery/timeline` by grepping
   `/home/lox/code/_fcl/rookery/timeline/0.1.0/src/*.typ` for `#let
   priority-of`/`#let priority-rung`; if they live somewhere else, e.g.
   `@rookery/todos`, import from there instead — do not assume without
   checking).

2. Write the row-derivation half of `cfps(..)`, changed from the reference
   in these ways:
   - It is now a METHOD returned by the SAME `cfps(kinds:)` factory
     `cfps-scaffold` built (the factory this bird's `cfps` merges into — do
     not create a second, differently-named factory; extend the one that
     already returns `(venue:, cfp:, cfp-state:)` to also return `panel:`,
     bound to the same closed-over `kinds`/ladder config, so `ladder`
     resolves the same way `#cfp` itself resolves it).
   - No `sort:`/`SORT-*` parameter — waterline's `sort:` argument groups
     several kinds into "job"/"conference"/"journal" for its own 3-column
     layout, which this package does not own (see `cfps-scaffold`'s bird
     for why). Replace it with a plain `tags:` filter parameter (default
     `none`, meaning no extra filter) that the caller can use to scope a
     panel to whatever grouping THEIR site wants — merged into the `want`
     array the reference builds at template.typ:947 (`(CFP-KEY,) + ..`)
     alongside any explicit tags the caller passes.
   - No `cycle:` parameter, for the same reason `#cfp` itself dropped it
     (see `cfps-scaffold`'s bird). A caller wanting a per-cycle panel passes
     `tags: "cycle-26-27"` (or whatever tag their own convention uses)
     through the new `tags:` parameter above.
   - `today:` becomes an explicit parameter (default `none`, same
     `document.date`-fallback-inside-`context` pattern `#cfp` itself uses —
     see `cfps-scaffold`'s bird for that pattern) — the reference reaches
     for a module-level `TODAY`, which this package does not have.
   - `HIDDEN-STAGES`-style filtering does not belong in this view at all —
     the reference's `cfps()` panel never filters on it (only `#window`
     does, and `#window` is `@rookery/todos`', a different package this
     bird does not touch); do not add it.
   - Keep the `state:`/`want-state` filter (`"open"`/`"in-flight"`/
     `"settled"`/`"watching"`), `countdown:`, and `empty:` parameters
     exactly as the reference has them — these are the panel's real,
     already-generic API and need no change.
   - Replace `_cfp-index()`'s venue/school join (see "Reference
     implementation" above) with a direct one: for each cfp row, read its
     `CFP-VENUE-KEY` tag value (a venue's name), look that venue up via
     `tag-data().at("idea:" + <name>)` for its `SCHOOL-KEY` array, and
     resolve each school name to a label the same way — one pass, cached in
     a dictionary keyed by name, the same shape the reference's
     `_cfp-index()` builds (template.typ ~330–376), just without the
     `SORT-*`-derived fields it also carries.

3. Write the HTML-rendering half verbatim from template.typ's `cfps()` (the
   `if target() != "html" { .. }` paged branch, then the `html.elem("ul",
   ..)` block) — this part has no waterline-specific vocabulary in it at
   all, only CSS class names (`round-row`, `round-when`, `round-title`,
   `round-school`, `round-badge`, `round-verdict`, `round-match`,
   `round-empty`), so it ports unchanged.

4. Add `src/cfps.css`, porting the ranges named under "Reference
   implementation" above, generalized per the color rule there. Add the
   stylesheet to `typst.toml`:
   ```toml
   [tool.rheo.html]
   css_stylesheet = "src/cfps.css"
   ```
   (`cfps-scaffold`'s `typst.toml` deliberately has no `[tool.rheo.html]`
   section yet — add it here, don't assume it exists.)

5. Update `src/lib.typ` if it needs to star-import `panel.typ` too (check
   whether `cfps-scaffold` already made `lib.typ` a blanket `#import
   "cfp.typ": *` — if so, add `#import "panel.typ": *` alongside it rather
   than replacing the existing line).

6. Extend `test/smoke.typ` (added by `cfps-scaffold`) with a call to the new
   `panel:` — mint two or three fake cfps under different states (one
   answered/settled, one open/unanswered, one dropped) and call `panel(..)`
   with `state: ("open", "in-flight", "settled", "watching")` so every
   branch of the row-mapping and the HTML-rendering halves actually run.

## Non-goals

- Do NOT write `readme.md` — `cfps-tests-readme` (depends on this bird and
  on `cfps-scaffold`) owns it, so two concurrent-if-unblocked birds never
  edit the same file.
- Do NOT touch `/home/lox/code/waterline/rookery`.
- Do NOT add a `#window`-equivalent hiding mechanism to this package — that
  is `@rookery/todos`' `#window`, a different, already-existing package;
  this bird only ports the rounds-table view.
- Do NOT port any literal color value — see "Reference implementation"
  above.

Touches: cfps/0.1.0/typst.toml, cfps/0.1.0/src/lib.typ, cfps/0.1.0/src/panel.typ, cfps/0.1.0/src/cfps.css, cfps/0.1.0/test/smoke.typ

## VERIFY

```
cd /home/lox/code/_fcl/rookery/cfps/0.1.0
just test
```
must print `smoke OK` with no Typst error, and the compiled
`test/build/smoke.html` must contain the literal strings `round-row` and
`round-empty` (grep it: `grep -o 'round-row\|round-empty' test/build/smoke.html`)
— confirming the panel actually rendered rows and, for whichever state
combination has none, the empty-state branch. Then, from the repo root:
```
cd /home/lox/code/_fcl/rookery
just build
```
must still succeed.