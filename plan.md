# Plan — `@rookery/slipshow`

## What this document is, and how to use it

This is an implementation plan for a new package in this repo,
`@rookery/slipshow`. It is written to be handed to an agent whose job is to
**turn it into beads** (`br` issues) and nothing else.

If you are that agent:

- Part 4 below contains eleven bead specifications. Create one `br` issue per
  spec, using the title, type, priority, slug and description given. The
  description text is written to be used **verbatim** — it is already
  self-contained, located, and carries a VERIFY section.
- Wire the dependencies listed in Part 5 with `br dep add`.
- `br init` has already been run here; the prefix is `rookery` and `.beads/` is
  already covered by this repo's `.gitignore`.
- After creating them, verify with `br list --status=open`. `br` can silently
  revert a mutation by reimporting its own export, so re-check rather than
  assuming they stuck. There is nothing to commit — `.beads/` is untracked.
- Do **not** implement anything. Creating the beads is the whole job.

Parts 2 and 3 are the research and the settled design decisions behind the
beads. They exist so that a bead's description can stay focused while the
reasoning remains recoverable. If a bead seems to contradict Part 3, Part 3
wins and the bead is wrong.

---

## Part 1 — The goal

`@rookery/slipshow` presents a rookery as an **endlessly scrolling
presentation**, in the spirit of <https://github.com/panglesd/slipshow>. Each
"slip" is an idea, rendered with `@rookery/core`'s own card styling — the left
border and the tab ("hat") as seen on <https://rookery.ohrg.org/>.

It exports:

- `#slipshow(..)` — the container, an ordered list of ideas plus deck-wide
  settings.
- `#slip(..)` — a wrapper around core's `#idea` that augments it with
  presentation options (`fullscreen`, `background`, `enter`, `order`, `class`),
  in exactly the way `#todo` in `@rookery/todos` augments `#idea`.

Everything this package ships is demonstrated inside the package itself, by the
`demo/rheo/` fixture bead `demo` builds. That fixture is both the lint (this
repo's definition of one — see part 2.1) and the worked example a consuming
project reads: it exercises every definition route and, in `content/deck.typ`, a
realistic multi-slip presentation of the kind the package exists to render. **No
bead in this plan touches a project outside this repo.**

---

## Part 2 — Scouted context

Everything in this part was verified against the source on 2026-09-03. Where a
line number is given it was read, not guessed.

### 2.1 Repo conventions

From `/home/lox/code/_fcl/rookery/CLAUDE.md` — read it before writing any code
or comment in this repo:

- Each package lives at `<name>/<version>/` and carries `typst.toml`, `src/`, a
  `Justfile`, and (where it ships JS) `flake.nix`.
- `core` and `timeline` are **pure Typst** — no `package.json`, no build step.
  `search` and `todos` are **built** — `package.json` + vite.
- A built package's `entrypoint` and `css_stylesheet` point at `src/` (vite
  copies them byte-identically), and `dist/` holds **only** the bundled JS
  (`dist/lib.js`). Each built package also declares `[tool.rheo.source.html]`
  listing its unbundled `src/*.js` as ES modules, **dependency-first**, so the
  package can be consumed straight off a ref with no build step.
- "Lint" here = the package builds and its demo project compiles with `rheo
  compile`. There is no separate linter.
- **Comment style** is strict: describe the present, never the history; no issue
  ids; one header per file and no interior `// ---- Section ----` banners; keep
  the measurement, drop the lab notebook; comment the non-obvious constraint,
  not the obvious line. The one exception is **parity** — a comment may name its
  counterpart in the other language, because that is a present-tense fact about
  how the code is arranged.

`slipshow` is a **built** package: it ships a JavaScript camera engine.

### 2.2 What auto-discovers, and the one CI file that does not

- `.github/workflows/publish-packages.yml` line 88 discovers packages with
  `find . -name typst.toml`. **Do not edit it.**
- The root `Justfile` line 4 walks `find . -mindepth 2 -name Justfile` and runs
  the DEFAULT recipe in each directory found. **Do not edit it.** Note the
  consequence for any `Justfile` this plan adds: whatever its first recipe is,
  the root build runs it.
- **`.github/workflows/check.yml` does NOT auto-discover, and the plan's earlier
  claim that no CI file needs editing was wrong about this one.** It is a
  hand-written list of per-package steps — `cd search/0.1.0 && just build && just
  parity`, `cd todos/0.1.0 && just build && just test && just test-js`, `cd
  core/0.1.0/demo/rheo && just check`, and so on. A new package with no step here
  is a package whose build, unit fixture and demo NEVER RUN IN CI while the
  workflow reports green. Bead `demo` owns that edit; no other bead touches CI.

One thing already in `check.yml` that this package gets for free: the step
"Resolve the `@rookery` namespace from this checkout" symlinks the WHOLE
namespace (`ln -s "$PWD" "$cache/rookery"`), so `@rookery/slipshow:0.1.0`
resolves in CI with no further setup. Local machines use per-package links
instead — see bead 1 step 11, and note that the two layouts are alternatives,
not a sequence.

`just check-versions` (root `Justfile` line 44) is the lint that pins every
`@rookery/<pkg>:<ver>` literal — in readmes, doc comments, `.marrow.typ` and
cross-package imports — against the manifest that declares it, and checks that
`<name>/<version>/` matches. It reads dotfiles and readmes. Run it.

### 2.3 The rheo floor

