---
id: rk-drop-the-dead-id-parameter-from-flatten-ecbd4341
short-id: ecb
title: Drop the dead id parameter from _flatten
priority: 2
labels:
- fix-content-derived-names
deps:
- blocked-by:rk-fail-the-build-on-two-notes-sharing-a-e9f4de62
closed: false
---
Touches: core/0.1.0/src/transclusion.typ, core/0.1.0/src/idea.typ, core/0.1.0/src/window.typ, core/0.1.0/.marrow.typ

`_flatten`'s `id:` parameter is dead. Its only two readers were a `_scope`
push/pop pair that no longer exists — a note is now named from its own content,
so nothing downstream needs to know which note's body is being flattened. The
parameter is still declared, still threaded through `_body-at`, and still
passed by four call sites, all of which now hand it a value nobody reads.

Remove it.

All paths relative to `/home/lox/code/_fcl/rookery/core/0.1.0`.

## 1. Confirm it is genuinely unread first

```
rg -n 'id' src/transclusion.typ
```

Read every hit inside `_flatten` and `_body-at`. If ANY of them reads the `id:`
parameter for something other than passing it along, STOP and report — the
premise of this bird is that none do, and that claim is worth one minute of
checking before you delete a parameter.

## 2. Drop the parameter

Anchors:

```
rg -n 'let _flatten' src/
rg -n 'let _body-at' src/
```

One hit each. Remove `id:` from both signatures and from any internal
forwarding between them.

## 3. Drop it from every call site

```
rg -n '_flatten\(|_body-at\(' src/ .marrow.typ
```

At filing this finds calls in `src/idea.typ` (passing `own-id`),
`src/window.typ` (two), and `.marrow.typ`. Remove the `id:` argument from each.

In `src/idea.typ`, `own-id` may become unused once its `_flatten` call stops
taking it. Anchor `rg -n 'let own-id' src/` — one hit. If nothing else reads
`own-id` after your change, delete the binding too; if something does, leave
it. Check, do not assume either way.

## 4. Comments

The comments around `_flatten` and `_body-at` currently explain that `id:` is
kept for signature compatibility and is no longer read. Those sentences go with
the parameter — do not leave a comment describing an argument that is gone. The
repo's `CLAUDE.md` governs: describe the present, never what was removed.

## NON-GOALS

- Do NOT change what `_flatten` renders. This is a signature change and
  nothing else; every demo must produce byte-identical output.
- Do NOT touch `src/pure.typ`, `src/state.typ` or `src/validate.typ`.
- Do NOT rename `_flatten` or `_body-at`.

## VERIFY

1. The parameter is gone everywhere:

   ```
   cd /home/lox/code/_fcl/rookery/core/0.1.0 && rg -n 'id:' src/transclusion.typ
   ```

   returns no hit that is `_flatten`'s or `_body-at`'s own parameter.

2. Nothing broke:

   ```
   cd /home/lox/code/_fcl/rookery/core/0.1.0 && just test
   cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/pure && just build
   cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check
   ```

   printing `units OK`, `demo/pure OK`, and the rheo demo's own OK line.