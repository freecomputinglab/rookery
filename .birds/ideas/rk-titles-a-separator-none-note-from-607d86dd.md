---
id: rk-titles-a-separator-none-note-from-607d86dd
short-id: '607'
title: Titles a separator-none note from document.title
priority: 3
labels:
- ideate-separator
deps:
- blocked-by:rk-defaults-ideate-s-separator-to-none-744f79e4
closed: true
---
Touches: core/0.1.0/src/ideate.typ, core/0.1.0/readme.md, core/0.1.0/demo/rheo/content/ideated-doctitle.typ, core/0.1.0/demo/rheo/check.sh, core/0.1.0/demo/rheo/native.typ

`#ideate` (in `@rookery/core`) mints the whole body as ONE note when
`separator: none`, which is now its default. Such a note has no heading to take
a title or an id from, so today it mints titleless and under the package's
auto-incrementing counter. Give it both from the document title instead: in
`none` mode, and only there, default the note's title to `document.title` and
its id to `slug(document.title)`.

Why the id matters as much as the title: the auto counter is assigned in
compile order across a whole bundle. Under rheo, with one note per page, every
page's note id would be a sequence number that shifts whenever a page is added
or removed — so every inbound `#hyperlink` to one of them breaks silently. A
slug of the page's own title is stable and readable.

## The feasibility question, already answered

`document.title` is readable and needs no new plumbing. MEASURED on typst
0.15.1:

- `#context document.title` returns the `#set document(title: ..)` value as
  CONTENT, and `none` when no document title was set.
- It is readable from inside a `#show: f` rule's own context.
- `#ideate`'s body is ALREADY inside a `context` block — the function is
  declared `... ..args) = context {` — so the read needs no new context and no
  new argument.

Do NOT reach for `state("rheo-handle")` and `_handle-title` in `src/base.typ`
to get a page title. That route works only under rheo and needs a fallback for
plain Typst; `document.title` covers both, because rheo wraps each vertebra in
its own `document(..., title: ...)`.

## Where the code is

All in `core/0.1.0/src/ideate.typ` unless stated. Run every `rg` from the
repository root (`/home/lox/code/_fcl/rookery`).

1. The `none-mode` classification, where the mode is decided.

   ```
   rg -n 'let none-mode = separator == none' core/0.1.0
   ```

   One hit, `src/ideate.typ:356` as of filing, inside `#let ideate(..)`.

2. The `mint` binding, which pre-binds the arguments every note is minted with.

   ```
   rg -n 'let mint = idea.with' core/0.1.0
   ```

   One hit, around `src/ideate.typ:430` as of filing, inside `#let ideate(..)`.
   It binds `show-frame`, `show-id`, `tags: base-tags`, the caller's `title:`
   when that is not a function, and `..args`. An argument passed at a CALL of
   `mint` overrides the value bound here — that is the existing mechanism this
   bird uses, and it is already how per-group `tags:` works.

3. The branch that mints a group with no lead heading — the branch `none` mode
   always takes.

   ```
   rg -n 'if not \(title-fn or name-fn\) or lead-heading == none' core/0.1.0
   ```

   One hit, around `src/ideate.typ:586` as of filing, inside `#let ideate(..)`'s
   per-group loop. Inside it, a group with no `#ideate-id` beacon is minted as
   `mint(content, tags: group-tags)` and one with a beacon as
   `mint(beacon-id, content, tags: group-tags)` — `#idea` takes the note's id as
   its first positional argument.

4. `slug`, the public helper that turns content into an id.

   ```
   rg -n '^#let slug\(content\)' core/0.1.0/src/pure.typ
   ```

   One hit, around `src/pure.typ:807` as of filing. It is already in scope
   inside `src/ideate.typ`: that file imports `base.typ`, which star-imports
   `pure.typ`.

5. The readme section on `none` mode.

   ```
   rg -n 'wraps everything in one note' core/0.1.0/readme.md
   ```

   One hit, around `readme.md:641` as of filing, in the section headed
   `### Choosing what starts a note`. A SIBLING BIRD HAS ALREADY REWORDED the
   prose around it to present `none` as the default — read what is actually
   there rather than expecting particular wording.

