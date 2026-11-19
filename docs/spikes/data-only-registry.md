> **Caveat on timings.** A sibling spike (settings, `/tmp/sws-*`) was compiling rheo projects on this machine concurrently with these measurements. Treat wall-clock ms as noise; the load-bearing number below is the convergence **iteration count**, which is a Typst property, not a scheduling one.

# Spike report: does a data-only registry cut convergence passes?

**Verdict: no. The 4th convergence pass is not caused by the registry carrying note bodies.** Moving every note's `raw`/`body` out of `_registry` and into a per-note `metadata` carrier, read back via `query(label(..))`, compiles to byte-identical output and still takes 5 convergence iterations, same as the unmodified package.

## Setup

- Package copy: `/tmp/dor-pkg` (from `/home/lox/code/_fcl/rookery`).
- Fixture: `/tmp/dor-fx` (from `core/0.1.1/demo/rheo`), `[packages.rookery]` repointed to `path = "/tmp/dor-pkg"`.
- `rheo` 0.6.4 on PATH, `--iterations` used throughout.

## The change

`core/0.1.1/src/idea.typ`: dropped `raw:`/`body:` from the `_registry` record; added a hidden per-note carrier beside the existing anchor:

```diff
       let rec = (
         title: title,
         label: note-label,
-        raw: body,
-        body: _flatten(body),
         created: resolved-created,
         origin: origin,
         links: links,
@@
       {
         show figure.where(kind: "rheo-idea-anchor"): none
         [#figure([], kind: "rheo-idea-anchor", supplement: none)#label(id)]
+        [#metadata((raw: body)) #label("rookery-body:" + id)]
       }
```

`core/0.1.1/src/transclusion.typ`: `_body-at` now takes `id` instead of `rec` and queries the carrier; the WK show rule's inline expansion does the same (the `depth == 2` cache-reuse special case falls away — `_flatten(raw, depth: 1)` is what `rec.body` always was):

```diff
-      let inner = if depth == 2 { rec.body } else {
-        _flatten(rec.raw, depth: depth - 1)
-      }
+      let raw = query(label("rookery-body:" + id)).first().value.raw
+      let inner = _flatten(raw, depth: depth - 1)
@@
-#let _body-at(rec, depth: auto) = {
+#let _body-at(id, depth: auto) = {
   let d = if depth == auto { _window-depth.final() } else { depth }
-  if d <= 1 { rec.body } else { _flatten(rec.raw, depth: d) }
+  let raw = query(label("rookery-body:" + id)).first().value.raw
+  _flatten(raw, depth: d)
 }
```

`core/0.1.1/.marrow.typ` (minted page) and `core/0.1.1/src/window.typ` (`#window`'s unfurl branch, `idea-body`): the three call sites pass `id` — already in scope at all three — instead of `rec`.

`ideas()`/`src/data.typ`, the settings `.update()` in `template.typ`, and the page-links beacon were not touched, per the bird's non-goals.

## Before / after

| | iterations | per-iteration | pages | wall |
|---|---|---|---|---|
| before (unmodified package) | 5 | 29ms, 26ms, 159ms, 143ms, 11ms | 67 | 474ms |
| after (data-only registry) | 5 | 30ms, 61ms, 152ms, 113ms, 10ms | 67 | 470ms |

Iteration count: **unchanged, 5 both times.** Wall time is within noise of concurrent load on this machine (see caveat above) and is not the result being reported.

## Correctness

- `diff -r /tmp/dor-fx-before/html /tmp/dor-fx-after/html`: **zero differences.** The fixture's 67 pages are byte-identical.
- `cd /tmp/dor-pkg/core/0.1.1 && just test`: **passes.** `units.typ`'s `raw:` fixture (used by `_rec-label`) needed no change — it builds its own literal record for a different function than the one this spike touched, and Typst dictionaries tolerate the extra key regardless.

Waterline was not built against the patched package: step 6 of the bird is conditional on dropping below 5 passes, which did not happen.

## Why the pass count didn't move

The 4th pass survives `#idea` gaining a body carrier, so it is not paid for storing/re-rendering a copy of a note's content in `_registry`. The carrier still round-trips content through `metadata` + `query(label(..))` inside `context`, which is itself an introspection dependency — the same general shape as the state read it replaced. Whatever forces pass 4 looks like it is tied to *some* per-note introspection existing at all (any note, any storage shape), not to the volume or duplication of what that introspection carries. This spike does not identify what that dependency actually is; it only rules out "the registry carries content twice" as the cause.

## Unknowns

- Whether an approach that removes per-note introspection *entirely* (e.g., resolving bodies from a document-tree walk rather than any `state`/`metadata` + `query`) would drop the pass count — not tested here; this spike only changed the STORAGE and READ mechanism, not whether one exists.
- Whether the pass 4 trigger is the `_registry` state's own existence (any record shape) versus something else in the `#idea` call graph (backlink harvesting, the anchor label, the tag/link fields still on `rec`) — not isolated.
- The 5th pass's cause is also unexplained and out of this spike's scope.

## Recommendation

Do not pursue a data-only registry as a route to fewer convergence passes — the correctness path (byte-identical output, cache-friendly per-note query) is sound and could still be worth it for other reasons (smaller registry state, less duplicated content in memory), but it does not touch the pass count this bird set out to explain. The 4th pass needs a different, narrower spike — most plausibly one that removes per-note state/metadata introspection altogether on a minimal fixture, to test whether ANY such mechanism (regardless of what it stores) is what pass 4 pays for.

## Where the work lives

- `/tmp/dor-pkg` — patched package copy (`core/0.1.1/src/idea.typ`, `src/transclusion.typ`, `src/window.typ`, `.marrow.typ` touched; nothing else).
- `/tmp/dor-fx` — fixture repointed at `/tmp/dor-pkg`, `/tmp/dor-fx-before` and `/tmp/dor-fx-after` its two builds.

No file in `/home/lox/code/_fcl/rookery/core/` or `/home/lox/code/waterline` was touched.
