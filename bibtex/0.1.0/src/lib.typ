// @rookery/bibtex — a BibTeX reader and a `#citation` note constructor for
// @rookery/core notes.
//
// `bibtex(src, tagged-idea:, tag:)` parses one or more `.bib` sources once and
// closes over the result, returning:
//
//   bib:      the parsed dictionary, `key -> (field: value, ..)`
//   entry:    key -> that entry, asserting the key exists
//   fields:   key -> its fields, as the HTML `<dl>` `fields-block` builds
//   citation: (key, title: auto, tags: none, show-tags: true, ..) -> a note,
//             titled from the entry unless `title:` overrides it
//   all:      () -> mints every entry NOT already claimed by a hand-written
//             `citation` call, once per document (see `claim.typ`)
//
// `src` may be a single string or an array of strings — several `.bib` exports
// read as one bibliography, joined with a newline between members so a file
// ending mid-token cannot fuse into the next file's first token.
//
// `parse-bib`, `bib-title`, `cite-key` and `fields-block` are re-exported so a
// consumer can reach the parts directly rather than only through the factory.

#import "@rookery/core:0.1.0": tagged-idea as _core-tagged-idea
#import "parse.typ": *
#import "format.typ": *
#import "view.typ": *
#import "claim.typ": *

// `tagged-idea:` defaults to core's own, which covers a project on plain
// rookery. IT STAYS A PARAMETER because a project on `@rookery/timeline` or
// `@rookery/todos` mints its notes through THAT package's own `tagged-idea` —
// the one decorated with its date or todo arguments — and a citation minted
// through core's undecorated version would not take them.
#let bibtex(src, tagged-idea: _core-tagged-idea, tag: "citation") = {
  let src = if type(src) == array { src.join("\n") } else { src }
  let bib = parse-bib(src)
  let entry = key => {
    let e = bib.at(key, default: none)
    assert(e != none, message: "no `" + key + "` in the bibliography")
    e
  }
  // The mint, with no claim. `all()` below calls this directly, for every key
  // the sweep reaches — `citation`'s claim would make the sweep both write and
  // read `_claimed` in the same pass, and Typst's state resolution does not
  // converge on that (see `claim.typ`).
  let note = (key, title: auto, tags: none, show-tags: true, ..args) => (tagged-idea(tag))(
    key,
    title: if title == auto { bib-title(entry(key)) } else { title },
    tags: tags,
    show-tags: show-tags,
    ..args,
  )
  (
    bib: bib,
    entry: entry,
    fields: key => fields-block(entry(key)),
    // The authoring form: claims its key — so `all()` skips it — then mints.
    // The claim is idempotent, so writing `citation` for one key twice still
    // reads as one claimed key, not a collision.
    citation: (key, title: auto, tags: none, show-tags: true, ..args) => {
      let key = cite-key(key)
      _claimed.update(c => if key in c { c } else { c + (key,) })
      note(key, title: title, tags: tags, show-tags: show-tags, ..args)
    },
    // Mints a note for every bibliography key not already claimed by a
    // hand-written `citation`, in the bibliography's own alphabetical key
    // order. Must be called ONCE, from one vertebra, inside a `#show: rookery`
    // document — a second call panics rather than re-minting.
    //
    // `.get()` on `_swept`, NOT `.final()`: `.final()` would see the increment
    // this very call makes and panic on the FIRST call too. `.get()` sees only
    // what ran before this point, so the guard fires on a genuine second call
    // and nothing else.
    all: () => context {
      if _swept.get() > 0 {
        panic(
          "@rookery/bibtex: all() mints the whole bibliography and must be "
            + "called once, from one vertebra",
        )
      }
      _swept.update(n => n + 1)
      for key in bib.keys().sorted() {
        if key not in _claimed.final() {
          // `[]`, an empty body, NOT omitted: core's `#idea` reads a single
          // positional argument as the note's BODY (idea.typ, the
          // `pos.len() == 1` branch), so `note(key)` alone would make the key
          // itself the body — unnamed, landing on the sequence counter as
          // `ideas/1.html` rather than under its own key. The empty body
          // keeps `key` in the name slot.
          note(key, [])
        }
      }
    },
  )
}
