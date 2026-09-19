---
id: rk-gives-idea-a-display-dictionary-3c9c7f11
short-id: 3c
title: 'Gives #idea a display dictionary'
priority: 3
labels:
- feat-display-dict
deps:
- blocked-by:rk-adds-resolve-display-for-the-display-5a057095
- blocked-by:rk-names-a-derived-vs-pinned-id-clash-in-351726a8
closed: false
---
Touches: core/0.1.0/src/idea.typ, core/0.1.0/src/transclusion.typ, core/0.1.0/.marrow.typ

Replace `#idea`'s seven `show-*` arguments with a single `display:` dictionary plus
seven matching `display-*` override arguments, store the result as one `display`
dictionary on the registry record and the IK metadata payload, and update the two
readers of those fields so core still compiles.

This is a BREAKING rename. The `show-*` names are removed outright, not kept as
aliases. `#window` and `rookery(..)` have their own `show-*` sets and are handled by
separate birds; this bird does not touch them.

## Prerequisite

`_resolve-display(dict, flags, where)` exists in `core/0.1.0/src/pure.typ`, reachable
from `idea.typ` via `#import "base.typ": *`. Find it:

```
rg -n -F '#let _resolve-display' /home/lox/code/_fcl/rookery
```

It returns a dictionary with nine keys — `context`, `backlinks`, `background`, `date`,
`frame`, `id`, `label`, `tags`, `title` — resolving each as: the individual flag when
it is not `auto`, else the dictionary's value when present, else `auto`. It panics on
an unknown key or a non-boolean value. If it is missing, stop and report.

`#idea` uses seven of the nine. `label` and `background` are `#window`'s; they will be
present in the resolved dictionary and `#idea` simply ignores them. Do not strip them.

## The rename

| was | becomes |
|---|---|
| `show-date: false` | `display-date: auto` |
| `show-tags: false` | `display-tags: auto` |
| `show-frame: true` | `display-frame: auto` |
| `show-id: true` | `display-id: auto` |
| `show-context: auto` | `display-context: auto` |
| `show-backlinks: auto` | `display-backlinks: auto` |
| `show-title: auto` | `display-title: auto` |

Plus a new `display: (:)` parameter taking those keys WITHOUT the prefix —
`display: (frame: false, backlinks: true)`.

**Every `display-*` parameter defaults to `auto`, including the four that used to
default to a boolean.** This is required, not cosmetic: "an explicit flag beats the
dictionary" is only expressible if an unpassed flag is distinguishable from one passed
as `false`. A `display-frame: true` default would make `display: (frame: false)`
impossible to honour. The built-in defaults move to step 3, so effective behaviour is
unchanged.

## Steps

1. Find the signature:

   ```
   rg -n -F 'show-context: auto, show-backlinks: auto' /home/lox/code/_fcl/rookery
   ```

   One hit, `core/0.1.0/src/idea.typ` (line 45 as of filing), the `#let idea(` line.
   Replace the seven `show-*` parameters with `display: (:)` plus the seven `display-*`
   parameters, all defaulting to `auto`. Leave every other parameter unchanged.

2. Resolve early in the body, alongside the existing `_assert-tags` calls, so a bad
   dictionary is reported before any work happens:

   ```typ
   let display = _resolve-display(
     display,
     (
       context: display-context, backlinks: display-backlinks, date: display-date,
       frame: display-frame, id: display-id, tags: display-tags, title: display-title,
     ),
     "#idea's",
   )
   ```

3. Apply built-in defaults for the four RENDER-TIME keys immediately after, so they are
   never `auto` below this point:

   ```typ
   let display = display + (
     date: if display.date == auto { false } else { display.date },
     tags: if display.tags == auto { false } else { display.tags },
     frame: if display.frame == auto { true } else { display.frame },
     id: if display.id == auto { true } else { display.id },
   )
   ```

   `context`, `backlinks` and `title` MUST stay `auto` when unset — `auto` there means
   "use the document-wide setting", resolved later on the minted page. Do not default
   them here. Say so in a comment; it is the one asymmetry a reader will otherwise take
   for a bug.

4. Replace every remaining use in this file with `display.frame`, `display.id`,
   `display.tags`, `display.date`:

   ```
   rg -n 'show-(date|tags|frame|id|context|backlinks|title)' /home/lox/code/_fcl/rookery/core/0.1.0/src/idea.typ
   ```

   Work through every hit, comments included. Rewrite comments to describe the present
   shape (`CLAUDE.md`, "Comment style").

   One call in this file passes `show-id:` to `_permalink-tab`, a private helper whose
   own parameter is NOT being renamed by this bird. Keep that call's keyword as
   `show-id:` and pass `display.id` as its value.

