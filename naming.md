# How an idea gets its name

The algorithm `@rookery/core` uses to decide the id of a note that was not
explicitly named, step by step, with the steps that cause the convergence
failure marked. Companion to `convergence-bug.md`, which covers the failure
itself.

Everything here lives in `core/0.1.0/src/idea.typ` (the mint block, roughly
lines 262–331) and `core/0.1.0/src/state.typ` (the two counters).

## Inputs

All fixed by the call site, before anything is rendered:

| | |
|---|---|
| `named`, `base` | whether `#idea(<some-name>, ..)` pinned a name, and what it was |
| `title` | the authored `title:`, or one a factory derived (`@rookery/meetings` builds `[Meeting with #_refs(who) on #stamp]`) |
| `body`, `tags`, `level`, `display` | the rest of the note's own content and flags |

And two pieces of ambient state, which are **not** fixed by the call site:

| | |
|---|---|
| `state("rheo-handle")` | which vertebra is being rendered right now |
| `_scope` | a stack of open containers, described in step 3 |

## The algorithm

### Step 0 — the prefix

`_pfx()` is `_prefix.final() + ":"`, normally `idea:`. Every id below is
prefixed with it.

### Step 1 — a pinned name wins outright

```typ
if named { id = _pfx() + base }
```

Done. No state is read, nothing positional is involved, and the id can never
move. **This is the escape hatch**: an author who needs a stable URL pins the
name, and none of the problems below can reach them.

### Step 2 — otherwise, try to derive a slug from the title

```typ
slug = _id-slug(_plain(title))
```

- `_plain` (`pure.typ:369`) is the **pure** plain-text projection: it walks the
  title's content and renders every `ref` as the empty string, because it runs
  before the registry that could resolve one.
- `_id-slug` (`pure.typ:974`) lowercases, collapses non-alphanumerics to `-`,
  trims, caps at 60 chars, and returns `none` for an empty or all-digit result.

> **⚠ Problem (cause of a collision, fixed upstream).** A title built out of
> references projects to almost nothing. `[Meeting with #_refs(who)]` becomes
> `"Meeting with "`, slugged to `meeting-with` — so *every* dateless untitled
> meeting in a project derived the same id, and the build died on a duplicate.
> A title made **only** of refs projects to `""`, `_id-slug` returns `none`,
> and the note silently falls through to step 3 instead.
>
> Fixed in `@rookery/meetings` by naming such a meeting after its participants
> rather than letting the title be slugged. The sharp edge remains for any
> other factory that builds a title out of refs.

If a slug came back, the note takes it — and is numbered against anything else
that took the same one:

```typ
occupant = (title, body, tags, level, display)
slug-n   = _slug-peek(slug, occupant)
id       = _pfx() + slug + (if slug-n > 1 { "-" + str(slug-n) })
_slug-record(slug, occupant)
```

`_slug-count` maps a slug to an **array of occupants**. `_slug-peek` returns an
occupant's existing position if it is already in the array, and the next free
position otherwise; `_slug-record` appends **only if absent**. So rendering the
same note again — on its own minted page, or inside a `#window` — finds itself
already listed and gets the same number back.

> **⚠ Problem (accepted).** The suffix counts in document order, so inserting a
> colliding note earlier renumbers the ones after it and moves their URLs. This
> was chosen deliberately over failing the build; pinning a name (step 1) is the
> way out.

### Step 3 — with no name and no slug, take a container ordinal

```typ
container = _scope-peek()          // -> (key, n)
id        = _pfx() + key + "-" + n // key omitted when empty
_scope-record(key)
```

`_scope-peek` (`state.typ:415`) decides the key by looking at the top of the
stack:

- **If the top entry is a note's own open container** (no `top` marker), the
  note is nested inside another note. The key is **the parent note's id**, and
  `n` continues that parent's count. This is what produces
  `meeting-with-on-4-9-26-1`.
