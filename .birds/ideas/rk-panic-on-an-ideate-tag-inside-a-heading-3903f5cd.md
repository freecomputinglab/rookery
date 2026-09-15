---
id: rk-panic-on-an-ideate-tag-inside-a-heading-3903f5cd
short-id: '39'
title: Panic on an ideate-tag inside a heading
priority: 2
labels:
- fix-ideate-tag-nested-beacon
deps: []
closed: true
---
Touches: core/0.1.0/src/ideate.typ

`#ideate` finds an `#ideate-tag` beacon by folding over a group's TOP-LEVEL
children, at `/home/lox/code/_fcl/rookery/core/0.1.0/src/ideate.typ:496-500`. A
beacon written INSIDE the section heading —

```typst
== Literate programming #ideate-tag("dissertation")
```

— is nested in the heading's body, never reaches that fold, and is dropped
silently. The section mints UNTAGGED, with no error, no warning, and a
correct-looking title. Make it loud.

## Why this is worth a panic

The failure is invisible at every level an author can see. `_strip-beacons`
(`ideate.typ:196`) runs at the group level, so it does not remove the nested
beacon from the heading either — yet the rendered title still looks right,
because a `metadata` element draws nothing. So the author gets the title they
wanted and a tag that does not exist.

And the consequence is not cosmetic. A section that fails to carry its tag is
absent from `tags-of`, from `#window(tags: ..)` selections, and from
`@rookery/search`'s tag index — not merely missing a pill. On
weeknotes.ohrg.org this had already happened: `content/26w37.typ:100` reads
`== Literate programming #ideate-tag("dissertation")`, and that section shipped
outside the `dissertation` thread entirely.

Typst gives a package no warning channel, so the only signal available is a
`panic` that names the offender.

## REJECTED ALTERNATIVE — honouring the nested beacon

Scanning the lead heading's body and stripping the beacon out of the title would
make that line WORK, which is what an author writing it expects. It loses for a
concrete reason: it silently changes what `title:` and `name:` receive for every
existing document carrying such a beacon, and `name:` is commonly a slug of the
heading content — so a section's id, and therefore its published page URL, could
move under an author who changed nothing. A panic moves no URL and asks the
author to move one line down. Do not implement the alternative.

## Steps

1. In `/home/lox/code/_fcl/rookery/core/0.1.0/src/ideate.typ`, insert the guard
   between the `fn-tags` binding and the beacon fold. The anchor: `fn-tags` ends
   with `} else { (:) }` on line 491, and line 493 opens the comment
   `// Scan the group for `#ideate-tag` metadata beacons and union their values`.
   The guard goes in that gap, and `lead-heading` is already in scope (it is read
   at line 489).

   ```typst
   // A beacon inside the heading never reaches the fold below, so the section
   // would mint untagged with nothing to say a tag was asked for.
   if lead-heading != none {
     let hb = lead-heading.body
     let kids = if hb.has("children") { hb.children } else { (hb,) }
     if kids.any(c => _ideate-tag-value(c) != none) {
       panic(
         "@rookery/core: #ideate-tag inside a heading is never read — move it to "
           + "its own line BENEATH the heading, as a sibling. Heading: "
           + repr(hb),
       )
     }
   }
   ```

   `_ideate-tag-value` is defined at `ideate.typ:187` and returns `none` for a
   child that is not a beacon, so it is the right predicate and needs no new
   helper. `repr(hb)` rather than a stringified title: the body is arbitrary
   content, and `repr` is the only form guaranteed to render.

2. Nothing else changes. The fold at `ideate.typ:496-500` and `_strip-beacons`
   at `:196` both stay exactly as they are.

## VERIFY

The guard must not fire on anything the demo already contains, and the whole
suite must stay green. Requires the `rheo` binary for the first command, because
`demo/rheo/rheo.toml` resolves `@rookery` with a `path` source and `path` landed
in rheo 0.6.3 — check `rheo --version` first and stop if it reads lower.

```bash
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check
cd /home/lox/code/_fcl/rookery/core/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/pure && just build
```

`just check` must print `demo/rheo OK`. Two of its assertions bear directly on
this change and must both stay green:

- `check.sh:590-591` — `ideas/rookery.html` carries `idea-tag-rookery` from a
  correctly-placed sibling beacon. The guard must not reject the valid shape.
- `check.sh:602-607` — `== Testing edge cases <sec:one>` carries a LABEL on the
  heading, and the script asserts "no extra tag, no panic". A label is not a
  metadata beacon, so `_ideate-tag-value` returns `none` for it and the guard
  stays silent. If this one trips, the guard is matching too broadly.

Then confirm the panic actually fires. Typst cannot catch a panic, so this is a
throwaway edit rather than a committed fixture: temporarily append
`#ideate-tag("x")` to the end of the `== Literate programming` heading at
`/home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo/content/ideated.typ:16`, run

```bash
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just build
```

and confirm it FAILS with a message containing `#ideate-tag inside a heading`.
Then restore line 16 to exactly `== Literate programming` and re-run `just check`
to confirm it prints `demo/rheo OK` again.

Report the panic message you saw. If the throwaway edit proves awkward, say so
in the report rather than skipping it silently — the three `just` commands above
passing is not on its own evidence that the guard fires.

## Non-goals

- **Do not add a permanent demo fixture for the panic.** A committed nested
  beacon would fail `demo/rheo`'s build by design, which is the opposite of a
  test. The throwaway edit in VERIFY must be reverted.
- **Do not make the nested beacon work.** See the rejected alternative above.
- **Do not touch `_strip-beacons` (`ideate.typ:196`) or the fold
  (`ideate.typ:496-500`).**
- **Do not extend the guard to labels.** `<tag:x>`-style labels on a heading are
  a CONSUMING PROJECT's convention, read through `#ideate`'s own `tags:` function
  argument, and are none of this guard's business.
- **Do not edit `core/0.1.0/readme.md`, `check.sh`, or `core/0.1.0/typst.toml`.**