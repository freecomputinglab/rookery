---
id: rk-demo-cases-for-content-derived-names-ad8cb137
short-id: ad8
title: Demo cases for content-derived names
priority: 3
labels:
- fix-content-derived-names
deps:
- blocked-by:rk-name-a-titleless-note-from-its-content-8ef775a9
closed: true
---
Touches: core/0.1.0/demo/pure/naming.typ, core/0.1.0/demo/pure/Justfile, core/0.1.0/demo/rheo/check.sh

A titleless note is now named from its own content, and the property that
matters — the SAME note reaching the SAME name wherever it is rendered — is
exactly the one no unit test can reach, because it only appears when a note is
rendered twice. Cover it in the demos, which compile real documents.

All paths relative to `/home/lox/code/_fcl/rookery/core/0.1.0`.

## 1. A new pure-Typst case, `demo/pure/naming.typ`

`demo/pure` compiles with plain `typst compile` and no rheo. Look at an
existing case first for the shape — anchor:

```
rg -n 'cg-empty' demo/
```

One hit, `demo/pure/card-gap.typ:27`,
`#idea("cg-empty", title: [An empty-bodied card])[]`.

The new file declares, at minimum:

1. A titleless note whose body is ordinary prose.
2. A titleless note whose body BEGINS with a bare URL —
   `https://anil.recoil.org/projects/unikernels` — to exercise the URL-tail
   rule.
3. A second titleless note under the same URL host but a different path —
   `https://anil.recoil.org/papers/2024-hope-bastion` — which must take a
   DIFFERENT name. Left-to-right slugging gives both `https-anil-recoil`; that
   is the regression this case exists to catch.
4. A titleless note nested inside another note's body, which under the old
   scheme took its parent's ordinal and now does not.
5. A `#window` transcluding note 1, so its body renders twice.

Then print the ids so the shell can assert on them. `#idea-href` and the
registry are available; the simplest observable is to emit each note's id as
text. Look at how `demo/pure/excluded.typ` makes its claims greppable —
anchor `rg -n 'count=' demo/` — and follow that pattern rather than inventing
one.

## 2. Register it in `demo/pure/Justfile`

The `build` recipe compiles each root explicitly. Anchor:

```
rg -n 'excluded.typ build/excluded.html' demo/
```

One hit, in `demo/pure/Justfile`'s `build` recipe. Add an HTML compile for
`naming.typ` beside it, in the same style. HTML only is enough — this case
asserts nothing about the paged target.

The header comment above that recipe explains which roots are built both ways
and why. Extend it to mention the new root, in the same register: `just`
echoes a `#` line inside a recipe body as if it were a command, so the
explanation belongs in the header, not among the commands.

## 3. Assertions in the `check` recipe

`demo/pure/Justfile`'s `check` recipe is a bash block of `grep -q` calls with a
`note()` helper for failures. Add:

- The URL-bodied notes took DIFFERENT names, and neither name contains
  `https` or starts with `http`.
- The transcluded note carries the SAME id in both places it appears — grep
  the id and confirm it occurs more than once, and that no variant of it with
  a different trailing digest exists.
- The nested note's id is NOT of the form `<parent>-<digit>`.

Follow the file's own rule for why the assertions live in the recipe: they are
claims about the OUTPUT, which a Typst `assert` cannot see.

## 4. One rheo-side assertion in `demo/rheo/check.sh`

`demo/rheo` is where a note's marrow-minted page exists, and a minted page is a
second rendering of the same body — the case that broke before. The file greps
the built HTML; anchor:

```
rg -n 'href="ideas/root-note.html"' demo/
```

One hit, `demo/rheo/check.sh:26`.

Add one assertion in that style: a titleless note's minted page is named by its
content digest, and the id used on the authoring vertebra matches the id in the
minted page's filename. If `demo/rheo`'s content has no titleless note, add one
to the demo's content and say so in your report.

## NON-GOALS

- Do NOT edit anything under `src/` or `.marrow.typ`. If a case fails because
  the implementation is wrong, report it rather than fixing it here.
- Do NOT add a `test/units.typ` assertion. Unit coverage of the pure helpers
  already exists; this bird is about compiled documents.
- Do NOT add a PDF compile for the new root.
- Do NOT commit anything under `demo/pure/build/` or `demo/rheo`'s build
  output — both are gitignored artifacts.

## VERIFY

```
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/pure && just build
```

prints `demo/pure OK`, having compiled `naming.typ` among the roots.

```
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check
```

passes, including the new assertion.

Then confirm the new case genuinely tests the URL rule — make it fail on
purpose by changing one of the two URL-bodied notes to share the other's full
URL, re-run `just build`, and see `check` report a failure. Change it back.