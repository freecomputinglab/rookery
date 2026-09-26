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

To test that theory directly, I restructured a scratch copy of `core/0.1.1`
(outside this repository) so `_refs-block` and `_sweep-block` — the two
per-idea/per-window entry points that call `_bib.final()` — return empty
unconditionally, leaving exactly one bibliography call: the template's own
trailing one, rewritten to take `bib-args` as a plain local (computed once
inside `rookery()`, no state read) rather than through `_bib.final()`. Built
against a fuller demo (a copy of `core/0.1.1/demo/sidenotes` with a note
style added, eight ideas, several citations and cross-idea windows) that
this reduction was tried on:

- **The convergence error is gone.** No more `failed to determine link
  anchor`, no more `did not stabilize` warnings.
- **A different, more ordinary error takes its place**: `label <knuth1984>
  does not exist in the document`, and `the document does not contain a
  bibliography`, raised from `state.typ`'s own `cite(label(k), form:
  "full")` call — the mechanism `_fn-side` uses to build a footnote's
  trailing `sidenote-refs` text. With every per-idea bibliography call
  removed and only one left at the very end of the page, an earlier
  citation's `cite(.., form: "full")` lookup runs before any bibliography
  has been laid out at all, and Typst's own full-form citation resolution
  needs one to already exist nearby, not merely somewhere later in the
  document.

So collapsing to one page-level, state-independent bibliography call is a
real fix for the convergence failure, but it is not a drop-in swap for
today's per-idea `_refs-block`/`_sweep-block` calls — those also carry the
per-idea References-block *visibility* (an idea's own citations, listed
under its own card) and the full-form citation lookups that `_fn-side` uses
for margin notes. A correct fix keeps exactly one *bibliography()* per page
(the part that must be state-independent to converge) while still deciding,
separately, which idea's citations are *shown* under which heading — the
visual per-idea split and the underlying single Typst bibliography call are
two different concerns that today's code fuses into one `_bib.final()`
read at every site.

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
- **`@rookery/core`** owns the actual fix: routing the bibliography's
  *presence* through per-idea/per-window `state(..).final()` reads is what
  spends the shared convergence budget a `Location`-typed footnote anchor
  needs, and core owns every one of those read sites (bib.typ's
  `_bib-call`, `_refs-block`, `_sweep-block`, state.typ's `_bib-keys`) plus
  the two behind-the-error problems above (footnote wrapping, margin-cite
  duplication).

## Recommendation

Fix this in `@rookery/core`, in two independent pieces:

1. **One bibliography() call per page, state-independent.** Compute
   `bib-args` once inside `rookery()` (already a plain local there) and pass
   it directly into whatever emits the actual `bibliography(..)` call,
   rather than round-tripping it through `_bib.final()`. Keep the per-idea
   and per-window *visibility* decisions (which heading gets a References
   block, `display-bibliography:`, the group-window combined block) as a
   separate concern from *emitting* the call — they can still read
   `_bib.final()` for their own bookkeeping (which keys are whose), as long
   as only one site in the whole page tree actually calls
   `bibliography(..)`. This is the one avenue that measurably removes the
   convergence error; the remaining work is re-deriving the per-idea
   visibility split without it depending on a second bibliography call.
2. **Gate `_margin-cite` and the footnote-wrapping problem behind an
   explicit note-style flag**, not name-sniffing `style:`. Add a parameter
   (`citations: "notes"` alongside today's `"vertical"`/`"horizontal"`, or a
   sibling `note-style: bool`) that a project sets itself. Under it: skip
   `_margin-cite` entirely (Typst's own auto-footnote already carries the
   full reference), and either accept that a note-style citation's footnote
   lives in Typst's native `doc-endnotes` section (documented as a known gap
   — it does not join `footnotes:` mode), or teach `pure.typ`'s footnote walk
   to also recognize Typst's native footnote marker so it can fold into
   core's own Footnotes-block/margin-note machinery. The second is more work
   and belongs in its own bird once the convergence fix above lands and can
   be tested against a real footnote instead of a citation.

## Breakdown into implementation birds (not filed)

- **Route the trailing bibliography through a state-independent local.**
  `rookery()`'s `bib-args` local feeds one, unconditional, page-level
  `bibliography(..)` call directly; `_bib.final()` stays for every other
  site that only needs to know *which keys*, not to emit the call itself.
  Verify against `core/0.1.1/demo/notes` (this fixture) compiling clean.
- **Re-derive per-idea/per-window References visibility without a second
  bibliography() call.** `_refs-block`/`_sweep-block` keep deciding whether
  an idea's own citations are *listed* under its card, using the single
  call from the bird above instead of minting their own.
- **Add an explicit note-style switch and stop `_margin-cite` duplicating
  it.** A parameter the author sets (not `style:`-name sniffing); skips the
  citation's own margin span under it.
- **Decide native-footnote fold-in for note-style citations.** Whether a
  note-style citation's Typst-native footnote joins core's `footnotes:`
  mode or stays documented as living in Typst's own `doc-endnotes` section;
  depends on the bird above landing first.
