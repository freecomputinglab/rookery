---
id: rk-carries-a-note-s-resolved-id-on-its-ik-0525b40f
short-id: '05'
title: Carries a note's resolved id on its IK payload
priority: 3
labels:
- feat-title-derived-ids
deps: []
closed: true
---
Touches: core/0.1.0/src/idea.typ, core/0.1.0/src/transclusion.typ

Move `#idea`'s id resolution ABOVE the `figure(kind: IK, ..)` marker and put the
resolved id onto that figure's metadata payload, so a consumer reading the payload can
learn the note's id. Then make `_flatten`'s IK show rule read it instead of
recomputing it.

This is a REFACTOR: after it lands, every note's id must be exactly what it is today.
It is the structural prerequisite for a later change that derives an unnamed note's id
from its title, which cannot be recomputed at a transclusion site.

## The problem

Today the id is resolved INSIDE a `#context` block that sits inside the figure's body,
below the metadata payload — so the payload cannot carry it. Find the payload:

```
rg -n -F '#metadata((body: body, title: title' /home/lox/code/_fcl/rookery
```

One hit, `core/0.1.0/src/idea.typ` (line 202 as of filing). It carries `body`, `title`,
`label`, `named`, `base`, `level`, `tags`, `show-frame`, `show-id` — everything
`_flatten`'s IK rule needs to rebuild the note's card when it is shown nested inside a
transcluded or minted parent — but not the id.

So the consumer has to rebuild the id itself, and can only do it for a NAMED note:

```
rg -n -F 'let id = if v.named { _pfx() + v.base }' /home/lox/code/_fcl/rookery
```

One hit, `core/0.1.0/src/transclusion.typ` (line 321 as of filing), inside the
`show figure.where(kind: IK):` rule in `_flatten`. The comment above it explains why an
auto-numbered note gets `none`: its id is a counter value frozen at its original site,
and reading the counter here would give the value at this LATER, transcluded position.
A transcluded auto-numbered note therefore has no id, no permalink, and no tab.

Carrying the id on the payload removes the recomputation entirely, and as a side effect
gives transcluded auto-numbered notes a correct permalink for the first time.

## The mechanic is verified

Wrapping the whole `figure(..)` in a `context` block, resolving the id above it, and
putting it in the metadata was tested standalone under
`typst compile --features html --format html`. The IK show rule's
`it.body.children.find(c => c.func() == metadata)` still finds the metadata, the
payload's `id` field reads back correctly, `query(figure.where(kind: IK))` still finds
every figure, and counter values resolve to the same numbers as before the wrap.

## Steps

1. Find the figure:

   ```
   rg -n -F 'figure(kind: IK, supplement: none' /home/lox/code/_fcl/rookery
   ```

   One hit, `core/0.1.0/src/idea.typ` (line 185 as of filing).

2. Find the current id resolution:

   ```
   rg -n -F 'let n = _seq.get().first()' /home/lox/code/_fcl/rookery
   ```

   One hit, same file (line 210 as of filing), inside the `let id = if named { .. }`
   binding at the top of the inner `#context` block.

3. Find the counter step that precedes the figure:

   ```
   rg -n -F '#if not named { _seq.step() }' /home/lox/code/_fcl/rookery
   ```

   One hit, same file (line 205 as of filing). This one is INSIDE the figure body.
   There is a second, different `_seq.step()` earlier in the file inside the
   exclusion-gate early return (near the comment `THE COUNTER STILL STEPS`) — do NOT
   touch that one; this bird does not change the exclusion path at all.

4. Restructure `#idea` so that, in order: `_seq.step()` runs for an unnamed note (keep
   it exactly where it is relative to the figure — it must still step once per unnamed
   note, including the excluded ones handled elsewhere), then a `context` block wraps
   the `figure(..)`, and inside that block the id is resolved ONCE, above the figure:

   ```typ
   context {
     let id = if named { _pfx() + base } else { _pfx() + str(_seq.get().first()) }
     figure(kind: IK, supplement: none, [
       #metadata((body: body, title: title, label: note-label, named: named,
                  base: base, id: id, level: level, tags: tags,
                  show-frame: show-frame, show-id: show-id, show-tags: show-tags))
       ...
     ])
   }
   ```

   Keep every existing payload key — `id` is ADDED, nothing is removed or renamed,
   because `_flatten`'s IK rule and `#ideas-outline` both read this payload and a
   dropped key breaks them silently.

5. The inner `#context` block that currently resolves the id still exists and still does
   everything else it does (the date resolution, the `state("rheo-handle")` read, the
   footnote check, the outbound-link walk, the `_registry.update`). It must now USE the
   id resolved in step 4 rather than resolving its own. Do not resolve the id twice —
   one binding, used by both the payload and the registry record, is the entire point.

   A nested `context` inside an outer `context` is fine in Typst; leave the inner block
   in place rather than trying to merge the two, so the diff stays small.

6. Update the IK show rule in `transclusion.typ` to read the payload:

   ```typ
   let id = v.at("id", default: if v.named { _pfx() + v.base } else { none })
   ```

   Use `.at(.., default: ..)` rather than a bare `v.id`, matching the convention two
   lines below it (`v.at("show-id", default: true)`), whose comment explains that a
   payload minted before a key existed carries no such key.

7. Replace the comment above that line. It currently explains why an auto-numbered
   nested idea has no id. That reason no longer holds — the id now travels on the
   payload rather than being recomputed. Write a present-tense comment saying the id
   comes from the payload because it was resolved at the note's ORIGINAL site, and that
   this is what lets a transcluded auto-numbered note carry a correct permalink.
   Follow `CLAUDE.md`'s "Comment style": describe the present, never what it used to be.

8. Two comments downstream of the change say an auto-numbered nested note has no id and
   therefore no tab. Find them:

   ```
   rg -n -F 'An auto-numbered nested idea' /home/lox/code/_fcl/rookery
   rg -n -F 'an auto-numbered nested note has no id' /home/lox/code/_fcl/rookery
   ```

   Both in `transclusion.typ`. Update them to match the new behaviour. Keep the
   `id == none` guards in the code — a payload without an `id` key still degrades to
   `none`, and the guard is what makes that safe.

## Non-goals

- Do NOT change any note's id. Ids stay exactly as they are: `_pfx() + base` for a
  named note, `_pfx() + str(<counter>)` for an unnamed one. A later bird changes that.
- Do NOT touch `core/0.1.0/src/pure.typ`, `state.typ`, `ideate.typ` or the readme.
- Do NOT change the exclusion-gate early return near `THE COUNTER STILL STEPS`.
- Do NOT remove or rename any existing key in the metadata payload.
- Do NOT add a slug, a title-derived id, or any collision handling.

## VERIFY

From `core/0.1.0`:

1. `just test` exits 0 and prints `units OK`.
2. `(cd demo/pure && just build)` exits 0 and ends with `demo/pure OK`. That
   recipe compiles `root.typ`, `root-prefix.typ` and `excluded.typ` and runs its own
   `check` — it is the pure-Typst demo's real entrypoint.
   `ls demo/pure demo/rheo` and compile whichever `.typ` is the entrypoint; report the
   command you used.
3. `rg -n -F 'id: id,' src/idea.typ` returns at least one hit, inside the metadata
   payload — proving the id now rides on it.
4. `rg -n -F 'v.at("id", default:' src/transclusion.typ` returns exactly one hit.
5. `rg -c '_seq.get()' src/idea.typ` reports exactly 1 — the id is resolved once, not
   twice.