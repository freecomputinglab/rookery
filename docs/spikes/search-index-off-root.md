# Spike: search index off the bundle root

**Verdict: keep the index build as a single Typst-script pass in
`.marrow.typ`. Prototype a WASM plugin (route A) and it is correct — a
real waterline build with the plugin wired in produces a byte-identical
`index.json` and byte-identical HTML everywhere else — but it is only about
2.5-3x faster than the Typst script it replaces, not the 10-100x a
plugin is usually worth. That turns an estimated ~6s of a ~30-45s cold
build into roughly 2-4s saved, and it would leave the package maintaining
two implementations of the same compression rule (Typst stays mandatory for
the `file://`/no-rheo inline fallback) with a real correctness gap already
open between them (grapheme clusters vs. Rust `char`s) and a new axis for
`just parity` to pin. Not worth landing at this rookery's size. The
prototype and its numbers are below for when a larger corpus changes that
arithmetic.**

## Measurements

All times are `typst-compile` seconds from rheo's own summary line (never
wall time, which includes HTML writing and asset copying). The machine ran
two other spike flights' waterline builds concurrently throughout this
work, so every full-build figure below carries several seconds of noise —
every number is reported with its spread, and none of the per-configuration
splits taken from full builds alone should be trusted on their own; they
are corroborated against a clean, isolated microbenchmark run with no other
load.

### Full waterline builds (noisy — concurrent builds on the machine)

`rheo compile` of a scratch copy of waterline's rookery
(`/home/lox/code/waterline/rookery`) with `[packages.rookery]` repointed at
a flight-copy of this package tree, `--build-dir /tmp/srch-*`, 1783 pages,
41.2MB output.

| Configuration | typst-compile (s), n samples | mean |
|---|---|---|
| Unmodified `.marrow.typ` (baseline) | 43.1, 44.3, 39.6 | 42.3 |
| `.marrow.typ` emptied entirely (`#context {}`, no `ideas()`/tokenize/rank/asset) | 41.4, 32.9, 34.7 | 36.3 |
| `_compress-ranked` stubbed to `toks.map(_ => "")` (tokenize runs, rank skipped) | 38.1, 44.2 | 41.2 |
| Tokenize also stubbed (`toks = rows.map(_ => ())`, only `ideas().filter(..)` runs) | 36.6, 31.2 | 33.9 |
| WASM plugin prototype wired into `.marrow.typ` (route A) | 40.3, 33.3 | 36.8 |

The baseline-vs-emptied delta (42.3s - 36.3s ≈ 6.0s) is this rookery's
version of the bird's own ~3s waterline measurement — larger here, plausibly
because of the concurrent load, not a real regression. The within-block
split implied by the middle two rows (tokenize costs ~7s added to the
`ideas()` floor, ranking costs ~1s added on top) does not match the clean
microbenchmark below and should be discarded — the spread on 2-3 samples
under contention is wider than the effect being measured.

### Clean microbenchmark (no rheo, no HTML pages, no concurrent load)

A synthetic corpus of 1179 bodies (300-900 words each, drawn from a 70-word
general vocabulary plus 400 distinctive per-document terms, to give `df` a
realistic spread) run through `search/0.1.1/src/compress.typ`'s real
`_tokenize`/`_compress-ranked` via a standalone `typst compile` of a 4-line
driver file — no rheo, no page layout, nothing but the two functions under
test. This isolates the three costs the bird asked about:

| Pass | typst-compile (s) | 
|---|---|
| `_tokenize` only (`bodies.map(_tokenize)`) | 3.3, 3.3 |
| `_tokenize` + `_compress-ranked` (the real pass) | 5.06, 5.07, 6.56 |

So: tokenizing costs about **3.3s**, and the df/tf-idf ranking pass adds
another **~2-3s** on top — ranking is NOT free, contrary to what the noisy
full-build numbers above suggested. `ideas().filter(..)` itself is cheap
enough to be within the noise floor of both the full-build and the
microbenchmark measurements (candidate route C's premise — that the sort
key closures in `_compress-ranked` are the expensive part — undercounts:
tokenizing, not ranking, is the larger of the two, and both are real).

### WASM plugin prototype, same microbenchmark

A hand-written Rust plugin (`/tmp/srch-plugin/tokenize.rs`, ~250 lines)
implementing Typst's `wasm-minimal-protocol` ABI directly — no crates, since
the sandbox this spike ran in has no network access to crates.io (a real
implementation on a developer's machine would reach for the
`wasm-minimal-protocol` crate and `wasm-bindgen`-free macros the usual way,
rather than hand-rolling the ABI). Compiled with a bare `rustc --target
wasm32-unknown-unknown` — nixpkgs ships a prebuilt `std` for that target, so
no `cargo`/crates.io dependency was needed even for this hand-rolled
version. Two input encodings were tried:

