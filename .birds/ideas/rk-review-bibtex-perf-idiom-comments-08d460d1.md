---
id: rk-review-bibtex-perf-idiom-comments-08d460d1
short-id: '08'
title: 'Review bibtex: perf, idiom, comments'
priority: 3
labels:
- chore-package-reviews
deps: []
closed: false
---
Review `@rookery/bibtex` for performance, idiomatic Typst, readability and
comment bloat, and FILE the findings as birds. This bird writes no package code.

Touches: nothing in the package — this bird only creates new birds under
`.birds/ideas/`.

## What this bird is

`@rookery/core` and `@rookery/search` have had this review and their findings are
filed as birds already. The same four questions have not been asked of this
package. Ask them, then file what you find.

**You are not fixing anything.** Read, decide, file. A fix is a separate bird
that a separate flight works.

Note that this package is absent from the repo's own `CLAUDE.md`, which lists
five `@rookery` packages and does not mention it. A separate bird already covers
fixing that file; do not fix it here, and do not treat its silence as meaning
this package is unsupported.

## The package

```
/home/lox/code/_fcl/rookery/bibtex/0.1.0/
  src/lib.typ       184 lines   src/parse.typ     111
  src/format.typ     65         src/view.typ       84
  src/keywords.typ   27         src/claim.typ      13
  src/bibtex.css    111
  test/units.typ    149         test/large.typ     32
  test/sweep.typ     38         test/sweep-all.typ 30
  test/sweep-existing.typ 36    test/fields.typ    11
  demo/rheo/
```

Pure Typst plus CSS — no `package.json`, no build step, no JavaScript. It is a
BibTeX reader and a `#citation` note constructor over `@rookery/core` notes.

Its suite, green today — run it BEFORE you start so you know the baseline and can
say so in your report:

```sh
cd /home/lox/code/_fcl/rookery/bibtex/0.1.0 && just test
```

That recipe compiles `test/units.typ` and `test/large.typ` as PDF (the
assertions are `assert.eq` calls, so a passing compile is the green light) and
then four HTML fixtures — `sweep.typ`, `sweep-existing.typ`, `sweep-all.typ`,
`fields.typ` — each with its stderr captured to `test/build/*.stderr` and echoed.
**Those stderr files are part of the test**: the fixtures are about which
warnings a sweep emits, so read what is echoed rather than only checking the
exit status, and record it as your baseline.

`/home/lox/code/_fcl/rookery/CLAUDE.md` is the repo's own instruction file: read
its "Comment style" and "Pure-Typst packages" sections before judging anything.

## The four questions

### 1. Performance

This package parses text, which makes it the one place in the repo where the
parsing shapes below are likely to be the main cost. Typst has no profiler here,
so this is a reading exercise. Every item is a defect actually found in `core` or
`search`:

- **`regex(..)` built inside a loop** rather than bound once at module scope.
  Found in `search`'s tokenizer, once per token — and `src/parse.typ` is a
  parser, so this is the first thing to check.
- **Byte-offset `str.len()`/`str.slice` arithmetic on text that can be
  non-ASCII.** Typst's `str.slice` takes BYTE offsets and PANICS when one lands
  inside a multi-byte character; `core`'s `_derived-title` uses `.clusters()` for
  exactly that reason and says so. A BibTeX file is full of accented names, so
  every slice here wants checking against that rule — a finding of this kind is a
  correctness bug as much as a performance one, and worth filing at priority 4.
- **A full re-parse where the answer cannot change.** `core`'s `_bib-keys()`
  re-scanned the whole bibliography source on every call, once per note render
  per page. Ask of every parse here: how many times does it run per build, and
  what keys it.
- **An O(a x b) membership test** where one pass into a dictionary answers the
  same question — a dictionary key test is what this repo uses for that. Found in
  `search`'s `#filter-panel`.
- **A `state` read repeated per element.** `.final()` is a document-wide
  resolution; a helper that reads one and is called four times for one answer
  pays four.
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
  imports, `demo/` and the other packages before calling anything dead.

### 3. Readability

