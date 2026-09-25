// Bibliographies: the block an idea renders, and the walk that decides which
// citations are that idea's to render.
//
// The walk is the subtle half. A citation belongs to the idea it was written
// in, which means a nested idea or window CLAIMS the citations under it, and a
// footnote does not — the comments here record what each of those cost to get
// right.

#import "base.typ": *
#import "state.typ": *

// Typst partitions citations POSITIONALLY: each `#bibliography` claims the
// citations nearest-following it. That is the whole mechanism — one
// bibliography emitted after an idea's body claims exactly that idea's
// citations, with no key filtering needed and nothing to keep in sync.
//
// Builds the call from `_bib`'s parts rather than spreading and adding
// `title:` on top: passing a named argument the spread already carries is a
// duplicate-argument error the moment an author configures their own title.
#let _bib-call(title) = {
  let cfg = _bib.final()
  let named = cfg.named()
  named.insert("title", title)
  bibliography(..cfg.pos(), ..named)
}

// `_cite-scan` answers "what does this content cite", which is a CONTENT
// question. An idea's own block needs a narrower, POSITIONAL one: "what will
// still be unclaimed by the time my block renders".
//
// A nested `#idea` or `#window` emits a references block of its own, INSIDE the
// enclosing idea's body and therefore BEFORE the enclosing idea's block. Typst
// partitions positionally, so that inner block sweeps up everything preceding
// it — including the enclosing idea's own citations — leaving the outer block
// with nothing and rendering a visible empty `<h2>References</h2><ul></ul>`,
// which is precisely what `_own-cited-keys` exists to prevent, arriving through
// ordering rather than through content.
//
// So scan the body in order, recording citations AND the nested blocks that
// will claim them. Both IK and WK count: a nested idea emits a block just as a
// window does.
#let _cite-scan(node) = {
  let out = ()
  if type(node) != content { return out }
  if node.func() == ref { return ((kind: "cite", key: str(node.target)),) }
  if node.func() == cite { return ((kind: "cite", key: str(node.key)),) }
  // A `#window` builds its `figure(kind: WK)` INSIDE a `context` block, so at
  // raw-body time there is no figure here to find — only the announce marker
  // `#window` emits up front for exactly this kind of walk (`_outbound` reads
  // the same one). Scanning for the WK figure alone misses every window and
  // leaves the empty heading in place.
  if node.func() == metadata {
    // DELIBERATELY INDEPENDENT OF `backlink:`. A window claims the citations it
    // is going to render whether or not it counts as a link from here — the two
    // are different questions, and the marker carries both. Do not "tidy" this
    // into agreement with `_outbound`/`_page-outbound`, which DO read the flag.
    if type(node.value) == dictionary and "rookery-window" in node.value {
      return ((kind: "claim", via: "window"),)
    }
    // `#footnote` carries its body as a metadata PAYLOAD, so a citation written
    // inside one is reachable ONLY through the value. Descend into it: "a
    // citation belongs to the idea in which you write it, just as footnotes do"
    // is what the documentation promises, and a footnote is written in this
    // idea. Without this branch, a citation inside `#footnote[...]` renders its
    // author-date marker with no references block anywhere naming what it cited.
    //
    // Counted ONCE, not twice. `_own-cited-keys` scans the RAW body; the
    // rendered footnote content `_footnoted` appends is never fed back through
    // it, so the payload is the only place this citation is ever seen.
    if type(node.value) == dictionary and "rookery-fn" in node.value {
      return _cite-scan(node.value.rookery-fn)
    }
    return out
  }
  // A nested `#idea`, by contrast, IS a figure by the time it lands in the
  // enclosing body: `#idea` returns one directly rather than deferring it.
  if node.func() == figure and node.at("kind", default: none) in (IK, WK) {
    return ((kind: "claim"),)
  }
  if node.has("children") { for k in node.children { out += _cite-scan(k) } }
  else if node.has("body") { out += _cite-scan(node.body) }
  else if node.has("child") { out += _cite-scan(node.child) }
  out
}

