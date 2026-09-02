# CLAUDE.md — rookery

The `@rookery` family of [Rheo](https://rheo.ohrg.org) Typst packages: atomic,
interlinked, transcludable notes (`core`), fuzzy search over them (`search`),
a dated lifecycle log (`timeline`), and todos/epics/a dependency DAG
(`todos`). Each package lives in `<name>/<version>/` (e.g. `search/0.1.0/`)
and mirrors the same layout: `typst.toml`, `src/`, a `Justfile`, and
`flake.nix`. Two of the four (`search`, `todos`) also ship JS via
`package.json`/vite — see "Pure-Typst packages" below for the two that
don't.

This repo was split out of `rheo-packages` (`freecomputinglab/rheo-packages`)
on 2026-08-30, once `@rookery` needed a repository URL of its own to resolve
as a git-backed namespace — see that repo's `CLAUDE.md` and its
`rheo-packages-prerelease-coords` decision record for why coordinates never
change and a namespace is instead backed by a git ref declared in a
project's `rheo.toml`.

`search` (fuzzy search over a rookery — ranking, a JSON index, an embeddable
search bar, and an overlay search modal) imports `core` for its `ideas()` and
`note-href()` primitives. It is built like every other JS package here; core
is not. A project using it must import BOTH in its own `.typ` files — see
that package's readme for why.

`todos` then imports `search` in ONE file, `panel.typ`, which skins
`#filter-panel` into a version whose pills know the todo graph. That edge was
forbidden until it was needed: `ready` and `blocked` are derived in `todos`
and nowhere else, so a panel that cannot press them is the one thing every
consuming site hand-rolls. `#todos-search` still reaches for nothing in
`search` — see that package's `search.typ` for which half of the old rule
still holds.

## Build

- Per package: `cd <name>/<version> && just build` (copies/bundles `src/` into
  `dist/`, where applicable). `dist/` is gitignored — it is a build artifact.
- All packages: `just build` at the repo root (walks every nested `Justfile`).
- There is no separate linter. "Lint" = the package builds and its demo/test
  project compiles with `rheo compile`.

## Comment style

A comment here describes the code as it stands. Not how it got that way, not
what it replaced, not which version moved it — a reader arriving cold needs the
current shape and the reasons it holds, and everything else is a diff they can
read in `jj log` if they want it.

- **Describe the present.** Say what the code is and why it is that way. Never
  what it used to be, what moved where, which release changed it, or that
  something "is gone". "The scorer lives in `score.typ`" is worth a line; "the
  scorer used to live in `tagquery.typ`" is worth none.
- **No issue ids.** Never name a beads issue, a bookmark or a branch. The
  argument for a line has to stand on its own, because most readers of it have
  no access to the tracker and no interest in one.
- **Keep the measurement, drop the lab notebook.** A number that justifies a
  constant stays, and says what it buys: 48 terms, a 40% document-frequency
  ceiling, 12 keyword chips. The machine it was measured on, the date, the
  baseline it beat and the alternatives that lost do not — unless a future
  reader would otherwise retune the number, and then one sentence, not a
  paragraph.
- **One header per file, no interior banners.** The first comment block says
  what the file is. A `// ---- Some Section ----` divider restating it is
  forbidden: the module is the section, and a file needing dividers is a file
  wanting to be two.
- **Comment the non-obvious.** A comment restating the line under it earns
  nothing. What earns its place: a constraint the code cannot express (a
  stylesheet rule the script depends on, an import order a closure makes
  load-bearing), a contract a caller would otherwise get wrong, a rule shared
  with another language.
- **Declarative and concise.** Present tense. Emphasis capitals are for the one
  claim in a block that carries it, not for every second clause, and a comment
  should not argue with mistakes its reader has not made yet. Aim for files
  where comments are a minority of the lines.

The one exception is **parity**. A comment may name its counterpart in the other
language — `score.typ` naming `src/score.js`, `tagquery.typ` naming
`src/tagquery.js`, either naming `just parity` as what pins them — because that
is a present-tense fact about how the code is arranged, and the two halves
cannot be changed apart.

## Local development against a live rheo project

`@rookery/<pkg>` resolves from the Typst package cache
(`~/.cache/typst/packages/rookery/<pkg>/<version>`). As in `rheo-packages`,
this is a REAL directory that can hold either a symlink into a checkout or a
downloaded copy of a published release — check which one is there before
trusting an edit to show up:

```sh
ls -la ~/.cache/typst/packages/rookery/<pkg>/     # symlink, or a real directory?
mkdir -p ~/.cache/typst/packages/rookery/<pkg>
ln -s "$PWD/<pkg>/<version>" ~/.cache/typst/packages/rookery/<pkg>/<version>
```

Note the link path ends in the VERSION and must not exist yet. `ln -sfn
TARGET DIR` where `DIR` already exists as a directory writes the link
*inside* it, leaving a self-referential nested symlink — `rm -rf` the stale
entry first rather than trying to overwrite it, then confirm with `jj status`
that nothing landed in the tree.

Then `just build` the package (skip this for `core`/`timeline`, the two
dist-less pure-Typst packages — see "Pure-Typst packages" below) and `rheo
compile` a test project that imports it. No per-package devShell needed
either for most work: this repo's own root `flake.nix`/`.envrc` provide
`just` and `typst`, and direnv finds them by walking up from anywhere under
the repo. `search/0.1.0` carries its own `flake.nix` on top of that, for
`node`/`pnpm` pinned to that package specifically.

## Pattern: consuming the injected `rheo-context`

Core rheo injects per-file build context that a package cannot read
implicitly — a Typst function captures its definition scope, not the call
site. There are two valid patterns, depending on what the package needs.

### Pattern A — template packages: explicit `ctx:`

A package that needs the CURRENT FILE's own handle (for a per-page template,
nav, etc.) takes it as an explicit parameter, because only the call site (the
vertebra itself) has `rheo-context` in scope:

```typ
#import "@rookery/<pkg>:x.y.z": template
#show: template.with(ctx: rheo-context())
```

**Guard requirement (do this in every package using this pattern):** assert
that `ctx` is a valid rheo-context and fail with a message pointing to rheo.
Put the assert at the top of the template, before any use of `ctx`:

```typ
#let template(ctx: none, doc) = {
  assert(
    type(ctx) == dictionary and "handle" in ctx,
    message: "@rookery/<pkg>: the template needs the per-file `rheo-context` "
      + "injected by Rheo. Apply it as `#show: template.with(ctx: rheo-context())` "
      + "and compile the project with Rheo (https://rheo.ohrg.org), not native Typst.",
  )
  // ...
}
```

This catches the common misuses: `ctx` omitted, passed as `none`, or not
rheo-context-shaped.

**Detect a rheo build before calling `rheo-context()`** rather than letting
pure native `typst compile` hard-error on an unbound variable:

```typ
#let ctx = if "rheo-context" in sys.inputs { rheo-context() } else {
  panic("@rookery/<pkg>: compile this project with Rheo (https://rheo.ohrg.org), not native Typst.")
}
```

`sys.inputs` is global to the bundle compile, so it is readable even where
the per-vertebra `rheo-context()` binding is not — this gives a native-Typst
build the friendly panic message instead of Typst's own
`unknown variable: rheo-context`. Still true, and still worth the warning:
**any in-file fallback binding of `rheo-context` clobbers rheo's real
injection.** An `#import "@rookery/<pkg>": rheo-context` sentinel, or a
top-level `#let rheo-context = ...`, both shadow the injected value under
rheo (the injection is prepended, so a later import/let wins). So do NOT
ship a package-level `rheo-context` fallback binding — it breaks the rheo
build; use the `sys.inputs` guard above instead.

### Pattern B — packages that work without rheo: feature-detect

A package that doesn't need the CURRENT FILE's handle — only the shared
spine-wide data, or nothing rheo-specific at all — should instead detect
rheo's presence rather than require it. This is the pattern for a package
whose primary supported mode is running under plain `typst compile` with no
rheo present at all.

