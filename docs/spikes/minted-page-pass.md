# Spike: the minted-page fifth pass

**Verdict:** the fifth convergence pass is caused by the minted page's footer
carrying BOTH of two things at once — `context-part`'s `_page-href(origin,
here: page-at.handle)` call (an un-deferred, eager page-href lookup) and
`backlinks-part`'s `window(...)` rows (the folded transclusions for a note's
`from:` parents/children and its ordinary backlinks). Neither one alone costs
the fifth pass. Removing either — zeroing `context-part`, or zeroing just the
three `window()` calls (`parent-rows`/`child-rows`/`note-rows`) while leaving
everything else including `context-part`'s `_page-href` call untouched — drops
the build to 4 iterations. Leaving both in, even with `backlinks-part`'s other
half (`page-rows`, which is unrelated) removed, keeps it at 5. No
dependency-avoiding prototype was found that preserves `context-part`'s output
and removes the interaction: wrapping its `_page-href` call in its own
`context { .. }` block (the pattern `page-rows` already uses for the same
helper) did NOT fix it — still 5 passes. Swapping `_handle-title` for a static
placeholder, while keeping `_page-href` real, also did NOT fix it — still 5
passes. So the specific trigger is `_page-href` itself, called un-deferred
inside `context-part`, stacked against at least one `window()` call elsewhere
on the same page — not `_handle-title`, not `page-rows`'s own (already
deferred) page-href call, and not generic footer bulk (a same-sized inert
placeholder in `context-part`'s place also dropped the count to 4).

**Caveat on timings:** this machine ran two other spike flights' waterline
builds concurrently throughout. Wall times below swing by several seconds
build to build for that reason and are reported only for context — the load-
bearing number in every row is the convergence **iteration count**, which is
deterministic: the unmodified tree was rebuilt twice (rows 1 and 8) and
produced identical 5-iteration counts both times.

## Builds

All builds: `rheo compile /tmp/mpp-wl --html --input today=2026-10-15
--build-dir <dir> --iterations`, against a scratch copy of waterline's
content repointed at this flight via `path =` (see harness in the bird). Page
count 1783 unless noted.

| # | What changed | Iteration line | typst-compile |
|---|---|---|---|
| 1 | BEFORE — unmodified tree | `5 convergence iteration(s) — iter(1) 3.8s, iter(2) 18.6s, iter(3) 11.7s, iter(4) 5.5s, iter(5) 378ms` | 46.9s |
| 2 | `.slice(0, 0)` on the mint loop's `registry.pairs()` (confirms the known 4-pass result; 604 pages, not 1783) | `4 convergence iteration(s) — iter(1) 2.6s, iter(2) 11.8s, iter(3) 7.3s, iter(4) 408ms` | 28.2s |
| 3 | Both `page-body` (lines 530-600: `_footnoted`/`_refs-block`) and the whole footer (601-798: `context-part` + `backlinks-part`) replaced with `[]` | `4 convergence iteration(s) — iter(1) 3.7s, iter(2) 15.1s, iter(3) 10.4s, iter(4) 1.4s` | 38.8s |
| 4 | Footer only replaced with `[]`; `page-body` untouched | `4 convergence iteration(s) — iter(1) 2.6s, iter(2) 14.4s, iter(3) 10.0s, iter(4) 678ms` | 36.0s |
| 5 | `page-body` only replaced with `[]`; footer untouched | `5 convergence iteration(s) — iter(1) 3.3s, iter(2) 15.8s, iter(3) 8.9s, iter(4) 3.3s, iter(5) 350ms` | 38.9s |
| 6 | Within the footer: `backlinks-part` zeroed (`let backlinks-part = []`), `context-part` untouched | `4 convergence iteration(s) — iter(1) 2.5s, iter(2) 13.2s, iter(3) 8.4s, iter(4) 640ms` | 35.2s |
| 7 | Within the footer: `context-part` zeroed (`let context-part = []`), `backlinks-part` untouched | `4 convergence iteration(s) — iter(1) 2.5s, iter(2) 13.0s, iter(3) 8.9s, iter(4) 689ms` | 35.6s |
| 8 | BEFORE, rechecked (unmodified tree, no changes carried over from row 7) | `5 convergence iteration(s) — iter(1) 2.6s, iter(2) 13.2s, iter(3) 9.9s, iter(4) 4.2s, iter(5) 358ms` | 40.9s |
| 9 | `context-part` replaced with an inert same-size placeholder (`[Lorem ipsum ...]`, no `_page-href`/`link`/`window`); `backlinks-part` fully untouched | `4 convergence iteration(s) — iter(1) 2.7s, iter(2) 13.3s, iter(3) 9.0s, iter(4) 694ms` | 35.5s |
| 10 | `context-part` untouched; within `backlinks-part`, only the three `window()` calls zeroed (`parent-rows`, `child-rows`, `note-rows` all `= []`), `page-rows` untouched | `4 convergence iteration(s) — iter(1) 2.5s, iter(2) 12.7s, iter(3) 8.1s, iter(4) 631ms` | 31.1s |
| 11 | `context-part` untouched; within `backlinks-part`, only `page-rows` zeroed, all three `window()` calls untouched | `5 convergence iteration(s) — iter(1) 2.6s, iter(2) 12.8s, iter(3) 9.3s, iter(4) 4.1s, iter(5) 350ms` | 39.7s |
| 12 | `context-part`'s `_page-href` call wrapped in its own `context { .. }` block (mirroring `page-rows`'s existing deferred pattern), output otherwise unchanged; `backlinks-part` fully untouched | `5 convergence iteration(s) — iter(1) 2.5s, iter(2) 13.2s, iter(3) 10.4s, iter(4) 6.2s, iter(5) 441ms` | 43.5s |
| 13 | `context-part`'s `_handle-title(origin, mode: page-titles)` replaced with a static placeholder; its `_page-href` call left real and un-deferred; `backlinks-part` fully untouched | `5 convergence iteration(s) — iter(1) 3.3s, iter(2) 15.4s, iter(3) 14.0s, iter(4) 4.0s, iter(5) 393ms` | 47.2s |

## Reading the table

Rows 6/7 (and 9, same conclusion with an inert placeholder) establish that
`context-part` and `backlinks-part` are each individually "load-bearing" for
the fifth pass — removing either one alone is enough to drop to 4 — so the
5-pass behavior needs both halves of the footer present together. Rows 10/11
narrow `backlinks-part` further: it is specifically its `window()` calls
(`parent-rows`/`child-rows`/`note-rows`) that matter, not `page-rows` (the
other half of `backlinks-part`, itself a `_page-href` call but deferred
inside its own `context { .. }`, per the existing banner at that call site).
Rows 12/13 narrow `context-part` the same way: it is specifically the
`_page-href(origin, here: page-at.handle)` call that matters, not
`_handle-title`, and wrapping that call in a `context { .. }` of its own
(the fix `page-rows` already applies for the identical helper) does not
remove the interaction.

So the fifth pass needs, on the same minted page: an eager (non-deferred)
`_page-href` call in `context-part`, AND at least one `window()`-rendered row
in `backlinks-part`. Every build that kept both of those present measured 5
passes (rows 1, 5, 8, 11, 12, 13); every build that removed either measured 4
(rows 2, 3, 4, 6, 7, 9, 10).

## No working prototype

Step 4 of this spike calls for prototyping a variant that keeps
`context-part`'s output but avoids the dependency, if one part is
responsible. Two candidate variants were tried and neither removed the fifth
pass while keeping `_page-href`'s real resolution:

```diff
-        let context-part = if origin == none or not use-context { [] } else {
-          let context-href = _page-href(origin, here: page-at.handle)
-          let context-dest = if context-href != none { context-href + "#" + id } else { label(id) }
-          section(_c("context"), "context", [Context],
-            page-list((link(context-dest, _handle-title(origin, mode: page-titles)),)))
-        }
+        let context-part = if origin == none or not use-context { [] } else {
+          section(_c("context"), "context", [Context],
+            page-list((context {
+              let context-href = _page-href(origin, here: page-at.handle)
+              let context-dest = if context-href != none { context-href + "#" + id } else { label(id) }
+              link(context-dest, _handle-title(origin, mode: page-titles))
+            },)))
+        }
```

(row 12 — still 5 passes), and swapping only `_handle-title` for a
placeholder while leaving `_page-href` eager and real (row 13 — still 5
passes). Both rule out the easy fixes: deferring the call the way
`page-rows` does, and suspecting `_handle-title` instead of `_page-href`.
Since the interaction is between `_page-href` and `window()`'s own
introspection rather than a defect isolated to one call site, a genuine fix
would need to change how `window()` or `_page-href` resolve relative to each
other — out of scope for this spike's budget. No prototype is included; the
deliverable here is the isolation itself (`_page-href` in `context-part` x
`window()` in `backlinks-part`), for whoever picks this up next.

## Non-goals observed

Nothing in the flight changed except this document — every marrow.typ edit
made during bisection was reverted before writing it up, and `core/0.1.1 &&
just test` passes against the restored tree.
