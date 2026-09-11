---
id: rk-review-timeline-perf-idiom-comments-248ff0db
short-id: '24'
title: 'Review timeline: perf, idiom, comments'
priority: 3
labels:
- chore-package-reviews
deps: []
closed: false
---
Review `@rookery/timeline` for performance, idiomatic Typst, readability and
comment bloat, and FILE the findings as birds. This bird writes no package code.

Touches: nothing in the package — this bird only creates new birds under
`.birds/ideas/`.

## What this bird is

`@rookery/core` and `@rookery/search` have had this review. Its findings are
filed as birds already, and the same four questions have not been asked of this
package. Ask them, then file what you find.

**You are not fixing anything.** Read, decide, file. A fix is a separate bird
that a separate flight works — that is what keeps a review from turning into an
unreviewable change across nine files.

## The package

```
/home/lox/code/_fcl/rookery/timeline/0.1.0/
  src/lib.typ        117 lines    src/read.typ       142
  src/when.typ       215          src/view.typ       206
  src/ladder.typ     146          src/index.typ       65
  src/fragment.typ   303          src/upcoming.typ   423
  src/timeline.css   321
  test/units.typ     504          test/view.typ      104
  test/upcoming.typ   67
```

Pure Typst plus CSS — no `package.json`, no build step, no JavaScript. Its
suite is:

```sh
cd /home/lox/code/_fcl/rookery/timeline/0.1.0 && just test
```

which compiles `test/units.typ` as PDF (the assertions are `assert.eq` calls, so
a passing compile is the green light) and `test/view.typ` / `test/upcoming.typ`
as HTML into `test/build/`. Run it BEFORE you start, so you know the baseline is
green and can say so in your report.

`/home/lox/code/_fcl/rookery/CLAUDE.md` is the repo's own instruction file: read
its "Comment style" and "Pure-Typst packages" sections before judging anything.

## The four questions

### 1. Performance

Typst has no profiler here, so this is a reading exercise against known shapes.
Every item below is a defect that was actually found in `core` or `search`, so
they are worth grepping for by name:

- **A `state` read inside a loop or repeated per element.** `.final()` is a
  document-wide resolution; a helper that reads one and is called four times for
  one answer pays four. In `core`, `#idea` called `_visible-tags(tags.keys())`
  four times per note, each reading `_invisible-tags.final()`.
- **A date formatted more than once per row.** `datetime.display` in a
  `.filter(..).sorted(key: ..)` pipeline runs per filter AND per sort-key read;
  a grouping pass that then re-tests each row per distinct date makes it
  `N + N·D`. Found in `core`'s `_sort-ids`, `search`'s `_rank` and `search`'s
  `#filter-panel`. This package sorts dated things for a living — `when.typ`,
  `upcoming.typ`, `ladder.typ` — so look there first.
- **`regex(..)` built inside a loop** rather than bound once at module scope.
  Found in `search`'s `_tokenize`, once per token.
- **An O(a x b) membership test** where one pass into a dictionary answers the
  same question — a dictionary key test is what this repo uses for that (see
  `_stopwords` in `search/0.1.0/src/compress.typ`). Found in `search`'s
  `#filter-panel`, pills x rows.
- **A pure helper called with a page-varying argument**, which defeats Typst's
  memoisation of the call. `search/0.1.0/src/compress.typ:110-121` documents that
  trap in full: a per-page call keyed on an `href` costs the page count times
  what it should.
- **A `query()` selector wider than what the walk uses.** `core`'s outline
  queried every `metadata` element in the bundle to find its own markers.

### 2. Idiomatic Typst

- `p.at(0)` / `p.at(1)` on a `(key, value)` pair where a destructuring parameter
  reads better: `.map(((k, v)) => ..)`, with `_` for an unused half. Both
  spellings already exist in this repo, which is the problem.
- A bare `target()` where the file defines or imports a `_target()` helper that
  reads rheo's context first (`core/0.1.0/src/base.typ`,
  `search/0.1.0/src/base.typ`). Found in both packages.
- `assert(false, message: ..)` where `panic(..)` is meant.
- An identity binding (`let x = if y == none { none } else { y }`).
- A counter or state addressed by its string key in several places rather than
  bound once — a typo there is silent.
