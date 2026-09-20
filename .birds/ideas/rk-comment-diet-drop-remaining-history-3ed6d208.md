---
id: rk-comment-diet-drop-remaining-history-3ed6d208
short-id: 3e
title: 'Comment diet: drop remaining history-narration in core''s src/'
priority: 3
labels:
- chore-core-review
deps:
- blocked-by:rk-hoist-regex-state-reads-out-of-core-s-a04eea8f
closed: true
---
A follow-up comment diet: seven `src/` files carry comments that narrate what
the code USED TO do — a removed panic, a substituted default, a prior
resolution strategy — rather than describing what it does now. Two prior
birds (`rk-comment-diet-idea-typ-and-ideate-typ`,
`rk-comment-diet-pure-typ-and-state-typ`, both retired) already swept
`idea.typ`, `ideate.typ`, `pure.typ` and `state.typ` for exactly this pattern;
these are new instances, added since those birds landed, plus two files
(`transclusion.typ`, `window.typ`, `permalink.typ`) not previously covered.

Touches: /home/lox/code/_fcl/rookery/core/0.1.0/src/ideate.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/src/state.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/src/idea.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/src/transclusion.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/src/window.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/src/permalink.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/src/pure.typ

## The rubric

`/home/lox/code/_fcl/rookery/CLAUDE.md`, "Comment style" section, restated so
this bird stands alone: describe the present. Never what the code used to be,
what moved where, or that something "is gone". Keep the RULE the comment is
protecting; delete the history around it. A comment naming a real Typst
constraint, a caller contract, or a measured number that justifies a constant
is NOT in scope here and must survive untouched.

Line numbers are as of filing; if they have shifted, match the quoted text.

## The specific work

### `ideate.typ`

1. **Lines 169-179**, the banner above `#let _blank(c) = {`:

   ```
   // `parbreak` COUNTS TOO, and it is heading mode that needs it. In parbreak mode
   // a `parbreak` is the separator and so never lands inside a group at all, which
   // is why this went unnoticed for as long as parbreak was the only mode. In
   // heading mode a parbreak is ordinary content, and the blank line that precedes
   // the FIRST `==` of a body therefore becomes a group of exactly one parbreak —
   // non-blank by the old test, not heading-only either, so it minted a note whose
   // entire content was a paragraph break. MEASURED as a spurious third `.idea-box`
   // on a two-section document, and it is the normal case rather than an edge one:
   // almost every body has a blank line before its first heading. Nothing is lost
   // by dropping such a group — a parbreak between two notes is spacing, and the
   // boxes bring their own.
   ```

   Rewrite as present-tense rule, keeping the WHY (a leading blank line before
   a heading is a real, common case, not an edge one) and dropping the
   "went unnoticed"/"the old test"/"MEASURED" framing:

   ```
   // `parbreak` COUNTS TOO, and it is heading mode that needs it: a parbreak is
   // the separator in parbreak mode, so it never lands inside a group there, but
   // in heading mode it is ordinary content — and the blank line before a body's
   // FIRST `==` becomes a group of exactly one parbreak, which is common rather
   // than an edge case (almost every body has a blank line before its first
   // heading). Nothing is lost dropping such a group: a parbreak between two
   // notes is spacing, and the boxes bring their own.
   ```

2. **Line 222**, end of the banner above `_heading-only`:

   ```
   // mode, `none` mode, and the unit tests' own default — keeps the old rule whole.
   ```

   The referent ("the old rule") is the sentence just before it, about a
   non-matching heading level staying structure. Reword to name the rule
   directly instead of calling it "old": e.g. "...`want: none` — par mode,
   `none` mode, and the unit tests' own default — leaves that rule
   unconditional." Keep the rest of the banner (206-221) unchanged; it is a
   real design rationale, not history.

3. **Line 536**, inside the emit loop:

   ```
   // HOISTED OUT of the titling branch below, where it used to live: a
   // `tags:` function reads the same two arguments and is called for groups
   // that branch never reaches.
   ```

   Drop "where it used to live" — say what IS true instead of what moved:

   ```
   // Computed HERE, ABOVE the titling branch below, because a `tags:`
   // function reads the same two arguments and is called for groups that
   // branch never reaches.
   ```

