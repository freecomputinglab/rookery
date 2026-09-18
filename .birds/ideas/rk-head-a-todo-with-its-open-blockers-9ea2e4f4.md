---
id: rk-head-a-todo-with-its-open-blockers-9ea2e4f4
short-id: 9e
title: Head a todo with its open blockers
priority: 3
labels:
- feat-todo-blocked-by-header
deps:
- blocked-by:rk-move-a-row-s-label-into-graph-typ-8b327208
closed: false
---
Touches: todos/0.1.0/src/fields.typ, todos/0.1.0/src/lib.typ, todos/0.1.0/src/todo.typ, todos/0.1.0/src/todos.css, todos/0.1.0/readme.md

Open every todo note with a one-row record naming the todos that still block
it, in the same shape `@rookery/meetings` gives its `with:` record. Everything
in this bird happens inside `/home/lox/code/_fcl/rookery/todos/0.1.0`.

A todo note currently says nothing on its own page about what it is waiting for.
Its deps are stored (as the `todo-deps` tag value) and are read by the list views
and the graph deck, but the note itself shows only the shared pill strip
`@rookery/core` gives every note. A reader landing on `docs` has no way to see
that `ship` is in front of it without going back to a list.

`@rookery/meetings` already solved the shape of this problem: a meeting note
opens with a two-column `<dl>` whose one row reads `With` in a label gutter and
the attendees to its right. Read that implementation before writing this one —
it is the thing being mirrored:

```sh
rg -n -F '#let _fields(who) = {' /home/lox/code/_fcl/rookery/meetings/0.1.0/src/lib.typ
```

One hit as of filing, `meetings/0.1.0/src/lib.typ:92`, and its stylesheet half:

```sh
rg -n -F '.meeting-fields {' /home/lox/code/_fcl/rookery/meetings/0.1.0/src/meetings.css
```

One hit as of filing, `meetings/0.1.0/src/meetings.css:51`.

## Decisions already made — do not revisit these

- **Copy the markup and the CSS under a `.todo-fields` class family. Do NOT
  factor a shared helper into `@rookery/core`.** `meetings.css`'s own header
  records the precedent (anchor: `This is the same markup @rookery/bibtex gives
  a citation`, one hit, `meetings/0.1.0/src/meetings.css:29`): `@rookery/bibtex`
  already keeps its own classes and its own copy of these rules so that a
  project using it need not install `@rookery/meetings` to see the block. This
  is the third copy, for the same reason. Core owns the shared pill strip
  (`.idea-tab`) and deliberately owns no other note chrome.
- **No caption row.** `meetings` emits a `.meeting-fields-head` caption reading
  "Meeting" above its `<dl>`. Do not emit a "Todo" equivalent: every todo note
  already carries a `todo` pill in core's pill strip, so a caption would say the
  same thing twice. Emit the `<dl>` alone.
- **Only OPEN, RESOLVABLE blockers, and get them from `blockers-of`.** Do not
  write a second test for whether a dep blocks. A dep whose todo is closed is
  history and must not appear; a dep naming a todo that does not exist is
  collected into `graph.unresolved` and is the validator's business, not this
  record's. `blockers-of` already drops both.
