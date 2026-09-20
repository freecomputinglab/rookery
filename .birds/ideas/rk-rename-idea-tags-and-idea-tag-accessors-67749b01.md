---
id: rk-rename-idea-tags-and-idea-tag-accessors-67749b01
short-id: '677'
title: Rename idea-tags and idea-tag accessors
priority: 3
labels:
- fix-idea-tag-accessor-names
deps: []
closed: true
---
Touches: core/0.1.0/src/idea.typ, core/0.1.0/src/data.typ, core/0.1.0/src/window.typ, core/0.1.0/src/state.typ, core/0.1.0/readme.md, core/0.1.0/demo/pure/theme.typ, core/0.1.0/demo/rheo/content/tags.typ, todos/0.1.0/src/skin.typ, todos/0.1.0/src/graph.typ, cfps/0.1.0/test/units.typ, search/0.1.0/src/lookup.typ

Two of core's public tag accessors are named for what they are *about* rather than
what they *return*, and both under-promise silently:

- `idea-tags(name)` returns the tag NAMES only — a flat array of keys. But a tag in
  rookery is a key/value pair, so a caller reaching for "this idea's tags" gets the
  keys and loses every value with no error at all.
- `idea-tag(name, key)` returns a tag's VALUE, not a tag. The name also hides the
  documented trap that a plain tag's value is `none`, indistinguishable from an
  absent key.

Rename them to say what they return:

| now | after |
| --- | --- |
| `idea-tags(name)` | `idea-tag-names(name)` |
| `idea-tag(name, key, default: none)` | `idea-tag-value(name, key, default: none)` |

This is partly a regression being caught. `readme.md`'s own migration table records
that these were once `tags-of` and **`tag-value`**; the earlier rename onto the
`idea-` prefix dropped the word "value" and bought a one-character difference
between two functions that do categorically different things.

Rename BOTH or neither. The pair `-names` against `-value` is what makes the
distinction legible; renaming one alone leaves the asymmetry worse than it is now.

## Scope: 57 sites, one landing

Every site must change in ONE flight. `todos/0.1.0/src/skin.typ` and
`cfps/0.1.0/test/units.typ` call these functions, so core renaming alone leaves the
repo not compiling. Do not split this.

Most sites are prose cross-references inside doc comments, not code. They count:
this package's comments are its design documentation, and a comment naming a
function that no longer exists is a defect.

## CRITICAL — what is NOT being renamed

The CSS class `idea-tag` and the per-tag class `idea-tag-<tag>` are a DIFFERENT
thing that merely shares a spelling. Leave every one of these exactly as they are:

- the class names `idea-tag`, `idea-tag-<tag>`, `idea-outline-row idea-tag-todo`
- the custom properties `--idea-tag-size`, `--idea-tag-bg`, `--idea-tag-line`,
  `--idea-tag-color`, `--idea-tag-radius`
- the attribute `data-rookery-tags`
- the expression `_c("tag-" + ...)` which builds those classes

They appear throughout `row.typ`, `theme.typ`, `template.typ`, `permalink.typ`,
`outline.typ`, `state.typ`, `transclusion.typ`, every `check.sh`, the readme's CSS
sections, and all of `meetings/`, `bibtex/`, `slipshow/`, `timeline/`, `pinboard/`.
A rename that catches them breaks the stylesheet silently — nothing will fail to
compile.

The reliable discriminator: a FUNCTION site is `idea-tag` or `idea-tags` followed by
`(`, or the bare name inside backticks in prose that is talking about calling it. A
CSS site is followed by `-<something>`, or sits inside a class/selector/property
string.

## Steps

1. In `core/0.1.0/src/idea.typ`, rename the two definitions.
   - Anchor: `rg -n '#let idea-tags\(name\)' /home/lox/code/_fcl/rookery/core`
     → one hit, `core/0.1.0/src/idea.typ` (line 601 at filing), landmark: the
     `#idea-tags / #idea-tag — reading an idea's tags` banner comment.
     Becomes `#let idea-tag-names(name) = {`.
   - Anchor: `rg -n '#let idea-tag\(name, key' /home/lox/code/_fcl/rookery/core`
     → one hit, same file (line 621 at filing), landmark: the `One tag's VALUE on one
     note:` comment directly above it.
     Becomes `#let idea-tag-value(name, key, default: none) = {`.
   - Then fix the nine doc-comment references in the same file: the section banner
     (`idea-tags / #idea-tag — reading`), the usage examples
     (`idea-tags("etal")   // -> ("note"`, `idea-tag("etal", "priority")`,
     `idea-tag("etal", "nope", default: 4)`), and the prose cross-references
     (``idea-tag` below fetches one`, `Takes the same name forms `idea-tags` takes`,
     `for the same reason it is not one in `idea-tags``, `Ask `idea-tags` (or
     `tag-data`)`, `same as `idea-tags``).

2. Fix the prose cross-references in the other three core source files.
   - `core/0.1.0/src/data.typ` — five sites. Anchors:
     ``#idea-tags(name)` exposes ONE`, `the cheap one: `idea-tags` resolves`,
     `idea-tags(e.name))` works and is VERIFIED`, ``idea-tags`/`idea-tag` each
     resolve`, `noted against `idea-tags` further up`.
   - `core/0.1.0/src/window.typ` — one site, anchor
     `unlike `idea-tags`/`idea-tag`/`ideas`/`tag-data``. Both names on one line.
   - `core/0.1.0/src/state.typ` — one site, anchor
     `must not: `idea-tags`, `idea-tag`, `tag-data``. Both names on one line.
     Take care here: `state.typ` is FULL of the CSS-class spelling. Only this one
     line is a function reference.

3. `core/0.1.0/src/lib.typ` needs NO edit. It re-exports through
   `#import "idea.typ": *`, a wildcard, so both new names are exported the moment
   step 1 lands. Confirm rather than assume:
   `rg -n 'idea-tag' /home/lox/code/_fcl/rookery/core/0.1.0/src/lib.typ`
   → expected to print nothing.