// The keys an idea's own block will actually still own.
//
// Everything after the LAST nested claimant, not the first: each nested block
// claims in turn, so it is the final one that decides what is left. A citation
// written between two nested windows belongs to the second, not to the idea.
//
// `windows-claim: false` for a context where nested windows COLLAPSE instead of
// rendering — a minted page, or any `_flatten` scope out of depth budget. A
// collapsed window is a bare permalink: it emits no references block and
// therefore claims nothing, so the idea keeps its own citations after all. A
// nested `#idea` always renders its own box and block, so it stays a claimant
// either way.
#let _own-cited-keys(body, windows-claim: true) = {
  let keys = _bib-keys()
  if keys.len() == 0 { return () }
  let scan = _cite-scan(body)
  let last = -1
  for (i, e) in scan.enumerate() {
    if e.kind == "claim" and (windows-claim or e.at("via", default: none) != "window") {
      last = i
    }
  }
  scan.slice(last + 1).filter(e => e.kind == "cite").map(e => e.key).filter(k => k in keys)
}

// One idea's references. Empty content when the idea cites nothing, so no
// stray "References" heading appears — that is what `_own-cited-keys` is for.
//
// ALWAYS emitted on html, never `hidden` in Typst's own output — whether a
// reader sees this block or the margin notes instead is a CSS decision keyed
// on `data-rookery="mode"` (core.css), not something Typst decides here.
// Typst partitions citations POSITIONALLY regardless of mode, so a citation
// with no bibliography following it is a hard error, and this block is that
// bibliography.
#let _refs-block(keys, id: none) = {
  if _bib.final() == none or keys.len() == 0 { return [] }
  if _target() == "html" or _target() == "epub" {
    let attrs = (class: _c("references"), data-rookery: "references")
    if id != none { attrs = attrs + (id: id) }
    html.elem("div", attrs: attrs, _bib-call([References]))
  } else {
    _bib-call([References])
  }
}

// Claims any unclaimed PROSE citations that precede an idea.
//
// Without it they leak into that idea's list, the partition being positional
// and the idea's own bibliography being the nearest one following them.
//
// UNCONDITIONAL, and `title: none`. Whether unclaimed prose citations precede
// a given idea cannot be determined from inside `#idea` — it never sees page
// prose — and it cannot be determined by querying either: deciding whether to
// emit a bibliography from `query(cite)` is CIRCULAR and hard-errors, because
// with none yet emitted the refs never resolve to cites, so the query finds
// nothing, so nothing is emitted, so the refs fail. A title-less bibliography
// with nothing to list renders `<section><ul></ul></section>` — no heading,
// nothing visible — which is what makes always emitting it safe.
#let _sweep-block() = {
  if _bib.final() == none { return [] }
  if _target() == "html" or _target() == "epub" {
    html.elem("div", attrs: (class: _c("page-refs"), data-rookery: "page-refs"), _bib-call(none))
  } else {
    _bib-call(none)
  }
}

// A `show cite` rule, installed exactly once per page (template.typ's
// `rookery()`, `.marrow.typ` — never here, see `_footnoted`'s banner for
// why a second installation double-wraps a window's citations): beside
// every inline citation marker, mint a margin note carrying the FULL
// reference — the same information the vertical Footnotes block's
// References section would otherwise be the only place to find. Emitted
// UNCONDITIONALLY — whether a reader sees it is CSS's call, not Typst's; see
// `_refs-block` above for why the split lives there.
//
// `it.form == "full"` is the recursion guard: the full-form `cite` this rule
// itself mints below re-enters the same show rule when it renders, and must
// pass through unchanged rather than growing a margin note of its own.
// `it.form == none` is defensive for the same reason, in case a caller ever
// constructs a citation with no form set.
//
// A citation written inside a footnote's own sidenote, or inside a nested
// window, still mints one of these spans — core.css hides it in both cases
// (`[data-rookery="sidenote"] [data-rookery-cite]`, and every sidenote inside
// `[data-rookery="window"]`) rather than Typst skipping it, so the span's
// presence never depends on where in the tree it was rendered.
#let _margin-cite(it) = {
  if it.form == "full" or it.form == none {
    return it
  }
  // Gated on the target, not the mode: a paged export has no margin, and an
  // `html.elem` inside a paragraph there is dropped with a warning.
  context if _target() == "html" {
    it + html.elem(
      "span",
      attrs: (
        class: _c("sidenote") + " " + _c("sidenote-cite"),
        data-rookery: "sidenote",
        data-rookery-cite: "cite",
      ),
      cite(it.key, form: "full"),
    )
  } else {
    it
  }
}

