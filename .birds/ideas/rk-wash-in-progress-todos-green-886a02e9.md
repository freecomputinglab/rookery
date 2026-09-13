---
id: rk-wash-in-progress-todos-green-886a02e9
short-id: '88'
title: Wash in-progress todos green
priority: 3
labels:
- feat-todos-in-progress
deps: []
closed: false
---
A todo whose `status:` is `"in-progress"` looks exactly like one nobody has
started: the flat tag is emitted, the state is derived, and nothing on the page
is drawn differently for it. Give it a green wash across the row and a green
state label, in a hue that continues the red/orange/yellow ramp the date bands
already use rather than borrowing from it.

Touches: /home/lox/code/_fcl/rookery/todos/0.1.0/src/todos.css

## The hooks already exist — this is a stylesheet-only change

Nothing in the Typst emits needs adding. Both classes this bird styles are
already on the page:

- **The row's tag class.** A todo written `#todo("x", status: "in-progress")`
  carries the flat tag key `todo-in-progress`
  (`/home/lox/code/_fcl/rookery/todos/0.1.0/src/tags.typ:50`, the `STATUSES`
  list). Every list view turns each tag key into a class:
  `#todo-table` and `#today-panel` through `#panel`'s `row-class:`
  (`/home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ:583`), which yields
  `idea-row idea-tag-todo-in-progress`; `#todos-list` and its siblings through
  `_row-classes` (`/home/lox/code/_fcl/rookery/todos/0.1.0/src/views.typ:32`),
  which yields `todo-row idea-tag-todo-in-progress`.
- **The state badge's class.** `_state-of`
  (`/home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ:127-133`) projects the
  string `"in-progress"` as the row's `state` facet, and both badge shapes wear
  `idea-tag-in-progress` for it: `@rookery/core`'s row chip
  (`/home/lox/code/_fcl/rookery/core/0.1.0/src/row.typ:134`, `idea-tag
  idea-tag-<tag>`) under `#todo-table`'s default `badge-pills: false`, and
  `@rookery/search`'s filter pill
  (`/home/lox/code/_fcl/rookery/search/0.1.0/src/panel.typ:245-251`,
  `panel-pill idea-tag-<value>`) under `#today-panel`'s `badge-pills: true`.

Note the asymmetry, because it is easy to get backwards: the ROW's class is
`idea-tag-todo-in-progress` (from the tag KEY, which is namespaced) and the
BADGE's is `idea-tag-in-progress` (from the facet VALUE, which is not).

## Decisions already made — do not re-derive

- **The green is `#26b31e`, and it is derived rather than picked.** The heat
  ramp the date bands use is `#b3261e` red, `#b3611e` orange, `#b38f1e` yellow
  (`src/todos.css:282`, `297`, `304`): red pinned at 179, blue pinned at 30,
  green climbing 38 → 97 → 143. Carrying that construction past yellow and into
  green is the same pair swapped, `#26b31e`. It reads as part of the ramp
  because it is built like the ramp.
- **Do NOT add a `--rookery-heat-*` name for it.** The date bands reach their
  hues through `var(--todo-band-X, var(--rookery-heat-Y, #hex))`, and
  `--rookery-heat-*` belongs to `@rookery/core`. A fourth rung there would be a
  cross-package edit this does not need. Use the one-level shape
  `--todo-ready-color` and `--todo-blocked-color` already take
  (`src/todos.css:104`, `109`): a single `--todo-in-progress-color` owned here.
- **Two custom properties, not one.** `--todo-in-progress-color` is the HUE,
  shared by the wash and the label so they cannot drift; `--todo-row-in-progress-bg`
  overrides the whole computed fill, which is what `--todo-band-*` does for each
  date band. A site that wants a different green sets the first; a site that
  wants a different treatment entirely sets the second.
- **18% in `oklab`, under every date band's own strength.** The bands run 22%
  (`later`) to 38% (`urgent`) and `overdue` is solid. The row wash sits
  UNDERNEATH the date cell's band, and the two have to stay tellable apart, so
  the row goes weaker than the weakest band.
- **Do not reuse `--todo-ready-color` (seagreen).** Ready and in-progress are
  different states — `_state-of` returns `"in-progress"` before it tests
  readiness — and one colour for both would say a todo nobody has touched and a
  todo being worked are the same thing.
- **Horizontal padding with a matching negative margin**, the device the date
  band already uses at `src/todos.css:274-275` (`padding: 0 0.3em;
  margin-left: -0.3em`). Without it the wash hugs the text; with a plain
  `padding` it would shift the row out of alignment with its unwashed
  neighbours.
- **`#todos-search` is out of scope** and needs no rule. Its pill row offers
  only `ready` and `blocked` (`/home/lox/code/_fcl/rookery/todos/0.1.0/src/search.typ:213-214`),
  so a `.todo-search-pill[data-todo-value="in-progress"]` rule beside the two at
  `src/todos.css:104` and `109` would be dead CSS.

