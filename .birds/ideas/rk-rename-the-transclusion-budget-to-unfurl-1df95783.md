---
id: rk-rename-the-transclusion-budget-to-unfurl-1df95783
short-id: 1df
title: Rename the transclusion budget to unfurl
priority: 3
labels:
- feat-unfurl-budget
deps:
- blocked-by:rk-rename-core-s-four-off-pattern-accessors-34feb9e6
closed: true
---
Touches: core/0.1.0/src/window.typ, core/0.1.0/src/template.typ, core/0.1.0/readme.md, core/0.1.0/demo/rheo/content/sub/page.typ, core/0.1.0/demo/rheo/content/sub/deeper/page.typ, core/0.1.0/demo/rheo/check.sh

`depth:` means two different things inside `@rookery/core`, on functions an author uses side by
side:

- `#window(depth:)` and `idea-body(depth:)` — the TRANSCLUSION BUDGET. `0` renders the idea as a
  link to its own page, `1` renders it and collapses any window written inside it to a
  permalink, `n` unfurls `n - 1` levels of those. Zero is meaningful.
- `#ideas-outline(depth:)` — how many LEVELS OF THE OUTLINE TREE to keep. Its assert demands a
  positive integer, so zero is rejected.

Same word, same package, different unit, and the two asserts disagree about whether `0` is even
legal.

**`#ideas-outline` keeps `depth:`; the transclusion budget is renamed.** That direction is
forced, not preferred: Typst's own `#outline(depth:)` means exactly "levels of the tree", and a
sibling bird adds `#outline(target: idea)` as a front door that forwards to `#ideas-outline`. If
the outline's `depth:` were renamed, `#outline(target: idea, depth: 2)` and `#outline(depth: 2)`
over headings would mean different things — a worse collision than the one being fixed.

The budget becomes **`unfurl:`**, a word this package already uses for it: `#window`'s own
comment says "`n` unfurls n-1 levels of those". The document-wide default `rookery(window-depth:)`
becomes `window-unfurl:` to match.

```typ
#window("etal", unfurl: 0)                  // a link to the idea's page
#window("etal", unfurl: 2)                  // unfurl one level of nested windows
#show: rookery.with(window-unfurl: 2)       // the document-wide default
```

## Steps

1. **`#window` — rename the parameter.** Find it:

   ```
   rg -Fn 'depth: auto,' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   One hit as of filing, `window.typ` line 110, in the multi-line `#let window(..)` parameter
   list. Rename to `unfurl: auto,`, keeping its position.

2. **`#window` and `idea-body` — rename the asserts.** Both carry the same check:

   ```
   rg -Fn 'depth == auto or (type(depth)' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   Two hits as of filing, `window.typ` line 116 (inside `#window`) and line 429 (inside
   `idea-body`). Rename the identifier and the argument each message names, keeping each
   message's explanation of what `0`, `1` and `n` do — that explanation is the most useful text
   in either function and must survive the rename intact.

3. **`#window` — rename the use.** Inside its `context` block:

   ```
   rg -Fn 'let d = if depth == auto' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   Two hits as of filing: `window.typ` line 288 (inside `#window`) and `transclusion.typ` line
   490. **Change only the `window.typ` one.** The `transclusion.typ` line is inside a private
   helper whose own parameter is called `depth`, and private names are out of scope — see the
   non-goals.

4. **`idea-body` — rename its parameter.** Find the signature:

   ```
   rg -Fn 'let idea-body(name' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   One hit as of filing, `window.typ` line 424, `#let idea-body(name, depth: 1, limit: none)`.
   Rename to `unfurl: 1`. Its body passes the value into `_body-at(rec, depth: ..)` a few lines
   down — that call keeps the `depth:` keyword, because it is the private helper's own parameter
   name; only the value being passed is renamed.

5. **`rookery` — rename the document-wide default.** Find it:

   ```
   rg -Fn 'window-depth: 1,' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   One hit as of filing, `template.typ` line 442, in `#let rookery(..)`'s parameter list. Rename
   to `window-unfurl: 1,`. Its body publishes the value into the `_window-depth` state — that
   state keeps its name (see the non-goals), so only the parameter and the read of it change.

