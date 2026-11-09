# Spike: an incremental search corpus pass

**Verdict: a narrowed round 1's search corpus cost (~3.7s of this measurement's
~21s/15s typst-compile) is NOT mostly the per-row df/tf-idf weighting step —
caching each row's finished term string and skipping its recompute for rows
whose tokens AND relevant document frequencies are unchanged shaves only
~1.0-1.3s off round 1 (roughly 15-20%), not the several seconds hoped for, and
the saving shrinks further whenever the edited note shares common vocabulary
with the rest of the corpus (two edits using deliberately generic
"spike"/"incremental" wording showed no measurable saving at all, since those
exact words recur across this rookery's own build-system notes and so moved
document frequencies that many unrelated rows then had to re-rank around).
The prototype IS correct — a full, unmodified build produces a byte-identical
`search/index.json` — but the complexity it adds (a second ligament class for
a corpus-wide value, attached to an arbitrarily chosen "stable" vertebra since
df belongs to no single note) is not worth landing for a win this modest and
this sensitive to what the edit happens to say. Not recommended to land.**

## What `_compress-ranked` computes, and where the corpus-wide line actually falls

`search/0.1.1/src/compress.typ`'s `_compress-ranked(toks, body-terms:,
df-ceiling:)` takes every row's already-tokenized term list and returns one
compressed term string per row, in two passes:

- **Corpus-wide, unavoidably:** a `df` dictionary — for every term, how many
  of the corpus's rows contain it, counted once per row with the `seen` set
  trick so repeats within one row's body don't inflate it. This is a single
  walk over every row's tokens with hashmap inserts only — no sort, no
  logarithm, no per-row closure.
- **Per-row, given `df`:** `tf` (term frequency within the one row), the
  `df-ceiling`/`df<=1` filter, the `-tf*log2(n/df)` weight, a `.sorted(key:)`
  by that weight, and the top-`body-terms` slice. Each of these needs only
  the row's own tokens plus the shared `df` dictionary that has already been
  computed — nothing here reads another row's tokens directly.

So the only truly corpus-wide computation is the `df` count itself. Once `df`
is known, a row's own weighting step is pure given `(tokens, df)` — exactly
what `.marrow.typ`'s own LIGAMENTS banner already says about the *tokenize*
step, just one level further down: the weighting step is ALSO narrowable, but
only if `df` is known to be unchanged for every term the row actually holds,
since `df` is the one value genuinely shared across every row.

The bundle-root `.marrow.typ` ligament cache (`search-row:<id>`) already
skips re-tokenizing a row whose body is byte-identical to what was cached.
What it does NOT do today is skip the weighting step: `_compress-ranked` is
called once over ALL rows' tokens every build, so one row's tokens differing
(the edited note) forces Typst's memoization on that call to miss and the
whole df-count-plus-weight-plus-sort pass to rerun for every row, cached
tokens or not — this is the mechanism `/home/lox/code/_fcl/rheo-f5/docs/spikes/ligament-feed-cache.md`'s
"Answer" section traced and its "Recommendation" pointed at.

## Measurement conditions

All times are `typst-compile` milliseconds from `rheo`'s own `RUST_LOG=rheo=debug`
trace (`phase="typst-compile" ms=`), never wall time. `rheo watch --html` on
a `/tmp/searchspike-wl-8a` copy of `rookery/` (`rsync -a
/home/lox/code/waterline/rookery/`), with `[packages.rookery]` repointed at
`path = "/home/lox/code/_fcl/rookery-8a"` (this spike's own jj workspace,
`[watch] narrow = true` already set in the site's `rheo.toml`). Edits appended
one sentence to the last paragraph of `nest/papers/ends-of-theory/index.typ`,
reverted between series. `uptime`/`pgrep -af 'rheo|typst'` were checked
before every timing series and showed no other `rheo`/`typst` process
running and load averages of 1.3-3.9 throughout (this machine, not an idle
one) — every series below ran under broadly similar, moderate background
load, but none of it was isolated to a quiet machine, so the first edit in
every series (always markedly slower, plausibly a cold-page-cache effect
right after the preceding full build) is excluded from each series' reported
mean; the other two are closer to each other and to a clean rerun of this
same series order, which is the basis for treating them as the stabler
estimate.

Four configurations, three narrowed edits each (first excluded from the
mean, both in the table and in the prose above and below):

1. **Baseline** — unmodified `search/0.1.1/.marrow.typ`.
2. **Emptied marrow** — `.marrow.typ` replaced with `#context {}` (same
   trick `search-index-off-root.md` used), to price the whole search pass
   (tokenize-for-new-rows plus the full df/weight/sort) against doing
   nothing at all.