Every package in this family declares `min_version = "0.6.2"`. The reasoning is
in `core/0.1.0/typst.toml`'s comment: 0.6.1 is where rheo learned to resolve a
namespace it does not ship (via a project's `[packages.<ns>]` table), and 0.6.2
is where it learned to locate a package fetched from a ref rather than by
probing Typst's directory layout — before which every page minted from marrow
went missing on a build that succeeded and warned about nothing.

`slipshow` inherits that floor because it imports `@rookery/core:0.1.0`. Do not
lower it.

### 2.4 `#idea` — what a slip is made of

`core/0.1.0/src/idea.typ` line 31. Signature:

```typ
#let idea(level: 1, title: none, tags: (), exclude-tags: (), created: none,
          show-date: false, show-tags: false, show-context: auto,
          show-backlinks: auto, ..args) = { .. }
```

Three call forms all work via the positional sink: `#idea[body]`,
`#idea("name")[body]`, `#idea(<name>)[body]`.

It renders (html/epub branch, idea.typ line 347 onward) a
`figure(kind: IK)` marker wrapping `<div class="idea-box">`, whose
`.idea-head` holds the `.idea-tab`. **The tab is the "hat"**: a flex row whose
`::before` stub reaches back across the card's own `padding-left` plus the left
rule's width, so it ends on that rule's outer edge and the corner has no notch
(`core.css` lines 170-190). This is the look the user wants preserved.

The marker's body carries a `#metadata` payload (idea.typ line 177):

```typ
#metadata((body: body, title: title, label: note-label, named: named,
           base: base, level: level, tags: tags))
```

`tags` there is the normalized **dictionary**, values included.

**Verified, and it is what makes bead 4 possible:** the `tags` in that payload
and the `tags` in the registry record (line 288, `tags: tags`) are THE SAME
local variable, normalized once above both. So the two definition routes do not
merely agree by convention — they read one value, and bead 4's VERIFY can assert
exact dictionary equality rather than a subset.

### 2.5 The registry record — and why options must be tags

`idea.typ` line 288 builds the registry record. Its fields are fixed:
`title`, `label`, `raw`, `body`, `created`, `origin`, `links`, `tags`,
`show-context`, `show-backlinks`.

**`tags` is the only extensible channel.** A slipshow can be defined by a tag
query, in which case it only ever sees a record. So `#slip`'s options must live
in tags or they cannot survive that route. This constraint decides the whole
data model.

Tag values may be arbitrary Typst values. A plain tag's value is `none`.

### 2.6 `tagged-idea` — and the trap

`core/0.1.0/src/idea.typ` line 491. It is a **factory** returning an `#idea`
variant that *prepends and merges* one tag.

The banner above it (lines 469-473) records the trap explicitly:

> **THE TRAP, do not reintroduce:** `#let note = idea.with(tags: (note: none))`.
> An explicit `tags:` argument at the call site OVERRIDES a value bound by
> `.with()`, so `#note("x", tags: ("draft",))` would silently drop "note".

So `#slip` must be built on `tagged-idea`, never `idea.with(..)`.

Lines 474-490 carry a second requirement that is a **correctness bug if
missed**: `tagged-idea`'s returned closure calls the `idea` captured in
*package* scope, so a project's `#let idea = idea.with(exclude-tags: E)` does
not reach a wrapper built on it — the wrapper keeps hatching the very notes the
project asked to exclude, on a build that succeeds while doing it. `#slip` must
therefore accept `exclude-tags:` and pass it through. (`#todo` does not; do not
take its omission as licence.)

### 2.7 `#todo` — the wrapper pattern to copy

`todos/0.1.0/src/todo.typ` line 126, with its tag mapping in
`todos/0.1.0/src/tags.typ` line 148 (`todo-tags`). Read both. The shape:

- Built on `tagged-idea(TODO-KEY)`.
- Consumes its own named options, folds them into tag keys via a **pure**
  `todo-tags(..)` in a separate module.
- Forwards `..args` untouched, which is what keeps all three id forms and every
  core named argument working.
- Namespaces its keys (`todo-`, `epic-<name>`) because **a key becomes a CSS
  class fragment** and a bare name is generic enough for two packages to claim.
- Validates any name that becomes a class fragment against
  `^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$` (todo.typ line 238).

`tags.typ`'s header documents a **three-surface split** that `slipshow` adopts
wholesale:

1. **Flat, key encodes the value** — value `none`. Renders as a pill, emits an
   `.idea-tag-<key>` class, and is filterable by core's `tags:` *and* by
   `@rookery/search`'s query language. Use for a small finite domain.
2. **Valued** — renders no pill but **is** still presence-filterable by key,
   because rookery's tag predicate tests keys (`"a" in (a: 1)` is `true`).
3. **Not our tags** — the caller's own `tags:`, merged **last** so their keys
   win. Typst dictionary `+` is right-wins.

Plus a rule worth restating: **empty means absent.** `closed: false` emits
nothing (tags.typ lines 143-147), because a key valued `false` would read as an
assertion about the note to anything testing for the key.

`todo-tags` also keeps a **local six-line copy** of core's four-form tag
normalizer (`_norm-tags-local`, tags.typ lines 111-121) rather than importing
core's private `_norm-tags`, on the stated grounds that reaching into another
package's underscore names creates a dependency on an internal that can move
without notice.

### 2.8 `ideas()` — the registry accessor

`core/0.1.0/src/data.typ` line 297:

```typ
#let ideas(tags: none, match: "any", index: none, values: false) = { .. }
```

Two facts the plan works around:

- It returns rows **sorted by id** (line 304, `.sorted(key: p => p.at(0))`). Id
  order is almost never presentation order, so the query route needs an
  explicit sort.
- Its filtering is only `tags:` plus `match: "any"|"all"`. **No boolean
  operators.**

Row fields: `id`, `name`, `title`, `text`, `label`, `tags` (names only),
`body` (**plain text**, not renderable content), `href`, `page`, `created`, and
— only with `values: true` — **`tags-dict`**, the full tag dictionary with
arbitrary values. Always pass `values: true`; slip options live in tag values.

Must be called inside a `#context` block; it is not itself a context function,
because a Typst context function may only return content and the point is to
return data.

### 2.9 Rendering a queried note

Rows carry only plain-text bodies, so the query route needs a renderer:

- `#window(name, ..)` — `core/0.1.0/src/window.typ` line 62. Core's public
  transclusion renderer. Emits `.idea-window` with a `.idea-window-summary`
  carrying a `.idea-tab` — so a windowed note **has a hat and a left rule**
  without this package rebuilding core's markup. **This is the chosen
  renderer.**
- `#idea-body(name, depth: 1, limit: none)` — window.typ line 347. Body content
  with no chrome; what search's preview pane uses.

**The folded-state wrinkle is now RESOLVED, and needs no work in any bead.**
`#window`'s signature (window.typ line 65) carries `folded: false` as its
DEFAULT, and `transclusion.typ` lines 161-162 show what that renders:

```typ
let d-attrs = if folded { (class: "idea-window-details") } else {
  (class: "idea-window-details", open: "open")
}
```

So a plain `#window(id)` already emits `<details open>`. Bead 6 passes nothing,
bead 7 adds no forcing rule, and `core.css`'s
`.idea-window-details:not([open])` block is simply never matched inside a slip.

**One consequence that IS work, in bead 9:** the disclosure is a real native
`<details>`, so a viewer clicking a slip's `<summary>` collapses it. Since the
controller advances on a click anywhere in the deck, such a click would both
fold the slip and move the camera. Bead 9's click guard therefore bails on
`summary` as well as on `<a>`. Folding by hand afterwards is harmless and stays
available; folding as a side effect of advancing is not.

Also verified, so bead 6 need not hedge: `#window`'s positional is variadic and
every name it receives goes through core's `_norm` (window.typ lines 100-110),
which strips the `idea:` prefix if present. So `#window(row.id)` and
`#window(row.name)` are equivalent — use `row.id`. Its `depth: auto` default
resolves to 1, which is the wanted "render this note, collapse any window inside
it to a permalink".

**Do not modify `@rookery/core`.**

### 2.10 The `a&b` query language lives in `search`, not `core`

`search/0.1.0/src/tagquery.typ` — `parse-tag-query` (line 58),
`eval-tag-query` (line 162), `split-query` (line 193). Grammar, from its header:

```
(a|b)&c     `&` binds tighter than `|`; `()` groups
!draft      `!` negates, binds tightest, right-associative
a\&b        `\` escapes the next cluster into the current atom
```

The escape set is exactly `( ) | & ! \` and is frozen. Parsing never fails —
every malformed form repairs itself and records a reason, because in a live
search box every prefix of a valid query is typed on the way to it. There is a
parity-pinned JavaScript twin (`src/tagquery.js`, pinned by `just parity`).

`core` has none of this. See Part 3.4 for what `slipshow` does about it.

### 2.11 Slipshow itself — what is and is not available

Researched because it determines whether the engine can be reused:

- The current tool is **v0.12.0** (Aug 2026), an **OCaml CLI** compiling an
  extension of Markdown to a standalone HTML file. Its releases ship only
  platform binaries and a source tarball — **no engine JS, no documented
  embedding contract.**
- **Its browser engine is OCaml too, and it is GPLv3.** Both facts were checked
  against the repository, and both are load-bearing:
  - `src/engine/runtime/dune` is `(executable (modes js) (name main) (libraries
    communication brr normalization browser rescale table_of_content undoable
    step universe drawing_controller messaging fast gui toolbar
    mouse_disappearing))`, with a rule copying `main.bc.js` to `slipshow.js`. So
    the engine reaches the browser through **js_of_ocaml + brr**. The repository's
    language breakdown is 7.0 MB OCaml and **zero bytes of JavaScript**.
  - `LICENSE.md` places the main body of the code, `src/engine` included, under
    **GPL v3**; the enumerated exceptions are vendored libraries, static
    JavaScript files and bundled fonts, none of which covers the engine. The MIT
    licence noted below belongs to the ABANDONED npm 0.0.33 Slip.js, not to
    anything current.
  - Architecturally the engine is a **scaled-coordinate "universe"** the whole
    document is transformed inside (`universe/`, `rescale/`), coupled to its own
    `<slip-slip>` DOM — not a scroll-based camera over ordinary document flow.
- The npm package `slipshow` stopped at **0.0.33 (Sept 2024)**, the abandoned
  pre-rewrite "Slip.js". It *does* ship a standalone browser bundle
  (`dist/slipshow.cdn.min.js`) plus `dist/css/slip.css`, MIT, with a genuinely
  hand-authorable DOM — `<slip-slipshow>` / `<slip-slip>` / `<slip-title>` /
  `<slip-body>` and attributes `pause`, `down-at`, `up-at`, `enter-at`,
  `center-at-unpause`, `emphasize-at`, `chg-visib-at`, `delay`. Two years stale,
  and its vocabulary already diverges from the current docs.
- The **current** action vocabulary
  (<https://docs.slipshow.org/en/stable/actions-api.html>) is: camera —
  `down`, `up`, `center`, `scroll`, `focus`, `unfocus`; visibility — `pause`,
  `pause-block`, `step`, `reveal`, `unreveal`, `static`, `unstatic`; plus
  drawing, carousels, speaker notes, media and custom scripts.

Two feasibility checks were run and **passed**:

- Typst emits custom elements and arbitrary attributes intact
  (`<slip-slip id="one">`, `<slip-body down-at="1">`), so either DOM was open.
- An `#import` inside an **untaken branch is not resolved** — a file importing a
  nonexistent package inside `#if false { .. }` compiles fine. So a gated
  import is technically possible. It is not used; see Part 3.4.

### 2.12 `IK` is exported, and how the re-export chain gets it there

`IK` is defined in `core/0.1.0/src/pure.typ` line 417 (`#let IK = "rheo-idea"`),
which `base.typ` line 46 pulls in with `#import "pure.typ": *`, which `lib.typ`
line 40 pulls in the same way. `#import "x.typ": *` re-exports transitively —
core's own `lib.typ` header states this is what keeps the package a single
import — so `#import "@rookery/core:0.1.0": IK` resolves. Bead 4 can rely on it
and does not need its fallback hunt.

### 2.13 How this repo tests a Typst package, and how it tests a panic

The plan's beads originally said "compile a scratch file". That is not this
repo's shape, and a scratch file is thrown away — so the assertions it proves
are not gated by CI and rot immediately. Every package here instead keeps a
PERSISTENT fixture plus a `test` recipe:

```
# core/0.1.0/Justfile, timeline, todos — all the same shape
test:
    typst compile --features html --root . --format pdf test/units.typ /dev/null
    @echo "units OK"
```

There is no test runner. `assert`/`assert.eq` inside `test/units.typ` fail the
compile with a line number, and a passing compile is the green light. Three
details are load-bearing and are copied, not re-derived:

- `--features html` is **mandatory regardless of output format**: `std.target` is
  gated by the feature and core's `src/lib.typ` reads it at import time.
- `--root .` so the fixture's `#import "/src/lib.typ"` resolves against the
  package.
- `--format pdf` writing to `/dev/null`, because Typst cannot infer a format
  from that path and nothing here is rendered — only asserted.

**Typst has no `try`/`catch`, so an `assert` cannot test that something PANICS.**
Several beads below ask for exactly that (a rejected `enter` name, a
`resolve-slips()` with neither `slips:` nor `tags:`). A panic case is therefore
one file per case plus a NEGATIVE compile, asserted in a shell script — the same
shape as the `check.sh` files the demo fixtures already use:

```sh
# slipshow/0.1.0/test/panics.sh — a panic is proved by a compile that FAILS.
# One file per case: a panic aborts the whole compile, so two cases in one file
# only ever exercise the first.
expect_panic() {   # $1 = file, $2 = substring the message must contain
  if out=$(typst compile --features html --root . --format pdf "$1" /dev/null 2>&1); then
    echo "FAIL: $1 compiled, expected a panic"; exit 1
  fi
  case "$out" in *"$2"*) ;; *) echo "FAIL: $1 panicked without '$2':"; echo "$out"; exit 1;; esac
}
```

Bead 1 creates `test/units.typ`, `test/panics.sh` and the `test` recipe as
skeletons; beads 2, 3, 4 and 5 each APPEND their assertions to those two files
rather than writing anything scratch.

---

## Part 3 — Settled design decisions

These are decided. A bead contradicting one of them is wrong.

### 3.1 Our own camera engine, in plain JavaScript

There is no maintained embeddable slipshow engine (Part 2.11), so this package
implements the slip **model** with its own JS: vite-bundled like `search` and
`todos`, zero runtime dependencies, camera bound to the rookery cards. The
readme must say plainly that it does not embed slipshow's own JavaScript.

**Neither OCaml/js_of_ocaml nor TypeScript. Plain, hand-written ES modules.**
This was considered on the merits — slipshow's own engine is OCaml compiled with
js_of_ocaml (Part 2.11), so reusing its logic through the same toolchain is the
obvious idea — and rejected for three reasons, in descending order of force:

1. **Licence.** slipshow's engine is GPLv3. This package declares MIT, like the
   rest of the family. Porting or linking that code makes this a derivative
   work: the manifest's licence would be false and every rookery site shipping
   the bundle would be distributing GPLv3 JavaScript. That rules out reuse
   whatever language we write in.
2. **`[tool.rheo.source.html]` requires checked-in, browser-runnable ES
   modules.** That block exists so a package resolved from a git ref works with
   NO build step (see `rheo-packages`' `rheo-packages-prerelease-coords`
   record), and every consumer currently tracks the `0.1.0` branch rather than a
   release — so it is the ordinary consumption path, not an edge one.
   js_of_ocaml emits one generated blob, which could only satisfy that block by
   being committed, contradicting `dist/` being a gitignored build artifact.
   **The same objection rules out TypeScript**: the browser cannot run `.ts`.
3. **Size, against a package whose whole point is to stay small.** `camera.js`
   is two exports over `{top, height}` and `{height, width}` — about twenty
   lines of arithmetic, already scoped and unit-testable with plain numbers by
   bead 8's pure/controller split. A brr-sized runtime blob to type that is a
   trade in the wrong direction, and it would add opam, dune and js_of_ocaml to
   a repo of vite+pnpm packages, an OCaml pin to `flake.nix`, and an opam step
   to CI.

There is also little to reuse even setting the licence aside: slipshow's camera
lives in its `universe/`+`rescale/` scaled-coordinate model, coupled to its own
`<slip-slip>` DOM, where this package scrolls ordinary document flow over
rookery cards.

Do not reopen this in a bead.

### 3.2 Camera-only

A slip is **fully rendered**; only the viewport moves. Implement `scroll`, `up`,
`down`, `center`, `focus`, `unfocus`.

**Do not implement** `pause`, `pause-block`, `step`, `reveal`, `unreveal`,
`static`, `unstatic`, drawing, carousels, speaker notes, media or custom
scripts. No fragment or incremental-reveal styling anywhere.

### 3.3 A slipshow is a flat list

Ideas nested inside a slip are ordinary content; slipshow does not look into
them and needs no nesting-depth setting. There is no sub-slip and no zoom-into-a-
child behaviour.

### 3.4 `tags:` takes a spec **or a predicate** — and there is no search dependency

`#slipshow`'s `tags:` accepts either a core-style spec (string/array, with
`match: "any"|"all"`) **or a predicate function** `tags-dict => bool`. A project
wanting the full `a&b` grammar builds the predicate itself:

```typ
#import "@rookery/search:0.1.0": parse-tag-query, eval-tag-query
#slipshow(tags: t => eval-tag-query(parse-tag-query("a&b").rpn, t))
```

This keeps `search` a pure extension point with **zero dependency edges** and no
conditional-import trickery. Without `search`, a project still has explicit
orderings plus core's `any`/`all`.

**Do not** add a `search` import, a `search: true` flag, or a reimplementation
of the grammar. Do not move `tagquery.typ` into `core`.

### 3.5 Both definition routes recover the same options

- **Tag query** → registry rows → `ideas(values: true).tags-dict`.
- **Explicit array** → rendered content → walk the `figure(kind: IK)` marker's
  `#metadata` payload (Part 2.4), the way core's own `_flatten` IK rule does.

These must yield the identical dictionary, so a `#slip` behaves the same however
the slipshow was defined. Bead 4's VERIFY asserts exactly this.

### 3.6 Sort orders

Three, for the query route: an explicit `order:` array of ids; `"created"`; and
`"slip-order"` (the default), reading the valued `slip-order` tag. An explicit
`slips:` array is ordered by construction and `order:` is **rejected** alongside
it rather than silently ignored.

### 3.7 Paged output is transparent

On a paged target `#slipshow` renders the ideas exactly as core would — no slip
wrappers, no page breaks of its own, no title page, no slide numbering. The
presentation is an HTML concern.

### 3.8 `#slip`, not a re-exported `#idea`

The package exports `#slip`, an augmented wrapper. It does **not** re-export
core's `#idea`. A plain `#idea` remains usable inside a slipshow and simply
takes the deck defaults.

### 3.9 One vocabulary: `enter:`, and no `transition:` or `duration:`

An earlier draft of this plan gave `#slip` both a `transition:`
(`none|scroll|fade|focus`) and an `enter:` (`top|center|whole`). **Both were
wrong and are now settled otherwise.** The two arguments named the same thing —
`enter: top|center|whole` is `up|center|scroll` under other names — while
`transition`'s own values were not camera actions at all, so bead 9 would have
handed `"fade"` to `targetFor` and bead 8 would have thrown by its own rule.

- **`transition:` is DROPPED.** `enter:` is the only arrival argument, and its
  domain is the camera action set itself: `("scroll", "up", "down", "center",
  "focus")`. Deck-wide default `"scroll"`. One vocabulary, shared verbatim by
  `tags.typ`, the `data-enter` attribute, and `camera.js`'s `targetFor`.
- **`duration:` is DROPPED.** The controller scrolls with
  `window.scrollTo({behavior: "smooth"})`, which takes no duration — the browser
  owns the timing. Keeping the argument would have meant accepting it, emitting
  `data-duration`, and silently ignoring it. There is no rAF tween and no
  easing function anywhere in this package.

No bead may reintroduce either name, a `fade`, or an animation-timing argument.

### 3.10 The tag surface

| key | surface | from |
| --- | --- | --- |
| `slip` | flat | base key, every slip |
| `slip-fullscreen` | flat | `fullscreen: true` |
| `slip-enter-<action>` | flat | `enter:`, from the camera action set |
| `slip-background` | valued | `background:` |
| `slip-order` | valued | `order:` |
| `slip-class` | valued | `class:` |

Flat keys are deliberate: they stay filterable by core's `tags:` and by search's
grammar, **and** they emit `.idea-tag-<key>` classes, so fullscreen and
per-action styling can be pure CSS with no JS reading attributes.

---

## Part 4 — The beads

Eleven. Create each with the given type, priority and slug; use the description
verbatim.

---

### Bead 1 — `scaf`

- **Title:** Scaffold the `@rookery/slipshow` package
- **Type:** task · **Priority:** 1 · **Slug:** `scaf`

