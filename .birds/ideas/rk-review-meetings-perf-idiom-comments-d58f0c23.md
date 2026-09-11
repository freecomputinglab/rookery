---
id: rk-review-meetings-perf-idiom-comments-d58f0c23
short-id: d5
title: 'Review meetings: perf, idiom, comments'
priority: 2
labels:
- chore-package-reviews
deps: []
closed: false
---
Review `@rookery/meetings` for performance, idiomatic Typst, readability and
comment bloat, and FILE the findings as birds. This bird writes no package code.

Touches: nothing in the package — this bird only creates new birds under
`.birds/ideas/`.

## What this bird is

`@rookery/core` and `@rookery/search` have had this review and their findings are
filed as birds already. The same four questions have not been asked of this
package. Ask them, then file what you find.

**You are not fixing anything.** Read, decide, file. A fix is a separate bird
that a separate flight works.

This is the smallest package in the repo — 253 lines of Typst and 93 of CSS — so
the likeliest honest outcome is a short report with one or two birds, or none at
all. **A review that finds nothing is a result, not a failure.** Say so plainly
rather than manufacturing findings to justify the flight.

## The package

```
/home/lox/code/_fcl/rookery/meetings/0.1.0/
  src/lib.typ        253 lines
  src/meetings.css    93
  test/units.typ      53
  test/view.typ       26
```

Pure Typst plus CSS — no `package.json`, no build step, no JavaScript. It is a
meeting note over `@rookery/core`: who was in the room, when it happened, and
what was said.

Its suite, green today — run it BEFORE you start so you know the baseline and can
say so in your report:

```sh
cd /home/lox/code/_fcl/rookery/meetings/0.1.0 && just test
```

That recipe compiles `test/units.typ` and `test/view.typ` to HTML under
`test/build/`. The assertions inside `units.typ` are `assert.eq` calls, so a
passing compile is the green light.

`/home/lox/code/_fcl/rookery/CLAUDE.md` is the repo's own instruction file: read
its "Comment style" and "Pure-Typst packages" sections before judging anything.

## The four questions

### 1. Performance

Typst has no profiler here, so this is a reading exercise against known shapes.
Every item below is a defect actually found in `core` or `search`:

- **A `state` read repeated per element.** `.final()` is a document-wide
  resolution; a helper that reads one and is called four times for one answer
  pays four. In `core`, `#idea` called `_visible-tags(tags.keys())` four times
  per note.
- **A date formatted more than once per row.** `datetime.display` inside a
  `.filter(..).sorted(key: ..)` pipeline runs per filter AND per sort-key read.
  Found three times across `core` and `search`. A meeting note is a dated thing,
  so this is the item most likely to apply here.
- **An O(a x b) membership test** where one pass into a dictionary answers the
  same question — a dictionary key test is what this repo uses for that. A
  participants list crossed with something else is the shape to look for.
- **`regex(..)` built inside a loop** rather than bound once at module scope.
- **A `query()` selector wider than the walk that uses it.** `core`'s outline
  queried every `metadata` element in the bundle to find its own markers.

### 2. Idiomatic Typst

- `p.at(0)` / `p.at(1)` on a `(key, value)` pair where a destructuring parameter
  reads better: `.map(((k, v)) => ..)`, `_` for an unused half.
- A bare `target()` where the package has (or should have) a `_target()` helper
  reading rheo's context first — see `core/0.1.0/src/base.typ` for the pattern and
  the reason.
- `assert(false, message: ..)` where `panic(..)` is meant.
- An identity binding (`let x = if y == none { none } else { y }`).
- A state addressed by its string key in several places rather than bound once.
- Dead code: a function with no caller anywhere in the repo. Check `test/`
  imports and the other packages before calling anything dead.
- A copy of something `@rookery/core` already exports, on the wrong side of an
  import edge this package already has. `#idea-row` in core's `row.typ` and
  `_rec-label` in its `pure.typ` are the two most often hand-copied.

