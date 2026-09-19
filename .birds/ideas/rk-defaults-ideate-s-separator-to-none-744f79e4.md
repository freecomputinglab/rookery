---
id: rk-defaults-ideate-s-separator-to-none-744f79e4
short-id: '74'
title: Defaults ideate's separator to none
priority: 3
labels:
- ideate-separator
deps:
- blocked-by:rk-accepts-only-heading-where-as-ideate-dc9435ee
closed: false
---
Touches: core/0.1.0/src/ideate.typ, core/0.1.0/readme.md, core/0.1.0/demo/rheo/content/ideated-id.typ

`#ideate` (in `@rookery/core`) splits a body into groups and mints each group as
a note. Its `separator:` argument decides where one note ends and the next
begins, and it currently defaults to `par` — every paragraph becomes its own
note. Change the default to `none`, so a call with no `separator:` given mints
the WHOLE body as ONE note.

Why: the common use is a document-level show rule, `#show: ideate`, on a page
that is one idea. Defaulting to `par` shatters that page into a note per
paragraph and every caller who wants the obvious behaviour has to say
`separator: none` to get it. `none` is the default worth having; `par` stays
available and unchanged for callers who want it, written explicitly.

This is a breaking change to the package's behaviour. That is accepted — the
package is at `0.1.0` and unreleased under this name.

## Where the code is

Run every `rg` from the repository root (`/home/lox/code/_fcl/rookery`) so a
moved file still resolves.

1. The function signature carrying the default.

   ```
   rg -n 'separator: par, title: none' core/0.1.0
   ```

   Two hits, one per file. `src/ideate.typ:330` as of filing is the real
   declaration, `#let ideate(body, separator: par, title: none, name: auto,
   tags: (), show-frame: false, show-id: false, ..args) = context {`.
   `readme.md:857` as of filing is the same signature quoted as prose, in the
   section headed `### Its two inverted defaults`.

2. The readme section documenting the defaults.

   ```
   rg -n 'Its two inverted defaults' core/0.1.0/readme.md
   ```

   One hit, `readme.md:855` as of filing. The heading counts the inverted
   defaults (`show-frame` and `show-id`, both `false` where `#idea` has them
   `true`). After this bird `separator:` is a third thing worth explaining in
   that section, though it is not an inversion of an `#idea` default — `#idea`
   has no separator.

3. The readme prose on `none` mode.

   ```
   rg -n 'wraps everything in one note' core/0.1.0/readme.md
   ```

   One hit, `readme.md:641` as of filing, in the section headed
   `### Choosing what starts a note`.

4. The file-header comment block in `src/ideate.typ`, under the comment heading
   `// ---- Choosing what starts a note: \`separator:\` ----`. Locate it with:

   ```
   rg -n 'Choosing what starts a note' core/0.1.0
   ```

   Two hits, one per file: `src/ideate.typ:29` and `readme.md:587` as of
   filing. In `src/ideate.typ` this heading is followed by a short list of the
   accepted `separator:` spellings, one per line, with `(the default)`
   annotating the `par` row. A SIBLING BIRD HAS ALREADY REWRITTEN THIS LIST —
   it dropped a row and reworded the surrounding prose — so find the list by
   this heading and read what is actually there, rather than expecting any
   particular wording.

5. The demo fixture that calls `#ideate` with an explicit separator.

   ```
   rg -n 'ideate\(separator: par\)' core/0.1.0
   ```

   One hit, `demo/rheo/content/ideated-id.typ:20` as of filing. It is already
   explicit, so it keeps working — but its comment says `separator: par splits
   this into two notes`, which was describing the default and now describes an
   opt-in.

If an anchor does not hit, widen the search to the repository root; if it is
still gone, report the miss rather than guessing.

## Steps

1. In `src/ideate.typ`, change the signature's `separator: par` to
   `separator: none`. Nothing else in the function changes: `none-mode`,
   `heading-mode` and `par-mode` are all computed from the value and the
   `none` branch already exists and is already tested by the demos.

2. Move the `(the default)` annotation in the header comment's spelling list
   from the `par` row to the `none` row.

