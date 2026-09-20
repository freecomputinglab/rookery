---
id: rk-comment-diet-core-s-test-suite-demo-195e5ddb
short-id: '19'
title: 'Comment diet: core''s test suite, demo fixtures and .marrow.typ'
priority: 3
labels:
- chore-core-review
deps: []
closed: true
---
Outside `src/`, this package's unit fixture, its two demo suites and
`.marrow.typ` carry the same history-narrating pattern the `src/` comment-diet
birds already target: a comment that explains a regression fixture by
recounting the BUG it once caught ("used to render...", "MEASURED before the
fix"), rather than stating the invariant the fixture now asserts. None of
these were in scope for the prior `src/`-only comment-diet birds.

Touches: /home/lox/code/_fcl/rookery/core/0.1.0/test/units.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/demo/pure/Justfile,
/home/lox/code/_fcl/rookery/core/0.1.0/demo/pure/folded-height.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo/check.sh,
/home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo/content/same-title-pair.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo/content/sub/page.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo/content/index.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/.marrow.typ

## The rubric

Same as the `src/` comment-diet birds: `/home/lox/code/_fcl/rookery/CLAUDE.md`,
"Comment style" — describe the present, never what the code used to do. For a
regression fixture specifically, the present-tense form is "asserts that X
holds" or "X, which is what Y depends on", not "X used to fail this way;
MEASURED". Line numbers are as of filing; match the quoted text if they have
shifted.

## The specific work

### `test/units.typ`

1. **Lines 229-230**, above an assertion in the `_blocks` tests:

   ```
   // this holds only because a `space` between two items no longer clears the run:
   ```

   (confirm the full sentence in file before editing — it continues onto
   context around the assertion it sits above). Reword to state the current
   rule the assertion checks, without "no longer": e.g. "this holds because a
   `space` between two items does not clear the run — see `_blocks`'s own
   comment on why a list's own punctuation space must survive."

2. **Lines 284-285**, above `#assert.eq(_blocks([A#metadata((k: 1))B]).len(), 1)`:

   ```
   // `#idea`'s own marker is `metadata`: invisible, and it used to take a whole
   // block — and therefore a whole `limit` slot — to itself.
   ```

   Reword to state what the assertion verifies now: "`#idea`'s own marker is
   `metadata`: invisible, and this assertion is what confirms it never takes a
   whole block — and therefore a whole `limit` slot — to itself."

3. **Lines 475-476**, above a footnote/citation walk test:

   ```
   // walks used to stop dead at any metadata that was not a window marker. MEASURED
   // before the fix: an idea whose only citation sat in a footnote rendered the
   ```

   Read the full comment (it continues past line 476) and reword to state
   what the test asserts — that a citation inside a `#footnote` is still
   claimed by the enclosing idea's own references block — dropping "used to
   stop dead" and "MEASURED before the fix".

4. **Line 617**, inside the smartquote/block test:

   ```
   // It used to contribute NOTHING, so every apostrophe and quotation mark vanished
   ```

   Reword to state the current, asserted behaviour: a `smartquote` renders as
   its ASCII form in plain text (see the sibling banner in `pure.typ` on
   `_plain-with`'s own `smartquote` branch), so this assertion is what checks
   an apostrophe is never dropped.

5. **Lines 691-692 and 698-699**, inside the parbreak-group tests:

   ```
   // of one parbreak that used to mint a note holding nothing but a paragraph
   ...
   // body, which renders nothing yet is not whitespace — so it used to mint one
   ```

   Read both comments in full and reword each to state the current rule (a
   lone parbreak / an inert node is dropped or held rather than minting a
   note of its own) without "used to".

6. **Line 740**, inside the heading-only test:

   ```
   // used to vanish from `#ideas()`, and so from every pinboard and outline). A
   ```

   Read the full sentence and reword to state the current, asserted outcome
   (such a section stays in `#ideas()`, and so in every pinboard and outline)
   rather than what it used to do.

### `demo/pure/Justfile`

7. **Line 17**, inside the `build` recipe's header comment:

   ```
   # (typst compile` directly, which
   # is why this comment used to warn that both needed updating — it no longer does.
   ```

   This sentence is ONLY about the comment's own editing history — delete it
   outright; nothing downstream depends on it. Read the two or three lines
   around it first (the recipe header explains why CI picks up a root added
   here automatically) and keep that substance intact.

8. **Lines 93-94**, inside the `check` recipe's item 7 comment:

   ```
   #    parent's id with a counter appended — the old ordinal-based scheme
   #    this replaced.
   ```

   Reword to state the current rule without naming what it replaced: "...a
   nested titleless note derives its own id from its own body rather than
   reusing its parent's id with a counter appended."

### `demo/pure/folded-height.typ`

9. **Line 9**:

   ```
   // titled one had two. MEASURED before the fix: titled 26.02px, untitled 8.02px.
   ```

   Read the full comment above this line. Keep the two pixel measurements if
   they still justify the fixture's assertion (a real number worth keeping,
   per the rubric's "keep the measurement" allowance) but drop "before the
   fix" — state what the fixture currently asserts about the two heights
   instead of what was true before a fix landed.

### `demo/rheo/check.sh`

10. **Lines 58-59**, in the comment above the backlink-from-context assertion:

    ```
    # transcludes used to lose its backlink from the page transcluding it.
    ```

    Read the full comment (it explains why a `#window` computed inside
    `#context` needs its own test). Reword to state what the assertion
    verifies now — that such a window's target note DOES gain a backlink from
    the transcluding page — dropping "used to lose".

11. **Line 64**:

    ```
    # MEASURED before the fix it produced no backlink at all while a hand-written
    ```

    Part of the same passage as (10); fold into the same rewrite, keeping any
    concrete detail that distinguishes this case from the hand-written-window
    case it contrasts with.

12. **Lines 127-130**, in the href-format assertion comment:

    ```
    #    `<slug>.html` is the whole correct href. It used to be spelled
    ...
    #    82-note site: every row 404. So the old form must NOT be accepted again.
    ```

    Read the full passage. State the current contract (what the correct href
    shape is, and that this assertion is a regression guard against a
    specific wrong shape) without "used to be spelled" / "the old form".

13. **Lines 289-291 and 300-303**, in the derived-title-on-a-minted-page
    comment block:

    ```
    #     card; only here is there a minted page, whose `<title>` and `<h1>` used to
    #     fall back to the note's SLUG — so an untitled note's own page was named `1`.
    ...
    #   regression guard for the defect it fixed: a derived name is a LABEL for
    #   referring to the note, not a heading to print above the note's own body.
    #   MEASURED before the split — the minted page rendered `<h1>DERIVEDBODY..</h1>`
    #   and then `<p>DERIVEDBODY..</p>`, the same text twice.
    ```

    Read both passages in full. Reword to state the current, asserted
    contract: a minted page's `<title>`/`<h1>` come from the note's derived
    title, and its `<h1>` is empty because a derived name is a LABEL, not a
    heading — dropping "used to fall back", "the defect it fixed" and
    "MEASURED before the split".

14. **Lines 383-386** (the `unfurl: 2` window's tail description) and
    **lines 400-401** (the w-inner unfurl-count failure message) both use
    "no longer"/"may no longer be" — read both in context before touching
    them. Line ~349 ("is no longer exercised") and line ~400 sit inside
    PRINTED FAILURE MESSAGES describing what a future failure would mean, not
    narration about the package's past — leave those two alone. Only reword
    384-386 if, on reading it in full, it reads as historical narration rather
    than a description of the current disclosure shape; if it already reads
    as a present-tense description of where the tail sits, leave it as is and
    say so in your report.

15. **Line 601**, in a comment on a hat/heading assertion:

    ```
    #   wrote; it used to be emitted as a bare heading and never reach the
    ```

    Read the full comment and reword to state the current, asserted shape
    (what the hat/heading wraps and reaches now) without "used to be".

### `demo/rheo/content/same-title-pair.typ`

16. **Line 8**:

    ```
    // `core/0.1.0/src/idea.typ` used to panic the instant the second one
    ```

    Read the full comment (fixture-level rationale for why this pair of notes
    exists). Reword to state what the fixture currently demonstrates (two
    notes with the same title get a numeric suffix rather than a panic)
    without "used to panic".

### `demo/rheo/content/sub/page.typ`

17. **Lines 26-28**:

    ```
    // cannot enter a context block, so a window written like this used to announce
    // itself to nobody and the note it transcludes lost its backlink from this page.
    // `check.sh` asserts that `plain-note` now lists this vertebra.
    ```

    Reword to state the current contract directly: a window computed inside a
    `#context` block still has to announce itself so the transcluded note
    gains a backlink from this page, and `check.sh` asserts that `plain-note`
    lists this vertebra — dropping "used to announce itself to nobody" and
    "now lists".

### `demo/rheo/content/index.typ`

18. **Lines 39-40**:

    ```
    // Its only citation sits inside a footnote, which is the case that used to
    // vanish: the marker rendered and no references block was emitted anywhere.
    ```

    Reword to state what the fixture currently demonstrates: a citation
    inside a footnote is still claimed by the idea's own references block.

19. **Lines 108-110** (the derived-title-on-minted-page header comment,
    companion to check.sh item 13):

    ```
    // rheo is the minted page, whose `<title>` and `<h1>` used to fall back to the
    // note's SLUG — so an auto-numbered note's own page was called `1`.
    ```

    Reword to state the current contract (the minted page's `<title>`/`<h1>`
    come from the derived title) without "used to fall back".

20. **Lines 122-124**:

    ```
    // exactly the case that broke before a nested note's borrowed ordinal was
    // replaced by one. A note with NEITHER a name NOR a title mints under a body
    ```

    Reword to state the current id-derivation rule directly (a nested,
    unnamed, untitled note mints a body-slug-plus-digest id) without "broke
    before" / "was replaced by".

### `.marrow.typ`

21. **Lines 15-17**:

    ```
    // links to. This file no longer strips it itself for the minting path:
    // `_note-page` returns the slug, the file and the handle together, and reads
    // that one state on this file's behalf.
    ```

    Reword to state the current division of labour directly: "The
    `<prefix>:` stripping for the minting path is `_note-page`'s job, not
    this file's: it returns the slug, the file and the handle together,
    reading that one state on this file's behalf." Drop "no longer strips it
    itself".

22. **Line 357**, at the end of a footnote-wrapping comment:

    ```
    // note's footnotes from its own page. MEASURED before the fix.
    ```

    Keep the sentence before it (the failure mode a reader would reintroduce
    by removing the wrapper — that is a real caller contract) and drop the
    trailing "MEASURED before the fix." with nothing needed to replace it.

## Do NOT

- Do not change one token of code, or one assertion, in any of these files —
  comments only.
- Do not touch `src/*.typ` — that is the separate `src/`-only comment-diet
  birds' scope.
- Do not touch any `demo/` or `test/` file not listed under `Touches:`.
- Do not remove a comment's concrete measurement (a pixel value, a count) if
  it still justifies the fixture's assertion — reword the historical framing
  around it, keep the number.
- For item 14, do not reword the two printed failure-message lines
  (`check.sh` around lines 349 and 400) unless you determine on reading them
  that they narrate package history rather than describe what a future
  failure would mean — say what you decided and why in your report either
  way.

## VERIFY

```sh
cd /home/lox/code/_fcl/rookery/core/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/pure && just build
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check-typst
```

Expected last lines: `units OK`, `demo/pure OK`, `demo/rheo OK`, `demo/rheo
(native) OK` — comment-only changes (`demo/rheo/check.sh` and
`demo/pure/Justfile` are test scripts, not fixtures under test, but their
assertions must still fire identically), so all four must stay exactly as
green as they are today, with the same pass/fail pattern.

Then confirm the named sites are gone (allow the two printed failure-message
lines from item 14 to remain if you judged them out of scope):

```sh
cd /home/lox/code/_fcl/rookery/core/0.1.0 && grep -rnE "used to|no longer|MEASURED before|before the (fix|split)" test/units.typ demo/pure/Justfile demo/pure/folded-height.typ demo/rheo/check.sh demo/rheo/content/same-title-pair.typ demo/rheo/content/sub/page.typ demo/rheo/content/index.typ .marrow.typ
```

Expected: no output, other than the two failure-message lines from item 14 if
you kept them — name which, if any, you kept and why in your report.