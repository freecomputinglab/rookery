---
id: rk-export-every-todo-as-a-marrow-json-b0c2de60
short-id: b0
title: Export every todo as a marrow JSON sidecar
priority: 3
labels:
- feat-todos-export
deps: []
closed: false
---
Touches: todos/0.1.0/.marrow.typ, todos/0.1.0/src/target.typ, todos/0.1.0/readme.md

## Goal

Make `@rookery/todos` write one JSON sidecar per build holding **every**
registered todo, fully decoded, so a program outside Typst can read a
rookery's todo corpus without parsing or evaluating Typst.

The file lands at `rookery/todos/index.json` in the built output, beside this
package's own copied scripts.

## Why

Nothing on disk today carries the full decoded set. Verified by reading the
built output of `/home/lox/code/waterline/rookery` on 2026-09-17:

- The only JSON in `build/html/` is
  `build/html/rookery/search/index.json` — 528 notes, 199 of them carrying the
  `todo` tag. But `@rookery/search`'s row shape is
  `(id, name, text, tags, body, created, href)` where `tags` is the tag-KEY
  array with **no values**. So a todo's dependency names and its closing date
  are not there: only that a `todo-deps` key and a `todo-closed` key exist.
- `#todo-graph-view` emits a decoded payload
  (`/home/lox/code/_fcl/rookery/todos/0.1.0/src/views.typ:470-474`, anchor
  `class:"todo-graph-data"`) but drops `tags-dict` and `metadata` entirely
  (see its own comment at `views.typ:381-387`), is emitted once per page that
  calls the view rather than consolidated, and is **not used anywhere** in
  waterline's build.
- `@rookery/core` has no export path at all.

So the corpus has to be written from the one place that already holds it
decoded: `todos()`.

## The precedent to copy exactly

`@rookery/search` already does this. Read
`/home/lox/code/_fcl/rookery/search/0.1.0/.marrow.typ` in full before
starting — it is 121 lines and is the model for every structural decision
here. Its shape:

```typst
#import "@rookery/search:0.1.0": (_index-asset-path, ...)
#import "@rookery/core:0.1.0": ideas

#context {
  let rows = ideas().filter(e => e.page != none)
  if rows.len() > 0 {
    ...
    asset(_index-asset-path, json.encode(final-rows, pretty: false))
  }
}
```

Facts that come with it, all verified:

- **A marrow is registered by filename alone.** Shipping a file named
  `.marrow.typ` at the package root is the whole registration; rheo
  auto-detects it (`/home/lox/code/_fcl/rheo/crates/core/src/plugins/typst_manifest.rs:227-263`).
  **No `typst.toml` change is needed** and this bird must not make one.
- **`asset(path, bytes)` is a bundle-root-only primitive.** rheo writes it to
  `<output_dir>/<path>` verbatim
  (`/home/lox/code/_fcl/rheo/crates/core/src/build.rs:1205-1215`, anchor
  `let dest = prepared.output_dir.join(path);`).
- **The path is a hand-chosen namespaced constant**, not derived from build
  data. `search`'s lives at
  `/home/lox/code/_fcl/rookery/search/0.1.0/src/base.typ:28`, anchor
  `#let _index-asset-path`.
- **The marrow body must be one `#context { .. }` block**, because `todos()`
  reads `.final()` state.
- **The marrow root has no per-page context.** `rheo-context().handle` and
  `href` are per-vertebra and unavailable here; only `page` (a site-root
  path) is meaningful. `search`'s marrow works around this the same way.
- **The marrow re-runs on every `rheo watch` rebuild.** There is no
  incremental skip (`/home/lox/code/_fcl/rheo/crates/cli/src/lib.rs:658-660`).
  So keep the work proportionate: one pass over `todos()`, no per-row state
  reads.

## The data, and the one trap in it

`todos()` is at
`/home/lox/code/_fcl/rookery/todos/0.1.0/src/graph.typ:30`, anchor
`#let todos() = {`. Each row is rookery core's own `ideas()` row spread
(`id, name, title, text, label, body, href, page, created`) plus this
package's decoded fields: `tags-dict`, `priority`, `kind`, `status`,
`closed`, `closed-on`, `deps`, `metadata`.

**The trap: `json.encode` of a Typst content value silently produces junk.**
`@rookery/core` warns about exactly this in its own source — see
`/home/lox/code/_fcl/rookery/core/0.1.0/src/data.typ:27` and `:326`. Several
`todos()` fields are content or may contain it:

- `title` is the **authored** title and is content. Do NOT encode it. Use
  `label` instead, which core already derives as flattened plain text (see
  `core/0.1.0/src/idea.typ:153`, anchor
  `let note-label = if title != none { _plain(title) }`). This is what
  `search`'s marrow does — it writes `text: e.label`.
- `body` is content. `search` replaces it with compressed terms; this export
  should **omit it entirely** — a todo's prose is not what an external reader
  of the corpus needs, and including it would multiply the file size for no
  gain. State this in the file's header comment.
- `closed-on` is a `datetime`. Stamp it to a string. `search` has
  `_date-stamp` for its `created` field; reuse the same helper if it is
  exported, and otherwise format as ISO `YYYY-MM-DD` rather than inventing a
  second stamp format. Do the same for `created`.
- `metadata` is an author-supplied dictionary and may contain content. Encode
  only entries whose value is a `str`, `int`, `float` or `bool`, and drop the
  rest. Say so in a comment — a silently-dropped key is better than a silently
  corrupt file, and the alternative (flattening arbitrary content) is not this
  file's job.
- `tags-dict` values may be arrays or content. Export the **keys** as an array
  (matching how `search` exports `tags`), since the decoded fields above
  already carry every value this package assigns meaning to.

## Steps

