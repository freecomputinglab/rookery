---
id: rk-renames-rookery-s-document-wide-display-5a8874b1
short-id: 5a8
title: Renames rookery's document-wide display options
priority: 3
labels:
- feat-display-dict
deps:
- blocked-by:rk-gives-idea-a-display-dictionary-3c9c7f11
closed: false
---
Touches: core/0.1.0/src/template.typ, core/0.1.0/src/state.typ, core/0.1.0/.marrow.typ

Rename `rookery(..)`'s three document-wide display options to `display-*` and let it
take a `display:` dictionary too, matching `#idea` and `#window`.

BREAKING rename — `show-*` is removed, not aliased.

## What changes

`rookery(show-context: true, show-backlinks: true, show-title: true)` becomes
`rookery(display: (:), display-context: auto, display-backlinks: auto,
display-title: auto)`.

These three are the DOCUMENT-WIDE defaults for minted note pages. A per-note
`#idea(display-context: false)` overrides them; a per-note value of `auto` means
"defer to these". That two-tier arrangement is unchanged — only the names and the
addition of the dictionary.

**`rookery(..)` accepts only these three keys in its `display:` dictionary.** The other
six (`date`, `frame`, `id`, `tags`, `label`, `background`) have no document-wide tier
today, and this bird does NOT invent one. Passing one of them to `rookery(..)` must
panic with a message naming the three it does accept. This is the conservative reading:
adding four more document-wide states is a separate decision nobody has made.

## Prerequisite

`_resolve-display(dict, flags, where)` in `core/0.1.0/src/pure.typ`
(`rg -n -F '#let _resolve-display' /home/lox/code/_fcl/rookery`). It validates against
all nine keys, so `rookery(..)` must do its own narrower check IN ADDITION — reject any
key outside `("context", "backlinks", "title")` before calling it.

## Steps

1. Rename the three states:

   ```
   rg -n -F '#let _show-context = state(' /home/lox/code/_fcl/rookery
   ```

   One hit, `core/0.1.0/src/state.typ` (line 199 as of filing); `_show-backlinks` and
   `_show-title` follow at 205 and 216. Rename the BINDINGS to `_display-context`,
   `_display-backlinks`, `_display-title`.

   Leave each `state("rheo-idea-show-context", ..)` STRING KEY exactly as it is. A state
   key is a runtime identifier shared across a compile, not a name a reader sees;
   changing it is churn with a real chance of a silent mismatch. Add a short comment
   saying the binding and the key deliberately differ.

   Update the surrounding comments, which refer to each other by the old names.

2. Rename the parameters and assertions in `template.typ`:

   ```
   rg -n 'show-(context|backlinks|title)' /home/lox/code/_fcl/rookery/core/0.1.0/src/template.typ
   ```

   Hits around lines 34-36 (an inner template's parameters), 130-139 (type assertions)
   and 495-497 (the state updates) as of filing, plus the public `rookery(..)`
   signature. Rename all of them to `display-*`, defaulting to `auto` rather than
   `true`.

3. Add `display: (:)` to `rookery(..)`, validate its keys against exactly
   `("context", "backlinks", "title")` with a panic naming the offender and the three
   valid keys, then resolve:

   ```typ
   let display = _resolve-display(
     display,
     ("context": display-context, backlinks: display-backlinks, title: display-title),
     "#rookery's",
   )
   let display = display + (
     "context": if display.context == auto { true } else { display.context },
     backlinks: if display.backlinks == auto { true } else { display.backlinks },
     title: if display.title == auto { true } else { display.title },
   )
   ```

   Note `"context"` is QUOTED in both dictionary literals: `context` is a Typst
   keyword and a bare `context:` key is a parse error (`expected expression`).
   Measured — it breaks the compile outright.

   `true` is the existing default for all three — confirm against the signature you
   replaced and report if any differs. The document-wide tier is the bottom of the
   stack, so here `auto` IS resolved to a boolean, unlike in `#idea`.

4. Update the three `.update(..)` calls to store the resolved booleans:

   ```
   rg -n -F '_show-context.update(show-context)' /home/lox/code/_fcl/rookery
   ```

   One hit, `template.typ` (line 495 as of filing), with the other two just below.

5. Update `.marrow.typ`'s three state reads:

   ```
   rg -n --hidden -F 'let show-context = _show-context.final()' /home/lox/code/_fcl/rookery
   ```

   One hit, `core/0.1.0/.marrow.typ` (line 98 as of filing), with `_show-backlinks` and
   `_show-title` on the two lines below. Rename the state bindings being read and the
   locals they bind to. Note `--hidden`: `.marrow.typ` is a dotfile and ripgrep skips
   it by default.

   That file also imports the three state bindings by name in its `#import
   "@rookery/core:0.1.0": ..` list — update those too, or the import fails.

   Do NOT touch that file's per-note `rec.at("display", ..)` reads; those belong to
   `#idea`'s bird and are already correct.

## Non-goals

- Do NOT add document-wide state for `date`, `frame`, `id`, `tags`, `label` or
  `background`.
- Do NOT change the `state("rheo-idea-show-*")` string keys.
- Do NOT touch `idea.typ`, `window.typ`, `transclusion.typ`, `permalink.typ` or
  `ideate.typ`.
- Do NOT touch the readme, the demos, or any other package.
- Do NOT keep `show-*` as aliases.

## VERIFY

From `core/0.1.0`:

1. `just test` exits 0 and prints `units OK`.
2. `(cd demo/pure && just build)` exits 0 and ends with `demo/pure OK`. That
   recipe compiles `root.typ`, `root-prefix.typ` and `excluded.typ` and runs its own
   `check` — it is the pure-Typst demo's real entrypoint.
3. `rg -n 'show-(context|backlinks|title)' src/template.typ src/state.typ` returns hits
   ONLY inside `state("rheo-idea-show-...")` string literals and the comment explaining
   them.
4. `rg -n --hidden -F '_show-context' .marrow.typ` returns no hits;
   `rg -n --hidden -F '_display-context' .marrow.typ` returns at least two (the import
   and the read).
5. `rg -n -F 'display-context: auto' src/template.typ` returns at least one hit.