### `state.typ`

4. **Lines 225-232**, inside the `_display-background` block's leading
   comment:

   ```
   // date, its tag pills, its box frame, and its permalink id — plus, on
   // `#window` only, its derived label and its hover background. Same
   // binding/key naming split as `_display-context` above. `#idea`/`#window`
   // used to fall back to a built-in default the moment `display-*` came back
   // `auto`; that default now lives here, so `rookery(..)` can set it once for
   // the whole document instead of at every call site. The values match what
   // `#idea`/`#window` always applied: only `date` and `tags` start off.
   ```

   Replace the "used to fall back... now lives here" sentence with a present-
   tense statement of what these states ARE for: e.g. "Centralising the
   built-in default here, rather than in `#idea`/`#window` themselves, is what
   lets `rookery(..)` set it once for the whole document instead of at every
   call site." Keep "The values match what `#idea`/`#window` always applied:
   only `date` and `tags` start off" — that is a real, present invariant.

5. **Lines 366-368**, banner above `_slug-count`:

   ```
   // A title-derived slug that collides with an earlier one used to panic
   // outright; it now gets a numeric `-<n>` suffix instead, counted in document
   // order, and this dict is what counts it: ...
   ```

   Drop the "used to panic... now gets" framing and state the current rule
   directly: "A title-derived slug that collides with an earlier one gets a
   numeric `-<n>` suffix, counted in document order, and this dict is what
   counts it: ...". Keep everything after "and this dict is what counts it"
   unchanged — it documents the current occupant-list mechanism.

### `idea.typ`

6. **Lines 252-261**, inside the `context { ... }` block's resolution-order
   banner:

   ```
   // A collision has two shapes now, told apart by whether either side is
   // PINNED. Two titles slugging the same no longer panics: the second,
   // third, ... note to derive one slug gets a numeric `-<n>` suffix,
   // counted in document order, from `_slug-peek`/`_slug-record`
   // (state.typ) just below. That suffix IS position-dependent — inserting
   // a new colliding note earlier shifts every later `-<n>` down by one —
   // which is exactly what this comment used to say made a suffix
   // unusable. It is used anyway now: a build that panics is worse than a
   // URL that occasionally moves, and `#idea(<name>, ..)` is how an author
   // opts a note out of ever moving.
   ```

   This is the sharpest violation in the whole review: it literally says "what
   this comment used to say", naming its own prior text. Rewrite as a present-
   tense design decision — state the rule, the position-dependence caveat, and
   the WHY, with no reference to what any comment previously claimed:

   ```
   // A collision has two shapes, told apart by whether either side is PINNED.
   // Two titles slugging the same do not panic: the second, third, ... note
   // to derive one slug gets a numeric `-<n>` suffix, counted in document
   // order, from `_slug-peek`/`_slug-record` (state.typ) just below. That
   // suffix IS position-dependent — inserting a new colliding note earlier
   // shifts every later `-<n>` down by one — and that trade is accepted: a
   // build that panics is worse than a URL that occasionally moves, and
   // `#idea(<name>, ..)` is how an author opts a note out of ever moving.
   ```

7. **Lines 290-293**, inside the same context block:

   ```
   // `none` unless this note actually needs a slug suffix — same reason:
   // computed here as plain data, recorded below only once `id` no longer
   // needs to share a value with that write.
   ```

   Reword "`id` no longer needs to share a value with that write" to describe
   the current data flow rather than a past dependency: e.g. "computed here as
   plain data, ahead of the write below, so the peek and the record read the
   same value without threading it back out of `id`'s own resolution."

### `transclusion.typ`

8. **Lines 317-320**, inside `_window-content`'s paged branch:

   ```
   // `rest` is never rendered here — there is nothing to click it open with
   // — so `shown` grows the same grey ellipsis `_truncate` used to bake in,
   // and a paged window looks exactly as it did before the split.
   ```

   Reword to describe the current shared behaviour without the "used to"/
   "before the split" framing: "`rest` is never rendered here — there is
   nothing to click it open with — so `shown` grows the same grey ellipsis
   `_truncate` bakes in on its own, and a paged window's rendering matches a
   window with no `rest` to speak of."

### `window.typ`

9. **Lines 161-163**, above the `_resolve-display` call:

   ```
   // `_resolve-display` already rejects a non-boolean dictionary value with
   // its own message, so the per-argument asserts these six replaced are
   // redundant for the dictionary path.
   ```

   "these six replaced" refers to per-argument asserts that no longer exist in
   this function. Reword to describe what IS true of the six `display-*`
   flags without implying a prior state: "`_resolve-display` already rejects a
   non-boolean dictionary value with its own message, so a per-argument assert
   on any of the six flags it also validates (`date`, `tags`, `frame`, `name`,
   `label`, `background`) would be redundant for the dictionary path."

10. **Lines 172-175**, above the same call's result binding:

    ```
    // These six keys stay `auto` when unset, same as `context`/`backlinks`/
    // `title` — `#window` no longer substitutes a built-in default itself.
    // `auto` means "use the document-wide `rookery(..)` setting", resolved
    // against state (`_display-final`, state.typ) at the point this window
    // actually renders...
    ```

    Drop "no longer substitutes a built-in default itself" and state the
    current design directly: "These six keys stay `auto` when unset, same as
    `context`/`backlinks`/`title`: `#window` itself substitutes no built-in
    default for any of the nine. `auto` means..." (rest unchanged).

