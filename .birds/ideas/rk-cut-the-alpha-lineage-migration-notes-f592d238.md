---
id: rk-cut-the-alpha-lineage-migration-notes-f592d238
short-id: f59
title: Cut the alpha-lineage migration notes
priority: 3
labels:
- trim-core-readme
deps:
- blocked-by:rk-correct-the-rheo-floor-in-core-s-readme-13d996a8
closed: false
---
`core/0.1.0/readme.md` is the front door of a package about to be published for
the first time, and it opens with 165 lines of migration guidance away from an
alpha lineage that — by the readme's own admission — "nothing was published
from it that anybody but this machine's own four sites ever installed". A first
reader has nothing to migrate from. Scattered through the rest of the file are
further references to versions that no longer exist and to a label prefix the
package no longer uses.

Cut the migration material and correct the stale references. The reference
material about how the package works stays.

Touches: core/0.1.0/readme.md

## Part one: the migration section

Anchor — one hit, in `core/0.1.0/readme.md` (line 73 as of filing), a top-level
heading:

```
rg -n '^## 0\.1\.0$' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
```

The section runs from that heading to the next top-level heading, which is:

```
rg -n '^## Setup, and the' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
```

One hit, line 240 as of filing. Everything between them — the `## 0.1.0`
section and its `### Migrating from the alpha lineage`, `### Migrating from
`show-*` arguments`, `### Migrating from `#ideate-id``, `### Migrating from
`display-id:`` and `### Migrating from `id-color`` subsections — is migration
guidance from versions that were never published.

**Replace the whole span with a short `## 0.1.0` section**, three or four
sentences, keeping only the two facts a new reader actually needs:

1. This is the first release of `@rookery/core`.
2. The `@rookery` packages are version-aligned and should be installed as one
   family, because the idea registry's state key is not versioned, so two
   packages disagreeing about the record shape fail at compile time.

Do NOT keep the paragraph about the retired alpha lineage. A reader who never
had it does not need to be told it existed.

**One correction while you are there:** the existing text names three sibling
packages ("`@rookery/search`, `@rookery/timeline` and `@rookery/todos`"). The
repository holds eight siblings. Check and name them from the directory
listing rather than copying the old list:

```
ls -d /home/lox/code/_fcl/rookery/*/0.1.0 | xargs -n1 dirname | xargs -n1 basename
```

## Part two: the stale references elsewhere in the file

Each of these is a separate small edit. Run the search, then fix each hit in
place.

1. **The retired `@note:` label prefix.** The package's prefix is `idea:`, so
   every reference example in the readme should read `@idea:etal`:

   ```
   rg -n '@note:' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   Four hits as of filing (lines 266, 275, 277, 3073).

2. **Prose about versions that no longer exist.** Each of these describes what
   some pre-release version did, which is the lab-notebook register this
   project's `CLAUDE.md` excludes — a comment or a line of documentation
   describes the present:

   ```
   rg -n 'Migrating from 0\.4\.1|Was .minted. before|as of 0\.5\.0|exactly as in 0\.5\.0|Until 0\.6\.0' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   Five hits as of filing (lines 1492, 1575, 2015, 2418, 2479). In each case
   keep the **present-tense claim** and drop the version clause. For example
   "There is ONE date, and it is `created`" stands on its own; "Until 0.6.0
   there were two" does not belong in a first release's documentation. Where
   removing the clause would leave a sentence saying nothing, remove the
   sentence.

3. **A path into a version directory that does not exist.** Anchor — one hit,
   in `core/0.1.0/readme.md` (line 2756 as of filing), in the
   `### Giving minted pages your own chrome` section:

   ```
   rg -n 'rookery/0\.6\.0/demo' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   The real path is under `core/0.1.0/demo/rheo/content/lib.typ`. Confirm the
   file exists before rewriting the reference:

   ```
   ls /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo/content/lib.typ
   ```

4. **The wrong namespace in the local-development section.** Anchor — one hit,
   in `core/0.1.0/readme.md` (line 3107 as of filing), in the
   `## Build and local development` section, a sentence ending "symlinked into
   the package cache as the `rheo` namespace":

   ```
   rg -n 'as the .rheo. namespace' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   The namespace is `rookery`, not `rheo` — the same section's own `ln -s`
   example writes into `~/.cache/typst/packages/rookery/core/`. Fix the
   sentence to say `rookery`.

## Non-goals

- Do NOT touch the `## Requirements` section or any mention of rheo 0.5.2 /
  0.6.2 in it. A separate bird owns that, and it may already have landed.
- Do NOT rewrite, restructure, or shorten any of the reference sections that
  explain how the package works (`The display: dictionary`, `#ideate`,
  `Referencing a note`, `Tags`, `Bibliographies`, and so on). This bird removes
  migration material and corrects stale facts; it is not a readme rewrite.
- Do NOT rename `note-dir`. A separate bird owns that.
- Do NOT change any code under `src/`.

## VERIFY

1. `rg -n '^### Migrating from' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md`
   prints nothing.
2. `rg -n '@note:' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md` prints
   nothing.
3. `rg -n 'rookery/0\.6\.0/' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md`
   prints nothing.
4. `rg -n '^## 0\.1\.0$' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md` still
   prints one hit — the section exists, just much shorter.
5. `rg -n 'rookery. namespace' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md`
   prints one hit.