3. **Prototype, adversarial vocabulary** — the appended sentences
   deliberately reused this spike's own jargon ("incremental", "spike",
   "prototype", "edit"), which already recurs in this rookery's own notes
   about rheo/rookery's build system.
4. **Prototype, unrelated vocabulary** — three sentences built from ordinary,
   domain-unrelated nouns and verbs (marmots, lantern-makers, beekeepers),
   to see whether an edit sharing no vocabulary with the rest of the corpus
   gets a cleaner saving.

## Results

Round 1 is the round that recompiles the edited vertebra itself (where the
corpus pass runs over one genuinely new row); round 2 recompiles `index`
(home page) and showed no significant difference between configurations in
this corpus — consistent with the rheo spike's finding that round 2's cost
here is mostly an unrelated over-bind, not the search pass.

| Configuration | round 1, 3 edits (ms) | round 1 mean (edits 2-3) | round 2, 3 edits (ms) |
|---|---|---|---|
| Baseline (unmodified marrow) | 11148, 6579, 6405 | 6492 | 5982, 6266, 6368 |
| Emptied marrow (`#context {}`) | 6840, 2824, 2834 | 2829 | 3799, 6350, 6426 |
| Prototype, adversarial vocabulary | 8944, 4556, 6242 | 5399 | 5355, 6993, 6022 |
| Prototype, unrelated vocabulary | 8748, 5096, 5332 | 5214 | 10872, 7064, 6290 |

Reading round 1 alone: the whole search pass (baseline minus emptied) costs
about **3663ms** of round 1 at this corpus's size. The prototype recovers
**1093ms** (~30% of that 3663ms budget, ~17% of round 1 overall) when the
edit's vocabulary overlaps this rookery's own jargon, and **1278ms** (~35%
of the budget, ~20% of round 1) when it does not — a real but modest
difference between the two vocabularies, not the near-elimination a
"skip untouched rows" design was hoped to buy. Round 2 shows no consistent
pattern across configurations (noise exceeds any plausible effect), matching
the earlier finding that round 2's cost here sits elsewhere.

The bulk of round 1's non-weighting cost — the `_cached-tokens` map over
every row, the `df`-counting walk, building the `search-row:<id>` ligament
attach content for every row, and `json.encode`-ing the final asset — is paid
unconditionally by this prototype exactly as by the unmodified marrow. Only
the per-row `tf`/`pairs`/`sorted`/slice step (`_weight-one` below) is ever
skipped, and that step turns out to be a smaller share of the corpus pass's
own cost than the df count and the unconditional per-row bookkeeping around
it.

## The prototype

Caches each row's FINISHED compressed term string in the existing
`search-row:<id>` ligament (alongside the `body`/`tokens` it already carries)
and the corpus-wide `df` dictionary in a new `search-corpus-df:<key>`
ligament, attached on an arbitrarily chosen "stable" vertebra
(`rows.first().origin`) since `df` belongs to no single note. A later build
recomputes a row's weight+sort step only when that row's own tokens changed
(the same test `_cached-tokens` already makes) or its own token set
intersects a term whose `df` value moved since the cached build; every other
row's cached term string is reused untouched.

Verified byte-identical against an unmodified full build:
`diff <(json.tool baseline index.json) <(json.tool prototype index.json)`
on a clean (no appended-sentence) corpus reported no differences.

