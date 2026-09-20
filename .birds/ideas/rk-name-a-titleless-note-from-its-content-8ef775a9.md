---
id: rk-name-a-titleless-note-from-its-content-8ef775a9
short-id: 8ef
title: Name a titleless note from its content
priority: 5
labels:
- fix-content-derived-names
deps:
- blocked-by:rk-name-helpers-content-slug-and-digest-36190351
closed: true
---
Touches: core/0.1.0/src/idea.typ, core/0.1.0/src/state.typ, core/0.1.0/src/transclusion.typ

A titleless note is currently named by a container ordinal — its position among
its siblings — and position is destroyed by replay. `#window` re-renders a
note's body wherever it is placed and a marrow-minted page renders it again, so
an ordinal answers for whichever copy won that compile attempt. On a real site
this stops the document converging at all.

Name a titleless note from its own content instead, and delete the container
machinery outright.

All paths below are relative to `/home/lox/code/_fcl/rookery/core/0.1.0`, and
every `rg` is meant to be run from there.

## What you are given

A previous bird added three pure helpers to `src/pure.typ`, already exported
through `src/lib.typ` and already unit-tested:

- `_name-slug(s, limit: 16)` — plain text to a short slug, or `none`. Slugs a
  leading URL from its tail, drops leading stopwords, strips a leading
  `https-`/`http-`/`www-`, and takes whole words up to the limit.
- `_h3(s)` — three lowercase base36 characters, a djb2 digest.
- `_b36(n, width)`.

Confirm they are there before starting:

```
rg -n 'let _name-slug|let _h3' src/pure.typ
```

Two hits expected. If they are absent, STOP and report — this bird cannot be
done without them.

## The ladder after this change

1. pinned name — `#idea(<etal>, ..)` — `idea:etal`
2. title slug — `_id-slug(_plain(title))`, 60-char cap, unchanged
3. body slug + digest — `_name-slug(_plain(body)) + "-" + _h3(..)`
4. neither — **panic**

## 1. Replace the container branch in the main mint

Anchor:

```
rg -n 'let container = if not named' src/
```

One hit, `src/idea.typ:276`,
`let container = if not named and slug == none { _scope-peek() } else { none }`,
inside `#idea`. Delete that line.

Just above it, `src/idea.typ:271` (anchor `rg -n 'let slug = if not named' src/`,
one hit) computes the title slug. Leave it alone.

Below, `src/idea.typ:289` (anchor `rg -n 'let occupant = \(title:' src/`, one
hit) builds `occupant`, the tuple describing what this note IS. Leave it as it
is — you will reuse it.

Add, after `occupant` is bound:

```typ
let body-slug = if not named and slug == none { _name-slug(_plain(body)) } else { none }
```

## 2. Rewrite the id resolution

Anchor:

```
rg -n 'let id = if named' src/
```

One hit, `src/idea.typ:294`. The third arm currently destructures `container`
and builds `key + "-" + str(n)`. Replace the whole `let id = ...` expression
with three arms plus a panic:

