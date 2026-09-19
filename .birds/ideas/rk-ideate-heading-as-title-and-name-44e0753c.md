---
id: rk-ideate-heading-as-title-and-name-44e0753c
short-id: '44'
title: 'Ideate: heading as title and name'
priority: 3
labels:
- feat-ideate-heading-fields
deps: []
closed: true
---
`#ideate` (`core/0.1.0/src/ideate.typ:247`) mints one note per group, and every
note it mints gets the SAME arguments: `mint` is bound ONCE at line 298, above
the group loop, as `idea.with(show-frame: .., show-id: .., ..args)`. So a
`title:` passed to `#ideate` today is one fixed title repeated on every note it
mints, and there is no way at all to give each note a title of its own.

In heading mode — `#ideate(separator: heading.where(level: 2))` — that is the
wrong shape for the document the mode exists for. The separating heading stays
inside the note's body as its first line, the note has no title, and it has no
name either: its id is the package counter's next number, so a chapter of six
`==` sections mints six numbered notes, mints their pages at `ideas/169.html` …
`ideas/174.html`, and a consumer listing them (`#ideas()`, `@rookery/pinboard`)
has nothing to label them with but the first sixty characters of each body.
Insert a section at the top and every number after it shifts, which moves every
minted page and breaks every link into one.

This bird gives `#ideate` two sentinel spellings, so a heading-separated document
mints notes TITLED and NAMED by their own headings:

    #show: ideate.with(separator: heading.where(level: 2), title: heading, name: heading)

`== Literate programming` then mints a note whose `title:` is
`[Literate programming]` and whose id is `idea:literate-programming`, with the
heading itself removed from the note's body — `#idea` renders `title` as the
note's own heading, so leaving it in the body would print it twice.

Touches: core/0.1.0/src/ideate.typ, core/0.1.0/src/pure.typ, core/0.1.0/test/units.typ, core/0.1.0/readme.md, core/0.1.0/demo/rheo/content/ideated.typ, core/0.1.0/demo/rheo/check.sh

## The design, already decided

`title:` and `name:` are NEW NAMED PARAMETERS on `#ideate`, each accepting the
element function `heading` as a sentinel value. That spelling was chosen over a
parameter of its own (`title-from: "heading"`, say) because `separator:` already
takes `heading.where(level: 2)`: a document that says
`separator: heading.where(level: 2), title: heading` reads as one idea stated
twice rather than as two unrelated conventions. `heading` is safe as a sentinel
because a title is otherwise CONTENT and a name is otherwise a string or a
label — an element function is never a legal value for either, so nothing
ambiguous is being overloaded.

- **`title:`** — `none` (the default, and today's behaviour), any CONTENT (one
  fixed title forwarded to every note, which is what passing `title:` through
  the `..args` sink does today and must go on doing), or the sentinel `heading`.
