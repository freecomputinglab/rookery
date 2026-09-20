---
id: rk-document-why-idea-row-s-target-must-1a1aeba0
short-id: 1a
title: 'Document why #idea-row''s target() must stay bare'
priority: 4
labels:
- chore-core-review
deps: []
closed: false
---
`#idea-row`'s paged-target guard calls the bare Typst builtin `target()`
rather than this package's own `_target()` helper (`src/base.typ`) — and,
unlike every other file in this package, `row.typ` does not import `base.typ`
at all. That is not an oversight to "fix" by adding the import: `target()` and
`_target()` answer a DIFFERENT question for EPUB, and swapping to `_target()`
here would silently break `#idea-row` under an EPUB build. Nothing in the
package currently says so, and nothing tests it.

Touches: /home/lox/code/_fcl/rookery/core/0.1.0/src/row.typ

## What is wrong

`src/row.typ:149-163`:

```typ
#let idea-row(
  ...
) = context {
  assert(target() == "html", message: _paged-panic)
```

`row.typ` imports only `#import "state.typ": _c` (line 22) — it does not
import `base.typ`, so `target()` here is Typst's own unqualified builtin
(equivalent to `std.target()`), not this package's `_target()`.

`base.typ` (`src/base.typ:9-25`) documents exactly why that distinction
matters everywhere else in the package:

```
// `std.target()` reports EPUB as "html"; rheo's own context distinguishes
// them. Use `std.target()` rather than a bare `target()`: rheo injects its
// `target()` polyfill into each vertebra's scope, not into package scope.
```

Every other `_target()`-using site in this package treats HTML and EPUB the
same way, as `_target() == "html" or _target() == "epub"` (see
`idea.typ:506`, `window.typ:163`, `transclusion.typ:163`, `outline.typ:538`,
`template.typ:634`, among others) — because `_target()` reads
`_rheo-ctx().target` when rheo is present, and rheo DOES distinguish "epub"
from "html" there.

`row.typ`'s guard, by contrast, only accepts `target() == "html"` — no
`or "epub"` branch — and that is what makes it correct FOR THE WRONG REASON:
`std.target()` (what bare `target()` resolves to here, since nothing in this
file shadows the name) folds EPUB into `"html"`, per `base.typ`'s own
banner above. So an EPUB build passes this assert today, but only because of
that folding — not because `row.typ` was written with EPUB in mind.

**This is a real landmine, not a hypothetical one.** `row.typ`'s own header
says this shape is consumed by `@rookery/search`, `@rookery/todos` and
`@rookery/timeline` for their row-based views (filter panels, upcoming lists).
If a future edit "cleans up" `row.typ` by importing `base.typ` and swapping
`target()` for `_target()` — the package's own stated convention, followed
everywhere else — `_target()` would then report `"epub"` distinctly under
rheo, the `== "html"` check would fail, and `#idea-row` would start panicking
on every EPUB build across all three consuming packages, with no test
anywhere in this repo (core or otherwise) that would catch it.

Confirmed nothing tests this: `grep -rn "idea-row" test/` and
`grep -rn "format html.*epub\|--format epub" .` under
`/home/lox/code/_fcl/rookery/core/0.1.0` turn up nothing — this package's own
suite never compiles anything to EPUB at all (`Justfile`, `demo/pure/Justfile`,
`demo/rheo/Justfile` all use `--format pdf` or `--format html`, never `epub`).

## Decisions already made — do not re-derive

- **Do not import `base.typ` into `row.typ`, and do not change `target()` to
  `_target()`.** That would be the regression this bird exists to prevent, not
  the fix. `row.typ`'s own header explains it stays HTML-only and imports
  nothing from `base.typ` on purpose — see lines 1-21.
- **The fix is documentation, not behaviour.** Add a comment at the assert
  site recording why the bare builtin is used here and what an "obvious"
  cleanup would break — so the next person to read this file has the same
  information the rest of the package's `_target()` sites already carry.
- **No test infrastructure changes.** Adding an EPUB compile target to this
  package's own `Justfile`/`demo` suites, purely to cover a function this
  package does not itself call (`idea-row` has no caller inside `core`), is
  out of scope — flag it in your report rather than adding it here.

## Steps

1. In `/home/lox/code/_fcl/rookery/core/0.1.0/src/row.typ`, immediately above
   the `assert(target() == "html", message: _paged-panic)` line (currently
   line 163), add:

   ```typ
   // BARE `target()`, DELIBERATELY NOT `_target()` (src/base.typ) — and this
   // file imports no `base.typ` for exactly that reason. `std.target()`
   // (what the unqualified builtin resolves to here, since nothing in this
   // file shadows the name) reports EPUB as `"html"`; `_target()` would
   // instead read `_rheo-ctx().target` and report `"epub"` distinctly under
   // rheo. This guard wants to accept BOTH html and epub and reject only the
   // paged target, and the bare builtin's EPUB-folds-to-html behaviour is
   // what gives it that in one comparison. Importing `base.typ` here to
   // "match the rest of the package" and swapping to `_target()` would make
   // this assert start rejecting EPUB outright — untested anywhere in this
   // repo, since no `core` suite compiles to EPUB (see this package's own
   // Justfile and demo Justfiles, none of which pass `--format epub`).
   ```

2. Leave the assert itself, `_paged-panic`, and everything else in the file
   unchanged.

## Do NOT

- Do not add `#import "base.typ": *` (or any subset of it) to `row.typ`.
- Do not change `target()` to `_target()` or `std.target()` anywhere in this
  file.
- Do not add an EPUB build to this package's test/demo tooling as part of
  this bird — note it in your report as a possible follow-up instead.
- Do not touch `idea-row-body` or any other function in this file.

## VERIFY

```sh
cd /home/lox/code/_fcl/rookery/core/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/pure && just build
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check-typst
```

Expected last lines: `units OK`, `demo/pure OK`, `demo/rheo OK`, `demo/rheo
(native) OK` — this bird adds a comment only, so all four must stay exactly
as green as they are today.

Confirm the file still imports no `base.typ`:

```sh
cd /home/lox/code/_fcl/rookery/core/0.1.0 && grep -n '#import' src/row.typ
```

Expected: exactly one line, `#import "state.typ": _c`.