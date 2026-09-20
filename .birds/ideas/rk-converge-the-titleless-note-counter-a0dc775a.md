---
id: rk-converge-the-titleless-note-counter-a0dc775a
short-id: a0d
title: Converge the titleless note counter
priority: 4
labels:
- fix-idea-scope-convergence
deps: []
closed: true
---
Touches: core/0.1.0/src/state.typ, core/0.1.0/src/idea.typ, core/0.1.0/demo/rheo/content/titleless-pair.typ, core/0.1.0/demo/rheo/check.sh

## The defect, measured

Under rheo, a spine with **two or more vertebrae** in which **any one vertebra
carries two or more titleless unnamed notes** never converges. Typst gives up
after five attempts and the build fails — on a small project with the error
`failed to resolve cross-link` pointing at rheo's own page list, on a large one
with `@rookery/core: duplicate note id idea:4 — already registered in <handle>,
registered again in <handle>`.

A titleless unnamed note is `#idea[body]` with neither a name nor a `title:` —
the case that takes a container ordinal instead of a title slug. One such note
per vertebra converges; two on a single-vertebra project converges; two on one
vertebra of a multi-vertebra spine does not.

This is reproducible inside this repository's own demo, which has never
exercised the case because every fixture note there is either named or titled.
From `core/0.1.0/demo/rheo/`, write this file:

```typ
// content/probe-titleless.typ
#import "lib.typ": demo
#import "@rookery/core:0.1.0": idea
#show: demo

= Probe

#idea[First titleless note on this vertebra.]
#idea[Second titleless note on this vertebra.]
```

then run `rheo compile .`. It prints `document did not converge within five
attempts` followed by four `value of state("rheo-ideas") did not converge`
warnings. Delete the file again and `rheo compile .` is clean. Measured on
rheo 0.6.4 against this repository at the `dev` branch.

The same shape outside this repo, as a two-file rheo project, fails the same
way: page one with two titleless notes, page two with a `#show: rookery` and
no notes at all.

## What the run-by-run values say

The convergence warning reports the observed value of `rookery-idea-scope` at
the `_scope.get()` inside `_scope-peek`. On a real site (waterline, ~60
vertebrae, many titleless notes) it reads:

```
- run 1: `()`
- run 2: `((key: "", n: 1),)`
- run 3: `((key: "", n: 2),)`
- run 4: `((key: "", n: 3),)`
- run 5: `((key: "", n: 4),)`
- final: `((key: "clusters-aicre", n: 4),)`
```

Two facts in that trace, both load-bearing.

**One titleless note settles per run.** `n` advances by exactly one each
attempt rather than reaching its final value on the second, so the document
needs about as many attempts as the page has titleless notes and Typst only
gives five. That is why two is the threshold.

**The key is `""`, and stays `""` for the whole spine.** `_scope-record`
appends a fresh entry when the stack is empty and nothing ever pops that
entry, so the top-level accumulator is a single document-global slot whose
key freezes to whatever `state("rheo-handle")` was at the first top-level
titleless mint anywhere in the spine. When that first mint sees a non-string
handle the key is `""` for every page afterwards, and ids come out as bare
`idea:4` instead of `idea:<handle>-<n>`. Two notes landing on the same
ordinal is then a duplicate-id panic rather than a shifted id.

## The three sites

**The read.** Anchor:

```
rg -n 'let stack = _scope.get\(\)' /home/lox/code/_fcl/rookery/core
```

One hit, in `core/0.1.0/src/state.typ` (line 398 as of filing), inside
`_scope-peek`. The branch below it derives the key from the handle:

```
rg -n 'handle.replace\(":", "-"\)' /home/lox/code/_fcl/rookery/core
```

One hit, same file, line 403. This branch runs only when the stack is empty —
which, because of the never-popped accumulator, is true once per document
rather than once per vertebra.

**The write.** Anchor:

```
rg -n 's.slice\(0, -1\) \+ \(\(key: key, n: n\),\)' /home/lox/code/_fcl/rookery/core
```

One hit, in `core/0.1.0/src/state.typ` (line 407 as of filing), the whole body
of `_scope-record`. The `else` arm is the append that is never undone.

**The caller.** Anchor:

```
rg -n 'let container = if not named and slug == none' /home/lox/code/_fcl/rookery/core
```

One hit, in `core/0.1.0/src/idea.typ` (line 265 as of filing), inside `#idea`'s
main mint. It peeks, builds the id from `(key, n)` a few lines below, and
records. The note's own container is pushed just after:

```
rg -n '_scope.update\(s => s \+ \(\(key: own-id, n: 0\),\)\)' /home/lox/code/_fcl/rookery/core
```

One hit, `core/0.1.0/src/idea.typ` line 290. That push and its pop are
balanced, so a re-render of a stored body is net-neutral on the stack; the
unbalanced write is the top-level one in `_scope-record`.