- **`name:`** — `auto` (the default: the package counter, today's behaviour) or
  the sentinel `heading`. Nothing else is legal: a fixed string would mint every
  note in the body under one id.

Both sentinels are HEADING MODE ONLY. With `separator: par` or `separator: none`
there is no heading to read, so either sentinel there is a mistake and panics,
exactly as a malformed `separator:` already panics.

## Steps

1. `core/0.1.0/src/pure.typ` — add a pure helper `_slug(s)` taking a `str` and
   returning a `str`: lowercased, every run of characters outside `[a-z0-9]`
   replaced by a single `-`, leading and trailing `-` trimmed. So
   `"The Art of Computer Programming"` -> `"the-art-of-computer-programming"`
   and `"WEB and the two tangles"` -> `"web-and-the-two-tangles"`. Keep it pure
   (no `context`, no state) like everything else in that file — that is what
   lets `core/0.1.0/test/units.typ` call it directly.

   An EMPTY slug (a heading of nothing but punctuation) is a caller error, not a
   silent id. Panic, naming the heading's plain text and saying to retitle the
   section or drop `name: heading`.

2. `core/0.1.0/src/ideate.typ:247` — add `title: none, name: auto` to the
   `#ideate` signature, BEFORE the `..args` sink. That is what stops `title:`
   flowing through the sink; step 4 forwards it again by hand.

3. In the same function, in the block that classifies `separator:` (it binds
   `none-mode`, `heading-elem`, `heading-sel`, `heading-mode` and `par-mode`,
   and panics on anything else, ending just above the `mint` binding at line
   298), classify the two new arguments too:

       let title-from-heading = type(title) == function and title == heading
       let name-from-heading = type(name) == function and name == heading

   Then two panics, written in the voice of the `separator:` panic directly
   above them — name the offending value with `repr`, say what the legal
   spellings are, and say why:

   - `name` is neither `auto` nor the sentinel: a fixed name would mint every
     note in this body under one id.
   - either sentinel is used while `heading-mode` is false: both read the
     heading that STARTS each note, so they need
     `separator: heading.where(level: 2)` (or another level); with the
     separator actually given there is no heading to read.

   Classify BEFORE the single-paragraph early return
   (`if not body.has("children") { return mint(body) }`), for the same reason
   `separator:` is classified there: a bad argument must be rejected even on a
   body with nothing to split.

4. Line 298 — change the `mint` binding so the sentinel is never forwarded to
   `#idea`, which would try to render an element function as a title:

       let mint = idea.with(
         show-frame: show-frame,
         show-id: show-id,
         ..(if title-from-heading { (:) } else { (title: title) }),
         ..args,
       )

   Forwarding `title: none` explicitly is identical to today's behaviour:
   `#idea`'s own default for that argument is already `none`.

5. The emit loop is `core/0.1.0/src/ideate.typ:360-369`; the branch to change is
   the `mint(group.join())` at line 367. A group's own separating heading is its
   first non-blank child — heading mode pushes the matching heading into the
   FRESH group (line 327 and the lines under it), so it leads every group except
   the preamble group, which has no heading at all.

   - Find it: the first child `c` of `group` with `not _blank(c)` (`_blank` is
     defined in this same file, above `_heading-only` at line 146); use it only
     if `c.func() == heading and _level-of(c) == want` (`_level-of` is at line
     198, and reads `level` or `depth` — a markup heading carries `depth`, so do
     not compare `level` directly).
   - If there is no such heading — the preamble group — mint the group exactly
     as today, whatever the sentinels say.
   - The note's BODY is the group with that one child removed. Remove it BY
     POSITION, not by value: two sections can carry identical headings.
   - When `title-from-heading`, pass `title: h.body` — the heading's own
     CONTENT, not its plain text, so emphasis or a `#ref` in a heading survives
     into the title.
   - When `name-from-heading`, pass the slug as `#idea`'s POSITIONAL argument
     (`idea(_slug(..), title: .., ..)`); `#idea` takes a name that way, through
     its own `..args` sink.
   - The heading's PLAIN TEXT for the slug comes from the path `#ideas()`
     already uses: `core/0.1.0/src/data.typ:285-286` binds
     `let ref-text = _ref-text(reg)` and `let plain = c => _plain-with(c, ref-text)`,
     and line 301 calls `plain(..)` to fill a row's `text` field. `#ideate`'s
     body is already inside a `context`, so `_registry.final()` is readable for
     the `reg` that `_ref-text` needs. Reusing that path is what makes a heading
     carrying a `#ref` slug to the referenced note's name instead of to nothing.

6. Two sections in one `#ideate` call that slug to the SAME name panic rather
   than minting two notes under one id: keep the slugs seen so far in a local
   array and panic on a repeat, naming both headings and saying to retitle one.
   Within one call only — see the non-goals.

7. `core/0.1.0/readme.md` — document both parameters inside the `#ideate`
   section (lines 530-686), beside the `separator:` table at 586-600, with the
   one-line example from the top of this bird. Say plainly that the heading
   LEAVES the body when `title: heading` is on, and that ids minted from
   headings survive inserting and reordering sections, which is the reason to
   prefer them.

8. `core/0.1.0/test/units.typ` — cover `_slug` directly, beside the existing
   ideate predicate tests at lines 524-569: ordinary words, mixed case,
   punctuation, leading and trailing separator runs. Note that file's own
   constraint, stated in its comment at line 524: `#ideate` itself cannot be
   asserted there, because it passes its body straight through on a paged
   target. Only pure helpers go in this file; the end-to-end check is step 9.

9. `core/0.1.0/demo/rheo/` — add a NEW fixture page `content/ideated.typ` whose
   whole body is a `#show: ideate.with(separator: heading.where(level: 2),
   title: heading, name: heading)` and three `==` sections, and add assertions
   for it to `check.sh`: a page minted at `ideas/<slug>.html` for each section,
   and each heading's text appearing exactly once in the note's own page. Run
   the whole script afterwards, not only the new assertions — some of its
   existing checks count notes across the demo and will need their numbers
   moved.

## Non-goals

- Do NOT change `separator: par` or `separator: none` behaviour in any way.
  Neither sentinel is legal there, and step 3 is where that is settled.
- Do NOT dedupe names across separate `#ideate` calls, or across the document.
  Step 6 is one call's own slugs and nothing more. A second chapter with a
  section of the same name is a real collision, and it is left for a later
  bird — do not invent a numbering suffix for it here.
- Do NOT touch `#idea`'s signature (`core/0.1.0/src/idea.typ`), its counter, or
  its registry.
- Do NOT change `#ideate`'s `show-frame: false` / `show-id: false` defaults. A
  titled note still renders with no frame and no permalink unless the caller
  asks for them, exactly as today.
- Do NOT add a `tags:` parameter to `#ideate` and do NOT read labels off
  headings. That is a separate bird, and it edits the same region of this file.

## VERIFY

1. `cd core/0.1.0 && just test` passes — it compiles `test/units.typ` and
   `test/inputs.typ`, so the new `_slug` assertions run there.
2. `cd core/0.1.0/demo/rheo && just check` passes, including the new assertions
   from step 9: three pages minted under `ideas/` named after the headings'
   slugs, not numbers.
3. A body of `==` sections compiled WITHOUT the two new arguments still produces
   exactly what it produces today — numbered ids, heading inside the body. The
   rest of `check.sh` passing is this assertion.
4. `#ideate(separator: par, title: heading)[..]` fails the compile with the
   step-3 panic, and `#ideate(title: [Fixed])[..]` still gives every note the
   title `Fixed`. Check both by hand with
   `typst compile --features html --root . --format pdf <scratch file> /dev/null`
   from `core/0.1.0`; they are compile-time panics and cannot be asserted from
   inside a passing document.