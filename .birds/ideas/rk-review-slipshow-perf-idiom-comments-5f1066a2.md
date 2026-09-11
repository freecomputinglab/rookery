---
id: rk-review-slipshow-perf-idiom-comments-5f1066a2
short-id: 5f
title: 'Review slipshow: perf, idiom, comments'
priority: 3
labels:
- chore-package-reviews
deps: []
closed: false
---
Review `@rookery/slipshow` for performance, idiomatic Typst and JavaScript,
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

Note that this package is absent from the repo's own `CLAUDE.md`, which lists
five `@rookery` packages and does not mention it. A separate bird already covers
fixing that file; do not fix it here, and do not treat its silence as meaning
this package is unsupported.

## The package

```
/home/lox/code/_fcl/rookery/slipshow/0.1.0/
  src/lib.typ         11 lines   src/slip.typ        69
  src/marker.typ      46         src/tags.typ       159
  src/select.typ     417         src/slipshow.typ   543
  src/slipshow.css   337         src/slipshow.js    393
  src/camera.js      111         src/edges.js       198
  test/units.typ     384         test/camera.test.mjs   196
  test/reveal.test.mjs 51        test/edges.test.mjs     35
  test/panics.sh      28         test/panic-*.typ   (13 files, 2-6 lines each)
  demo/rheo/          examples/  (five example projects)
```

A built package: `package.json` plus vite, so `dist/lib.js` comes from a build
and `src/*.js` is what the node suite imports. It is the largest JavaScript
surface in the repo after `search`.

Its checks, all green today — run them BEFORE you start so you know the baseline
and can say so in your report:

```sh
cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just test-js
cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just check
```

`just test` compiles `test/units.typ` as PDF (the assertions are `assert.eq`
calls, so a passing compile is the green light). `just test-js` is
`node --test test/*.test.mjs`. `just check` runs `pnpm install && pnpm run build`
then `rheo compile demo/rheo`, so it needs the network the first time and the
`rheo` binary, which is on `PATH`. There is also `just examples`, which builds
every project under `examples/` — run it if your findings touch the selection or
the camera, since those examples are what exercise them.

`test/panics.sh` plus the thirteen `test/panic-*.typ` files are a negative suite:
each file must FAIL to compile with a particular message. If `just test` does not
run it, run `bash test/panics.sh` too and report what it printed — a change that
makes a panic stop firing is invisible to every other check.

`/home/lox/code/_fcl/rookery/CLAUDE.md` is the repo's own instruction file: read
its "Comment style" section before judging anything.

## The four questions

### 1. Performance

Typst has no profiler here, so this is a reading exercise against known shapes.
Every item below is a defect actually found in `core` or `search`:

- **A `state` read repeated per element.** `.final()` is a document-wide
  resolution; a helper that reads one and is called four times for one answer
  pays four. In `core`, `#idea` called `_visible-tags(tags.keys())` four times
  per note.
- **A `query()` selector wider than the walk that uses it.** `core`'s outline
  queried every `metadata` element in the bundle to find its own markers, which
  meant fetching every other package's beacons and discarding them. A deck that
  selects ideas out of a whole rookery — `src/select.typ`, 417 lines — is the
  most likely home for the same shape here.
- **An O(a x b) membership test** where one pass into a dictionary answers the
  same question; a Typst dictionary key test is what this repo uses for that.
  Found in `search`'s `#filter-panel`, pills x rows.
- **A date formatted more than once per row**: `datetime.display` inside a
  `.filter(..).sorted(key: ..)` pipeline runs per filter AND per sort-key read.
  Found three times across `core` and `search`.
- **`regex(..)` built inside a loop** rather than bound once at module scope.
  Found in `search`'s tokenizer, once per token.
- **A pure helper called with a page-varying argument**, which defeats Typst's
  memoisation. `search/0.1.0/src/compress.typ:110-121` documents the trap in
  full.
