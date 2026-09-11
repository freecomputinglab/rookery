---
id: rk-comment-diet-data-template-theme-row-d47f1a99
short-id: d4
title: 'Comment diet: data, template, theme, row'
priority: 3
labels:
- chore-core-review
deps:
- blocked-by:rk-cache-bib-keys-drop-dead-cite-walk-871b6099
- blocked-by:rk-move-config-helpers-out-of-data-typ-2d9d7cdd
- blocked-by:rk-destructure-pair-maps-across-core-de56c4bd
closed: false
---
`data.typ`, `template.typ`, `theme.typ` and `row.typ` are 1423 lines, 750 of
them comment lines. Three of those files explain themselves by recounting how
many hand copies of something there used to be, and one carries a paragraph
about how many lines a function was before it was split. Cut all four to
present-tense description without losing a constraint.

Touches: /home/lox/code/_fcl/rookery/core/0.1.0/src/data.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/src/template.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/src/theme.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/src/row.typ

## The rubric

`/home/lox/code/_fcl/rookery/CLAUDE.md`, the section headed "Comment style", is
the standard. Read it before editing. Restated so this bird stands alone:

- **Describe the present.** What the code is and why it is that way. Never what
  it used to be, what moved where, which release changed it, or that something
  "is gone".
- **No issue ids**, bookmark names or branch names.
- **Keep the measurement, drop the lab notebook.** A number that justifies a
  constant stays and says what it buys; the machine, the date, the baseline it
  beat and the alternatives that lost go — unless a future reader would
  otherwise retune the number, and then one sentence.
- **One header per file, no interior banners** restating it.
- **Comment the non-obvious.** What earns a line: a constraint the code cannot
  express, a contract a caller would otherwise get wrong, a rule shared with
  another language. Not a restatement of the line below it.
- **Declarative and concise, present tense.** Emphasis capitals for the one
  claim in a block that carries it. Comments should be a minority of the lines.

A `REJECTED`/`REFUTED` block is not automatically deletable: keep the RULE as
one or two present-tense sentences, delete the narrative.

## A warning about line numbers in this bird

A sibling bird moves `_validate-config`, `_resolve-tags-color` and
`_resolve-theme` out of `data.typ` and into `template.typ` verbatim. It lands
before this one, so those three functions and their comment blocks will be in
`template.typ` by the time you read them, and every line number below will have
shifted. **Match on the quoted text, not on the number.** The work is the same
either way: the same comment blocks, wherever they now live, and they are named
in this bird under `template.typ`.

## The specific work

### `data.typ`

1. The `tag-index` banner (14-42) opens "WHY THIS EXISTS. Until now there were
   two accessors and nothing between them" and spends a paragraph on four
   measured corpus walks in a consuming project. Keep the rules: a projection is
   resolved ONCE for the whole `ideas()` call, nothing caches, so a caller
   builds one index per page and passes it to everything on it; and the
   scalars-only contract with its reason, that a projected value is guaranteed
   encodable as JSON and as an HTML attribute. Drop the history.
2. `_project-one`'s `NOT \`as:\`` note (62-64) keeps its rule — `as` is a
   reserved keyword, so the conversion flag cannot wear that name — and loses
   the version reference.
3. The `#ideas` banner (194-297) is about a hundred comment lines. Keep: the
   field table; that `tags` is names only and why (a consumer puts the field
   straight into a JSON index and calls `.map` on it, and `json.encode` of
   content silently emits a structural blob rather than erroring); the three
   tiers and that the narrow one is the default; that filtering happens before
   the `.map`; that it must be called inside `#context` and why it is not itself
   a context function. Drop: "a real project had eight copies of that before
   this field existed" (line 333), the repeated scalar-rule paragraphs (277-293
   restates 33-37), and the "as of 0.5.0" version qualifiers at lines 72 and
   219 — keeping, in both cases, the rule that tag key order is unspecified and
   nothing may depend on it.

### `template.typ`

4. **Delete outright** the two paragraphs that describe the code's own history
   rather than the code: "Extracted from `rookery` below rather than inlined in
   it: the function was 158 code lines, 13 of them asserts, and a reader asking
   what `#show: rookery` actually DOES had to scroll past the whole validation
   wall..." and "Every message is verbatim from where it was, including the ones
   that name no function". Replace with one line saying what
   `_validate-config` is: every `#show: rookery` argument checked before
   anything is published. Do the same to `_resolve-theme`'s "Extracted
   alongside `_validate-config` above and for the same reason" — keep only its
   real content, that it returns the resolved dictionary rather than publishing
   it.