| Variant | typst-compile (s) |
|---|---|
| JSON array in/out (`json.encode`/`json.decode` on the Typst side, hand-rolled JSON parse in Rust) | 2.7, 2.8, 2.8 |
| `\0`-joined strings in/out, byte-level `char_indices` scan in Rust (no `Vec<char>` collect, no JSON) | 2.1, 2.1, 2.4 |

The second, leaner marshaling format is the one reported as "the prototype"
below. Isolating further: `tokenize_fast` alone (no rank) took ~1.2s against
pure Typst's 3.3s (**~2.75x**), and the full tokenize+rank plugin call took
~2.1-2.4s against pure Typst's 5-6.5s (**~2.5-3x**). This is a real, honest
speed-up from a first attempt — but it is nowhere near the "10-100x" a WASM
plugin is normally expected to buy over Typst script, because a large share
of a naive plugin's time goes to marshaling bytes across the host/plugin
boundary rather than to the tokenize/rank computation itself; a more heavily
tuned implementation would likely close some of that gap further, not open
a new one.

## The prototype (route A), wired into a real build

`/tmp/srch-pkg` is a flight copy with `.marrow.typ` and
`search/0.1.1/src/compress.typ` modified to call the plugin instead of the
Typst-script pass; `search/0.1.1/search-tokenize.wasm` is the compiled
plugin binary. Built the full waterline scratch project against it
(`/tmp/srch-after`, `/tmp/srch-after2`) and compared against the unmodified
baseline build (`/tmp/srch-before2`):

```
diff -rq /tmp/srch-before2/html /tmp/srch-after/html
# (no output — zero differences across all 1783 pages)

md5sum /tmp/srch-before2/html/rookery/search/index.json \
       /tmp/srch-after/html/rookery/search/index.json
# 46a9fb... (identical) for both — index.json is byte-for-byte equal
```

Every output file, including `rookery/search/index.json`, came out
byte-identical between the Typst-script pass and the plugin pass on this
rookery's real 1179-note corpus. That is a stronger correctness result than
the microbenchmark alone would justify, since it exercises the real body
text (punctuation, non-ASCII, note cross-references) rather than synthetic
words — though see the two gaps below that this corpus happens not to
trigger.

```diff
--- a/search/0.1.1/.marrow.typ
+++ b/search/0.1.1/.marrow.typ
@@
 #import "@rookery/search:0.1.1": (
   _cached-tokens, _compress-ranked, _corpus-cache, _corpus-key, _date-stamp,
-  _index-asset-path, _rows-cache,
+  _index-asset-path, _rows-cache, _spike-plugin-bytes,
 )
@@
-    let toks = rows.map(row => _cached-tokens(row.body, _lig-get(_LIG-SEARCH-ROW + row.id)))
-    let terms = _compress-ranked(toks, body-terms: body-terms, df-ceiling: df-ceiling)
-
-    // Re-attach every row's body and tokens under its own id, for the NEXT
-    // compile to read back. A row with no `origin` (no rheo compile, or a
-    // minted artifact with no owning vertebra) is skipped — there is no page
-    // to attribute the attach to, same guard `_idea-ligaments` applies.
-    _join-content(rows.enumerate().map(((i, row)) => {
-      if row.origin == none { return [] }
-      _attach(_LIG-SEARCH-ROW + row.id, (body: row.body, tokens: toks.at(i)), page: row.origin)
-    }))
+    // Tokenize + rank in a WASM plugin instead of Typst script. Ligament
+    // caching is dropped on this branch — the plugin has no per-note token
+    // cache to re-publish, so a real patch would need to push
+    // `_lig-get`/`_attach` into the plugin ABI too, or accept that a
+    // narrowed rebuild retokenizes every note through the plugin (still
+    // fast; just not cached).
+    let _spike-plugin = plugin(_spike-plugin-bytes)
+    let joined = rows.map(row => row.body).join("\u{0}")
+    let out-bytes = _spike-plugin.tokenize_rank_fast(bytes(joined))
+    let terms = str(out-bytes).split("\u{0}")

--- a/search/0.1.1/src/compress.typ
+++ b/search/0.1.1/src/compress.typ
@@
 #import "base.typ": *

+// The WASM plugin bytes, read relative to THIS file (inside the package)
+// rather than from `.marrow.typ`, which rheo inlines at the bundle root —
+// a path written there resolves against the project being compiled, not
+// the package, so `plugin("search-tokenize.wasm")` from `.marrow.typ`
+// fails with "file not found". Reading the bytes here and handing them to
+// `plugin(bytes)` from the marrow file sidesteps that.
+#let _spike-plugin-bytes = read("../search-tokenize.wasm", encoding: none)
+
 // The stopword FLOOR, not the filter: ...
```

