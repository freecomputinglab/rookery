---
id: rk-make-unnamed-idea-ids-survive-re-render-94c027fb
short-id: 94c
title: Make unnamed idea ids survive re-render
priority: 4
labels:
- fix-idea-auto-id-drift
deps: []
closed: true
---
Touches: core/0.1.0/src/idea.typ, core/0.1.0/src/state.typ, core/0.1.0/src/transclusion.typ, core/0.1.0/src/ideate.typ, core/0.1.0/.marrow.typ

## The defect

An unnamed note's id is minted inside a `context` block, so it is a function of
where the note is standing in the document rather than of the note itself. The
whole `#idea` call is then stored, unrealized, inside its parent's `_registry`
record — so every re-render of that stored body (a `#window`, a minted page
under `.marrow.typ`, a nested rebuild) re-realizes the context and mints a
DIFFERENT id.

Measured against `core/0.1.0` as it stands, with this project:

```typ
#import "@rookery/core:0.1.0": rookery, idea, window
#show: rookery

= Min

#idea(<outer>, title: [Outer])[
  Outer body.

  #idea(title: [Derived Child])[Child body.]

  #idea[Untitled child body.]
]

#idea(<other>, title: [Other])[
  #window(<outer>)
]
```

compiled with `rheo compile . --html`, the titled child renders under four
different ids:

| rendered on | id it wears |
| --- | --- |
| `index.html`, its own card | `idea:derived-child` |
| `index.html`, inside the window on `<outer>` | `idea:derived-child-1` |
| `ideas/outer.html` (minted) | `idea:derived-child-2` |
| `ideas/other.html` (minted) | `idea:derived-child-3` |

and the untitled child renders as `idea:2`, then `idea:4`, `idea:6`, `idea:8` —
`_seq.step()` is emitted as content, so it re-steps once per re-render.

The registry itself stays clean: `_flatten`'s `figure.where(kind: IK)` show rule
rebuilds a nested card from its metadata payload and never re-runs the INNER
`context` that registers the note. Only the rendered permalink and anchor drift.
The drifted ids therefore point at pages that are never minted — dead links in
the output.

Worse, the phantom ids accumulate in `state("rheo-ideas-taken")` and in
`counter("rheo-ideas-seq")` differently on each Typst layout run, which shifts
`_registry.final()`, which decides how many pages `.marrow.typ` mints, which
moves every element's location. On `rookery.ohrg.org` (the sibling repo at
`/home/lox/code/_fcl/rookery.ohrg.org`) that loop never settles and Typst emits
five warnings per target, headed `document did not converge within five
attempts`, with `value of state("rheo-ideas-taken") did not converge` pointing
at `core/0.1.0/src/idea.typ`'s probe. That site also ships two dead permalinks,
`ideas/what-is-the-genealogy-of-idea-1.html` and `-2.html`, for exactly this
reason. Pinning the one offending note there clears all five warnings, which is
what isolates the cause to unnamed notes.

## The fix: an unnamed note's id comes from its CONTAINER, not its position

The invariant to establish: **an unnamed note's id must be a pure function of
its authored call site**, so that any number of re-renders reproduce it. A
container is re-established every time a body is rebuilt, so a coordinate
expressed against the container reproduces; a document-wide counter or probe
does not.

Introduce a container SCOPE — a stack, because notes nest — and mint against
the top of it.

1. In `core/0.1.0/src/state.typ`, add one state beside the existing id
   machinery:

   ```typ
   #let _scope = state("rookery-idea-scope", ())
   ```

   Each entry is a dictionary `(key: <str>, n: <int>)`. `key` is the container's
   BARE id (the id with `_pfx()` already stripped) for a note, or the current
   vertebra's handle with every `:` replaced by `-` at top level, or `""` where
   neither exists (plain `typst compile` with no rheo). `n` is how many unnamed
   notes that container has minted so far.

   Retire `#let _taken-ids = state("rheo-ideas-taken", (:))` and
   `#let _seq = counter("rheo-ideas-seq")` from the same file, along with their
   banner comments. Find them with:

   ```
   rg -n 'state\("rheo-ideas-taken"|counter\("rheo-ideas-seq"\)' /home/lox/code/_fcl/rookery/core
   ```

   One hit each, both in `core/0.1.0/src/state.typ` (lines 364 and 372 as of
   filing).