6. The rheo demo and its assertions.

   - `core/0.1.0/demo/rheo/content/` holds one `.typ` file per page; every file
     there becomes a page, with no registration step.
   - `core/0.1.0/demo/rheo/check.sh` greps the built output. It is a long
     script of NUMBERED sections, `# 1.` through `# 27.` as of filing, each a
     comment header followed by its greps, using a `note "..."` helper to
     record a failure and a `$H` variable holding `build/html`. Find its last
     section, which is where the new one goes:

     ```
     rg -n 'NAMES A NOTE EXPLICITLY UNDER ANY SEPARATOR' core/0.1.0/demo/rheo/check.sh
     ```

     One hit, `check.sh:641` as of filing — the header of section 27, covering
     `#ideate-id`. Do NOT anchor on `no minted page at ideas`: that phrase
     appears ten times in this file, in ten different sections, and is not a
     locator.
   - `core/0.1.0/demo/rheo/native.typ` compiles the same `content/` the other
     way, as ONE plain-Typst document, by `#include`-ing each page. Its header
     comment ends with a sentence claiming every vertebra under `content/`
     belongs in that list.

## Steps

1. In `src/ideate.typ`, after the separator classification and before the group
   loop, bind the document title for `none` mode only, e.g.

   ```typ
   let doc-title = if none-mode and title == none { document.title } else { none }
   ```

   The `title == none` condition is what makes an explicitly-passed `title:`
   win: a caller who said `#ideate(title: [Mine])` keeps their title. (`title`
   cannot be a function here — a `title:` function already panics outside
   heading mode, in the existing guard a few lines above.)

2. In the no-lead-heading mint branch, use `doc-title` when it is not `none`:

   - Pass `title: doc-title` at the `mint(..)` call, which overrides the value
     bound into `mint` earlier.
   - Use `slug(doc-title)` as the note's id — the first positional argument to
     `mint` — UNLESS the group carries an `#ideate-id` beacon, which still wins
     outright. The beacon is a fixed value the caller wrote; a derived slug is
     not something to prefer over it.
   - Push the chosen id onto `seen-slugs` and run the same duplicate check the
     beacon path already runs, so the three id sources stay consistent.

3. When `doc-title` is `none` — no `#set document(title: ..)` anywhere — change
   NOTHING. The note mints titleless and under the auto counter, exactly as
   today. Do not invent a title, do not derive one from the body, do not panic.

4. Confirm by reading the code that par mode and heading mode are untouched:
   `doc-title` is `none` in both, so both take the existing paths unchanged.

5. Document it in `src/ideate.typ`'s file-header comment block, in three or four
   lines under the section on `none` mode: the title and id come from
   `document.title`, an explicit `title:` wins, `#ideate-id` wins the id, and
   with no document title the note is titleless under the counter. Follow the
   comment style in `CLAUDE.md` — present tense, no history.

6. Document it in `readme.md`'s `### Choosing what starts a note` section,
   beside the existing `none`-mode prose. Same four facts, in the readme's
   register.

7. Add a rheo demo page at
   `core/0.1.0/demo/rheo/content/ideated-doctitle.typ`. Model its shape on
   `core/0.1.0/demo/rheo/content/ideated-id.typ` — `#import "lib.typ": demo`,
   `#import "@rookery/core:0.1.0": ideate`, then `#show: demo`. It must set
   `#set document(title: [Doc Title Note])` and apply `#show: ideate` with NO
   separator given, with a distinctive body string such as `DOCTITLEBODY`.
   `#show: demo` must come before `#show: ideate`, so the template wraps
   `ideate`'s output rather than the other way round.

8. Add a new numbered section to the END of
   `core/0.1.0/demo/rheo/check.sh`, after its current last section and before
   the closing `if [ "$fail" -ne 0 ]` block, following the same shape as the
   sections around it: a `# 28. ...` comment header saying in one or two lines
   what the section proves, then the greps, using the script's existing `$H`
   variable and `note "..."` helper. Assert two things — a minted page exists
   at `$H/ideas/doc-title-note.html`, and it contains `DOCTITLEBODY`. If the
   file's last section number is not 27 by the time you get there, continue
   from whatever it actually is.

