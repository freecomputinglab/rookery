---
id: rk-ideate-title-name-as-function-or-content-de1305b7
short-id: de1
title: Ideate title/name as function or content
priority: 3
labels:
- feat-ideate-title-name-fn
deps:
- blocked-by:rk-ideate-tags-via-metadata-beacon-8c4920a3
closed: true
---
# Drop the `heading` sentinel: `title:`/`name:` take content or a function

## Why

`#ideate` (`core/0.1.0/src/ideate.typ`) lets `title:`/`name:` name a note
after its own separating heading by passing the literal Typst `heading`
element-constructor function as a magic sentinel value (`title: heading`,
`name: heading`), detected by identity comparison
(`type(title) == function and title == heading`, `ideate.typ:305-306`). This
overloads a real Typst builtin as a marker, is asymmetric (`title:` also
accepts a FIXED content value applied to every note, with no unifying shape
between that and "read the heading"), and is redundant:
`readme.md:795-798` already documents that `name: (content, labels) =>
slug(content)` is IDENTICAL to `name: heading` — the sentinel is a shorthand
for a one-line function, not a distinct capability.

Resolved decision (do not re-derive, do not ask which of these to keep):
drop the `heading` sentinel from BOTH parameters. The two parameters end up
with these accepted shapes:

- `title:` — `none` (default, no title on any note — unchanged) | fixed
  content (applied to every note — unchanged) | a function
  `(content, labels) => content`, called once per section with that
  section's own separating heading body and label array (the same two
  arguments `name:`'s function already receives), returning the content to
  use as THAT note's title.
- `name:` — `auto` (default, package counter — unchanged) | a function
  `(content, labels) => string` (unchanged — already implemented and already
  tested via `demo/rheo/content/ideated-named.typ`). A FIXED name (a plain
  string or content passed as `name:`) stays refused exactly as today
  (`ideate.typ:308-316`'s panic, unchanged) — a fixed name would still mint
  every note in the body under one id, which is the reason it is refused
  today and remains a reason regardless of this change. Do NOT add a "fixed
  content for `name:`" mode — this was considered and explicitly rejected:
  only the sentinel goes away, not the collision-safety panic.

Both function forms are heading-mode only, exactly as `name:`'s function
form already is today — with `separator: par` or `separator: none` there is
no per-section heading to pass as `content`, so passing a function for
either parameter there must panic (`ideate.typ:317-325`'s existing panic
already covers this for `name-fn`; extend the same guard to cover the new
`title:` function form).

## Exact changes, `core/0.1.0/src/ideate.typ`

1. **Lines 299-306** (comment + `title-from-heading`/`name-from-heading`
   bindings): delete `title-from-heading` and `name-from-heading` entirely.
   Replace with:
   ```typst
   let title-fn = type(title) == function
   let name-fn = type(name) == function
   ```
   (`name-fn` already exists today at line 307 as
   `type(name) == function and not name-from-heading` — simplify it to drop
   the now-nonexistent `name-from-heading` exclusion.)

2. **Lines 308-316** (the `name:` validation panic): the condition
   `name != auto and not name-from-heading and not name-fn` becomes
   `name != auto and not name-fn`. Update the panic message (currently names
   `heading` as an accepted sentinel at line 311) to drop that clause — it
   should read "must be `auto` (the package counter — the default) or a
   function of `(content, labels)` returning the note's id as a string."

3. **Lines 317-325** (the heading-mode-only guard): the condition
   `(title-from-heading or name-from-heading or name-fn) and not
   heading-mode` becomes `(title-fn or name-fn) and not heading-mode`.
   Update the panic message (line 319, currently "`title: heading`, `name:
   heading`, and `name:` functions all read the heading...") to read
   "`title:` and `name:` functions both read the heading that STARTS each
   note, so they need `separator: heading.where(level: 2)`..." — drop the
   two sentinel-specific clauses, keep the rest of the message's reasoning
   unchanged.

4. **Lines 334-352** (the `mint` closure construction and its surrounding
   comment): the comment at 334-339 explaining why `title:` is forwarded
   "only when it is NOT the `heading` sentinel" needs rewriting for "only
   when it is not a function" — same shape of reasoning (a function
   computes a PER-SECTION title, so it must not be forwarded as a fixed
   value to every group). Line 350's
   `..(if title-from-heading { (:) } else { (title: title) })` becomes
   `..(if title-fn { (:) } else { (title: title) })`.

5. **Lines 444-491** (the per-group emit branch):
   - Line 444's condition
     `not (title-from-heading or name-from-heading or name-fn) or
     lead-heading == none` becomes `not (title-fn or name-fn) or
     lead-heading == none`.
   - Line 451's `title-arg` becomes:
     ```typst
     let title-arg = if title-fn { (title: (title)(lead-heading.body, labels)) } else { (:) }
     ```
     reusing the `labels` array already computed for `name-fn` just below it
     (lines 457-459 build `labels` today) — HOIST that `labels` computation
     up so it is available to BOTH `title-arg` and the existing `name-fn`
     branch, computed exactly once. Today it is built only inside the
     `if name-fn` branch at line 458; move it up to before `title-arg` is
     built, since `title-arg` now needs it too.
   - Line 452's condition `not (name-from-heading or name-fn)` becomes
     `not name-fn`.
   - No change to `name-fn`'s own body (lines 457-481) beyond removing its
     now-redundant local `labels` binding (moved up per the point above) —
     the string-return assert (lines 460-465) is UNCHANGED; do NOT add an
     equivalent assert for `title-fn`'s return value — a fixed `title:` has
     never been type-checked either, and this stays consistent with that.

## Do not touch

- `idea.typ`, `pure.typ`'s `slug`/`_slug` — untouched;
  `name: (content, labels) => slug(content)` remains the documented
  replacement for the old `name: heading` one-liner.
- The `name:` collision panic (`ideate.typ:482-489`, "two sections in this
  body slug to the same name") — unchanged, applies identically regardless
  of how the id-computing function was spelled.

## Update the readme, `core/0.1.0/readme.md`

- **Lines 657-703** ("### Titling and naming notes from their own heading"):
  rewrite the code example at line 665 (`title: heading, name: heading`) to
  `title: (content, labels) => content, name: (content, labels) =>
  slug(content)`. Rewrite the table at lines 681-689 — it currently has a
  `heading` column for both rows; that column disappears, and the
  `function` column's `title:` cell (currently "— not available; use
  `heading` or `none`") becomes "a function `(content, labels) => content`
  — each note's own computed title."
- **Lines 738-803** ("### Naming sections with a custom function"): this
  section already documents `name:`'s function form correctly — only lines
  795-798's "is identical to `name: heading`" comparison needs rewriting,
  since `name: heading` no longer exists as a spelling; reframe as "is the
  one-line function that replaces what a `heading` sentinel would have
  meant."
- **Line 807** (the signature line `ideate(body, separator: par, title:
  none, name: auto, tags: (), show-frame: false, show-id: false, ..args)`):
  the signature TEXT is unchanged (parameter names and defaults are
  identical) — no edit needed here, only the prose describing what values
  `title:`/`name:` accept.

## Update the demo fixtures

- `core/0.1.0/demo/rheo/content/ideated.typ:14`:
  `#show: ideate.with(separator: heading.where(level: 2), title: heading,
  name: heading)` becomes `#show: ideate.with(separator:
  heading.where(level: 2), title: (content, labels) => content, name:
  (content, labels) => slug(content))`. Add `slug` to the import at line 2
  (`#import "@rookery/core:0.1.0": ideate` becomes
  `#import "@rookery/core:0.1.0": ideate, slug`).
