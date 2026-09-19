---
id: rk-documents-the-display-dictionary-in-core-03a933b6
short-id: 03a
title: Documents the display dictionary in core
priority: 2
labels:
- feat-display-dict
deps:
- blocked-by:rk-gives-window-a-display-dictionary-25e5104a
- blocked-by:rk-renames-rookery-s-document-wide-display-5a8874b1
- blocked-by:rk-renames-ideate-s-display-pass-throughs-3629782f
- blocked-by:rk-documents-title-derived-ids-and-the-url-579ccbdc
closed: false
---
Touches: core/0.1.0/readme.md, core/0.1.0/demo/pure/theme.typ, core/0.1.0/demo/rheo/content/index.typ, core/0.1.0/demo/rheo/content/tags.typ, core/0.1.0/demo/rheo/content/sub/deeper/page.typ, core/0.1.0/demo/rheo/check.sh

Update `@rookery/core`'s readme and demos for the `display` dictionary rename.

## What changed in the code

`#idea`, `#window`, `#ideate` and `rookery(..)` no longer take `show-*` arguments. Each
now takes a `display:` dictionary plus individual `display-*` overrides:

- `#idea(display: (..), display-context:, display-backlinks:, display-date:,
  display-frame:, display-id:, display-tags:, display-title:)`
- `#window(display: (..), display-background:, display-date:, display-frame:,
  display-id:, display-label:, display-tags:)` — `foldable:` and `reserve-title:` are
  NOT renamed and keep their names
- `#ideate(display-frame: false, display-id: false)` — the inverted defaults survive
- `rookery(display: (..), display-context:, display-backlinks:, display-title:)`, whose
  dictionary accepts ONLY those three keys

Dictionary keys drop the prefix: `display: (frame: false, backlinks: true)`.

**Precedence, which the readme must state plainly:** an individual `display-*` argument
beats the `display:` dictionary, which beats the document-wide `rookery(..)` setting,
which beats core's built-in default. Every `display-*` argument on `#idea` and
`#window` defaults to `auto`, meaning "no opinion" — which is what lets a lower tier
show through. `#ideate` is the exception: its two keep their `false` defaults, because
it is a caller with a real opinion rather than the bottom of the stack.

## Steps

1. Find every mention in the readme:

   ```
   rg -n 'show-(date|tags|frame|id|context|backlinks|title|label|background)' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   Around 50 hits as of filing. Work through all of them. Most are inline signature
   listings and worked examples; rename each and check the surrounding prose still
   reads correctly, since some sentences name the argument in running text.

2. The readme has a section on turning the minted-page footer off:

   ```
   rg -n -F 'Turning the footer off' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   One hit (line 2324 as of filing). Rewrite its example, which currently reads
   `#show: rookery.with(show-context: false, show-backlinks: false)`.

3. Add a short subsection documenting the `display:` dictionary itself and the
   precedence order above, placed near the first place display arguments are
   introduced. One worked example showing a dictionary and an override winning over it
   is worth more than a table of all nine keys:

   ```typ
   #idea(display: (frame: false, tags: true), display-frame: true)[..]
   // frame: true wins — the explicit argument beats the dictionary
   ```

4. Add a migration note stating the rename is breaking and listing the old-to-new
   mapping compactly. Do NOT write a changelog section — this project's convention is
   that documentation describes the present; one clearly-marked migration paragraph is
   the exception, not a precedent.

5. Update the demos:

   ```
   rg -rn 'show-(date|tags|frame|id|context|backlinks|title|label|background)' /home/lox/code/_fcl/rookery/core/0.1.0/demo/
   ```

   Hits in `demo/pure/theme.typ`, `demo/rheo/content/index.typ`,
   `demo/rheo/content/tags.typ`, `demo/rheo/content/sub/deeper/page.typ` and
   `demo/rheo/check.sh` as of filing. `check.sh` greps rendered HTML — check whether
   its patterns match CSS classes and data attributes (which this rename does NOT
   change) or Typst argument names (which it does), and change only the latter. Report
   which you found.

## Non-goals

- Do NOT change any behaviour. This bird edits prose, demo content and a check script.
- Do NOT touch `core/0.1.0/src/` or `.marrow.typ`.
- Do NOT rename any CSS class, `data-rookery-*` attribute, or `state("rheo-idea-show-*")`
  string key. None of them changed.
- Do NOT touch another package's readme.
- Do NOT document `_resolve-display` or `_DISPLAY-KEYS`; both are internal.

## VERIFY

From `core/0.1.0`:

1. `just test` exits 0 and prints `units OK`.
2. `rg -n 'show-(date|tags|frame|id|context|backlinks|title|label|background)' readme.md demo/`
   returns no hits, or only hits inside a `state("rheo-idea-show-...")` string or the
   migration note's old-name column. List anything you deliberately left.
3. `rg -n -F 'display: (frame: false' readme.md` returns at least one hit — the worked
   example is present.
4. `rg -i -F 'foldable' readme.md` still shows `foldable:` documented under its own
   name.
5. `bash demo/rheo/check.sh` exits 0, if that script is runnable standalone. If it
   needs `rheo` on PATH and that is unavailable in this flight, say so and skip it
   rather than reporting a false failure.