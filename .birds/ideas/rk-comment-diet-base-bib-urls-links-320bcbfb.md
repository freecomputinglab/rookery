---
id: rk-comment-diet-base-bib-urls-links-320bcbfb
short-id: '32'
title: 'Comment diet: base, bib, urls, links'
priority: 3
labels:
- chore-core-review
deps:
- blocked-by:rk-cache-bib-keys-drop-dead-cite-walk-871b6099
closed: false
---
Four comments in the reading modules name a tracker item — three issue ids and
one "(readme bead)" TODO — which the project's comment rules forbid outright.
Remove them, and give the same present-tense pass to the seven files they sit
in.

Touches: /home/lox/code/_fcl/rookery/core/0.1.0/src/base.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/src/bib.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/src/hyperlink.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/src/permalink.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/src/urls.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/src/links.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/src/lib.typ

## The rubric

`/home/lox/code/_fcl/rookery/CLAUDE.md`, the section headed "Comment style", is
the standard. Read it before editing. Restated so this bird stands alone:

- **Describe the present.** What the code is and why it is that way. Never what
  it used to be, what moved where, which release changed it, or that something
  "is gone".
- **No issue ids**, bookmark names or branch names. Most readers of a comment
  have no access to the tracker and no interest in one, so the argument for a
  line has to stand on its own.
- **Keep the measurement, drop the lab notebook.** A number that justifies a
  constant stays and says what it buys; the machine, the date, the baseline it
  beat and the alternatives that lost go — unless a future reader would
  otherwise retune the number, and then one sentence.
- **One header per file, no interior banners** restating it.
- **Comment the non-obvious.** What earns a line: a constraint the code cannot
  express, a contract a caller would otherwise get wrong, a rule shared with
  another language. Not a restatement of the line below it.
- **Declarative and concise, present tense.** Emphasis capitals for the one
  claim in a block that carries it. Comments should be a minority of the lines.

A `REJECTED`/`REFUTED` block is not automatically deletable: keep the RULE as
one or two present-tense sentences, delete the narrative.

## The four hard violations — these are the point of the bird

Line numbers are as of filing; match the quoted text if they have shifted.

1. `base.typ:20` — `// Document this as a hard requirement (readme bead).` A
   TODO pointing at a tracker item. Delete the sentence. The requirement it
   points at is already stated in the four lines above it (every invocation,
   including a plain paged build with no rheo, needs `--features html`, because
   `std.target` is gated by the compiler feature rather than by output format)
   and that statement stays.
2. `base.typ:216-217` — `// \`rheo.toml [inputs]\` table are specced (rheo beads
   \`rheo-cli-input-flag-q12\` / and \`rheo-toml-inputs-table-rih\`); nothing
   here changes when they land.` Delete both ids and the whole clause about
   planned rheo work. Keep the present-tense half: `rheo compile` forwards no
   `--input`, so the two `sys.inputs` keys reach a plain `typst compile` only,
   while the declared list works everywhere.
3. `bib.typ:108-113` — the `windows-claim: false` comment ends "the same
   contamination `rookery-bib-minted-m6h` had just fixed, reintroduced from the
   other side". Delete the id and the narrative. Keep the rule, which is the
   whole reason the parameter exists: a collapsed window is a bare permalink, so
   it emits no references block and claims nothing, and the idea therefore keeps
   its own citations — while a nested `#idea` always renders its own block and
   stays a claimant either way.
4. `hyperlink.typ:70-74` — "MEASURED CORRECTION to this bead's own sketch: it
   assumed the registry stored a dict with a `.title` field directly. It stores
   `(title:, body:)` now (added by this bead, since nothing previously persisted
   the title) — see `#idea`'s registration step." Delete the whole block. The
   one fact in it worth keeping is already stated by the code below and in the
   banner above: a note with no title falls back to the bare id text.

Also `lib.typ:21` — "That leaky requirement (REJECTED 2026-08-14) is worse than
not having the feature". Delete the parenthesised date. The reason stays, and it
is a good one: rheo's package asset auto-detection scans only a project's own
`.typ` files, so a `#preview` composing another package from inside this one
would make every consuming project import that package directly just to get its
JS injected.

## The rest of the work

