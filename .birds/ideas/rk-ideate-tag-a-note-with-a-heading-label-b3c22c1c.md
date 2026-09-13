---
id: rk-ideate-tag-a-note-with-a-heading-label-b3c22c1c
short-id: b3
title: 'Ideate: tag a note with a heading label'
priority: 2
labels:
- feat-ideate-tag-labels
deps:
- blocked-by:rk-ideate-heading-as-title-and-name-44e0753c
closed: true
---
A `#ideate` call tags every note it mints identically: `tags:` flows through the
`..args` sink at `core/0.1.0/src/ideate.typ:247` into the `mint` binding at line
298, which is built once above the group loop. A document that wants ONE of its
sections tagged differently from the rest has no way to say so short of pulling
that section out and writing `#idea` by hand.

This bird makes a LABEL on the separating heading say it:

    == Rookery <tag:rookery>

mints that section's note carrying the tag `rookery`, in ADDITION to whatever
the `#ideate` call's own `tags:` already puts on every note. Nothing else about
the heading changes.

Touches: core/0.1.0/src/ideate.typ, core/0.1.0/src/pure.typ, core/0.1.0/test/units.typ, core/0.1.0/readme.md, core/0.1.0/demo/rheo/content/ideated.typ, core/0.1.0/demo/rheo/check.sh

## Blocked by the `title:`/`name:` bird — what it leaves behind

This bird is blocked by the bird that adds `title: heading` / `name: heading` to
`#ideate`, because both edit the same two places: the signature at line 247 and
the `mint(group.join())` branch of the emit loop at line 367. Do not start this
one until that one has landed, and read the file rather than this paragraph for
the exact shape it left.

What matters here is that it puts code in that branch which FINDS the group's
separating heading — the group's first non-blank child, used only when it is a
`heading` whose `_level-of` (line 198) equals the separator's level. This bird
reuses that same heading; it does not find it a second way. If that code is not
there when you open the file, stop and say so rather than writing a second
finder.

## Facts, MEASURED on typst 0.15.1

Nothing in this repository reads a Typst label off a content element today —
every `.at("label")` in the tree is a dictionary key on a registry record, not
a label — so these were probed directly rather than copied from an existing
pattern:

- `== One <tag:rookery>` puts the label on the HEADING element, and
  `c.at("label", default: none)` on that child of the body's `children` returns
  it. An unlabelled heading returns `none`. The label does not change the
  heading's `func()`, its position among the children, or its `body`.
- `str(<tag:rookery>)` is the string `"tag:rookery"`. That is the only way in;
  a label has no accessors.
- TWO headings carrying the SAME label compile and render without error. Only a
  `#ref` to a repeated label is an error, and nothing writes one here — so two
  sections tagged `<tag:rookery>` is the normal case, not a hazard.

## The design, already decided

- **Only the `tag:` prefix is special.** A heading labelled `<my-anchor>` or
  `<sec:intro>` is untouched and keeps meaning what it means to Typst. The
  prefix IS the opt-in, which is why this needs no boolean parameter to switch
  it on: a second knob would exist for a namespace nothing else in the repo
  uses.
- **The tag is everything after the FIRST colon.** `<tag:a:b>` means the tag
  `a:b`. One rule, no second parse.
- **The label tag is ADDED to the call's `tags:`, never replaces it.** A chapter
  minted with `#ideate(.., tags: ("chapter", "knuth"))` whose section is
  labelled `<tag:rookery>` mints a note tagged all three.
- **No charset validation.** `#idea(tags: ..)` validates the SHAPE of `tags:`
  (`_assert-tags`, `core/0.1.0/src/pure.typ:717`) and never the characters in a
  tag name, and Typst's own label syntax already bounds what can appear here.
  Do not add a rule core does not otherwise have.
- **Heading mode only, and silent everywhere else.** With `separator: par` or
  `separator: none` there is no separator element to carry a label, so a
  `<tag:x>` written in such a body is ordinary Typst and is left alone. Not a
  panic: it is not a mistake, just a label.

## Steps

1. `core/0.1.0/src/pure.typ` — add a pure helper `_label-tag(l)` taking a
   `label` or `none` and returning the tag name as a `str`, or `none`:
   `none` in, `none` out; a label whose `str()` does not start with `tag:`,
   `none` out; otherwise everything after the first colon. A label that is
   exactly `<tag:>` (nothing after the colon) returns `none` too — an empty tag
   name is not a tag. Pure, no context, like the rest of that file, so
   `test/units.typ` can call it.