(The full Rust source is at `/tmp/srch-plugin/tokenize.rs` — not reproduced
here at ~250 lines; its header comment lists the known gaps, repeated
below.)

## Why not land it

- **The win is modest, not dramatic.** ~2.5-3x on the tokenize+rank pass
  translates to an estimated 2-4s off a ~30-45s cold build (the plugin
  build above landed at 33-40s against a 40-44s baseline, consistent with
  that estimate but swallowed by this machine's contention noise).
- **It does not replace the Typst-script path, it duplicates it.**
  `.marrow.typ`'s own header is explicit that `_tokenize`/`_compress-ranked`
  stay the fallback for `#search-index`'s `mode: "inline"` (the `file://`
  build, which cannot fetch an asset and so has no bundle root to run a
  marrow pass at all). A plugin only speeds up the bundle-root hot path;
  the inline Typst pass has to stay, so landing route A means maintaining
  two implementations of the same rule rather than replacing one.
- **`just parity` does not cover this pass today, and a plugin would need
  it to.** Today's parity suite pins `fuzzy-score`/`body-score` (the
  scorer, which reads already-compressed `body` terms) against
  `score.js`/`bodyScore`, and `_rank` against `search`/`score.js`'s tiering
  — it has no reference implementation at all for `_tokenize` or
  `_compress-ranked` themselves, because today there is only one
  implementation to drift from. A landed plugin needs that parity suite
  widened to cover it, on top of everything it already covers.
- **A real correctness gap is open and this spike's corpus didn't trigger
  it.** The prototype counts token length in Rust `char`s; `_tokenize`
  counts in Typst `clusters()` (extended grapheme clusters). This is the
  same distinction `search/0.1.1/src/text.js` already had to get right for
  a different matcher (its own comment: 73 of 250 fixture cases disagree
  when done as a code-point spread instead of grapheme segmentation) —
  closing it in Rust needs a real Unicode segmentation dependency, not
  `char_indices`. This rookery's 1179 real notes happened to produce a
  byte-identical index.json anyway (apparently no note here has a term
  whose grapheme-cluster count and `char` count disagree at the 3-cluster
  floor), but that is this corpus's luck, not a property of the plugin.
- **The hand-rolled JSON/ABI marshaling in this prototype is not
  production code.** It was written without network access to crates.io (no
  `wasm-minimal-protocol`, no `serde_json`); a real patch would use both and
  likely close some but not all of the marshaling-cost gap above.

## What would change the arithmetic

The marrow block's cost scales with corpus size (df/tf-idf is corpus-wide,
not per-note) and with body length (tokenizing is linear per body). A
rookery with several times today's 1179 notes, or with much longer note
bodies, would turn today's ~6s into something large enough that a 2.5-3x
cut is worth a second implementation and its parity surface. At that point,
revisit this spike's numbers rather than re-deriving them, and favor the
real `wasm-minimal-protocol` crate and a grapheme-aware Rust tokenizer over
this prototype's shortcuts.

## Routes not prototyped further

- **Route B (ship raw bodies, compute in the browser):** rejected without a
  full prototype. It needs the identical new port of `_tokenize`/
  `_compress-ranked` into JavaScript that route A needs into Rust — same new
  parity-surface cost, in a different language — while ALSO multiplying
  `index.json`'s size (shipping full plain-text bodies instead of
  `body-terms: 48`'s compressed ~146-byte-average rows;
  `search/0.1.1/src/corpus.typ`'s own comment notes that even cutting
  `body-terms` from 48 to 8 only takes a 320-note site's build from 20.5s to
  28.6s cheaper the wrong way — nearly all the cost is in walking and
  tokenizing the corpus, not in how many terms are kept, so shipping whole
  bodies buys little on the build side while making every page's first
  fetch bigger). It also moves the cost from one build to every visitor's
  first page load, which is a worse trade for a site with repeat traffic
  than a one-time build cost, not a better one.
- **Route C (profile and cut waste in `_compress-ranked`):** the clean
  microbenchmark above shows ranking taking ~2-3s on top of tokenizing's
  ~3.3s — a real cost, but tokenizing is still the larger half, so even a
  free fix to the sort-key closures `_compress-ranked` uses (~1.26M calls on
  waterline, per the bird) would not reclaim most of the ~6s prize. Not
  pursued further in this spike; a follow-up targeting just the sort
  mechanics could still be worth a small, low-risk patch on its own terms,
  independent of this verdict.
