> **Caveat on timings.** Two other spike flights were building waterline copies on this same machine concurrently with these measurements, so wall-clock and per-iteration-pass times carry several seconds of noise each — scratch paths were kept unique (`/tmp/regupd-*`) precisely so the builds themselves didn't collide, but the CPU they compete for still did. The load-bearing numbers below are the convergence **iteration count** (a Typst property) and the `diff -rq` result (exact or not), neither of which a concurrent build can move.

# Spike report: does a linear registry build cut the per-note `state.update` cost?

**Verdict: yes on the measured cost, with one risk left open.** Replacing `#idea`'s per-note `_registry.update(r => { .. r.insert(id, rec); r })` with a single hidden `#metadata((id:, rec:)) <rookery-rec>` element per note, read back by one `query(<rookery-rec>).fold(..)` in `_registry-final()`, builds waterline (1,783 pages) to **byte-identical HTML** in the **same 5 convergence iterations** as the unmodified package, with `typst-compile` time down from 48.6s to 41.7s. The open risk: a comment at the removal site (`idea.typ`, next to the hidden anchor) records that *any* per-note queryable element previously tipped this exact build over Typst's 5-pass convergence limit — the new element is one of those, and it happened not to tip it over this time, but the margin to that failure is unmeasured and this spike does not establish how much room is left before it does.

## Setup

