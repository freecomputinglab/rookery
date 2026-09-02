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
  (
    bib: bib,
    entry: entry,
    fields: key => fields-block(entry(key)),
    citation: (key, title: auto, tags: none, show-tags: true, ..args) => {
      let key = cite-key(key)
      (tagged-idea(tag))(
        key,
        title: if title == auto { bib-title(entry(key)) } else { title },
        tags: tags,
        show-tags: show-tags,
        ..args,
      )
    },
  )
}
