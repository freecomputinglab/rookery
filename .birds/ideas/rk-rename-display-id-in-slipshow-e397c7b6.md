---
id: rk-rename-display-id-in-slipshow-e397c7b6
short-id: e3
title: Rename display-id in slipshow
priority: 2
labels:
- fix-idea-name-terminology
deps: []
closed: false
---
`@rookery/core` has renamed the `display-id:` argument to `display-name:`, as
part of standardising on one word — **name** — for the thing that names a note.
`@rookery/slipshow` forwards that argument straight through to core from two of
its own public functions, with the default inverted, so it calls core with an
argument core no longer accepts and every deck fails to compile until this
lands.

Touches: slipshow/0.1.0/src/slipshow.typ, slipshow/0.1.0/src/slip.typ, slipshow/0.1.0/src/slipshow.css, slipshow/0.1.0/readme.md

## Prerequisite — fly this on a line that carries slipshow

The core rename landed on a line that does not carry the sibling packages at
all. Before starting, confirm both that core has the new name and that this
flight's tree actually has `slipshow/`:

```bash
ls slipshow/0.1.0/src/slipshow.typ
rg -n 'display-name' core/0.1.0/src/idea.typ
```

If `slipshow/0.1.0/src/slipshow.typ` does not exist, **stop and report that** —
the flight was slipped from the wrong base and there is nothing here to rename.
If the second command prints nothing, core's rename is not on this line either;
stop and report that too, rather than renaming slipshow to match a core that
still exports the old name.

## What core did

`display-id:` is now `display-name:`, on both `#idea` and `#window`. The
corresponding key in the `display:` dictionary changed from `id:` to `name:`,
core's internal state key `rheo-idea-show-id` became `rheo-idea-show-name`, and
the canonical key list `_DISPLAY-KEYS` in `core/0.1.0/src/pure.typ` now carries
`"name"` instead of `"id"`.

**There is no alias.** A stale `display-id:` does not silently do nothing — it
raises `#idea`'s (or `#window`'s) unknown-named-argument panic. That is
deliberate, and this bird must not soften it: do not add a `display-id:`
parameter to slipshow that forwards to `display-name:`, and do not accept both
spellings.

What core did NOT rename, so neither does this bird: a note's own `id` (the
positional argument to `#idea`, the `.id` field on `ideas()` rows), and the CSS
custom property `--idea-id-color`, which is a separate rename with a separate
bird.

## The sites

Nineteen occurrences across four files. The anchor is the literal string
`display-id`; run it at the package root so a moved file still resolves:

```bash
rg -n 'display-id' slipshow/0.1.0
```

As of filing that printed nineteen hits, in four files:

1. **`slipshow/0.1.0/src/slipshow.typ`** — 8 hits. A comment in the header
   block (line 31, in the paragraph listing which display arguments default to
   `false` here); the parameter declaration on `#slipshow` (line 153,
   `display-id: true,`) and its pass-through into the call it wraps (line 165,
   `display-id: display-id,`); the parameter declaration on the second public
   function (line 385, `display-id: false,`); the type assertion and its
   message (lines 433-434, `type(display-id) == bool` and
   `` "@rookery/slipshow: `display-id` must be a bool — got " ``); and two more
   pass-throughs (lines 487 and 520, both `display-id: display-id,`).
2. **`slipshow/0.1.0/src/slip.typ`** — 2 hits: the parameter declaration
   (line 55, `display-id: false,`) and its pass-through (line 84,
   `display-id: display-id,`).
3. **`slipshow/0.1.0/src/slipshow.css`** — 1 hit, a comment at line 224
   (`` slide has no id to clear: `#slipshow` sets `display-id: false`, which leaves the ``).
4. **`slipshow/0.1.0/readme.md`** — 8 hits: lines 82 and 188 inside code
   samples, lines 104 and 252 as the first cell of an argument-table row,
   and lines 117, 130, 209 and 267 in prose.

Line numbers are as of filing and will have drifted. Resolve every site by
running the `rg` above inside the flight and renaming what it finds. If it
prints nothing at all, widen to the whole flight path; if it is still empty,
report that upward rather than guessing.

## The steps

1. Run the prerequisite checks above.
2. Rename every one of the nineteen occurrences from `display-id` to
   `display-name`. This is a plain string substitution at each site — parameter
   names, pass-throughs, the assertion and its message, comments, code samples
   and table cells all take the same replacement. The inverted defaults stay
   exactly as they are: `display-name: true` on `#slipshow`, `display-name:
   false` on the other two declarations.
3. Grep slipshow's own `src/` for a canonical list of display keys before
   concluding you are done:

   ```bash
   rg -n 'DISPLAY-KEYS|display-keys' slipshow/0.1.0/src
   ```

   As of filing this prints nothing — slipshow has no list of its own and
   forwards each argument individually. If it now prints something, that list
   needs `"id"` renamed to `"name"` as well; core's equivalent turned out to be
   the load-bearing site in the core half of this rename.
4. Add a migration note to `slipshow/0.1.0/readme.md`, matching the pattern
   core's own readme now sets. Find core's to copy its shape and voice:

   ```bash
   rg -n 'Migrating from' core/0.1.0/readme.md
   ```

   One short section, stating that the rename is breaking, that `display-id:`
   is now `display-name:`, and that there is no alias — a stale `display-id:`
   fails the compile with an unknown-named-argument panic rather than silently
   doing nothing.

## Non-goals

- Do not add a back-compat alias, a deprecation shim, or acceptance of both
  spellings.
- Do not touch `--idea-id-color` / `idea-id-color` anywhere. That rename has
  its own bird, and this one must leave it alone even where the two appear in
  the same file.
- Do not rename `foldable:`, `reserve-title:`, or any other slipshow argument.
- Do not rename a note's own `id` — the positional argument to `#idea`, the
  `.id` field on `ideas()` rows, `idea:<name>` anchors, or anything in
  `slipshow/0.1.0/src/*.js`.
- Do not touch `core/`. Core's half of this rename has already landed.
- Do not restructure the readme's argument tables or reorder their rows; only
  the cell text changes.

## VERIFY

1. `rg -n 'display-id' slipshow/0.1.0` prints nothing except the migration note
   you added in step 4, which names the old spelling on purpose.
2. `rg -n 'display-name' slipshow/0.1.0/src/slipshow.typ` and
   `rg -n 'display-name' slipshow/0.1.0/src/slip.typ` each print hits.
3. `cd slipshow/0.1.0 && just build` succeeds.
4. `cd slipshow/0.1.0 && just test` prints `units OK`.
5. `cd slipshow/0.1.0 && just check` succeeds — this is the one that proves the
   forwarding actually reaches core, since it runs `rheo compile demo/rheo` and
   then `./demo/rheo/check.sh` against the rendered DOM. A stale `display-id:`
   surfaces here as an unknown-named-argument panic from `#idea` or `#window`.

If step 5 cannot run because `rheo` resolves `@rookery/core` from somewhere
other than this tree, say so in your flight report rather than reporting a
build you did not actually perform.