// Wrap one idea box's body: number its markers locally, then append the block.
//
// `_footnoted` runs FRESH every place a note's body is rendered: once for the
// idea's own box (idea.typ), and again for every `#window` that transcludes
// it (window.typ, transclusion.typ) — `notes` and the rebuilt body below are
// recomputed from scratch on each such call, which is what makes a
// transcluded body number its footnotes against the window's own block
// rather than the origin idea's.
//
// The inline reference number is NOT read from a `counter` at layout time. A
// `counter` read via `context` names a value by POSITION IN THE FINAL
// LAID-OUT DOCUMENT, and MEASURED (on a real, heavily-windowed site) a
// counter minted fresh per rendering — even one no other `_footnoted` call
// ever steps or reads — still did not converge: every trial pass read `0`
// and only the final pass read the true value, because the surrounding page
// had other content still resolving. There is nothing here for Typst to
// reconcile ACROSS ATTEMPTS in the first place — a footnote's number is
// fully decided by where it sits in this one body, which is known the moment
// the body is in hand — so `_number-footnotes` (pure.typ) decides it right
// there, with no counter and no layout dependency to converge.
//
// Returns `body` untouched when there is nothing to number, so `_fn-block` is
// not stepped for an idea with no footnotes.
//
// On html, Typst emits the SAME shape regardless of `_footnote-mode`: a
// margin note beside every marker AND the bottom Footnotes block, every
// time. Which one a reader sees is core.css's call, keyed on
// `data-rookery="mode"` — see that file for why: an html rendering that
// varied with the mode cost convergence passes on a large, deeply windowed
// project, and this function is what used to cost them.
//
// Installs NO `show cite: _margin-cite` of its own — that rule is installed
// exactly ONCE per page, at the top (template.typ's `rookery()`,
// `.marrow.typ`), not here. A `#window` transcludes a note's RAW stored
// body, so its own `_footnoted` call is a second rendering of citations the
// page-level rule has not seen yet — but the window's rendering still sits,
// structurally, inside whatever host card contains the `#window` call.
// Installing a SECOND `show cite:` here as well, nested inside the host's
// own, wrapped every citation in the window body TWICE — MEASURED: two
// identical margin-citation spans back to back — because Typst does not
// deduplicate a matching element across two independently active `show`
// statements for the same selector, only within a single one via its own
// recursion guard (`_margin-cite`'s `it.form == "full"` check). One
// page-wide installation has nothing else active to double against.
#let _footnoted(body) = {
  let notes = _footnotes(body)
  if notes.len() == 0 { return body }
  // `_fn-block.step()` is a bare statement, not assigned or joined by a
  // `return` below it — Typst auto-joins sequential statements in a block,
  // which is what makes the counter step actually land in the document
  // rather than being silently discarded (a `return` on the NEXT statement
  // would discard it instead; that is why this function has no early
  // `return` anywhere past this point).
  _fn-block.step()
  if _target() != "html" {
    // Paged and epub: the vertical block only, as always.
    context {
      let b = _fn-block.get().first()
      _number-footnotes(body, 1, n => _fn-ref(b, n)).node
      _fn-block-html(notes, b)
    }
  } else {
    context {
      let b = _fn-block.get().first()
      _number-footnotes(body, 1, n => _fn-ref(b, n) + _fn-side(b, n, notes.at(n - 1))).node
      _fn-block-html(notes, b)
    }
  }
}