6. **Update the doc comments in `window.typ`.** The header block above `#window` explains the
   budget at length:

   ```
   rg -Fn 'is the transclusion budget' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   One hit as of filing, `window.typ` line 44. Rewrite that passage and every other mention of
   the argument in the file's comments to the new name. Where a comment names the PRIVATE
   `_window-depth` state, leave that name as it is — it is still called that.

7. **Update the demo.** The pages that exercise the budget:

   ```
   rg -Fn 'window("w-outer", depth:' /home/lox/code/_fcl/rookery
   ```

   Three hits as of filing, `core/0.1.0/demo/rheo/content/sub/deeper/page.typ` lines 34, 38 and
   41, each with an explanatory comment directly above it (lines 33, 36 and 40) naming the
   argument. Also `#window("cycle-a", depth: 3)` at line 92 of the same file, and a comment at
   `core/0.1.0/demo/rheo/content/sub/page.typ` line 18 naming `window-depth: 0`. Rename the
   calls and the comments. **Do not touch line 137 of `sub/deeper/page.typ`** — its `depth: 1`
   comment is about `#ideas-outline`, which keeps the old name.

8. **Update the demo's assertion comments.** `core/0.1.0/demo/rheo/check.sh` describes the
   depths it asserts on:

   ```
   rg -Fn 'WINDOW DEPTHS' /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo/check.sh
   ```

   One hit as of filing, line 359, heading a block of assertions. The assertions are about the
   OUTPUT and stay exactly as they are; rename the argument where the comments name it.

9. **Update the readme.** Both spellings appear throughout:

   ```
   rg -n 'window-depth' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   rg -n 'depth: [0-9]|depth:`' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   As of filing, roughly thirteen `window-depth` hits (including the section heading "### Nested
   windows, and `window-depth`" at line 223 and a Limitations entry at line 2649) and a dozen
   `depth:` hits. Rename every one that is about a WINDOW or `idea-body`; leave every one that
   is about `#ideas-outline` (lines 1258 and its neighbours as of filing, plus the outline
   section around line 1188). Read each hit before changing it — the two meanings are what this
   bird exists to separate, and a blanket replace would destroy the distinction. Add a row to the
   readme's migration section (`rg -n 'is now .created.' readme.md`, one hit at line 110 as of
   filing) recording both renames.

## Non-goals

- **Do not rename `#ideas-outline(depth:)`.** It is the Typst-native meaning and a sibling bird
  routes `#outline(target: idea)` onto it.
- **Do not rename any private name.** `_window-depth` (the state), `_body-at(depth:)` and
  `transclusion.typ`'s own `depth` parameters keep their names. `_window-depth` in particular is
  one of the 33 names `core/0.1.0/.marrow.typ` imports by name, so renaming it would break that
  file for no public benefit.
- **Do not change behaviour.** Same defaults (`auto` on `#window`, `1` on `idea-body`, `1` on the
  template), same semantics for every value, same assert conditions. Only the words change.
- **Do not keep `depth:` as an accepted alias on `#window`.** One spelling. A stale call site
  should fail — and after the sibling bird that rejects unknown named arguments it will say so
  explicitly; before it, `#window`'s sink would swallow it silently. If that sibling bird has not
  landed yet, say so in your report.
- **Do not edit another repo.**

## VERIFY

1. `cd core/0.1.0 && just test` — prints `units OK`.
2. `cd core/0.1.0/demo/pure && just build` — succeeds.
3. `cd core/0.1.0/demo/rheo && just check` — succeeds, including the window-depth assertions at
   `check.sh` line 359 and after. (Needs the `rheo` binary, present at `~/.cargo/bin/rheo` when
   this bird was filed; if it is genuinely missing, say so rather than skipping quietly.)
4. `rg -Fn 'depth:' core/0.1.0/src/window.typ` returns only hits that pass a value INTO a private
   helper (`_body-at(rec, depth: ..)`) — nothing in either public signature, neither assert.
5. `rg -n 'window-depth' core/0.1.0/src/template.typ` returns only the private state's name, not
   a parameter.
6. `bd status <this bird's id>` reports `retired` after the flight lands.