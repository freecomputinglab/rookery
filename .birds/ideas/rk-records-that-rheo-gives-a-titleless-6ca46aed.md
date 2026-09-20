---
id: rk-records-that-rheo-gives-a-titleless-6ca46aed
short-id: 6c
title: Records that rheo gives a titleless page a path title
priority: 2
labels:
- ideate-separator
deps: []
closed: true
---
Touches: core/0.1.0/src/ideate.typ, core/0.1.0/readme.md

`#ideate` in `separator: none` mode titles its one note from `document.title`
and ids it `slug(document.title)`. Both the readme and the source comment end
with the same fallback sentence: with no document title set, the note mints
titleless under the package's auto counter.

That sentence is true under plain `typst compile` and effectively FALSE under
rheo, which is the more common way this package is used. Say so.

## The fact to record, MEASURED

Rheo wraps each vertebra in a `document(..., title: ...)` of its own and
supplies a PATH-DERIVED title when the page sets none. So a rheo page that
never writes `#set document(title: ..)` still reports a non-`none`
`document.title`, and its note is titled and named after the page.

Measured on rheo 0.6.3, in `core/0.1.0/demo/rheo`, by adding a page
`content/probe-notitle.typ` whose whole body was one paragraph under a bare
`#show: ideate` and no `#set document(..)` at all:

- the minted note landed at `build/html/ideas/probe-notitle.html`
- it carried `id="idea:probe-notitle"`
- its rendered title was `Probe Notitle`

So under rheo the titleless-under-the-counter branch is reached only by a page
that somehow has no title at all, not by the ordinary case of a page that
simply does not set one. That is the good outcome — every page's note gets a
stable id derived from the page — but a reader is currently told the opposite.

## Where the two sentences are

Run from the repository root (`/home/lox/code/_fcl/rookery`).

1. The source comment.

   ```
   rg -n 'the note mints titleless' core/0.1.0
   ```

   Two hits, one per file. In `core/0.1.0/src/ideate.typ` it is in the file
   header's `separator:` section, in the paragraph beginning `In \`none\` mode
   the single note has no heading of its own`. In `core/0.1.0/readme.md` it is
   in the section headed `### Choosing what starts a note`, in the paragraph
   beginning `The one note this mode mints has no heading of its own`.

   If the exact phrase has been reworded, find the paragraphs by their opening
   clauses above; both say the same thing about `document.title` and both end
   on the no-document-title fallback.

## Steps

1. In `core/0.1.0/src/ideate.typ`, extend the fallback sentence with one more:
   under rheo the fallback is rarely reached, because rheo gives every page a
   title derived from its path when the page sets none, so the note is named
   after the page. Two lines at most — the header block is already long, and
   the project's comment style asks for a minority of lines to be comments.
2. Do the same in `core/0.1.0/readme.md`, in the readme's register, where there
   is more room: name the behaviour as the reason a rheo site gets stable
   per-page note ids for free, without any `#set document(..)` in its pages.
3. Do NOT restate the measurement above in either file. The project's comment
   style keeps the number that justifies a constant and drops the lab notebook;
   there is no constant here, only a behaviour, so the behaviour is what gets
   written.

## What NOT to do

- Do NOT change any code. This bird writes two sentences; `#let` bindings,
  branches and tests all come out untouched.
- Do NOT add a demo page for the path-derived case. It was measured once, by
  the probe described above, and a permanent fixture asserting rheo's own
  title-derivation would be testing rheo from inside this package.
- Do NOT touch any package other than `core/0.1.0`.

## VERIFY

Run from `core/0.1.0/`:

1. `just test` exits 0 and prints `units OK` — nothing executable changed.
2. `cd demo/rheo && just check` exits 0 and prints `demo/rheo OK`.
3. `rg -n 'path' core/0.1.0/readme.md` hits inside the paragraph beginning
   `The one note this mode mints has no heading of its own`, showing the rheo
   behaviour is now named there.