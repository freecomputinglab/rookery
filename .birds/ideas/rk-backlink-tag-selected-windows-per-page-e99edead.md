---
id: rk-backlink-tag-selected-windows-per-page-e99edead
short-id: e9
title: Backlink tag-selected windows per page
priority: 3
labels:
- fix-tag-window-backlinks
deps: []
closed: true
---
A `#window` that selects its notes by TAG gives those notes no backlink, while a
`#window` that NAMES them does. This bird fixes the PAGE-level half of that gap:
after it, a vertebra carrying `#window(tagged: "phd")` appears in the Backlinks
of every note that window actually showed. The NOTE-level half — a tag window
written inside another note's body — is a separate bird (see "Non-goals").

Touches: core/0.1.0/src/window.typ, core/0.1.0/src/outline.typ, core/0.1.0/demo/rheo/check.sh

## The defect, as it stands

`#window` announces the notes it shows in a `metadata` element so the backlink
walks can see them, and that payload carries ONLY the ids the author named:

```
rg -n --fixed-strings 'rookery-window: ids, backlink: backlink' /home/lox/code/_fcl/rookery/core
```

One hit, `core/0.1.0/src/window.typ:262` as of filing:

```typst
  [#metadata((rookery-window: ids, backlink: backlink)) <rookery-window-mark>]
```

`ids` above is built only from the POSITIONAL argument (window.typ:208-211). The
`tagged:`/`match:`/`filter:` selection happens later, inside the `context` block
that opens at window.typ:264, and nothing from it ever reaches the marker.

Observable right now, before any change:

```bash
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check
grep -c -i backlink build/html/ideas/tag-t-both.html   # prints 0
grep -c -i backlink build/html/ideas/root-note.html    # prints a positive number
```

`tag-t-both` is shown by `#window(tagged: ("todo", "phd"), match: "all")` on
`demo/rheo/content/tags.typ` and gets nothing; `root-note` is shown by a named
window and gets its Backlinks section. That asymmetry is the whole bug.

## Why this is fixable, and where

The reconnaissance is done — do not redo it. There are two backlink walks and
they are NOT equally stuck:

- `_outbound` (`src/links.typ:39`) runs at note REGISTRATION on the raw body,
  before any registry exists. It genuinely cannot resolve a tag. Not this bird.
- `_page-links()` (`src/outline.typ:119`) is different: it uses
  `query(<rookery-window-mark>)`, so it runs at RENDER time, inside a `context`,
  and its only caller is `core/0.1.0/.marrow.typ:148`, which sits inside a
  `#context` block that has already bound `let registry = _registry.final()` at
  `.marrow.typ:95`. The registry is FINAL by the time `_page-links` runs.

So the predicate can be evaluated inside `_page-links`. Only the SELECTOR has to
travel there, and a selector is plain data.

## The `filter:` trap — read this before writing any code

`#window`'s `filter:` is a FUNCTION (asserted at window.typ:143). Nothing in this
package stores a function inside `metadata` — every `metadata((..))` call site
carries strings, booleans, dictionaries or content, and that is checked. A
function cannot ride on the marker.

That matters for CORRECTNESS, not just completeness. `tagged:` and `filter:` are
ANDed (window.typ:298 passes both to `_tag-pred`), so a window written as
`#window(tagged: "phd", filter: t => "draft" not in t)` shows FEWER notes than
`tagged: "phd"` alone. Resolving the tag half on its own would announce backlinks
from notes the window never rendered — a wrong backlink is worse than a missing
one.

So: the marker carries a boolean saying a filter was in play, and every reader
SKIPS tag resolution entirely when it is set. A `filter:` window keeps exactly
today's behaviour — no backlink — and that stays true until someone finds a way
to persist a predicate, which is not this bird.

## Steps

1. Add the selector to the marker payload in `src/window.typ`.

   Find the site:

   ```
   rg -n --fixed-strings 'rookery-window: ids, backlink: backlink' /home/lox/code/_fcl/rookery/core
   ```

   One hit, `src/window.typ:262` as of filing, the last statement before the
   `context {` block that opens at line 264. Add two keys, making the payload:

   ```typst
   [#metadata((
     rookery-window: ids,
     backlink: backlink,
     tagged: tagged,
     match: match,
     filtered: filter != none,
   )) <rookery-window-mark>]
   ```

   `tagged` and `match` are passed through UNCHANGED, exactly as `#window`
   received them — `_tag-pred` accepts the same shapes `#window` accepts, and
   normalising here would only put a second interpretation of the argument in the
   codebase. Note that `tagged` is re-bound later at window.typ:297 inside the
   context block; line 262 runs first and still sees the parameter, which is what
   you want.

   Write a comment above the marker explaining that the tag SELECTOR rides along
   because it is data, while `filter:` can only be recorded as a boolean because
   it is a function — and that `filtered: true` therefore means "this selection
   is narrower than its tags, do not resolve it".

