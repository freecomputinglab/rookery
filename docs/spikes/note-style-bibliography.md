# Spike report: note-style bibliographies in rookery core

`core/0.1.1/demo/notes` is the failing fixture this spike adds: one idea,
one citation, `footnotes: "horizontal"`, `bibliography: arguments(bytes(read("refs.bib")), style: "chicago-notes")`.
`rheo compile .` there exits non-zero with `failed to determine link anchor`
/ `failed to resolve cross-link`, the same pair the bird's own recon
recorded. All findings below were checked against this fixture, the
core-free single-file repro from the bird's recon, and two scratch
restructurings of `core/0.1.1/src` (outside this repository, per the bird's
non-goals) — none of the three touched anything under this repo's own
`core/0.1.1/src/`.

## Correction to the filing recon: plain Typst hard-errors too

The bird's recon reported that the core-free repro, under plain
`typst compile --features html --format html` with no rheo at all, only
*warns* `document did not converge within five attempts`. Re-running that
exact repro under the Typst version pinned on this machine (`typst 0.15.1
(9dfd3a08)`) instead exits 1 with `error: failed to determine link anchor` —
the identical hard error rheo reports, and for the identical reason: Typst's
own HTML link-anchor resolver, not rheo's link-rewriting rule, refuses to
settle. `--format pdf` (paged, not HTML) on the same file exits 0 — the
failure is HTML-export-specific, in Typst itself.

The one part of the original recon that still holds, and that isolates the
trigger precisely: a **literal**, unconditionally-placed
`#bibliography(bytes(read("refs.bib")), style: "chicago-notes")` compiles
clean under plain Typst HTML export. Gate that exact same call behind
`state(..).final()` read inside `#context` — nothing else changed — and it
hard-errors. So the trigger is not "a note-style bibliography under HTML
export" in general; it is a note-style bibliography whose placement in the
document depends on a state read.

## What converges and what does not

Each case below was verified at filing with `typst 0.15.1`, `typst compile --features html --format html`, one `refs.bib` entry `smith2020`:

1. **Converges:** a literal `#bibliography(bytes(read("refs.bib")), style: "chicago-notes")`, placed before or after the citation, with or without `#context` around it.

2. **Converges:** two literal note-style bibliographies in one document, each claiming the citations before it. Core's per-idea positional partition is not itself the problem.

3. **Converges:** `#context { let _ = s.get(); bibliography(<literal args>) }`, a context block that reads an updated state but emits the bibliography the same way every time.

4. **Converges:** a literal-args bibliography whose sibling is a context-dependent element, e.g. `#context html.elem("span", attrs: ("data-x": str(s.get())))` then the bibliography.

5. **Fails** (`error: failed to determine link anchor`): the bibliography's arguments come from an updated state, as in `#context bibliography(..s.get())` or `..s.final()`. Core's `_bib-call` (bib.typ) does exactly this.

6. **Fails:** the bibliography's presence depends on an updated state, as in `#context { if s.get() == 1 { bibliography(..) } }`.

7. **Fails:** a context-dependent wrapper around the bibliography, as in `#context html.elem("div", attrs: ("data-x": str(s.get())), bibliography(..))`.

8. **Converges even with cases 5–7's state plumbing:** no citation is left in a form that makes Typst mint a native footnote. A `show cite` rule that re-emits every citation as `cite(it.key, supplement: it.supplement, form: "full")` makes this compile cleanly: state-sourced args, a state gate, and a state-dependent `html.elem` wrapper, all at once. The failing link is the anchor of the footnote Typst auto-mints for a normal-form note-style citation. With no such footnote there is nothing to converge.

9. A citation written inside a `#footnote[..]` under a note style mints a second, nested native footnote. Typst does not special-case citations already in a note.

10. A `show footnote: it => ..` rule does see Typst's auto-minted note footnotes (their `it.body` is the note-form text), but Typst still emits its own `<section role="doc-endnotes">`. Core numbers footnotes by walking the raw markup for its own `#footnote` markers, and an auto-minted footnote never appears in that walk. That is why a note-style citation on `http://localhost:3000/ideas/26w25.html` (waterline) shows as a native endnote at the page end, not a margin note.

11. Typst built-in styles that are note-class (each mints `doc-noteref`): `chicago-notes`, `chicago-shortened-notes`, `chicago-fullnotes`, `turabian-fullnote-8`, `modern-humanities-research-association`. Checked and NOT note-class: `chicago-author-date`, `turabian-author-date`, `harvard-cite-them-right`, `ieee`, `apa`, `mla`.

## This is the same failure class rheo's own docs already name

`/home/lox/code/_fcl/rheo/docs/link-rule.md` documents an identical error,
`failed to determine link anchor`, for `std.outline()` in multi-page HTML
output: an outline links to a heading by Typst `Location`, not a label, and
upstream `typst-bundle` 0.15.0's own anchor resolver never settles on a page
path for a `Location`-typed destination within Typst's five-attempt
convergence cap — the doc calls this "the cause is upstream" and "not
available in multi-page HTML output today." A note-style bibliography's
auto-minted footnote link is destination-typed the same way (Typst mints it,
not the document's author), so it inherits the same upstream ceiling.

That still does not fully explain why the literal placement converges and
the state-gated one does not, since both mint the same kind of
`Location`-typed footnote link. The `link-rule.md` doc has the answer for
that too, under "What the change does not buy: convergence": Typst cap its
fixpoint at 5 attempts *total for the page*, shared across every
introspection-dependent element on it, and a page that spends more of that
budget on other `context`/`query`/state reads has less left for any one
anchor to stabilize in. A `state(..).final()` read inside `#context` is
exactly such a spend. `core`'s own bibliography plumbing (`_bib.final()`,
read from `_bib-call`, `_refs-block`, and `_sweep-block`, per the bird's
recon fact 4) does this once *per idea and per window on the page*, not
once — so a real project's page, with several ideas, spends far more of
that shared budget than the two-line repro does, which is consistent with
the fixture failing outright while a single-call, hand-reduced case still
sometimes converges.