- A module holding something its own header says it does not (`core`'s
  `data.typ` held 316 lines of the template's argument validation).
- A duplicated import, an unused import.
- A function whose signature runs to one 300-character line where its siblings
  are formatted one parameter per line.

### 4. Comment bloat

The rubric is `/home/lox/code/_fcl/rookery/CLAUDE.md`'s "Comment style" section.
A finding is: a comment describing what the code used to be, what it replaced,
which version changed it, or that something "is gone"; a tracker id, bookmark or
branch name; a measurement's lab notebook around a number that does justify a
constant; the same fact stated twice in one file or across two; an interior
`// ---- Section ----` banner restating the file header; a comment arguing with a
mistake its reader has not made.

NOT a finding: a constraint the code cannot express, a caller contract, a number
that justifies a constant, or a note naming a counterpart file in another
language. For a parser, a comment recording the exact grammar accepted or the
exact shape a malformed entry repairs to is a contract and stays.

Report the comment-line ratio per file:

```sh
cd /home/lox/code/_fcl/rookery/bibtex/0.1.0/src && for f in *.typ; do echo "$f $(grep -c '^[[:space:]]*//' $f)/$(wc -l < $f)"; done
```

## How to file what you find

Read `/home/lox/.claude/skills/bird-quality/SKILL.md` first if it is available to
you; if not, the shape it asks for is: a description that stands alone, absolute
paths and line numbers, the decisions already made spelled out, numbered steps,
an explicit list of what not to do, and a VERIFY naming this package's own
commands and their expected output. Never `jj` or `git` in a VERIFY.

- **Check what is already filed before you write anything.** `bd list` for open
  work and `bd list --all` for the retired ones — at least two retired birds
  touched this package's parsing ("Parse each bib entry from its own chunk",
  "Test a bib field longer than 10k chars"), so read those with `bd show` before
  filing anything about the parser. Do not re-file work that has landed.
- One bird per reviewable change. Do not file a bird whose VERIFY needs more than
  about five assertions; do not file three birds that only make sense together.
- Give every bird a `Touches:` line at the start of a line, comma-separated,
  naming the absolute paths it edits.
- **Where two of your birds touch the same file, add a dependency** so they
  cannot fly at once: `bd idea edit <later> --add-dep <earlier>`.
- A comment-diet bird should be LAST in its chain, blocked by every code bird
  touching the same files.
- Write each description to a file and pass it in:
  `bd create "Short title" -p 3 -l chore-bibtex-review -d "$(cat /path/to/desc.md)"`.
  Priorities in `bd` run the opposite way to beads: `0` is least important, higher
  is more important, default `2`. Use 4 for a correctness or hot-path finding, 3
  for a comment-diet bird, 2 for a small idiom fix.
- Any bird touching the parser must keep the four HTML fixtures AND their stderr
  in its VERIFY, because the warnings are what those fixtures assert.
- File nothing you cannot locate. If you found a smell but not its cause, say so
  in your report.
- If a whole dimension turns up nothing, say so explicitly.

## Do NOT

- Do not edit a single line of `bibtex/0.1.0/**`.
- Do not run `jj` or `git`, and do not read `.birds/` directly — `bd` is the
  interface.
- Do not touch `.beads/`.
- Do not start a flight for any bird you file, and do not work one.
- Do not fix the repo `CLAUDE.md`'s missing package list — a separate bird owns
  that file.
- Do not file a bird against `@rookery/core`; it has had its own review and its
  findings are filed.

## VERIFY

1. **Nothing changed.** The suite must be green and its echoed stderr must match
   the baseline you recorded:

   ```sh
   cd /home/lox/code/_fcl/rookery/bibtex/0.1.0 && just test
   ```

   Report what it printed, warnings included.

2. **The birds exist and are startable.** `bd list` shows every bird you filed,
   `bd ready` shows the ones with no dependency, and `bd show <id>` on each shows
   the dependency edges you intended and a self-contained description.

3. **Every bird carries a `Touches:` line** and a VERIFY naming this package's
   own commands rather than a version-control observation.

4. **Your report names the findings**, the ids they were filed as, the dependency
   edges, and — explicitly — any dimension that turned up nothing.