**Description:**

Create the `@rookery/slipshow` package skeleton so every later bead has a
manifest, a build and a place to put code.

Background. `@rookery/slipshow` is a new package in the rookery family. It
presents a rookery's notes ("ideas") as an endlessly scrolling presentation, in
the spirit of https://github.com/panglesd/slipshow. It is a BUILT package (it
ships a JavaScript camera engine), so it follows `search`/`todos` rather than
`core`/`timeline`, which are pure Typst.

Repo root: `/home/lox/code/_fcl/rookery`. Read
`/home/lox/code/_fcl/rookery/CLAUDE.md` before writing any comment — it sets the
comment style for this repo (describe the present, no issue ids, one header per
file, no interior banners). The closest existing package to copy from is
`search`: `/home/lox/code/_fcl/rookery/search/0.1.0/`.

IMPORTANT, so you do not go looking for it: neither CI nor the root `Justfile`
needs editing to pick up a new package. Both auto-discover —
`.github/workflows/publish-packages.yml` line 88 walks
`find . -name typst.toml`, and the root `Justfile` line 4 walks
`find . -mindepth 2 -name Justfile`.

Steps.

1. Create `/home/lox/code/_fcl/rookery/slipshow/0.1.0/` and
   `slipshow/0.1.0/src/`.

2. Write `slipshow/0.1.0/typst.toml`:

```toml
[package]
name = "slipshow"
version = "0.1.0"
compiler = "0.15.0"
entrypoint = "src/lib.typ"
authors = ["The Free Computing Lab <https://freecomputinglab.ohrg.org>"]
license = "MIT"
description = "An endlessly scrolling presentation over @rookery/core ideas"
repository = "https://github.com/freecomputinglab/rookery"

[tool.rheo]
min_version = "0.6.2"

[tool.rheo.html]
js_scripts = "dist/lib.js"
css_stylesheet = "src/slipshow.css"

[tool.rheo.source.html]
js_scripts = ["src/camera.js", "src/slipshow.js"]
js_module = true
```

   The `min_version = "0.6.2"` floor is not arbitrary and must not be lowered:
   this package imports `@rookery/core:0.1.0`, whose own manifest declares that
   floor. See the comment on it in
   `/home/lox/code/_fcl/rookery/core/0.1.0/typst.toml`. Write a SHORT comment in
   your manifest saying the floor comes from core, not a longer retelling.

   `[tool.rheo.source.html]` lists the unbundled ES modules DEPENDENCY-FIRST for
   when the package is consumed from a ref rather than a release. `camera.js`
   before `slipshow.js` because the latter imports the former. Those two files
   do not exist yet — later beads create them. That is expected.

3. Write `slipshow/0.1.0/package.json`, copying the shape of
   `/home/lox/code/_fcl/rookery/search/0.1.0/package.json`:

```json
{
  "name": "rookery-slipshow",
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "build": "vite build"
  },
  "packageManager": "pnpm@10.21.0",
  "devDependencies": {
    "vite": "^8.0.5"
  }
}
```

4. Write `slipshow/0.1.0/vite.config.js`, mirroring
   `/home/lox/code/_fcl/rookery/search/0.1.0/vite.config.js`:

```js
import { defineConfig } from "vite";

export default defineConfig({
  build: {
    lib: {
      entry: "src/slipshow.js",
      formats: ["iife"],
      name: "RookerySlipshow",
      fileName: () => "lib.js",
    },
    outDir: "dist",
  },
});
```

5. Write `slipshow/0.1.0/Justfile`. `build` MUST be the FIRST recipe — the root
   `Justfile` runs the DEFAULT recipe in every directory it finds, so the first
   recipe here is what a repo-wide `just build` runs. Copy
   `/home/lox/code/_fcl/rookery/search/0.1.0/Justfile`'s shape and add a `test`
   recipe alongside it:

```
build:
    pnpm install
    pnpm run build

test:
    typst compile --features html --root . --format pdf test/units.typ /dev/null
    ./test/panics.sh
    @echo "units OK"

test-js:
    node --test test/*.test.mjs
```

   Three flags to copy rather than re-derive, each explained in
   `/home/lox/code/_fcl/rookery/core/0.1.0/Justfile`: `--features html` is
   mandatory whatever the output format (`std.target` is gated by the feature and
   core reads it at import time); `--root .` so the fixture's
   `#import "/src/lib.typ"` resolves against this package; `--format pdf` into
   `/dev/null` because Typst cannot infer a format from that path and nothing is
   rendered, only asserted. Write a SHORT comment saying so — do not retell all
   three at length.

   `node --test test/*.test.mjs` uses the glob and not a bare directory
   deliberately; the comment on `search`'s own `test` recipe records why.

6. Create the test skeletons the later beads append to. Beads 2-5 each add
   assertions to these; none of them writes a throwaway scratch file.

   - `slipshow/0.1.0/test/units.typ` — a file header comment saying it is the
     unit fixture, that there is no runner (a failing `assert` fails the compile
     with a line number, and a passing compile is the green light), and an
     `#import "/src/lib.typ": *`. No assertions yet.
   - `slipshow/0.1.0/test/panics.sh` — executable (`chmod +x`), with the
     `expect_panic` helper given in the plan's part 2.13 and no cases yet. Typst
     has NO `try`/`catch`, so a panic can only be proved by a compile that fails;
     that is the whole reason this file exists next to `units.typ`. One case per
     file, because a panic aborts the whole compile and a second case in the same
     file would never run.

7. Write `slipshow/0.1.0/.gitignore` — copy
   `/home/lox/code/_fcl/rookery/search/0.1.0/.gitignore` verbatim, then confirm
   it covers all three artifact directories this package will produce: `dist/`
   (the vite bundle), `demo/rheo/build/` (bead `demo`) and `test/build/`. Add any
   it misses. None of the three is tracked.

8. Copy `/home/lox/code/_fcl/rookery/search/0.1.0/flake.nix` to
   `slipshow/0.1.0/flake.nix` unchanged. It pins `node`/`pnpm` for this package.

9. Write a STUB `slipshow/0.1.0/src/lib.typ`. It is the entrypoint and it is a
   MANIFEST, not a place for code — the same rule as
   `core/0.1.0/src/lib.typ` and `search/0.1.0/src/lib.typ`. For now it needs
   only a file header comment stating what the package is and that the import
   order below is dependency order. Leave the import list empty; later beads add
   lines to it in dependency order.

10. Write a MINIMAL placeholder `slipshow/0.1.0/src/slipshow.css` (a file header
    comment and nothing else). It must exist because `typst.toml` names it as
    `css_stylesheet`; bead `css` fills it in.

11. Create minimal placeholder `slipshow/0.1.0/src/slipshow.js` and
    `slipshow/0.1.0/src/camera.js` (each an ES module with a one-line header
    comment) so `just build` succeeds now. Later beads replace them. Give each
    ONE trivial named export rather than leaving the file literally empty —
    `slipshow.js` is vite's `lib.entry`, and an entry with nothing in it makes
    vite warn about an empty chunk. Nothing needs to import them yet.

12. Symlink the package into the Typst package cache so a local rheo project can
    resolve it. Per `/home/lox/code/_fcl/rookery/CLAUDE.md`, the link path ends
    in the VERSION and must NOT already exist:

```sh
mkdir -p ~/.cache/typst/packages/rookery/slipshow
ln -s /home/lox/code/_fcl/rookery/slipshow/0.1.0 ~/.cache/typst/packages/rookery/slipshow/0.1.0
```

    That is the layout this machine already has — VERIFIED:
    `~/.cache/typst/packages/rookery/` holds one real directory per package
    (`core/`, `search/`, `timeline/`, `todos/`), each containing a `0.1.0`
    symlink into this checkout. Adding a fifth alongside them is exactly right.

    CAUTION from that same CLAUDE.md: `ln -s TARGET DIR` where `DIR` already
    exists as a directory writes the link INSIDE it, leaving a self-referential
    nested symlink. If the path already exists, `rm -rf` it first, then link,
    then confirm with `jj status` that nothing landed in the tree.

    The whole-namespace form (`ln -s "$PWD" "$cache/rookery"`) that
    `.github/workflows/check.yml` uses is the ALTERNATIVE, not an addition. Do
    not do both: under a namespace link the target resolves back into the repo
    where `slipshow/` already exists, and the per-package link then nests inside
    it. This machine is already set up the per-package way, so use that.

Do NOT.

- Do NOT edit `.github/workflows/publish-packages.yml` or the root `Justfile`.
  Both auto-discover; editing them is scope creep. (`.github/workflows/check.yml`
  DOES need a step, but bead `demo` owns it — not this bead, which has no demo
  for CI to run yet.)
- Do NOT create a `.marrow.typ`. That file mints pages, and only `core` and
  `search` ship one. This package mints nothing.
- Do NOT write any Typst logic, `#slip`, `#slipshow`, camera code or CSS rules
  in this bead. Placeholders only.
- Do NOT add dependencies to `package.json` beyond `vite`. The camera engine has
  no runtime dependencies.

VERIFY.

1. `cd /home/lox/code/_fcl/rookery && just check-versions` exits 0. That lint
   checks `<name>/<version>/` against the manifest and every
   `@rookery/<pkg>:<ver>` literal against the manifests.
2. `cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just build` exits 0 and
   produces `dist/lib.js`.
2a. `just test` in that same directory exits 0 — the skeleton fixture asserts
   nothing yet, so this proves the flags and the `panics.sh` helper work before
   any bead depends on them.
3. `ls -la ~/.cache/typst/packages/rookery/slipshow/` shows `0.1.0` as a symlink
   pointing at `/home/lox/code/_fcl/rookery/slipshow/0.1.0`, and NOT a nested
   link inside a real directory.
4. `cd /home/lox/code/_fcl/rookery && jj status` shows only new files under
   `slipshow/`, and nothing under `dist/`. This machine uses jj for version
   control, never the other thing — do not reach for it even read-only.

---

### Bead 2 — `tags`

- **Title:** `src/tags.typ` — map slip options onto rookery tag keys
- **Type:** feature · **Priority:** 1 · **Slug:** `tags`

**Description:**

Write `src/tags.typ` — the mapping from a slip's options onto keys in rookery's
tag dictionary. This is the data model every other bead in the package reads.

Background. `@rookery/slipshow` exports `#slip`, a wrapper around
`@rookery/core`'s `#idea` that augments it with presentation options
(`fullscreen`, `background`, `enter`, `order`, `class`). Those options have to
travel with the note.

WHY TAGS, and this is the constraint that decides the whole design: a rookery
registry record has NO extensible field except `tags`. The record's fields are
fixed — see `/home/lox/code/_fcl/rookery/core/0.1.0/src/idea.typ` around line
288 (`title`, `label`, `raw`, `body`, `created`, `origin`, `links`, `tags`,
`show-context`, `show-backlinks`). A slipshow can be defined by a TAG QUERY over
the registry, in which case it only ever sees a record. So options MUST live in
tags or they cannot survive that route.

Tag values may be arbitrary Typst values, and `ideas(values: true)` hands back a
`tags-dict` field carrying the whole dictionary — see
`/home/lox/code/_fcl/rookery/core/0.1.0/src/data.typ` line 297.

THE MODEL TO COPY is `@rookery/todos`' equivalent file,
`/home/lox/code/_fcl/rookery/todos/0.1.0/src/tags.typ`. Read it first — its
header documents a THREE-SURFACE split that this bead adopts wholesale:

1. FLAT, KEY ENCODES THE VALUE. Value `none`. Renders as a pill, emits an
   `.idea-tag-<key>` CSS class, and is filterable by core's `#ideas(tags:)` and
   by `@rookery/search`'s query language. Use for a small finite domain.
2. VALUED. Renders no pill but IS still presence-filterable by key, because
   rookery's tag predicate tests keys (`"a" in (a: 1)` is `true`).
3. NOT OUR TAGS. The caller's own `tags:` are plain, unnamespaced rookery tags
   and are merged LAST so a caller naming one of our keys wins outright.

Keys are namespaced with a `slip-` prefix per rookery's convention, because a
key becomes a CSS class fragment and a bare name like `background` is generic
enough that two packages could both claim it.

Steps. Create `/home/lox/code/_fcl/rookery/slipshow/0.1.0/src/tags.typ`.

1. File header comment: what the file is (the tag mapping) and the three-surface
   rule above, stated concisely in your own words. Do not restate all of todos'
   header — say what applies here.

2. Declare the base key and the one finite domain as top-level constants:
   `SLIP-KEY = "slip"` and
   `ENTERS = ("scroll", "up", "down", "center", "focus")`.

   `ENTERS` IS THE CAMERA ACTION SET, verbatim — the same five names
   `src/camera.js`'s `targetFor` accepts. One vocabulary spans this file, the
   `data-enter` attribute and the engine, and a comment should say so, because it
   is the only reason the controller can pass the attribute straight through with
   no mapping table.

   There is NO `transition:` and NO `duration:` in this package. An earlier draft
   had both: `transition` duplicated `enter` while carrying values (`fade`,
   `none`) that are not camera actions, and `duration` could not be honoured by
   `window.scrollTo({behavior: "smooth"})`, which takes no duration. Do not
   reintroduce either name, a `TRANSITIONS` constant, or any animation-timing
   argument.