- **Link a blocker with a plain `<a>` carrying the row's own pre-resolved
  `href`, degrading to a `<span>` when `href` is `none`.** That is this
  package's own idiom — see `views.typ` (anchor: `attrs: (class:
  "todo-row-title", href: row.href),`, one hit, `views.typ:55`) and the comment
  above it explaining that `href` is `none` where nothing mints pages, so a row
  must degrade to unlinked text rather than emit a dead anchor. Do NOT use
  `meetings`' `ref(label("idea:" + n))` idiom: `todos` contains no `ref`/`label`
  cross-reference machinery anywhere, and its rows arrive from core with `href`
  already resolved.
- **The record goes in the note BODY, above the prose — not into a page
  template.** `meetings` states the reason directly (anchor: `a `#window`
  renders the body and knows`, `meetings/0.1.0/src/lib.typ:220`): a
  transclusion renders the body and knows nothing about the consuming project's
  page chrome, so a record drawn by a template would exist on the note's own
  page and nowhere else.
- **`html.elem` contributes nothing at all on a paged target**, element and
  children alike, so this record is HTML/EPUB only. That is the same trade every
  view in this family makes; no paged fallback is wanted.

## Prerequisite

This bird depends on the bird that moves `_label(row)` from `views.typ` into
`graph.typ`. That move is what lets a file imported by `todo.typ` reach the
label rule without closing an import cycle. Before starting, confirm it landed:

```sh
rg -c -F '#let _label(row)' /home/lox/code/_fcl/rookery/todos/0.1.0/src/graph.typ
```

Prints `1`. If it prints nothing, stop and report that the prerequisite is not
in the tree — do not copy the helper in by hand.

## Steps

### 1. New file `src/fields.typ`

Create it with exactly this content:

```typ
// The record at the top of a todo note: one row naming the todos still in front
// of it.
//
// Same two-column shape and gutter as @rookery/meetings' `with:` record and
// @rookery/bibtex's citation block, with this package's own classes — a project
// reading a todo must not have to install either of those to see this block.
//
// HTML only: `html.elem` contributes nothing at all on a paged target, element
// and children alike. That is the same trade every view here makes.
#import "graph.typ": *

// `deps` is an array of already-normalized handles. Blockedness is NOT derived
// here: `blockers-of` is the one place that decides which of a todo's deps are
// still in its way, and a one-key row is what lets this call it rather than
// restate it — it reads `row.deps` and nothing else.
#let todo-blocked-by(deps) = if deps.len() > 0 {
  context {
    let graph = todo-graph()
    let open = blockers-of((deps: deps), graph)
    if open.len() > 0 {
      html.elem("dl", attrs: (class: "todo-fields"), {
        html.elem("dt", "Blocked by")
        // Comma-joined rather than one per line: a handle carries no commas of
        // its own, so a row of them reads as a list without needing a column.
        html.elem(
          "dd",
          open
            .map(d => {
              let row = graph.nodes.at(d)
              let label = _label(row)
              // `href` is `none` where nothing mints pages, so a blocker
              // degrades to unlinked text rather than a dead anchor.
              if row.href == none {
                html.elem("span", label)
              } else {
                html.elem("a", attrs: (href: row.href), label)
              }
            })
            .join(", "),
        )
      })
    }
  }
}
```

Note the shape of the guard: the emptiness checks are nested `if`s, not early
returns. `return` is only legal in a function body, and the inner block here is
a `context` block, which is not one.

### 2. Export it from `src/lib.typ`

Add one line, plus nothing else:

```sh
rg -n -F '#import "graph.typ": *' /home/lox/code/_fcl/rookery/todos/0.1.0/src/lib.typ
```

One hit as of filing, `src/lib.typ:22`. Insert immediately below it:

```typ
#import "fields.typ": *
```

`fields.typ` uses `graph.typ`'s names, and the comment at the top of `lib.typ`
(anchor: `THE ORDER OF THESE IMPORTS IS DEPENDENCY ORDER`, one hit) states that
this file's import order is dependency order and load-bearing — hence below
`graph.typ`, not above it. This is the one step in the bird whose placement is
not certain: if `just test` afterwards fails with an unknown-variable error
naming something from `fields.typ` or `graph.typ`, move the line further down
the list and say so in your report.

### 3. Splice the record into the note body, in `src/todo.typ`

`todo.typ` forwards `..args` to the minting call untouched, so there is nowhere
for a header to go today — the body arrives inside `..args` and is never
unpacked. It has to be unpacked, exactly the way `@rookery/meetings` unpacks it
(`meetings/0.1.0/src/lib.typ:179-180`, anchor: `let name = if pos.len() == 2 {
pos.at(0) } else { none }`, one hit) and exactly the arity rule core's `#idea`
itself uses (`core/0.1.0/src/idea.typ:69`, anchor: `let (name, body) = if
pos.len() == 1 {`): one positional is the body, two are the name then the body.

Find the region:

```sh
rg -n -F 'let log = _closing(done, timeline)' /home/lox/code/_fcl/rookery/todos/0.1.0/src/todo.typ
```

One hit as of filing, `src/todo.typ:140`, the first line of `#todo`'s body. The
lines under it read, in shape:

```typ
  let log = _closing(done, timeline)
  (dated(tagged-idea(TODO-KEY)))(
    timeline: log,
    tags: todo-tags(
      ... a long argument list carrying several comment blocks ...
      norm: _norm,
    ),
    ..args,
  )
}
```

Restructure it to this, and to nothing more:

```typ
  let log = _closing(done, timeline)
  let all-tags = todo-tags(
    ... THE SAME argument list, every comment inside it kept byte for byte,
        de-indented by two spaces so it sits at this `let`'s level ...
    norm: _norm,
  )
  let pos = args.pos()
  assert(
    pos.len() == 1 or pos.len() == 2,
    message: "@rookery/todos: #todo takes a body, optionally preceded by a name "
      + "— `#todo[..]`, `#todo(\"x\")[..]` or `#todo(<x>)[..]` — got "
      + str(pos.len())
      + " positional argument(s).",
  )
  let name = if pos.len() == 2 { pos.at(0) } else { none }
  let body = pos.last()
  // The record opens the note, above the prose, rather than being drawn by a
  // page template: `#window` renders the body and knows nothing about the
  // consuming project's page chrome, so a template's record would exist on the
  // note's own page and nowhere else.
  //
  // Normalized here as well as inside `todo-tags`, because the two are separate
  // readers of the same argument and the stored deps are normalized too — a dep
  // written as a bare name, an `idea:x` id or a label `<x>` has to reach the
  // graph as the one string either way.
  let full = {
    todo-blocked-by(deps.map(_norm))
    body
  }
  let mint = dated(tagged-idea(TODO-KEY))
  // Two branches because a name is positional and Typst has no way to pass "no
  // positional argument here": an unnamed todo must be called with the body
  // alone, not with `none` in front of it, which `#idea` would read as the name.
  if name == none {
    mint(timeline: log, tags: all-tags, ..args.named(), full)
  } else {
    mint(name, timeline: log, tags: all-tags, ..args.named(), full)
  }
}
```

Then add the import `fields.typ` provides, alongside the imports already at the
top of the file (anchor: `#import "tags.typ": *` in `src/todo.typ`, one hit,
`src/todo.typ:5`) — put it directly below that line:

```typ
#import "fields.typ": todo-blocked-by
```

Two things that need no change and must not be changed: the `#done` and `#epic`
factories further down the file (`(..args) => todo(done: on, ..args)` at
`src/todo.typ:201`, one hit) forward their caller's positionals straight into
`#todo`, so `args.pos()` sees them and both factories keep working untouched.

### 4. The stylesheet, in `src/todos.css`

Insert this block inside `@layer todos { ... }`, immediately above this line:

```sh
rg -n -F '.todo-list {' /home/lox/code/_fcl/rookery/todos/0.1.0/src/todos.css
```

One hit as of filing, `src/todos.css:34`. The block, at the two-space indent
every rule in that layer uses:

```css
  /* The record at the top of a todo note: the field's name in the gutter, its
   * value to the right. A grid on the `<dl>` itself, with each `<dt>`/`<dd>`
   * auto-placed as its own item — so a value wrapping to three lines pushes the
   * next row down instead of drifting out of column. The default gutter reads
   * `--timeline-gutter` first, so setting that one property lines this block up
   * with @rookery/meetings' record and @rookery/bibtex's citation. */
  .todo-fields {
    display: grid;
    grid-template-columns: var(--todo-fields-gutter, var(--timeline-gutter, 7.5em)) 1fr;
    column-gap: 0.9rem;
    margin: 0.6rem 0 1.2rem;
    border-top: 1px solid var(--todo-fields-line, var(--timeline-line, currentColor));
  }

  /* The rule between fields is drawn once per row, on both cells, so the two
   * segments abut into a single line across the block. */
  .todo-fields dt,
  .todo-fields dd {
    padding: var(--todo-fields-gap, 0.4rem) 0;
    border-bottom: 1px solid var(--todo-fields-line, var(--timeline-line, currentColor));
  }

  .todo-fields dt {
    color: var(--todo-muted-color, var(--idea-id-color, gray));
    text-transform: uppercase;
    letter-spacing: 0.03em;
    font-size: 0.85em;
  }

  /* `margin: 0` is load-bearing rather than tidy: a browser's default `<dd>`
   * carries `margin-inline-start: 40px`, which in a grid cell indents every
   * value away from its own column. */
  .todo-fields dd {
    margin: 0;
  }
```

