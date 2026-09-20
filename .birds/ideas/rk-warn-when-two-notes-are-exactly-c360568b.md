---
id: rk-warn-when-two-notes-are-exactly-c360568b
short-id: c3
title: Warn when two notes are exactly identical
priority: 3
labels:
- fix-content-derived-names
deps:
- blocked-by:rk-fail-the-build-on-two-notes-sharing-a-e9f4de62
closed: true
---
Touches: core/0.1.0/src/transclusion.typ, core/0.1.0/src/validate.typ

Two notes with byte-identical body, title, tags, level and display resolve to
the same name and merge into one. That is almost never what the author meant —
a real site carries exactly this, the same reading-list line written twice:

```typ
#todo[Gillian Rose, _Hegel and Sociology_.]
```

The bundle-root uniqueness check cannot catch it, because identical payloads
are also what a REPLAY looks like: a note legitimately appears on its authoring
vertebra, on its marrow-minted page, and inside every `#window` transcluding
it. Emit a warning for the genuine case by counting call sites rather than
placements.

All paths relative to `/home/lox/code/_fcl/rookery/core/0.1.0`.

## The mechanism, and the fact it rests on

VERIFIED on typst 0.15.1: a show rule that replaces an element does NOT hide it
from `query()`. So `query(figure.where(kind: IK))` returns every PLACEMENT of
every note — originals and transcluded rebuilds alike — and a count alone
cannot tell them apart.

The asymmetry to exploit: a transcluded note is rebuilt by `_flatten`'s IK show
rule, and an original is not. Anchor:

```
rg -n 'show figure.where\(kind: IK\)' src/
```

One hit, `src/transclusion.typ:378`, inside `_flatten`. If that rule stamps its
output, then for a given id:

```
genuine call sites = placements − stamps
```

and two or more genuine sites under one id, with identical payloads, is exactly
the warnable case.

**This rests on one unverified claim: that EVERY replay of a note's body goes
through that IK rule — the `#window` path, the nested-transclusion path, and
the marrow-minted page alike.** Step 1 is to check it. If it does not hold, the
count will be wrong and the warning must not ship; see "If the claim fails".

## 1. Check the claim first

Build the rheo demo and count, for one note that is known to be both authored
and minted:

```
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check
```

Then add a temporary `#context` block at bundle root that prints, for each id,
the number of `query(figure.where(kind: IK))` hits. Compare against the number
of places that note actually appears in the built HTML. Record what you found
in your report, whichever way it comes out, and REMOVE the temporary block.

## 2. Stamp the rebuild

In the IK rule at `src/transclusion.typ:378`, emit a marker alongside the
rebuilt note carrying the id it is a replay of:

```typ
[#metadata((rookery-replay: id)) <rookery-replay>]
```

`id` is already in scope there — anchor
`rg -n 'let id = v.at\("id", default:' src/` — one hit,
`src/transclusion.typ:387`.

A `metadata` element renders nothing, so this changes no output. Comment it for
what it is: a count of replays, which is what lets the bundle-root check tell a
transclusion from a second authoring of the same content.

## 3. Warn in `_assert-unique-names`

`src/validate.typ` already groups placements by id and compares payloads; a
previous bird built it. Anchor:

```
rg -n 'let _assert-unique-names' src/
```

One hit. Extend it: for an id whose payloads are all EQUAL, compute

```
placements − query(<rookery-replay>) entries naming that id
```

and when the result is 2 or more, emit a `warning` — not a panic — naming the
id and describing the note, and saying that two identical notes have merged
into one and that pinning a name on one of them separates them.

Typst has no `warning()` builtin. Use the project's existing convention for a
non-fatal diagnostic if there is one (`rg -n 'warn' src/` to check); if there
is none, emit the message as content into the document through the same channel
the package already uses for build-time notices, and say in your report which
you chose and why.

## If the claim fails

If step 1 shows that some replay path does NOT go through the IK rule — so
`placements − stamps` is not the call-site count — do NOT ship a warning that
fires on replays. Leave `src/validate.typ` as it is, revert any stamp you added,
and report the finding with the numbers you measured. A wrong warning on every
transcluded note is far worse than no warning.

## NON-GOALS

- Do NOT panic on this case. Identical notes still get one name and still
  merge; the build must succeed. Only the uniqueness ERROR from the previous
  bird fails a build.
- Do NOT try to give two identical notes distinct names. Nothing distinguishes
  them but position, and position is what this whole design removes.
- Do NOT touch `src/idea.typ`, `src/state.typ` or `src/pure.typ`.
- Do NOT change what `_flatten` renders. The stamp is a `metadata` element and
  must alter no visible output.

## VERIFY

1. Output is unchanged by the stamp:

   ```
   cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/pure && just build
   cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check
   ```

   both pass, printing `demo/pure OK` and the rheo demo's own OK line.

2. A transcluded note produces NO warning. The rheo demo already transcludes;
   its `just check` output must contain no duplicate-note warning.

3. Two identical notes produce exactly one warning. In a scratch file outside
   the repo, at `/tmp/rookery-dup.typ`:

   ```typ
   #import "/src/lib.typ": rookery, idea
   #show: rookery
   #idea[Gillian Rose, Hegel and Sociology.]
   #idea[Gillian Rose, Hegel and Sociology.]
   ```

   ```
   cd /home/lox/code/_fcl/rookery/core/0.1.0 && typst compile --features html \
     --root . --format pdf /tmp/rookery-dup.typ /dev/null
   ```

   reports the duplicate once and still exits 0. Remove the scratch file after.