3. Declare the valued key constants: `BACKGROUND-KEY = "slip-background"`,
   `ORDER-KEY = "slip-order"`, `CLASS-KEY = "slip-class"`.

4. Add `_norm-tags-local(v)`, a local copy of rookery's four-form tag
   normalizer. Copy it verbatim from
   `/home/lox/code/_fcl/rookery/todos/0.1.0/src/tags.typ` lines 111-121. It
   handles `none`, a bare string, a dictionary, and an array of strings. (Those
   line numbers were read, not guessed: the `#let` is on 111 and the last branch
   closes on 121, under a header comment carrying the reasoning below.)

   It is deliberately NOT an import of core's private `_norm-tags`: it is six
   lines, and reaching into another package's underscore names creates a
   dependency on an internal that can move without notice. Keep that reasoning
   in a short comment.

   Define it ABOVE its caller — a Typst `#let` closure captures the scope
   visible AT DEFINITION time, so a helper defined further down is invisible.

5. Write `slip-tags(..)`, modelled directly on `todo-tags` at
   `/home/lox/code/_fcl/rookery/todos/0.1.0/src/tags.typ` line 148:

```typ
#let slip-tags(
  tags: none,
  fullscreen: false,
  background: none,
  enter: none,
  order: none,
  class: none,
) = { .. }
```

   Behaviour, in this order:

   a. Start with `let out = ((SLIP-KEY): none)`.
   b. `fullscreen`: assert it is a bool. If `true`, insert the FLAT key
      `"slip-fullscreen"` valued `none`. If `false`, insert NOTHING.
   c. `enter`: if not `none`, assert it is in `ENTERS` (the error message must
      list the accepted names), then insert the FLAT key
      `"slip-enter-" + enter` valued `none`. This gives a
      `.idea-tag-slip-enter-center` class the stylesheet can use directly.
   d. `background`: if not `none`, insert `BACKGROUND-KEY` with the value
      UNTOUCHED. It is an arbitrary Typst value — a colour, a gradient, or an
      image — and this file must not try to interpret it.
   e. `order`: if not `none`, assert it is an int, then insert `ORDER-KEY`.
   f. `class`: if not `none`, assert it is a str, then insert `CLASS-KEY`.
   g. Return `out + _norm-tags-local(tags)`. The caller's tags LAST: Typst
      dictionary `+` is right-wins, which is exactly the precedence wanted.

   EMPTY MEANS ABSENT for every optional key, flat or valued. A key present with
   an empty or false value would read as an assertion about the note — a
   `slip-fullscreen` valued `false` would mark every ordinary slip as fullscreen
   to anything testing for the key, including core's own `tags:` filter. Follow
   todos' `closed: false` precedent at its lines 143-147.

6. Write the readers. Each takes the tag DICTIONARY — what `ideas(values: true)`
   gives per note as `tags-dict` — rather than a note name, so they stay pure
   and a caller walking the corpus pays one registry read for everything rather
   than one per note per question. This mirrors todos' readers at its lines
   220-264.

   - `is-slip(tags)` -> `SLIP-KEY in tags`
   - `is-fullscreen(tags)` -> `"slip-fullscreen" in tags`
   - `enter-of(tags)` -> the name from `ENTERS` whose flat key
     (`"slip-enter-" + name`) is present, else `none`. DECODE from the key; do
     not store the value a second time.
   - `background-of(tags)`, `order-of(tags)`, `class-of(tags)` ->
     `tags.at(<KEY>, default: none)`.

7. Add `#import "tags.typ": *` as the FIRST import line in
   `/home/lox/code/_fcl/rookery/slipshow/0.1.0/src/lib.typ`. It depends on
   nothing, so it leads the dependency order.

Do NOT.

- Do NOT import `@rookery/core` in this file. It must stay a pure function of
  its arguments so it is unit-testable with no rookery present. (Unlike todos'
  `todo-tags`, this needs no `norm:` parameter — none of the values here are
  note names needing normalization.)
- Do NOT import `@rookery/search`. The `a&b` query language is not used here.
- Do NOT define `#slip` in this file — that is the next bead's job.
- Do NOT add a speaker-notes key, a `pause`/reveal key, or any nesting key. The
  package is camera-only and treats a slipshow as a FLAT list.

VERIFY. Append to `test/units.typ` (created by bead `scaf`) and run
`just test` in the package root. NOT a scratch file: a thrown-away compile
proves nothing after the bead closes, and this fixture is what CI runs.

Assertions to add:

1. `slip-tags()` returns exactly `(slip: none)` — the base key alone, and no
   `slip-fullscreen`.
2. `slip-tags(fullscreen: true, enter: "center")` contains the keys `slip`,
   `slip-fullscreen` and `slip-enter-center`, each valued `none`.
3. `slip-tags(background: red).at("slip-background")` is `red` — the value is
   passed through untouched.
4. `slip-tags(tags: (slip: "mine")).at("slip")` is `"mine"` — the caller's own
   tags win on a collision.
5. `enter-of(slip-tags(enter: "focus"))` is `"focus"`, and `enter-of((:))` is
   `none` — the reader decodes from the key.

The rejected-name case CANNOT be an `assert`: Typst has no `try`/`catch`, so a
panic aborts the compile and takes the fixture with it. Add it as a negative
compile instead (part 2.13 has the mechanism):

6. Write `test/panic-enter.typ`, a one-line file calling
   `slip-tags(enter: "nope")`, and add
   `expect_panic test/panic-enter.typ "scroll"` to `test/panics.sh`. The
   substring checks that the message lists the accepted names rather than merely
   failing.

---

### Bead 3 — `slip`

- **Title:** `src/slip.typ` — the `#slip` wrapper around `#idea`
- **Type:** feature · **Priority:** 1 · **Slug:** `slip`

**Description:**

Write `src/slip.typ` — the `#slip` function, an augmented wrapper around
`@rookery/core`'s `#idea`.

Background. `#slip` is to `#idea` what `#todo` is to `#idea` in
`@rookery/todos`: a wrapper that prepends a tag and folds its own named options
into that note's tag dictionary. A plain `#idea` remains perfectly usable inside
a slipshow — it just arrives with no `slip-*` keys and takes the deck's
defaults. `#slip` is for a note that wants presentation options of its own.

READ THIS FIRST: `/home/lox/code/_fcl/rookery/todos/0.1.0/src/todo.typ` line
126, the `#todo` function. It is the exact shape to copy. Note especially that
it is built on core's `tagged-idea` FACTORY, and how it forwards `..args`.
`tagged-idea` is defined at
`/home/lox/code/_fcl/rookery/core/0.1.0/src/idea.typ` line 491.

THE TRAP — do not reintroduce it. Do NOT implement `#slip` as
`idea.with(tags: (slip: none))`. The banner above `tagged-idea` (idea.typ lines
469-473) records why: an explicit `tags:` argument at the call site OVERRIDES a
value bound by `.with()`, so `#slip("x", tags: ("draft",))` would silently drop
the `slip` tag — the very tag `#slip` exists to add. `tagged-idea` returns a
closure that MERGES instead, which is why it exists.

`exclude-tags:` MUST be threaded, and this one is a correctness bug if missed.
The same banner (idea.typ lines 474-490) states that `tagged-idea`'s returned
closure calls the `idea` captured in PACKAGE scope. So a project writing
`#let idea = idea.with(exclude-tags: E)` does NOT thereby reach a wrapper built
on `tagged-idea` — the wrapper would keep hatching the very notes the project
asked to exclude, in a build that SUCCEEDS while doing it. That is a silently
incomplete exclusion in a published build. `tagged-idea` therefore takes
`exclude-tags:` itself; `#slip` must accept it and pass it through. (`#todo`
does not do this — do not take its omission as licence.)

Read `/home/lox/code/_fcl/rookery/CLAUDE.md` for the comment style.

Steps. Create `/home/lox/code/_fcl/rookery/slipshow/0.1.0/src/slip.typ`.

1. Imports:

```typ
#import "@rookery/core:0.1.0": tagged-idea
#import "tags.typ": *
```

2. File header comment: what `#slip` is, that a plain `#idea` works in a
   slipshow too, and — briefly — the `.with()` trap and why `tagged-idea` is
   used instead. Include the three call forms as a usage example:

```typ
//   #slip("intro", fullscreen: true)[The opening.]
//   #slip(background: blue)[A slip with an auto id.]
//   #slip(<intro>)[..]
```

3. Define `#slip`:

```typ
#let slip(
  fullscreen: false,
  background: none,
  enter: none,
  order: none,
  class: none,
  tags: none,
  exclude-tags: (),
  ..args,
) = (tagged-idea(SLIP-KEY, exclude-tags: exclude-tags))(
  tags: slip-tags(
    tags: tags,
    fullscreen: fullscreen,
    background: background,
    enter: enter,
    order: order,
    class: class,
  ),
  ..args,
)
```

   `..args` is forwarded UNTOUCHED. That is what keeps all three `#idea` call
   forms working (`#slip[body]`, `#slip("name")[body]`, `#slip(<name>)[body]`)
   along with every `#idea` named argument this wrapper does not itself consume:
   `title`, `level`, `created`, `show-date`, `show-tags`, `show-context`,
   `show-backlinks`.

   All argument VALIDATION lives in `slip-tags` (previous bead), not here. Do
   not duplicate the assertions.

4. Add `#import "slip.typ": *` to
   `/home/lox/code/_fcl/rookery/slipshow/0.1.0/src/lib.typ`, AFTER the
   `tags.typ` line — it depends on `tags.typ`, and import order in that manifest
   is dependency order.

Do NOT.

- Do NOT use `idea.with(..)`. See the trap above.
- Do NOT re-export core's `#idea` from this package. The public surface is
  `#slip`; a project wanting `#idea` imports `@rookery/core` itself, which it
  must do anyway.
- Do NOT add an epic-style `slip-<name>` factory, a `pause` primitive, or
  speaker notes. Out of scope.
- Do NOT validate arguments here — `slip-tags` does it.

VERIFY. Append to `test/units.typ` and run `just test` in the package root — not
a scratch file, for the reason bead `tags` gives.

Registering a note needs the registry, so these assertions sit inside a
`#context` block, and the file's existing `#import "/src/lib.typ": *` already
reaches `#slip`. `#idea`/`#ideas` come from `@rookery/core:0.1.0`, which resolves
from the package cache link bead `scaf` made.

1. `#slip("intro", fullscreen: true)[Body]` registers a note whose tag dict
   contains `slip` and `slip-fullscreen`. Read it with `ideas(values: true)` and
   inspect the row's `tags-dict`.
2. `#slip[Body]` (no name) also registers, taking an auto id — proving the
   positional sink is forwarded.
3. `#slip("x", tags: ("draft",))[Body]` has BOTH `slip` and `draft` in its tag
   dict. This is the regression the `.with()` trap would cause: if `slip` is
   missing, `tagged-idea` was not used.
4. A plain `#idea("plain")[Body]` in the same document registers with NO
   `slip-*` keys at all.

---

### Bead 4 — `ikw`

- **Title:** `src/marker.typ` — read a note's tags back out of rendered content
- **Type:** feature · **Priority:** 1 · **Slug:** `ikw`

**Description:**

Write `src/marker.typ` — recover a note's tag dictionary from rendered idea
content, so a slipshow defined as an explicit ordered array can read each slip's
options.

Background. `#slipshow` can be defined two ways, and they hand it different
things:

- A TAG QUERY over the registry. Here slipshow gets registry rows, and
  `ideas(values: true)` already carries each note's whole tag dictionary as a
  `tags-dict` field. Nothing to solve.
- An EXPLICIT ORDERED ARRAY of ideas, e.g.
  `#slipshow(slips: (slip("a")[..], slip("b")[..]))`. Here slipshow holds
  rendered CONTENT, not records — so the `slip-*` options set on each idea are
  not directly readable. This bead solves that.

THE MECHANISM: `#idea` wraps every note in a `figure(kind: IK)` marker whose
body carries a `#metadata((..))` payload. See
`/home/lox/code/_fcl/rookery/core/0.1.0/src/idea.typ` line 177 — the payload is:

```typ
#metadata((body: body, title: title, label: note-label, named: named,
           base: base, level: level, tags: tags))
```

`tags` there is the normalized DICTIONARY, values included. So walking a piece
of content for its `figure(kind: IK)` marker and reading that metadata recovers
exactly the same dictionary the registry route gets.

This is not a novel trick — core does it itself. `_flatten`'s IK rule in
`/home/lox/code/_fcl/rookery/core/0.1.0/src/transclusion.typ` walks for the same
marker, and so do `_outbound` (`src/links.typ`) and `_ideas-outline-data`'s
`query()` (`src/outline.typ`). Read `_flatten`'s IK rule before writing this, to
match how core locates the marker.

Steps. Create `/home/lox/code/_fcl/rookery/slipshow/0.1.0/src/marker.typ`.

1. Import what you need from core: `#import "@rookery/core:0.1.0": IK`.

   VERIFIED — this resolves, so do not go hunting for another name. `IK` is
   `#let IK = "rheo-idea"` at `core/0.1.0/src/pure.typ` line 417; `base.typ` line
   46 re-exports it with `#import "pure.typ": *`, and `lib.typ` line 40 does the
   same for `base.typ`. `#import "x.typ": *` re-exports transitively, which core's
   own `lib.typ` header names as the reason the package is a single import.

   Do NOT hardcode the literal `"rheo-idea"` even though you now know it: if core
   renames the constant, a literal breaks silently and an import breaks loudly.

