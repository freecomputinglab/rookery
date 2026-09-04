// @rookery/bibtex — a BibTeX reader and a `#citation` note constructor for
// @rookery/core notes.
//
// `bibtex(src, tagged-idea:, tag:, keywords:, show-fields:)` parses one or more `.bib`
// sources once and closes over the result, returning:
//
//   bib:      the parsed dictionary, `key -> (field: value, ..)`
//   entry:    key -> that entry, asserting the key exists
//   fields:   (key, show-fields: auto) -> its fields, as the HTML `<dl>`
//             `fields-block` builds; `show-fields` falls back to the
//             factory's own when omitted
//   citation: (key, title: auto, tags: none, show-tags: true, ..) -> a note,
//             titled from the entry unless `title:` overrides it
//   all:      () -> mints every entry NOT already claimed by a hand-written
//             `citation` call, once per document (see `claim.typ`)
//
// `src` may be a single string or an array of strings — several `.bib` exports
// read as one bibliography, joined with a newline between members so a file
// ending mid-token cannot fuse into the next file's first token.
//
// `parse-bib`, `bib-title`, `cite-key`, `fields-block` and `keyword-tags` are
// re-exported so a consumer can reach the parts directly rather than only
// through the factory.

// `_norm-tags` IS ONE OF CORE'S PRIVATE NAMES, imported deliberately: merging keyword
// tags into the caller's own needs both sides to be dictionaries, and `tags:` accepts a
// string, an array or a dictionary. Core has no public equivalent, and a local copy of
// its normalisation would drift silently the day core accepts a fifth shape — where
// this import breaks loudly, at compile time, if the name ever moves.
#import "@rookery/core:0.1.0": tagged-idea as _core-tagged-idea, tag-data, _norm-tags
#import "parse.typ": *
#import "format.typ": *
#import "view.typ": *
#import "claim.typ": *
#import "keywords.typ": *

#let _KEYWORDS-MODES = (none, "all", "existing")

// `tagged-idea:` defaults to core's own, which covers a project on plain
// rookery. IT STAYS A PARAMETER because a project on `@rookery/timeline` or
// `@rookery/todos` mints its notes through THAT package's own `tagged-idea` —
// the one decorated with its date or todo arguments — and a citation minted
// through core's undecorated version would not take them.
//
// `keywords:` turns an entry's `keywords` field into rookery tags, on top of
// whatever `tags:` a `citation`/`all()` call already carries:
//
//   none        (default) no tags from keywords — unchanged behaviour
//   "all"       every keyword becomes a tag, whatever the rookery already has
//   "existing"  only a keyword that already matches a tag somewhere in the
//               rookery becomes one; the rest are ignored
//
// `"existing"` reads `tag-data()` to learn what tags exist, which needs
// `#context`. That is safe here specifically because the sweep only ever adds
// tags that ALREADY exist — the known-tag set is a fixed point under its own
// writes — so reading it mid-sweep still converges. See `note` below for how
// that read reaches both minting paths.
#let bibtex(
  src,
  tagged-idea: _core-tagged-idea,
  tag: "citation",
  keywords: none,
  show-fields: (:),
) = {
  assert(
    keywords in _KEYWORDS-MODES,
    message: "@rookery/bibtex: `keywords` must be none, \"all\" or \"existing\" — got "
      + repr(keywords),
  )
  // Captured under its own name because `fields:` below takes a per-call
  // parameter of the same name — inside that closure, `show-fields` is the
  // per-call one, and this is the only way back to the factory's.
  let _show-fields = show-fields
  let src = if type(src) == array { src.join("\n") } else { src }
  let bib = parse-bib(src)
  let entry = key => {
    let e = bib.at(key, default: none)
    assert(e != none, message: "no `" + key + "` in the bibliography")
    e
  }
  // One entry's keyword slugs, filtered against the rookery's known tags in
  // "existing" mode. Needs `#context` only for that mode — `all()` already
  // calls `note` from inside one; `citation` wraps its own call below, only
  // when `keywords` is "existing", rather than becoming a context function
  // for every mode.
  let kw-tags-for(key) = {
    if keywords == none { return (:) }
    let slugs = keyword-tags(entry(key).at("keywords", default: none))
    let kept = if keywords == "existing" {
      let known = tag-data().values().map(t => t.keys()).flatten().dedup()
      slugs.filter(s => s in known)
    } else {
      slugs
    }
    kept.fold((:), (d, t) => { d.insert(t, none); d })
  }
  // The mint, with no claim. `all()` below calls this directly, for every key
  // the sweep reaches — `citation`'s claim would make the sweep both write and
  // read `_claimed` in the same pass, and Typst's state resolution does not
  // converge on that (see `claim.typ`).
  //
  // Keyword tags merge UNDER the caller's own `tags:` — dictionary `+` lets
  // the right side win a key collision, so an explicit tag always wins over
  // one derived from `keywords`. The package's own `tag` is then dedup'd on
  // top by `tagged-idea` exactly as it was before this merge existed.
  let note = (key, title: auto, tags: none, show-tags: true, ..args) => (tagged-idea(tag))(
    key,
    title: if title == auto { bib-title(entry(key)) } else { title },
    tags: kw-tags-for(key) + _norm-tags(tags),
    show-tags: show-tags,
    ..args,
  )
  (
    bib: bib,
    entry: entry,
    fields: (key, show-fields: auto) => fields-block(
      entry(key),
      show-fields: if show-fields == auto { _show-fields } else { show-fields },
    ),
    // The authoring form: claims its key — so `all()` skips it — then mints.
    // The claim is idempotent, so writing `citation` for one key twice still
    // reads as one claimed key, not a collision.
    citation: (key, title: auto, tags: none, show-tags: true, ..args) => {
      let key = cite-key(key)
      _claimed.update(c => if key in c { c } else { c + (key,) })
      if keywords == "existing" {
        context note(key, title: title, tags: tags, show-tags: show-tags, ..args)
      } else {
        note(key, title: title, tags: tags, show-tags: show-tags, ..args)
      }
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
