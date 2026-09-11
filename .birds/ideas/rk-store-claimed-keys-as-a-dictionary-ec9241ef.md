---
id: rk-store-claimed-keys-as-a-dictionary-ec9241ef
short-id: ec
title: Store claimed keys as a dictionary
priority: 4
labels:
- chore-bibtex-review
deps: []
closed: false
---
Store the claimed-key set as a dictionary instead of an array, so checking
whether a key is already claimed is a hash lookup instead of a linear scan.

Touches: /home/lox/code/_fcl/rookery/bibtex/0.1.0/src/claim.typ, /home/lox/code/_fcl/rookery/bibtex/0.1.0/src/lib.typ

## The problem, located exactly

`/home/lox/code/_fcl/rookery/bibtex/0.1.0/src/claim.typ` line 12:

```typst
#let _claimed = state("rookery-bibtex-claimed", ())
```

`_claimed` holds an ARRAY (a Typst tuple), initialized empty. Two places touch
it, both in `/home/lox/code/_fcl/rookery/bibtex/0.1.0/src/lib.typ`:

1. Line 147, inside the `citation:` closure — the only writer:

   ```typst
   _claimed.update(c => if key in c { c } else { c + (key,) })
   ```

   `key in c` on an array is a linear scan of everything claimed so far, run
   once per `citation(..)` call. Building up C claimed keys this way costs
   O(C²) in total.

2. Line 172, inside the `all:` closure's sweep loop — the only reader:

   ```typst
   for key in bib.keys().sorted() {
     if key not in _claimed.final() {
       note(key, [])
     }
   }
   ```

   This loop runs once per key in the WHOLE bibliography (`bib.keys()` — up to
   thousands of entries on a real reference-manager export), and for each one,
   `key not in _claimed.final()` is again a linear scan over every claimed key.
   The whole sweep is therefore O(bibliography size × claimed-key count) when
   one pass through a dictionary would answer the same question in O(1) per
   key. This is the exact shape already found and fixed in `@rookery/search`'s
   `#filter-panel` (a membership test that should have been a dictionary key
   test) — the same anti-pattern, in this package's own sweep.

## Decisions already made — do not re-derive

**Use a dictionary, key -> `none`.** This is the same shape `keywords.typ`'s
`keyword-tags` already builds with `.fold((:), (d, t) => { d.insert(t, none);
d })` — a set encoded as a dictionary whose values carry no information. Do
NOT introduce a new data structure or a helper module; this one match's the
package's own existing idiom for "a set of strings" (see
`/home/lox/code/_fcl/rookery/bibtex/0.1.0/src/keywords.typ` lines 24-27 for
the pattern already in this package).

**`dictionary.insert` is already idempotent** — inserting the same key twice
just overwrites its (ignored) value — so the `if key in c { c } else { .. }`
branch in the writer becomes unnecessary once `c` is a dictionary; a plain
insert replaces the whole conditional. Verified directly: in Typst, calling
`.insert("a", none)` twice on the same dictionary leaves `.keys()` as
`("a",)`, not `("a", "a")`.

**Line 172 needs NO code change.** `key not in _claimed.final()` already
reads correctly whether `_claimed` holds an array (element test) or a
dictionary (key test) — Typst's `in`/`not in` operator works both ways. Only
the value `_claimed` HOLDS needs to change, at its two definition/write
sites; the read site is already dictionary-shaped code that happens to also
work on an array today.

## Steps

1. `/home/lox/code/_fcl/rookery/bibtex/0.1.0/src/claim.typ` line 12 — change
   the initial state value from an empty array to an empty dictionary:

   ```typst
   #let _claimed = state("rookery-bibtex-claimed", (:))
   ```

2. `/home/lox/code/_fcl/rookery/bibtex/0.1.0/src/lib.typ` line 147 — replace:

   ```typst
   _claimed.update(c => if key in c { c } else { c + (key,) })
   ```

   with:

   ```typst
   _claimed.update(c => { c.insert(key, none); c })
   ```

3. Leave `/home/lox/code/_fcl/rookery/bibtex/0.1.0/src/lib.typ` line 172
   (`if key not in _claimed.final() {`) untouched — see "Decisions already
   made" above for why.

## Do NOT

- Do NOT touch `_swept` (the other state in `claim.typ`) or its `.get()` vs
  `.final()` distinction — that is a separate, already-correct mechanism.
- Do NOT change `claim.typ`'s header comment's explanation of WHY `_claimed`
  is a separate state from core's registry — that reasoning is unaffected by
  the array-to-dictionary change and still holds.
- Do NOT touch `all()`'s sweep-guard (`_swept.get() > 0` / `panic(..)`), the
  `note` closure, `kw-tags-for`, or anything in `format.typ`, `view.typ`,
  `parse.typ` or `keywords.typ`.
- Do NOT add a new public function or expose `_claimed` — it stays private.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery/bibtex/0.1.0 && just test` must be green,
   with output matching this baseline exactly (recorded before this bird was
   filed):

   ```
   units OK
   large OK
   [...four sweep/fields HTML compiles, each printing the html-export warning...]
   all(): 2 notes registered — ['<span class="sweep-id">idea:badiou2002</span><span class="sweep-body">A hand-written body.</span>', '<span class="sweep-id">idea:smith2020</span><span class="sweep-body"></span>']
   show-fields: doi and urldate absent, author present
   existing: aaa=citation+liminal | bbb=citation | ccc=citation | seed=liminal
   all:      aaa=brandnew+citation+liminal | bbb=brandnew+citation | ccc=citation+digital-humanities | seed=liminal
   no stray idea-tag- class tokens
   sweep OK
   ```

   The `existing:` and `all:` lines are exactly where claiming (via
   `citation`) and sweeping (via `all()`) interact — if the dictionary switch
   broke claiming, one of `aaa`/`bbb`/`ccc` would show up twice (once from its
   own `citation` call and again from `all()`) or go missing. Any difference
   in those two lines means this bird broke something; investigate before
   landing.

2. A dictionary really is used, not just "still passes by luck": temporarily
   add a debug line `#context [claimed: #_claimed.final().keys()]` anywhere
   after a `citation(..)` call in `test/sweep-existing.typ`, recompile with
   `typst compile --features html --format html --root . test/sweep-existing.typ /tmp/dbg.html`,
   confirm the printed value is a `.keys()`-shaped list (proving `_claimed`
   is a dictionary, since `.keys()` on an array would error), then remove the
   debug line before finishing.