---
id: rk-name-a-dateless-meeting-after-its-d86aa00b
short-id: d8
title: Name a dateless meeting after its participants
priority: 3
labels:
- fix-meeting-autoname-collision
deps: []
closed: true
---
Touches: meetings/0.1.0/src/lib.typ, meetings/0.1.0/test/units.typ, meetings/0.1.0/readme.md

An untitled `#meeting` that names participants but no date mints the id
`idea:meeting-with`, whatever the participants are. Two such meetings anywhere
in one project therefore collide and kill the build.

## The defect, measured

Observed on the site at `/home/lox/code/waterline`, whose spine has two such
meetings:

```
panicked with: @rookery/core: duplicate note id idea:meeting-with — already
registered in clusters:digitaltheory:pragma:meetings, registered again in grad
```

One of the two is `rookery/grad/index.typ:33` in that project:

```typ
#meeting(with: (<case-holly>, <stewart-william-joseph>))[
```

No `on:`, no title, no name. Its id is `idea:meeting-with`, and so is the id of
every other dateless untitled meeting in the project.

## Why the id collapses

Three facts, each verified in the source:

1. An untitled meeting with participants and NO date takes the derived title
   `[Meeting with #_refs(who)]`. Anchor, one hit:

   ```
   rg -n 'title: \[Meeting with #_refs\(who\)\]' /home/lox/code/_fcl/rookery/meetings
   ```

   printed `meetings/0.1.0/src/lib.typ:216`, inside the `derived` binding of
   the `meetings()` factory.

2. `_refs` turns each participant into a Typst `ref`. Anchor, one hit:

   ```
   rg -n 'let _refs\(who\)' /home/lox/code/_fcl/rookery/meetings
   ```

   printed `meetings/0.1.0/src/lib.typ:78`:
   `#let _refs(who) = who.map(n => ref(label("idea:" + n))).join(", ")`.

3. `@rookery/core` derives a note's id slug from the title's PURE plain-text
   projection, and that projection renders every `ref` as the empty string.
   Anchors, one hit each:

   ```
   rg -n '_id-slug\(_plain\(title\)\)' /home/lox/code/_fcl/rookery/core
   rg -n '_plain\(c\) = _plain-with' /home/lox/code/_fcl/rookery/core
   ```

   printed `core/0.1.0/src/idea.typ:260` and `core/0.1.0/src/pure.typ:369`
   (`#let _plain(c) = _plain-with(c, _ => "")`). The comment above the second
   one names this exact case: "where `_plain` alone leaves `Meeting with `".

So the title is fine — a reader sees "Meeting with Holly Case, William Joseph
Stewart" — while the id sees `Meeting with `, slugged to `meeting-with`.

A meeting WITH a date escapes this by accident: its title
(`meetings/0.1.0/src/lib.typ:214`) also carries the date as literal text, so
the plain projection keeps "on 11.3.25" and the slug stays distinct. That is
why only the dateless form collides.

## The fix

Give the dateless-with-participants case an explicit name built from the
participant names, which this package already holds as plain strings — `_who`
(`meetings/0.1.0/src/lib.typ:68-72`) maps each entry through `core._norm`, and
`_refs` above proves they are strings by concatenating them into a label.

`#meeting(with: (<case-holly>, <stewart-william-joseph>))` becomes
`idea:meeting-with-case-holly-stewart-william-joseph`.

This was chosen over a counter (`meeting-with-1`, `meeting-with-2`) on
purpose. A counter is position-dependent: inserting one meeting earlier in the
spine renumbers every later one and silently moves their published URLs.
`core/0.1.0/src/idea.typ:256-259` records that core removed exactly such a
suffix for that reason. A name built from participants is intrinsic to the
note, so it is stable whatever else the project gains or loses.

## Steps

1. Find the mint call at the end of the `meetings()` factory. Anchor, one hit:

   ```
   rg -n 'if name == none \{' /home/lox/code/_fcl/rookery/meetings
   ```

   printed `meetings/0.1.0/src/lib.typ:246`. It reads:

   ```typ
   if name == none {
     mint(tags: all-tags, created: resolved-created, ..derived, ..args.named(), full)
   } else {
     mint(name, tags: all-tags, created: resolved-created, ..derived, ..args.named(), full)
   }
   ```