5. `base.typ`'s CONSUMED BY `.marrow.typ` banner (48-108): keep the list of
   names and, above all, the failure mode — rheo returns None for a marrow it
   cannot read instead of erroring, so a broken marrow compiles, mints nothing,
   and reports no error. Compress the CI-and-version passage (98-108, "COVERED
   BY CI as of rheo 0.5.2... PR #164, released 2026-08-16... MEASURED on a
   from-source build at tag v0.5.2") to one sentence: the demo is what proves
   marrow mints, CI runs it against the release named by `[tool.rheo]
   min_version` in `typst.toml`, and nothing in rheo enforces that key.
   **Check the counts before keeping them.** The banner claims "THIRTY names,
   twenty-eight of them underscore-private", and `pure.typ` claims marrow
   "imports seventeen of `lib.typ`'s own internals" while `base.typ` says
   "eighteen". Count the real import list with
   `grep -n 'import "@rookery/core' /home/lox/code/_fcl/rookery/core/0.1.0/.marrow.typ`
   and either correct every number or drop the numbers and say "every name
   listed below" — a stale count is worse than no count. (The numbers in
   `pure.typ` belong to another bird; fix only `base.typ`'s.)
6. `base.typ`'s excluded-tags banner (171-217): keep the composition formula,
   why the decision must be readable with no `#context` (the gate sits above the
   `figure(kind: IK)` marker that five structural walks depend on), and why a
   `rookery.with(exclude-tags: ..)` state cannot work. Compress the two
   `REJECTED` passages to the rules they carry — a template argument becomes
   state and state needs context; a `show figure.where(kind: IK): none` does not
   remove the figure from `query()`.
7. `urls.typ`'s `_resolve-dest` banner (65-112) is 48 comment lines. Keep the
   rules, all four of them: the dest is handed to rheo unresolved as
   `rheo-page:<handle>` because a show rule installed by the enclosing
   `#document` applies afresh at each realization while a `context` read inside
   a replayed body does not; it is a string and not a label because Typst
   attaches labels syntactically, so a computed label does not exist; this is a
   hard rheo floor rather than a graceful degradation; and `link-to: "anchor"`
   plus every non-rheo target still falls back to the label. Drop the
   convergence anecdote (lines 84-88, the four pages at two depths and the 72
   dead links) — one clause, that a non-converging document collapses every copy
   of a replayed `context` read to one shared value, carries what a reader
   needs.
8. `urls.typ:29-35`, `permalink.typ:70-80`, `permalink.typ:95-100` and
   `permalink.typ:176-191` each describe what the code replaced ("`.marrow.typ`
   used to derive all three itself", "It used to render inside the heading", "
   used to reach this pill as an inline style", "It used to be TWO renderings").
   Rewrite each as the present rule: the mirror lives in one function and marrow
   reads it; the date is the hat's other end and is emitted last; the pill wears
   the class and the colours arrive as generated rules; one bottom-out rendering
   serves both places a window can run out of budget.
9. `links.typ` and `lib.typ` need little beyond point 4's date: read them for
   anything that describes the past and leave the rest. `lib.typ`'s statement
   that the import order is the dependency order, and why, is exactly the kind
   of comment the rubric asks for — keep it in full.

## Do NOT

- **Do not change one token of code.** Not a rename, not a reformat. Comments
  only.
- Do not delete a comment that states a constraint, a caller contract, a
  measured number that justifies a constant, or a parity link.
- Do not add a claim you have not verified in the code in front of you.
- Do not touch any file outside the seven named above. `state.typ`, `pure.typ`,
  `idea.typ`, `window.typ`, `outline.typ`, `transclusion.typ`, `data.typ`,
  `template.typ`, `theme.typ` and `row.typ` all belong to sibling birds.

## VERIFY

A comment edit that swallows a line of code fails these, so all four must still
be green:

```sh
cd /home/lox/code/_fcl/rookery/core/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/pure && just build
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check-typst
```

Expected last lines: `units OK`, `demo/pure OK`, `demo/rheo OK`,
`demo/rheo (native) OK`.

Then the hard gate — no tracker reference may survive anywhere in the package:

```sh
cd /home/lox/code/_fcl/rookery/core/0.1.0/src && grep -rnE "rookery-bib-minted-m6h|rheo-cli-input-flag-q12|rheo-toml-inputs-table-rih|readme bead|this bead|REJECTED 2026" .
```

Expected: no output. (`this bead` may still appear in `transclusion.typ`, which
is a sibling bird's file — if it does, report it rather than editing it.)

And the size check:

```sh
cd /home/lox/code/_fcl/rookery/core/0.1.0/src && for f in base.typ bib.typ hyperlink.typ permalink.typ urls.typ links.typ lib.typ; do echo "$f $(grep -c '^[[:space:]]*//' $f)/$(wc -l < $f)"; done
```

Today: `197/251`, `107/191`, `128/189`, `151/216`, `113/146`, `57/90`, `43/60`.
Land each at roughly 60% of its comment count or below, except `lib.typ`, which
is a manifest and whose comments are its content — leave that one near where it
is. The count is guidance, not a gate: losing a constraint to hit a number is
the one failure this bird cannot accept.