---
id: rk-uses-the-rehydrate-helper-instead-of-7c24ad02
short-id: 7c2
title: Uses the rehydrate helper instead of local copies
priority: 2
labels:
- rehydrate-via-helper
deps: []
closed: false
---
Touches: search/0.1.0/src/panel.js, search/0.1.0/src/search.js, todos/0.1.0/src/todo-search.js, pinboard/0.1.0/src/pinboard.js, slipshow/0.1.0/src/slipshow.js

Four packages here each hand-rolled the same two patterns to survive `rheo
watch` patching a page. `@rheo/rehydrate` now holds both, tested once. Replace
the copies with calls to it.

This is a cleanup, not a fix: all four packages work correctly today. The value
is that the next package to need this does not write a fifth copy, and that the
duplicate-append trap has one place to be right instead of five.

## The background a worker needs

`rheo watch` patches a content edit into the live DOM instead of reloading.
Because a morph re-executes no script and hands back the *pre-hydration*
markup, each package registers a callback on `globalThis.__rheoRehydrate` that
re-wires its widgets. And because a morph mutates elements **in place** where it
can match them, listeners bound to surviving nodes **survive** — so every
re-wire must drop the previous pass's listeners or one click fires twice.

The two patterns that got copied:

1. **A `WeakMap` of `AbortController`s keyed on the widget's container**, so a
   re-wire aborts its own previous pass. Three copies.
2. **A module-level `AbortController` for page-level listeners** bound to
   `document` or `window`, which no morph ever replaces. Two copies.

`@rheo/rehydrate` replaces both with `wiring(key)`, which takes any object as
the key — a container element, or `document` — aborts the previous signal issued
for that key, and returns a fresh one. It also offers
`only(parent, selector, make)`, the ensure-exactly-one-child guard, and
`rehydrate(fn)` for registration.

## Locate the five sites

Confirmed at filing time — this printed exactly these five hits:

```bash
rg -n 'const wirings = new WeakMap\(\);|^let pass = null;' --glob '*.js' /home/lox/code/_fcl/rookery
```

- `search/0.1.0/src/panel.js` line 75 — `const wirings = new WeakMap();`, module scope, used by `wirePanel`
- `todos/0.1.0/src/todo-search.js` line 55 — `const wirings = new WeakMap();`, module scope, used by `wire`
- `pinboard/0.1.0/src/pinboard.js` line 49 — `const wirings = new WeakMap();`, module scope, used by `layOutBoard`
- `search/0.1.0/src/search.js` line 85 — `let pass = null;`, module scope, aborted at the top of `init`
- `slipshow/0.1.0/src/slipshow.js` line 69 — `let pass = null;`, module scope, aborted in its wiring pass

These anchors are the declarations this bird deletes, so they stop matching once
it lands and must not appear in VERIFY. The landmark — the function each one
serves, named above — is what locates the site afterwards. If an anchor does not
hit, widen to `/home/lox/code/_fcl/rookery` and report the miss rather than
guessing.

Each package's own `typst.toml` already carries `js_rehydrate = true` in both
its `[tool.rheo.html]` and `[tool.rheo.source.html]` blocks. Leave those alone.

## Steps

1. Add `@rheo/rehydrate:0.1.0` as a dependency of each of the four packages:
   import it in the package's Typst entrypoint so rheo injects its JavaScript.

2. In each of the five sites, delete the local controller bookkeeping and call
   the helper instead. Read it through the global **inside** the function, never
   at module-evaluation time — script order between two packages is not
   something either can assume, and a module body that reads the global is a
   bug. Give each use a one-line fallback so a missing helper degrades rather
   than breaking first load:

   ```js
   const wiring = globalThis.RheoRehydrate?.wiring ?? (() => new AbortController().signal);
   ```

   For the three container-keyed sites, pass the container as the key. For the
   two page-level ones, pass `document`.

3. **Keep every `{ signal }` option exactly where it is.** The listeners are
   already correctly scoped; only the thing that produces the signal changes.
   Do not add, remove or re-target a listener in this bird.

4. Route any create-and-append in a boot path through `only()`. There is at
   least one: `todos/0.1.0/src/todos.js` removes a previous
   `.todo-graph-svg` before appending a fresh one, which is exactly what
   `only()` does. Find the others by reading each package's boot path; if a
   package has none, say so rather than inventing one.

5. Leave each package's `(globalThis.__rheoRehydrate ??= []).push(...)`
   registration as it is, or switch it to the helper's `rehydrate(fn)` — but if
   you switch it, keep the `globalThis` spelling and keep it working when the
   helper is absent. **Never use `window` here**: the node suites in these
   packages supply a `document` and no `window`, so reading `window` at
   module-evaluation time throws there. That mistake has already been made and
   fixed once in `search/0.1.0/src/search.js`; its comment explains why, and
   `search/0.1.0/test/global.test.mjs` deliberately supplies no `window` in
   order to catch it. Do not defeat that test by adding one.

6. Do not change `search/0.1.0/src/urlstate.js`'s `claimKey`. Its owner-liveness
   rule is not part of this pattern and is load-bearing for a separate reason:
   it is what keeps one package's rehydrate callback from depending on
   another's having run first.

## Non-goals

- **Do not change any widget's behaviour.** Every test in all four packages must
  pass unchanged. If a test needs editing to accommodate this, that is a signal
  the change went too far — stop and report.
- **Do not touch `slipshow`'s first-load-versus-rehydrate split**, `pinboard`'s
  `currentTopZ` re-derivation, or `todos`'s URL-sync feature detection. Those
  are deliberate and specific; this bird only swaps out controller bookkeeping.
- **Do not edit any `typst.toml` asset block** beyond adding the dependency
  import in step 1.
- **Do not bump any package version.** These are consumed from a repo ref, not
  a version spec.
- **Do not commit `dist/`.** It is gitignored.

## Honest uncertainty

This bird cannot land until `@rheo/rehydrate:0.1.0` exists in the `/home/lox/code/_fcl/rheo-packages` repo (the bird `rheo-packages-ships-the-rehydrate-helper-package-9ffb793f`), and it is only *useful* once rheo
resolves a package's own `@`-imports transitively — without that, depending on
the helper does not get its script onto the page, and the fallbacks in step 2
are what every call site will actually use. That transitive resolution is the bird `rheo-resolves-a-package-s-own-package-imports-00b44cf9` in the `rheo` repo.

So check before starting: if `@rheo/rehydrate` does not resolve, stop and
report rather than copying the helper's source into these packages. A fifth and
sixth copy of the code is the exact outcome this bird exists to prevent.

## VERIFY

Every package's own suite, all of which must pass:

```bash
cd /home/lox/code/_fcl/rookery/search/0.1.0   && just test && just parity
cd /home/lox/code/_fcl/rookery/todos/0.1.0    && just test && just test-js
cd /home/lox/code/_fcl/rookery/pinboard/0.1.0 && just test-js && just check
cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just test && just test-js && just check
```

Then the real-browser suites, which are what actually exercise re-wiring:

```bash
cd /home/lox/code/_fcl/rookery && node --test slipshow/0.1.0/test/browser/deck.mjs
```

That must report `ok slipshow-deck` for each engine it runs. Finally, confirm no
`window.__rheoRehydrate` crept in — this must print nothing:

```bash
rg -n 'window.__rheoRehydrate' --glob '*.js' /home/lox/code/_fcl/rookery
```