---
id: rk-adds-resolve-display-for-the-display-5a057095
short-id: 5a
title: Adds _resolve-display for the display dictionary
priority: 3
labels:
- feat-display-dict
deps:
- blocked-by:rk-adds-id-slug-for-title-derived-note-ids-d9206148
closed: true
---
Touches: core/0.1.0/src/pure.typ, core/0.1.0/test/units.typ

Add `_resolve-display`, a pure helper that merges a `display:` dictionary with a set of
individual `display-*` flags into one canonical dictionary. It is the first piece of a
larger change replacing `@rookery/core`'s `show-*` arguments on `#idea` and
`#window` with a single
`display` dictionary plus matching `display-*` overrides; this bird adds the helper and
its unit tests ONLY, and wires it to nothing.

## The contract

Nine keys: `context`, `backlinks`, `background`, `date`, `frame`, `id`, `label`,
`tags`, `title`.

They are the union of two sets. `#idea` uses seven of them (`context`, `backlinks`,
`date`, `frame`, `id`, `tags`, `title`); `#window` uses six (`date`, `frame`, `id`,
`tags`, `label`, `background`). Both call this one helper and each ignores the keys it
has no use for — one vocabulary rather than two overlapping ones. Do NOT try to give
each caller its own key subset; a caller passing a key its function ignores is
harmless, and per-caller subsets would put the validation in two places.

`_resolve-display(dict, flags, where)` returns a dictionary with ALL NINE keys always
present. For each key, the value is the first of:

1. `flags.at(key)`, when it is not `auto` — an individual `display-<key>` argument the
   caller passed. These take precedence.
2. `dict.at(key)`, when the key is present in the `display:` dictionary.
3. `auto` — no opinion from this caller.

`auto` is deliberately preserved in the output rather than resolved to a boolean. It
means "this caller expressed no preference", and what happens next differs by key:
three of them (`context`, `backlinks`, `title`) fall back to a document-wide setting
much later, on the minted page; the rest are given their built-in default by their
caller. Resolving `auto` here would destroy that distinction, so this function
must not do it.

`where` is a caller label for error messages, in the style this file already uses —
`"#idea's"`, `"#rookery's"`. Find an existing example:

```
rg -n -F '_assert-tags(tags, "#idea' /home/lox/code/_fcl/rookery
```

## Validation

Both of these are caller errors that must panic with a clear message, because a silent
typo in a display dictionary produces a note that renders wrong with no clue why:

- **An unknown key in `dict`.** Panic naming the offending key AND listing all nine
  valid keys, so the author can see the typo. Message prefix `@rookery/core: `, as
  every other message in this package has.
- **A value in `dict` that is neither `true`, `false` nor `auto`.** Panic naming the
  key and the bad value with `repr(..)`.

Do NOT validate `flags` — those come from named parameters the package controls, not
from author input.

## Steps

1. Find where to put it. `_resolve-tags-color` is a comparable resolution helper in the
   same file:

   ```
   rg -n -F '#let _resolve-tags-color' /home/lox/code/_fcl/rookery
   ```

   One hit, `core/0.1.0/src/pure.typ`. Add `_resolve-display` near it. Also add a
   module-level constant for the key list so the panic message and the iteration share
   one source:

   ```typ
   #let _DISPLAY-KEYS = (
     "context", "backlinks", "background", "date", "frame",
     "id", "label", "tags", "title",
   )
   ```

2. Implement it. Iterate `_DISPLAY-KEYS` and build the result; validate `dict`'s keys
   against `_DISPLAY-KEYS` first so an unknown key is reported before anything else.

3. Comment it to this package's house style (`CLAUDE.md`, "Comment style"): present
   tense, no history. The non-obvious facts worth stating are the precedence order, and
   WHY `auto` survives into the output rather than being resolved here.

4. Export for the fixture. `core/0.1.0/test/units.typ` imports an explicit list from
   `/src/lib.typ`:

   ```
   rg -n -F '_no-content, _slug, _ideate-tag-value' /home/lox/code/_fcl/rookery
   ```

   One hit (line 23 as of filing). Add `_resolve-display` and `_DISPLAY-KEYS` to that
   list. No other export work is needed: `lib.typ` re-exports `base.typ` with `*`, and
   `base.typ` re-exports `pure.typ` with `*`.

5. Add a `// ---- _resolve-display — ...` section to the fixture asserting at least:

   ```typ
   // All nine keys are always present, `auto` where nobody had an opinion.
   #assert.eq(_resolve-display((:), (:), "#t").len(), 9)
   #assert.eq(_resolve-display((:), (:), "#t").frame, auto)
   // The dictionary supplies a value.
   #assert.eq(_resolve-display((frame: false), (:), "#t").frame, false)
   // An individual flag WINS over the dictionary.
   #assert.eq(_resolve-display((frame: false), (frame: true), "#t").frame, true)
   // A flag left `auto` does NOT override the dictionary.
   #assert.eq(_resolve-display((frame: false), (frame: auto), "#t").frame, false)
   // `auto` is a legal dictionary value and stays `auto`.
   #assert.eq(_resolve-display((title: auto), (:), "#t").title, auto)
   // Keys nobody mentioned are still present and still `auto`.
   #assert.eq(_resolve-display((frame: false), (:), "#t").backlinks, auto)
   ```

   Match the fixture's convention of a short comment above each assertion naming the
   rule it pins. The two panic cases cannot be asserted — a panic aborts the compile,
   which this `assert.eq` harness cannot survive. The fixture's own header explains
   this; follow the precedent set by the `_slug` section, which documents its panic case
   in a comment instead of asserting it.

## Non-goals

- Do NOT touch `core/0.1.0/src/idea.typ`, `window.typ`, `template.typ`, `state.typ`,
  `transclusion.typ`, `permalink.typ`, `ideate.typ` or `.marrow.typ`.
  Nothing calls `_resolve-display` after this bird, and that is correct.
- Do NOT rename any existing `show-*` argument anywhere. Separate birds do that.
- Do NOT resolve `auto` to a boolean inside this function.
- Do NOT add document-wide state, or read any state — this is a pure function.
- Do NOT touch the readme.

## VERIFY

From `core/0.1.0`:

1. `just test` exits 0 and prints `units OK`.
2. `rg -n -F '#let _resolve-display' src/pure.typ` returns exactly one hit.
3. `rg -n -F '#let _DISPLAY-KEYS' src/pure.typ` returns exactly one hit.
4. `rg -c 'show-' src/pure.typ` reports the same count as before your change — this
   bird renames nothing.
5. `rg -c '_resolve-display' src/` reports hits in `pure.typ` only.