5. Change the IK metadata payload:

   ```
   rg -n -F '#metadata((body: body, title: title' /home/lox/code/_fcl/rookery
   ```

   One hit, same file (line 202 as of filing). It carries `show-frame`, `show-id` and
   `show-tags` as three separate keys. Replace all three with one `display: display`
   key carrying the whole resolved dictionary. Keep every other key — `body`, `title`,
   `label`, `named`, `base`, `id`, `level`, `tags` — unchanged.

6. Change the registry record:

   ```
   rg -n -F '_registry.update(r => {' /home/lox/code/_fcl/rookery
   ```

   One hit, same file (line 325 as of filing). The record just above carries
   `show-context`, `show-backlinks` and `show-title`. Replace all three with one
   `display: display` key; keep `title`, `label`, `raw`, `body`, `created`, `origin`,
   `links`, `tags` unchanged.

   The record takes part in the duplicate-detection identity comparison (`existing !=
   rec`). Typst compares dictionaries by value, order-insensitively, so one `display`
   key behaves exactly as the three booleans did. No change needed there.

7. Update the IK show rule, which reads the three payload keys this bird replaced:

   ```
   rg -n -F 'show-frame: v.at("show-frame", default: true)' /home/lox/code/_fcl/rookery
   ```

   That anchor is in the WK (window) rule and is NOT yours — leave it alone. The IK
   rule's reads are the ones inside `show figure.where(kind: IK):`; find them with

   ```
   rg -n 'v\.at\("show-(tags|id|frame)"' /home/lox/code/_fcl/rookery/core/0.1.0/src/transclusion.typ
   ```

   and change only the hits inside the IK rule (three, near lines 339, 342 and 373 as
   of filing) to read from the payload's `display` dictionary:

   ```typ
   let d = v.at("display", default: (:))
   ... d.at("tags", default: false) ... d.at("id", default: true) ... d.at("frame", default: true)
   ```

   Keep `.at(.., default: ..)` throughout. The existing comment explains why: a payload
   minted by an older version carries no such key, and the defaults differ per key.

8. Update `.marrow.typ`'s three per-note reads off the registry record:

   ```
   rg -n --hidden -F 'rec.at("show-title", default: auto)' /home/lox/code/_fcl/rookery
   rg -n --hidden -F 'let v = rec.at("show-context", default: auto)' /home/lox/code/_fcl/rookery
   rg -n --hidden -F 'let v = rec.at("show-backlinks", default: auto)' /home/lox/code/_fcl/rookery
   ```

   One hit each, `core/0.1.0/.marrow.typ` (lines 210, 389, 393 as of filing). Each must
   now read the record's `display` dictionary instead, e.g.

   ```typ
   let v = rec.at("display", default: (:)).at("context", default: auto)
   ```

   Note `--hidden`: `.marrow.typ` is a dotfile and ripgrep skips it by default.

   Do NOT touch the three `_show-context.final()` / `_show-backlinks.final()` /
   `_show-title.final()` reads near the top of that file. Those read document-wide
   STATE, which a separate bird renames.

## Non-goals

- Do NOT keep `show-*` as deprecated aliases anywhere.
- Do NOT touch `core/0.1.0/src/window.typ`, `template.typ`, `state.typ`,
  `permalink.typ` or `ideate.typ`. `#window`'s own `show-*` set, `rookery(..)`'s, and
  `#ideate`'s forwarding are three separate birds.
- Do NOT rename `_window-content`'s or `_permalink-tab`'s parameters — private helpers,
  handled with `#window`.
- Do NOT touch any other package, the readme, or the demos.
- Do NOT add document-wide state for the four render-time keys.
- Do NOT change id derivation, the taken-ids probe, or the exclusion gate.

## VERIFY

From `core/0.1.0`:

1. `just test` exits 0 and prints `units OK`.
2. `(cd demo/pure && just build)` exits 0 and ends with `demo/pure OK`. That
   recipe compiles `root.typ`, `root-prefix.typ` and `excluded.typ` and runs its own
   `check` — it is the pure-Typst demo's real entrypoint.
   the command you used. Core must be GREEN at the end of this bird.
3. `rg -n 'show-(date|tags|frame|id|context|backlinks|title)' src/idea.typ` returns no
   hits.
4. `rg -n -F 'display: display' src/idea.typ` returns exactly two hits — the payload
   and the record.
5. `rg -n --hidden -F 'rec.at("show-' .marrow.typ` returns no hits, while
   `rg -n --hidden -F '_show-context.final()' .marrow.typ` still returns one.