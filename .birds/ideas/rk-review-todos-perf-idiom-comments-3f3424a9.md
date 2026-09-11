---
id: rk-review-todos-perf-idiom-comments-3f3424a9
short-id: 3f
title: 'Review todos: perf, idiom, comments'
priority: 3
labels:
- chore-package-reviews
deps: []
closed: false
---
Review `@rookery/todos` for performance, idiomatic Typst and JavaScript,
readability and comment bloat, and FILE the findings as birds. This bird writes
no package code.

Touches: nothing in the package — this bird only creates new birds under
`.birds/ideas/`.

## What this bird is

`@rookery/core` and `@rookery/search` have had this review and their findings are
filed as birds already. The same four questions have not been asked of this
package. Ask them, then file what you find.

**You are not fixing anything.** Read, decide, file. A fix is a separate bird
that a separate flight works — that is what keeps a review from turning into an
unreviewable change across a dozen files.

## The package

```
/home/lox/code/_fcl/rookery/todos/0.1.0/
  src/lib.typ         46 lines   src/todo.typ       252
  src/tags.typ       284         src/graph.typ      568
  src/views.typ      372         src/table.typ      593
  src/today.typ      166         src/deck.typ       183
  src/search.typ     233         src/skin.typ        59
  src/target.typ      29         src/todos.css      540
  src/todos.js       180         src/todo-search.js 280
  src/layout.js       97         vite.config.js      17
  test/units.typ     514         test/layout.test.mjs        84
  test/todo-search.test.mjs 219  test/todo-search-sync.test.mjs 158
  test/panic-layer-cycle.typ  4  demo/rheo/content/index.typ   272
```

A built package: `package.json` plus vite, so `dist/lib.js` comes from a build
and `src/*.js` is what the node suite imports. It imports `@rookery/core`
throughout and `@rookery/search` in exactly one file, `src/table.typ`, which
builds `#todo-table` on that package's `#panel`.

Its three checks, all green today — run them BEFORE you start so you know the
baseline and can say so in your report:

```sh
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just test-js
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just check
```

`just test` compiles `test/units.typ` as PDF (the assertions are `assert.eq`
calls, so a passing compile is the green light). `just test-js` is
`node --test test/*.test.mjs`. `just check` runs `pnpm install && pnpm run build`
and then `rheo compile demo/rheo`, so it needs the network the first time and the
`rheo` binary, which is on `PATH`.

`/home/lox/code/_fcl/rookery/CLAUDE.md` is the repo's own instruction file: read
its "Comment style" section, and the paragraph about why `todos` is allowed to
import `search`, before judging anything.

## The four questions

### 1. Performance

Typst has no profiler here, so this is a reading exercise against known shapes.
Every item below is a defect actually found in `core` or `search`, so each is
worth grepping for by name:

- **A `state` read repeated per element.** `.final()` is a document-wide
  resolution; a helper that reads one and is called four times for one answer
  pays four. In `core`, `#idea` called `_visible-tags(tags.keys())` four times
  per note.
- **A date formatted more than once per row.** `datetime.display` inside a
  `.filter(..).sorted(key: ..)` pipeline runs per filter AND per sort-key read,
  and a grouping pass that re-tests each row per distinct date makes it
  `N + N·D`. Found three times across `core` and `search`. This package sorts
  dated work for a living — `today.typ`, `views.typ`, `table.typ` — so look
  there first.
- **An O(a x b) membership test** where one pass into a dictionary answers the
  same question. Found in `search`'s `#filter-panel`: pills x rows, each
  rebuilding a row's tag array. `src/graph.typ` is the file most likely to carry
  the same shape here — a dependency DAG's ready/blocked derivation, its
  transitive closure and its cycle check are exactly where an accidental
  quadratic hides, and it is 568 lines of it.
- **`regex(..)` built inside a loop** rather than bound once at module scope.
  Found in `search`'s tokenizer, once per token.
- **A pure helper called with a page-varying argument**, which defeats Typst's
  memoisation. `search/0.1.0/src/compress.typ:110-121` documents the trap: a
  per-page call keyed on something page-relative costs the page count times what
  it should. Every view in this package can run on every page of a site.
- **A `query()` selector wider than the walk that uses it.** `core`'s outline
  queried every `metadata` element in the bundle to find its own markers.
