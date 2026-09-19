---
id: rk-records-that-an-idea-s-return-value-is-1fda1f23
short-id: 1f
title: Records that an idea's return value is opaque
priority: 2
labels:
- docs-idea-introspection
deps: []
closed: true
---
Touches: core/0.1.0/readme.md, core/0.1.0/src/idea.typ

Record, in `@rookery/core`'s own documentation, that a `#idea` call's RETURN VALUE
cannot be introspected — a constraint that currently costs a package author a day to
rediscover, and that one downstream package has already had to work around.

## The constraint

`#idea` resolves a note's id and registers it from inside a `context` block, so what it
returns is a deferred `context` node. A Typst `context` node's body is opaque to
`.fields()` until Typst actually realizes it, and reading an unplaced content value
never realizes it. So this returns nothing useful:

```typ
#let c = idea(title: [X], tags: ("a",))[body]
// walking `c` for the `figure(kind: IK)` marker finds nothing
```

The note still renders and registers correctly when PLACED. It is only introspection of
the unplaced value that fails, and it fails SILENTLY — no error, just an empty result.

## Prior art to point at, not to duplicate

`@rookery/slipshow` hit this and worked around it. Read both before writing, and cite
them rather than restating their content:

```
rg -n -F '#let _SLIP-META' /home/lox/code/_fcl/rookery
rg -n -F 'walks rendered content looking for a' /home/lox/code/_fcl/rookery
```

`slipshow/0.1.0/src/marker.typ`'s header explains the mechanism and why `#slip` emits a
second PLAIN `#metadata` marker as a SIBLING of the deferred `#idea` call.
`slipshow/0.1.0/src/select.typ`'s header records the same trap for `#window`, which
wraps its body in `context` for the same reason.

The workaround shape — a plain sibling marker, not a nested one — is the part worth
generalizing in prose: a package that needs to read a note's own options back off a
content value must emit its own marker beside the `#idea` call.

## Steps

1. Add a short subsection to `core/0.1.0/readme.md`, near the material on `#idea`'s
   registry and markers. State: what `#idea` returns, why it is deferred, that
   `.fields()` introspection of it silently yields nothing, that `#window` has the same
   property, and what a package should do instead (emit its own sibling `#metadata`
   marker, or read the registry by name rather than sniffing content). Name
   `slipshow/0.1.0/src/marker.typ` as the worked example.

   Keep it to a few paragraphs. Match the readme's register (`CLAUDE.md`, "Comment
   style", which governs prose here too: present tense, describe what is).

2. Add a brief comment at the site itself:

   ```
   rg -n -F 'let slug = if not named and title != none' /home/lox/code/_fcl/rookery
   ```

   One hit, `core/0.1.0/src/idea.typ` (line 248 as of filing). The `context` block
   wrapping the figure begins just above it. Add two or three lines to that block's
   existing comment noting the consequence for callers: the returned value is deferred,
   so a caller cannot walk it for the IK marker. Do not restate the whole readme
   section — one cross-reference plus the fact.

   `CLAUDE.md` permits a comment naming its counterpart in another file, so pointing at
   `slipshow`'s `marker.typ` here is allowed; keep it to one clause.

## Non-goals

- Do NOT change any behaviour. This bird is documentation plus one comment.
- Do NOT add an accessor, a sibling marker, or any new API to core. Whether core should
  offer a supported way to do this is a real question and a separate decision — this
  bird only records the current constraint.
- Do NOT modify `slipshow/0.1.0/` at all; it is cited, not changed.
- Do NOT restructure `#idea`'s `context` block to make the value introspectable. That
  would undo the id resolution the block exists for.

## VERIFY

From `core/0.1.0`:

1. `just test` exits 0 and prints `units OK`.
2. `rg -i -F 'marker.typ' readme.md` returns at least one hit — the worked example is
   cited.
3. `rg -i 'fields()' readme.md` returns at least one hit.
4. `rg -c 'context' src/idea.typ` returns a higher count than before your change, and
   `just test` still passes — confirming the comment landed and nothing executable moved.