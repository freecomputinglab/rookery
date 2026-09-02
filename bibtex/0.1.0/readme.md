# @rookery/bibtex

A BibTeX reader and a `#citation` note constructor for
[`@rookery/core`](../../core/0.1.0) notes — parse a `.bib` file once, then mint
one note per reference, titled and keyed from the entry itself.

```typst
#import "@rookery/core:0.1.0": idea
#import "@rookery/bibtex:0.1.0": bibtex

#let refs = bibtex(read("refs.bib"))

#refs.citation("badiou2002")[
  #refs.fields("badiou2002")
]
```

`badiou2002` is the BibTeX key. `#refs.citation(..)` mints a note titled
`Badiou, *Ethics* (2002)` — derived from the entry, not typed by hand — tagged
`citation` by default; `#refs.fields(..)` renders every field the entry
carries as an HTML definition list, for a body that just wants the record
laid out.

## `bibtex(src, tagged-idea:, tag:)`

`src` is a `.bib` file's contents, or an array of them — several exports read
as one bibliography, joined with a newline between members so a file ending
mid-token cannot fuse into the next file's first token:

```typst
#let refs = bibtex((read("primary.bib"), read("secondary.bib")))
```

The return value is a dictionary of five functions, all closed over the
parsed bibliography:

| | |
| --- | --- |
| `bib` | the parsed dictionary itself, `key -> (field: value, ..)`, every value a plain string |
| `entry(key)` | that entry, asserting the key exists rather than handing back `none` |
| `fields(key)` | that entry's fields, as the `<dl class="citation-fields">` `fields-block` builds |
| `citation(key, title: auto, tags: none, show-tags: true, ..)` | a note titled from the entry (`title:` overrides it) and tagged `tag:` (`"citation"` by default) alongside whatever `tags:` you pass |
| `all()` | mints a note for every entry not already claimed by a hand-written `citation` call |

`citation`'s `key` accepts the form you actually write: `@badiou2002` (a
Typst `ref`, caught by Typst's own reference checking if the key is wrong), a
bare label, or a string computed at build time.

A dictionary field holding a function cannot be called with `#refs.citation(..)`
under Typst 0.15.1 — `cannot directly call dictionary keys as functions` — so
call through parenthesized field access instead: `#(refs.citation)(..)`,
`#(refs.all)()`.

## `all()` — minting the rest of the bibliography

A bibliography is a list of things worth a note. `citation(..)` mints one
where you've written it by hand; `all()` mints the REST — every key `bib`
carries that no `citation` call has claimed, in the bibliography's own
alphabetical key order:

```typst
#let refs = bibtex(read("refs.bib"))

#refs.citation(<etal2002>)[The one you want to say something about.]
#(refs.all)()
```

`etal2002` keeps its hand-written body; every other entry mints with an empty
body, titled from the entry the same way `citation` derives its own title.
**Call it once, from one vertebra** — a second call is a compile error
(`all() mints the whole bibliography and must be called once, from one
vertebra`), because it mints the whole bibliography and a second pass would
either double-register every key or silently do nothing, neither of which is
useful. A hand-written `citation` for a key always wins: `all()` never mints
over one, no matter where in the document the two calls sit relative to each
other.

`tagged-idea:` defaults to `@rookery/core`'s own, which is what you want on
plain rookery. **A project on `@rookery/timeline` or `@rookery/todos` should
pass THAT package's own `tagged-idea` instead** — the version decorated with
its date or todo arguments — because a citation minted through core's
undecorated one would not carry them:

```typst
#import "@rookery/timeline:0.1.0": tagged-idea
#let refs = bibtex(read("refs.bib"), tagged-idea: tagged-idea)
```

`parse-bib`, `bib-title`, `cite-key` and `fields-block` are re-exported from
the entrypoint too, for a consumer that wants the parts directly rather than
only through the factory.

## What the parser does not handle

A hand-rolled scanner over `@type{key, field = {..} | "..." | bare}`, with
nested braces and `{{Protected Words}}` unwrapped to the words themselves —
BibTeX uses an interior brace to protect capitalization from a citation
style, not to say anything about the text. It does not:

- expand `@string` macros;
- resolve `#` string concatenation;
- translate LaTeX escapes (`\&`, `{\'e}`, …) — they come through as literal
  text.

Export from your reference manager with macros expanded and Unicode rather
than LaTeX escapes (Zotero and most others do this by default) and the parser
sees exactly what you'd expect.

## Requirements

No build step and no JavaScript: `typst.toml`'s `entrypoint` points straight
at `src/`, so an edit takes effect immediately. `citation(..)` calls into
`@rookery/core` 0.1.0 for `tagged-idea`; nothing else here imports it.

## Development

```sh
cd bibtex/0.1.0
just test
```