- **On the JavaScript side**: a DOM collection rebuilt inside an event handler
  (`[...el.children].indexOf(x)` per hover, found in `search`'s modal), a layout
  read forced in a loop, and `querySelectorAll` inside a per-row callback.

### 2. Idiomatic Typst and JavaScript

- `p.at(0)` / `p.at(1)` on a `(key, value)` pair where a destructuring parameter
  reads better: `.map(((k, v)) => ..)`, `_` for an unused half. Both spellings
  already exist in this repo, which is the problem.
- A bare `target()` where the package has a `_target()` helper that reads rheo's
  context first — this package has a whole module for it, `src/target.typ`, so
  every read should go through it. Found wrong in `search`'s `_panel-shell`.
- `assert(false, message: ..)` where `panic(..)` is meant.
- An identity binding (`let x = if y == none { none } else { y }`).
- A counter or state addressed by its string key in several places rather than
  bound once — a typo there is silent.
- Dead code: a function with no caller anywhere in the repo. Check this
  package's `test/` imports, its demo, and the other packages before calling
  anything dead.

### 3. Readability

- A module holding something its own header says it does not (`core`'s
  `data.typ` held 316 lines of the template's argument validation).
- A duplicated import, an unused import.
- A function whose signature runs to one 300-character line where its siblings
  are formatted one parameter per line.
- A copy of something `@rookery/core` or `@rookery/search` already exports, on
  the wrong side of an import edge this package already has.

### 4. Comment bloat

The rubric is `/home/lox/code/_fcl/rookery/CLAUDE.md`'s "Comment style" section.
A finding is: a comment describing what the code used to be, what it replaced,
which version changed it, or that something "is gone"; a tracker id, bookmark or
branch name; a measurement's lab notebook (the machine, the date, the site, the
alternatives that lost) around a number that does justify a constant; the same
fact stated twice in one file or across two; an interior `// ---- Section ----`
banner restating the file header; a comment arguing with a mistake its reader has
not made.

NOT a finding: a constraint the code cannot express, a caller contract, a number
that justifies a constant, or a note naming a counterpart file in the other
language. This package has a Typst/JavaScript boundary, so those parity notes are
load-bearing and stay.

Report the comment-line ratio per file, the one measurable part:

```sh
cd /home/lox/code/_fcl/rookery/todos/0.1.0/src && for f in *.typ; do echo "$f $(grep -c '^[[:space:]]*//' $f)/$(wc -l < $f)"; done
cd /home/lox/code/_fcl/rookery/todos/0.1.0/src && for f in *.js; do echo "$f $(grep -cE '^[[:space:]]*(//|\*|/\*)' $f)/$(wc -l < $f)"; done
```

## How to file what you find

Read `/home/lox/.claude/skills/bird-quality/SKILL.md` first if it is available to
you; if not, the shape it asks for is: a description that stands alone, absolute
paths and line numbers, the decisions already made spelled out, numbered steps,
an explicit list of what not to do, and a VERIFY naming this package's own
commands and their expected output. Never `jj` or `git` in a VERIFY.

- **Check what is already filed before you write anything.** `bd list` for open
  work and `bd list --all` for the retired birds — this project has several that
  touched this package, including work on the priority scale, `#todo-table`,
  `#today-panel` and the URL sync. Do not re-file what one of them already did.
- One bird per reviewable change. Do not file a bird whose VERIFY needs more than
  about five assertions; do not file three birds that only make sense together.
- Give every bird a `Touches:` line at the start of a line, comma-separated,
  naming the absolute paths it edits.
- **Where two of your birds touch the same file, add a dependency** so they
  cannot fly at once: `bd idea edit <later> --add-dep <earlier>`. The fan-out
  runs one agent per unblocked bird concurrently and they land into one tree.
- A comment-diet bird should be LAST in its chain, blocked by every code bird
  touching the same files, because it rewrites the prose around code they change.
- Write each description to a file and pass it in:
  `bd create "Short title" -p 3 -l chore-todos-review -d "$(cat /path/to/desc.md)"`.
  Priorities in `bd` run the opposite way to beads: `0` is least important, higher
  is more important, default `2`. Use 4 for a performance finding on a real hot
  path, 3 for a comment-diet bird, 2 for a small idiom fix.
- File nothing you cannot locate. If you found a smell but not its cause, say so
  in your report rather than filing "find where X happens".
- If a whole dimension turns up nothing, say so explicitly. "No performance
  findings" is a result; a review that silently drops a dimension reads as one
  that covered it.

## Do NOT

- Do not edit a single line of `todos/0.1.0/**`. Not a comment, not a formatting
  fix, not a typo.
- Do not run `jj` or `git`, and do not read `.birds/` directly — `bd` is the
  interface.
- Do not touch `.beads/`.
- Do not start a flight for any bird you file, and do not work one.
- Do not file a bird against `@rookery/core` or `@rookery/search`. Both have had
  their own review and their findings are filed; if a finding is really theirs,
  put it in your report instead.

## VERIFY

1. **Nothing changed.** All three checks must be green, exactly as they were:

   ```sh
   cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just test
   cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just test-js
   cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just check
   ```

   Report what each printed.

2. **The birds exist and are startable.** `bd list` shows every bird you filed,
   `bd ready` shows the ones with no dependency, and `bd show <id>` on each shows
   the dependency edges you intended and a self-contained description.

3. **Every bird carries a `Touches:` line** and a VERIFY naming this package's
   own commands rather than a version-control observation. Confirm with
   `bd show`.

4. **Your report names the findings**, the ids they were filed as, the dependency
   edges, and — explicitly — any dimension that turned up nothing.