2. File header comment: what the file does (reads a note's tags back out of
   rendered content), and the one fact that makes it work — that `#idea` carries
   its tag dictionary in the `#metadata` inside its `figure(kind: IK)` marker.
   Name `core/src/idea.typ`'s payload as the counterpart, since the two cannot
   be changed apart.

3. Write `slip-meta(it)`, taking one piece of content and returning the metadata
   dictionary of the FIRST `figure(kind: IK)` marker found in it, or `none` if
   there is none:

   - If `it` is itself a figure of kind `IK`, read the metadata from its body.
   - Otherwise search its children.
   - Return the whole payload dictionary (`body`, `title`, `label`, `named`,
     `base`, `level`, `tags`), not just the tags — callers want `title` and
     `level` too.

   Implementation note: a Typst content value is inspected with `.func()` and
   `.fields()`. A `figure`'s kind is `it.kind`. To find the `#metadata`, look for
   a child whose `.func()` is `metadata` and read its `.value`. Follow how
   `_flatten` does this in core rather than inventing a traversal.

4. Write `slip-tags-of(it)` returning just the tag dictionary: `slip-meta(it)`
   then `.at("tags", default: (:))`, and `(:)` when `slip-meta` returned `none`.
   A piece of content that is not an idea at all is NOT an error — it has no
   tags, which is a legitimate answer, and `#slipshow` will treat it as a slip
   with default options.

5. Add `#import "marker.typ": *` to
   `/home/lox/code/_fcl/rookery/slipshow/0.1.0/src/lib.typ` after `tags.typ`.
   It depends only on core, so its position relative to `slip.typ` is free — put
   it before `slip.typ` so the reading modules precede the drawing ones.

Do NOT.

- Do NOT use `query()` here. `query()` finds markers across the whole document;
  this function must read the tags of ONE given piece of content, and a
  document-wide query cannot tell which idea the caller meant. (The registry
  route is what handles "every note matching X".)
- Do NOT re-register, re-count or re-render anything. This is a READ. In
  particular do not call `#idea` — that would step core's unnamed-note counter
  and mint a duplicate.
- Do NOT panic on content that has no IK marker. Return `none`/`(:)`.
- Do NOT flatten or render the `body` field. Hand it back as it is.

VERIFY. Append to `test/units.typ` and run `just test` in the package root — not
a scratch file, for the reason bead `tags` gives. These assertions construct
slips, so this bead cannot be verified before bead `slip` lands; the dependency
graph in part 5 reflects that.

1. `slip-tags-of(slip("a", fullscreen: true)[Body])` contains the keys `slip`
   and `slip-fullscreen`.
2. `slip-tags-of(idea("b")[Body])` has NO `slip-*` keys (a plain idea has no
   slip options).
3. `slip-tags-of([just some text])` is `(:)` and does NOT panic.
4. `slip-meta(slip("c", title: [T])[Body]).at("title")` is the content `[T]`,
   and `.at("level")` is `1`.
5. The tag dictionary returned for a given note EQUALS — exactly, with
   `assert.eq`, not as a subset — the `tags-dict` that `ideas(values: true)`
   reports for the same note. This is the property the whole file exists to
   guarantee: both definition routes must see identical options.

   Exact equality is the right assertion and not a hopeful one: `idea.typ`
   normalizes `tags` once and passes THE SAME LOCAL into both the `#metadata`
   payload (line 177) and the registry record (line 288, `tags: tags`). Typst
   dictionary `==` is order-insensitive, which core's own comment at lines
   275-284 records as measured, so key order cannot make this flake.

---

### Bead 5 — `sel`

- **Title:** `src/select.typ` — resolve the slip list and its order
- **Type:** feature · **Priority:** 1 · **Slug:** `sel`

**Description:**

Write `src/select.typ` — resolve a slipshow's slip list and its order, from
either definition route. It does no rendering.

Background. `ideas()` is core's registry accessor:
`/home/lox/code/_fcl/rookery/core/0.1.0/src/data.typ` line 297:

```typ
#let ideas(tags: none, match: "any", index: none, values: false) = { .. }
```

Two facts about it that this bead exists to work around:

- It returns rows SORTED BY ID (`.sorted(key: p => p.at(0))`, data.typ line
  304). Id order is almost never presentation order, so the query route NEEDS an
  explicit sort.
- Its filtering is only `tags:` plus `match: "any"|"all"`. It has NO boolean
  operators.

Row fields available as sort keys (data.typ lines 297-370): `id`, `name`,
`title`, `text`, `label`, `tags`, `body`, `href`, `page`, `created`, and — only
when called with `values: true` — `tags-dict` carrying the full tag dictionary
with arbitrary values. Always call it with `values: true` here; slip options live
in tag values.

The `a&b` query language and why it is NOT imported. The boolean tag grammar
(`a&b`, `a|b`, `!a`, parentheses) lives in `@rookery/search`, at
`/home/lox/code/_fcl/rookery/search/0.1.0/src/tagquery.typ` (`parse-tag-query`,
`eval-tag-query`), with a parity-pinned JavaScript twin. It is NOT in core.

This package does NOT depend on `@rookery/search`, optionally or otherwise.
Instead `tags:` accepts EITHER a core-style spec OR A PREDICATE FUNCTION taking
a tag dictionary and returning a bool. A project that wants the full grammar
builds the predicate itself:

```typ
#import "@rookery/search:0.1.0": parse-tag-query, eval-tag-query
#slipshow(tags: t => eval-tag-query(parse-tag-query("a&b").rpn, t))
```

That keeps search a pure extension point with zero dependency edges, and needs
no conditional-import trickery. This decision is settled — do not add a search
import, a `search: true` flag, or a reimplementation of the grammar.

Steps. Create `/home/lox/code/_fcl/rookery/slipshow/0.1.0/src/select.typ`.

1. Imports:

```typ
#import "@rookery/core:0.1.0": ideas
#import "tags.typ": *
#import "marker.typ": *
```

2. File header comment: the two definition routes, the fact that `ideas()` sorts
   by id so the query route must be sorted explicitly, and the predicate
   extension point (briefly).

3. Write `_slip-rows-from-query(tags, match)`:

   - Must be called inside a `#context` block (it reads the registry via
     `ideas`), and say so in a comment. Like core's own `ideas`, it is not
     itself a context function, because the point is to return DATA and a Typst
     context function may only return content.
   - If `tags` is a FUNCTION: call `ideas(values: true)` with no tag filter, then
     `.filter(r => tags(r.tags-dict))`.
   - Otherwise pass `tags`/`match` straight to
     `ideas(tags: tags, match: match, values: true)` and let core validate them
     — core's `_assert-tags`/`_assert-match` already produce good messages, and
     duplicating them here would mean two messages teaching the same rule.
   - Return the rows.

4. Write `_sort-rows(rows, order)`, implementing the three orders:

   - `order` is an ARRAY of note names/ids: sort by position in that array. Rows
     named in it come first, in that exact sequence; rows NOT named in it are
     appended afterwards in their incoming (id) order. Compare against each
     row's `name` AND `id`, so a caller may write either form.
   - `order` is `"created"`: sort ascending by the row's `created` field. A row
     with `created: none` sorts LAST — otherwise undated notes silently lead the
     deck.
   - `order` is `"slip-order"` (the default): sort ascending by
     `order-of(row.tags-dict)`. A row with no `slip-order` sorts after every row
     that has one, keeping its incoming relative order.
   - Any other value: panic with a message listing the three accepted forms.

   Sorting must be STABLE for equal keys, so a tie keeps id order and a build is
   reproducible. Sort by a COMPOUND key — the real key, then the row's `id` —
   rather than relying on `.sorted()`'s stability, and say in a comment that this
   is why the key is compound. Typst's sort happens to be stable, but a tie-break
   the code states outright is one a reader can check and a future Typst cannot
   take away.

5. Write the public
   `resolve-slips(slips: none, tags: none, match: "any", order: "slip-order")`:

   - Assert that EXACTLY ONE of `slips` and `tags` is given. Both, or neither, is
     an error naming both parameters — this is the most likely caller mistake and
     the message should resolve it outright.
   - If `slips` is given: assert it is an array. Return entries
     `(kind: "content", content: <item>, tags: slip-tags-of(<item>))` in the
     array's own order, IGNORING `order:` entirely. An explicit array is already
     ordered by construction, and silently re-sorting it would be surprising. If
     the caller passed a non-default `order:` alongside `slips:`, panic saying
     the two conflict.
   - If `tags` is given: get rows via `_slip-rows-from-query`, sort with
     `_sort-rows`, and return entries
     `(kind: "row", row: <row>, tags: <row.tags-dict>)`.
   - The two shapes differ deliberately: a content entry is rendered inline, a
     row entry is rendered via `#window`. The `kind` field means the renderer
     needs no key-presence guessing.

6. Add `#import "select.typ": *` to
   `/home/lox/code/_fcl/rookery/slipshow/0.1.0/src/lib.typ`, after both
   `tags.typ` and `marker.typ`.

Do NOT.

- Do NOT import `@rookery/search`. See above; this is settled.
- Do NOT render anything. No `html.elem`, no `#window`, no `figure`.
- Do NOT support nesting. A slipshow is a FLAT list of ideas; nested ideas
  inside a slip are ordinary content and slipshow does not look into them.
- Do NOT call `ideas()` without `values: true` — the slip options are in tag
  values and would be silently dropped.
- Do NOT re-validate `tags`/`match` when delegating to core.

VERIFY. Append to `test/units.typ` and run `just test`, inside `#context` — not
a scratch file, for the reason bead `tags` gives.

1. `resolve-slips(slips: (slip("a")[A], slip("b")[B]))` returns 2 entries of
   kind `"content"` in that exact order.
2. With notes `#slip("a", order: 2)[..]` and `#slip("b", order: 1)[..]`,
   `resolve-slips(tags: "slip")` returns `b` before `a` — the default
   `slip-order` sort.
3. `resolve-slips(tags: t => "slip-fullscreen" in t)` returns only the
   fullscreen slips — proving the predicate route works with no
   `@rookery/search` present.
4. `resolve-slips(tags: "slip", order: "created")` places a note with
   `created: none` LAST.
5. The three panic cases go in `test/panics.sh` as negative compiles, NOT as
   asserts — Typst has no `try`/`catch` (part 2.13). One tiny file each, because
   a panic aborts the whole compile and a second case in the same file never
   runs:

   - `test/panic-neither.typ` — `resolve-slips()`; message must name both
     `slips` and `tags`.
   - `test/panic-both.typ` — `resolve-slips(slips: (), tags: "slip")`; same
     message.
   - `test/panic-order.typ` — `resolve-slips(slips: (), order: "created")`;
     message must say the two conflict.

   Add an `expect_panic <file> <substring>` line per case.

---

### Bead 6 — `show`

- **Title:** `src/slipshow.typ` — the `#slipshow` container and the DOM contract
- **Type:** feature · **Priority:** 1 · **Slug:** `show`

**Description:**

Write `src/slipshow.typ` — the `#slipshow` container that renders the resolved
slip list as the presentation DOM.

This bead DEFINES THE DOM CONTRACT that the stylesheet (bead `css`) and the
JavaScript engine (beads `cam`, `ctrl`) both depend on. Nothing downstream can
be written until the element and attribute names are fixed here, so fix them
deliberately and record them in the file header.

Background. `resolve-slips(..)` (from `src/select.typ`) hands back an ordered
list of entries, each with a `kind` field:

- `kind: "content"` — an explicit-array entry carrying rendered idea `content`
  plus its `tags` dictionary. Render the content INLINE.
- `kind: "row"` — a query entry carrying a registry `row` plus its `tags`
  dictionary. Render it via core's `#window(row.id)`.

`#window` is core's public transclusion renderer. It already emits a tab (the
"hat") and the left rule, so a windowed note looks like a rookery card without
this package rebuilding core's markup. See `.idea-window`,
`.idea-window-summary` and `.idea-tab` in
`/home/lox/code/_fcl/rookery/core/0.1.0/src/core.css`.

THE FOLDED-STATE WRINKLE IS ALREADY SETTLED and needs nothing from this bead.
`#window`'s `folded:` parameter defaults to `false` (window.typ line 65), and
`transclusion.typ` lines 161-162 emit `open: "open"` in exactly that case — so a
plain `#window(row.id)` is already `<details open>`. Pass no `folded:` argument,
and do not ask bead `css` for a forcing rule.

Call it as `#window(row.id)`: `#window`'s positional is variadic and every name
goes through core's `_norm`, so `row.id` and `row.name` are equivalent. Its
`depth: auto` default resolves to 1 — render this note, collapse any window
inside it to a permalink — which is what a slip wants.

Do NOT modify `@rookery/core`.

PAGED OUTPUT IS TRANSPARENT. On a paged target `#slipshow` must render the ideas
exactly as core would, with no slip wrappers, no page breaks of its own and no
slipshow-specific chrome. The presentation is an HTML concern only. This package
cannot import core's private `_target()`, so read `target()` via `#context`
directly, matching the pattern in
`/home/lox/code/_fcl/rookery/core/0.1.0/src/idea.typ` line 347.