- Flight copy: `/tmp/regupd-pkg` (from this bird's flight).
- Waterline copy: `/tmp/regupd-wl`, `rsync`'d from `/home/lox/code/waterline/rookery` (PDFs/EPUBs/MP4s symlinked back to the original, per the harness), `[packages.rookery]` repointed to `path = "/tmp/regupd-pkg"`.
- `rheo` 0.6.4 on PATH, `--input today=2026-10-15`, `--html`, `--iterations`.
- BEFORE build: `/tmp/regupd-before`. AFTER build: `/tmp/regupd-after`.

## BEFORE / AFTER

```
BEFORE:  5 convergence iteration(s) — iter(1) 3.5s, iter(2) 16.2s, iter(3) 13.4s, iter(4) 7.2s, iter(5) 465ms
         1783 page(s), 41.2 MB in 49.6s (+2 asset(s)) — typst-compile 48.6s, copy-globs 594ms, plugin-write 152ms

AFTER:   5 convergence iteration(s) — iter(1) 2.6s, iter(2) 13.7s, iter(3) 13.2s, iter(4) 5.0s, iter(5) 499ms
         1783 page(s), 41.2 MB in 42.7s (+2 asset(s)) — typst-compile 41.7s, copy-globs 590ms, plugin-write 167ms
```

Iteration count: **unchanged, 5 both times** — the change does not push the build past Typst's 5-pass limit, which was the standing risk going in (see "The risk" below). `typst-compile` dropped from 48.6s to 41.7s (~14%), concentrated in iterations 1 and 4 — consistent with removing the N memoized, dictionary-hashing `state.update` resolutions this bird's background measured at 5,697 calls / 1.1s CPU on waterline, since those calls no longer exist in the AFTER build at all. Per the caveat above, these absolute numbers carry noise from concurrent builds on the same machine; the iteration count and the diff result below do not.

## Correctness

`diff -rq /tmp/regupd-before/html /tmp/regupd-after/html`: **no output — byte-identical**, across all 1,783 pages.

`cd core/0.1.1 && just test` (run against the prototype in `/tmp/regupd-pkg`, not the flight): **passes** — `test/units.typ`, `test/inputs.typ`, `demo/pure/ligaments.typ` (which specifically asserts `_reg-final()`/`_reg-merge()` ligament-merge behaviour against the new `_registry-final()`), and `test/paged-cite.typ` all compile clean. `demo/pure/backlinks-off.typ`, which is not part of `just test`'s own recipe, was compiled separately and also passes.

The flight itself (`core/` under this bird's flight path) was not touched — only `/tmp/regupd-pkg` was edited, per the bird's non-goals.

## The change

Three ideas, in order: (1) stop writing the registry through a folded `state.update`, (2) stop reading it through `state.final()`, (3) keep the duplicate-id panic's message and trigger condition, moved from eager (at registration) to lazy (at first read).

**`idea.typ`** — the per-note mint emits one hidden element instead of folding into state:

```diff
-      _registry.update(r => {
-        let existing = r.at(id, default: none)
-        if id in r and existing != rec {
-          panic(
-            "@rookery/core: duplicate note id " + id + " — already registered"
-              + (if existing.origin != none { " in " + existing.origin } else { "" })
-              + ", registered again" + (if origin != none { " in " + origin } else { "" })
-              + ". An id must be unique whether it was pinned by name or derived"
-              + " from a title — a pinned id and a title-derived id collide just"
-              + " like two pinned ids would. Retitle or rename one of the two"
-              + " notes, or pin the derived one explicitly with #idea(<some-name>, title: [..]).",
-          )
-        }
-        r.insert(id, rec)
-        r
-      })
+      [#metadata((id: id, rec: rec)) <rookery-rec>]
```

**`state.typ`** — `_registry = state("rheo-ideas", (:))` is replaced by a function that folds every `<rookery-rec>` hit in one linear pass, carrying the duplicate-id panic along with it:

```diff
-#let _registry = state("rheo-ideas", (:))
+#let _registry-final() = {
+  query(<rookery-rec>).fold((:), (acc, elem) => {
+    let id = elem.value.id
+    let rec = elem.value.rec
+    let existing = acc.at(id, default: none)
+    if id in acc and existing != rec {
+      panic(
+        "@rookery/core: duplicate note id " + id + " — already registered"
+          + (if existing.origin != none { " in " + existing.origin } else { "" })
+          + ", registered again" + (if rec.origin != none { " in " + rec.origin } else { "" })
+          + ". An id must be unique whether it was pinned by name or derived"
+          + " from a title — a pinned id and a title-derived id collide just"
+          + " like two pinned ids would. Retitle or rename one of the two"
+          + " notes, or pin the derived one explicitly with #idea(<some-name>, title: [..]).",
+      )
+    }
+    acc.insert(id, rec)
+    acc
+  })
+}
```

`_reg-merge`/`_reg-final` (also `state.typ`) are unchanged except their two `_registry.final()` reads become `_registry-final()` calls.

Every other reader of `_registry.final()` is updated the same way — a plain rename, no logic change: `.marrow.typ:107`, `demo/pure/backlinks-off.typ:16`, and `demo/pure/ligaments.typ:319` (plus its import lists and `lib.typ`'s wildcard re-export, which needs no edit since `#import "state.typ": *` already carries whatever `state.typ` defines).

The full prototype diff (five files) is in `/tmp/regupd-pkg`, unstaged against this bird's flight; the patch above covers the two load-bearing files. `data.typ`, `window.typ`, `outline.typ`, `pure.typ`, `idea.typ`'s own comment banner at line ~720 mention `_registry.final()` only in comments, not call sites that needed touching for correctness — a real implementation bird should still sweep those for wording, plus the two stale comment lines at `demo/pure/ligaments.typ:238-239` which still say `_registry.final()`.

## The risk this spike leaves open

Directly below the removed `_registry.update(..)` call, `idea.typ` carries a comment (kept, unedited, in the prototype) recording that an earlier attempt to emit a LIGAMENTS element from this exact spot — "even a content-free dummy `#metadata(..)`" — broke Typst's 5-pass convergence on both `demo/notes` and this same waterline build ("document did not converge within five attempts"). The `#metadata((id:, rec:)) <rookery-rec>` element this spike adds is precisely the shape that comment warns against: one more queryable element, per note, at the one place in the call graph already proven to sit at the convergence edge.

It did not tip the build over this time — AFTER converged in 5 iterations, same as BEFORE — but this spike offers no margin measurement: it does not say how close to 6 iterations this build now sits, nor whether a future, larger waterline (more notes, more cross-links) would still converge under the same change. The comment's warning is about *adding* a per-note element; this change *replaces* one quietly-expensive mechanism (a folded state) with one differently-expensive mechanism (a queryable element), and the two are not proven equivalent in their effect on convergence pass count in general — only in this one measurement.

## Recommendation

The linear-fold approach is worth landing for real — it is a genuine, measured win on the cost this bird set out to cut (the O(N²) folded `state.update`), it preserves byte-identical output and the duplicate-id panic's behaviour, and the package's own test suite needs no change beyond the mechanical rename. A follow-up implementation bird should: apply the patch above to `core/`; sweep the stale `_registry.final()` comments this spike left untouched (`demo/pure/ligaments.typ:238-239`, and the banner comments in `data.typ`/`window.typ`/`outline.typ`/`pure.typ`/`idea.typ`); and rewrite the LIGAMENTS comment at the removal site in `idea.typ` so it describes the new element's existence rather than contradicting it. Before shipping, it would be worth re-running this same waterline build once more in isolation (no concurrent builds) to get a convergence-iteration reading with real margin visibility, since this spike's single run proves the change doesn't cross the line today but says nothing about how close it now sits.

## Where the work lives

- `/tmp/regupd-pkg` — the prototype package copy (`core/0.1.1/src/idea.typ`, `src/state.typ`, `.marrow.typ`, `demo/pure/backlinks-off.typ`, `demo/pure/ligaments.typ` touched; nothing else).
- `/tmp/regupd-wl` — waterline's rookery content, repointed at `/tmp/regupd-pkg`.
- `/tmp/regupd-before` / `/tmp/regupd-after` — the two cold builds diffed above.

No file in `/home/lox/code/_fcl/rookery/core/` or `/home/lox/code/waterline` was touched; this bird's own flight carries only this document.
