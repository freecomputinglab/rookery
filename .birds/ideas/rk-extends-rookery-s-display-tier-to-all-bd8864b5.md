---
id: rk-extends-rookery-s-display-tier-to-all-bd8864b5
short-id: bd8
title: Extends rookery's display tier to all nine keys
priority: 2
labels:
- feat-display-document-wide
deps:
- blocked-by:rk-documents-the-derived-id-ordering-caveat-2b3c62b2
closed: true
---
Touches: core/0.1.0/src/template.typ, core/0.1.0/src/state.typ, core/0.1.0/.marrow.typ, core/0.1.0/src/idea.typ, core/0.1.0/src/window.typ, core/0.1.0/readme.md

Give the remaining six display keys a document-wide tier, so `rookery(..)` can set a
default for all nine rather than only three.

## Where things stand

`#idea` and `#window` take a `display:` dictionary plus `display-*` overrides across
nine keys: `context`, `backlinks`, `background`, `date`, `frame`, `id`, `label`,
`tags`, `title`. `rookery(..)` accepts only three of them — `context`, `backlinks`,
`title` — and PANICS on the other six:

```
rg -n -F 'display-context: auto' /home/lox/code/_fcl/rookery/core/0.1.0/src/template.typ
```

That narrowness is deliberate and not an oversight: only those three ever had a
document-wide state, and the earlier rename did not invent one for the rest. This bird
is the follow-up that does.

The value is real: `rookery(display: (tags: true))` to show tag pills everywhere, or
`display: (frame: false)` for a whole document of bare notes, currently means passing
the argument at every single call site.

## The existing three-tier resolution, which this must extend, not replace

1. An individual `display-*` argument on the call, when not `auto`.
2. The call's own `display:` dictionary, when it carries that key.
3. The document-wide `rookery(..)` setting.
4. The built-in default.

Today `#idea` collapses tiers 3 and 4 for the six render-time keys by defaulting them
in its own body, so `auto` never escapes:

```
rg -n -F 'date: if display.date == auto { false } else { display.date }' /home/lox/code/_fcl/rookery
```

That substitution is what has to move: those keys must stay `auto` out of `#idea` and
be resolved against the document-wide state at render time, exactly as `context`,
`backlinks` and `title` already are on the minted page.

**This is the subtle part and the main risk in the bird.** `#idea` renders its own card
inline, not on a minted page, so it needs the document-wide value at render time in its
own `context` block — it cannot defer to `.marrow.typ` the way the other three do.
Read how `_display-context` is declared and read before designing this:

```
rg -n -F '#let _display-context = state(' /home/lox/code/_fcl/rookery
```

## Steps

1. Add six states beside the existing three in `core/0.1.0/src/state.typ`, following
   their exact shape and their convention that the binding is `_display-*` while the
   `state("rheo-idea-show-*")` string key keeps its older spelling. Pick each default to
   match today's built-in: `date` false, `tags` false, `frame` true, `id` true,
   `label` true, `background` true.

2. Widen `rookery(..)`'s key whitelist in `template.typ` from three keys to all nine,
   add the six `display-*` parameters (defaulting to `auto`), resolve them the way the
   three are resolved now, and publish each to its state.

3. In `#idea` (`src/idea.typ`) and `#window` (`src/window.typ`), STOP substituting the
   built-in default for the six render-time keys. Leave them `auto` out of
   `_resolve-display`, and resolve `auto` against the document-wide state at the point
   of use, inside the `context` block that already renders the card.

4. `.marrow.typ` reads the three minted-page keys off state already. Check whether any
   of the six newly-stated keys is also read there and wire it the same way if so.

5. Update the readme's precedence description and its `rookery(..)` signature listing to
   say all nine keys are accepted.

## Non-goals

- Do NOT change the resolution ORDER. An explicit flag still beats the dictionary, which
  beats the document-wide setting, which beats the built-in default.
- Do NOT change any default's value. A document that sets nothing must render
  byte-identically after this bird.
- Do NOT rename anything, or touch the `state("rheo-idea-show-*")` string keys.
- Do NOT touch another package.

## VERIFY

From `core/0.1.0`:

1. `just test` exits 0 and prints `units OK`.
2. `(cd demo/pure && just build)` exits 0 and ends `demo/pure OK`.
3. `(cd demo/rheo && just check)` exits 0 and ends `demo/rheo OK`.
4. `rg -n -F 'display-background: auto' src/template.typ` returns at least one hit —
   `rookery(..)` now takes the wider set.
5. A scratch fixture with `#show: rookery.with(display: (tags: true))` and a plain
   `#idea(title: [X], tags: ("a",))[b]` renders the tag pill without the call site
   asking for it. Delete the fixture and its output afterwards and report what you saw.
6. The unchanged-default guarantee: `(cd demo/rheo && just check)` passing IS this
   check, since its `check.sh` asserts against rendered HTML. Say so in your report.