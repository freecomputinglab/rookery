> **Caveat, added at filing.** Wall-clock timings below were taken while a
> sibling flight (a data-only-registry spike, `/tmp/dor-*`) was compiling
> rheo projects on the same 12-core machine concurrently. Treat every
> millisecond figure as noise; the load-bearing number is the convergence
> **iteration count**, which is discrete and was re-run three times each
> side to confirm it wasn't itself jittering.

# Spike report: settings without state in rookery core

**Verdict: hard-coding every document-wide settings read does NOT reduce the
convergence iteration count. Both the unmodified package and the fully
hard-coded package converge in 5 iterations on the demo fixture. This lead is
refuted — the settings are not costing a pass, and no follow-up bird is
warranted from this spike alone.**

## Setup

- `/tmp/sws-pkg` — a full copy of this repository, edited only in
  `core/0.1.1` (never `/home/lox/code/_fcl/rookery` or
  `/home/lox/code/waterline`).
- `/tmp/sws-fx` — a copy of `core/0.1.1/demo/rheo`, `[packages.rookery] path`
  repointed at `/tmp/sws-pkg`.
- `/tmp/sws-pkg-clean` / `/tmp/sws-fx-clean` — a second, wholly untouched
  copy of the same pair, rebuilt independently to confirm the baseline is
  stable and not itself an artifact of the first copy's state.
- `rheo 0.6.4` on PATH, which already has `--iterations`.

## What the fixture sets, and what everything else defaults to

`content/lib.typ`'s one `#show: rookery.with(..)` call sets:
`idea-page-template: idea-page` (a named function), `index-page: true`
(matches the default), `syndicate: true`, `theme: (tags-color: (note:
rgb("#3366ff"), secret: rgb("#ff0000")))`, `invisible-tags: ("secret",)`,
`bibliography: arguments(bytes(read("refs.bib")))` (style defaults to
`"chicago-author-date"`). Every other parameter — `prefix`, `idea-dir`,
`css-prefix`, `window-unfurl`, every `display-*` key, `page-titles`,
`footnotes`, `citations` — is left at `rookery()`'s own default.

## What was hard-coded

Found every settings state's `.final()` reader with
`rg -n --hidden '\.final\(\)' core/0.1.1/src core/0.1.1/.marrow.typ` (about
80 hits) and hard-coded the ones on states `#show: rookery` writes, computing
each fixture-specific literal by hand from the block above and from
`rookery()`'s own parameter defaults (`src/template.typ`):

- **`src/state.typ`**: `_pfx()`, `_dir()`, `_cls()` (prefix/idea-dir/css-prefix)
  return literals directly. `_display-final` reads a new `_DISPLAY-DEFAULTS`
  dict instead of `_DISPLAY-STATES.at(k).final()`. `_visible-tags` filters
  against a literal `("secret",)` instead of `_invisible-tags.final()`.
  `_bib-keys()` runs off a new `_bib-frozen` (an `arguments` built from a
  `refs.bib` copy placed alongside `state.typ`, since a package cannot
  `read()` a path outside its own root — the real reason `_bib` was ever
  state in the first place) instead of `_bib-key-cache.final()` /
  `_bib.final()`.
- **`src/theme.typ`**: `_theme-style()` and `_tags-color-rules()` read a new
  `_theme-frozen` — the fixture's `tags-color` dict, hand-resolved through
  the package's own `_resolve-theme`/`_resolve-tags-color` logic to
  `(tags-color: (note: (background: "#3366ff"), secret: (background:
  "#ff0000")))` — instead of `_theme.final()`.
- **`src/bib.typ`**: all three `_bib.final()` reads (`_bib-call`,
  `_refs-block`, `_sweep-block`) point at `_bib-frozen`.
- **`src/transclusion.typ`**, **`src/window.typ`**: the two `_window-depth.final()`
  reads become the literal `1`.
- **`.marrow.typ`**: `_idea-page-template.final()` becomes
  `_idea-page-template-frozen`, a literal copy of the fixture's own
  `idea-page` function pasted into `state.typ` (the package cannot import a
  project's function, so for a single-fixture spike the body is duplicated
  verbatim). `_syndicate`, `_display-context`, `_display-backlinks`,
  `_display-title`, `_page-titles`, `_footnote-mode`, `_citation-mode`,
  `_index-page` all become their fixture literals (`true`, `true`, `true`,
  `true`, `"title"`, `"vertical"`, `"vertical"`, `true`).