2. Correct the stale comment that sits directly above that marker.

   ```
   rg -n --fixed-strings 'A tag selection is not known until' /home/lox/code/_fcl/rookery/core
   ```

   One hit, `src/window.typ:223` as of filing. The paragraph there says tag
   matches get no backlink and ends with an instruction not to "fix" it by
   announcing the tags. That instruction was about having `_outbound` read the
   registry while it is still being built, which this bird does NOT do — the
   resolution happens in `_page-links`, at render time. Rewrite the paragraph to
   say what is now true: the selector is announced, `_page-links` resolves it
   against the final registry, `_outbound` still cannot (note-level backlinks are
   a separate matter), and a `filter:` window still announces nothing resolvable.
   Keep the warning against making `_outbound` read the registry — it is still
   correct, and it is the reason the fix lives where it does.

3. Resolve the selector in `_page-links`, `src/outline.typ`.

   ```
   rg -n --fixed-strings 'for n in v.at("rookery-window", default: ())' /home/lox/code/_fcl/rookery/core
   ```

   One hit, `src/outline.typ:146` as of filing, inside the
   `for el in query(<rookery-window-mark>)` loop that starts at outline.typ:137,
   in the function `_page-links` (the landmark to name if the anchor has moved).

   That loop already computes `seen` (the ids this page links to) and already
   skips a marker whose `backlink` is `false` at outline.typ:142. After the
   existing `for n in ...` loop that adds the named ids, add the tag resolution:

   - skip when `v.at("filtered", default: false)` is `true`;
   - skip when `v.at("tagged", default: none)` is `none`;
   - otherwise build `let pred = _tag-pred(v.tagged, v.at("match", default: "any"))`
     and, for every `(id, rec)` in `_registry.final()` whose
     `rec.at("tags", default: (:))` satisfies `pred`, push `id` into `seen` if it
     is not already there.

   `_tag-pred` is already in scope: it lives in `src/pure.typ:150` and
   `src/base.typ:45` star-imports `pure.typ`, which `outline.typ:7` star-imports
   in turn. Do not add an import.

   `_registry` is likewise in scope via `src/state.typ` (outline.typ:8), and
   `_page-links` is only ever called from inside a context, so `.final()` is
   legal here. Ids in the registry are already full ids — do NOT apply `_pfx()`
   to them the way the named branch does at outline.typ:147, which is there
   because a marker carries BARE names.

   Comment the branch: say that this is the one reader that can resolve a tag
   selection at all, because it runs after the registry is final, and that the
   `filtered` skip is about not claiming backlinks a filter would have excluded.

4. Add an assertion to `core/0.1.0/demo/rheo/check.sh`.

   ```
   rg -n --fixed-strings 'no minted page at ideas' /home/lox/code/_fcl/rookery/core
   ```

   One hit, in `demo/rheo/check.sh`, inside the numbered assertion list. Add a
   new numbered assertion at the END of that list, in the same style as the ones
   already there (a `grep -q ... || note "..."` pair):

   - `build/html/ideas/tag-t-both.html` must contain `Backlinks` — the fixture
     `#window(tagged: ("todo", "phd"), match: "all")` at
     `demo/rheo/content/tags.typ:30` sits on the vertebra `tags`, so that note
     must now record a page backlink.

   Write the `note` message so a failure says what broke: that a tag-selected
   window stopped registering a page backlink.

## Non-goals

- Do NOT touch `_outbound` (`src/links.typ:39`) or the note-level graph. A tag
  window written INSIDE a note's body is bird `rk-<note-level id>` and needs a
  new registry field; doing it here will collide with that bird on landing.
- Do NOT try to persist `filter:`, in metadata or on a state. A window with
  `filter:` keeps getting no backlink, on purpose.
- Do NOT change what a window RENDERS. This bird changes the backlink graph
  only; no window shows a different set of notes afterwards.
- Do NOT touch `_cite-scan` (`src/bib.typ:61`), which reads the same marker for
  citation partitioning and cares only that it exists.
- Do NOT add a self-edge guard here. A page is not a note, so a page linking to
  a note it contains is already handled by the existing page-backlink rules in
  `.marrow.typ:142-154`; leave them alone.

## VERIFY

1. Unit fixture still compiles:

   ```bash
   cd /home/lox/code/_fcl/rookery/core/0.1.0 && just test
   ```

   Expect `units OK`.

2. The demo builds and every assertion passes, including the new one:

   ```bash
   cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check
   ```

   Expect no `FAIL:` lines. (`just check` cleans, builds with `rheo compile .`,
   then runs `check.sh`. `rheo` must be on PATH; if it is not, report that rather
   than working around it.)

3. The specific behaviour, checked by hand after that build:

   ```bash
   cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo
   grep -c -i backlink build/html/ideas/tag-t-both.html
   ```

   Must now print a positive number. It printed `0` before this bird.

4. Named windows did not regress:

   ```bash
   grep -c -i backlink build/html/ideas/root-note.html
   ```

   Still positive.