- **On the JavaScript side**: a DOM collection rebuilt inside an event handler
  (`[...el.children].indexOf(x)` per hover, found in `search`'s modal); a layout
  property read in a loop that also writes, forcing reflow per iteration — worth
  looking for specifically in `camera.js`, which by name does geometry; and a
  listener attached per element where one delegated listener on a container
  answers the same question (`search`'s `search.js` states that reasoning for its
  own `pointerdown` handler).

### 2. Idiomatic Typst and JavaScript

- `p.at(0)` / `p.at(1)` on a `(key, value)` pair where a destructuring parameter
  reads better: `.map(((k, v)) => ..)`, `_` for an unused half. Both spellings
  already exist in this repo, which is the problem.
- A bare `target()` where the package has (or should have) a `_target()` helper
  reading rheo's context first — see `core/0.1.0/src/base.typ` and
  `search/0.1.0/src/base.typ` for the pattern and the reason. Found wrong in
  `search`'s `_panel-shell`.
- `assert(false, message: ..)` where `panic(..)` is meant.
- An identity binding (`let x = if y == none { none } else { y }`).
- A counter or state addressed by its string key in several places rather than
  bound once — a typo there is silent.
- Dead code: a function with no caller anywhere in the repo. Check `test/`
  imports, `demo/`, `examples/` and the other packages before calling anything
  dead.

### 3. Readability

- A module holding something its own header says it does not (`core`'s
  `data.typ` held 316 lines of the template's argument validation).
- A duplicated import, an unused import.
- A function whose signature runs to one 300-character line where its siblings
  are formatted one parameter per line.
- A copy of something `@rookery/core` already exports, on the wrong side of an
  import edge this package already has.

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
language. This package has a Typst/JavaScript boundary and a negative test
suite, so notes about either are load-bearing and stay.

Report the comment-line ratio per file, the one measurable part:

```sh
cd /home/lox/code/_fcl/rookery/slipshow/0.1.0/src && for f in *.typ; do echo "$f $(grep -c '^[[:space:]]*//' $f)/$(wc -l < $f)"; done
cd /home/lox/code/_fcl/rookery/slipshow/0.1.0/src && for f in *.js; do echo "$f $(grep -cE '^[[:space:]]*(//|\*|/\*)' $f)/$(wc -l < $f)"; done
```

## How to file what you find

Read `/home/lox/.claude/skills/bird-quality/SKILL.md` first if it is available to
you; if not, the shape it asks for is: a description that stands alone, absolute
paths and line numbers, the decisions already made spelled out, numbered steps,
an explicit list of what not to do, and a VERIFY naming this package's own
commands and their expected output. Never `jj` or `git` in a VERIFY.

- **Check what is already filed before you write anything**: `bd list` for open
  work, `bd list --all` for the retired birds. Do not re-file what one of them
  already did.
- One bird per reviewable change. Do not file a bird whose VERIFY needs more than
  about five assertions; do not file three birds that only make sense together.
- Give every bird a `Touches:` line at the start of a line, comma-separated,
  naming the absolute paths it edits.
- **Where two of your birds touch the same file, add a dependency** so they
  cannot fly at once: `bd idea edit <later> --add-dep <earlier>`. The fan-out
  runs one agent per unblocked bird concurrently and they land into one tree.
- A comment-diet bird should be LAST in its chain, blocked by every code bird
  touching the same files.
- Write each description to a file and pass it in:
  `bd create "Short title" -p 3 -l chore-slipshow-review -d "$(cat /path/to/desc.md)"`.
  Priorities in `bd` run the opposite way to beads: `0` is least important, higher
  is more important, default `2`. Use 4 for a performance finding on a real hot
  path, 3 for a comment-diet bird, 2 for a small idiom fix.
- Any bird touching this package's Typst side must keep the negative suite in its
  VERIFY (`bash test/panics.sh`), because nothing else notices a panic that
  stopped firing.
- File nothing you cannot locate. If you found a smell but not its cause, say so
  in your report rather than filing "find where X happens".
- If a whole dimension turns up nothing, say so explicitly.

## Do NOT

- Do not edit a single line of `slipshow/0.1.0/**`. Not a comment, not a
  formatting fix, not a typo.
- Do not run `jj` or `git`, and do not read `.birds/` directly — `bd` is the
  interface.
- Do not touch `.beads/`.
- Do not start a flight for any bird you file, and do not work one.
- Do not fix the repo `CLAUDE.md`'s missing package list — a separate bird owns
  that file.
- Do not file a bird against `@rookery/core` or `@rookery/search`; both have had
  their own review and their findings are filed.

## VERIFY

1. **Nothing changed.** Every check must be green, exactly as it was:

   ```sh
   cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just test
   cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just test-js
   cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just check
   cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && bash test/panics.sh
   ```

   Report what each printed.

2. **The birds exist and are startable.** `bd list` shows every bird you filed,
   `bd ready` shows the ones with no dependency, and `bd show <id>` on each shows
   the dependency edges you intended and a self-contained description.

3. **Every bird carries a `Touches:` line** and a VERIFY naming this package's
   own commands rather than a version-control observation.

4. **Your report names the findings**, the ids they were filed as, the dependency
   edges, and — explicitly — any dimension that turned up nothing.