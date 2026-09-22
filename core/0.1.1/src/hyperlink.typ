// `#hyperlink` — a plain link to a note, page-or-anchor, and the `show ref:`
// rule that makes `@idea:etal` render as one.
//
// BEFORE `transclusion.typ` in the import order, and that is load-bearing:
// `_flatten` installs `show ref: hyperlink` on a transcluded body, so the name
// has to already exist when that module is evaluated. A `#let` closure captures
// the scope visible at definition time.
#import "base.typ": *
#import "state.typ": *
#import "theme.typ": *
#import "urls.typ": *
#import "permalink.typ": *

// `#hyperlink("etal")[see this]` links to note "etal"'s own minted page when
// one exists, falling back to its in-context anchor otherwise (same
// preference the permalink and `#window` already carry, via
// `_resolve-dest`). `hyperlink-target-minted: false` forces the anchor
// unconditionally, landing on the note where it was hatched — pass it per
// call, or `.with()` it for a whole-document default (see below). Name
// resolution is `_norm`'s: bare or full, string or label —
// `"etal"`, `"idea:etal"`, `<etal>`, `<idea:etal>` all reach the same note.
// Existence is checked eagerly, so a typo'd name fails at the call site
// rather than producing a dangling link.
//
// THE SAME FUNCTION is also `@idea:x`'s renderer. A note's label lives on a
// hidden anchor FIGURE, so a bare `@idea:etal` would otherwise resolve to
// that figure and render as a bare figure NUMBER, useless to a reader. This
// package installs no document template by design (the author just imports
// and calls `#idea`/`#window`/`#hyperlink`), so there is nowhere to put a
// `show ref:` rule implicitly; it must be an exported rule the author opts
// into:
//
//   #import "@rookery/core:0.1.1": idea, window, hyperlink
//   #show ref: hyperlink        // the default: the note's own minted page
//   #show ref: hyperlink.with(hyperlink-target-minted: false)   // its anchor
//
// ONE function serves both call shapes via an argument sink, the same way
// `#idea[body]`/`#idea("name")[body]` do: Typst's `show ref:` always calls
// its rule with exactly the `ref` element as the sole argument, so a single
// `content` positional whose `.func()` is `ref` means "installed as a show
// rule" — an author can never construct that value by hand (`@label` is
// markup-only syntax, not a callable `ref(...)` constructor), so the two
// shapes cannot collide. That also lets `hyperlink-target-minted:` double as
// the one knob for both an explicit `#hyperlink(...)` call and the `show ref:`
// rule, instead of a separate export per mode.
//
// References to anything else (an ordinary figure, a heading, ...) pass
// through untouched via the `else { it }` branch below — checking
// `e.kind == "rheo-idea-anchor"` on the RESOLVED element, not the label's
// text, is what makes this safe to install as a document-wide `show ref:`
// with no narrower selector: it already only touches rookery refs, whatever
// `prefix:` the document is using. A selector-level scope (`ref.where(...)`)
// can't do this instead — `.where()` matches a static field value (one exact
// label), not "resolves to a rookery anchor", which is only knowable by
// resolving the reference. Without the rule, `@idea:x` still compiles — it
// just shows a number; an explicit `#hyperlink("x")[text]` remains
// unaffected either way (a `show ref:` rule only ever touches `ref`
// elements, never the `link` a direct call like this one produces).
//
// CUSTOM TEXT: `@idea:x[custom text]` (or `#ref(<idea:x>, supplement: [...])`)
// sets `it.supplement`, which the ref-mode branch prefers over the note's
// own title whenever it is not `auto` — `auto` is what an unadorned
// `@idea:x` leaves it at, the signal to fall back to the title/raw-id
// default. An explicit call has no such fallback chain: its body is
// whatever the caller wrote, always.
#let hyperlink(..args) = {
  let pos = args.pos()
  let minted = args.named().at("hyperlink-target-minted", default: true)
  // An argument sink accepts every named argument silently, so a misspelled
  // one would link somewhere the caller did not ask for and report nothing.
  // The sink is what lets one function serve both call shapes (see above), so
  // the check a named parameter list would give for free is done by hand.
  let unknown = args.named().keys().filter(k => k != "hyperlink-target-minted")
  assert(
    unknown.len() == 0,
    message: "@rookery/core: #hyperlink's only named argument is "
      + "hyperlink-target-minted — got " + repr(unknown),
  )
  assert(
    type(minted) == bool,
    message: "@rookery/core: #hyperlink's hyperlink-target-minted must be a "
      + "boolean — `true` for the note's minted page, `false` for its "
      + "in-context anchor. Got " + repr(minted),
  )

  if pos.len() == 1 and type(pos.at(0)) == content and pos.at(0).func() == ref {
    // Installed as `show ref: hyperlink`, or with the flag `.with()`-bound:
    // Typst hands us the resolved `ref` element itself.
    let it = pos.at(0)
    context {
      let e = it.element
      if e != none and e.func() == figure and e.kind == "rheo-idea-anchor" {
        let id = str(it.target)
        let reg = _registry.final()
        // A NAME: a reference NAMES the note it points at, so `@idea:x` renders
        // the note's title, or its opening words when it has none, instead of
        // falling through to a bare id. `_rec-label` (pure.typ) is that name and
        // is the same one `ideas()` puts in a row, so a reference and a search
        // hit call one note by one name — including when the target's own title
        // references a third note, which its registration-time `label` cannot
        // resolve and this can. A STRING rather than the title's content: the
        // name goes inside a `link`, and content carrying a reference of its own
        // would nest one link inside another.
        let rec = reg.at(id, default: none)
        let named = if rec == none { none } else { _rec-label(rec, _ref-text(reg)) }
        let shown = if it.supplement != auto {
          it.supplement
        } else if named != none {
          named
        } else {
          raw(id)
        }
        let linked = link(_resolve-dest(id, minted), shown)
        // Wrapped so `@idea:other` is reachable from CSS and carries the
        // theme. A SPAN around Typst's own `link()`, not a hand-rolled
        // `<a>`: the label-fallback branch has no href to hand-roll WITH,
        // since only Typst can resolve a label to the `#loc-N` it ends up
        // at. And the wrapper has to carry the theme itself — a reference
        // sits in ordinary prose, with no `.idea-box`/`.idea-window`
        // ancestor to inherit from.
        if _target() == "html" or _target() == "epub" {
          html.elem("span", attrs: _themed((class: _c("ref"), data-rookery: "ref")), linked)
        } else {
          linked
        }
      } else {
        it
      }
    }
  } else {
    assert(
      pos.len() == 2,
      message: "@rookery/core: #hyperlink wants a name and a body — "
        + "#hyperlink(\"etal\")[text] — got " + str(pos.len()) + " argument(s).",
    )
    let (name, body) = (pos.at(0), pos.at(1))
    let n = _norm(name)
    // Announced up front, in an invisible `metadata` element, the same
    // reason `#window` does: this is a way of pointing at a note, so it has
    // to show up in the target's backlinks, and the `link()` below renders
    // inside a `context` block that is not a concrete element yet at
    // registration time / page-walk time (see `_outbound`/`_page-links`).
    metadata((rookery-link: n))
    context {
      let id = _pfx() + n
      if id not in _registry.final() {
        // EXCLUDED IS NOT MISSING — the same distinction `#window` and
        // `#idea-body` draw, through the same `_excluded-ids` state, for the
        // same reason: a build that drops a tag must not fail wherever a
        // surviving page links to a dropped note.
        //
        // THE BODY, UNLINKED, rather than nothing — and this is the one place
        // the degradation differs from `#window`'s. A hyperlink sits INLINE in a
        // sentence the author wrote, so deleting it would delete a word out of
        // their prose and leave the grammar broken. The text stays and only the
        // link goes.
        //
        // A TYPO STILL PANICS, message unchanged. See `#window`'s own banner for
        // why the `@idea:x` markup form cannot be rescued here at all.
        if id in _excluded-ids.final() { return body }
        panic("@rookery/core: #hyperlink unknown note '" + id + "'")
      }
      link(_resolve-dest(id, minted), body)
    }
  }
}

// Flatten a note's body ONCE, at registration, so `#window` is pure
// presentation (any number of windows cost nothing) and cycles are safe (a
// self-window, or A-windows-B/B-windows-A, collapses one level instead of
// re-expanding forever). Without this, a transcluded body re-emits its
// embedded machinery live: a self-window fails with "maximum show rule depth
// exceeded", and a nested `#idea` inside a transcluded body re-runs its
// registration and counter step, inflating later ids.
//
// REFUTED: a `state` depth counter around the expansion — a self-window
// still fails identically, because typst hits its nesting cap before the
// state timeline converges.
//
// The `show` rules below are LOCALLY SCOPED to the content this function
// returns — Typst content carries its own style/show-rule modifications
// wherever it is later inserted, so a nested IK/WK marker anywhere inside
// `body` gets reduced when this returned content is finally rendered, no
// matter how many `#window`s later re-embed it.
//
// GOTCHA: do NOT use `it.body.children.first()` to find the
// metadata child — the marker's body begins with a SPACE element whenever the
// markup block spans multiple lines, so `.first()` returns a `space` and
// fails with `space does not have field "value"`. Use
// `.children.find(c => c.func() == metadata)`.
