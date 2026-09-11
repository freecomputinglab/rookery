---
id: rk-comment-diet-todo-typ-and-tags-typ-4f5975b7
short-id: 4f5
title: 'Comment diet: todo.typ and tags.typ'
priority: 3
labels:
- chore-todos-review
deps:
- blocked-by:rk-hoist-priority-of-s-regex-to-module-ea715ded
closed: false
---
Comment diet: rewrite six comment blocks in
`/home/lox/code/_fcl/rookery/todos/0.1.0/src/todo.typ` and
`/home/lox/code/_fcl/rookery/todos/0.1.0/src/tags.typ` that describe removed
or prior behavior instead of the code as it stands.

Touches: /home/lox/code/_fcl/rookery/todos/0.1.0/src/todo.typ, /home/lox/code/_fcl/rookery/todos/0.1.0/src/tags.typ

## The rubric

Per this repo's own
`/home/lox/code/_fcl/rookery/CLAUDE.md`, "Comment style" section: a comment
describes the code as it stands, not how it got that way — never what it
used to be, what it replaced, or which version changed it. A reader who
wants that history has `jj log`. Each finding below is a comment that
violates this by naming a removed parameter, a past behavior, or an old
version number.

This is a comment-only change. Do not alter any code — every rewrite below
only replaces prose inside `//` lines. Compiled output (PDF/HTML bytes)
must be identical before and after.

## Findings and rewrites

### `todo.typ`, lines 42-46 (inside `#todo`'s file-level doc comment, just above `// IT TAKES A DATE, NOT A BOOL.`)

Current:
```
// So there is still ONE store and one write path — `done:` folds into the
// `timeline:` dictionary before anything reads it (`_closing` below), rather than
// setting a second flag beside it. That is the whole reason the old `closed:`
// argument was removed in 0.6.0: it wrote the flat marker while
// `timeline: (closed: d)` wrote the entry, and the two disagreed. Folding cannot
// disagree.
```

Replace with:
```
// So there is one store and one write path: `done:` folds into the
// `timeline:` dictionary before anything reads it (`_closing` below), rather
// than setting a second flag beside it — the flat `todo-closed` marker
// (below) is derived from that one dictionary, so the two spellings of a
// close cannot disagree.
```

### `todo.typ`, lines 64-66 (a few paragraphs later, just above `// A CLOSE IS A DATE however it is written`)

Current:
```
// `created` is rookery's own row field, forwarded through `..args`. There is no
// `updated`: rookery removed it in 0.6.0 and rookery-timeline derives last-touched
// from the log. Nothing in this package auto-stamps a date; there is no wall
// clock to stamp from (see rookery-timeline's readme for the measured evidence).
```

Replace with:
```
// `created` is rookery's own row field, forwarded through `..args`. There is
// no `updated` field — rookery-timeline derives last-touched from the log
// instead. Nothing in this package auto-stamps a date; there is no wall
// clock to stamp from (see rookery-timeline's readme for the measured evidence).
```

### `todo.typ`, lines 150-156 (inside `#todo`'s body, the comment directly above `closed: log != none and CLOSED-STAGE in log,`)

Current:
```
// THE FLAT MARKER IS DERIVED FROM THE LOG, not from an argument. There used
// to be a `closed:` parameter beside `timeline:`, and the two were not
// equivalent: MEASURED, `#todo("a", closed: d)` carried `todo-closed` while
// `#todo("b", timeline: (closed: d))` did not, so the second read as closed to
// `is-closed` and as OPEN to `tags:todo&!todo-closed` — the query this
// package's own header calls the payoff of the flat-tag surface. Two ways to
// write one fact, one of them silently unfilterable.
```

Replace with:
```
// THE FLAT MARKER IS DERIVED FROM THE LOG, not from an argument — so
// `done:` and `timeline: (closed: ..)` always agree, and
// `tags:todo&!todo-closed` (the query this package's header calls the
// payoff of the flat-tag surface) never disagrees with `is-closed`.
```

Leave the paragraph immediately after this one ("Deriving it here is what
makes them one way...") untouched — it describes the present split of
responsibility between `todo-tags` and `#todo` and is not a violation.

### `tags.typ`, lines 23-26 (inside the file's 3-surface header comment, item 3)

Current:
```
//    @rookery/timeline's `timeline-log`, including the one this package used to
//    store itself (see `CLOSED-KEY` below). `created` comes from rookery's own
//    row field; there is no `updated` field any more — rookery-timeline derives
//    last-touched from the log.
```

Replace with:
```
//    @rookery/timeline's `timeline-log`, including the todo's close date (see
//    `CLOSED-KEY` below). `created` comes from rookery's own row field; there
//    is no `updated` field — rookery-timeline derives last-touched from the
//    log.
```

### `tags.typ`, lines 83-88 (the `CLOSED-KEY` doc comment's first paragraph, just above `// WHAT THIS KEY STILL IS:`)

Current:
```
// `todo-closed` IS NO LONGER A VALUED KEY. The date a todo closed lives in
// @rookery/timeline's `timeline-log`, under its reserved `closed` stage, alongside
// every other dated event in the todo's life — which is the whole point of
// 0.6.0: one store for a todo's timeline instead of a valued tag here, two date
// keys there, and core's `updated` somewhere else again.
```

Replace with:
```
// `todo-closed` is a flat presence marker, not a valued key. The date a
// todo closed lives in @rookery/timeline's `timeline-log`, under its
// reserved `closed` stage, alongside every other dated event in the todo's
// life — one store for a todo's timeline, rather than a valued tag here and
// a second date somewhere else.
```

Leave the rest of that comment block (the `WHAT THIS KEY STILL IS` and `So:
presence here, date in the log` paragraphs, lines 89-98) untouched — they
state the present contract and are not a violation.

### `tags.typ`, lines 229-233 (the `is-closed` doc comment, just above `#let is-closed(tags) = ...`)

Current:
```
// THE LOG ALONE, which it can be now that there is one write path. It used to
// read "the flat marker OR a `closed` log entry", because `#todo(closed: d)` wrote
// the marker and `entries(timeline: (closed: d))` wrote the entry and neither wrote both.
// With the marker derived from the log the two cannot disagree, so reading both
// would only hide a bug rather than tolerate one.
```

Replace with:
```
// THE LOG ALONE — the flat `todo-closed` marker is derived from it (see
// `todo.typ`'s `_closing`), so the two cannot disagree, and reading both
// here would only hide a bug rather than tolerate one.
```

## Do NOT

- Do not touch any other comment in either file. In particular, leave the
  "AN AUTO-ID DEP IS FRAGILE" section (`todo.typ`, roughly lines 73-83), the
  rest of `_closing`'s surrounding comments, and every comment in `tags.typ`
  outside the two blocks quoted above untouched — they describe present
  behavior and are not violations.
- Do not change any code, function signature, or logic — comment text only.

## VERIFY

```sh
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just test-js
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just check
```

All three must stay green exactly as before — a comment-only change cannot
affect compiled output; if any of the three fails, a comment edit broke
Typst's `//` syntax (e.g. an unclosed block) rather than the intended prose
change.