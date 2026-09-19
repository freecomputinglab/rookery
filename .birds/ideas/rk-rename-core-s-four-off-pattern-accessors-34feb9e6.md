---
id: rk-rename-core-s-four-off-pattern-accessors-34feb9e6
short-id: 34f
title: Rename core's four off-pattern accessors
priority: 2
labels:
- feat-idea-accessor-names
deps:
- blocked-by:rk-add-filter-and-sort-to-window-and-ideas-743f0195
closed: false
---
Touches: core/0.1.0/src/idea.typ, core/0.1.0/src/urls.typ, core/0.1.0/src/data.typ, core/0.1.0/readme.md, core/0.1.0/demo/pure/theme.typ, core/0.1.0/demo/rheo/content/tags.typ, todos/0.1.0/src/skin.typ, todos/0.1.0/src/graph.typ, search/0.1.0/src/lib.typ, search/0.1.0/src/corpus.typ, search/0.1.0/readme.md, cfps/0.1.0/test/units.typ, CLAUDE.md

Four public names in `@rookery/core` are spelled against the grain of the rest of the API.

**`note-href` and `note-path` say "note" where everything else says "idea".** The package's
vocabulary is settled everywhere else: `#idea`, `ideas()`, `idea-body`, `idea-row`, the
`idea:<name>` label prefix, the `.idea-*` CSS classes. These two are the last pair using the
older word for the same thing.

**`tags-of` reads as the family's `-of` accessor and is not one.** Across `timeline`, `todos`,
`meetings`, `slipshow` and `cfps` there are two dozen `-of` functions and every one of them
takes a TAG DICTIONARY and pulls a field out of it: `deadline-of(tags)`, `priority-of(tags)`,
`enter-of(tags)`. Core's `tags-of(name)` takes an idea NAME and hits the registry — the same
suffix for a different kind of argument, and core is the minority spelling. `todos` has even
had to define a private `_tags-of` of its own (`todos/0.1.0/src/table.typ` line 135 as of
filing) that behaves the family way, next to an import of core's that does not.

Rename the four:

| now | becomes |
| --- | --- |
| `tags-of(name)` | `idea-tags(name)` |
| `tag-value(name, key, default: none)` | `idea-tag(name, key, default: none)` |
| `note-href(name)` | `idea-href(name)` |
| `note-path(name)` | `idea-path(name)` |

`idea-tags` and `idea-tag` differ by one character, which is deliberate: it is the same
singular/plural distinction the package already teaches with `idea` and `ideas()`, one idea's
tag names against one tag's value. Document them adjacently so the pair is read together.

**`tag-data()` is NOT renamed, and that is a decision rather than an omission.** The obvious
parallel with `ideas()` would be a bare `tags()`, and it cannot be had: `tags` is a parameter
name on `#idea`, `#window`, `ideas()`, `#ideate` and most of the family's constructors, so
inside any of those bodies the parameter would shadow the function. Record that reason in a
comment on `tag-data` so nobody re-proposes it.

## Steps

1. **Rename `tags-of`.** Find it:

   ```
   rg -n 'let tags-of' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   One hit as of filing, `idea.typ` line 567. Rename the binding to `idea-tags`, keeping its
   parameter and body untouched. Update its own doc comment, including any sentence that names
   the old spelling.

2. **Rename `tag-value`.** Find it:

   ```
   rg -n 'let tag-value' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   One hit as of filing, `idea.typ` line 587, directly below the previous one. Rename to
   `idea-tag`. Its comment refers the reader to `tags-of` and `tag-data` for the
   presence-versus-value distinction — update the first of those names and leave the second.

3. **Rename `note-href` and `note-path`.** Find them:

   ```
   rg -n 'let note-href|let note-path' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   Two hits as of filing, `urls.typ` lines 123 and 142. Rename to `idea-href` and `idea-path`.
   **The private helpers keep their names**: `_note-href` and the rest of that file's
   underscore-prefixed internals are not part of this rename, and `urls.typ`'s header comment
   explains the public/private split — leave that structure exactly as it is. Update the two
   public functions' own comments, including the worked example at line 111 as of filing
   (`#context note-href("etal")`).

4. **Record why `tag-data` stays.** Find it:

   ```
   rg -n 'let tag-data' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   One hit as of filing, `data.typ` line 380. Add two sentences to its comment: the bulk reader
   would be `tags()` by parallel with `ideas()`, and that name is refused because `tags` is a
   parameter name throughout this package and the parameter would shadow the function inside
   every body that has one.

5. **Fix core's remaining internal mentions.** Two comments in `data.typ` name `tags-of`:

   ```
   rg -n 'tags-of' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   As of filing this returns the definition from step 1 plus `data.typ` lines 211 and 240, both
   prose in comments. Update every hit outside the private `_`-prefixed names.