Line numbers are as of filing. If they have shifted, match the quoted text.

## Steps

1. In `/home/lox/code/_fcl/rookery/todos/0.1.0/src/todos.css`, insert the
   following two rules between the closed-card hover rule that ends at line 186
   with `  }` and the `.todo-row-ready {` rule that begins at line 188. Keep the
   two-space indent every rule inside `@layer todos` uses:

   ```css
     /* IN PROGRESS, AS A WASH ON THE WHOLE ROW. The countdown bands below paint the
      * DATE CELL for how long you have; being under way is a different question, so it
      * takes a different surface. The green continues the ramp's own construction
      * rather than borrowing a hue from it: `#b3261e`, `#b3611e` and `#b38f1e` hold red
      * at 179 and blue at 30 while green climbs, and `#26b31e` is that pair swapped,
      * which lands past yellow in green.
      *
      * 18%, under the weakest band's 22%, because this wash sits UNDERNEATH the date
      * cell's and the two have to stay tellable apart.
      *
      * BOTH LIST SHAPES. `#todo-table` and `#today-panel` build rows through `#panel`,
      * whose `row-class:` gives an `idea-row`; `#todos-list` and its siblings build
      * theirs through `_row-classes`, which gives a `todo-row`. Both then carry
      * `idea-tag-<key>` for every tag the todo wears.
      *
      * The padding and its matching negative margin are the date band's own device:
      * the wash needs room around the text without moving the row off the alignment
      * its unwashed neighbours keep. */
     .idea-row.idea-tag-todo-in-progress,
     .todo-row.idea-tag-todo-in-progress {
       background-color: var(
         --todo-row-in-progress-bg,
         color-mix(in oklab, var(--todo-in-progress-color, #26b31e) 18%, transparent)
       );
       border-radius: 3px;
       padding-inline: 0.3em;
       margin-inline: -0.3em;
     }

     /* THE LABEL, in the hue the row is washed with. `idea-tag-in-progress` is the
      * class both badge shapes already wear — @rookery/core's row chip under the
      * default `badge-pills: false`, @rookery/search's filter pill under
      * `#today-panel`'s `badge-pills: true`. NO `todo-` PREFIX here where the row's
      * class above has one: this comes from the state facet's VALUE, which is bare,
      * and that one from the tag KEY, which is namespaced. */
     .idea-tag-in-progress {
       color: var(--todo-in-progress-color, #26b31e);
     }
   ```

2. Nothing else. There is no Typst, JavaScript or demo change in this bird.

## Do NOT

- Do not edit any `.typ` or `.js` file. Every class this styles is already
  emitted.
- Do not add a `--rookery-heat-*` custom property, and do not edit anything
  under `/home/lox/code/_fcl/rookery/core/` or `/home/lox/code/_fcl/rookery/search/`.
- Do not change any existing colour, custom property or rule — in particular
  leave the `todo-when-*` bands (`src/todos.css:270-360`), `--todo-ready-color`,
  `--todo-blocked-color` and `--todo-stale-color` exactly as they are.
- Do not add a rule under `.todo-search-pill`; see the last decision above.
- Do not add a card rule for `[data-rookery-tags~="todo-in-progress"]` beside
  the `todo-closed` opacity rules at `src/todos.css:170-186`. Closed is a
  terminal state worth marking wherever the todo appears; in-progress is a
  reading aid for a LIST, and washing the note's own card green on the page
  where it is written is a separate call nobody has made.
- Do not change the ORDER rows appear in — a separate bird covers hoisting
  in-progress todos to the top, and it edits `src/table.typ` only.

## VERIFY

```sh
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just check
```

Expected: `just check` compiles `demo/rheo` and runs `demo/rheo/check.sh` to its
existing pass. It asserts nothing about colour — there is no CSS assertion
anywhere in `test/` — so what it proves here is that the stylesheet still parses
and still ships into a real build.

**There is no `dist/todos.css` to check, and no `just build` step for this
bird.** `typst.toml` sets `css_stylesheet = "src/todos.css"`, pointing straight
at the source: `dist/` holds only the JavaScript bundle (`dist/lib.js`), which
this bird does not touch. (The `build` recipe's comment in the `Justfile` claims
`dist/` gets a copy of the stylesheet; it is stale — believe `typst.toml` and
`vite.config.js`, which bundles `src/todos.js` and nothing else. `just check`
runs `build` as a prerequisite regardless.)

Then confirm the rules landed, in the source stylesheet the manifest ships:

```sh
grep -c 'idea-tag-todo-in-progress\|idea-tag-in-progress' /home/lox/code/_fcl/rookery/todos/0.1.0/src/todos.css
```

Expected: `3` — two selectors in the row rule, one in the label rule.