2. `core/0.1.0/src/ideate.typ:247` — add `tags: ()` to the `#ideate` signature,
   BEFORE the `..args` sink, capturing what today flows through it. Normalize it
   once, beside the `separator:` classification block: `let base-tags =
   _norm-tags(tags)` (`_norm-tags` is `core/0.1.0/src/pure.typ:72`; it turns
   `none`, a string, an array or a dictionary into a dictionary, and it is the
   same function `#idea` itself calls at `core/0.1.0/src/idea.typ:56`, so a
   dictionary handed on from here is exactly what `#idea` would have built).

3. Line 298, the `mint` binding — pass `tags: base-tags` explicitly, since
   `tags:` no longer rides the `..args` sink. Every note minted by a group with
   no label on its heading must come out tagged exactly as it is today.

4. In the emit loop's `mint(group.join())` branch (line 367, as the blocking
   bird leaves it), where the group's separating heading is already in hand:
   read `_label-tag(h.at("label", default: none))`. When it is not `none`, mint
   that group with `tags: base-tags + ((that tag): none)` instead of
   `base-tags` — the `none` VALUE is what makes it a flat tag rather than a
   valued one, which is the shape `#idea`'s own `tags: "x"` produces.
   A group with no heading (the preamble group) and a heading with no `tag:`
   label both keep `base-tags` unchanged.

5. `core/0.1.0/readme.md` — document it in the `#ideate` section (lines
   530-686), near where that section already talks about `tags:` (lines 639 and
   672). Show `== Rookery <tag:rookery>`, say the tag is added to the call's own
   `tags:`, say that only the `tag:` prefix is claimed and every other label is
   left alone, and say that one Typst element carries at most one label — so a
   section wanting two extra tags is a section that wants `#idea` written out by
   hand.

6. `core/0.1.0/test/units.typ` — assert `_label-tag` directly, beside the
   existing ideate predicate tests at lines 524-569: a `tag:`-prefixed label, a
   label with another prefix, a bare label with no colon, `<tag:>` itself,
   `none`, and a label with two colons (which yields a tag containing a colon).
   That file cannot call `#ideate` itself — see its comment at line 524 — which
   is why step 7 exists.

7. `core/0.1.0/demo/rheo/` — extend the fixture page `content/ideated.typ` (the
   blocking bird adds it) with one section whose heading carries a `<tag:..>`
   label, and assert in `check.sh` that the minted note carries the tag: the
   note's own page and its card wear the `idea-tag-<tag>` class, which is how
   every other tag assertion in that script is written. Run the whole script
   afterwards, not only the new assertion.

## Non-goals

- Do NOT make the `tag:` prefix configurable, and do NOT add a parameter to
  switch this behaviour on or off. The prefix is the opt-in.
- Do NOT read labels off anything but the separating heading — not off a
  paragraph, not off a non-matching heading level inside a group, not off the
  body's other children.
- Do NOT support VALUED tags through a label (`<tag:priority=3>` or similar).
  A label-derived tag is flat, value `none`. A valued tag is what `tags:` on the
  call, or `#idea` written by hand, is for.
- Do NOT strip the label from the heading when the heading stays in the body.
  A repeated label is harmless (measured above), and content cannot be relabelled
  in place anyway.
- Do NOT touch `#idea`, `_visible-tags` (`core/0.1.0/src/state.typ:290`) or the
  themed-tag rules (`core/0.1.0/src/theme.typ:151`). A tag arriving this way is
  an ordinary tag from that point on, and every one of those already handles it.

## VERIFY

1. `cd core/0.1.0 && just test` passes, including the new `_label-tag`
   assertions.
2. `cd core/0.1.0/demo/rheo && just check` passes, including the step-7
   assertion that the labelled section's note carries the tag.
3. A section whose heading carries NO label, in the same fixture, still comes
   out with exactly the call's own `tags:` — the rest of `check.sh` passing is
   this assertion.
4. In the same fixture, a heading labelled with a NON-`tag:` label (`<sec:one>`,
   say) mints a note with no extra tag and still compiles — no panic, no
   `idea-tag-sec` class in the output.