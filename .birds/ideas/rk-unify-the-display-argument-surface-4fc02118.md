---
id: rk-unify-the-display-argument-surface-4fc02118
short-id: 4fc
title: Unify the display-* argument surface
priority: 3
labels:
- feat-display-arg-parity
deps: []
closed: true
---
Touches: core/0.1.0/src/idea.typ, core/0.1.0/src/window.typ, core/0.1.0/demo/pure/display-parity.typ, core/0.1.0/demo/pure/Justfile, core/0.1.0/readme.md, todos/0.1.0/src/todo.typ

`@rookery/core` has one display vocabulary and three functions that each expose a
different slice of it, with no error when a caller names a slice the function it is
calling does not carry.

`_DISPLAY-KEYS` (`core/0.1.0/src/pure.typ`, line 808 as of filing) names the nine keys:
`context`, `backlinks`, `background`, `date`, `frame`, `id`, `label`, `tags`, `title`.
`_resolve-display` (same file, line 828) merges a `display:` DICTIONARY with a set of
individual flags and always returns all nine. The dictionary half is already uniform: every
function that takes `display:` accepts all nine keys in it, and the keys it has no use for
ride along ignored — `#window`'s own comment states that as deliberate, so that one
dictionary can be handed to `#idea` and `#window` alike.

The per-argument `display-*` flags do not match that dictionary:

- `#idea` declares seven — `date`, `tags`, `frame`, `id`, `context`, `backlinks`, `title`.
  It has no `display-label` and no `display-background`.
- `#window` declares six — `date`, `tags`, `frame`, `id`, `label`, `background`. It has no
  `display-context`, `display-backlinks` or `display-title`.
- `rookery(..)` (the document-wide template, `core/0.1.0/src/template.typ` around line 438)
  already declares all nine, so the whole-document tier is the one that is right.

Worse than ragged: it is silent. Both `#idea` and `#window` end in a `..args` sink and read
only `args.pos()` from it. Neither file ever calls `args.named()`. So
`#idea(display-label: false)`, `#window(display-title: false)` and an ordinary typo such as
`#idea(dispaly-id: false)` are all accepted, all do nothing, and none of them says anything.
This is not hypothetical: the `rookery.ohrg.org` site (a SEPARATE repo — see the heads-up at
the bottom, do not edit it from this flight) still passes the pre-rename `show-tags:` and
`show-date:` spellings at about eight call sites, which have been inert since the rename
landed and have reported nothing.

This package already knows how to check an argument sink by hand. `#hyperlink`
(`core/0.1.0/src/hyperlink.typ`, lines 68-80 as of filing) takes `..args` for the same reason
these two do, and rejects every named argument but its own with an explicit message.

## The design, already decided — implement it, do not re-open it

1. **Both functions declare all nine `display-*` flags**, defaulting to `auto`, and pass all
   nine to `_resolve-display`. A flag the function has no use for is accepted and ignored,
   exactly as the same key inside a `display:` dictionary already is. This is what makes the
   two spellings — `display: (label: false)` and `display-label: false` — mean the same thing
   everywhere.
2. **An unrecognised named argument panics**, in the shape `#hyperlink` already uses.

Two alternatives were considered and lost. Adding the validation WITHOUT the missing flags
would turn `#idea(display-label: false)` into a hard error while `#idea(display: (label:
false))` stayed legal — two spellings of one thing disagreeing, which is the defect this bird
exists to remove. Making `#window` genuinely HONOUR `context`/`backlinks`/`title` is a
different and much larger change: those three are properties of a minted page, and a window
is not a page. They are accepted and ignored here, nothing more.

Defaults do not change anywhere. `#window`'s six keep defaulting to `auto`; `#ideate`'s
inverted `display-frame: false` / `display-id: false` stay false.

## Steps

1. **`#idea` — add the two missing flags.** Find its signature:

   ```
   rg -n 'display-context: auto, display-backlinks: auto, display-title: auto' /home/lox/code/_fcl/rookery
   ```

   One hit as of filing, `core/0.1.0/src/idea.typ` line 57, the `#let idea(..)` signature
   itself. Add `display-label: auto` and `display-background: auto` to the parameter list,
   keeping the existing alphabetical-ish grouping of the other seven.

2. **`#idea` — feed all nine to `_resolve-display`.** In the same function, a few lines below
   the signature, the call that builds the flags dictionary:

   ```
   rg -n 'frame: display-frame, id: display-id, tags: display-tags, title: display-title,' /home/lox/code/_fcl/rookery
   ```

   One hit as of filing, `core/0.1.0/src/idea.typ` line 95, inside `#let idea`. Add
   `label: display-label` and `background: display-background` to that dictionary. Note the
   existing `"context": display-context` is quoted because `context` is a Typst keyword —
   leave that exactly as it is.