```typ
let id = if named {
  _pfx() + base
} else if slug != none {
  _pfx() + slug + (if slug-n > 1 { "-" + str(slug-n) } else { "" })
} else if body-slug != none {
  _pfx() + body-slug + "-" + _h3(_digest-input(occupant))
} else {
  panic(
    "@rookery/core: this note has no name, no title, and a body that yields no "
      + "readable text, so no id can be derived for it. Give it a name — "
      + "`#idea(<some-name>, ..)` — or a `title:`.",
  )
}
```

Define `_digest-input(occupant)` next to the mint, or in `src/pure.typ` if it
fits better there:

```typ
#let _digest-input(o) = {
  let r = repr(o)
  // CAP the hashed string: cost is linear in body size, measured at roughly
  // 1.5 MB/s, so one very long body would otherwise be paid for on every note.
  // The true length rides along so two bodies sharing a 4096-byte prefix still
  // differ.
  (if r.len() > 4096 { r.slice(0, 4096) } else { r }) + "#" + str(r.len())
}
```

`slug-n` (anchor `rg -n 'let slug-n = if slug' src/`, one hit,
`src/idea.typ:293`) stays exactly as it is — rung 2 keeps its existing
occupant-list numbering.

## 3. Delete every `_scope` use

Nine sites. Run `rg -n '_scope' src/ .marrow.typ` and work through the hits;
many are comments, which must go too where they describe the deleted machinery.
The code sites:

| file | anchor | line at filing |
|---|---|---|
| src/state.typ | `state("rookery-idea-scope", ())` | 395 |
| src/state.typ | `#let _scope-peek() = {` | 415 |
| src/state.typ | `#let _scope-record(key) = {` | 451 |
| src/idea.typ | `let (key, _) = _scope-peek()` | 167 |
| src/idea.typ | `_scope-record(key)` (exclusion gate) | 168 |
| src/idea.typ | `_scope-record(key)` (main mint) | 310 |
| src/idea.typ | `s + ((key: own-id, n: 0),)` | 331 |
| src/idea.typ | `s.slice(0, -1) } else { s })` | 634 |
| src/transclusion.typ | `_scope.update(s => s + ((key: id, n: 0),))` | 525 |
| src/transclusion.typ | the matching pop just below | 527 |

Notes on three of them:

- **`src/idea.typ:165-169`, the exclusion gate.** The whole `context { ... }`
  block that peeks and records exists only so a dropped note still consumes its
  sibling's ordinal. With no ordinal, an excluded note shifts nobody. Delete the
  block and the comment above it explaining why it was needed.
- **`src/idea.typ:330-331`.** `own-id` is computed solely to key the pushed
  container. Delete both the `let own-id = ...` line and the `_scope.update`.
- **`src/transclusion.typ:525,527`.** A push/pop pair around a transcluded
  body, for the same reason. Both go.

After this, `rg -n '_scope' src/ .marrow.typ` must return NOTHING — including
comments. `.marrow.typ:440,445,457,462` carry comment-only mentions; rewrite
those comments so they describe what the code does now, and do not leave a
sentence explaining a mechanism that no longer exists.

Do NOT touch `_slug-count`, `_slug-peek` or `_slug-record` (`src/state.typ:494`,
`:517`, `:535`). Rung 2 still uses them.

## 4. Comments

`CLAUDE.md` in the repo root governs: describe the present, never what the code
used to be or what moved; no bird ids, no branch names; keep a measurement only
where it justifies a constant. The long banners above `_scope-peek` and
`_scope-record` disappear with the functions. Where a remaining comment
explains a behaviour in terms of the ordinal, rewrite it for the content-derived
scheme rather than deleting the explanation.

## NON-GOALS

- Do NOT add a uniqueness check, an error on duplicate ids, or any bundle-root
  validation. A separate bird does that.
- Do NOT edit `src/pure.typ`. The helpers are already there.
- Do NOT edit `readme.md`, `demo/`, or any `.md` at the repo root. Separate
  birds.
- Do NOT change `_id-slug`'s 60-character cap or rung 2's behaviour.
- Do NOT try to keep old ids stable. Titleless notes are being renamed on
  purpose; their URLs move.

## VERIFY

1. No trace of the deleted state:

   ```
   cd /home/lox/code/_fcl/rookery/core/0.1.0 && rg -n '_scope' src/ .marrow.typ
   ```

   prints nothing.

2. Units still pass:

   ```
   cd /home/lox/code/_fcl/rookery/core/0.1.0 && just test
   ```

   prints `units OK`.

3. The pure demo still compiles and its own assertions hold:

   ```
   cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/pure && just build
   ```

   prints `demo/pure OK`.

4. A titleless note now takes a content-derived id. Add nothing permanent for
   this — compile the existing demo and grep its output:

   ```
   rg -o 'idea:[a-z0-9-]+' /home/lox/code/_fcl/rookery/core/0.1.0/demo/pure/build/root.html | sort -u
   ```

   No id in that list may be a bare number or end in `-<digit>` from a container
   ordinal; any auto-named note's id ends in `-` plus three base36 characters.