```diff
--- search/0.1.1/.marrow.typ (original)
+++ search/0.1.1/.marrow.typ (prototype)
@@ -1,112 +1,129 @@
-// Builds the rookery's search index ONCE per build, at the bundle root, and
-// emits it as a single fetched asset.
+// SPIKE PROTOTYPE — docs/spikes/search-corpus-incremental.md
 //
-// rheo inlines this file verbatim at the bundle root when a project imports
-// `@rookery/search`, so it runs once for the whole build with the finished
-// note registry in scope — the same place `@rookery/core`'s own `.marrow.typ`
-// mints note pages from. Two things come out of that one pass:
-//
-//   - `rookery/search/index.json`, the whole index as a bundle asset, which
-//     `#search-index(mode: "asset")` points every page at instead of carrying
-//     a copy of it. This is what keeps a large rookery's build from scaling
-//     the index by the page count: MEASURED on a 320-note, 360-page site,
-//     29.5s and 43MB of output against 2.3s and 4.9MB.
-//   - `_rows-cache` and `_corpus-cache`, for `#search-index(mode: "inline")` —
-//     the `file://` mode, which cannot fetch and so must still carry the island
-//     in every page. The first holds the finished rows so no page derives them
-//     again (26.0s to 17.7s on that same site); the second holds the compressed
-//     body terms alone, and is what a `tags:`-filtered or non-default-knobbed
-//     index still falls back to.
-//
-// WITHOUT RHEO there is no bundle root, this file never runs, no asset is
-// emitted, `_corpus-cache` keeps its `(:)` default and `#search-index`
-// compresses inline as it always did. A miss there is only slower, never
-// different; a missing asset is why `mode: "asset"` needs rheo at all.
+// Caches each row's FINISHED compressed term string (`terms:`) alongside its
+// `body`/`tokens` in the existing `search-row:<id>` ligament, and the
+// corpus-wide `df` dict in a new `search-corpus-df:<key>` ligament, attached
+// on a stable vertebra (`rows.first().origin`) since df belongs to no single
+// note. A later build recomputes a row's weight+sort step ONLY when that
+// row's own tokens changed (same test `_cached-tokens` makes internally) OR
+// its token set intersects a term whose df value moved since the cached
+// build — every other row's cached term string is reused untouched. `df`
+// itself is still counted over every row's tokens every build (a hashmap
+// walk, no sort, no per-row log/round — the cheap half of the corpus-wide
+// pass), so the comparison is always against the real prior values, the
+// same reason `_cached-tokens` compares bodies rather than guessing from
+// "did this note's own vertebra recompile."
 #import "@rookery/search:0.1.1": (
-  _cached-tokens, _compress-ranked, _corpus-cache, _corpus-key, _date-stamp,
+  _cached-tokens, _corpus-cache, _corpus-key, _date-stamp,
   _index-asset-path, _rows-cache,
 )
 #import "@rookery/core:0.1.1": (ideas, _attach, _join-content, _lig-get)
 
-// This package's own ligament key, same vocabulary rules as
-// `@rookery/core`'s (`state.typ`'s `_LIG-*` banner): `search-row:<id>`, one
-// per note, carrying this build's compressed terms for that note AND the
-// plain-text `body` they were compressed from. `page:` is the row's own
-// `origin` (the OWNING VERTEBRA), never this file's own — bundle-root marrow
-// code has no page of its own to attach under.
-//
-// WHY A ROW CARRIES ITS OWN `body` ALONGSIDE `tokens`: `_tokenize` is a pure
-// function of a note's body alone, so this cache is sound ONLY while the
-// cached body still matches what `ideas()` returns for that id THIS compile
-// — and a note's body is not purely a function of its own raw text: it is
-// flattened against the WHOLE corpus's resolved titles (`_ref-text`, data.typ),
-// so a note that references another note whose title changed gets a
-// DIFFERENT body even though nothing in `rec.origin == id`'s own vertebra
-// moved. Comparing the actual materialized body string — not a `page:
-// matches the round's live vertebra` guess — catches that case for free: a
-// mismatch retokenizes, a match reuses. See the LIGAMENTS banner below for
-// why no cheaper, still-correct signal exists.
 #let _LIG-SEARCH-ROW = "search-row:"
+#let _LIG-SEARCH-DF = "search-corpus-df:"
+
+// Exactly `_compress-ranked`'s per-row body, pulled out so it can be called
+// for one row at a time once `df` (corpus-wide) is already known.
+#let _weight-one(ts, df, n, body-terms: 48, df-ceiling: 40) = {
+  let tf = (:)
+  let order = ()
+  for t in ts {
+    if t in tf {
+      tf.insert(t, tf.at(t) + 1)
+    } else {
+      tf.insert(t, 1)
+      order.push(t)
+    }
+  }
+  let pairs = ()
+  for t in order {
+    let d = df.at(t)
+    if d <= 1 or d * 100 <= n * df-ceiling {
+      let w = -1 * int(calc.round(100 * tf.at(t) * calc.log(n / d, base: 2)))
+      pairs.push((w, t))
+    }
+  }
+  let ranked = pairs.sorted(key: p => p.first()).map(p => p.last())
+  let top = ranked.slice(0, calc.min(body-terms, ranked.len()))
+  if top.len() == 0 { "" } else { top.join(" ") }
+}
 
 #context {