## What actually removes the convergence error, and what it breaks instead

Finding 8 shows that state reads are harmless once the bibliography's
arguments themselves do NOT come from state. To test that directly, I
restructured a scratch copy of `core/0.1.1` (outside this repository) so
`_refs-block` and `_sweep-block` — the two per-idea/per-window entry points
that call `_bib.final()` — return empty unconditionally, leaving exactly one
bibliography call: the template's own trailing one, rewritten to take
`bib-args` as a plain local (computed once inside `rookery()`, no state
read) rather than through `_bib.final()`. The convergence error vanished
against a fuller demo (eight ideas, several citations, cross-idea windows),
but revealed that collapsing to one page-level bibliography call is not a
drop-in swap for today's per-idea `_refs-block`/`_sweep-block` calls — those
also carry the per-idea References-block *visibility* (an idea's own
citations, listed under its own card) and the full-form citation lookups
that `_fn-side` uses for margin notes. A correct fix keeps exactly one
*bibliography()* per page (the part whose arguments must NOT come from state
to converge) while still deciding, separately, which idea's citations are
*shown* under which heading — the visual per-idea split and the underlying
single Typst bibliography call are two different concerns that today's code
fuses into one `_bib.final()` read at every site.

## The two problems that wait behind the compile error (confirmed, unchanged from filing)

1. **A note-style citation's footnote is Typst's own `std.footnote`, not
   core's `#footnote` wrapper.** Core's footnote machinery walks a marker
   only `#footnote` (`pure.typ`) emits; a citation Typst auto-converts to a
   footnote never gets one, so it cannot join a `footnotes: "horizontal"`
   margin note or a `footnotes: "vertical"` Footnotes block — it lands in
   Typst's own `doc-endnotes` section, outside the `data-rookery="mode"` CSS
   split entirely.
2. **`_margin-cite` (bib.typ) still mints a `data-rookery-cite` margin span
   beside a note-style citation**, duplicating text the citation's own
   auto-footnote already carries. Detecting a note style to skip this has no
   API surface on `cite`/`bibliography`; the only workable signal is
   comparing the author's `style:` string against Typst's built-in
   note-style names (`"chicago-notes"`, `"ieee"` in some variants,
   `"chicago-note"`, etc. — the exact list Typst ships internally). A
   project supplying its own `.csl` file cannot be classified this way at
   all: nothing short of parsing the CSL XML's own `class="note"` attribute
   would work, and core has no CSL parser. **Recommendation: an explicit
   parameter** (e.g. `note-style: bool` or accepting a fourth value on
   `citations:`), not name-sniffing — sniffing built-in names silently
   mis-detects a custom CSL file either way, so nothing is lost by asking
   the author to say so instead of guessing.

## Which layer owns each part of the failure

- **Typst's own HTML export** owns the raw convergence ceiling on
  `Location`-typed anchors — the same limitation `link-rule.md` already
  documents for `std.outline()`, upstream in `typst-bundle`, not something
  rheo's link rule can special-case around (it does not touch
  `Location`-typed destinations at all, by design).
- **rheo** owns nothing extra here beyond inheriting that ceiling; the
  identical failure reproduces with no rheo present. rheo's own docs already
  say where to look when a convergence budget runs out ("find which `query`
  is being fed") — `core` is the thing feeding it in this case.
- **`@rookery/core`** owns the actual fix: preventing the bibliography's
  arguments from coming from a state read is what allows Typst to converge —
  the convergence budget is shared with every introspection-dependent element
  on the page, and a `state(..).final()` read on the bibliography's own args
  spends budget that a `Location`-typed footnote anchor needs. Core also owns
  the decision whether Typst ever mints a native footnote for a citation at
  all, via the `citations:` and `style:` parameters — moving note-style
  citations into core's own footnote mechanism (finding 8) bypasses the
  `Location`-typed anchor problem entirely, and core owns both the footnote
  wrapping and margin-cite machinery that enable it.

## Recommendation

Core never lets Typst mint a native footnote for a citation. Under a
note-style bibliography, core treats each prose citation as one of its own
footnotes, holding `cite(key, supplement: .., form: "full")`. That footnote
then follows `footnotes:` like any other: a margin note under "horizontal",
the Footnotes block under "vertical". Triggering: `citations: auto` resolves
to a new `"notes"` value when the configured `style:` is one of the built-in
note styles in finding 11, and a project using a custom note-class `.csl`
sets `citations: "notes"` explicitly. Known trade-off: `form: "full"`
renders the bibliography-entry form ("Smith, John. "A Study." …, p. 9"), not
the CSL's note form ("John Smith, "A Study," …"). Typst exposes no note-form
rendering that avoids minting a footnote. The breakdown is one implementation
bird: "Render note-style citations as core footnotes".

## Implementation

**Render note-style citations as core footnotes.** When the configured `style:`
is one of the note-class built-ins or `citations:` is explicitly set to
`"notes"`, the citation resolver converts each `cite(..)` call into a core
`#footnote` holding `cite(key, supplement: .., form: "full")` instead of
emitting the citation inline and letting Typst mint its own footnote. The
footnote then integrates with `footnotes:` mode like any other (margin notes
or Footnotes block). The bibliography itself emits once, state-independently,
at the page level; its arguments do not depend on any state read.
