---
id: rk-suffixes-a-duplicate-ideate-heading-slug-a2ef6726
short-id: a2
title: Suffixes a duplicate ideate heading slug
priority: 3
labels:
- fix-ideate-slug-clash
deps: []
closed: true
---
Touches: core/0.1.0/src/ideate.typ

Make `#ideate` disambiguate a duplicate heading slug with a `-<n>` suffix instead of
panicking, matching what `#idea` already does for a title-derived id. After this,
two sections whose headings slug the same mint `idea:intro` and `idea:intro-1` rather
than aborting the compile.

## Why deleting the panics is NOT enough — read this before starting

`#ideate` does not hand `#idea` a title and let it derive an id. It passes the slug as
a POSITIONAL NAME, which pins it:

```
rg -n -F 'mint(doc-id, content, title: doc-title, tags: group-tags)' /home/lox/code/_fcl/rookery
```

One hit, `core/0.1.0/src/ideate.typ` (line 626 as of filing). And `#idea` claims a
PINNED id unconditionally, without probing:

```
rg -n -F 'let slug = if not named and title != none' /home/lox/code/_fcl/rookery
```

One hit, `core/0.1.0/src/idea.typ` (line 248 as of filing). The `let id = if named {
_pfx() + base }` branch immediately below it takes the pin as given; only the
`not named and title != none` branch probes `_taken-ids` for a free `-<n>`.

So simply removing `#ideate`'s panics would NOT produce `intro-1`. It would let two
sections pin the same id and hit `#idea`'s own duplicate-note-id registry panic
instead — a later, blunter error. `#ideate` has to do the probe itself.

## The state to probe

```
rg -n -F '#let _taken-ids = state(' /home/lox/code/_fcl/rookery
```

One hit, `core/0.1.0/src/state.typ`. It is a dictionary used as a set of every FULL id
minted so far, pinned or derived, and it is already reachable from `ideate.typ` (that
file imports the same modules `idea.typ` does — confirm with the import block at the
top before assuming it, and add `#import "state.typ": *` only if genuinely absent).

Note the ids in it are FULL ids, carrying the `_pfx()` prefix, while `#ideate` works in
bare slugs — prefix before probing, strip nothing.

## This also closes a real hole

```
rg -n -F 'let seen-slugs = ()' /home/lox/code/_fcl/rookery
```

One hit, `core/0.1.0/src/ideate.typ` (line 509 as of filing). `seen-slugs` is a LOCAL
array, so it only sees sections within ONE `#ideate` call. Two separate `#ideate`
blocks that both slug to `intro`, or an `#ideate` section colliding with a hand-written
`#idea(<intro>)` elsewhere, are invisible to it today and reach the registry panic.
Probing the document-wide `_taken-ids` fixes that as a side effect. Say so in a comment.

## Steps

1. Find the three panics:

   ```
   rg -n 'two sections in this body slug' /home/lox/code/_fcl/rookery/core/0.1.0/src/ideate.typ
   ```

   Three hits (near lines 605, 616 and 650 as of filing), one per id source: a
   `#ideate-id` beacon, a `doc-title` slug, and a `name:` function's value.

2. Replace each panic with a probe. Write ONE small helper near the top of the minting
   section rather than repeating the loop three times:

   ```typ
   #let _free-id(bare) = {
     let taken = _taken-ids.get()
     let candidate = _pfx() + bare
     let n = 1
     while candidate in taken {
       candidate = _pfx() + bare + "-" + str(n)
       n = n + 1
     }
     candidate.trim(_pfx(), at: start)
   }
   ```

   It returns a BARE name, because `mint(..)` takes a bare name positionally and
   `#idea` adds the prefix itself — returning a full id here would double it.

   `_taken-ids.get()` needs context. The minting code already runs inside `#ideate`'s
   own `context` block (the function body is `= context {`), so this is fine where the
   three panics currently sit. Verify that before relying on it; if some call site is
   outside context, report it rather than restructuring the function.

3. Delete `seen-slugs` entirely — the array, its three `.push(..)` calls and its
   declaration. `_taken-ids` replaces it, and `#idea` claims each id as it mints, so
   nothing here needs to record anything itself.

4. Leave the ordering caveat honest in a comment: which of two same-slug sections gets
   the bare name and which gets `-1` depends on document order, exactly as it does for
   `#idea`'s title-derived ids. Follow `CLAUDE.md`'s comment style — present tense, no
   history, no issue ids.

## Non-goals

- Do NOT change `#idea`, `pure.typ`, `state.typ` or `_taken-ids` itself.
- Do NOT change `#ideate`'s separator handling, its `name:`/`title:` resolution, or
  which id source wins (a `#ideate-id` beacon still beats a `doc-title` slug).
- Do NOT touch the readme — a separate bird documents this.
- Do NOT add a parameter making the behaviour configurable.

## VERIFY

From `core/0.1.0`:

1. `just test` exits 0 and prints `units OK`.
2. `(cd demo/pure && just build)` exits 0 and ends with `demo/pure OK`.
3. `(cd demo/rheo && just check)` exits 0 and ends with `demo/rheo OK`. That recipe
   builds before checking; `bash check.sh` alone fails for lack of a build, which is
   not your change.
4. `rg -n 'two sections in this body slug' src/ideate.typ` returns no hits.
5. `rg -n -F 'seen-slugs' src/ideate.typ` returns no hits.
6. Write a scratch fixture with two sections whose headings both slug to `intro`,
   compile it to HTML, and confirm the ids are `idea:intro` and `idea:intro-1` rather
   than a panic. Delete the fixture and its output afterwards; report the ids you saw.