2. Just above that branch, derive a name for the one case that needs it. `who`
   and `stamp` are both already in scope there — `who` is bound at the anchor
   `rg -n 'let who = _who\(with\)'` (one hit, `meetings/0.1.0/src/lib.typ:145`)
   and `stamp` a few lines above `derived`. Add:

   ```typ
   // A dateless meeting's derived title is refs and nothing else, and a ref
   // contributes no text to the pure plain-text projection core slugs an id
   // from — so every such meeting would mint `idea:meeting-with` and the
   // second one would collide. The participants are the note's own content,
   // so they name it: stable wherever the meeting sits in the spine, unlike a
   // counter.
   let auto-name = if name == none and who.len() > 0 and stamp == none {
     core._id-slug("meeting-with-" + who.join("-"))
   } else {
     none
   }
   ```

3. Use it in the branch from step 1: where `name == none` and `auto-name !=
   none`, call `mint(auto-name, ..)` exactly as the `else` arm calls
   `mint(name, ..)`. Where both are `none`, leave today's no-positional call
   untouched — the comment above that branch
   (`meetings/0.1.0/src/lib.typ:244-246`) explains that passing `none` in front
   of the body is read by `#idea` as the name, so it must stay absent, not
   become `none`.

4. Add a case to `meetings/0.1.0/test/units.typ` asserting the derived name,
   following whatever the fixtures there already do to assert a derived value
   (that file asserts every value `#meeting` derives — tags, date, synthesized
   title). Assert that two dateless meetings with DIFFERENT participants mint
   different ids, and that a meeting with `on:` keeps the id it has today.

5. Note the new behaviour in `meetings/0.1.0/readme.md`, wherever that file
   documents what an untitled meeting is called. One or two sentences: a
   dateless meeting with participants is named after them, and why.

## Non-goals

- **Do not change the DATED branch** (`meetings/0.1.0/src/lib.typ:214`). Its
  ids are in use as published URLs in at least one project; renaming them to
  match this scheme would move every one of them. Two meetings with the same
  participants on the same day still collide — that is a known, deliberate
  residual, and belongs to a separate bird, not this one.
- **Do not change the derived TITLE text.** A reader must still see the
  resolved participant names. Only the id changes.
- **Do not edit anything under `core/0.1.0/`.** That core panics rather than
  disambiguating a duplicate id is deliberate and is being reconsidered
  separately; this bird removes one cause of a collision, not the panic.
- **Do not add a counter or a `-1`/`-2` suffix.** See "The fix" for why.
- **Do not edit anything in `/home/lox/code/waterline`.** That project found
  the bug; it is not part of this change.

## Uncertainty, and the fallback

`core._id-slug` is reached the same way this file already reaches `core._norm`
and `core._merge-base-tags`, so the private member is available — but confirm
it with `rg -n '_id-slug' /home/lox/code/_fcl/rookery/core` before relying on
it. If it is not importable from here, slug the joined string with whatever
`_who` already normalised the names to (they are note names, already
hyphen-safe) and say in your report that you did so.

If `who` turns out to hold something other than strings at this point, stop
and report it rather than coercing — `_refs` concatenating them into
`label("idea:" + n)` is the evidence that they are strings, and if that is
wrong the whole approach needs rethinking.

## VERIFY

1. From `meetings/0.1.0/`, `just test` passes, including the case added in
   step 4.
2. From `meetings/0.1.0/`, whatever `just` recipe drives `test/check.sh`
   passes, unchanged in behaviour from before this bird.
3. `rg -n 'meeting-with-' meetings/0.1.0/src/lib.typ` shows the new name
   derivation, and `rg -n 'title: \[Meeting with #_refs\(who\) on #stamp\]'`
   still shows the dated branch untouched.
4. From the repository root, `just check-versions` still prints its OK line.