### 3. Readability

- A module holding something its own header says it does not.
- A duplicated import, an unused import.
- A function whose signature runs to one 300-character line where its siblings
  are formatted one parameter per line. At 253 lines this file holds the whole
  package, so also ask the honest question: does it want to be two modules, and
  if so where is the seam?

### 4. Comment bloat

The rubric is `/home/lox/code/_fcl/rookery/CLAUDE.md`'s "Comment style" section.
A finding is: a comment describing what the code used to be, what it replaced,
which version changed it, or that something "is gone"; a tracker id, bookmark or
branch name; a measurement's lab notebook around a number that does justify a
constant; the same fact stated twice; an interior `// ---- Section ----` banner
restating the file header; a comment arguing with a mistake its reader has not
made.

NOT a finding: a constraint the code cannot express, a caller contract, a number
that justifies a constant, or a note naming a counterpart file in another
language.

Report the comment-line ratio:

```sh
cd /home/lox/code/_fcl/rookery/meetings/0.1.0/src && for f in *.typ; do echo "$f $(grep -c '^[[:space:]]*//' $f)/$(wc -l < $f)"; done
```

## How to file what you find

Read `/home/lox/.claude/skills/bird-quality/SKILL.md` first if it is available to
you; if not, the shape it asks for is: a description that stands alone, absolute
paths and line numbers, the decisions already made spelled out, numbered steps,
an explicit list of what not to do, and a VERIFY naming this package's own
commands and their expected output. Never `jj` or `git` in a VERIFY.

- **Check what is already filed before you write anything**: `bd list` for open
  work, `bd list --all` for the retired ones — several touched this package when
  it was added. Do not re-file what one of them already did.
- One bird per reviewable change. Given the size of this package, one bird
  covering everything found is a likely and acceptable answer — but only if the
  findings genuinely belong to one change.
- Give every bird a `Touches:` line at the start of a line, comma-separated,
  naming the absolute paths it edits.
- **Where two of your birds touch the same file, add a dependency** so they
  cannot fly at once: `bd idea edit <later> --add-dep <earlier>`. With one source
  file in this package, two birds almost certainly need that edge.
- A comment-diet bird should be LAST in its chain.
- Write each description to a file and pass it in:
  `bd create "Short title" -p 3 -l chore-meetings-review -d "$(cat /path/to/desc.md)"`.
  Priorities in `bd` run the opposite way to beads: `0` is least important, higher
  is more important, default `2`. Use 4 for a performance finding on a real hot
  path, 3 for a comment-diet bird, 2 for a small idiom fix.
- File nothing you cannot locate. If you found a smell but not its cause, say so
  in your report.
- If a dimension — or the whole review — turns up nothing, say so explicitly.

## Do NOT

- Do not edit a single line of `meetings/0.1.0/**`.
- Do not run `jj` or `git`, and do not read `.birds/` directly — `bd` is the
  interface.
- Do not touch `.beads/`.
- Do not start a flight for any bird you file, and do not work one.
- Do not file a bird against `@rookery/core`; it has had its own review and its
  findings are filed.
- Do not file a bird proposing a new feature. This is a review of the code as it
  stands, not a design session.

## VERIFY

1. **Nothing changed.** The suite must be green, exactly as it was:

   ```sh
   cd /home/lox/code/_fcl/rookery/meetings/0.1.0 && just test
   ```

   Report what it printed.

2. **The birds exist and are startable** — or, if you filed none, your report
   says so and says why. `bd list` shows every bird you filed, `bd ready` shows
   the ones with no dependency, and `bd show <id>` on each shows the dependency
   edges you intended and a self-contained description.

3. **Every bird carries a `Touches:` line** and a VERIFY naming this package's
   own commands rather than a version-control observation.

4. **Your report names the findings**, the ids they were filed as, the dependency
   edges, and — explicitly — any dimension that turned up nothing.