### `permalink.typ`

11. **Lines 35-46**, the banner above `_permalink`:

    ```
    // `href: auto` used to resolve via `_note-href(id)` — a `#context` read of
    // `state("rheo-handle")` taken wherever THIS call happens to run. Fine at a
    // note's own render, wrong at a REPLAY of it (a `#window`, a minted page, a
    // nested transclusion re-placing this note's stored body elsewhere):
    // Typst collapses every copy of a replayed context read to ONE shared value,
    // so a permalink minted this way came out right on at most one of the pages
    // it appeared on. `_resolve-dest(id, true)` hands the destination to rheo's
    // own per-`#document` link rule instead — unresolved, as a plain `link()` —
    // which applies afresh at each realization and so gets every copy right (see
    // `_resolve-dest`'s own banner, urls.typ). An explicit `href:` still bypasses
    // this entirely, as before: a caller passing one already knows its own
    // destination and needs no help resolving it.
    ```

    This is a real, load-bearing trap worth keeping — a future editor
    "simplifying" `_permalink` back to a direct `_note-href(id)` call would
    reintroduce a genuine bug (a permalink wrong on every replayed page but
    one). Keep the mechanism and the WHY; drop the "used to resolve via...
    Fine at... wrong at..." framing that narrates the earlier, broken
    approach as history. Rewrite along these lines:

    ```
    // `href: auto` resolves through `_resolve-dest(id, true)` rather than a
    // direct `_note-href(id)` call, and that indirection matters: a REPLAY of
    // this note (a `#window`, a minted page, a nested transclusion re-placing
    // its stored body elsewhere) shares one Typst context read across every
    // copy, so a `#context` read of `state("rheo-handle")` taken here would
    // come out right on at most one of the pages the note appears on.
    // `_resolve-dest(id, true)` instead hands the destination to rheo's own
    // per-`#document` link rule, unresolved, as a plain `link()` — that rule
    // applies afresh at each realization, so every copy gets the right
    // destination (see `_resolve-dest`'s own banner, urls.typ). An explicit
    // `href:` still bypasses this entirely: a caller passing one already
    // knows its own destination and needs no help resolving it.
    ```

12. **Lines 48-52**, the `link()` rendering note:

    ```
    // `link()` renders as a bare `<a href="..">`, with none of this element's own
    // attributes — VERIFIED empirically, not assumed. They move onto a wrapping
    // `<span>` instead of the anchor itself; core.css's `[data-rookery="label"]`
    // rule carries a matching `> a` rule so the bare anchor inherits the look the
    // class used to set directly.
    ```

    Reword the trailing clause to describe the current split between the
    `<span>` and the `<a>` without "used to set directly": "...so the bare
    anchor inherits the look via that `> a` rule, rather than carrying the
    class itself."

### `pure.typ`

13. **Lines 335-338**, inside `_plain-with`'s banner on the `ref` branch:

    ```
    // A `ref` IS THE ONE LEAF A CALLER CAN DECIDE FOR ITSELF, through `resolve`.
    // It has no `.text`, no `.children` and no `.body`, so a title that names
    // another note — [Meeting with #ref(<idea:x>)] — has nothing here to walk
    // into: what a reference is worth in plain text is the NAME OF ITS TARGET,
    // and only a caller holding the registry knows that. `_plain` below passes
    // the pure answer, `_ => ""`, which is what a title's plain text was before
    // the hook existed; `ideas()` passes one that reads the target's own label.
    ```

    Reword the last sentence to describe the two current callers without
    "before the hook existed": "`_plain` below passes the pure answer, `_ =>
    ""`, for a caller with no registry to resolve against; `ideas()` passes one
    that reads the target's own label."

14. **Lines 429-432**, the matching banner on `_body-text-with`:

    ```
    // resolve` hook and for a sharper reason: a note with NO TITLE names itself by
    // its body (`_derived-title` below), so `#todo[Write @idea:nz-man post]` is
    // called "Write  post" on every worklist, index row and search hit unless
    // whoever holds the registry can say what that reference is worth. MEASURED on
    // exactly that todo. `_body-text` below passes the pure answer, `_ => ""`, which
    // is what a body's plain text was before the hook existed; `_rec-label` and
    // `ideas()` pass `_ref-text(reg)`.
    ```

    Same fix as (13): "`_body-text` below passes the pure answer, `_ => ""`,
    for a caller with no registry to resolve against; `_rec-label` and
    `ideas()` pass `_ref-text(reg)`." Keep "MEASURED on exactly that todo" and
    the sentence before it — that is a real, concrete justification for why
    the hook exists at all, not history-narration about the hook's own past.

## Do NOT

- Do not change one token of code. Comments only, in the seven files listed
  under `Touches:`.
- Do not touch `idea.typ`'s or `ideate.typ`'s other comments beyond the exact
  passages named in items 1-3 and 6-7 — the rest of both files was already
  swept by the two retired comment-diet birds for this package and is out of
  scope here.
- Do not delete a comment that states a Typst constraint, a caller contract,
  or a measured number that justifies a constant. Item 11 in particular is a
  real bug-trap; keep the mechanism and the reasoning, only drop the "used
  to"/"before" framing around it.
- Do not touch any file not listed under `Touches:` — `bib.typ`, `hyperlink.typ`,
  `outline.typ`, `row.typ`, `template.typ`, `data.typ`, `theme.typ`, `urls.typ`,
  `links.typ`, `base.typ`, `lib.typ`, `validate.typ` are all out of scope.

## VERIFY

```sh
cd /home/lox/code/_fcl/rookery/core/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/pure && just build
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check-typst
```

Expected last lines: `units OK`, `demo/pure OK`, `demo/rheo OK`, `demo/rheo
(native) OK` — comment-only changes, so all four must stay exactly as green
as they are today.

Then confirm every named site is gone:

```sh
cd /home/lox/code/_fcl/rookery/core/0.1.0/src && grep -nE "used to|no longer|the old (test|rule)|this comment used" ideate.typ state.typ idea.typ transclusion.typ window.typ permalink.typ pure.typ
```

Expected: no output. If a hit remains, check it is not the ordinary
present-tense sense of "used to" (as in "the value used to build the string")
before treating it as a miss — none of the fourteen sites above are that kind,
but a rewrite could accidentally introduce one.