3. In that same header block, near the top of the file there are two short
   usage examples — a `#ideate[ .. ]` block form showing "First paragraph — one
   note / Second paragraph — another", and a `#show: rookery` / `#show: ideate`
   pair captioned "Every paragraph below is a note". Both now describe `par`,
   which is no longer what those calls do. Rewrite them so the bare calls
   describe one-note-per-body, and show `separator: par` explicitly on whichever
   example is meant to demonstrate paragraph splitting. Keep them short —
   examples, not a tutorial.

4. Update `readme.md`'s `### Its two inverted defaults` section: correct the
   quoted signature to `separator: none`, and retitle the section so the count
   in its heading is not wrong (`### Its inverted defaults` is fine, or fold the
   separator default in under a heading that does not count). Add two or three
   sentences saying the default mints the whole body as one note and that
   `separator: par` is how a caller asks for the old paragraph-per-note
   behaviour.

5. Update `readme.md`'s `### Choosing what starts a note` section so the table
   marks `none` as the default rather than `par`, and so the prose anchored by
   "wraps everything in one note" reads as the default case rather than an
   option.

6. In `demo/rheo/content/ideated-id.typ`, update the comment above the
   `#ideate(separator: par)[` call so it does not present `par` as the default.
   Do NOT change what either call in that file does — both are explicit and both
   assertions in `demo/rheo/check.sh` must keep passing.

7. Re-check the cross-reference in `readme.md` that names a line number inside
   `src/ideate.typ`:

   ```
   rg -n 'ideate.typ.*line [0-9]' core/0.1.0/readme.md
   ```

   One hit as of filing, around `readme.md:834`, pointing at "line 460" of
   `src/ideate.typ`. Line numbers there have shifted. Open
   `src/ideate.typ`, find the comment it means (it explains a measured
   convergence failure, in the group-splitting region of `#ideate`), and correct
   the number. If the reference is already correct, leave it.

## What NOT to do

- Do NOT remove or deprecate `par` or `parbreak`. Both stay accepted, with
  identical behaviour; only the default moves.
- Do NOT change any behaviour of `none` mode itself. The single-group path, the
  handling of the trailing rheo postamble child inside that group, and the
  `#ideate-id` beacon all stay exactly as they are.
- Do NOT add a `document.title` default for the minted note's title. A separate
  bird does that, on top of this one.
- Do NOT edit `core/0.1.0/test/units.typ`. Its assertions cover pure helpers
  (`_blank`, `_heading-only`, `_level-of`, `_sel-level`, `_slug` and the beacon
  readers) and none of them reads the signature's default.
- Do NOT touch any package other than `core/0.1.0`. A repository-wide search
  for `ideate` and `separator:` found no hits outside it.

## VERIFY

Run from `core/0.1.0/`:

1. `just test` exits 0 and prints `units OK`.
2. `cd demo/rheo && just check` exits 0 and prints its own OK line.
3. `cd demo/rheo && just check-typst` exits 0.
4. A bare `#ideate` now mints one note, not one per paragraph. Write a scratch
   file OUTSIDE the repository, `/tmp/defsep.typ`:

   ```typ
   #import "@rookery/core:0.1.0": rookery, ideate
   #show: rookery
   #show: ideate

   FIRSTPARA, one paragraph.

   SECONDPARA, another paragraph.
   ```

   Compile it with
   `typst compile --features html --format html /tmp/defsep.typ /tmp/defsep.html`
   and confirm the output contains exactly ONE note card: `grep -c 'idea-box'
   /tmp/defsep.html` should report 1, with both `FIRSTPARA` and `SECONDPARA`
   inside it. Note that this scratch compile resolves `@rookery/core` through
   the machine's package cache rather than the flight; if it picks up different
   code, say so in the landing message instead of treating it as a failure. If
   `idea-box` is not the class the card actually carries, grep the class that is
   there — read it off `src/core.css` or the demo output rather than guessing.
5. `rg -n 'separator: none, title: none' core/0.1.0/src/ideate.typ` hits,
   confirming the declaration changed.