Steps. Create `/home/lox/code/_fcl/rookery/slipshow/0.1.0/src/slipshow.typ`.

1. Imports:

```typ
#import "@rookery/core:0.1.0": window
#import "tags.typ": *
#import "select.typ": *
```

2. File header comment. It MUST document the DOM contract as the file's primary
   fact, because `src/slipshow.css` and `src/slipshow.js` are pinned to it and
   the three cannot be changed apart. Name them as counterparts.

3. Fix and implement this DOM. Use these names exactly:

   - Root: `<div class="slipshow" data-enter="<action>">`, carrying the
     DECK-WIDE default from `#slipshow`'s own `enter:` argument. There is no
     `data-transition` and no `data-duration`; part 3.9 records why both
     arguments are gone.
   - Each slip: `<section class="slip" id="slip-<note-id>" data-index="<n>">`.
     Add `data-enter` ONLY when that slip overrides the deck default, so the
     engine can distinguish "unset" from "same as the default".
   - ONE `div.slipshow` per page. Nothing enforces it, and the controller uses
     the first it finds and ignores any others — say so in the header rather than
     asserting, since a page with two decks is a mistake and not a feature.
   - A fullscreen slip additionally gets the class `slip-fullscreen`.
   - A slip with a `slip-class` value appends that string to its class list.
   - A background is applied as an inline `style` attribute on the section. Emit
     `background: <css>` for a colour or gradient. For an image, emit
     `background-image: url(..)`. Convert a Typst colour to CSS with
     `<color>.to-hex()`.

   Read each slip's options from its `tags` dictionary using the readers from
   `tags.typ`: `is-fullscreen`, `enter-of`, `class-of`, `background-of`.

4. Define `#slipshow`:

```typ
#let slipshow(
  slips: none,
  tags: none,
  match: "any",
  order: "slip-order",
  enter: "scroll",
) = context { .. }
```

   - NO `..args` sink. Every argument this container takes is named above, and
     without a sink Typst reports an unknown one for free — a sink would swallow
     a misspelled `enterr:` and present it as a slipshow that ignores its
     settings.
   - Assert `enter` is in `ENTERS` (from `tags.typ`). Reuse that vocabulary; do
     not invent a second set of names.
   - On a paged target: resolve the slips and emit each entry's content (or
     `#window(row.id)`) in order, with NO wrappers. Return early.
   - On html/epub: emit the root div containing one section per entry, in the
     resolved order.
   - It must be a `context` function because `resolve-slips` reads the registry.

5. Add `#import "slipshow.typ": *` as the LAST import line in
   `/home/lox/code/_fcl/rookery/slipshow/0.1.0/src/lib.typ` — it reads
   everything else, so it sits last in the dependency order, exactly as
   `template.typ` does in core's own manifest.

Do NOT.

- Do NOT write any CSS rules or JavaScript in this bead. Beads `css`, `cam` and
  `ctrl` own those, and they depend on the names fixed here.
- Do NOT emit `pause`, `reveal`, `step` or any incremental-reveal attribute. The
  package is camera-only: a slip is fully rendered and only the viewport moves.
- Do NOT rebuild core's `.idea-box` card markup. Query entries go through
  `#window`; array entries are already-rendered ideas.
- Do NOT modify anything under `/home/lox/code/_fcl/rookery/core/`.
- Do NOT add page breaks, a title slide, or slide numbering on the paged target.
  Transparent means transparent.

VERIFY. The demo fixture does not exist yet — bead `demo` builds it, and it is
what turns these checks into something CI runs. So build a THROWAWAY rheo
project for now, under the session scratchpad rather than in this repo, and
check the emitted `build/html/*.html`. Do not leave it in the tree; confirm with
`jj status` that nothing landed.

1. A `#slipshow(tags: "slip")` over three slips emits exactly one
   `<div class="slipshow">` containing exactly three `<section class="slip"`
   elements, with `data-index` 0, 1, 2 in the resolved order.
2. A slip authored `#slip("a", fullscreen: true)[..]` emits a section whose
   class list contains `slip-fullscreen`.
3. A slip authored `#slip("b", background: red)[..]` emits a section whose
   `style` attribute contains that colour as a hex value.
4. A slip with no overrides emits NO `data-enter` attribute of its own — the
   deck default on the root is the only one present. No `data-transition` or
   `data-duration` appears anywhere in the output.
5. Compiling the same project to PDF produces the ideas in order with NO
   `slipshow`/`slip` wrapper elements and no extra page breaks.

---

### Bead 7 — `css`

- **Title:** `src/slipshow.css` — slip layout, fullscreen and backgrounds
- **Type:** feature · **Priority:** 2 · **Slug:** `css`

**Description:**

Write `src/slipshow.css` — the presentation stylesheet: slip layout, fullscreen
slips, and backgrounds.

Background. The file currently exists as a placeholder created by the scaffold
bead, because `typst.toml` names it as `css_stylesheet`. This bead fills it in.

It styles the DOM fixed by `src/slipshow.typ` (bead `show`). READ THAT FILE'S
HEADER FIRST — it documents the contract. The elements:

- `div.slipshow` — the deck root, carrying `data-enter` (the deck default).
- `section.slip` — one slip, with `id="slip-<note-id>"` and `data-index`.
- `section.slip.slip-fullscreen` — a slip that should fill the viewport.
- An optional per-slip `data-enter`, present only where it overrides the deck.
- An inline `style` carrying a background, when set.

A slip's inner content is a rookery card rendered by `@rookery/core` — either an
`.idea-box` (an inline idea) or an `.idea-window` (a queried note rendered via
`#window`). This stylesheet MUST NOT restyle those cards' own identity: the
border-left and the tab ("hat") are core's look and the whole point of
presenting ideas as slips.

REUSE CORE'S DESIGN TOKENS rather than hardcoding values. Core's stylesheet
(`/home/lox/code/_fcl/rookery/core/0.1.0/src/core.css`) exposes, among others:
`--idea-border-color`, `--idea-rule-width`, `--idea-pad`, `--idea-label-size`,
`--idea-link-color`. Read that file for the full set and the fallbacks each rule
uses before inventing a variable.

Read `/home/lox/code/_fcl/rookery/CLAUDE.md` for the comment style — it applies
to CSS comments too, and `core.css` is the house example of the density expected
(comment the non-obvious constraint, not the obvious rule).

Steps.

1. File header comment: what the stylesheet is, and that it is pinned to the DOM
   contract in `src/slipshow.typ` and driven by `src/slipshow.js` — name both as
   counterparts, since the three cannot be changed apart.

2. `div.slipshow`: establish the scroll container. It is the element the engine
   scrolls, so it needs a predictable height and `overflow-y`. Define the deck as
   a single continuous vertical flow — this is a SLIP model, not a slide model:
   there is no fixed slide height and a slip may be arbitrarily long.

3. `section.slip`: block layout, generous vertical rhythm between slips, and
   `scroll-margin-top` so a programmatic scroll does not butt the slip against
   the viewport edge. A slip has NO fixed height by default — its height is its
   content's.

4. `section.slip.slip-fullscreen`: `min-height: 100svh` (not `vh` — `svh` is
   stable against mobile browser chrome; say so in a comment), centring its
   content vertically. This is the "fullscreen slide" case.

5. Backgrounds: ensure a slip carrying an inline background renders it across
   the full slip, including any padding. Add a rule so `background-image` cases
   get `background-size: cover` and `background-position: center` without the
   Typst side having to emit them.

6. Provide a `prefers-reduced-motion` block that disables smooth scrolling and
   the focus zoom transition. The engine reads the same preference (bead `ctrl`),
   but the CSS must stand on its own for anything the engine has not taken over.

7. Do NOT add a rule forcing `#window`'s `details` open. That wrinkle is
   settled: `#window` defaults to `folded: false` and already emits
   `<details open>`, so `core.css`'s `.idea-window-details:not([open])` block is
   never matched inside a slip. A forcing rule here would be dead CSS.

Do NOT.

- Do NOT restyle `.idea-box`, `.idea-window`, `.idea-tab`, `.idea-title` or any
  `.idea-*` card internals beyond what is strictly needed to place them inside a
  slip. The card's border and hat are core's and must survive.
- Do NOT hardcode colours that core already exposes as variables.
- Do NOT add a theme system, multiple named themes, or a colour palette. A
  consuming project layers its own CSS.
- Do NOT style `pause`/`reveal`/`fragment` states. There are none.
- Do NOT set `overflow: hidden` on the document body from here; a presentation
  that cannot be scrolled by hand is a worse fallback than one that can.

VERIFY.

1. `cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just build` exits 0.
2. Build a throwaway rheo project (the demo fixture is bead `demo`'s job and
   does not exist yet) under the session scratchpad, not in this repo, and open
   the HTML in a browser: slips flow continuously down one scrolling column,
   each rookery card still showing its left border and tab. `jj status` must
   show nothing new in the tree afterwards.
3. A slip authored `#slip("a", fullscreen: true)[..]` occupies at least the full
   viewport height.
4. A slip authored with `background: red` shows that colour behind the whole
   slip, card included.
5. With the OS set to reduce motion, scrolling between slips is instant rather
   than animated.

---

### Bead 8 — `cam`

- **Title:** `src/camera.js` — pure camera geometry
- **Type:** feature · **Priority:** 2 · **Slug:** `cam`

**Description:**

Write `src/camera.js` — the pure geometry of the slip camera. No DOM writes, no
event handling.

Background. `@rookery/slipshow` presents a rookery as an endlessly scrolling
presentation. The "camera" is the viewport: advancing the presentation moves the
viewport to the next slip rather than swapping one slide for another.

This bead is the GEOMETRY ONLY, deliberately split from the controller (bead
`ctrl`) so it can be unit-tested with plain numbers and no browser. It takes
measurements in and returns a target position out. It must not touch the DOM,
read `window`, or attach a listener.

The action vocabulary is taken from slipshow's own, documented at
https://docs.slipshow.org/en/stable/actions-api.html — implement these five:

- `scroll` — move vertically until the element is entirely visible on screen, if
  possible.
- `up` — move vertically until the element is at the TOP of the screen.
- `down` — move vertically until the element is at the BOTTOM of the screen.
- `center` — move vertically until the element is CENTRED.
- `focus` — zoom so the element fills the viewport; paired with `unfocus`, which
  returns to the previous position and zoom.

This package is CAMERA-ONLY: there is no `pause`, `reveal`, `step`, drawing or
speaker-note action. Do not implement them.

`/home/lox/code/_fcl/rookery/search/0.1.0/src/score.js` is a good example in
this repo of a pure JS module with a unit test; match its style. Read
`/home/lox/code/_fcl/rookery/CLAUDE.md` for the comment style.

Steps. Replace the placeholder
`/home/lox/code/_fcl/rookery/slipshow/0.1.0/src/camera.js`.

1. File header comment: what the module is (pure camera geometry), that it does
   no DOM access so it can be tested with numbers, and that `src/slipshow.js` is
   the counterpart that applies its output.

2. Export `targetFor(action, rect, viewport, opts)` returning
   `{ scrollTop, scale }`:

   - `action` — one of `"scroll" | "up" | "down" | "center" | "focus"`.
   - `rect` — the element's position in DOCUMENT coordinates:
     `{ top, height }`. Document coordinates, NOT viewport-relative — the
     controller converts before calling, and this keeps the maths independent of
     current scroll. Say so in a comment; it is the contract most easily got
     wrong.
   - `viewport` — `{ height, width }`.
   - `opts` — `{ margin = 0 }`, a gap left around the element.

   Geometry per action:
   - `up`: `scrollTop = rect.top - margin`, `scale = 1`.
   - `down`: `scrollTop = rect.top + rect.height + margin - viewport.height`,
     `scale = 1`.
   - `center`: `scrollTop = rect.top + rect.height / 2 - viewport.height / 2`,
     `scale = 1`.
   - `scroll`: if `rect.height + 2 * margin <= viewport.height`, behave as
     `center` (the element fits, so centring shows all of it). Otherwise behave
     as `up` — show the element's start and let the rest run off the bottom,
     which is the only sensible reading of "entirely visible, IF POSSIBLE" for a
     slip taller than the screen.
   - `focus`: `scale = min(viewport.height / (rect.height + 2 * margin), 1)`,
     capped at 1 so focusing never magnifies beyond natural size; `scrollTop`
     centres the element as in `center`. A zero or negative `rect.height` must
     yield `scale = 1` rather than a division blow-up.

   These five names ARE the `enter:` domain — `ENTERS` in `src/tags.typ` holds
   the same five strings, so a `data-enter` attribute reaches `targetFor` with no
   mapping table in between. Say so in a comment; it is the reason no translation
   layer exists.

   Unknown `action`: throw an `Error` naming the action and listing the accepted
   values. A silent fallback would make a typo in an authored `data-enter` look
   like a camera bug.

   There is no easing function and no tween helper in this module. The controller
   scrolls with `window.scrollTo({behavior: "smooth"})` and the browser owns the
   timing — part 3.9 records why `duration:` does not exist.

