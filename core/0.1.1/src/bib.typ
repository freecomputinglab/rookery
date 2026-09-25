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
// Emitted (but `hidden`, via CSS) even in horizontal mode, where the margin
// notes already show every reference in full: Typst partitions citations
// POSITIONALLY, so a citation with no bibliography following it is a hard
// error, and this block is that bibliography.
//
// `horizontal:` overrides `_footnote-mode` for this one call: `false` keeps
// the block visible regardless of the document-wide mode, which is what an
// idea with `display-right-gutter: false` needs — its citations render
// inline only, so its references have nowhere else to be read. `auto` (the
// default) defers to `_footnote-mode` as before.
#let _refs-block(keys, id: none, horizontal: auto) = {
  if _bib.final() == none or keys.len() == 0 { return [] }
  if _target() == "html" or _target() == "epub" {
    context {
      let attrs = (class: _c("references"), data-rookery: "references")
      if id != none { attrs = attrs + (id: id) }
      let mode-horizontal = if horizontal == auto {
        _footnote-mode.final() == "horizontal" and _in-window.get() == 0
      } else {
        horizontal
      }
      if mode-horizontal and _target() == "html" {
        attrs = attrs + (hidden: "hidden")
      }
      html.elem("div", attrs: attrs, _bib-call([References]))
    }
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

// A `show cite` rule, applied only under horizontal html (`_footnoted`
// below): beside every inline citation marker, mint a margin note carrying
// the FULL reference — the same information the vertical Footnotes block's
// References section would otherwise be the only place to find.
//
// `it.form == "full"` is the recursion guard: the full-form `cite` this rule
// itself mints below re-enters the same show rule when it renders, and must
// pass through unchanged rather than growing a margin note of its own.
// `it.form == none` is defensive for the same reason, in case a caller ever
// constructs a citation with no form set.
//
// Skipped entirely inside a sidenote (`_in-sidenote.get()`, state.typ): a
// citation written inside a footnote is already in the margin, and stays
// inline there rather than spawning a second margin note. Unnumbered and
// idless, unlike `_fn-side` — the inline marker beside it already identifies
// which work it names, and two citations of the same work each get their own
// note rather than being deduplicated.
//
// Also skipped inside a window (`_in-window.get()`, state.typ), and not only
// via `_footnoted`'s own gate: a host card's `show cite: _margin-cite` rule
// stays in scope for content a nested window renders inside it, since the
// window installs no rule of its own when it falls back to vertical mode —
// this is the guard that keeps such a citation out of the host's margin.
#let _margin-cite(it) = {
  if it.form == "full" or it.form == none {
    return it
  }
  it + context {
    if _in-sidenote.get() or _in-window.get() > 0 {
      []
    } else {
      html.elem(
        "span",
        attrs: (
          class: _c("sidenote") + " " + _c("sidenote-cite"),
          data-rookery: "sidenote",
          data-rookery-cite: "cite",
        ),
        cite(it.key, form: "full"),
      )
    }
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
// `horizontal:` overrides `_footnote-mode` for this one call — `auto` (the
// default) defers to it as before; `false` renders vertically regardless of
// the document-wide mode. This is what `display-right-gutter: false` needs:
// that idea's footnotes and citations fall back to the vertical blocks even
// though the rest of the document is in horizontal mode.
#let _footnoted(body, horizontal: auto) = {
  let mode-horizontal = if horizontal == auto {
    _footnote-mode.final() == "horizontal"
  } else {
    horizontal
  }
  let notes = _footnotes(body)
  if notes.len() == 0 {
    // No footnotes to number, but citations still need `_margin-cite` under
    // horizontal html — an idea with no footnotes still gets margin
    // citations. Reading `.final()` needs `context`, so this path is no
    // longer a bare pass-through of `body`.
    //
    // `_in-window.get()` is read INSIDE this context, not folded into the
    // eager `mode-horizontal` above: this whole function runs synchronously
    // inside whatever context its caller already established (`_window-
    // content`'s, typically), a SINGLE fixed position, so a read taken there
    // cannot see an `_in-window.update()` that is itself part of the very
    // content this call is helping build. This `context` literal is
    // returned as content and gets its OWN position once actually laid out
    // — after the update, if the update sits earlier in the tree — which is
    // what makes the read here correct.
    return context {
      if mode-horizontal and _in-window.get() == 0 and _target() == "html" {
        show cite: _margin-cite
        body
      } else {
        body
      }
    }
  }
  _fn-block.step()
  context {
    let b = _fn-block.get().first()
    // Horizontal mode is HTML-only (see `_fn-side`'s CSS, core.css) — paged
    // and epub always get the vertical block below, regardless of the mode.
    // `_in-window.get()` is read here for the same reason as the no-notes
    // branch above.
    let horizontal = mode-horizontal and _in-window.get() == 0 and _target() == "html"
    if horizontal {
      show cite: _margin-cite
      _number-footnotes(body, 1, n => _fn-ref(b, n) + _fn-side(b, n, notes.at(n - 1))).node
    } else {
      _number-footnotes(body, 1, n => _fn-ref(b, n)).node
      _fn-block-html(notes, b)
    }
  }
}
