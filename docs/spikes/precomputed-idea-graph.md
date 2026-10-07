> **Caveat on timings.** A sibling spike (settings, `/tmp/sws-*`) was compiling
> rheo projects on this machine concurrently with these measurements. Treat
> wall-clock ms as noise; the load-bearing number in every row below is the
> convergence **iteration count**, a Typst property, not a scheduling one.

# Spike report: does a precomputed idea graph cut convergence passes?

**Verdict: no. Handing the whole idea graph to the build through `sys.inputs`
does not move the pass count off 5.** Baseline, the data-only-registry
predecessor, graph-from-input, and two follow-up experiments that stripped
further per-note introspection (bibliography, the syndication feed) all
converge in exactly 5 passes on this fixture. The floor a plain rheo page sets
is 2; nothing tried here gets closer to it than the unmodified package already
was.

## Setup

- Package copy: `/tmp/pig-pkg`, from `/home/lox/code/_fcl/rookery`, with the
  data-only-registry diff from `docs/spikes/data-only-registry.md` applied by
  hand to `core/0.1.1/src/idea.typ` and `core/0.1.1/src/transclusion.typ` (the
  three call sites in `window.typ`/`.marrow.typ` updated to pass `id` instead
  of `rec`, as that document's diff implies but doesn't spell out).
  Confirmed against that diff's own "after" line before building anything new:
  5 iterations, byte-identical HTML, `just test` passes.
- Fixture: `/tmp/pig-fx`, from `core/0.1.1/demo/rheo`, `[packages.rookery]`
  repointed to `path = "/tmp/pig-pkg"`.
- `rheo` 0.6.4 on PATH, `--iterations` used throughout.

## The change

- **`.marrow.typ`**: mints one extra page, `rookery-graph.html`, dumping every
  note's data fields plus the already-inverted page-backlinks map as JSON
  (`raw(json.encode(graph))`), skipped when a graph was itself supplied as
  input. The page-backlinks computation itself now branches: with a supplied
  graph it reads `input-graph.page-backlinks` directly and never calls
  `_page-links()` — no beacon query at all for that map.