3. Export `clamp(scrollTop, docHeight, viewportHeight)` returning the value
   clamped to `[0, max(0, docHeight - viewportHeight)]`. Every target must go
   through it, because a slip near either end of the document would otherwise
   produce an unreachable position and the engine would appear to do nothing.

4. Export `unfocusTarget(saved)`, returning the saved `{ scrollTop, scale }` an
   `unfocus` restores, or `{ scrollTop: 0, scale: 1 }` when nothing was saved.
   Keeping the stack in the controller and the restore shape here keeps this
   module stateless.

5. Keep the module free of any `import`. It is the FIRST entry in
   `[tool.rheo.source.html]`'s dependency-first list in `typst.toml` precisely
   because it imports nothing.

Do NOT.

- Do NOT read or write the DOM, `window`, `document` or any global. No
  `getBoundingClientRect` here — the controller measures and passes numbers in.
- Do NOT attach event listeners or manage navigation state.
- Do NOT animate. This module returns a TARGET; the controller decides how to
  get there.
- Do NOT implement `pause`, `reveal`, `unreveal`, `static`, `unstatic`, drawing,
  carousels or speaker notes.
- Do NOT add a dependency to `package.json`.

VERIFY. Add `test/camera.test.mjs` and a `test` recipe to the package `Justfile`
in the style of `/home/lox/code/_fcl/rookery/search/0.1.0/Justfile` (which runs
`node --test test/*.test.mjs`, with a comment explaining why the glob rather
than a bare directory). Assert:

1. `targetFor("up", {top: 500, height: 100}, {height: 800}, {margin: 0}).scrollTop`
   is `500`.
2. `targetFor("center", {top: 500, height: 100}, {height: 800}).scrollTop` is
   `150` (500 + 50 - 400).
3. `targetFor("scroll", ..)` on an element TALLER than the viewport equals the
   `up` result; on a shorter one it equals the `center` result.
4. `targetFor("focus", {top: 0, height: 1600}, {height: 800}).scale` is `0.5`,
   and `targetFor("focus", {top: 0, height: 0}, {height: 800}).scale` is `1`.
5. `clamp(-50, 1000, 800)` is `0` and `clamp(9999, 1000, 800)` is `200`.
6. `targetFor("nope", ..)` throws an Error whose message contains `nope`.

---

### Bead 9 — `ctrl`

- **Title:** `src/slipshow.js` — the navigation controller
- **Type:** feature · **Priority:** 2 · **Slug:** `ctrl`

**Description:**

Write `src/slipshow.js` — the controller: discover the slips, hold navigation
state, handle input, and apply `camera.js`'s targets to the page.

Background. This is the browser half of `@rookery/slipshow`. `src/camera.js`
(bead `cam`) already computes WHERE to go from plain numbers; this module
measures the DOM, asks it, and moves there. Keeping the split intact is the
point — do not put geometry here.

THE DOM CONTRACT is fixed by `src/slipshow.typ` (bead `show`). Read that file's
header before writing anything. The elements:

- `div.slipshow` — deck root, with `data-enter` carrying the DECK DEFAULT.
- `section.slip` — one slip, `id="slip-<note-id>"`, `data-index="<n>"`.
- `section.slip.slip-fullscreen` — fills the viewport.
- An optional per-slip `data-enter`, present ONLY when that slip overrides the
  deck default, so absence means "inherit". There is no `data-transition` and no
  `data-duration` — part 3.9 records why both are gone.

`camera.js` exports `targetFor(action, rect, viewport, opts)` returning
`{ scrollTop, scale }`, plus `clamp(scrollTop, docHeight, viewportHeight)` and
`unfocusTarget(saved)`. `rect` must be in DOCUMENT coordinates — this module is
responsible for converting from `getBoundingClientRect()`, which is
viewport-relative. Getting that conversion wrong is the most likely bug in this
bead: document top = `rect.top + window.scrollY`.

A useful model for a rheo package's browser entrypoint is
`/home/lox/code/_fcl/rookery/search/0.1.0/src/search.js` — same repo, same
conventions, also an ES module bundled by vite into `dist/lib.js`. Read
`/home/lox/code/_fcl/rookery/CLAUDE.md` for the comment style.

Steps. Replace the placeholder
`/home/lox/code/_fcl/rookery/slipshow/0.1.0/src/slipshow.js`.

1. File header comment: what the module is, that `src/camera.js` owns the
   geometry and `src/slipshow.css` the layout, and that all three are pinned to
   the DOM contract documented in `src/slipshow.typ`.

2. `import { targetFor, clamp, unfocusTarget } from "./camera.js";`
   A RELATIVE ES import, because the package is also consumed unbundled from a
   ref via `[tool.rheo.source.html]` in `typst.toml`, where the browser resolves
   this import itself. `camera.js` is listed BEFORE this file there for that
   reason.

3. On init, find the FIRST `div.slipshow` and ignore any others. If there is
   none, RETURN SILENTLY — the script
   is injected on every page of a rheo project, and most pages are not
   presentations. Do not throw and do not log.

4. Collect `section.slip` elements in `data-index` order into an array. Hold the
   current index in a variable starting at 0. If there are no slips, return.

5. Resolve each slip's effective camera action: its own `data-enter` if present,
   else the root's, else `"scroll"`. That is the whole chain — one attribute, one
   helper, no mapping table. The attribute's five values ARE `targetFor`'s five
   action names (`scroll`, `up`, `down`, `center`, `focus`), fixed once in
   `src/tags.typ`'s `ENTERS`; pass the string straight through.

6. `goTo(index)`:
   - Clamp `index` into range; if unchanged, do nothing.
   - Measure the slip: `const r = el.getBoundingClientRect()`, then build the
     document-coordinate rect
     `{ top: r.top + window.scrollY, height: r.height }`.
   - Call `targetFor(action, rect, { height: window.innerHeight, width: window.innerWidth }, { margin })`,
     where `margin` is a module constant. There is no per-slip margin argument.
   - Pass `scrollTop` through
     `clamp(.., document.documentElement.scrollHeight, window.innerHeight)`.
   - Scroll with `window.scrollTo({ top, behavior })` where `behavior` is
     `"smooth"` normally and `"auto"` when reduced motion is requested (step 9).
   - If the action is `focus` and `scale !== 1`, apply the zoom as a CSS
     transform on the deck root, with a transform-origin at the slip's centre.
     Push the previous `{ scrollTop, scale }` onto a stack so `unfocus` can
     restore it via `unfocusTarget`. Keep the stack HERE — `camera.js` is
     stateless by design.
   - Update `window.location.hash` to the slip's `id` so a position is linkable
     and survives reload. Use `history.replaceState`, NOT assignment to
     `location.hash`, so navigating the deck does not fill the browser's back
     history with one entry per slip.

7. Input handling, all on `document`:
   - `ArrowRight`, `ArrowDown`, `PageDown`, `Space` -> next slip.
   - `ArrowLeft`, `ArrowUp`, `PageUp` -> previous slip.
   - `Home` -> first, `End` -> last.
   - `Escape` -> `unfocus` if the focus stack is non-empty.
   - A click on the deck root advances, but bail on
     `event.target.closest("a, summary, button, input, select, textarea, label")`.
     Two reasons, and both are real rather than defensive: links inside a rookery
     card are real links, and swallowing them would break every permalink and
     cross-note reference on the slip; and a queried slip is rendered by
     `#window` as a native `<details open>`, so its `<summary>` is a real
     disclosure control — a click there would both fold the slip and advance the
     deck. Folding a slip by hand stays available and is harmless; folding one as
     a side effect of advancing is not.
   - Ignore any key event whose `event.target` is an input, textarea or
     contenteditable, and any event with a modifier key held, so a project's own
     search bar keeps working.

8. On load, if `window.location.hash` matches a slip id, start at that slip
   instead of 0.

9. Read `window.matchMedia("(prefers-reduced-motion: reduce)")` once and use it
   to choose the scroll behaviour — `"auto"` when reduce is set, `"smooth"`
   otherwise. That choice is the ONLY animation control this module has:
   `scrollTo`'s smooth behaviour takes no duration and the browser owns the
   timing, which is why there is no `duration:` argument anywhere in the
   package. Do NOT add a rAF tween to get one back. The stylesheet honours the
   same preference independently.

10. Re-measure on `resize` — a slip's height changes with the viewport, so a
    cached rect goes stale. Debounce it; do not re-measure per scroll event.

11. Initialise on `DOMContentLoaded`, or immediately if `document.readyState` is
    no longer `"loading"`. Copy that guard's shape from the bottom of
    `/home/lox/code/_fcl/rookery/search/0.1.0/src/search.js`.

Do NOT.

- Do NOT put camera geometry here. If you need a new calculation, it belongs in
  `camera.js` with a unit test.
- Do NOT implement `pause`, `reveal`, `step`, drawing, carousels or speaker
  notes. Camera-only.
- Do NOT hijack ordinary scrolling. A viewer must still be able to scroll the
  deck by hand — that is the fallback when the engine misbehaves.
- Do NOT add a runtime dependency to `package.json`.
- Do NOT `console.log` on a normal path.
- Do NOT assume `dist/lib.js` is how the module loads. It is also loaded
  unbundled, so keep the relative import and use no bundler-only syntax.

VERIFY.

1. `cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just build` exits 0 and
   `dist/lib.js` contains the controller.
2. `just test` still passes the `camera.js` unit tests. This bead adds no JS
   test of its own — the controller needs a DOM and this repo has no browser
   harness. Say so rather than inventing one.
3. In a browser on the demo fixture: pressing ArrowDown moves the viewport to
   the next slip and the URL hash becomes that slip's id.
4. Pressing ArrowUp returns to the previous slip; `Home` returns to the first.
5. Clicking a permalink or note link inside a slip FOLLOWS the link rather than
   advancing the deck; clicking a queried slip's `<summary>` folds that slip and
   does NOT advance.
6. Reloading the page at `#slip-<id>` starts at that slip.
7. On a page with no `div.slipshow`, the console is clean — no error, no log.

---

### Bead 10 — `demo`

- **Title:** `demo/rheo/` — the fixture that proves the package compiles
- **Type:** task · **Priority:** 2 · **Slug:** `demo`

**Description:**

Add `demo/rheo/` — the in-repo fixture that proves `@rookery/slipshow` compiles
under rheo.

Background. This repo's definition of lint is stated in
`/home/lox/code/_fcl/rookery/CLAUDE.md`: "there is no separate linter. 'Lint' =
the package builds and its demo/test project compiles with `rheo compile`."
Every other package here carries such a fixture, and `search`'s own was added
precisely because it was the one package without one.

Copy the SHAPE of `/home/lox/code/_fcl/rookery/search/0.1.0/demo/rheo/`: a
`rheo.toml`, a `content/` directory, a `Justfile`, and a `check.sh`. Read the
header comment in that `rheo.toml` — it explains why a fixture seeds a real
corpus rather than a single page, and that `lib.typ` is excluded from the spine
because it is a library rather than a page.

The fixture must exercise BOTH ways a slipshow can be defined, because they take
different code paths and one can break while the other passes:

- an EXPLICIT ORDERED ARRAY (`slips:`), which reads options out of rendered
  content via `src/marker.typ`;
- a TAG QUERY (`tags:`), which reads them out of the registry via
  `ideas(values: true)`.

It must ALSO carry one realistic presentation, not only minimal one-line pages.
This package has no consumer outside this repo, so the fixture is the only place
the package is ever exercised at the shape it exists for — a dozen slips with
titles, prose, a table and fullscreen bookends. A fixture of three-word slips
compiles clean while leaving every layout question untested.

Steps.

1. Create `/home/lox/code/_fcl/rookery/slipshow/0.1.0/demo/rheo/rheo.toml`:

```toml
version = "0.6.2"
content_dir = "content"
formats = ["html", "pdf"]

[spine]
exclude = ["lib.typ"]
```

   `formats` includes `pdf` deliberately: `#slipshow` must be TRANSPARENT on a
   paged target, and only a PDF build proves it. A header comment should say so.

2. Create `content/lib.typ` holding the shared imports and any `#show` rule both
   pages apply, following `search`'s demo `lib.typ`. It is excluded from the
   spine because it is a library, not a page.

3. Create `content/index.typ` — a slipshow defined by TAG QUERY. It should
   author several notes with `#slip(..)`, using a spread of options across them:
   one `fullscreen: true`, one with a `background`, one with a non-default
   `enter`, one with an explicit `order`, and at least one plain `#idea` with no
   slip options at all (to prove a plain idea still presents). Render them with
   `#slipshow(tags: "slip")`.

4. Create `content/explicit.typ` — a slipshow defined by EXPLICIT ARRAY, using
   `#slipshow(slips: (..))` with the ideas written inline in the call. This is
   the `src/marker.typ` path.

5. Create `content/predicate.typ` — a slipshow whose `tags:` is a PREDICATE
   FUNCTION, e.g. `#slipshow(tags: t => "slip-fullscreen" in t)`. This proves
   the extension point works with NO `@rookery/search` installed. Add a comment
   noting that a project wanting the `a&b` grammar builds the predicate from
   `@rookery/search`'s `parse-tag-query`/`eval-tag-query`, and that slipshow
   itself does not depend on that package.