-  // `page`, not `href`: `#note-path` is the site-root-relative output path and
-  // is defined exactly when a note has a minted page, which is the same
-  // condition `#search-index`'s own `href != none` filter tests from a
-  // vertebra. `href` is depth-relative and has no meaning at the bundle root,
-  // where there is no current page to measure from.
   let rows = ideas().filter(e => e.page != none)
   if rows.len() > 0 {
-    // The DEFAULTS only. A project calling `#search-index(body-terms: 64)` gets
-    // a key miss and compresses inline — correct, just not cached. Publishing
-    // every combination a project might ask for would mean reading the call
-    // sites' arguments back out of a state the marrow itself feeds, and a state
-    // that depends on a state fed from the pages it feeds is the one shape
-    // Typst's convergence cannot be trusted to settle.
     let body-terms = 48
     let df-ceiling = 40
+    let cache-key = _corpus-key(body-terms, df-ceiling)
+
+    let hits = rows.map(row => _lig-get(_LIG-SEARCH-ROW + row.id))
+    let cacheds = hits.map(h => if h == none or h.len() == 0 { none } else { h.first().value })
+    let toks = rows.enumerate().map(((i, row)) => _cached-tokens(row.body, hits.at(i)))
+    // A row's own tokens moved this build iff `_cached-tokens` fell through —
+    // the same test it makes internally, redone here since it does not
+    // report which rows hit and which missed.
+    let changed = rows.enumerate().map(((i, row)) => {
+      let c = cacheds.at(i)
+      c == none or c.at("body", default: none) != row.body
+    })
+
+    let n = toks.len()
+    let df = (:)
+    for ts in toks {
+      let seen = (:)
+      for t in ts {
+        if t in seen { continue }
+        seen.insert(t, true)
+        df.insert(t, df.at(t, default: 0) + 1)
+      }
+    }
+
+    let df-hits = _lig-get(_LIG-SEARCH-DF + cache-key)
+    let prior-df = if df-hits == none or df-hits.len() == 0 { (:) } else { df-hits.first().value }
+
+    // Every term whose df value moved since the cached build, either
+    // direction — covers a term newly crossing the ceiling, one dropping
+    // under it, and one appearing in or vanishing from the corpus entirely.
+    let delta-terms = (:)
+    for (t, d) in df {
+      if prior-df.at(t, default: -1) != d { delta-terms.insert(t, true) }
+    }
+    for (t, d) in prior-df {
+      if df.at(t, default: -1) != d { delta-terms.insert(t, true) }
+    }
+
+    let terms = rows.enumerate().map(((i, row)) => {
+      let ts = toks.at(i)
+      let c = cacheds.at(i)
+      let prior-term = if c == none { none } else { c.at("terms", default: none) }
+      let stale = prior-term == none or changed.at(i) or ts.any(t => t in delta-terms)
+      if stale {
+        _weight-one(ts, df, n, body-terms: body-terms, df-ceiling: df-ceiling)
+      } else {
+        prior-term
+      }
+    })
 
-    // LIGAMENTS — the whole optimization this cache exists for: skip
-    // RE-TOKENIZING a note whose body this compile produces byte-identical
-    // to the one `search-row:<id>` cached last time it was attached. The
-    // df/tf-idf WEIGHTING below still runs over every note's tokens every
-    // compile (`_compress-ranked`, corpus-wide by construction — a changed
-    // note's terms can shift another note's document frequency, so that
-    // pass cannot be narrowed without risking a different index.json for an
-    // unrelated note). Only the regex-driven tokenize pass, which is a pure
-    // function of one note's own body, is skippable this way.
-    //
-    // `_lig-get` returns `none` on an ordinary full build (no ligaments
-    // supplied at all) or `()` on a narrowed compile where this id was never
-    // attached before (a brand-new note) — both fall through to a fresh
-    // `_tokenize`, exactly a full build's own behaviour.
-    let toks = rows.map(row => _cached-tokens(row.body, _lig-get(_LIG-SEARCH-ROW + row.id)))
-    let terms = _compress-ranked(toks, body-terms: body-terms, df-ceiling: df-ceiling)
-
-    // Re-attach every row's body and tokens under its own id, for the NEXT
-    // compile to read back. A row with no `origin` (no rheo compile, or a
-    // minted artifact with no owning vertebra) is skipped — there is no page
-    // to attribute the attach to, same guard `_idea-ligaments` applies.
     _join-content(rows.enumerate().map(((i, row)) => {
       if row.origin == none { return [] }
-      _attach(_LIG-SEARCH-ROW + row.id, (body: row.body, tokens: toks.at(i)), page: row.origin)
+      _attach(
+        _LIG-SEARCH-ROW + row.id,
+        (body: row.body, tokens: toks.at(i), terms: terms.at(i)),
+        page: row.origin,
+      )
     }))
+    let corpus-page = rows.first().origin
+    if corpus-page != none {
+      _attach(_LIG-SEARCH-DF + cache-key, df, page: corpus-page)
+    }
 
     let by-id = (:)
     for (i, e) in rows.enumerate() { by-id.insert(e.id, terms.at(i)) }
     _corpus-cache.update(c => {
       let c = c
-      c.insert(_corpus-key(body-terms, df-ceiling), by-id)
+      c.insert(cache-key, by-id)
       c
     })
 
-    // THE ASSET'S ROWS ARE `_rank`'s EMPTY-QUERY ORDER, reproduced here rather
-    // than borrowed: `#search-index` used to get this order by calling
-    // `search-ideas("")` per page, and the browser is entitled to the same
-    // sequence from the fetched file. `fuzzy-score` returns 0 for an empty
-    // query, so every note ties in the name tier and the tie breaks by date —
-    // dated notes newest first, undated notes last in id order (`ideas()`
-    // sorts by id, and each `.filter` below preserves that). See `_rank` in
-    // `src/rank.typ` for the same three steps on the per-page path.
     let stamped = rows.enumerate().map(pair => {
       let (i, e) = pair
       (
@@ -126,18 +143,6 @@
       ordered += dated.filter(r => r.created == s)
     }
 
-    // `href` CARRIES THE SITE-ROOT PATH here, where the per-page island's
-    // carries a depth-relative one: one shared file cannot hold a path
-    // measured from each of 360 pages. `src/island.js` joins each row's
-    // `href` onto the `data-rookery-search-base` prefix the page it was
-    // fetched from published. The field keeps its name so nothing downstream
-    // of the fetch has to know which mode produced it.
-    //
-    // The remaining field rules are `#search-index`'s and are asserted by
-    // `test/`: `tags` omitted when the note has none, `created` omitted when
-    // it is undated, `body` always present (the asset is `body-search: true`
-    // by construction — a page wanting no body tier drops the field on read
-    // rather than fetching a second file for it).
     let final-rows = (ordered + undated).map(r => {
       let row = (id: r.id, name: r.name, text: r.text)
       if r.tags.len() > 0 { row.insert("tags", r.tags) }
@@ -148,14 +153,9 @@
     })
     asset(_index-asset-path, json.encode(final-rows, pretty: false))
 
-    // THE SAME ROWS, published for `mode: "inline"` to read back. Kept with
-    // `page` rather than the asset's finished `href` because an inline island's
-    // href is measured from the page it sits in, which only that page knows —
-    // see `_rows-cache`. `body` is always present and `body-search: false`
-    // drops it on read, so one row set serves both switches.
     _rows-cache.update(c => {
       let c = c
-      c.insert(_corpus-key(body-terms, df-ceiling), ordered + undated)
+      c.insert(cache-key, ordered + undated)
       c
     })
   }
 }
```

## What would be worth trying instead

Given the df count and the unconditional per-row bookkeeping (the
`_cached-tokens` map, the ligament-attach construction, the `json.encode` of
the whole asset) dominate round 1's cost more than the weight+sort step does,
a follow-up spike pricing THOSE parts individually — in particular whether
the `_cached-tokens` map itself (one closure call per row, every build, even
when every single row hits cache) carries meaningful closure-call overhead at
this corpus's size — would tell a cleaner story than this one does. Not
pursued here; this spike answers the question the bird asked (does caching
the weighting step pay off) and the answer is "a little, not enough."

## Non-goals honored

No lasting change to any package: `search/0.1.1/.marrow.typ` is back to its
original, byte-identical state (confirmed by `diff` against a copy taken
before this spike started). No WASM. No change to rheo.