2. In `core/0.1.0/src/idea.typ`, replace the minting block. Its anchor is the
   probe line:

   ```
   rg -n 'let taken = _taken-ids.get\(\)' /home/lox/code/_fcl/rookery/core
   ```

   Two hits: `core/0.1.0/src/idea.typ` (line 248 as of filing, inside the
   `context {` that opens at line 223 and produces the `figure(kind: IK, ...)`)
   and `core/0.1.0/src/ideate.typ` (line 526, in `_free-id`). Step 2 is the
   `idea.typ` one; step 4 is the `ideate.typ` one.

   The new resolution order inside that context block:

   - **named** — unchanged: `_pfx() + base`. A pin is a promise about the id.
   - **unnamed, with a title** — `_pfx() + _id-slug(_plain(title))`, with NO
     probe of any kind. This is pure, so it reproduces under every re-render.
   - **unnamed, no title** (or a title `_id-slug` cannot turn into a name) —
     `_pfx() + <container key> + "-" + str(k)`, where `<container key>` is
     `_scope.get().last().key` and `k` is that entry's `n` after this note
     increments it. Where the scope stack is empty, use the vertebra key alone;
     where that too is empty, `_pfx() + str(k)`.

   Then, still inside the same context block, push this note's own scope entry
   so its body's nested notes mint against it, and pop it after the body:

   ```typ
   _scope.update(s => s + ((key: id.trim(_pfx(), at: start), n: 0),))
   // ... the figure, whose body contains `body` ...
   _scope.update(s => if s.len() > 0 { s.slice(0, -1) } else { s })
   ```

   The push must be emitted as content BEFORE the figure and the pop AFTER it,
   so that both land in document order around the body. Keep the existing
   `_taken-ids.update(...)` line deleted, not repurposed.

3. Also in `core/0.1.0/src/idea.typ`, delete both `_seq.step()` emissions:

   ```
   rg -n 'if not named \{ _seq.step\(\) \}' /home/lox/code/_fcl/rookery/core
   ```

   Two hits, both in `core/0.1.0/src/idea.typ` (lines 147 and 211 as of filing).
   Line 147 is inside the exclusion gate's early return and exists so a note's
   id does not depend on which build variant it was compiled in — REPLACE that
   one with the equivalent scope increment (bump the top entry's `n` without
   emitting a figure), do not simply drop it. Line 211 sits just above the
   `context {` of step 2 and is subsumed by the new minting, so delete it.

   Delete the `_pfx() + str(_seq.get().first())` branch too — one hit, same
   file, line 257 as of filing.

