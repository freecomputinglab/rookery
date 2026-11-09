# Spike: passing minted pages their handle

**Question:** does handing each minted note page its own handle, instead of
letting it read `state("rheo-handle").get()`, cut a convergence pass from
waterline's build?

**Verdict: no.** The ablation that gives the handle read every chance to cost
a pass (`ceil`, below) converges in the same number of iterations as its own
prerequisite variant (`pre`). There is no headroom between them for a
handle-threading rewrite to recover, so `thread` — the real rewrite carrying
`page-at.handle` down to `ideas()`, `_note-href` and `_page-base` — was not
built. The minted-page handle is not the last link in the pass-count chain.

Rookery checkout used for every variant: commit `bd5b9591920b` (`jj log -r @-
--no-graph -T 'commit_id.short()'` in `/home/lox/code/_fcl/rookery`), copied
once to `/tmp/handle-spike/base` before any edit and re-copied per variant
from there. Timings are noisy — other flights built waterline concurrently
throughout — so only the convergence iteration *count* is load-bearing; each
variant was run once since counts, unlike timings, were not observed to
jitter.

## Variants

All builds: `rheo compile rookery --config <variant>.toml --html --input
today=2026-09-27 --iterations --build-dir /tmp/handle-spike/b-<variant>`,
against waterline, with `@rookery` repointed via `path =` at the variant's
copy under `/tmp/handle-spike/`. 1784 pages throughout.

| Variant | Change | Iteration line |
|---|---|---|
| `base` | unmodified | `5 convergence iteration(s) — iter(1) 4.4s, iter(2) 13.8s, iter(3) 7.9s, iter(4) 4.0s, iter(5) 388ms` |
| `pre` | measurement scaffolding: disables slug-collision tracking (`_slug-peek`), the duplicate-id registry panic, `#idea`'s handle fallback, and the duplicate-name panic in `validate.typ` | `4 convergence iteration(s) — iter(1) 4.3s, iter(2) 24.9s, iter(3) 7.0s, iter(4) 775ms` |
| `ceil` | `pre`, plus the three minted-page handle reads (`ideas()` in `data.typ`, `_note-href` in `urls.typ`, `_page-base` in `search/base.typ`) replaced with the constant `""` — every page is treated as the site root, hrefs wrong, but this is the ceiling on what dropping the handle read can buy | `4 convergence iteration(s) — iter(1) 4.5s, iter(2) 13.6s, iter(3) 4.6s, iter(4) 775ms` |

No build in either `pre` or `ceil` printed an `error:`.

## Reading the result

`pre` already converges in 4 passes rather than the 5 the bird's filing
recorded for an equivalent-looking ablation (slug read plus handle fallback
removed, with pass 4 under 1s but the count still 5). `pre` additionally
removes the duplicate-id and duplicate-name panics themselves, not only
their inputs — silencing the panic path outright, rather than just starving
it of a collision to report, is enough on its own to collapse what was
previously a wasted pass. That is a different, and new, measurement from the
one on file; it does not contradict it, since the two ablations are not the
same set of changes.

What answers this spike's question is the step from `pre` to `ceil`: forcing
every minted page's handle to resolve to a constant, maximally cheap value
bought nothing — `ceil` sits at the same 4 iterations as `pre`, with pass 4
at the same ~775ms. If the handle read were the chain's last link, `ceil`
would have to drop below `pre`, because `ceil` represents the best case for
removing it (a real handle-threading rewrite could only do as well as
replacing the read with a constant, never better). It didn't, so the handle
read reaching into `state("rheo-handle")` instead of a lexical parameter is
not, on its own, costing a pass under the version of the chain this flight
's prerequisite patches expose.

## Non-goals observed

No rookery or waterline source was left edited — every change lives under
`/tmp/handle-spike/`. The duplicate-title note and the slug counter were not
"fixed"; the `pre` patches that touch them are measurement scaffolding
only, as scoped by the bird.
