---
id: rk-correct-the-rheo-floor-in-core-s-readme-13d996a8
short-id: '13'
title: Correct the rheo floor in core's readme
priority: 4
labels:
- fix-rheo-version-floor
deps:
- blocked-by:rk-rename-note-dir-to-idea-dir-79af1377
closed: true
---
`core/0.1.0/typst.toml` and `core/0.1.0/readme.md` disagree about the minimum
rheo version, and the readme is the one that is wrong. A reader who follows it
onto rheo 0.5.2 gets a build that succeeds, warns about nothing, and mints none
of the standalone idea pages the package's headline feature depends on.

Touches: core/0.1.0/readme.md

## The facts, already established — do not re-derive them

`core/0.1.0/typst.toml` declares `min_version = "0.6.2"` under `[tool.rheo]`,
and the comment block above that line gives the full reasoning across three
raises:

- **0.6.0** — rheo rewrites the reserved `rheo-page:<handle>` link destination
  that `src/urls.typ` emits for every idea link. An older rheo passes it through
  untouched and ships a literal `href="rheo-page:ideas:<slug>"`, a silent
  site-wide dead-link failure.
- **0.6.1** — where rheo learned to resolve a namespace it does not ship, via
  the `[packages.<ns>]` table a project needs in order to say where `@rookery`
  comes from at all. `[tool.rheo.source.html]` is also a 0.6.1 manifest key.
- **0.6.2** — 0.6.1 located packages by probing Typst's directory layout in the
  two places that read a package's `.marrow.typ`, and a package fetched from a
  remote ref lives at a path keyed by its resolved commit, which no probe
  matches. Every page this family mints from marrow therefore went missing, on a
  build that succeeded and warned about nothing.

**0.6.2 is correct. The readme's 0.5.2 is stale.** Do not change `typst.toml`.

## Steps

1. Fix the Requirements bullet. Anchor — this fragment has two hits in the
   readme; this step is about the one in the `## Requirements` section (line
   3069 as of filing), the bullet beginning "- rheo >= 0.5.2 — but only if you
   build with rheo at all":

   ```
   rg -n 'rheo >= 0\.5\.2' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   Rewrite that bullet to name **0.6.2** as the floor and to give the reason in
   one or two sentences, drawn from the three bullets above. The essential point
   for a reader is that an older rheo does not complain: it mints nothing and
   leaves every idea link pointing at a page that was never written.

2. Delete the `OBSERVED (rheo 0.5.2, ...)` paragraph that follows that bullet.
   Anchor — one hit, in `core/0.1.0/readme.md` (line 3077 as of filing), inside
   the same `## Requirements` section:

   ```
   rg -n 'OBSERVED \(rheo 0\.5\.2' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   The whole paragraph is a measurement of a version that is no longer the
   floor, and it makes a promise ("the version this line promises is the version
   actually tested") that is now false. This anchor stops matching once the step
   lands, which is why it does not appear in VERIFY.

3. Fix the second mention. Anchor — the other hit from step 1's search (line
   2635 as of filing), in the `## Standalone note pages (rheo only)` section,
   the sentence beginning "This is the part that needs". Change
   `**rheo >= 0.5.2**` to `**rheo >= 0.6.2**` there too.

4. Confirm no mention of 0.5.2 survives:

   ```
   rg -n '0\.5\.2' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   This must print nothing.

## Non-goals

- Do NOT edit `core/0.1.0/typst.toml`. Its `min_version = "0.6.2"` is correct
  and its comment block is the source of truth this bird copies from.
- Do NOT change the typst version requirement (`typst >= 0.15`) or the
  `--features html` bullet in the same section. Both are correct.
- Do NOT touch any other section of the readme. Other stale version prose in
  this file is a separate bird.

## VERIFY

1. `rg -n '0\.5\.2' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md` prints
   nothing.
2. `rg -n '0\.6\.2' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md` prints at
   least two hits.
3. `rg -n 'min_version = "0.6.2"' /home/lox/code/_fcl/rookery/core/0.1.0/typst.toml`
   still prints one hit — the manifest is unchanged.