3. **`#window` — add the three missing flags.** Find its signature:

   ```
   rg -n 'display-label: auto,' /home/lox/code/_fcl/rookery/core/0.1.0/src/window.typ
   ```

   One hit as of filing, line 86, inside the multi-line `#let window(..)` parameter list
   (the file's other display flags are on the lines around it). Add `display-context: auto`,
   `display-backlinks: auto` and `display-title: auto`. Each of the existing flags in that
   list carries a comment explaining what it does; give the three new ones one short shared
   comment saying they are accepted for parity with `#idea` and the `display:` dictionary and
   are ignored here, because they describe a minted page and a window is not one.

4. **`#window` — feed all nine to `_resolve-display`.** In the same function:

   ```
   rg -n 'id: display-id, label: display-label, background: display-background,' /home/lox/code/_fcl/rookery
   ```

   One hit as of filing, `core/0.1.0/src/window.typ` line 148. Add `"context":
   display-context`, `backlinks: display-backlinks` and `title: display-title` to that
   dictionary, quoting `context` the same way `#idea` does. The comment directly above that
   call says `#window` "uses six of the nine" and that the other three "ride along unused" —
   update it to say all nine are now nameable as flags too, with the same three still unused.

5. **Reject unknown named arguments, in both functions.** The model to copy:

   ```
   rg -n 'unknown = args.named\(\).keys\(\).filter' /home/lox/code/_fcl/rookery
   ```

   One hit as of filing, `core/0.1.0/src/hyperlink.typ` line 75, inside `#let hyperlink`.
   Read the five lines around it, including the comment above explaining why the check is
   done by hand. In `#idea` and in `#window`, right beside the existing `let pos =
   args.pos()` line, add the equivalent: collect `args.named().keys()`, and assert it is
   empty with a message naming the offending keys. Neither function has any legitimate named
   argument arriving through the sink once step 1 and step 3 land — every named argument
   either of them honours is a declared parameter — so the allowed set is empty and no
   exception list is needed. Messages, verbatim, in the house style:

   - `#idea`: `"@rookery/core: #idea got unknown named argument(s) " + repr(unknown) + " — every argument #idea honours is a declared one; the display flags are display-background, display-backlinks, display-context, display-date, display-frame, display-id, display-label, display-tags and display-title."`
   - `#window`: the same sentence with `#window` in place of `#idea`.

6. **A fixture that proves the accept-and-ignore half.** Create
   `core/0.1.0/demo/pure/display-parity.typ`, modelled on the other roots in that directory
   (`root.typ` is the fullest; read its opening lines for the import and `#show: rookery`
   shape). It needs a short header comment saying what it is for, then a note and a window
   that between them name ALL NINE flags on each function — the inapplicable ones included:

   ```typ
   #idea(<parity>, display-label: false, display-background: false, display-date: false, display-tags: false, display-frame: false, display-id: false, display-context: false, display-backlinks: false, display-title: false)[PARITYBODY]
   #window("parity", display-context: false, display-backlinks: false, display-title: false, display-label: false, display-background: false, display-date: false, display-tags: false, display-frame: false, display-id: false)
   ```

   A clean compile is the whole assertion — no `check` grep is needed for this root.

7. **Wire the fixture into the demo build.** `core/0.1.0/demo/pure/Justfile`'s `build` recipe
   lists every root explicitly (its header says so, and the `@just check` line closes it).
   Add one HTML line for the new root, matching the existing ones:

   ```
   typst compile --features html --format html --root ../.. display-parity.typ build/display-parity.html
   ```

   HTML only — the cards are an HTML concern and a PDF line would double the runtime for no
   coverage, which is the reason `excluded.typ` is HTML-only already. Put it after the
   `excluded.typ` lines and before `@just check`. Do not touch the `check` recipe.

8. **Fix the stale signature in the readme.** `core/0.1.0/readme.md` quotes `#idea`'s full
   signature and is already out of date — it omits `display-context`, `display-backlinks` and
   `display-title`, which the function has carried since before this bird:

   ```
   rg -n 'Full signature: ' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   One hit as of filing, line 23, in the `#idea` section. Rewrite that quoted signature to
   match the function as it stands after step 1 — all nine flags.

9. **Give `#window` a full signature in the readme too.** It has none: its arguments are
   documented piecemeal across the file (`depth` around line 234, `display-label` around 461,
   `display-background` around 535, `backlink` around 546). Find the section heading for
   `#window` and add, near its top, one quoted full-signature line in the same shape the
   `#idea` section uses, followed by one sentence saying that `context`, `backlinks` and
   `title` are accepted for parity and ignored. Do not restructure or relocate the existing
   piecemeal prose.

10. **One stale comment in `@rookery/todos`.** A doc comment still names the pre-rename
    argument spellings:

    ```
    rg -n 'created`, `show-date`, `show-tags`' /home/lox/code/_fcl/rookery
    ```

    One hit as of filing, `todos/0.1.0/src/todo.typ` line 18, in the header comment above
    `#todo` listing the `#idea` arguments that `..args` forwards. Change `show-date`,
    `show-tags` to `display-date`, `display-tags`. This is the last legacy spelling in the
    repo's own source; do not go looking for others. (The strings inside
    `core/0.1.0/src/state.typ`, such as `"rheo-idea-show-context"`, are internal state KEYS,
    not argument names — leave every one of them alone. The migration table in
    `core/0.1.0/readme.md` around lines 145-153 names the old spellings on purpose, as a
    migration table must — leave it alone too.)