- **Otherwise** the note is at a page's top level. The key comes from
  `state("rheo-handle")` with `:` replaced by `-`, giving `grad`,
  `fcl-rookery`, and so on. If the top entry already belongs to that vertebra
  the count continues; otherwise a fresh accumulator starts at 1.

> **⚠ Problem (fixed, but the read remains).** The key is derived from *where
> the renderer currently is*. Until `rheo-handle` settles, every titleless note
> in the whole spine falls into one accumulator keyed `""` — which is where the
> original `idea:4` duplicates came from, and why run 2 of a build still shows
> a single `(key: "", n: 103)` entry before run 3 splits it per vertebra. Under
> a plain `typst compile` with no rheo the key is legitimately `""` and ids are
> bare ordinals; that case is intended.

> **⚠⚠ Problem (OPEN — this is the current resolution bug).**
> `_scope-record(key)` advances the count **unconditionally**. Compare step 2:
> `_slug-record` takes the note's `occupant` and appends only if that note is
> not already listed. `_scope-record` takes only a key, so it cannot tell a
> *new* nested note from a *replay* of one it has already counted.
>
> `#window` re-renders a parent note's body wherever it is placed, so the
> nested `#idea` mint block runs a second time, records again, and the parent's
> container goes from 1 to 2. The nested note's id is `<parent>-<n>`, so the
> same note resolves to `…-1` in one place and `…-2` in another.
>
> Measured: `pragma/meetings.typ:376-419` contains exactly one nested `#idea[`
> (line 398), yet the site's scope trace shows that meeting's container at
> `n: 2` with a second entry keyed `meeting-with-on-4-9-26-2`.
>
> Filed as `fix-scope-ordinal-replay`. The fix is to give `_scope-record` the
> same occupant-idempotence step 2 already has.

Note the deliberate asymmetry in how `n` travels: `_scope-peek` returns an `n`
used to build the id string, but `_scope-record` is handed **only the key** and
re-derives the new count from its own updater argument. Closing over the peeked
`n` instead was measured to cost one extra compile attempt per note sharing a
container — with 103 titleless notes and a five-attempt budget, that alone
sank the build.

### Step 4 — every note then opens a container of its own

```typ
own-id = id without the prefix
_scope.update(s => s + ((key: own-id, n: 0),))
... render the body ...
_scope.update(s => s.slice(0, -1))        // popped after the body
```

This is what makes step 3's first branch work: while a note's body renders, any
titleless note inside it numbers against the parent rather than the page. The
push/pop pair is also why a nested note's ordinal can reproduce when the parent
is transcluded — the container is re-established around the replayed body.

> **⚠ Problem (consequence).** The push is keyed by `own-id`. When step 3's
> ordinal drifts, the *key* of the pushed container drifts with it, so the
> stack observed at a given read point differs between passes. That is the
> mechanism by which one unstable id keeps the whole document from settling,
> rather than merely producing one wrong URL.

## Summary

| step | what decides the name | positional? | status |
|---|---|---|---|
| 1 | the pinned name | no | stable by construction |
| 2 | title slug, `+ -n` when shared | the suffix only | idempotent per note; suffix order accepted |
| 2 | `_plain` drops refs from the title | n/a | caused collisions; fixed in `@rookery/meetings` |
| 3 | vertebra handle, or parent note id | **yes** | key settles once the handle does |
| 3 | the ordinal `n` | **yes** | **OPEN — not idempotent under replay** |
| 4 | container pushed under `own-id` | inherits step 3 | drifts when step 3 drifts |

The rule the whole table argues for: a generated name may only be derived from
what the note **is**. Where something positional is unavoidable — a container
ordinal genuinely is, since nothing about a titleless note distinguishes it
from its sibling — recording it must be **idempotent**, so that rendering the
same note twice is indistinguishable from rendering it once. Step 2 does this.
Step 3 does not, and that is the bug.
