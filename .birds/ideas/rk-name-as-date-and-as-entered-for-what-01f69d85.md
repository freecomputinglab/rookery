---
id: rk-name-as-date-and-as-entered-for-what-01f69d85
short-id: 01f
title: Delete the as-* extractor family
priority: 1
labels:
- chore-timeline-api
deps:
- blocked-by:rk-name-the-write-surface-and-the-queue-013fb075
closed: false
---
`index.typ` (`/home/lox/code/_fcl/rookery/timeline/0.1.0/src/index.typ`) is 65
lines exporting six names whose entire content is partial application. Every one
of them is an eta-expansion of a reader that is already a function of a tag
dictionary:

```typ
#let as-stage(today: none) = tags => stage-of(tags, today: today)
#let as-rung(ladder: none, today: none) = tags => rung(tags, ladder: ladder, today: today)
#let as-settled(ladder: none, today: none) = tags => is-settled(tags, ladder: ladder, today: today)
#let as-days-in-flight(today: none) = tags => days-in-flight(tags, today: today)
```

Core's `tag-index` `from:` form takes a function of a note's tag dictionary
(`core/0.1.0/src/data.typ:137`), and Typst's own closure syntax writes that in one
line at the call site. `as-date` and `as-entered` do slightly more — they stamp
the datetime to a zero-padded `[year][month][day]` string — but core's `tag-index`
already does exactly that with `stamp: true`, which is legal alongside `from:`
(the stamp is applied to whatever the extractor returned,
`core/0.1.0/src/data.typ:102-119`). So the transform is core's, spelled twice.

Delete the file and the six exports. What replaces them is shorter than what it
replaces, and it names one mechanism instead of two.

`as-entered` is worth one more sentence, because it is the clearest evidence: it
accepts `today:` and never uses it. The only caller in existence passes
`today: TODAY` to an argument the body ignores, which is the kind of thing a
factory whose whole content is partial application makes invisible.

## Where it is used

Nowhere in this repo except its own tests and readme, and:

- `/home/lox/code/waterline/rookery/_lib/template.typ:240-248`, the `CFP-INDEX`
  spec — four uses of three of the six. THIS IS A SEPARATE REPOSITORY and needs
  its own commit; it resolves `@rookery/timeline` through the cache symlink at
  `~/.cache/typst/packages/rookery/timeline/0.1.0`, which points at this
  checkout, so the site breaks the moment this lands. Land both together.

`as-rung`, `as-settled` and `as-days-in-flight` have no callers anywhere at all.

Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/src/index.typ (deleted)
Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/src/lib.typ
Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/readme.md
Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/test/units.typ
Touches: /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
Touches: /home/lox/code/waterline/rookery/_lib/template.typ (separate repo)

## Steps

1. Delete `timeline/0.1.0/src/index.typ` and its line in `lib.typ`'s import
   manifest (the `#import "index.typ": *` among the star-imports at the foot of
   the header).
2. Delete the `as-*` assertions from `timeline/0.1.0/test/units.typ` (around lines
   255-262). Everything they covered is covered by the readers' own assertions,
   which are in the same file.
3. Replace the readme's `tag-index` section (`timeline/0.1.0/readme.md:440-455`)
   with the same example written against the readers, and keep the paragraph
   explaining WHY a log needs `from:` at all — that tag values never ride on an
   `ideas()` row, so a log-derived field is only filterable and sortable as a
   projected scalar. That reasoning is the valuable half of the section and it
   survives the deletion:

   ```typ
   #let INDEX = tag-index((
     stage:    (from: tags => stage-of(tags, today: TODAY)),
     deadline: (from: tags => stage-date(tags, DEADLINE-STAGE), stamp: true),
     rung:     (from: tags => rung(tags, ladder: JOB, today: TODAY)),
     settled:  (from: tags => is-settled(tags, ladder: JOB, today: TODAY)),
     entered:  (from: entered-of, stamp: true),
     waiting:  (from: tags => days-in-flight(tags, today: TODAY)),
   ))
   ```

   Note `entered-of` needs no wrapper at all — it is already a one-argument
   function of the tag dictionary — and that `stamp: true` is what keeps a
   projected date a scalar.
4. Add a line to the readme's migration table: the `as-*` extractors are gone,
   and a spec calls the readers directly.
5. `core/0.1.0/readme.md:1366-1367` cites `as-stage`, `as-date` and `as-rung` as
   how a package ships extractors for its own keys. Rewrite that sentence: a
   package ships READERS over a tag dictionary, and a spec names one in a `from:`
   — which is the same point without a second layer. Change no code in core.
6. In `/home/lox/code/waterline`, update `rookery/_lib/template.typ`:
   - drop `as-date`, `as-entered`, `as-stage` from the `rookery.typ` import list
     at lines 15-18, and add `entered-of` (`stage-date` and `stage-of` are already
     imported);
   - rewrite `CFP-INDEX` (240-248) with the four fields as above —
     `deadline`/`watch` through `stage-date` with `stamp: true`, `stage` through
     `stage-of(.., today: TODAY)`, `entered` as `(from: entered-of, stamp: true)`;
   - the comment above it says the fields "go through @rookery/timeline's own
     extractors, so `timeline-log` is named in that package and nowhere here" —
     that claim still holds, because the readers are what never name the key.
     Reword it to say readers rather than extractors.
   - `entered` currently passes `today: TODAY` to a function that ignores it;
     do not carry that across.

## Non-goals

- **Do not keep one or two of the six.** Six names for one mechanism or none; a
  half-kept family is the worst of both.
- **Do not add a `stamp:` argument, or any other argument, to a reader.** The
  stamping belongs to core's `tag-index`, which already has it.
- **Do not change any reader.** `stage-of`, `stage-date`, `entered-of`, `rung`,
  `is-settled`, `days-in-flight` keep their names, signatures and behaviour —
  they are what the spec now calls.
- **Do not change `tag-index` in core.** The `from:` form and `stamp: true`
  already do everything needed here.
- **Do not commit the waterline change into this repo.** Separate repo, separate
  commit; the user pushes both.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery/timeline/0.1.0 && just test` — `units OK`,
   `views OK`.
2. `rg -n 'as-stage|as-date|as-entered|as-rung|as-settled|as-days-in-flight'
   /home/lox/code/_fcl/rookery /home/lox/code/waterline` returns nothing (the
   unrelated `as-ideas`/`as-ref`/`as-outline` in waterline's other sites are
   different functions — do not touch them).
3. `cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just check` and
   `cd /home/lox/code/_fcl/rookery/cfps/0.1.0 && just test` pass.
4. `cd /home/lox/code/waterline && just build` succeeds, and the cfp table it
   renders still sorts by deadline and still shows a stage pill per row — the
   projection is what both are read from, so a wrong `stamp:` shows up as an
   unsorted table rather than as an error.
5. `cd /home/lox/code/_fcl/rookery && just check-versions` passes.