- `core/0.1.0/demo/rheo/content/ideated-named.typ:14`: `title: heading`
  becomes `title: (content, labels) => content` (this file already imports
  `slug` at line 2 for its own `name:` lambda — no import change needed
  here).
- `core/0.1.0/demo/rheo/check.sh` check 23 (lines 560-581, "HEADING AS TITLE
  AND NAME") and check 25 (lines 608-621, "FUNCTION FORM FOR `name:`"): the
  HTML assertions do not need to change (the rendered `<title>` per page is
  identical either way) — only their comments describing the mechanism as
  "heading as title and name" / referencing `title: heading` should be
  reworded to describe the function form. Re-read the comments after editing
  `content/ideated.typ` and `content/ideated-named.typ` to confirm they
  still match those files.

## Non-goals

- Do NOT allow a fixed (non-function) value for `name:` — considered and
  rejected, see "Why" above.
- Do NOT add a type assertion on `title:`'s function return value.
- Do NOT change `separator:`'s own accepted forms (`par`/`parbreak`/
  `heading.where(..)`/`heading(..)`/`none`) — out of scope.
- Do NOT touch the `<tag:x>`-to-metadata-beacon change — that is a separate
  bird, `rk-ideate-tags-via-metadata-beacon-8c4920a3`, and this bird is
  `blocked-by` it because both touch `content/ideated.typ` and `check.sh`'s
  adjacent numbered checks; work it after that one lands.

## Touches

`core/0.1.0/src/ideate.typ`, `core/0.1.0/readme.md`,
`core/0.1.0/demo/rheo/content/ideated.typ`,
`core/0.1.0/demo/rheo/content/ideated-named.typ`,
`core/0.1.0/demo/rheo/check.sh`

## VERIFY

1. `cd core/0.1.0 && just test` — must print `units OK` (no unit test
   directly exercises `ideate()`'s title/name branches per that file's own
   header comment, so this only confirms nothing else broke).
2. `cd core/0.1.0/demo/rheo && just check` — must print `demo/rheo OK`, with
   checks 23 and 25 passing against the rewritten fixtures. This recipe
   needs a `rheo` binary on `PATH` (see that directory's own `Justfile`
   header comment for how to point it at a locally built one) — if none is
   available, say so explicitly rather than skipping this step silently.
3. `bd status <this-bird-id>` reports `retired` after landing — if it still
   reports `ready`, the flight landed but the bird did not close; re-slip
   and alight the empty flight.