9. Add ONE sentence to `core/0.1.0/demo/rheo/native.typ`'s header comment
   recording that `content/ideated-doctitle.typ` is deliberately NOT in its
   include list: `native.typ` compiles every page into one document, and a
   `#set document(title: ..)` inside an included file applies to that whole
   single document, so including it would either fight the other pages or fail
   outright. Do NOT add it to the include list.

## Honest uncertainty

Under rheo, each vertebra is wrapped in its own `document(..., title: ...)`,
and rheo supplies a PATH-DERIVED title when the page sets none. So a rheo page
with no `#set document(title: ..)` may report a non-`none` `document.title` and
therefore mint a titled, slug-named note rather than a titleless counter-named
one. That is acceptable and arguably desirable, and the spec above holds either
way — it says "use whatever `document.title` gives". Observe which happens when
running the demo and state it in the landing message. Do not add a special case
to suppress it.

## What NOT to do

- Do NOT apply this in par mode or heading mode. Only `none` mode.
- Do NOT change what `#ideate-id` does, or its one-per-section panic. It still
  wins the id.
- Do NOT override a `title:` the caller passed explicitly.
- Do NOT derive a title from the body when there is no document title —
  `_derived-title` in `src/pure.typ` already supplies the note's LINK TEXT in
  that case, inside `#idea`, and that is a separate thing from the rendered
  title. Leave both alone.
- Do NOT add `content/ideated-doctitle.typ` to `demo/rheo/native.typ`'s include
  list (step 9 says why).
- Do NOT change the default of `separator:` — it is already `none`.
- Do NOT touch any package other than `core/0.1.0`.

## VERIFY

Run from `core/0.1.0/`:

1. `just test` exits 0 and prints `units OK`.
2. `cd demo/rheo && just check` exits 0 and prints its own OK line, with the
   new `ideas/doc-title-note.html` assertions passing.
3. `cd demo/rheo && just check-typst` exits 0 — but ONLY with the package
   override below, and the difference matters. `just check` runs `rheo
   compile`, which reads `demo/rheo/rheo.toml`'s `[packages.rookery] path =
   "../../../.."` and so always compiles the code sitting beside it, inside the
   flight. `just check-typst` runs plain `typst`, which has no such override
   and resolves `@rookery/core:0.1.0` through the machine-global package cache
   at `~/.cache/typst/packages/rookery/core/0.1.0` — a symlink pointing at a
   DIFFERENT checkout. Run bare, it silently compiles code this flight never
   touched and passes for the wrong reason. MEASURED: a probe that must panic
   compiled clean that way. Point typst at the flight for that one invocation,
   and do NOT alter the global symlink, which is shared with every other
   flight:

   ```sh
   # from core/0.1.0/demo/rheo
   rm -rf /tmp/fl-pkgs/rookery/core/0.1.0
   mkdir -p /tmp/fl-pkgs/rookery/core
   ln -s "$PWD/../.." /tmp/fl-pkgs/rookery/core/0.1.0
   TYPST_PACKAGE_PATH=/tmp/fl-pkgs just check-typst
   ```

   The same `TYPST_PACKAGE_PATH=/tmp/fl-pkgs` prefix applies to every scratch
   `typst compile` in the steps below — without it they read the other
   checkout too.
4. The behaviour holds under plain Typst too. Write a scratch file OUTSIDE the
   repository, `/tmp/doctitle.typ`:

   ```typ
   #import "@rookery/core:0.1.0": rookery, ideate
   #set document(title: [Scratch Title])
   #show: rookery
   #show: ideate

   SCRATCHBODY, the whole page as one note.
   ```

   Compile with `TYPST_PACKAGE_PATH=/tmp/fl-pkgs typst compile --features html
   --format html /tmp/doctitle.typ /tmp/doctitle.html` — the prefix is what
   makes it read the flight — then confirm the output mentions both `Scratch Title` and the id
   `idea:scratch-title`.
5. `rg -n 'DOCTITLEBODY' core/0.1.0/demo/rheo` hits in both the new content file
   and `check.sh`.