---
id: rk-comment-diet-views-table-search-f1a1bd5d
short-id: f1
title: 'Comment diet: views, table, search'
priority: 3
labels:
- chore-todos-review
deps:
- blocked-by:rk-move-todo-graph-view-into-views-typ-7d46fa97
- blocked-by:rk-format-a-row-date-once-in-todo-table-2f322ddd
closed: false
---
Comment diet: rewrite three comment blocks in
`/home/lox/code/_fcl/rookery/todos/0.1.0/src/views.typ`,
`/home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ` and
`/home/lox/code/_fcl/rookery/todos/0.1.0/src/search.typ` that describe prior
behavior or a prior version of the comment itself, instead of the code as
it stands.

Touches: /home/lox/code/_fcl/rookery/todos/0.1.0/src/views.typ, /home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ, /home/lox/code/_fcl/rookery/todos/0.1.0/src/search.typ

## The rubric

Per this repo's own
`/home/lox/code/_fcl/rookery/CLAUDE.md`, "Comment style" section: a comment
describes the code as it stands, not how it got that way — never what it
used to be, what it replaced, or which version changed it. Each finding
below is a comment that violates this. This is a comment-only change: do
not alter any code, and compiled output (PDF/HTML bytes) must be identical
before and after.

## Findings and rewrites

### `views.typ`, `todos-stale`'s doc comment (currently lines 265-272, just above the older-than paragraph)

Current:
```
// RE-SOURCED IN 0.6.0, AND IT NOW MEASURES WHAT IT CLAIMS TO. It used to read
// rookery core's `updated` field, which resolved from `#idea(updated:)`, then
// `minted`, then the DOCUMENT's date — so on any project that did not hand-write
// an `updated:` per todo, "stale" measured how old the document was and not
// whether anything had happened. It now reads @rookery/timeline's
// `updated-of(row, tags)`: the last entry in the todo's own dated log, falling
// back to `created`. A todo that was deferred, activated or otherwise touched
// says so, because touching it puts an entry in the log.
```

Replace with:
```
// MEASURES WHAT IT CLAIMS TO: it reads @rookery/timeline's
// `updated-of(row, tags)`, the last entry in the todo's own dated log,
// falling back to `created`. A todo that was deferred, activated or
// otherwise touched says so, because touching it puts an entry in the log.
```

Leave the paragraph immediately after this one ("A todo with NO date at all
is still not stale...") untouched.

### `table.typ`, the file header's third paragraph (currently lines 16-23, just above `// THE \`tag\` GROUP IS WHY \`multi:\` EXISTS`)

Current:
```
// AND THE GROUPS DO NOT ALL COMPOSE ALIKE, which is the correction this file needed
// after shipping. "Within a facet the values OR .. and across facets they AND" was
// quoted here as though it were the whole of what a reader expects, and it is not: it
// is right for the STATE line, where `ready` and `p0` ask different questions, and
// wrong for the SUBJECT line, where `epic` and `tag` are one question in two
// projections and ANDing them returns nothing. `union:` below says which line is
// which — see the argument at the `panel(..)` call.
```

Replace with:
```
// AND THE GROUPS DO NOT ALL COMPOSE ALIKE. "Within a facet the values OR ..
// and across facets they AND" is right for the STATE line, where `ready`
// and `p0` ask different questions, and wrong for the SUBJECT line, where
// `epic` and `tag` are one question in two projections and ANDing them
// returns nothing. `union:` below says which line is which — see the
// argument at the `panel(..)` call.
```

### `search.typ`, file header (currently lines 33-38, just above `// LINKS, NOT TRANSCLUSIONS.`)

Current:
```
// THAT USED TO BE WRITTEN AS A RULE ABOUT THE WHOLE PACKAGE — "MUST NOT depend on
// @rookery/search" — and it was too strong. `table.typ` now builds `#todo-table`
// atop that package's `#panel`, for the reason point 1 above states: `ready` and
// `blocked` are derived HERE and nowhere else, so a panel that cannot press them is
// the one thing every consuming site ends up hand-rolling. The two facts sit side by
// side — this file needs no panel, and the panel needs this file's graph.
```

Replace with:
```
// `table.typ` builds `#todo-table` atop @rookery/search's `#panel`, for the
// reason point 1 above states: `ready` and `blocked` are derived HERE and
// nowhere else, so a panel that cannot press them is the one thing every
// consuming site ends up hand-rolling. The two facts sit side by side —
// this file needs no panel, and the panel needs this file's graph.
```

## Do NOT

- Do not touch any other comment in these three files — in particular, the
  paragraphs in `views.typ`, `table.typ` and `today.typ` explaining why
  nothing may call `datetime.today()` are caller contracts, not history, and
  are not violations. Leave every `MEASURED` comment elsewhere alone unless
  it is quoted above.
- Do not change any code, function signature, or logic — comment text only.

## VERIFY

```sh
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just test-js
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just check
```

All three must stay green exactly as before — a comment-only change cannot
affect compiled output.