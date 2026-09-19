---
id: rk-document-core-s-package-extension-f7ae4796
short-id: f7a
title: Document core's package extension surface
priority: 2
labels:
- docs-core-extension-surface
deps:
- blocked-by:rk-rename-core-s-four-off-pattern-accessors-34feb9e6
closed: false
---
Touches: core/0.1.0/readme.md

`@rookery/core` exports 23 public names. Three of them are the extension surface every other
package in this repo is built on, and the readme documents none of it — while eight packages
reverse-engineer it from the source.

Two gaps, both real:

1. **`idea-row` and `idea-row-body` appear nowhere in the readme**, and three packages import
   them by name: `search/0.1.0/src/filter-panel.typ` line 22,
   `timeline/0.1.0/src/upcoming.typ` line 52, `todos/0.1.0/src/table.typ` line 30 (as of
   filing). A public API with three consumers and no documentation is the worst of both — it
   cannot be changed safely and cannot be used without reading `row.typ`.
2. **`WK` and `FNK` appear nowhere, and `IK` appears once in passing** (readme line 2685 as of
   filing, inside the Limitations section). They are the figure/label kinds this package marks
   its own output with, and `@rookery/slipshow` already walks for one: its comments at
   `src/select.typ` line 18 and `src/marker.typ` line 8 both name `figure(kind: IK)` as the
   thing they cannot or must walk.

There is also an unwritten convention — the **skin** — that two packages follow by imitation.
`@rookery/timeline` overrides `idea` (`src/lib.typ` line 99 as of filing) to add its dated
arguments; `@rookery/todos` overrides `window` (`src/skin.typ` line 41) to hide closed todos.
Both re-export everything else untouched, and `todos` deliberately imports the timeline skin
rather than core so the decoration composes. That reasoning is written in
`todos/0.1.0/src/skin.typ`'s header and nowhere a package author would look first.

This bird is DOCUMENTATION ONLY. No source file changes, no renames, no behaviour.

## Steps

1. **Add one new readme section**, titled `## Building a package on core`, placed between the
   existing `## Standalone note pages (rheo only)` and `## Limitations` sections. Find the
   boundary:

   ```
   rg -n '^## Limitations' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   One hit as of filing, line 2647. The new section goes immediately above it. Match the
   readme's existing register: prose, present tense, worked examples in fenced `typst` blocks,
   no change-narration and no issue ids.

2. **Document the row shape** in that section. Read the two functions first:

   ```
   rg -n 'let idea-row-body|let idea-row' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   Two hits as of filing, `row.typ` lines 59 and 149; each carries a full doc comment above it
   — `idea-row` is described there as "ONE ROW SHAPE for every list of notes: when, title,
   cells and badges". Write from those comments, not from invention. Cover: what the two
   functions emit, the difference between them (`idea-row-body` is the row's children without
   the `<li>` around them, for a caller building its own list container), and their parameters
   at the level of what each is for. Name the three packages that use them as the worked
   evidence that this is the supported shape for a list of ideas.

3. **Document the three marker constants** in the same section: `IK` for an idea, `WK` for a
   window, `FNK` for a footnote. Find their definitions and say what each actually marks:

   ```
   rg -n 'let IK |let WK |let FNK ' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   Three hits as of filing, `pure.typ` lines 567, 568 and 589 — `IK` and `WK` are figure
   `kind` strings, `FNK` is a label, and the comments around them say what claims each. State
   the one thing a package author needs: these are how rookery's own output is recognised when
   walking rendered content, which is what `@rookery/slipshow` does to find the ideas in a
   body. Keep the existing mention at line 2685 in Limitations where it is; this is the
   reference entry it currently lacks.

4. **Write the skin contract** as the last part of the section. State it as a rule, with the
   two existing skins as the examples:

   - A skin imports its PARENT skin, not core, when one exists — `todos` imports
     `@rookery/timeline`, so an idea written through todos takes timeline's dated arguments as
     well as todos' own. Importing core there would silently drop them.
   - A skin overrides a name by re-exporting its own binding of it, and forwards everything it
     does not consume through `..args`.
   - A skin must not change what the name it overrides means, only what it can additionally be
     told: `timeline`'s `idea` is still `#idea`, `todos`' `window` is still `#window`.

   Read `todos/0.1.0/src/skin.typ` lines 1-18 (as of filing) before writing this — the
   reasoning is already stated well there, and the readme entry should agree with it rather
   than invent a second account. Do not copy it verbatim; the readme speaks to a package author
   who has not opened that file.

5. **Check nothing else in the readme contradicts the new section.** In particular, the
   Limitations mention of `figure(kind: IK)`:

   ```
   rg -n 'figure\(kind: IK\)' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   One hit as of filing, line 2685. Leave the claim alone; if it now duplicates a sentence in
   the new section, cut the duplicate from the NEW section, not from Limitations.

## Non-goals

- **Change no source file.** Not `row.typ`, not `pure.typ`, not any package. If writing the
  documentation turns up a bug or an awkward signature, report it — do not fix it here.
- **Do not make `IK`, `WK` or `FNK` private.** Documenting them is this bird's answer to their
  being public; renaming them to `_IK` and friends would touch a dozen call sites across core
  and break `@rookery/slipshow`'s ability to reason about them.
- **Do not document the private `_`-prefixed names**, including the 33 that
  `core/0.1.0/.marrow.typ` imports. Those are internal by construction and the readme should
  not promise them.
- **Do not restructure the readme.** One new section in the named position; leave the ordering,
  the headings and the existing prose alone.
- **Do not write a migration note.** Nothing changed for a reader upgrading.

## VERIFY

1. `rg -n '^## Building a package on core' core/0.1.0/readme.md` returns exactly one hit, and
   `rg -n '^## Limitations' core/0.1.0/readme.md` returns one hit at a LARGER line number.
2. `rg -n 'idea-row-body' core/0.1.0/readme.md` returns at least one hit, and so does
   `rg -n '\bWK\b' core/0.1.0/readme.md` and `rg -n '\bFNK\b' core/0.1.0/readme.md` — all three
   were absent before this bird.
3. The section names all three packages that consume the row shape: `rg -n 'search|timeline|todos' core/0.1.0/readme.md`
   returns hits inside the new section's line range.
4. `cd core/0.1.0 && just test` — prints `units OK`. (Nothing should have changed, and this is
   the check that nothing did.)
5. `bd status <this bird's id>` reports `retired` after the flight lands.