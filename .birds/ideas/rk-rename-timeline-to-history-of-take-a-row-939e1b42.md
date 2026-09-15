---
id: rk-rename-timeline-to-history-of-take-a-row-939e1b42
short-id: 939e
title: Rename timeline() to history-of, take a row
priority: 2
labels:
- chore-timeline-api
deps:
- blocked-by:rk-drop-the-dated-idea-alias-fix-the-84e526ff
closed: false
---
`timeline-of(tags)` (`/home/lox/code/_fcl/rookery/timeline/0.1.0/src/read.typ:26`)
is the stored log. `timeline(entry, tags)` (same file, line 116) is a DIFFERENT
sequence — rookery's own `created` prepended to that log — with a different arity
and a different source. The names differ by one suffix and say nothing about any
of that, and `timeline` is simultaneously the package's name and the name of
`entries()`'s third parameter. Three meanings for one word, one of them a
function a reader will reach for by accident.

The same module also spells `-of` three ways: `deadline-of(tags)` takes a tag
dictionary, `created-of(entry)` takes an `ideas()` row (line 87), and
`updated-of(entry, tags)` takes both (line 97). Rows from `ideas(values: true)`
already carry `tags-dict`, so the two row readers can be single-argument, and the
module gets one rule: a dict reader takes a dict, a row reader takes a row.

Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/src/read.typ
Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/src/view.typ
Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/readme.md
Touches: /home/lox/code/_fcl/rookery/timeline/0.1.0/test/units.typ
Touches: /home/lox/code/_fcl/rookery/todos/0.1.0/src/views.typ

## The new surface

```typ
#let created-of(row)    // unchanged behaviour, unchanged name
#let updated-of(row)    // was updated-of(entry, tags) — reads row.tags-dict itself
#let history-of(row)    // was timeline(entry, tags) — created + the log, in order
```

`history-of`, because that is what it returns: the note's record, which starts
when the note was written. `timeline-of(tags)` keeps its name and its meaning.

## Steps

1. In `read.typ`, rename `timeline` (116) to `history-of` and give it one
   parameter, the row. Inside, read the log via `timeline-of(row.tags-dict)`.
2. Change `updated-of` (97) to take the row alone, reading `row.tags-dict` the
   same way.
3. Both new one-argument readers need `tags-dict`, which only
   `ideas(values: true)` supplies. Say so in one line above them — the same note
   `upcoming.typ:238` already carries for itself — and use
   `row.at("tags-dict", default: (:))` so a row fetched without `values: true`
   reads as an empty log rather than failing on a missing field, matching
   `created-of`'s own `.at` with a default and the reasoning at lines 84-86.
4. Update `view.typ`: `#timeline-view(entry, tags, ..)` calls `timeline(entry,
   tags)` at line 50. It takes both arguments from its caller, so pass
   `history-of` a row-shaped dictionary — `(..entry, tags-dict: tags)` — or, if
   every in-repo caller already has a real row, leave `#timeline-view`'s own
   signature alone and reach for `timeline-of(tags)` plus `created-of(entry)`
   directly. Do NOT change `#timeline-view`'s signature in this bird.
5. Update `todos/0.1.0/src/views.typ:295`, `let touched = r => updated-of(r,
   r.tags-dict)`, to `updated-of(r)`, and the comment at line 268 that spells the
   old two-argument call.
6. Update the `timeline(..)`, `updated-of(..)` and `created-of(..)` assertions in
   `timeline/0.1.0/test/units.typ` (lines 187-204) and the `updated-of`
   assertions in `todos/0.1.0/test/units.typ` (278-285) to the new shapes. The
   tests build row dictionaries by hand, so each becomes one dictionary carrying
   `created` and `tags-dict` rather than two arguments.
7. Update `timeline/0.1.0/readme.md`: the migration table's "everything else keeps
   its name" list (53-56) loses `timeline` and `updated-of`, and gains a row
   apiece; every example calling either is updated. Also fix the sentence in
   `readme.md`'s rename rationale that cites `timeline(entry, tags)` as the reader
   the package was named after — it is `history-of(row)` now, and the name still
   came from the log.
8. `core/0.1.0/src/transclusion.typ:102` mentions `updated-of(entry, tags)` in a
   comment. Update the spelling; change no code in core.

## Non-goals

- **`timeline-of(tags)` does not move or change.** It is the log, it is what four
  packages import, and it stays a pure function of a tag dictionary.
- **Do not change `#timeline-view`'s signature.** It takes `(entry, tags, ..)` and
  keeps taking them; a view API change is not this bird.
- **Do not make the dict readers take rows.** `scheduled-of`, `deadline-of`,
  `stage-date`, `has-stage`, `entered-of`, everything in `when.typ` and everything
  in `ladder.typ` keep taking a tag dictionary — that is what makes them callable
  from a `tag-index` `from:` extractor, which never has a row.
- **Do not add a row-or-dict polymorphic normalizer.** One rule, visible in the
  name, is the point.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery/timeline/0.1.0 && just test` — `units OK`,
   `views OK`. The view fixture renders eight rails whose first row is `created`,
   so a broken `history-of` fails the rail-1 class assertion.
2. `cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just check` passes —
   `#todos-stale` is built on `updated-of` and its own fixture covers it.
3. `cd /home/lox/code/_fcl/rookery/cfps/0.1.0 && just test` passes.
4. `rg -n 'updated-of\([^)]*,' /home/lox/code/_fcl/rookery` returns nothing, and
   `rg -n '\btimeline\(' /home/lox/code/_fcl/rookery` returns nothing.
5. `cd /home/lox/code/_fcl/rookery && just check-versions` passes.