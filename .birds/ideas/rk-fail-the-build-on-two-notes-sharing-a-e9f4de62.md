---
id: rk-fail-the-build-on-two-notes-sharing-a-e9f4de62
short-id: e9f
title: Fail the build on two notes sharing a name
priority: 4
labels:
- fix-content-derived-names
deps:
- blocked-by:rk-name-a-titleless-note-from-its-content-8ef775a9
closed: true
---
Touches: core/0.1.0/src/validate.typ, core/0.1.0/src/lib.typ, core/0.1.0/src/template.typ, core/0.1.0/.marrow.typ

Note names are now derived purely from a note's own content, which makes them
stable under replay but says nothing about whether two different notes landed
on the same name. Check that once, at bundle root, and fail the build with a
message naming both notes when they did.

All paths relative to `/home/lox/code/_fcl/rookery/core/0.1.0`.

## Why Typst's own label check is not enough

Every note emits `#label(id)`. Duplicate labels look like they should catch
this, and they half do. VERIFIED on typst 0.15.1: two `#label("idea:dup")`
definitions with nothing referencing them compile clean, exit 0, no warning;
add one `#link(label("idea:dup"))` and you get
`error: label <idea:dup> occurs multiple times in the document` — pointing at
the LINK, not at either note. So the check fires only for a name something
happens to reference, and when it fires it blames the wrong place.

## The rule

Group every note in the document by its resolved id. Within a group, compare
payloads. **Payloads differ → two distinct notes took one name → panic, naming
both.** Payloads identical → the same note placed more than once → fine.

That second half is not optional. A note legitimately appears several times —
its authoring vertebra, its marrow-minted page, every `#window` transcluding
it — so "this id occurs twice" is the ORDINARY case. VERIFIED on typst 0.15.1:
a show rule that REPLACES an element does not hide it from `query()` (a
document with one plain marker and one whose show rule replaced it reports two
hits), so the transcluded copies cannot be filtered out by querying alone. Only
the payload comparison separates a collision from a replay.

## 1. New file `src/validate.typ`

Export `_assert-unique-names()`, a `context` function returning content
(nothing, on success).

Query every note marker and read its payload:

```typ
for el in query(figure.where(kind: IK)) { ... }
```

The payload is a `metadata` element inside the figure's body. The idiom already
in the codebase is at `src/transclusion.typ`; anchor:

```
rg -n 'children.find\(c => c.func\(\) == metadata\)' src/
```

One hit, `src/transclusion.typ:379`, inside the `show figure.where(kind: IK)`
rule. Use the same shape, but defensively — a figure body that is a single
element has no `children`:

```typ
let ch = if el.body.has("children") { el.body.children } else { (el.body,) }
let m = ch.find(c => c.func() == metadata)
```

The dict `m.value` carries `body`, `title`, `label`, `named`, `base`, `id`,
`level`, `tags`, `display`. Anchor for where it is built:

```
rg -n 'metadata\(\(body: body, title: title' src/
```

One hit, `src/idea.typ:351`, inside `#idea`'s `figure(kind: IK, ..)`.

Build a dictionary from id to the list of DISTINCT payloads seen under it.
Compare payloads with `==`; two placements of one note compare equal.

On any id whose list holds more than one distinct payload, `panic` with a
message that names the id and describes BOTH notes, so the author can find
them. Describe a note by its title where it has one and by the opening of its
body otherwise:

```typ
#let _describe(v) = {
  let t = _plain(v.title)
  let s = if t.trim() != "" { t } else { _plain(v.body) }
  s = s.trim()
  if s.len() > 60 { s.slice(0, 60) + "…" } else { s }
}
```

The message must say what to do about it — pinning a name is the fix:

```
@rookery/core: two different notes both resolved to the name `idea:<id>`.
  1. <description>
  2. <description>
Give one of them an explicit name — `#idea(<some-name>, ..)` — or a distinct
`title:`.
```

## 2. Call it once per bundle, on both paths

`@rookery/core` must keep working under plain `typst compile` with no rheo, so
the check has two call sites and a guard, not one.

- **Under rheo**, `.marrow.typ` is the bundle root and runs once. Anchor:

  ```
  rg -n 'let registry = _registry.final\(\)' .marrow.typ
  ```

  One hit, `.marrow.typ:95`, opening a top-level `#context` block. Call
  `_assert-unique-names()` inside that block. `.marrow.typ` imports its
  internals from `"@rookery/core:0.1.0"` BY NAME, not by relative path — add
  the new name to that import list, and note the banner at `src/base.typ`
  warning that marrow's imported names are a real API.

- **Without rheo**, call it from the `rookery` template, guarded so it does not
  also run under rheo (where marrow already covers it, and where the template
  runs once per vertebra). Anchor:

  ```
  rg -n '_page-links-beacon\(doc\)' src/
  ```

  One hit, `src/template.typ:665`, inside `#let rookery(..)`. Add the call
  beside it, wrapped:

  ```typ
  if _rheo-ctx() == none { context _assert-unique-names() }
  ```

  `_rheo-ctx` is `sys.inputs.at("rheo-context", default: none)`; anchor
  `rg -n 'let _rheo-ctx' src/` — one hit, `src/base.typ:20`. It reads
  `sys.inputs`, so it needs no `context` of its own.

Export `_assert-unique-names` from `src/lib.typ` alongside the other module
re-exports.

## NON-GOALS

- Do NOT warn about two notes with IDENTICAL payloads. They are indistinguishable
  from one note placed twice, and a separate bird handles that case.
- Do NOT rename, suffix or otherwise repair a collision. The whole point is to
  fail loudly; silently moving a name is what this design removes.
- Do NOT touch `src/idea.typ`, `src/state.typ` or `src/pure.typ`.
- Do NOT add a `query()` call to `src/idea.typ`'s mint path. The check belongs
  at bundle root, once, not per note.

## VERIFY

1. Units and the pure demo still pass:

   ```
   cd /home/lox/code/_fcl/rookery/core/0.1.0 && just test
   cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/pure && just build
   ```

   printing `units OK` and `demo/pure OK`.

2. A real collision fails the build. Create a scratch file OUTSIDE the
   repository, at `/tmp/rookery-collide.typ`:

   ```typ
   #import "/src/lib.typ": rookery, idea
   #show: rookery
   #idea(title: [Shared heading])[First body.]
   #idea(title: [Shared heading])[Second, different body.]
   ```

   ```
   cd /home/lox/code/_fcl/rookery/core/0.1.0 && typst compile --features html \
     --root . --format pdf /tmp/rookery-collide.typ /dev/null
   ```

   NOTE: rung 2 gives the second note a `-2` suffix, so this pair may legally
   NOT collide. If it compiles clean, that is the correct outcome — say so in
   your report and instead verify the panic by temporarily making two notes
   resolve to the same name however your implementation allows, then remove
   that scratch file. Do not add a permanent failing fixture to the repo.

3. The check does not run twice under rheo:

   ```
   rg -n '_assert-unique-names' /home/lox/code/_fcl/rookery/core/0.1.0
   ```

   shows exactly one definition, one export, and two call sites — one in
   `.marrow.typ`, one guarded by `_rheo-ctx() == none` in `src/template.typ`.