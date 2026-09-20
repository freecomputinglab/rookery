---
id: rk-export-idea-key-for-a-name-s-label-583d8b9d
short-id: '58'
title: Export idea-key for a name's label
priority: 2
labels:
- export-idea-key
deps:
- blocked-by:rk-cut-the-alpha-lineage-migration-notes-f592d238
- blocked-by:rk-halve-the-comments-in-urls-and-base-5e633e85
- blocked-by:rk-drop-tracker-ids-from-shipped-comments-b0162a03
closed: false
---
Every consumer that needs an idea's Typst label name — the `idea:etal` string
that is simultaneously the label, the registry key, and the key `#tag-data`
returns its dictionary under — has to build it by hand, because the package
exports no way to ask for it.

`@rookery/core` exports `idea-href` and `idea-path`, which turn a name into a
URL. Neither hands back the id itself. So a consumer does the only thing left:
it hardcodes the literal `"idea:"` prefix and reaches into an internal
normalizer.

Add `#idea-key(name)`, which returns exactly that string.

Touches: core/0.1.0/src/urls.typ, core/0.1.0/readme.md, core/0.1.0/demo/pure/idea-key.typ, core/0.1.0/demo/pure/Justfile

## The evidence this is needed

The most extensive consumer of this package, the rheo project at
`/home/lox/code/waterline/rookery`, does this in four places:

- `_lib/template.typ:779` — `ref(label("idea:" + venue))`
- `_lib/template.typ:846` — `tag-data().at("idea:" + _norm(pos.at(0)), default: (:))`
- `writing/blog/template.typ:66` — `item(id: "idea:" + slug, ..)`
- and a fourth, in a sibling site, with the same shape

Two problems with every one of them. First, `"idea:"` is the DEFAULT prefix,
not necessarily the configured one — a project calling
`#show: rookery.with(prefix: "note")` gets `note:` and every hardcoded string
silently stops matching. Second, `_norm` is an internal helper, reachable only
because it leaks through the package's wildcard import chain; nothing promises
it will keep its name.

## What to add

In `core/0.1.0/src/urls.typ`, beside `idea-href` and `idea-path`, which already
compose the same two pieces:

```typ
#let idea-key(name) = _pfx() + _norm(name)
```

Anchor for the insertion point — one hit, in `core/0.1.0/src/urls.typ`
(line 133 as of filing), the last line of the `#idea-href` block:

```
rg -n 'let idea-href\(name\) = ' /home/lox/code/_fcl/rookery/core/0.1.0/src
```

Put `idea-key` immediately ABOVE `#idea-href`, since both `idea-href` and
`idea-path` are expressed in terms of the same `_pfx() + _norm(name)` pair and
a reader meets the simplest one first. Optionally rewrite those two to call
`idea-key(name)` rather than repeating the expression — this is tidier and is
allowed, but it is not required and must not change their behaviour.

`urls.typ` is already imported by `src/lib.typ` with `#import "urls.typ": *`,
so no change to the entrypoint is needed for the export to reach consumers.

## Contract, and the one thing to be careful about

- **Takes** a bare name (`"etal"`), a full id (`"idea:etal"`), or a label
  (`<etal>`, `<idea:etal>`) — whatever `_norm` accepts, exactly as `idea-href`
  does. `_norm` is what makes all four forms equivalent.
- **Returns** a `str`: the configured prefix, a colon, and the normalized name.
  Not a `label`. A caller wanting a label writes `label(idea-key("etal"))`.
  Returning a str is the right choice because the two things consumers need it
  for — a `label(..)` call and a `#tag-data()` dictionary lookup — want a string
  and a string-keyed lookup respectively.
- **Needs context.** `_pfx()` reads `state("rheo-idea-prefix").final()`, so
  `idea-key` must be called inside a `#context` block, the same as `idea-href`.
  Say so in its comment.
- Unlike `idea-href`/`idea-path`, it never returns `none`. There is no rheo
  dependency here: the prefix and the normalizer both work under plain
  `typst compile`.

## Steps

1. Add the function in `src/urls.typ` as above, with a short comment in the
   style of its two neighbours: what it returns, that it needs `#context`, and
   why it is public — a consumer that needs the label name should not have to
   hardcode the prefix, which a project can change.

2. Document it in `core/0.1.0/readme.md`. Anchor — one hit, a section heading:

   ```
   rg -n '^## Building a package on core' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   Add a short subsection under it, beside the existing `### The row shape` and
   `### The marker constants` subsections. Give the signature, the four accepted
   input forms, the `#context` requirement, and one example of each use:
   `label(idea-key("etal"))` and `tag-data().at(idea-key("etal"), default: (:))`.

3. Add a fixture at `core/0.1.0/demo/pure/idea-key.typ`. Model it on the other
   roots in that directory — read `core/0.1.0/demo/pure/naming.typ` first for
   the shape, including its `#import "../../src/lib.typ": ..` line. The fixture
   should, inside `#context` blocks, `assert.eq` that:

   - `idea-key("etal")` is `"idea:etal"`
   - `idea-key(<etal>)` is `"idea:etal"` — the label form agrees with the string
   - `idea-key("idea:etal")` is `"idea:etal"` — an already-prefixed id is not
     double-prefixed

   A failing `assert.eq` fails the compile with a line number, which is how
   every fixture in this package reports.

4. Add a second fixture root, or extend the first, covering a NON-DEFAULT
   prefix: a file applying `#show: rookery.with(prefix: "note")` and asserting
   `idea-key("etal")` is `"note:etal"`. This is the case the whole function
   exists for, so it must be covered. `core/0.1.0/demo/pure/root-prefix.typ`
   already sets a non-default prefix — read it for how that is done before
   writing anything.

5. Wire the new root(s) into `core/0.1.0/demo/pure/Justfile`'s `build` recipe
   alongside the existing `typst compile ...` lines. HTML only is sufficient —
   the fixture asserts nothing about the paged target. The comment block above
   that recipe explains the HTML-only convention; follow it and add a sentence
   naming the new root, as the existing entries do.

## Non-goals

- Do NOT add a `label`-returning variant, a plural form, or an inverse
  (`key-to-name`). One function.
- Do NOT rename, deprecate, or change the behaviour of `idea-href` or
  `idea-path`.
- Do NOT un-export `_norm` or otherwise change what leaks through the wildcard
  import chain. Typst has no private imports; that is a known and accepted
  property of this package.
- Do NOT edit anything under `/home/lox/code/waterline`. The consumers listed
  above are evidence, not scope — see the follow-up below.
- Do NOT add this to `test/units.typ`. That fixture is compiled with no context
  and no `#show: rookery`, and `idea-key` needs `#context` to resolve the
  prefix; the pure demo is where it belongs.

## Follow-up for the human, NOT part of this bird

Once this lands and the ref that `/home/lox/code/waterline/rookery` pins has
moved, the four hardcoded `"idea:" + ..` sites in that project can be rewritten
to call `idea-key`. That work is in another repository, which resolves this
package through its own `rheo.toml` pin, so nothing done inside this flight can
verify it.

## VERIFY

1. `rg -n 'let idea-key' /home/lox/code/_fcl/rookery/core/0.1.0/src/urls.typ`
   prints one hit.
2. `rg -n 'idea-key' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md` prints at
   least two hits.
3. From `core/0.1.0/demo/pure`, `just build` passes (prints `demo/pure OK`). A
   failed `assert.eq` in the new fixture fails this step with a line number.
4. From `core/0.1.0`, `just test` passes (prints `units OK`) — confirming the
   addition broke nothing in the pure helpers.