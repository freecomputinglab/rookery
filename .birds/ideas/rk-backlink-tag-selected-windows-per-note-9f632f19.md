---
id: rk-backlink-tag-selected-windows-per-note-9f632f19
short-id: 9f
title: Backlink tag-selected windows per note
priority: 3
labels:
- fix-tag-window-backlinks
deps:
- blocked-by:rk-backlink-tag-selected-windows-per-page-e99edead
closed: false
---
A `#window` that selects by TAG rather than by name gives the notes it shows no
backlink. The companion bird fixed the PAGE-level half of that (a vertebra
carrying the window now appears in those notes' Backlinks). This bird fixes the
NOTE-level half: a tag window written INSIDE another note's body should make that
note link to every note the window showed, exactly as a named window already
does.

Touches: core/0.1.0/src/links.typ, core/0.1.0/src/idea.typ, core/0.1.0/.marrow.typ, core/0.1.0/demo/rheo/content/tags.typ, core/0.1.0/demo/rheo/check.sh

## What the companion bird already did — you are building on it

It added three keys to the `<rookery-window-mark>` metadata payload emitted by
`#window`, so the marker now reads:

```typst
[#metadata((
  rookery-window: ids,
  backlink: backlink,
  tagged: tagged,
  match: match,
  filtered: filter != none,
)) <rookery-window-mark>]
```

Confirm that before starting:

```
rg -n --fixed-strings 'filtered:' /home/lox/code/_fcl/rookery/core/0.1.0/src/window.typ
```

One hit expected, in `src/window.typ` around line 262, in the statement just
above the `context {` block. If it is NOT there, this bird's dependency has not
landed — stop and report that rather than adding the keys yourself.

`tagged` and `match` are the values `#window` was given, unchanged. `filtered` is
`true` when the call also passed a `filter:` predicate.

## Why the note-level half needs more than the page-level half did

The page-level fix was cheap because `_page-links()` (`src/outline.typ:119`)
already runs at render time via `query()`, inside a context, after the registry
is final. The note-level graph does not work that way:

- `_outbound` (`src/links.typ:39`) walks a note's RAW body at REGISTRATION and
  returns a flat array of target ids, stored on that note's registry record as
  its `links` field (`src/idea.typ:422`, `links: links,`).
- The reverse index is built much later, in `core/0.1.0/.marrow.typ:132-140`,
  inside the file's one `#context` block, which binds
  `let registry = _registry.final()` at `.marrow.typ:95`.

So the registry IS final where the index is built — it is only unavailable where
the walk happens. The fix is therefore to record an UNRESOLVED SELECTOR at
registration and expand it when the index is built. No walk ever reads a registry
that is still being written, which is the rule the comment at `src/window.typ`
warns about.

## The `filter:` rule — same as the companion bird

`filter:` is a function (asserted `src/window.typ:143`) and cannot be stored in
metadata; nothing in this package stores a function there. `tagged:` and
`filter:` are ANDed, so resolving the tag half alone would claim backlinks from
notes the window never showed. A marker with `filtered: true` is therefore SKIPPED
entirely and keeps today's behaviour — no backlink. Do not try to persist the
predicate.

## Steps

1. Add a second walk beside `_outbound` in `src/links.typ`.

   ```
   rg -n --fixed-strings 'for (_, v) in node.fields() { out += _outbound(v) }' /home/lox/code/_fcl/rookery/core
   ```

   One hit, `src/links.typ:88` as of filing — the last line of `_outbound`'s
   generic recursion (the landmark is the function `_outbound` itself). Add a new
   function `_outbound-tag-selectors(node)` directly AFTER `_outbound` ends.

   It returns an array of dictionaries, each `(tagged: .., match: ..)`, and it
   mirrors `_outbound`'s traversal rules exactly, because the two walks must agree
   about which windows belong to which note:

   - an array recurses elementwise and flattens, as `links.typ:40` does;
   - a non-content value returns `()`, as `links.typ:41` does;
   - a `figure` whose `kind` is `IK` returns `()` — a nested note owns its own
     links, as `links.typ:47` does;
   - a `metadata` whose dictionary value has a `rookery-window` key returns `()`
     when `backlink` is false (`.at("backlink", default: true)`, as at
     `links.typ:59`), `()` when `.at("filtered", default: false)` is true, `()`
     when `.at("tagged", default: none)` is `none`, and otherwise the single-entry
     array `((tagged: v.tagged, match: v.at("match", default: "any")),)`;
   - a `metadata` with a `rookery-fn` key recurses into its payload, as
     `links.typ:81-83` does — a `#window` inside a footnote counts, and that
     traversal blind spot has already been fixed once for `_outbound` (see its
     comment) so do not reintroduce it here;
   - everything else recurses over `node.fields()` as `links.typ:88` does.

   Do NOT collect `link`/`ref` targets here — those are `_outbound`'s and are
   already recorded.

   Comment the function: say it is the deferred half of `_outbound`, that it
   records a SELECTOR rather than ids because the registry does not exist at
   registration, and that `.marrow.typ` is what expands it once the registry is
   final.

2. Record the selectors on the note's registry record, in `src/idea.typ`.

   ```
   rg -n --fixed-strings 'let links = _outbound(body)' /home/lox/code/_fcl/rookery/core
   ```

   One hit, `src/idea.typ:387` as of filing, inside `#idea`'s deferred context
   block. Immediately after the existing `links` binding and its dedupe (the
   dedupe is at idea.typ:388-389), add:

   ```typst
   let tag-links = _outbound-tag-selectors(body)
   ```

   Then store it on the record:

   ```
   rg -n --fixed-strings 'links: links,' /home/lox/code/_fcl/rookery/core
   ```

   One hit, `src/idea.typ:422` as of filing, in the dictionary that becomes the
   registry record. Add `tag-links: tag-links,` beside it.

   Every later reader uses `.at("tag-links", default: ())`, so an older record
   without the field is harmless — no migration, no version bump.

3. Expand the selectors when the reverse index is built, in
   `core/0.1.0/.marrow.typ`.

   NOTE: `.marrow.typ` is a DOTFILE. `rg` skips hidden files unless told not to,
   so every search below needs `--hidden`:

   ```
   rg -n --hidden --fixed-strings 'for target in rec.at("links", default: ())' /home/lox/code/_fcl/rookery/core
   ```

   One hit, `.marrow.typ:135` as of filing, inside the `NOTE backlinks` loop that
   starts at `.marrow.typ:134` (the landmark is the comment line
   `// NOTE backlinks: the inverse of every note's recorded outbound links.`).

   Inside the same `for (src, rec) in registry.pairs()` loop, after the existing
   `links` loop, add the selector expansion:

   - for each selector in `rec.at("tag-links", default: ())`, build
     `let pred = _tag-pred(sel.tagged, sel.at("match", default: "any"))`;
   - skip a `none` predicate defensively;
   - for every `(target, trec)` in `registry` whose
     `trec.at("tags", default: (:))` satisfies `pred`, insert the edge
     `src -> target` into `backlinks` the same way the existing loop does.

   TWO GUARDS, both required:

   - **Skip `target == src`.** A tag window is a query, so a note can easily
     match its OWN selection — a note tagged `phd` whose body windows everything
     tagged `phd`. The named path cannot realistically hit this and so has no
     guard; this path hits it immediately, and a note listed in its own Backlinks
     is a visible bug.
   - **Do not double-insert.** The existing loop guards with
     `if src not in seen`; do the same, since a window may both name a note and
     match it by tag.

   `_tag-pred` is NOT currently imported here. Add it to the import list:

   ```
   rg -n --hidden --fixed-strings '_visible-tags' /home/lox/code/_fcl/rookery/core/0.1.0/.marrow.typ
   ```

   The first hit (`.marrow.typ:92` as of filing) is the single long
   `#import "@rookery/core:0.1.0": ...` line; add `_tag-pred` to it. The function
   is defined at `src/pure.typ:150` and reaches the package's public surface
   through `src/base.typ:45`'s star-import, so no other export work is needed.

4. Add the fixture this bird needs, in `core/0.1.0/demo/rheo/content/tags.typ`.

   ```
   rg -n --fixed-strings '#window(tagged: ("todo", "phd"), match: "all")' /home/lox/code/_fcl/rookery/core
   ```

   One hit, `demo/rheo/content/tags.typ:30` as of filing. That window sits at the
   PAGE's top level, not inside a note, so it exercises the page-level path only —
   which is why this bird needs a fixture of its own.

   Add, below the existing tag notes on that page, a note whose BODY carries a tag
   window, in the same style as the notes already there:

   ```typst
   #note("tag-windower")[
     A note whose body windows by tag rather than by name.

     #window(tagged: ("todo", "phd"), match: "all")
   ]
   ```

   `#note` is already bound on that page (it comes from `content/lib.typ` via the
   page's own import at `tags.typ:1`) and `window` is already imported at
   `tags.typ:2` — check both are still there rather than adding imports blind.

   The note must NOT itself carry the `todo` and `phd` tags, or it will match its
   own selection and the self-edge guard becomes the thing under test rather than
   the backlink. `#note` prepends the `note` tag only, so the snippet above is
   already safe — keep it that way.

5. Assert it in `core/0.1.0/demo/rheo/check.sh`.

   The companion bird added an assertion that
   `build/html/ideas/tag-t-both.html` contains `Backlinks`. Add one more,
   numbered in the same style: `build/html/ideas/tag-t-both.html` must now also
   mention `tag-windower`, the note whose body windowed it.

   Grep for the slug rather than for prose, and write the `note` message to say
   that a tag window inside a note stopped producing a note-level backlink.

## Non-goals

- Do NOT change `_outbound` itself. It keeps returning ids and only ids; the new
  walk is a separate function. Changing its return type would touch every caller.
- Do NOT try to persist `filter:`. A `filter:` window still gets no backlink.
- Do NOT touch `_page-links` (`src/outline.typ:119`) or the marker payload — both
  are the companion bird's and are already correct.
- Do NOT change what any window RENDERS.
- Do NOT add a migration or bump the package version for the new record field;
  every read uses a default.

## VERIFY

1. Unit fixture still compiles:

   ```bash
   cd /home/lox/code/_fcl/rookery/core/0.1.0 && just test
   ```

   Expect `units OK`.

2. Demo builds and every assertion passes:

   ```bash
   cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check
   ```

   Expect no `FAIL:` lines. (`rheo` must be on PATH; if it is not, report that
   rather than working around it.)

3. The note-level edge exists, checked by hand after that build:

   ```bash
   cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo
   grep -c 'tag-windower' build/html/ideas/tag-t-both.html
   ```

   Must print a positive number.

4. No note lists itself:

   ```bash
   grep -c 'tag-windower' build/html/ideas/tag-windower.html
   ```

   The self-edge guard means this note's own Backlinks must not name itself. A
   minted page mentions its own slug in other places (its permalink, its href),
   so read the Backlinks section rather than trusting the count alone if this is
   not zero.