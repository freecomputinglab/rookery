---
id: rk-thread-the-known-handle-into-page-href-234485c3
short-id: '234'
title: Thread the known handle into page-href
priority: 4
labels:
- fix-page-href-handle-replay
deps: []
closed: true
---
Touches: core/0.1.0/src/outline.typ, core/0.1.0/.marrow.typ

`_page-href` re-reads the page handle out of state every time it is called,
including when it is called from `.marrow.typ`'s registry loop, which already
knows the handle for the page it is building. That read is one of the last
things keeping a large project from converging.

## Why this bird exists, and what is already done

A previous bird fixed the SAME defect in the sibling function `_note-href`, by
rendering a permalink through rheo's own link rule instead of resolving the
destination with a context read. That landed and is verified. It measurably
reduced the non-convergence surface, and the site's `urls.typ` warning is gone.

What it could not do was fix `_page-href`, because the fix requires editing
`.marrow.typ`, which was not on that bird's `Touches:` line. Its worker went as
far as adding a `here: auto` parameter to `_page-href`, confirming the default
preserved today's behaviour exactly, and then REVERTING it rather than land an
inert diff outside its scope. So that parameter does not exist yet; you are
adding it.

## The defect, measured

Building `/home/lox/code/waterline` (60+ vertebrae, heavy `#window` nesting)
against the package with the sibling fix in place still prints:

```
warning: value of `state("rheo-handle")` did not converge
    ┌─ @rookery/core:0.1.0/src/outline.typ:605:14
    │
605 │   let here = state("rheo-handle").get()
      - run 1: `none`
      - run 2: `"writing:remarks:joan-symposium"`
      - run 3: `"writing:remarks:joan-symposium"`
      - run 4: `"writing:remarks:joan-symposium"`
      - run 5: `"ideas:index"`
      - final: `"ideas:typst-summer"`
```

The value is a different page on almost every attempt, because the read is
replayed wherever the built markup is placed rather than answering for the page
it was built FOR.

## The sites

**The read.** Anchor, one hit:

```
rg -n 'let here = state\("rheo-handle"\).get\(\)' /home/lox/code/_fcl/rookery/core
```

printed `core/0.1.0/src/outline.typ` (line 605 as of filing), inside
`_page-href`.

**The two callers**, both in `core/0.1.0/.marrow.typ`, both inside the
`for (id, rec) in registry.pairs()` loop. Anchors, one hit each:

```
rg -n '_page-href\(origin\)' /home/lox/code/_fcl/rookery/core
rg -n '_page-href\(handle\)' /home/lox/code/_fcl/rookery/core
```

They read `context-href = _page-href(origin)` and `href = _page-href(handle)`.
That loop ALREADY computes the handle of the page it is emitting, as
`page-at.handle` — anchor `rg -n 'page-at.handle'`, in the same file. That is
the value the read is failing to reproduce.

## Steps

1. Give `_page-href` an optional `here:` parameter defaulting to `auto`, and
   use it in place of the state read when it is not `auto`:

   ```typ
   let here = if here != auto { here } else { state("rheo-handle").get() }
   ```

   This is the exact shape `_note-href` already uses — anchor
   `rg -n 'if handle != auto'` in `core/0.1.0/src/urls.typ`, one hit. Copy that
   shape rather than inventing a second one.

2. With the default `auto`, EVERY existing caller keeps today's behaviour
   byte-for-byte. Verify that before going further: at this point `just check`
   in `demo/rheo` must still pass with no other change made.

3. Update the two `.marrow.typ` callers to pass the handle the loop already
   holds. Match each call to the right value — one is the ORIGIN page (where
   the note was authored), the other the page being emitted; they are not
   interchangeable, and passing the wrong one produces links that point at the
   wrong page without any error. Read the surrounding loop and say in your
   report which value you passed to which call, and why.

4. Re-measure on both reproductions and report the numbers:
   - `core/0.1.0/demo/rheo/`: `rheo compile .`
   - the site: copy `/home/lox/code/waterline/rookery/rheo.toml` to a scratch
     config INSIDE that repository (e.g. `rookery/.checkph.toml`), replace the
     `repo =`/`branch =` pair in `[packages.rookery]` with
     `path = "<your flight path>"`, build with
     `rheo compile rookery --config rookery/.checkph.toml --html --build-dir <a scratchpad dir> --input today=2026-09-20`,
     and DELETE that scratch file afterwards. You may read and build that site;
     you may NOT edit anything else in it.

   State whether `outline.typ`'s warning is gone, and whether the document now
   converges. It may not — see below.

## Known remaining sites, which are NOT yours

The sibling bird's measurement named two further handle reads that this bird
does NOT cover. Do not fix them; DO report whether they still warn after your
change, since that determines what gets filed next:

- `core/0.1.0/src/idea.typ` (line 386 as of filing),
  `let handle = state("rheo-handle").get()` — the note's REGISTRATION-time
  read. Structurally different: a first read, not a replay.
- `core/0.1.0/src/outline.typ` (line 301 as of filing),
  `state("rheo-handle").at(el.location())` inside `_ideas-outline-data`'s query
  walk — a positional per-element lookup, which may well be correct as written.

A separate bird also owns `bib.typ`'s footnote counter. Leave it alone.

## Non-goals

- **Do not touch `urls.typ`, `permalink.typ`, `bib.typ`, or `state.typ`.**
  Other birds own them; editing them here collides in the nest.
- **Do not change what a link POINTS AT.** This is about where the handle comes
  from, not about link structure. A link that changes target is a bug you
  introduced, and step 3 is where it would happen.
- **Do not add the `titleless-pair.typ` fixture.** It is withheld deliberately
  by another bird until the demo can build it; if your change happens to make
  that possible, say so in your report and let that bird land it.
- **Do not edit anything in `/home/lox/code/waterline`** beyond creating and
  deleting the scratch config named in step 4.

## Uncertainty

It is NOT established that this is the last cause. The document may still fail
to converge after this change — that is an acceptable outcome for this bird, as
long as `outline.typ:605`'s own warning is gone and you report what remains.
Do not chase the remainder into other files.

## VERIFY

1. From `core/0.1.0/demo/rheo/`, `rheo compile .` prints no warning naming
   `outline.typ`'s `here` read.
2. From `core/0.1.0/demo/rheo/`, `just check` passes and prints `demo/rheo OK`.
3. From `core/0.1.0/`, `just test` passes.
4. From `core/0.1.0/demo/pure/`, `just build` prints `demo/pure OK` — this must
   still work with no rheo present, where the handle is empty.
5. Spot-check one built page under `demo/rheo/build/html/ideas/` and confirm a
   transcluded note's "Context" link still points at the page the note was
   authored on, not at the page it is transcluded into.
6. From the repository root, `just check-versions` still prints its OK line.