5a. Create `content/deck.typ` — the REALISTIC presentation, and the page a
   reader opens to see what this package is for. Around a dozen slips, each with
   a `title:` and real prose rather than placeholder words:

   - A fullscreen opening slip and a fullscreen closing slip, to show the
     bookend case (`fullscreen: true`).
   - A slip whose body holds a TABLE, because a table is the layout most likely
     to break inside a slip and the one a presentation most often wants. Use a
     borderless `table`, NOT `grid`: Typst silently drops `grid` in HTML export,
     so a `grid` here produces a slip that is empty in the browser and correct
     in the PDF. Say that in a comment — it is a constraint the code cannot
     express.
   - A slip with a `background`, and one with a non-default `enter`.
   - PINNED NAMES on every slip (`#slip("opening", ..)`), never auto ids: core's
     unnamed notes take a sequence number that SHIFTS when a note is inserted
     earlier, so an auto id would silently repoint `order:` and every link into
     the deck.

   Render it with whichever definition route reads better with a dozen slips —
   either is fine, but say in a comment which you chose and why.

6. Create `demo/rheo/Justfile` with a recipe that runs `rheo compile .`, copying
   the shape of `/home/lox/code/_fcl/rookery/search/0.1.0/demo/rheo/Justfile`.

   IMPORTANT: the ROOT `Justfile` walks `find . -mindepth 2 -name Justfile` and
   runs `just` (the DEFAULT recipe) in each directory found. Check what
   `search`'s demo Justfile names its default recipe and match that convention,
   so `just build` at the repo root does not either skip this fixture or try to
   `pnpm install` in it.

7. Create `demo/rheo/check.sh` (executable), modelled on
   `/home/lox/code/_fcl/rookery/search/0.1.0/demo/rheo/check.sh`: compile the
   project and grep the built HTML for the structures that must be present. At
   minimum assert one `<div class="slipshow">` per page and the right number of
   `<section class="slip"` elements.

8. ADD A STEP TO `.github/workflows/check.yml`. This is the one CI file in the
   repo that does NOT auto-discover — it is a hand-written list of per-package
   steps — so without this edit `slipshow`'s build, unit fixture and demo never
   run in CI while the workflow reports green. Read the existing `todos` step
   ("todos build, unit fixture and graph tests") and the `search` demo step and
   match their shape:

```yaml
      - name: slipshow build, unit fixture and rheo demo
        run: cd slipshow/0.1.0 && just build && just test && just check
```

   PLACEMENT MATTERS and the existing steps' comments explain why: it must come
   AFTER the "Resolve the `@rookery` namespace from this checkout" step, because
   this package imports `@rookery/core:0.1.0` by coordinate, and after its own
   `just build`, because `dist/` is gitignored and rheo cannot resolve the
   package until vite has written it. Put it last, alongside the other built
   packages. Write a SHORT comment giving those two reasons — do not restate the
   neighbouring steps at length.

   That means the package `Justfile` also needs a `check` recipe, in the shape
   `todos/0.1.0/Justfile` uses:

```
check: build
    rheo compile demo/rheo
    ./demo/rheo/check.sh
```

Do NOT.

- Do NOT edit the repo root `Justfile` or
  `.github/workflows/publish-packages.yml`. Both auto-discover packages, so
  neither needs a line for this one. `check.yml` is the exception, and step 8
  above is the whole of it.
- Do NOT commit `demo/rheo/build/`. Confirm the package `.gitignore` covers it;
  add the entry if it does not.
- Do NOT use `@rookery/search` anywhere in the fixture, including in the
  predicate page. The predicate must be a plain inline Typst closure.
- Do NOT add speaker notes, `pause`, or nested-slip content.

VERIFY.

1. `cd /home/lox/code/_fcl/rookery/slipshow/0.1.0/demo/rheo && rheo compile .`
   exits 0 with no warnings about ignored elements.
2. `build/html/index.html` contains exactly one `<div class="slipshow">` and one
   `<section class="slip"` per authored note in that page.
3. `build/html/explicit.html` and `build/html/predicate.html` both exist and each
   contain a `<div class="slipshow">`.
3a. `build/html/deck.html` contains one `<div class="slipshow">`, a
   `<section class="slip"` per slip, and exactly two carrying
   `slip-fullscreen` — the opening and closing bookends.
3b. The table slip's rows are PRESENT in `build/html/deck.html`. This is the one
   assertion that catches the `grid`-in-HTML trap: a `grid` compiles clean,
   renders correctly in the PDF, and is silently empty in the browser, so a
   check on the PDF alone would pass while the page a reader opens is broken.
3c. Open `build/html/deck.html` in a browser and page through it with the
   keyboard. It is the only end-to-end look this package gets, since nothing
   outside this repo consumes it: every slip's card keeps its left border and
   tab, the fullscreen bookends fill the viewport, and no slip's content
   overflows its background.
4. The PDF output builds, and `pdftotext build/pdf/*.pdf -` shows the note bodies
   in order with no slip wrapper artefacts.
5. `cd /home/lox/code/_fcl/rookery && just build` walks the new fixture without
   error.
5a. `cd /home/lox/code/_fcl/rookery/slipshow/0.1.0 && just check` exits 0 — the
   recipe the new CI step calls.
5b. `.github/workflows/check.yml` contains a `slipshow` step, and it sits after
   the namespace-symlink step. Read the file to confirm the order rather than
   trusting the diff.
6. `cd /home/lox/code/_fcl/rookery && jj status` shows nothing under
   `demo/rheo/build/`. This machine uses jj for version control, never the other
   thing — do not reach for it even read-only.

---

### Bead 11 — `docs`

- **Title:** `readme.md` for `@rookery/slipshow`
- **Type:** docs · **Priority:** 3 · **Slug:** `docs`

**Description:**

Write `readme.md` for `@rookery/slipshow`.

Background. Every package here ships a readme that a consuming project reads to
use it. Match the register and depth of
`/home/lox/code/_fcl/rookery/search/0.1.0/readme.md` and
`/home/lox/code/_fcl/rookery/core/0.1.0/readme.md` — read both first. These
readmes explain not just the API but the constraints a project has to know
about. Read `/home/lox/code/_fcl/rookery/CLAUDE.md` for the prose style.

Steps. Create `/home/lox/code/_fcl/rookery/slipshow/0.1.0/readme.md` covering:

1. What the package is: an endlessly scrolling presentation over
   `@rookery/core` ideas, in the spirit of https://github.com/panglesd/slipshow.
   Each slip is an idea, rendered with core's own card styling — the border and
   the tab. State plainly that this package implements the slip MODEL with its
   own camera engine and does not embed slipshow's own JavaScript, which has no
   maintained embeddable distribution.

2. That it is CAMERA-ONLY: a slip is fully rendered and only the viewport moves.
   There is no `pause`/`reveal`/incremental reveal. Say it explicitly — a reader
   who knows slipshow will expect those actions.

3. That a slipshow is a FLAT ordered list of ideas. Ideas nested inside a slip
   are ordinary content; slipshow does not look into them.

4. Installation and the DOUBLE IMPORT requirement. A project must import BOTH
   `@rookery/core` and `@rookery/slipshow` in its own `.typ` files. Explain why,
   as `search`'s readme does: rheo's package asset auto-detection only scans a
   project's own files for package imports, not the packages those files'
   packages import in turn — so core's stylesheet is not injected off
   slipshow's import alone.

5. `#slip` — the augmented `#idea` wrapper. Document every option with its type
   and default: `fullscreen`, `background`, `enter`, `order`, `class`, plus
   `tags` and `exclude-tags`. `enter`'s domain is the camera action set
   (`scroll`, `up`, `down`, `center`, `focus`), which is also the vocabulary
   `src/camera.js` accepts — one set of names, and worth saying so. Note that
   every `#idea`
   argument (`title`, `level`, `created`, `show-date`, ...) is forwarded, that
   all three id forms work, and that a plain `#idea` is usable in a slipshow and
   simply takes the deck defaults.

   Include the `exclude-tags` note: a project excluding tags must pass the same
   list to `#slip` as to its `#idea` binding, for the reason core's own
   `tagged-idea` banner gives — a wrapper does not inherit a project's
   `idea.with(exclude-tags: ..)`.

6. `#slipshow` — the container. Document both definition routes with a worked
   example each: `slips:` (explicit ordered array) and `tags:`/`match:` (query).
   Document `order:` and its three forms (an array of ids, `"created"`,
   `"slip-order"`), and that `order:` is rejected alongside `slips:` because an
   explicit array is already ordered.

7. THE `a&b` QUERY LANGUAGE. Document that `tags:` also accepts a PREDICATE
   function taking a tag dictionary and returning a bool, with the worked
   example:

```typ
#import "@rookery/search:0.1.0": parse-tag-query, eval-tag-query
#slipshow(tags: t => eval-tag-query(parse-tag-query("a&b").rpn, t))
```

   State that slipshow does NOT depend on `@rookery/search`: the grammar lives
   there, the predicate is the seam, and without search a project still has
   explicit orderings and core's own `tags:`/`match: "any"|"all"`.

8. The tag surface, for a project that wants to filter or style slips itself:
   the flat keys (`slip`, `slip-fullscreen`, `slip-enter-<action>`) that render
   as pills and emit `.idea-tag-<key>` classes, and the valued keys
   (`slip-background`, `slip-order`, `slip-class`). Note that flat keys are
   filterable by core's `tags:` and by search's query language.

9. Keyboard and mouse controls, as implemented in `src/slipshow.js`.

10. Customising the CSS: the package stylesheet loads from the manifest and a
    project layers its own on top via `[[html.assets]] css_stylesheet` in
    `rheo.toml`. Mention that the slip DOM contract (`div.slipshow`,
    `section.slip`, `data-*`) is documented in `src/slipshow.typ`'s header, and
    that core's `--idea-*` variables are the tokens to reuse.

11. That it is a BUILT package: `dist/lib.js` comes from `just build`, so an
    edit to `src/*.js` takes effect only after a rebuild, while the Typst
    entrypoint and stylesheet are read from `src/` directly. Copy this
    paragraph's substance from `search`'s readme, which states the same fact
    about itself.

Do NOT.

- Do NOT document actions the package does not implement (`pause`, `reveal`,
  `step`, drawing, carousels, speaker notes).
- Do NOT claim compatibility with slipshow's own `.md` input format or its CLI.
- Do NOT include a changelog, a roadmap or a comparison table against other
  presentation tools.
- Do NOT restate rheo's own documentation; link to https://rheo.ohrg.org where a
  rheo concept needs explaining.

VERIFY.

1. `/home/lox/code/_fcl/rookery/slipshow/0.1.0/readme.md` exists.
2. `cd /home/lox/code/_fcl/rookery && just check-versions` exits 0. That lint
   reads readmes, so a stale `@rookery/<pkg>:<ver>` literal here fails it.
3. Every option named in the `#slip` section exists in `src/tags.typ`'s
   `slip-tags` signature, and every `#slipshow` argument named exists in
   `src/slipshow.typ`. Check them off one by one against the source.
4. The predicate example compiles: paste it into a scratch page of the demo
   fixture with `@rookery/search` available and confirm `rheo compile` succeeds.
   If search is not installed locally, say so rather than claiming it was tested.

---

## Part 5 — Dependency graph

Wire these with `br dep add <issue> <depends-on>`:

```
scaf ──> tags ──> slip ──┬─> ikw ──> sel ──> show ──┬─> css ──┐
                         │                          │         ├─> demo ──> docs
                         └──────────> cam ──> ctrl ───────────┘
```

Explicitly:

| bead | depends on |
| --- | --- |
| `scaf` | — |
| `tags` | `scaf` |
| `slip` | `tags` |
| `ikw` | `tags`, `slip` |
| `sel` | `ikw` |
| `show` | `sel` |
| `css` | `show` |
| `cam` | `slip` |
| `ctrl` | `cam`, `show` |
| `demo` | `css`, `ctrl` |
| `docs` | `demo` |

Notes on the shape:

- **`slip` moved ahead of `ikw` and `sel`, and that is a correction.** An
  earlier draft had `ikw` depending only on `scaf` and `sel` on `tags`+`ikw`,
  with `slip` off to one side — but both of those beads' VERIFY sections
  construct slips (`slip-tags-of(slip("a", fullscreen: true)[Body])`,
  `resolve-slips(slips: (slip("a")[A], ..))`), so neither can be verified before
  `#slip` exists. The graph now says what the tests already required.
- `cam` depends on `slip` only for the scaffold-and-tags chain beneath it; its
  geometry has no code dependency on anything and it can be picked up as soon as
  `scaf` lands if a second implementer is free. It is `ctrl`, not `cam`, that
  needs `show`'s DOM contract.
- `show` is the choke point: it fixes the DOM contract, and `css` and `ctrl`
  both encode it.
- `demo` depends on `css` and `ctrl`, which carry `show` transitively; listing
  `show` again would add nothing. It is the first point at which the package is
  proved end to end, the first point at which CI runs any of it (bead `demo`
  step 8 is the `check.yml` edit), and — since this package has no consumer
  outside this repo — the ONLY place it is ever exercised at the shape it exists
  for. Its `content/deck.typ` page carries that weight.
- `docs` is last. Every bead in this plan works inside
  `/home/lox/code/_fcl/rookery`; none reaches into another project.