6. **Update the core demos.** They call the renamed functions directly:

   ```
   rg -n '\btags-of\(|\btag-value\(' /home/lox/code/_fcl/rookery/core/0.1.0/demo
   ```

   Nine hits as of filing: `demo/pure/theme.typ` line 26, and `demo/rheo/content/tags.typ`
   lines 22, 23, 64, 65, 66, 67, 117, 118, 119 and 142. Rename each call. Surrounding prose in
   those files that names the function — `tags.typ` is a demo page whose visible text discusses
   them — must be updated too, since it is rendered output a reader sees.

7. **Update `@rookery/todos`.** It imports core's by name:

   ```
   rg -n '\btags-of' /home/lox/code/_fcl/rookery/todos
   ```

   As of filing: `src/skin.typ` line 21 (the import), line 48 (a comment) and line 57 (the
   call); `src/graph.typ` lines 22, 24 and 70 (comments). Rename all of them. **Do NOT touch
   `src/table.typ`'s `_tags-of`** (line 135 as of filing and its call sites at 452 and 671):
   that is todos' own private helper over a tag dictionary, unrelated to the function being
   renamed, and it keeps its name.

8. **Update `@rookery/search`.** It imports `note-href` by name:

   ```
   rg -n 'note-href' /home/lox/code/_fcl/rookery/search
   ```

   Four hits as of filing: `src/lib.typ` line 25 (the import) and line 4 (a comment), plus
   `src/corpus.typ` lines 262 and 273 (comments, the second naming core's private `_note-href`
   — that one keeps its name), and `readme.md` line 58. Rename the public spellings, leave the
   private one.

9. **Update `@rookery/cfps`' test.** One assertion calls the renamed function:

   ```
   rg -n 'tags-of' /home/lox/code/_fcl/rookery/cfps
   ```

   One hit as of filing, `test/units.typ` line 127. Rename the call.

10. **Update the repo's own `CLAUDE.md`.** It names the primitive in its description of
    `search`:

    ```
    rg -n 'note-href' /home/lox/code/_fcl/rookery/CLAUDE.md
    ```

    One hit as of filing, line 26. Change only that name; alter nothing else in that file.

11. **Update the readme, and give it a migration entry.** The core readme names these four
    across roughly two dozen lines:

    ```
    rg -n '\btags-of|\btag-value|\bnote-href|\bnote-path' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
    ```

    Rename every one, then add a row per rename to the readme's existing migration section —
    find it with `rg -n 'is now .created.' core/0.1.0/readme.md` (one hit, line 110 as of
    filing, the `minted` → `created` note). That section is the one place where the OLD names
    are written on purpose; everywhere else they must be gone.

## Non-goals

- **Do not rename `tag-data`, `tag-index`, `ideas`, `idea-body`, `idea-row` or `idea-row-body`.**
  Only the four in the table.
- **Do not rename any private `_`-prefixed helper**, in core or in any other package. `_note-href`
  (core), `_tags-of` (todos) and their neighbours keep their names.
- **Do not keep the old names as aliases.** One spelling each. A stale call site should fail,
  and it will: these are plain `#let` bindings, so Typst reports an unknown variable.
- **Do not change any function's parameters, defaults or behaviour.** This bird moves names and
  nothing else — a renamed function must return exactly what it returned before.
- **Do not edit another repo.** See the heads-up below.

## VERIFY

1. `cd core/0.1.0 && just test` — prints `units OK`.
2. `cd core/0.1.0/demo/pure && just build` — succeeds.
3. `cd core/0.1.0/demo/rheo && just check` — succeeds. (Needs the `rheo` binary, present at
   `~/.cargo/bin/rheo` when this bird was filed; if it is genuinely missing, say so in the
   report rather than skipping quietly.)
4. `cd cfps/0.1.0 && just test` — succeeds, with the renamed assertion. If that package has no
   `test` recipe, run its `Justfile`'s default and say which recipe you ran.
5. `rg -n '\btags-of\(|\btag-value\(|\bnote-href\(|\bnote-path\(' .` from the repo root returns
   NOTHING outside `.birds/` and outside the readme's migration section. (The leading `\b`
   means todos' `_tags-of(` and core's `_note-href(` correctly do not match.)
6. `bd status <this bird's id>` reports `retired` after the flight lands.

## Heads-up, out of scope for this flight

`rookery.ohrg.org` — a SEPARATE repo at `/home/lox/code/_fcl/rookery.ohrg.org`, not this one —
documents and may call these names. Do not edit it from this flight; report this line with the
landing so the operator can sequence the site's update.