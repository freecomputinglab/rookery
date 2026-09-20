---
id: rk-select-with-tagged-assign-with-tags-d385cd88
short-id: d38
title: Select with tagged, assign with tags
priority: 3
labels:
- feat-tagged-selection
deps:
- blocked-by:rk-rename-the-transclusion-budget-to-unfurl-1df95783
closed: true
---
Touches: core/0.1.0/src/window.typ, core/0.1.0/src/data.typ, core/0.1.0/src/outline.typ, core/0.1.0/readme.md, core/0.1.0/demo/rheo/content/tags.typ, core/0.1.0/demo/rheo/content/relations.typ, core/0.1.0/demo/rheo/content/sub/deeper/page.typ, core/0.1.0/demo/rheo/check.sh, search/0.1.0/src/lookup.typ, search/0.1.0/src/filter-panel.typ, timeline/0.1.0/src/upcoming.typ, cfps/0.1.0/src/panel.typ

`tags:` does two opposite jobs in `@rookery/core`, and nothing in the API says which one a
reader is looking at:

- **It ASSIGNS.** `#idea(tags: "draft")` puts the tag on the idea being minted. So do `tag:`,
  `base-tags:` and `#ideate(tags:)`.
- **It SELECTS.** `#window(tags: "draft")`, `ideas(tags: "draft")` and
  `#ideas-outline(tags: "draft")` pick out ideas already carrying it and attach nothing to
  anything.

The two read identically at a call site, which is why `#window(tags: "draft")` is routinely
misread as tagging the window rather than choosing what it shows.

Split the vocabulary: **`tags:` puts tags on, `tagged:` picks by them.** Rename the selecting
argument on the three view functions; leave every assigning argument exactly as it is.

```typ
#idea(tags: "draft")[..]                  // assigns — unchanged
#window(tagged: "draft")                  // selects — renamed
#ideas(tagged: "draft", match: "all")     // selects — renamed
#ideas-outline(tagged: "draft")           // selects — renamed
```

`match:` is unchanged: it modifies the selection rather than naming it, and reads correctly
beside the new name. So does `filter:`, where a sibling bird has added it.

## Steps

1. **`#window` — rename the parameter.** Find its selection group:

   ```
   rg -Fn 'match: "any",' /home/lox/code/_fcl/rookery/core/0.1.0/src/window.typ
   ```

   One hit as of filing, line 112, with `tags: none,` directly above it in the multi-line
   `#let window(..)` parameter list. Rename that `tags:` to `tagged:`, keeping its position.
   Do NOT touch `match:` or any `display-tags` argument — `display-tags` is about whether the
   tag pills are SHOWN and is a third, unrelated meaning that keeps its name.

2. **`#window` — rename the uses and the assert.** Inside the same function, the assert
   (`_assert-tags(tags, "#window's")`) and the `context` block's selection
   (`if tags == none { .. }` and `_tag-pred(tags, match, ..)`). `_assert-tags` takes a `what:`
   parameter for exactly this — check its signature:

   ```
   rg -Fn 'let _assert-tags' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   One hit as of filing, `pure.typ` line 781, `#let _assert-tags(v, where, what: "tags")`. Pass
   `what: "tagged"` from each renamed caller so the error message names the argument the author
   actually wrote. The private helper itself is not renamed.

3. **`ideas()` — same rename.** Find the signature:

   ```
   rg -Fn 'let ideas(tags: none' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   One hit as of filing, `data.typ` line 273. Rename `tags:` to `tagged:`, update the
   `_assert-tags(tags, "#ideas'")` call directly below it with `what: "tagged"`, and rename the
   `_tag-pred(tags, match, ..)` argument a few lines further down. **The row field stays
   `tags`**: every row `ideas()` returns carries a `tags` field, three packages read it, and it
   is data rather than an argument — renaming it is explicitly out of scope.

4. **`#ideas-outline` — same rename.** Find the signature:

   ```
   rg -Fn 'let ideas-outline' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   One hit as of filing, `outline.typ` line 449. Rename `tags:` to `tagged:`, with the same
   two follow-ups: the `_assert-tags(.., "#ideas-outline's")` call gains `what: "tagged"`, and
   the `_tag-pred(tags, match, filter: filter)` call takes the renamed value.

5. **Update core's own doc comments.** Every header block above the three functions explains
   the selection. Find the mentions:

   ```
   rg -n '`tags:`|tags:/match:|`tags`/`match`' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   Rename those that describe SELECTION on the three view functions. Leave every mention
   describing assignment on `#idea`/`#ideate`, every mention of the `tags` FIELD on an `ideas()`
   row, and every mention of the private `_tag-pred`/`_norm-tags`/`_assert-tags` helpers.

