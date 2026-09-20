---
id: rk-number-a-duplicate-title-derived-id-ffe0db70
short-id: ff
title: Number a duplicate title-derived id instead of panicking
priority: 3
labels:
- fix-duplicate-title-ids
deps:
- blocked-by:rk-converge-the-titleless-note-counter-a0dc775a
closed: true
---
Touches: core/0.1.0/src/idea.typ, core/0.1.0/src/state.typ, core/0.1.0/demo/rheo/content/same-title-pair.typ, core/0.1.0/demo/rheo/check.sh, core/0.1.0/readme.md

Two notes whose titles derive the same id kill the build. They should instead
get different ids, numbered in document order.

## What happens today

`#idea` derives a titled note's id by slugging the title's plain text, and
registration panics if that id is already taken:

```
panicked with: @rookery/core: duplicate note id idea:meeting-with — already
registered in clusters:digitaltheory:pragma:meetings, registered again in grad
```

That was measured on the site at `/home/lox/code/waterline`, where two
untitled meetings each derived the title "Meeting with <refs>" and both slugged
to `meeting-with`. A separate bird fixes that particular factory; this bird
makes core stop turning any such coincidence into a failed build.

## The rule

A **title-derived** id that is already taken gets a numeric suffix, counting in
document order: the first note keeps `idea:meeting-with`, the second becomes
`idea:meeting-with-2`, the third `idea:meeting-with-3`.

A **pinned** id — `#idea(<some-name>, ..)` — never gets a suffix. Two notes
pinned to the same name is an authoring mistake with one right answer, and the
panic stays exactly as it is for that case. Where a derived id collides with a
pinned one, the DERIVED note is the one that moves, whichever registers first:
the author said what the pinned note is called, and the derived note did not.

The first colliding note deliberately keeps the bare, unsuffixed id rather than
becoming `-1`. At mint time a note cannot know that a later note will collide
with it, so numbering the first one too would mean numbering EVERY title-derived
id in every project — renaming every existing note. The cost of this choice is
that `-2` and `-3` shift if a colliding note is inserted before them; that is
accepted, and the readme must say so (step 5).

## Why the existing comment says not to do this

`core/0.1.0/src/idea.typ` carries a comment saying the opposite. Anchor, one
hit:

```
rg -n 'cannot be position-independent|made position-independent' /home/lox/code/_fcl/rookery/core
```

printed `core/0.1.0/src/idea.typ:256-259`, immediately above `let slug`:

> the `-<n>` suffix that used to tell two same-titled notes apart is exactly
> the kind of thing that cannot be made position-independent, so there is none
> left to reach for.

That statement is still TRUE — the suffix IS position-dependent — and the
project has now chosen it anyway, because a build that dies is worse than a
URL that moves when a colliding note is inserted. **Rewrite this comment** as
part of step 4; do not leave it contradicting the code, and do not delete the
reasoning — say what is position-dependent and why it was accepted.

## Steps

1. Find where a titled note's slug and id are computed. Anchor, one hit:

   ```
   rg -n '_id-slug\(_plain\(title\)\)' /home/lox/code/_fcl/rookery/core
   ```

   printed `core/0.1.0/src/idea.typ:260`, inside `#idea`'s main mint, a few
   lines above `let container` and `let id`.

2. Add a slug-occurrence counter to `core/0.1.0/src/state.typ`, beside the
   existing `_scope` machinery (anchor: `rg -n '_scope-record' ` in that file).
   It is a dict of slug to the number of notes that have taken it so far, with
   a peek and a record in the shape `_scope-peek`/`_scope-record` already use.

   **Write the updater as a pure function of its own argument** — derive the
   new count inside the closure from the dict it receives, never from a value
   read by the peek a few lines earlier. The sibling bird that fixed this
   file's convergence measured that an updater closing over a separately-read
   value costs one extra Typst compile attempt per note sharing the key, and a
   pure updater costs none. This is the single most important constraint in
   this bird: get it wrong and every project with same-titled notes stops
   converging.

3. In `idea.typ`, where `id` is built from `slug` (the `else if slug != none`
   arm of the `let id = ..` chain, just below the anchor from step 1), consult
   the counter: if this slug has been seen before, append `-` and the
   occurrence number (2 for the second, 3 for the third). Record the
   occurrence whether or not a suffix was needed, so the next note counts
   correctly. Leave the `named` arm and the container-ordinal arm untouched.

4. Rewrite the comment at `idea.typ:256-259` per "Why the existing comment
   says not to do this" above.

5. Document the rule in `core/0.1.0/readme.md`, wherever it explains how a
   titled note gets its id. State plainly that the suffix counts in document
   order and therefore moves if a colliding note is added earlier, and that
   pinning a name with `#idea(<name>, ..)` is how an author gets an id that
   never moves.

6. Add the fixture `core/0.1.0/demo/rheo/content/same-title-pair.typ`: two
   notes on one vertebra with the SAME title, each body carrying a distinctive
   grep marker in the shape the existing fixtures use
   (`SAMETITLEONEBODY`, `SAMETITLETWOBODY`). Comment it with why it exists.

7. Assert on it in `core/0.1.0/demo/rheo/check.sh`, appending a numbered block
   after the last one and before the `if [ "$fail" -ne 0 ]` summary (anchor:
   `rg -n 'demo/rheo: FAILED' /home/lox/code/_fcl/rookery/core`, one hit).
   Assert that both notes minted a page, that their page names differ, that one
   of them carries the bare slug and the other the `-2` suffix, and that each
   renders its own marker. Follow the surrounding style — a
   `[ -f ... ] || note "..."` per assertion, no test framework.

## Non-goals

- **Do not suffix a pinned id.** The panic stays for two notes pinned to the
  same name. If you cannot tell the two cases apart at that point in the code,
  say so in your report rather than guessing — the `named` flag is already in
  scope at the anchor from step 1.
- **Do not reach for `state("rheo-handle")`, or any other rheo state, to build
  the suffix.** This package must keep working under a plain `typst compile`
  with no rheo, which `demo/pure/` exercises and `readme.md` documents. The
  handle is empty there, so a handle-derived disambiguator would silently not
  disambiguate at all.
- **Do not change how a NAMED note or a container-ordinal (titleless) note
  gets its id.** Both arms of the `let id` chain stay as they are.
- **Do not touch any other package**, and do not edit anything in
  `/home/lox/code/waterline`.

## Uncertainty, and the fallback

The registry update that raises the panic (anchor: `rg -n 'duplicate note id'`,
one hit, `core/0.1.0/src/idea.typ:438`) runs AFTER `id` is computed and after
the note's own anchor has been emitted with that id. So the suffix has to be
decided at mint time, from the counter, not at registration — the registry is
the wrong place to fix this and a patch there will produce ids that disagree
with the anchors already written. If you find a case where the counter and the
registry disagree about a note, stop and report it.

If adding the counter costs convergence attempts despite step 2's pure
updater, report the measurement rather than working around it by reading the
state less often — a wrong id is worse than a slow build.

## VERIFY

1. From `core/0.1.0/`, `just test` passes.
2. From `core/0.1.0/demo/rheo/`, `just check` passes and prints `demo/rheo OK`,
   with the new assertion block included.
3. From `core/0.1.0/demo/rheo/`, `rheo compile .` prints no line containing
   `did not converge`.
4. From `core/0.1.0/demo/pure/`, that demo's own check still passes — the
   suffix must work with no rheo present.
5. From the repository root, `just check-versions` still prints its OK line.