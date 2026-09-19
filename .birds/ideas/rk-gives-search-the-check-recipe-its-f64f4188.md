---
id: rk-gives-search-the-check-recipe-its-f64f4188
short-id: f64
title: Gives search the check recipe its siblings have
priority: 2
labels:
- fix-search-check-recipe
deps: []
closed: false
---
Touches: search/0.1.0/Justfile

Give `@rookery/search` the `check` recipe its three sibling JavaScript packages have,
so its tests cannot be run against an uninstalled `node_modules` and fail with an
opaque module-not-found error.

## The defect

`search/0.1.0/Justfile` has `build` (which runs `pnpm install`) and `test`, but no
`check`. Every other JS package in the repo pairs them:

```
rg -n '^check: build' /home/lox/code/_fcl/rookery/todos/0.1.0/Justfile /home/lox/code/_fcl/rookery/slipshow/0.1.0/Justfile /home/lox/code/_fcl/rookery/pinboard/0.1.0/Justfile
```

Three hits, one per package. `search` is the only one missing it.

The consequence, observed: running `just test` in `search/0.1.0` on a checkout whose
dependencies are not fully installed fails with

```
Error [ERR_MODULE_NOT_FOUND]: Cannot find package 'linkedom'
```

`linkedom` IS correctly declared — `search/0.1.0/package.json` lists it under
`devDependencies` and `pnpm-lock.yaml` pins `linkedom@0.18.13`. Fifteen test files
import it. Nothing is wrong with the manifest; the recipe simply never guarantees the
install, and there is no `check` recipe to be the one that does.

## Steps

1. Read the three sibling Justfiles named above and copy their shape rather than
   inventing one. Note what each one's `check` actually runs beyond `build` — at least
   one of them also runs a demo check script, and `search` may or may not have an
   equivalent.

2. Find `search`'s current recipes:

   ```
   rg -n '^(build|parity|test):' /home/lox/code/_fcl/rookery/search/0.1.0/Justfile
   ```

   Three hits (lines 1, 6 and 16 as of filing).

3. Add a `check: build` recipe that runs the package's own verification. At minimum it
   runs the `test` recipe's command; include `parity` too if the sibling packages'
   `check` recipes include their equivalent — `search`'s `parity` pins the Typst and
   JavaScript copies of the ranking rule to the same numbers, so it is verification, not
   a build step.

4. Leave `test` as a bare recipe that does NOT install. That is the house pattern: the
   fast inner-loop recipe assumes an installed tree, and `check` is the one that
   guarantees it. Add a one-line comment saying so, in the style of the existing
   comments in this file, which are unusually explanatory.

## Non-goals

- Do NOT add `pnpm install` to `test` itself. That would make the common inner-loop
  command slow and would diverge from the three sibling packages.
- Do NOT change `package.json`, `pnpm-lock.yaml`, or any test file. The dependency is
  correctly declared; this is purely a missing recipe.
- Do NOT touch another package's Justfile.
- Do NOT add a `check` recipe to the repo-root Justfile.

## VERIFY

From `search/0.1.0`:

1. `just check` exits 0. It must install first, so this passes even from a tree whose
   `node_modules` is incomplete — which is the whole point of the bird.
2. `rg -n '^check: build' Justfile` returns exactly one hit.
3. `rg -n '^test:' Justfile` still returns exactly one hit, and the recipe body still
   does NOT contain `pnpm install`.
4. Report which commands you put in `check`, and whether you included `parity`.