- Dead code: a function with no caller anywhere in the repo. Check the package's
  own `.marrow.typ` if it has one, its `test/` imports, and the other packages,
  before calling anything dead.

### 3. Readability

- A module holding something its own header says it does not (`core`'s
  `data.typ` held 316 lines of the template's argument validation).
- A duplicated import, an unused import.
- A function whose signature runs to one 300-character line where its siblings
  are formatted one parameter per line.

### 4. Comment bloat

The rubric is `/home/lox/code/_fcl/rookery/CLAUDE.md`'s "Comment style" section.
What counts as a finding: a comment describing what the code used to be, what it
replaced, which version changed it, or that something "is gone"; a tracker id, a
bookmark or a branch name; a measurement's lab notebook (the machine, the date,
the site, the alternatives that lost) around a number that does justify a
constant; the same fact stated twice in one file or twice across two; an
interior `// ---- Section ----` banner restating the file header; a comment that
argues with a mistake its reader has not made.

What is NOT a finding: a constraint the code cannot express, a caller contract, a
number that justifies a constant, or a note naming a counterpart file in another
language. Those stay.

Report the comment-line ratio per file, which is the one measurable part:

```sh
cd /home/lox/code/_fcl/rookery/timeline/0.1.0/src && for f in *.typ; do echo "$f $(grep -c '^[[:space:]]*//' $f)/$(wc -l < $f)"; done
```

## How to file what you find

Read `/home/lox/.claude/skills/bird-quality/SKILL.md` first if it is available to
you; if it is not, the shape it asks for is: a description that stands alone,
absolute paths and line numbers, the decisions already made spelled out, numbered
steps, an explicit list of what not to do, and a VERIFY section naming the
package's own commands and their expected output. Never `jj` or `git` in a
VERIFY.

- One bird per reviewable change. Do not file a bird whose VERIFY needs more than
  about five assertions; do not file three birds that only make sense applied
  together.
- Give every bird a `Touches:` line at the start of a line, comma-separated,
  naming the absolute paths it edits.
- **Where two of your birds touch the same file, add a dependency** so they
  cannot fly at once: `bd idea edit <later> --add-dep <earlier>`. The fan-out
  runs one agent per unblocked bird concurrently and they land into one tree.
- A comment-diet bird for this package should be LAST in its chain, blocked by
  every code bird touching the same files, because it rewrites the prose around
  code those birds change.
- Write each description to a file and pass it in:
  `bd create "Short title" -p 3 -l chore-timeline-review -d "$(cat /path/to/desc.md)"`.
  Priorities in `bd` run the opposite way to beads: `0` is least important,
  higher is more important, and the default is `2`. Use 4 for a performance
  finding on a real hot path, 3 for a comment-diet bird, 2 for a small idiom fix.
- File nothing you cannot locate. A bird whose steps are "find the place where X
  happens" is the bird a small model gets wrong; if you found a smell but not its
  cause, say so in your report instead.
- If a whole dimension turns up nothing, say so explicitly. "No performance
  findings" is a result, and a review that silently drops a dimension reads as one
  that covered it.

## Do NOT

- Do not edit a single line of `timeline/0.1.0/**`. Not a comment, not a
  formatting fix, not a typo.
- Do not run `jj` or `git`, and do not read `.birds/` directly — `bd` is the
  interface.
- Do not touch `.beads/` if this repo has one.
- Do not start a flight for any bird you file, and do not work one.
- Do not file a bird against another package. If a finding is really about
  `@rookery/core` or `@rookery/search`, say so in your report — both have had
  their own review and their findings are already filed, so it may be a
  duplicate.

## VERIFY

1. **Nothing changed.** The suite must be green, exactly as it was before you
   started:

   ```sh
   cd /home/lox/code/_fcl/rookery/timeline/0.1.0 && just test
   ```

   Report what it printed.

2. **The birds exist and are startable.** `bd list` shows every bird you filed,
   `bd ready` shows the ones with no dependency, and `bd show <id>` on each one
   shows the dependency edges you intended and a description that reads as
   self-contained.

3. **Every bird you filed carries a `Touches:` line** and a VERIFY section
   naming `just test` in this package rather than a version-control observation.
   Confirm by reading each one back with `bd show`.

4. **Your report names the findings**, the ids they were filed as, the
   dependency edges between them, and — explicitly — any dimension that turned
   up nothing.