4. Update the two demos, each of which carries an explicit named-import list.
   - `core/0.1.0/demo/rheo/content/tags.typ` — the import at the top, anchor
     `idea-tag, idea-tags, window`, plus seven `#repr(idea-tags("…"))` calls and
     three `#repr(idea-tag("tag-valued", …))` calls.
   - `core/0.1.0/demo/pure/theme.typ` — the import, anchor
     `idea, window, hyperlink, idea-tags, ideas-outline`; one call, anchor
     `Et al.'s tags: #repr(idea-tags("etal"))`; one prose line, anchor
     `#idea-tags/#ideas-outline all reading`.

5. Update `core/0.1.0/readme.md` — fourteen sites, all prose, fenced examples, or
   the migration table. Anchors: ``#ideas().tags` and `#idea-tags()``,
   ``#idea-tags()` below asks`, ``#context idea-tags(name)` gives the note`,
   `#context idea-tags("y")`, ``#context idea-tag(name, key, default: none)` gives
   ONE`, `#context idea-tag("ship-it", "priority")`,
   `#context idea-tag("ship-it", "nope", default: 4)`, `ask `idea-tags` when the
   question is presence`, `the corpus: `idea-tags` and `idea-tag``,
   `It does NOT touch filtering. `#idea-tags`, `#idea-tag`, `#tag-data``,
   `#context idea-tags("etal")`, `#context idea-tag("etal", "priority")`.

   The migration table near line 148 is two rows mapping the OLD names to the
   current ones. Anchors ``tags-of(name)`` and ``tag-value(name, key, default:
   none)``. Update the right-hand column of each to the new name — keep the
   left-hand column as it is, since that column is the historical name and does not
   change. Do NOT touch the readme's CSS sections (roughly lines 1834–2030, plus
   453, 1211, 2657), which are the class-name spelling.

6. Update the two downstream call sites and their prose.
   - `todos/0.1.0/src/skin.typ` — the import, anchor
     `#import "@rookery/core:0.1.0": idea-tags`; the live call, anchor
     `if CLOSED-KEY in idea-tags(pos.at(0))`; two prose lines, anchors
     ``idea-tags` takes the same name forms `#window`` and ``idea-tags` returns tag
     NAMES, not the tag dictionary`.
   - `cfps/0.1.0/test/units.typ` — the import, anchor
     `rookery, tag-data, idea-tags`; the assertion, anchor
     `assert.eq(idea-tags("units-venue-auto")`.

7. Update the remaining prose-only cross-references in two more packages.
   - `todos/0.1.0/src/graph.typ` — four sites, anchors
     `Reaching for `idea-tags` or`, ``idea-tag` per row instead would pay`,
     `documents explicitly against `idea-tags``, ``idea-tags`, where an unknown id
     answers emptily`.
   - `search/0.1.0/src/lookup.typ` — one site, anchor `here and `idea-tags` is`.
     This comment explains that the function is deliberately NOT imported; keep that
     meaning, just rename.

## Non-goals — do NOT do these

- **Do not rename the `tags` field on an `#ideas()` row.** It is also names-only and
  therefore has the same imprecision, and it still keeps its name. `data.typ` marks
  it a contract `@rookery/search` reads directly in its `corpus.typ` and `rank.typ`,
  where it is put into a JSON index and `.map`ped; changing it is a breaking change
  to a different package's parsing. It is acceptable that the accessor now says
  `tag-names` while the row field beside it says `tags`.
- **Do not rename `tag-data()` or `tag-index()`.** They are correct already.
- **Do not add back-compat aliases.** The package is pre-release `0.x`; an alias
  that keeps `idea-tags` working would defeat the point of the rename and would have
  to be deprecated later.
- **Do not touch any CSS class, custom property or selector.** See the CRITICAL
  section above.
- **Do not edit `.birds/ideas/*.md`.** Several of those tracker documents describe
  the EARLIER `tags-of` → `idea-tags` rename. They are historical records of what
  was done at the time and are correct as written.
- **Do not change behaviour.** Signatures, return values, the `default:` parameter
  and the `#context` requirement are all unchanged. This is a rename only.

## VERIFY

1. Both new names exist and neither old one does, as a function:

   ```bash
   rg -n '#let idea-tag-names\(|#let idea-tag-value\(' /home/lox/code/_fcl/rookery/core
   rg -n 'idea-tags?\(' /home/lox/code/_fcl/rookery
   ```

   The first prints two lines. The second prints NOTHING — no call, anywhere, to
   either old name.

2. The CSS classes are untouched. This count must be unchanged by your work:

   ```bash
   rg -c 'idea-tag-' /home/lox/code/_fcl/rookery/core/0.1.0/src/core.css
   ```

3. Core's own tests pass:

   ```bash
   cd /home/lox/code/_fcl/rookery/core/0.1.0 && just test
   ```

4. Both downstream packages still build and test:

   ```bash
   cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just check
   cd /home/lox/code/_fcl/rookery/cfps/0.1.0 && just test
   ```

5. The readme documents the new names rather than the old:

   ```bash
   rg -n 'idea-tag-names|idea-tag-value' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   Prints several hits, including the two migration-table rows.