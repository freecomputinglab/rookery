---
id: rk-move-the-root-design-notes-out-of-sight-9c2b1644
short-id: 9c
title: Move the root design notes out of sight
priority: 3
labels:
- move-root-design-notes
deps: []
closed: false
---
Three working-note documents sit at the root of this repository and would be
the first three files a visitor sees beside `CLAUDE.md`. They are lab notebooks
of the kind this project's own comment rules exclude, and one of them opens by
stating something that is no longer true.

Touches: naming.md, generating-idea-names.md, convergence-bug.md

## What the three files are

- **`naming.md`** (184 lines) — opens with "> **Superseded.** This describes
  the container-ordinal scheme `@rookery/core` used before an unnamed note's id
  became a pure function of its own content." It is, by its own first line, a
  record of a scheme that is gone.
- **`generating-idea-names.md`** (250 lines) — describes the naming algorithm
  actually in use. This one is a real design document and its content is
  current.
- **`convergence-bug.md`** (237 lines) — "Working notes, 20 September 2026",
  about why `waterline` stopped building. It states "**Status:** ... The site
  still does not build." **That status is stale**: `waterline`'s rookery project
  at `/home/lox/code/waterline/rookery` now compiles cleanly, producing 798
  pages. The document describes a resolved incident.

## What to do

Move the design material somewhere a visitor is not confronted with it, and
delete what is finished.

1. Create the directory `docs/design/` at the repository root.

2. Move `generating-idea-names.md` into it, unchanged:

   ```
   mkdir -p /home/lox/code/_fcl/rookery/docs/design
   mv /home/lox/code/_fcl/rookery/generating-idea-names.md /home/lox/code/_fcl/rookery/docs/design/
   ```

3. Delete `naming.md`. It documents a scheme the package does not use, and
   `generating-idea-names.md` already explains the algorithm that replaced it:

   ```
   rm /home/lox/code/_fcl/rookery/naming.md
   ```

   Before deleting, check whether `generating-idea-names.md` refers to it.
   Anchor:

   ```
   rg -n 'naming\.md' /home/lox/code/_fcl/rookery --glob '!.birds/**'
   ```

   Two hits as of filing, both inside the two documents themselves. If
   `generating-idea-names.md` points at `naming.md` for the superseded scheme,
   delete that cross-reference sentence rather than leaving a dangling pointer.

4. Delete `convergence-bug.md`. The incident is closed and the document's own
   status line is wrong:

   ```
   rm /home/lox/code/_fcl/rookery/convergence-bug.md
   ```

   Same check first — if `generating-idea-names.md` refers to it (it does, in
   its opening paragraph: "answers the failure recorded in
   `convergence-bug.md`"), rewrite that sentence so it stands on its own without
   the pointer. Anchor:

   ```
   rg -n 'convergence-bug' /home/lox/code/_fcl/rookery --glob '!.birds/**'
   ```

5. Write a short `docs/design/readme.md`, three or four sentences, saying what
   the directory is: design notes about how parts of `@rookery/core` work, kept
   beside the code rather than in the package readme because they are longer
   than a package reader needs. List what is in it.

## Non-goals

- Do NOT rewrite the content of `generating-idea-names.md` beyond removing
  pointers to the two deleted files. Its description of the naming algorithm is
  current and correct.
- Do NOT move `CLAUDE.md`, `Justfile`, `flake.nix`, `flake.lock`, or anything
  else at the repository root.
- Do NOT create a `docs/` structure beyond `docs/design/`.
- Do NOT go looking for other documents to move. These three are the ones at the
  repository root; that is the whole scope.

## VERIFY

1. `ls /home/lox/code/_fcl/rookery/*.md` prints only `CLAUDE.md`.
2. `ls /home/lox/code/_fcl/rookery/docs/design/` prints
   `generating-idea-names.md` and `readme.md`.
3. `rg -n 'convergence-bug|naming\.md' /home/lox/code/_fcl/rookery/docs`
   prints nothing.
4. From `core/0.1.0`, `just test` passes (prints `units OK`) — nothing this bird
   touches is reachable from the package, and this confirms it.