- **`src/state.typ`**: added `_graph()` (parses `sys.inputs.at("rookery-graph")`
  through `json(bytes(..))`, `none` when absent), `_graph-rec(entry)` (rebuilds
  one note's registry-shaped record from its graph entry), `_encode-tag-value`/
  `_decode-tag-value` (see Correctness), and `_reg-final()` — the one function
  every real reader now calls instead of `_registry.final()`, graph-aware.
- **13 real call sites** across `.marrow.typ`, `transclusion.typ`, `data.typ`,
  `hyperlink.typ`, `window.typ`, `outline.typ`, `permalink.typ`, `idea.typ`
  switched from `_registry.final()` to `_reg-final()`.
- **`idea.typ`**: the `_registry.update(..)` write (and the duplicate-id panic
  it carries) is skipped outright when `_graph() != none` — nothing is ever
  written to `_registry` in graph mode; every reader reaches the graph's
  reconstruction instead.
- The body carrier from the data-only-registry spike (`#metadata((raw: body))`
  under `label("rookery-body:" + id)`, read back with
  `query(label(..)).first()`) is untouched and still runs unconditionally in
  both modes — content cannot travel through `sys.inputs`, so it remains the
  only route to a note's body.

## Before / after / graph-from-input

Raw `rheo compile --iterations` lines, the load-bearing ones:

- baseline (unmodified package, bird's filing figure): `5 convergence
  iteration(s)`, 67 pages, 481ms.
- graph supplied via `--input rookery-graph=..`: `5 convergence iteration(s)`
  — iter(1) 37ms, iter(2) 64ms, iter(3) 130ms, iter(4) 100ms, iter(5) 11ms —
  67 pages, 690ms.

Full table, all six builds:

| build | iterations | per-iteration | pages | wall |
|---|---|---|---|---|
| baseline (unmodified package, bird's filing figure) | 5 | — | 67 | 481ms |
| data-only registry (dependency spike, re-confirmed here) | 5 | 27, 63, 135, 108, 10ms | 67 | 703ms |
| graph dumped, no input supplied (instrumented build) | 5 | 26, 63, 140, 120, 12ms | 68 | 743ms |
| **graph supplied via `--input`** | **5** | 37, 64, 130, 100, 11ms | 67 | 690ms |
| graph supplied + bibliography disabled | 5 | 37, 61, 122, 98, 10ms | 67 | 435ms |
| graph supplied + syndication feed disabled | 5 | 35, 64, 133, 99, 11ms | 67 | 447ms |

Every row: **5 convergence iteration(s)**. The wall-clock column swings by
±300ms across identical iteration counts — exactly the noise the caveat above
warns about — and is not the result being reported.

Graph size: 53 notes, 22KB of JSON, passed as a literal `--input` CLI argument
(well under `ARG_MAX`; the fallback of an `[inputs]` key in `rheo.toml` named
in the bird was not needed).

## Correctness

`diff -rq` between a graph-free build and the graph-supplied build (both from
the same patched package, same fixture, `rookery-graph.html` excluded from the
comparison since it only exists in the former): **19 of 68 files differ**, all
of one of two shapes, both traceable to `sys.inputs` carrying strings only:

1. **18 files** (every titleless note's minted page, plus their reflection on
   nothing else): the graph-supplied build's `<h1>` carries an empty
   `<span class="idea-title" data-rookery="title"></span>` that the graph-free
   build's `<h1>` does not. Cause: a titleless note's real `rec.title` is
   `none`; the graph dump projects every title through `_plain()` regardless
   (`_plain(none) == ""`), and `_graph-rec` rewraps that empty string as
   `[#""]` — empty content, but not `none`. The one reader that branches on
   `rec.title == none` (`.marrow.typ`'s `<h1>` builder) takes the "has a
   title" arm and emits an empty span. Purely a plain-text-title artifact, one
   the bird's own VERIFY explicitly allows.
2. **1 file** (`ideas/ref-titled.html`, echoed in `ideas/index.html`'s link
   text for that row): a title built from `[About #ref(<idea:cited-note>)]`
   loses the referenced note's name — "About Cited note" becomes "About ". The
   graph dump flattens titles with `_plain()`, whose `ref` branch has no
   registry to resolve against and returns nothing for one (`_plain`'s own
   banner: "a caller with no registry to resolve against"); the real registry
   reader used by `ideas()`/the page title (`_ref-text(reg)`-aware projection)
   *does* have one. Also a plain-text-title artifact by the letter of the
   bird's allowance, though a sharper one than case 1 — it silently drops
   real information, not just an empty wrapper element.

No other differences. `cd core/0.1.1 && just test` passes against the patched
package.

**One fact from the bird's own filing needs a correction.** "Typst 0.15.1
round-trips a nested dictionary through `json.encode`/`json(bytes(..))`
unchanged" does not hold for every value a tag can carry: the fixture's own
`tag-valued` note stores a real `datetime` under `date-deadline`, and
`json.encode` does not refuse it — it silently substitutes `repr()`'s string
form (`"datetime(year: 2026, month: 11, day: 1)"`), which then fails a
downstream `tag-index(.., stamp: true)` assertion that expects a real
`datetime` back. `_encode-tag-value`/`_decode-tag-value` special-case
`datetime` specifically (round-tripped as a small tagged dictionary) to avoid
the failure; any OTHER non-JSON-safe tag value (content, for instance) is not
handled and would hit the same silent-`repr()` trap. None of this fixture's
other tags exercise that case.

## Why the pass count didn't move (two more mechanisms ruled out)

Building on the dependency spike's finding that removing content from
`_registry` doesn't touch the pass count: this spike additionally removed the
`_registry` write/read cycle entirely (nothing written, every reader served
from parsed input) and the one `_page-links()` beacon query this fixture's
mint loop depends on, and the count still didn't move. Two follow-up
experiments each disabled one more per-note-or-per-page introspection
mechanism, on top of the graph-supplied build:

- **Bibliography off** (`bibliography: none` in the demo's `ctx`, dropping
  `#cite`/margin-note resolution): still 5.
- **Syndication feed off** (`syndicate: false`, dropping the per-note feed
  beacon `#metadata(..)#label("feeds:item")` and its `rec.created` reads):
  still 5.

Both ruled out as sole causes. What remains active in every row above,
including the best one, is the body carrier's own
`#metadata((raw: body))#label(..)` + `query(label(..))` round trip — the
one thing this design cannot remove, because content has no route through
`sys.inputs`. That is now the leading remaining suspect, unconfirmed: the
data-only-registry spike's own theory was that *some* per-note
introspection existing at all — regardless of what it stores — is what pass 4
(and, on this evidence, pass 5 too) pays for, and the body carrier is exactly
that shape.

## Unknowns

- Whether removing the body carrier's `metadata`+`query` mechanism entirely
  (resolving a note's body from a document-tree walk instead) would drop the
  count below 5 — not tested; doing so on this fixture would mean
  reimplementing how every reader gets a note's rendered content, well past
  this spike's scope.
- Whether the 4th and 5th passes have the same cause or two different ones —
  neither this spike nor its predecessor isolates that.
- Whether a *smaller* input graph (a project with far fewer than 53 notes, or
  one with no cross-note title references/tag-selected windows at all) would
  converge faster than 5 passes even with the body carrier still active — not
  tried; every measurement here used the same 53-note fixture throughout for
  comparability.

## What producing the graph without a prior compile would take

Both routes this spike's non-goals rule out are real options for a follow-up,
and this spike's own dump mechanism (a JSON-only projection of every `#idea`
call's data fields, computed here from a completed compile) sizes what either
would need to reproduce. A **static scan** of a project's `.typ` sources for
`#idea(` call sites, run before Typst starts, would have to re-derive titles,
tags, links and tag-selectors from source text without evaluating Typst
markup or resolving `#show`/`.with(..)` sugar — every tag constructor this
demo uses (`#note`, `#todo`, `#draft`, `.with(tags: ..)` chains) is exactly the
kind of indirection a textual scan cannot see through, so it would likely need
to fall back to a real (if minimal) Typst evaluation pass rather than regex
over source, at which point it is doing much of what a normal compile already
does. Reusing the **previous build's own graph under `rheo watch`** is the
cheaper-looking route precisely because this spike proves the artifact itself
is small (22KB for 53 notes) and mechanical to produce — a watch session that
already holds yesterday's graph could hand it back in as `sys.inputs` for any
rebuild that doesn't touch an `#idea` call's own arguments, at the cost of
invalidating it (falling back to a real compile once) whenever one does. Both
routes are moot for THIS spike's own question, though: this spike shows that
even a perfect, free graph — computed with no cost at all, as `--input` here
effectively is — still leaves the build at 5 convergence passes, so neither
route would, by itself, buy back the difference between a warm rebuild and
rheo's own 2-pass floor.

## Where the work lives

- `/tmp/pig-pkg` — patched package copy (`core/0.1.1/src/idea.typ`,
  `src/transclusion.typ`, `src/window.typ`, `src/state.typ`, `src/data.typ`,
  `src/hyperlink.typ`, `src/outline.typ`, `src/permalink.typ`, `.marrow.typ`
  touched).
- `/tmp/pig-fx` — fixture repointed at `/tmp/pig-pkg`.
- `/tmp/pig-graph.json` — the extracted 53-note graph used for every
  graph-supplied build below.
- `/tmp/pig-before` / `/tmp/pig-after` — the correctness-diff pair (graph-free
  vs graph-supplied).
- `/tmp/pig-exp-bib` / `/tmp/pig-exp-synd` — the two follow-up experiments.
- `/tmp/pig-verify`, `/tmp/pig-graphdump`, `/tmp/pig-nograph` — intermediate
  builds along the way (setup verification, first graph dump, re-dump after
  the tag-value fix).

No file in `/home/lox/code/_fcl/rookery/core/`, `/home/lox/code/_fcl/rheo`, or
`/home/lox/code/waterline` was touched.