If any anchor misses, widen the search to the repository root. If it is still
gone, report the miss rather than guessing at the site — these four lines are
the whole mechanism and a wrong guess silently changes every unnamed id on
every site using the package.

## This one needs measurement, not only reading

The second fact above — key frozen to `""` — is fully diagnosed and its fix is
a design decision (below). The first — one note settling per run — is not. It
is an observation with a plausible cause and no confirmed one, so instrument
before changing anything: add a temporary `context` block to the probe page
that renders `_scope.get()` as text, compile, and read what each attempt
leaves. Do not file the fix on the strength of the trace above alone.

## Steps

1. Reproduce. Write `core/0.1.0/demo/rheo/content/probe-titleless.typ` exactly
   as given above, run `rheo compile .` from `core/0.1.0/demo/rheo/`, and
   confirm the non-convergence warnings. Keep this file only while working;
   step 5 replaces it with the permanent fixture.

2. Make the top-level accumulator per-vertebra rather than document-global.
   The intent stated in `_scope-peek`'s own comment is already this — "the
   container is the current vertebra's own handle, so every top-level
   titleless note in one vertebra counts against a shared container" — and the
   code does not do it once the accumulator has been appended. The shape to
   aim for: mark the top-level accumulator so it is distinguishable from a
   note's own pushed container (an extra field on the entry is enough), and in
   `_scope-peek`, when the stack's last entry is that accumulator and its key
   is not the key the current `rheo-handle` derives, start a fresh count at 1
   under the new key instead of continuing the old one. `_scope-record`
   replaces the accumulator for the same key and appends one for a new key.
   Notes' own pushed containers keep today's behaviour exactly — their key is
   the parent note's id and has nothing to do with the handle.

3. Handle the non-string handle honestly. Outside rheo there is no handle and
   `""` is the right key; the bug is `""` persisting into pages that do have
   one. After step 2 a later vertebra with a real handle no longer inherits an
   earlier `""`.

4. Fix the convergence cost, guided by what the instrumentation in "This one
   needs measurement" showed.
   The target is that the scope state reaches its final value by the second
   attempt regardless of how many titleless notes a vertebra carries. State
   what you measured in the flight's banking message, so the next reader does
   not have to re-derive it.

5. Add the permanent fixture. Rename the probe to
   `core/0.1.0/demo/rheo/content/titleless-pair.typ`, keep both titleless
   notes, and give each body a distinctive grep marker in the shape the
   existing fixtures use (`TITLELESSONEBODY`, `TITLELESSTWOBODY`). Explain in
   a comment that the file exists because two titleless notes on one vertebra
   of a multi-vertebra spine is the case that did not converge, so nobody
   collapses it back to one note.

6. Assert on it in `core/0.1.0/demo/rheo/check.sh`. Append a new numbered
   block after the last one, which is number 29 and ends at this anchor:

   ```
   rg -n 'window-ellipsis span' /home/lox/code/_fcl/rookery/core
   ```

   One hit, `core/0.1.0/demo/rheo/check.sh` line 695. Put the new block
   between that line and the `if [ "$fail" -ne 0 ]` summary, whose own anchor
   is `rg -n 'demo/rheo: FAILED' /home/lox/code/_fcl/rookery/core` (one hit,
   line 698). Assert that both notes minted a page of their own under
   `ideas/`, that the two page names differ, and that each page renders its
   own marker. Follow the surrounding style: a `[ -f ... ] || note "..."` per
   assertion, no test framework.

## Non-goals

- **Do not change how a NAMED or TITLED note gets its id.** A named note mints
  from its name and a titled one from its title slug; neither touches the
  container ordinal and neither is implicated here.
- **Do not change the id FORMAT** beyond what step 2 forces. `idea:<key>-<n>`
  stays; what changes is which key and which `n` a note gets.
- **Do not touch `@rookery/timeline`, `@rookery/todos` or any other package.**
  The defect is entirely inside core's scope state.
- **Do not add a fallback that disambiguates a collision by suffixing.** The
  comment above `let slug` in `idea.typ` says why that was removed on purpose:
  a position-dependent suffix is exactly what cannot be made reproducible.
- **Do not edit anything in `/home/lox/code/waterline`.** That site is what
  found the bug; it is not part of this change.

## VERIFY

1. From `core/0.1.0/`, `just test` passes — the unit fixtures still compile.
2. From `core/0.1.0/demo/rheo/`, `just check` passes and prints `demo/rheo OK`,
   with the new assertion block included.
3. From `core/0.1.0/demo/rheo/`, `rheo compile .` prints no line containing
   `did not converge`.
4. `ls build/html/ideas/` after that build lists two distinct pages for the two
   titleless notes in `content/titleless-pair.typ`, and neither is named by a
   bare number.
5. From the repository root, `just check-versions` still prints its OK line.