5. The `<style>` block comment (200-240 before the move) keeps: that custom
   properties inherit only from an ancestor that carries them, which is why a
   document-scope `:root` block is emitted in addition to the per-container
   inline styles; that it runs exactly once per output page and why; that an
   unthemed project still emits nothing; the two-blocks-one-`<style>` shape; and
   the html/epub gate. Drop the named downstream bug it fixed.
6. The page-links beacon comment (254-274) keeps the exactly-once-per-page fact
   and that a minted page publishes no beacon. Drop the pointer to "the 72 dead
   links the sweep was ultimately responsible for" — the rule it points at lives
   in `outline.typ` and is a sibling bird's to state.
7. The trailing-citations block (291-310) keeps everything: that an unclaimed
   citation is a hard error, so this is required for the page to build; that the
   template can ask the question an idea cannot because it holds the whole page.

### `theme.typ`

8. `_tags-color-rules` (111-154) keeps: why rules rather than an inline style
   (the same class is worn by surfaces Typst cannot reach, including chips built
   in the browser); the `@layer rookery-tags` requirement, that unlayered CSS
   beats layered CSS regardless of source order, so without the layer these
   generated rules would outrank a project's own; the accepted EPUB consequence;
   and the three-properties-from-two-keys rule for `--idea-tag-line`. Drop
   "These colours used to be an inline `style` attribute on the one pill
   `_permalink-tab` builds".
9. The `_THEME-KEYS` banner (15-79) keeps the cross-package contract in full —
   the state key string, the dictionary's shape and every property spelling are
   read by `@rookery/search` by name, and changing any of them means changing
   that package in the same commit. Compress the design prose about which colour
   belongs to which hover, and drop "they were four literals" (line 66).

### `row.typ`

10. The file header (1-27) currently justifies the file by counting hand copies:
    "had been written five times across this repo and its first consumer", "One
    object, three hand copies", and a quoted comment from another package's
    stylesheet. Rewrite it as what the row is: one row shape — when, title,
    cells, badges — shared by every list of notes in the family, with the cells
    arriving already formatted so the row asks no questions about what a date or
    a badge means. Keep "WHY IT LIVES IN CORE" compressed to its real
    constraint: rheo scans only a project's own imports, never a package's, so a
    project reaching this markup through another package would get it without
    that package's CSS or JS. Keep the no-JavaScript rule.
11. `idea-row-body`'s and `idea-row`'s parameter comments (41-67, 100-131,
    152-157, 175-182) keep their contracts — that `attrs:`/`when-attrs:` merge
    UNDER the computed class so a caller cannot drop the row's own classes; that
    a badge is a dictionary or content and core styles only the dictionary form;
    that `soft` is dropped for a dateless row; and the paged-target panic. Drop
    the repeated "which is the fifth hand copy this file's header exists to
    prevent", which appears three times.

## Do NOT

- **Do not change one token of code.** Not a rename, not a reformat. Comments
  only.
- Do not delete a comment that states a constraint, a caller contract, a
  measured number that justifies a constant, or a parity link.
- Do not add a claim you have not verified in the code in front of you.
- Do not touch any file outside the four named above.
- Do not move any function between files. That is the sibling bird's work and
  it has already landed by the time this one flies.

## VERIFY

A comment edit that swallows a line of code fails these, so all four must still
be green:

```sh
cd /home/lox/code/_fcl/rookery/core/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/pure && just build
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check-typst
```

Expected last lines: `units OK`, `demo/pure OK`, `demo/rheo OK`,
`demo/rheo (native) OK`.

Then the checks specific to this bird:

```sh
cd /home/lox/code/_fcl/rookery/core/0.1.0/src && grep -nE "158 code lines|verbatim from where|hand copies|five times|eight copies|Until now|as of 0\.[0-9]|used to" data.typ template.typ theme.typ row.typ
cd /home/lox/code/_fcl/rookery/core/0.1.0/src && for f in data.typ template.typ theme.typ row.typ; do echo "$f $(grep -c '^[[:space:]]*//' $f)/$(wc -l < $f)"; done
```

The first must print nothing, with two honest exceptions: `used to` also spells
the ordinary present-tense "X is used to build Y", and `verbatim` is used
correctly in `row.typ:122` about content a caller owns. A hit of either kind is
fine — say so in the flight rather than rewording a correct sentence.

The second command's numbers depend on the sibling move having landed; land
each file at roughly 60% of whatever it reports before you start. The count is
guidance, not a gate — losing a constraint to hit a number is the one failure
this bird cannot accept.