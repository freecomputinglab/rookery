---
id: rk-drop-the-dead-clamp-alias-60383530
short-id: '60'
title: Drop the dead clamp alias
priority: 2
labels:
- chore-slipshow-review
deps: []
closed: false
---
Drop the unused `clamp` alias from `@rookery/slipshow`'s `src/camera.js`.
`clampTo` is the one and only clamping function this package actually uses —
`src/slipshow.js` imports and calls `clampTo` directly, four times, and
nothing in `src/`, `demo/`, or `examples/` ever imports the name `clamp`.
The only place `clamp` is referenced at all is its own test, whose entire
body proves it behaves identically to `clampTo`:

```js
test("clamp: is the same function as clampTo", () => {
  assert.equal(clamp(-50, 1000, 800), clampTo(-50, 1000, 800));
  assert.equal(clamp(9999, 1000, 800), clampTo(9999, 1000, 800));
});
```

A production alias kept alive only by a test that checks it equals the thing
it aliases is dead code: there is no caller anywhere that needs the name
`clamp` to exist.

Touches: /home/lox/code/_fcl/rookery/slipshow/0.1.0/src/camera.js, /home/lox/code/_fcl/rookery/slipshow/0.1.0/test/camera.test.mjs

## Where

`/home/lox/code/_fcl/rookery/slipshow/0.1.0/src/camera.js`, lines 100-105:

```js
export const clampTo = (pos, docSize, viewportSize) =>
  Math.min(Math.max(pos, 0), Math.max(0, docSize - viewportSize));

// `clamp` is the vertical-only name `src/slipshow.js` and the tests still
// reach `clampTo` by.
export const clamp = clampTo;
```

`/home/lox/code/_fcl/rookery/slipshow/0.1.0/test/camera.test.mjs`, line 4
(the import) and lines 169-172 (the test):

```js
import { targetFor, clamp, clampTo, unfocusTarget } from "../src/camera.js";
```

```js
test("clamp: is the same function as clampTo", () => {
  assert.equal(clamp(-50, 1000, 800), clampTo(-50, 1000, 800));
  assert.equal(clamp(9999, 1000, 800), clampTo(9999, 1000, 800));
});
```

## Decisions already made — do not re-derive

- Confirmed by grep across the whole package (`src/`, `test/`, `demo/`,
  `examples/`) that no file other than `test/camera.test.mjs` ever writes
  the bare word `clamp` as an imported binding — every other reference in
  comments or prose says `clampTo`. This is genuinely dead code, not a
  public API this package promises anywhere (`camera.js` is an internal
  module, not something declared as a consumable export in `typst.toml` or
  `package.json`).
- Remove the alias AND its comment AND its test together — the comment
  exists only to explain why the alias is there, so once the alias is gone
  the comment has nothing left to explain.
- Do not rename `clampTo` — it is the name every real caller
  (`src/slipshow.js`) already uses.

## Steps

1. In `src/camera.js`, delete lines 103-105 (the two-line comment and the
   `export const clamp = clampTo;` line), leaving `clampTo`'s own export
   (lines 100-101) as the last thing in the file.
2. In `test/camera.test.mjs` line 4, remove `clamp` from the import list:

   ```js
   import { targetFor, clampTo, unfocusTarget } from "../src/camera.js";
   ```

3. In the same file, delete the `test("clamp: is the same function as
   clampTo", ...)` block (lines 169-172), including the blank line
   immediately above or below it so no double blank line is left behind —
   check both neighbours after deleting and keep exactly one blank line
   between the remaining tests.

## Do NOT

- Do not touch `targetFor`, `unfocusTarget`, or any other export in
  `camera.js` — this bird removes exactly one alias and nothing else.
- Do not remove or rename `clampTo` itself, or any of the other `clampTo`
  tests in `camera.test.mjs` (the ones at lines 161-167 and elsewhere in the
  file) — only the one test naming `clamp` goes.
- Do not add a deprecation comment or a migration note in place of the
  removed code — there is nothing downstream to migrate, since nothing
  outside this file and its own test ever used the name.

## VERIFY

1. JS suite green with one fewer test than before:

   ```sh
   cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just test-js
   ```

   Expect `ℹ tests 43` (one less than the 44 the baseline run reports today)
   and `ℹ fail 0`.

2. Typst suite unaffected (this bird touches no `.typ` file):

   ```sh
   cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just test
   ```

   Expect `units OK`.

3. Full build check:

   ```sh
   cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just check
   ```

   Expect `demo/rheo OK`.