4. In `core/0.1.0/src/ideate.typ`, `_free-id` (line 525 as of filing, the second
   hit from step 2's `rg`) probes `_taken-ids` the same way and has the same
   defect. Replace its body with the pure form: return `bare` unchanged. Keep
   the function and its call sites (`context mint(_free-id(...), ...)`, three
   hits around lines 639, 641 and 669) so the shape of `ideate` is untouched;
   only the probe goes. If `_free-id` then has no reason to exist, inlining it
   is acceptable, but do not otherwise restructure `ideate`.

5. In `core/0.1.0/src/transclusion.typ`, make a rebuild re-establish the same
   container. Anchors:

   ```
   rg -n '#let _flatten\(body, depth: 1\)|#let _body-at\(rec, depth: auto\)' /home/lox/code/_fcl/rookery/core
   ```

   One hit each, lines 304 and 489 as of filing. Both return content that is
   placed wherever the stored body is re-rendered. Wrap each return value in a
   push of the RECORD'S OWN bare id with `n: 0`, and a matching pop:

   ```typ
   _scope.update(s => s + ((key: <the record's bare id>, n: 0),))
   <the flattened body>
   _scope.update(s => if s.len() > 0 { s.slice(0, -1) } else { s })
   ```

   `_flatten(body, depth: 1)` does not currently receive the record's id. Add an
   `id: none` parameter to it, pass the note's id from `#idea`'s registry write
   (`rec.body = _flatten(body)` in `core/0.1.0/src/idea.typ`, line 384 as of
   filing) and from `_body-at`, and skip the push when it is `none`. This is
   what makes the k-th unnamed note inside a rebuilt body get the same k it got
   at the authored site.

6. `core/0.1.0/.marrow.typ` renders a minted page's subject via
   `let flat = _body-at(rec, depth: minted-depth)` (line 204 as of filing; one
   hit for `rg -n '_body-at\(rec' /home/lox/code/_fcl/rookery/core`). It needs
   no change of its own once `_body-at` pushes the scope, but re-read it after
   step 5 to confirm it is not stripping the pushed markers out of `flat`
   before placing it.

## Consequences to accept, and to write into the code's comments

- **Untitled notes change id shape.** `idea:1`, `idea:2` become
  `idea:<container>-1`. A bare number cannot survive, because a per-container
  ordinal reset makes `idea:1` ambiguous across containers. This is a breaking
  change to permalinks for any existing rookery; at `0.1.0` that is accepted,
  and providing a migration is a NON-GOAL of this bird.
- **Two unnamed notes with the same title now panic instead of silently
  disambiguating.** The `-<n>` suffix the probe used to mint is exactly what
  cannot be made position-independent, so it goes. `_registry`'s existing
  duplicate-id panic already fires for this case and already names both
  origins; extend its message to say that pinning one of the two with
  `#idea(<some-name>, ...)` is the fix. Do not add a new panic path.
- Follow `CLAUDE.md`'s comment style when rewriting the banners in `idea.typ`
  and `state.typ`: describe the scheme as it now stands and why, never what it
  replaced, and name no bird or bookmark.

## NON-GOALS

- Do not touch the NAMED path. `_pfx() + base` is already stable.
- Do not add a migration, an alias table, or a redirect for old numeric ids.
- Do not change `#window`, `#ideas-outline`, `#ideas` or `.marrow.typ`'s page
  layout beyond what step 5 and step 6 force.
- Do not try to fix `rookery.ohrg.org`. That is a separate repo with its own
  tracker and its own issue for this.
- Do not chase the other four convergence warnings separately — they are
  downstream of this one and go away with it (measured: pinning the offending
  note on `rookery.ohrg.org` clears all five).

## VERIFY

1. Build the package: `cd /home/lox/code/_fcl/rookery/core/0.1.0 && just build`.
   It must succeed.

2. Write the reproduction project above to a scratch directory as
   `content/index.typ`, with a `rheo.toml` of:

   ```toml
   version = "0.6.4"
   content_dir = "content"
   ```

   then `rheo compile . --html` in that directory. It must succeed.

3. The titled child must wear ONE id everywhere. This must print the same id on
   every line, and no `derived-child-1`, `-2` or `-3` anywhere:

   ```
   grep -rho 'idea:derived-child[a-z0-9-]*' build/html --include=*.html | sort -u
   ```

   Expected output: exactly `idea:derived-child`.

4. Every minted-page href must resolve to a file that exists:

   ```
   grep -rhoE 'href="\.\./ideas/[a-z0-9-]+\.html"' build/html/ideas/*.html \
     | sed 's/.*ideas\///; s/"//' | sort -u > /tmp/want.txt
   ls build/html/ideas > /tmp/have.txt
   comm -23 /tmp/want.txt /tmp/have.txt
   ```

   Expected output: nothing.

5. The untitled child must wear one id everywhere too, and it must be
   container-qualified rather than a bare number:

   ```
   grep -rho 'idea:outer-[0-9]*' build/html --include=*.html | sort -u
   ```

   Expected: exactly one id, `idea:outer-1`.

6. Compile `/home/lox/code/_fcl/rookery.ohrg.org` — the sibling site that
   currently fails to converge — with `rheo compile .` run from that directory,
   and confirm no convergence warning of any kind:

   ```
   rheo compile . 2>&1 | grep -c 'did not converge\|did not stabilize'
   ```

   Expected output: `0`. This is the end-to-end check; report the actual number
   if it is not zero rather than adjusting the grep.

   HONEST UNCERTAINTY: the scheme reads `_scope` through Typst introspection, so
   run 1 of each layout sees an empty stack and mints wrong ids, with run 2
   onward correct. That is the same two-run settle named notes already rely on
   (`_prefix.final()`), and it is expected to converge — but it has NOT been
   measured against the new code, and step 6 is the measurement. If it still
   warns, stop and report the observed run-by-run values from the warning rather
   than adding further state.