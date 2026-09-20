// Everything with no rookery dependency of its own: whether we are compiling
// under rheo and to what, plus a re-export of `pure.typ`. EVERY OTHER MODULE
// IMPORTS THIS ONE, and this imports only `pure.typ`, keeping the graph a
// DAG — a cycle would surface as an unresolvable name, not a warning.

// `std.target()` reports EPUB as "html", unlike rheo's own context. Used
// over a bare `target()` (rheo-injected, vertebra scope only); REQUIRES `--features html`.
#let _rheo-ctx() = sys.inputs.at("rheo-context", default: none)

#let _target() = {
  let c = _rheo-ctx()
  if c != none and "target" in c { c.target } else { std.target() }
}

// `pure.typ` holds the functions pure in their arguments, carrying none of
// this file's scope-capture ordering. The wildcard RE-EXPORTS to anything
// importing `lib.typ` in turn. RELATIVE import: unlike `.marrow.typ`,
// spliced into rheo's bundle root, this resolves against the package's own dir.
#import "pure.typ": *

// `.marrow.typ` imports THIRTY-THREE names from `"@rookery/core:0.1.0"`,
// thirty underscore-private and load-bearing — a broken marrow mints no
// pages but fails silently. RENAME OR RE-SIGN ONLY WITH `.marrow.typ`:
//   _registry            note store; marrow mints pages from it, inverts links
//   _note-page           slug + minted path + handle for one note
//   _pfx                 prefix stripped off a backlink id for `#window`
//   _head                per-page <head> contributions
//   _permalink           a note's `[idea:x]` permalink
//   _permalink-tab       the permalink tab reused on a note's minted page
//   _themed              document theme as inline custom props
//   _handle-title        human title of a vertebra's handle
//   _page-titles         spine title vs. the page's own path
//   _page-links          notes a given page links to
//   _page-href           depth-relative href between two pages
//   _body-at             a note's body at a nested-window budget
//   _footnoted           wraps a body with its own Footnotes block
//   _refs-block          References block for a set of citation keys
//   _own-cited-keys      keys a body cites, minus the windowed ones
//   _window-depth        nested-window budget state
//   _idea-page-template  the project's own minted-page template, if any
//   _visible-tags        tag names minus invisible ones, for index rows
//   window               public; backlinks render as folded windows
//
// Not gathered beside their definitions: moving them would break the closures.

// The human title of the vertebra a handle names, from `rheo-context`'s
// spine-wide `spine-flat` — needs no `ctx:`, no `query()`. `mode` is passed
// in, not read off `_page-titles`, since a state read here would tie the
// value to layout. `"path"` drops the content dir by MATCHING THE HANDLE's
// first segment: a landing page's handle is its own directory.
#let _handle-title(handle, mode: "title") = {
  let c = _rheo-ctx()
  if c == none { return handle }
  for v in c.at("spine-flat", default: ()) {
    if v.at("handle", default: none) == handle {
      let title = v.at("title", default: handle)
      if mode != "path" { return title }
      let path = v.at("path", default: none)
      if path == none { return title }
      let stem = if path.ends-with(".typ") { path.slice(0, -4) } else { path }
      let segs = stem.split("/")
      let from = segs.position(s => s == handle.split(":").first())
      return if from == none { stem } else { segs.slice(from).join("/") }
    }
  }
  handle
}

// `spine-flat` lists the vertebrae the author wrote, not the per-note pages
// `.marrow.typ` mints, else a minted page's links get harvested as backlinks.
#let _is-vertebra(handle) = {
  let c = _rheo-ctx()
  if c == none { return false }
  c.at("spine-flat", default: ()).any(v => v.at("handle", default: none) == handle)
}

// A note carrying an excluded tag is ABSENT, not hidden: `#idea` never
// builds its marker. Reads `sys.inputs` directly (no `#context`) because the
// gate sits ABOVE the `figure(kind: IK)` marker that several sites walk
// structurally before realization, where a `#context` node's children don't
// yet exist. Channels compose as `excluded = (declared UNION rookery-exclude)
// MINUS rookery-include`: the declared list is the CD baseline,
// `rookery-include` restores notes for a dev build, `rookery-exclude` carves
// a further subsection — both reach a plain `typst compile` only, since `rheo
// compile` forwards no `--input`.

// One `sys.inputs` key as an array of tag names, or `()` when absent. DEFINED
// AT THE BOTTOM: `_split-tag-list` reaches this file only via the import above.
#let _input-tags(key) = {
  let v = sys.inputs.at(key, default: none)
  if v == none { return () }
  assert(
    type(v) == str,
    message: "@rookery/core: `--input " + key + "` must be a string of comma- "
      + "or space-separated tag names — got " + repr(v),
  )
  _split-tag-list(v)
}

// The final excluded set, per the formula above; `declared` accepts the same forms `#idea`'s `tags:` does.
#let _resolve-excluded(declared) = {
  let d = _norm-tags(declared).keys()
  let add = _input-tags("rookery-exclude")
  let drop = _input-tags("rookery-include")
  (d + add).dedup().filter(t => t not in drop)
}
