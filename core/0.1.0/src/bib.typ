// Bibliographies: the block an idea renders, and the walk that decides which
// citations are that idea's to render.
//
// The walk is the subtle half. A citation belongs to the idea it was written
// in, which means a nested idea or window CLAIMS the citations under it, and a
// footnote does not — the comments here record what each of those cost to get
// right.

#import "base.typ": *
#import "state.typ": *

// ---- References blocks ----------------------------------------------------
//
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

// ---- Whose citation is it, when a note contains another block? ------------
//
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

// Wrap one idea box's body: number its markers locally, then append the block.
//
// The `show FNK:` rule installed here is NESTED relative to the document-wide
// fallback `#show: rookery` installs, and the nested rule wins — MEASURED. It
// also travels with the content wherever it is later inserted, the same way
// `_flatten`'s `show ref: hyperlink` does, which is what makes a transcluded
// body number its footnotes against the window's own block rather than the
// origin idea's.
//
// `_footnoted` runs FRESH every place a note's body is rendered: once for the
// idea's own box (idea.typ), and again for every `#window` that transcludes
// it (window.typ, transclusion.typ) — `notes`, `seq` and the `show FNK:` rule
// below are rebuilt from scratch on each such call.
//
// The inline reference number is NOT read from one document-wide `counter`
// shared by every idea box. A `counter` read via `context` names a value by
// POSITION IN THE FINAL LAID-OUT DOCUMENT, and a transcluded body is replayed
// at more than one such position; sharing one counter NAME across every box
// means Typst has to reconcile writes from every placement of every note
// against a single global timeline, and MEASURED (on a real, heavily-windowed
// site) that does not converge — a footnote's number settled differently on
// different resolution passes. (A plain local variable, mutated directly
// inside the `show FNK:` handler below instead of through a counter, is
// REFUTED too: Typst raises "variables from outside the function are
// read-only and cannot be modified" — a show-rule handler cannot close over
// and mutate an outer binding.)
//
// The fix keeps `context`/`counter`, the only mechanism Typst gives a show
// rule for counting its own matches, but gives THIS call's counter a NAME
// nothing else in the document can ever share: `b`, `_fn-block`'s value for
// this exact rendering, is already unique per call (see `_fn-block` above),
// so `counter("rheo-idea-fn-" + str(b))` is a counter no other `_footnoted`
// call, anywhere in the document, ever steps or reads. Its entire history is
// the handful of `.step()` calls this one body's own footnotes make, in
// fixed structural order relative only to each other — nothing left for
// Typst to reconcile against another placement, so it converges in one pass.
//
// Returns `body` untouched when there is nothing to number, so `_fn-block` is
// not stepped for an idea with no footnotes.
#let _footnoted(body) = {
  let notes = _footnotes(body)
  if notes.len() == 0 { return body }
  _fn-block.step()
  context {
    let b = _fn-block.get().first()
    let seq = counter("rheo-idea-fn-" + str(b))
    {
      show FNK: _ => {
        seq.step()
        context _fn-ref(b, seq.get().first())
      }
      body
    }
    _fn-block-html(notes, b)
  }
}