`--todo-muted-color, var(--idea-id-color, gray)` is this stylesheet's existing
muted expression, used nine times already, so the label column matches the rest
of the package rather than importing `meetings`' `--meeting-muted`.

Do NOT add `meetings`' `:has(+ .timeline)` sibling rules. Those exist because a
meeting note draws a timeline rail directly under its record; `todos` draws no
rail in a note body at all — `timeline-view` appears nowhere in
`todos/0.1.0/src` — so those rules would be dead CSS.

### 5. Document it in `readme.md`

Add a new `##` section. Insert it immediately above this heading:

```sh
rg -n -F '## A skin over rookery' /home/lox/code/_fcl/rookery/todos/0.1.0/readme.md
```

One hit as of filing, `readme.md:141`. Write four or five sentences and a short
example, in the register of the surrounding sections: what the record is (one
row, `Blocked by`, the open blockers as links), that it appears on the note's own
page and inside a `#window` transclusion of it, that a closed dep and a dangling
dep both leave the record absent, and that it is HTML/EPUB only. Name the three
custom properties a project restyles it with — `--todo-fields-gutter`,
`--todo-fields-line`, `--todo-fields-gap` — and say that the gutter falls back to
`--timeline-gutter` so one property lines this block up with a meeting's record.
Do not write a changelog entry, a version number, or any note about what the
readme said before.

## Non-goals

- Do NOT change `#todos-blocked` in `views.typ`. It renders its blockers as
  plain comma-joined text (anchor: `let why = r => [blocked by`, one hit,
  `views.typ:249`), and turning those into links is a separate change that is
  not part of this record.
- Do NOT show closed deps, dangling deps, transitive blockers, or a count.
  One row, the direct open blockers, nothing else.
- Do NOT add a `.todo-fields`-based record for anything other than blockers —
  no priority row, no deadline row, no status row. The pill strip and the table
  views already carry those.
- Do NOT touch `demo/rheo/content/index.typ`. The demo already contains every
  case this bird needs to be verified against.
- Do NOT add a paged-target fallback.
- Do NOT add a unit assertion to `test/units.typ` for the renderer. It needs
  `context` and a corpus, which that fixture cannot supply; the demo's output
  assertions are where this is checked.
- Do NOT edit any file outside `todos/0.1.0/`.

## VERIFY

Run from `/home/lox/code/_fcl/rookery/todos/0.1.0`.

1. The Typst fixture still compiles, which is what proves `fields.typ` parses
   and that `lib.typ` re-exports it without an unknown-variable error:

   ```sh
   just test
   ```

   Ends with `units OK` and exits 0.

2. The demo builds and its existing output assertions still pass:

   ```sh
   just check
   ```

   Ends with `demo/rheo OK`. (`just check` runs `just build` first, which runs
   `pnpm install`; if that cannot reach the network, run `just test`, then
   `rheo compile demo/rheo`, then `./demo/rheo/check.sh`, and say in your report
   that `pnpm install` was skipped.)

   If one of `check.sh`'s existing assertions now fails because a blocker link
   has appeared inside a page region it counts, the fix is to narrow that
   assertion to the class it already means (its row selectors are all
   class-scoped) — NOT to remove the record. Report it either way.

3. The record appears on a todo whose dep is open. `docs` depends on `ship`,
   which is open:

   ```sh
   rg -c -F 'class="todo-fields"' demo/rheo/build/html/ideas/docs.html   # prints 1
   rg -c -F 'ideas/ship.html' demo/rheo/build/html/ideas/docs.html       # at least 1
   ```

4. The record is absent where every dep is closed. `parse` depends only on
   `fetch`, which the demo closes with `done:`:

   ```sh
   rg -c -F 'class="todo-fields"' demo/rheo/build/html/ideas/parse.html
   ```

   Prints nothing and exits 1.

5. The record is absent where the only dep is dangling. `blog` depends on
   `nope`, which no todo mints:

   ```sh
   rg -c -F 'class="todo-fields"' demo/rheo/build/html/ideas/blog.html
   ```

   Prints nothing and exits 1.