## Non-goals

- **Do not touch `#ideate`** (`core/0.1.0/src/ideate.typ`). It declares `display:`,
  `display-frame` and `display-id` and forwards everything else through `..args` into
  `#idea`, so it inherits the full nine for free once step 1 lands, and a typo written at an
  `#ideate` call site surfaces as `#idea`'s panic. That message names the wrong function by a
  hair and is accepted; do not add a second validation pass there.
- **Do not touch `#ideas-outline`** (`core/0.1.0/src/outline.typ`). It has no `..args` sink
  and no display flags at all, so Typst already rejects an unknown argument for it. Giving it
  display flags would be a feature, not parity.
- **Do not change `_DISPLAY-KEYS` or `_resolve-display`** (`core/0.1.0/src/pure.typ`). Nine
  keys, same names, same merge order. The existing `_resolve-display` assertions in
  `core/0.1.0/test/units.typ` must keep passing untouched.
- **Do not change any default.** No flag's default moves, in either function, and `#ideate`'s
  inverted `display-frame: false` / `display-id: false` stay false.
- **Do not unify the SELECTION arguments.** `#window` has `sort:` and no `filter:`;
  `#ideas-outline` has `filter:` and no `sort:`; `ideas()` has neither. That is a real
  inconsistency and it is a different bird — this one is about `display-*` only.
- **Do not edit another repo.** `rookery.ohrg.org` is a separate checkout and is out of
  bounds from this flight.

## VERIFY

1. `cd core/0.1.0 && just test` — prints `units OK`.
2. `cd core/0.1.0/demo/pure && just build` — succeeds, and `build/display-parity.html` exists
   afterwards.
3. `cd core/0.1.0/demo/rheo && just check` — succeeds. (It needs the `rheo` binary on PATH;
   it was present at `~/.cargo/bin/rheo` when this bird was filed. If it is genuinely
   missing, say so in the report rather than skipping quietly, and run
   `cd core/0.1.0/demo/pure && just check-typst` in its place.)
4. The panic actually fires. A compiling fixture cannot assert a panic — a panic aborts the
   compile — so check it by hand, from inside `core/0.1.0`:

   ```
   mkdir -p demo/pure/build
   printf '#import "/src/lib.typ": *\n#show: rookery\n#idea(dispaly-id: false)[x]\n' > demo/pure/build/badarg.typ
   typst compile --features html --root . --format pdf demo/pure/build/badarg.typ /dev/null
   ```

   It must exit non-zero with a message naming `dispaly-id`. Then delete the scratch file:
   `rm demo/pure/build/badarg.typ` (`demo/pure/build/` is build output, but leave nothing
   behind in it regardless).
5. `rg -n 'show-date|show-tags' todos/0.1.0/src/todo.typ` returns nothing.
6. `bd status <this bird's id>` reports `retired` after the flight lands.

## Heads-up, out of scope for this flight

Once step 5 lands, a legacy `show-*` argument stops being silently ignored and becomes a hard
compile error. The `rookery.ohrg.org` site — a SEPARATE repo at
`/home/lox/code/_fcl/rookery.ohrg.org`, not this one — still passes `show-tags:`,
`show-date:`, `show-background:` and friends at roughly eight call sites under `content/`,
so its build will break the moment it is compiled against a core carrying this change. Do not
edit that repo from this flight. Report this line back with the landing so the operator can
sequence the site's migration.