- Shared spine data (title, spine tree, etc.) is reachable from ANY scope via
  `sys.inputs`, not just the injected per-file binding:

  ```typ
  #let rheo-context() = sys.inputs.at("rheo-context", default: (spine-flat: ()))
  ```

  Falls back to an empty/absent spine when built without rheo — no assert,
  no error, because running without rheo is the primary supported mode for
  this kind of package. For the exact keys `sys.inputs.rheo-context` carries
  and their stability, see rheo core's `docs/contract.md` rather than
  re-deriving the field list here.
  **`sys.inputs.rheo-context` carries no `handle`** (it is bundle-global,
  not per-file) — a package needing the CURRENT file's own handle still
  needs Pattern A's `rheo-context()` or `state("rheo-handle")` below.
- The CURRENT OUTPUT PAGE's own handle (if needed) is `state("rheo-handle")`,
  which rheo publishes per page in `rheo-page-init` (rheo core's
  `crates/core/src/typ/rheo.typ`; the checkout is at `/home/lox/code/_fcl/rheo`
  on this machine) — readable from package scope without any `ctx:`
  parameter.
- `@rookery/core` uses this pattern throughout and takes NO `ctx` parameter at
  all: see `core/0.1.0/src/lib.typ`'s `_rheo-ctx()`/`_target()` helpers.

DO NOT assert or panic when rheo is absent under this pattern — that's
Pattern A's job for packages that genuinely can't function without rheo.
Pick the pattern by whether the package's primary mode is "always under
rheo" (A) or "works standalone, rheo optionally enhances it" (B).

## Pure-Typst packages

`core` and `timeline` are pure Typst (+ CSS) — no `package.json`, no
`pnpm-lock.yaml`, no build step at all: `typst.toml`'s `entrypoint` and
`css_stylesheet` point straight at `src/` — editing `src/` takes effect
immediately, nothing to rebuild or forget to re-run.

`search` and `todos` are ORDINARY built packages — `package.json` + vite.
`search` shares core's name-space and hard-imports it, and is nonetheless
built because search is only worth having with JavaScript; core ships none.
Splitting kept that true instead of trading it away.

The built shape is narrower than "everything lives in `dist/`", though: a
built package's `entrypoint` and `css_stylesheet` point at `src/` — vite only
copies those files into `dist/` byte-identically, so the manifest names the
originals — and `dist/` holds ONLY the built JavaScript bundle
(`dist/lib.js`). Each also declares a `[tool.rheo.source.html]` block listing
its unbundled `src/*.js` files as ES modules, dependency-first, for when the
package is resolved from a git ref rather than a release: see
`rheo-packages`' `rheo-packages-prerelease-coords` decision record for why
that split exists. This is what lets a package be consumed straight off a
git ref with no build step at all: `src/` is checked in and carries a
working entrypoint, stylesheet AND (via the source block) JavaScript on its
own; only the optimized bundle is genuinely missing outside a release.

`.github/workflows/publish-packages.yml` handles two cases per package: a
`package.json` present means `pnpm install && pnpm run build`; its absence
means no build step at all. The release archive step tars `src/` always, and
ADDS `dist/` on top of it when the build produced one — so `core`/`timeline`
ship their `src/` directly, and `search`/`todos` ship both `src/`
(entrypoint, stylesheet, source-mode scripts) and `dist/` (the optimized JS
bundle).

## Cross-package data without an import: the beacon protocol

A package can contribute data to another package it has no import
relationship with, in either direction, by emitting a `#metadata((..))
<label>` beacon and letting the other side `query()` for it back. `core`'s
own cross-vertebra beacons (`<rheo-meta:<handle>>`) rely on the same fact:
rheo compiles a whole project in one `typst::compile` pass, so a `query()`
at bundle root sees a beacon from any vertebra. `@rheo/feeds` in
`rheo-packages` carries a second, fuller worked example of this pattern
(`<feeds:item>`) alongside the accessor-call alternative, if a template for
either is useful here.

This is the FALLBACK, not the first thing to reach for. Where the data
already has a synchronous accessor — a function you can call directly, the
way `core`'s `ideas()` hands back every note as a plain array — call it
directly instead, with a small function reshaping its output for the
consumer and no beacon or `query()` involved.
