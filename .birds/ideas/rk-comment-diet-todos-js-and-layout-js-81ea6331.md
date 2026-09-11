---
id: rk-comment-diet-todos-js-and-layout-js-81ea6331
short-id: '81'
title: 'Comment diet: todos.js and layout.js'
priority: 3
labels:
- chore-todos-review
deps: []
closed: false
---
Comment diet: rewrite two comments in
`/home/lox/code/_fcl/rookery/todos/0.1.0/src/todos.js` and
`/home/lox/code/_fcl/rookery/todos/0.1.0/src/layout.js` that describe prior
behavior instead of the code as it stands.

Touches: /home/lox/code/_fcl/rookery/todos/0.1.0/src/todos.js, /home/lox/code/_fcl/rookery/todos/0.1.0/src/layout.js

## The rubric

Per this repo's own
`/home/lox/code/_fcl/rookery/CLAUDE.md`, "Comment style" section: a comment
describes the code as it stands, not how it got that way — never what it
used to be, what it replaced, or which version changed it. Each finding
below is a comment that violates this. This is a comment-only change: do
not alter any code, and the built output (`dist/lib.js` after `pnpm run
build`) must be functionally identical before and after.

## Findings and rewrites

### `todos.js`, lines 90-92 (the comment above `function drawEdge(upper, lower, unresolved) {`)

Current:
```
// An edge leaves the bottom of the box that UNBLOCKS and arrives at the top of
// the box waiting on it, so the arrow reads "upper unblocks lower".
//
// The geometry is unchanged from when the drawing ran the other way: bottom of
// the first argument, top of the second, cubic control points at the midpoint.
// Only which position is passed as which argument moved — see the call site.
function drawEdge(upper, lower, unresolved) {
```

Replace the SECOND paragraph only (keep the first paragraph — "An edge
leaves the bottom..." — unchanged, it already states the present contract)
with a present-tense statement of the geometry:

```
// An edge leaves the bottom of the box that UNBLOCKS and arrives at the top of
// the box waiting on it, so the arrow reads "upper unblocks lower".
//
// The curve runs from the bottom of `upper` to the top of `lower`, with
// cubic control points at the midpoint of the two.
function drawEdge(upper, lower, unresolved) {
```

### `layout.js`, lines 77-83 (inside `export function place(rowsOfNodes) {`, just above `const depth = rowsOfNodes.length;`)

Current:
```
  // LAYER 0 AT THE TOP — the todos that depend on nothing, i.e. the work that
  // is unblocked — with whatever waits on them hanging below. An index page
  // reads "here is what you can pick up, and here is what it releases".
  //
  // `depth` is still needed for `height` below, which is why it survives the
  // formula no longer using it.
  const depth = rowsOfNodes.length;
```

Replace the SECOND paragraph only (keep the first — "LAYER 0 AT THE TOP..."
— unchanged) with a present-tense statement of what `depth` is for:

```
  // LAYER 0 AT THE TOP — the todos that depend on nothing, i.e. the work that
  // is unblocked — with whatever waits on them hanging below. An index page
  // reads "here is what you can pick up, and here is what it releases".
  //
  // `depth` is `rowsOfNodes.length`, used by `height` below.
  const depth = rowsOfNodes.length;
```

## Do NOT

- Do not touch any other comment in either file.
- Do not change any code, function signature, or logic — comment text only.

## VERIFY

```sh
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just test-js
cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just check
```

Both must stay green exactly as before — `just test-js` runs
`test/layout.test.mjs`, which exercises `place` directly, and `just check`
rebuilds `dist/lib.js` via `pnpm run build`. A comment-only change cannot
affect either.