1. Add the asset path as a private constant in
   `/home/lox/code/_fcl/rookery/todos/0.1.0/src/target.typ`:

   ```typst
   #let _todos-asset-path = "rookery/todos/index.json"
   ```

   with a one-line comment saying where `.marrow.typ` writes it from, and that
   it sits beside this package's own copied scripts so the data and the code
   land in one directory — the same reasoning `search/src/base.typ:28` gives.
   Export it from `src/lib.typ` alongside the package's other underscore
   helpers so the marrow can import it by package spec.

2. Create `/home/lox/code/_fcl/rookery/todos/0.1.0/.marrow.typ`. One header
   comment saying what the file is: it runs once for the whole build with the
   finished note registry in scope and writes the todo corpus as JSON for
   readers outside Typst. Then:

   ```typst
   #import "@rookery/todos:0.1.0": _todos-asset-path, todos

   #context {
     let rows = todos()
     if rows.len() > 0 {
       asset(_todos-asset-path, json.encode(rows.map(_export-row), pretty: false))
     }
   }
   ```

   Import by **package spec**, never a relative path — a marrow's paths
   resolve against the *project* root, not the package's own directory
   (`/home/lox/code/_fcl/rheo/docs/contract.md`, the "Package-shipped marrow"
   section).

3. Write the row projection. Emit, per todo:

   | key | from | note |
   | --- | --- | --- |
   | `id` | `e.id` | rookery's full id, e.g. `idea:65` |
   | `name` | `e.name` | the short name deps refer to |
   | `title` | `e.label` | flattened plain text, never `e.title` |
   | `priority` | `e.priority` | integer; omit when 0 or none |
   | `type` | `e.kind` | omit when none |
   | `status` | `e.status` | omit when none |
   | `closed` | `e.closed` | bool, always present |
   | `closed-on` | `e.closed-on` | ISO date string; omit when none |
   | `deps` | `e.deps` | array of names; omit when empty |
   | `tags` | `e.tags-dict.keys()` | omit when empty |
   | `metadata` | scalar entries only | omit when empty |
   | `created` | `e.created` | ISO date string; omit when none |
   | `href` | `e.page` | site-root path; `page` not `href`, per the marrow's scope |

   Omit absent keys rather than writing `none`, as `search`'s marrow does
   (`search/.marrow.typ`, the `final-rows` mapping) — it keeps the file small
   and makes a missing value unambiguous.

4. Document it in
   `/home/lox/code/_fcl/rookery/todos/0.1.0/readme.md`: a short section naming
   the output path, the row shape, and that it is written on every build
   including every `rheo watch` rebuild. The readme already has a table of
   `br` verbs against this package's functions; this is not one of those, so
   give it its own heading rather than a table row.

## Conventions this repo will judge the work against

From `/home/lox/code/_fcl/rookery/CLAUDE.md`, read it before writing comments:

- **Describe the present.** No "used to", no "moved from", no release names.
- **No issue ids in comments.** Never name a bird, bookmark or branch.
- **One header comment per file, no interior `// ---- Section ----` banners.**
- **Comment the non-obvious**, not the line beneath. The content/`json.encode`
  trap and the marrow's lack of per-page context are exactly the kind of
  constraint that earns a comment; restating `let rows = todos()` is not.
- Present tense, declarative, concise. Emphasis capitals for the one claim in
  a block that carries it.

## Non-goals

- Do NOT change `typst.toml`. A marrow needs no manifest key.
- Do NOT add a `.marrow.prologue.typ` or `.marrow.epilogue.typ`. Either
  explicit name outranks a bare `.marrow.typ` and would take its place rather
  than adding a second contribution.
- Do NOT export `body`. See the trap section.
- Do NOT touch `@rookery/search`, its marrow, or its index. This is a second,
  independent file.
- Do NOT add a view, a function, or a CLI. This bird writes a file.
- Do NOT make the path configurable. A fixed namespaced constant is what
  `search` does and what its consumer can rely on.
- Do NOT flatten arbitrary content into strings to force it into the JSON.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just build` succeeds.
2. `cd /home/lox/code/_fcl/rookery/todos/0.1.0/demo/rheo && rheo compile .`
   succeeds, and `build/html/rookery/todos/index.json` now exists.
3. That file parses as JSON and is an array. Check with
   `python3 -c "import json;d=json.load(open('build/html/rookery/todos/index.json'));print(len(d));print(d[0])"`.
   The demo's own `content/index.typ` authors a dozen-plus todos including a
   closed one (`done: datetime(..)`), one with `deps: ("fetch",)`, and one with
   `metadata: (estimate: 45, assignee: "lox", external-ref: "GH-412")`, so
   assert specifically that:
   - a row exists whose `name` is `"fetch"` with `closed: true` and a
     `closed-on` string;
   - the row named `"parse"` carries `deps: ["fetch"]` and a `metadata`
     object containing `estimate` and `assignee`;
   - no row contains the string `"content("` or any other sign of a
     mis-encoded content value.
4. `rg -c 'null' build/html/rookery/todos/index.json` finds nothing — absent
   keys are omitted, not written as null.
5. `cd /home/lox/code/waterline/rookery && rheo compile .` succeeds and writes
   `build/html/rookery/todos/index.json`. Report how many rows it holds; the
   site has 76 `#todo(` call sites and 199 notes tagged `todo` in the existing
   search index, so a row count in that neighbourhood is the signal the export
   is corpus-wide rather than page-scoped. A count near 76 rather than near
   199 means the factory-derived todos (`#done(date)`, `#epic(name)`) are
   being missed and the export is wrong — report that rather than accepting it.
6. `build/html/rookery/search/index.json` is still written and unchanged in
   shape, confirming the two marrows coexist.