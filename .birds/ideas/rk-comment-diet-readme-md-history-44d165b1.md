---
id: rk-comment-diet-readme-md-history-44d165b1
short-id: 44d
title: 'Comment diet: readme.md history-narration (0.1.0 prep)'
priority: 3
labels:
- chore-core-review
deps: []
closed: true
---
`readme.md` carries seven stray asides that explain a current feature by
narrating what an earlier, unpublished revision did instead — outside any of
the readme's own, deliberate "Migrating from..." sections. This is
DIFFERENT from those sections, which must NOT be touched by this bird: they
are real, addressed migration guidance for this machine's own four sites that
were on the pre-0.1.0 alpha lineage (readme.md:82-84), and gutting them is a
product decision for the package's maintainer, not a comment-cleanliness fix.

Touches: /home/lox/code/_fcl/rookery/core/0.1.0/readme.md

## Explicitly OUT OF SCOPE — do not touch

- The whole `## 0.1.0` chapter, lines 73-239, and everything under its five
  `### Migrating from ...` subsections.
- The inline `**Migrating from the old scale.**` callout at line 334 (under
  `### Nested windows, and \`window-unfurl\``).
- The inline `**This changes existing URLs, again.**` callout at lines
  1168-1174 (under `## Unnamed notes: where their names come from`).
- The "upgrading reader" aside at lines 1427-1429 (under `## Outlining
  notes`): "The default used to be page-only; an upgrading reader who wants
  that back writes `#ideas-outline(scope: "page")`."

All four of the above are deliberately addressed to a reader upgrading from a
specific prior state, and say so in their own words ("Migrating from",
"upgrading reader", "changes existing URLs"). Line numbers for the seven
IN-SCOPE sites below are as of filing; match the quoted text if they have
shifted.

## The specific work

1. **Line 1049** (under `### Its inverted defaults`):

   ```
   the common case is a document-level `#show: ideate` on a page that is one
   idea, and a caller who wants the old paragraph-per-note behaviour asks for
   it explicitly with `separator: par`.
   ```

   Reword "the old paragraph-per-note behaviour" to describe it directly: "a
   caller wanting one note per paragraph asks for it explicitly with
   `separator: par`."

2. **Lines 1227-1229** (under the `limit:` truncation discussion):

   ```
   A limit can no longer land mid-paragraph. One paragraph is one block however
   many inline runs it is made of, so a plain text run and the `raw` span beside
   it are never separated, and the space between them survives — the MEASURED
   defect that once rendered "three layers, because" as "three layers,because".
   ```

   Reword to state the current guarantee without "no longer"/"once rendered":
   "A limit cannot land mid-paragraph: one paragraph is one block however many
   inline runs it is made of, so a plain text run and the `raw` span beside it
   are never separated, and the space between them survives." The concrete
   example ("three layers, because") may stay as an illustration of the
   guarantee if reworded as a present-tense example (e.g. "so \"three layers,
   `because`\" keeps its space rather than losing it to a truncation cut"),
   or be dropped — your judgement, since it is illustrative rather than a
   measurement that justifies a constant.

3. **Line 1418** (under `## Outlining notes`):

   ```
   DERIVED label (see "Derived labels"), so an auto-numbered note is no longer
   skipped — only one with an empty body is, since there is then nothing to name
   it by at all.
   ```

   Reword to state the current inclusion rule directly: "...so an
   auto-numbered note is listed like any other — only a note with an empty
   body is skipped, since there is then nothing to name it by at all."

4. **Line 2098** (under `### Per-tag colour: \`tags-color\``):

   ```
   - **A project stylesheet can override a themed pill.** The generated rules sit in a layer, and unlayered CSS beats layered CSS whatever the source order, so your own `.idea-tag-draft { --idea-tag-bg: ... }` wins. The inline style this replaced could not be overridden at all.
   ```

   Drop the trailing "The inline style this replaced could not be overridden
   at all." sentence outright — the bullet's point (a project stylesheet CAN
   override a themed pill, and why) stands without it.

5. **Line 2408** (a table row under `## Derived labels`):

   ```
   | an `#ideas-outline` entry | a titleless note used to be skipped outright |
   ```

   Reword the second column to state the current rule instead of the removed
   one: "an untitled note is listed under its derived label, not skipped".

6. **Lines 2470-2473** (under `## Dates`):

   ```
   **Where it renders is the hat** — the `.idea-tab` rule across the top of a card
   or a window, with the name on the stub at the left end and the date pushed to the
   far right. It is the frame's metadata, not a subtitle: it used to sit inside the
   `<h2>` on a card and as a third item in a window's summary row, which made one
   piece of information wear two classes in two places. Now it is `.idea-date`
   inside `.idea-tab`, wherever it appears.
   ```

   Drop the "it used to sit... Now it is" framing and state the current
   placement and its rationale directly: "It is the frame's metadata, not a
   subtitle — `.idea-date` sits inside `.idea-tab` wherever it appears, one
   class in one place, rather than duplicated as a heading child on a card and
   a summary-row item on a window."

7. **Lines 2545-2548** (under `## Footnotes`):

   ```
   **`#footnote` has to be imported to take effect**, and Typst imports are
   per-file: every vertebra that writes a footnote needs `footnote` in its own
   import list, the same way each one needs the template for the `ref` rule.
   Omitting it used to be silent — the body went to the page's endnote section,
   numbered page-wide, and the idea rendered no block at all — so it is now a
   build error naming the import to add.
   ```

   Reword the "used to be silent... is now a build error" framing to state
   the current contract and its rationale directly: "Omitting it fails the
   build with an error naming the import to add — the alternative (Typst's
   own footnote behaviour: the body goes to the page's endnote section,
   numbered page-wide, and the idea renders no block at all) fails silently,
   which is worse than a loud build error for a mistake this easy to make."

## Do NOT

- Do not touch any content inside the `## 0.1.0` chapter (lines 73-239) or the
  three other callouts named under "Explicitly OUT OF SCOPE" above, even if
  they also use words like "used to" or "old" — they are deliberate migration
  guidance, not comment bloat, and removing or softening them is the package
  maintainer's call, not this bird's.
- Do not change any code fence, table structure, or heading in the file —
  prose rewording only, confined to the seven passages named above.
- Do not touch any other file. This bird is `readme.md` only.

## VERIFY

This file is documentation with no compiler or test attached, so VERIFY is a
grep confirming the seven sites are gone and the four excluded ones survive:

```sh
cd /home/lox/code/_fcl/rookery/core/0.1.0 && grep -n "the old paragraph-per-note\|once rendered \"three layers\|is no longer skipped\|this replaced could not be overridden\|used to be skipped outright\|it used to sit inside the\|used to be silent" readme.md
```

Expected: no output.

```sh
cd /home/lox/code/_fcl/rookery/core/0.1.0 && grep -n "Migrating from the old scale\|This changes existing URLs, again\|The default used to be page-only" readme.md
```

Expected: all three still present, unchanged — confirms the excluded callouts
were left alone.