6. **Update the core demos.** The call sites:

   ```
   rg -n 'window\(tags:|ideas-outline\([^)]*tags:|ideas\(tags:' /home/lox/code/_fcl/rookery/core/0.1.0/demo
   ```

   As of filing: `demo/rheo/content/tags.typ` lines 30, 31 and 122, `demo/rheo/content/relations.typ`
   line 44, and `demo/rheo/content/sub/deeper/page.typ` line 111. Several carry explanatory
   comments naming the argument — `tags.typ` line 26 and `sub/deeper/page.typ` line 96 as of
   filing — and those are rendered demo prose, so rename them too.

7. **Update the demo's assertion message.** `core/0.1.0/demo/rheo/check.sh`:

   ```
   rg -Fn 'window(tags:' /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo/check.sh
   ```

   One hit as of filing, line 546, inside a failure message. The assertion is about the OUTPUT
   and stays; rename the argument the message quotes.

8. **Update the three sibling packages that call `ideas(tags: ..)` by name.** Find them:

   ```
   rg -n 'ideas\(tags:' /home/lox/code/_fcl/rookery --glob '!core/**'
   ```

   Four hits as of filing: `search/0.1.0/src/lookup.typ` line 146
   (`ideas(tags: tags, match: match)`), `search/0.1.0/src/filter-panel.typ` line 232
   (`ideas(tags: tag, values: true)`), `timeline/0.1.0/src/upcoming.typ` line 206
   (`ideas(tags: tags, match: match, values: true)`) and `cfps/0.1.0/src/panel.typ` line 101
   (`ideas(tags: want, match: "all", values: true)`). In each, rename ONLY the keyword being
   passed to core's `ideas()`. **The local variable and the package's own parameter keep their
   names** — `search-ideas(tags:, match:)` and `timeline-upcoming(tags:, match:)` are those
   packages' own public surface and are not being renamed here, so the edit is
   `ideas(tagged: tags, match: match, ..)` and nothing more.

9. **Update the prose in those packages that names core's argument.** Comments and readmes:

   ```
   rg -n 'window\(tags:|ideas\(tags:' /home/lox/code/_fcl/rookery --glob '!core/**'
   ```

   As of filing: `search/0.1.0/src/panel.typ` line 15, `search/0.1.0/readme.md` lines 561 and
   1229, `timeline/0.1.0/readme.md` line 139, `pinboard/0.1.0/readme.md` line 38, and
   `slipshow/0.1.0/src/select.typ` line 72. Rename where the passage is about calling CORE's
   function; leave it where the passage is about the package's own argument of the same name,
   and say in your report which you judged to be which.

10. **Update core's readme.** Find every selecting use:

    ```
    rg -n 'window\([^)]*tags:|ideas\(tags:|ideas-outline\([^)]*tags:' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
    ```

    Roughly a dozen hits as of filing, including lines 1119 and 1258. Rename them, leave the
    assigning ones alone, and state the rule once where tags are first introduced — `tags:` puts
    tags on, `tagged:` picks by them. Add a row to the readme's migration section
    (`rg -n 'is now .created.' readme.md`, one hit at line 110 as of filing).

## Non-goals

- **Do not rename any assigning argument.** `#idea(tags:)`, `#idea(tag:)`, `#idea(base-tags:)`,
  `#idea(exclude-tags:)` and `#ideate(tags:)` keep their names. That is half the point.
- **Do not rename `display-tags`.** A third meaning — whether tag pills are shown — already
  distinct and already consistent across the package.
- **Do not rename the `tags` FIELD on an `ideas()` row**, nor `tags-dict`, nor any private
  helper (`_tag-pred`, `_norm-tags`, `_assert-tags`, `_visible-tags`).
- **Do not rename the sibling packages' own `tags:` parameters** — `search-ideas`,
  `todos-list`, `timeline-upcoming`, `slipshow`, `pinboard` and `cfps` all take one, and
  whether they should follow core is a separate decision, deliberately not made here.
- **Do not change behaviour.** Same forms accepted (string, array, dictionary), same defaults,
  same `match:` interaction.
- **Do not keep `tags:` as an alias on the three view functions.** One spelling each.

## VERIFY

1. `cd core/0.1.0 && just test` — prints `units OK`.
2. `cd core/0.1.0/demo/pure && just build` — succeeds.
3. `cd core/0.1.0/demo/rheo && just check` — succeeds, including the tag-narrowing assertion
   whose message is at `check.sh` line 546. (Needs the `rheo` binary, present at
   `~/.cargo/bin/rheo` when this bird was filed; if it is genuinely missing, say so rather than
   skipping quietly.)
4. Each edited sibling package still builds: `cd search/0.1.0 && just build`,
   `cd timeline/0.1.0 && just` , `cd cfps/0.1.0 && just test`. Run whatever recipe each
   `Justfile` offers and name the ones you ran.
5. `rg -n 'ideas\(tags:' .` from the repo root returns nothing outside `.birds/` and outside
   the readme migration rows.
6. `bd status <this bird's id>` reports `retired` after the flight lands.