- **`src/template.typ`**: every `.update()` whose only reader was one of the
  above is deleted from `rookery()`'s settings block. `_backlinks.update`
  stays — its one reader (`idea.typ`) uses `.get()`, not `.final()`, and the
  bird scoped this spike to `.final()` reads only. `citations`/`theme`
  resolution logic is kept where a *local* variable (not a state) still feeds
  a later `data-rookery-citations` marker in the same function.

`_registry.final()`, the backlinks-harvested graph (`.get()`-read), and the
per-idea/per-page citation-key scans (`_own-cited-keys` and friends, which
answer "what does *this content* cite", not a settings question) were left
untouched, as scoped.

## Iteration counts

Three runs each side, `rheo compile . --html --iterations`, 67 pages:

| | run 1 | run 2 | run 3 |
|---|---|---|---|
| **before** (unmodified `/tmp/sws-pkg-clean`) | 5 — 30/27/159/127/10ms | 5 — 27/25/146/134/11ms | — |
| **after** (hard-coded `/tmp/sws-pkg`) | 5 — 31/68/110/137/8ms | 5 — 30/68/103/123/7ms | 5 — 31/69/98/126/8ms |

5 convergence iterations both before and after, every run. No bisection was
needed — per the bird's instruction, bisection is only for a count that
*dropped*; this one didn't move at all.

## Correctness (VERIFY 1–2)

`diff -r /tmp/sws-before/html /tmp/sws-after/html` — zero differences, not
even a `loc-N` id drift. `cd core/0.1.1 && just test` passes against the
real, untouched package in this flight (`units OK`).

## Why the count didn't drop

The demo fixture already needed 5 passes with a plain, unconfigured
`#show: rookery` (recorded at filing: "`#show: rookery` with no notes = 3;
plus any `#idea` = 4; plus a citation = 5"). This fixture has both notes and
a citation, so it was already at the ceiling the filing recon describes
*before* any settings-state cost is added or removed. The three earlier
drivers named at filing — the page-links beacon's `context`, `#idea`'s own
registration, and the citation/bibliography positional partition — are all
still state-driven and untouched by this spike (they read `_registry`,
harvest backlinks, or resolve citations from Typst's own bibliography
machinery, none of which this spike touched). Removing the settings reads
took away zero of those three, so the ceiling didn't move. This is
consistent with, not contradicting, the filing recon's other finding that
making the page-links beacon contextless *also* didn't reduce the count once
any note exists — the 5-pass ceiling on this fixture looks driven by
`#idea`/citation machinery, not by settings.

## Unknowns

- Not tested on a fixture with fewer built-in convergence drivers — e.g. a
  page with `#show: rookery` and no `#idea` at all (the filing recon's "3"
  case) or one with notes but no citation (its "4" case). It's possible
  settings-state costs a pass only below this ceiling, on a document that
  wouldn't otherwise need 5 passes; this spike's one fixture cannot
  distinguish "settings cost nothing" from "settings cost something already
  masked by a higher-order driver its own recon names."
- Not tested at waterline's actual scale (858 pages, many settings readers
  invoked per page via `ideas()`/`tag-data()`-style aggregate reads) — the
  per-note-registry spike (`docs/spikes/per-note-registry.md`, this same
  directory) found that a per-key `state.final()`'s cost can scale with how
  many distinct reads an aggregate caller issues, and settings reads are
  exactly the kind of read every page issues at least once each; this
  spike's 67-page single-vertebra-config fixture may not be representative
  of that aggregate cost even if it says nothing about pass *count*.
- `_idea-page-template-frozen`'s body is a hand-pasted duplicate of the
  fixture's own function, not a real mechanism — a real project could not
  ship a package that has to know its callers' functions verbatim. The
  sketch in the bird (`rheo.toml` `[inputs]` read through `sys.inputs`) would
  not help here either: a function value cannot cross `sys.inputs`, which
  only carries strings. Whatever replaces this one setting, if any ever
  does, needs a different channel than the rest.
