// The fourth order form, and the page this example exists for: a KEY
// FUNCTION, called once per row over the whole registry row `content/
// corpus.typ` describes (`id`, `name`, `title`, `text`, `label`, `tags`,
// `tags-dict`, `body`, `href`, `page`, `created` — `@rookery/core`'s
// `data.typ`). See `content/index.typ` for the three forms that need no
// function at all.
#import "lib.typ": template
#import "@rookery/slipshow:0.1.0": slipshow
#show: template

= Ordering by a key function

== Alphabetical by `label`

`label` and not `title`: `label` is a `str`, always — the authored title
flattened to plain text, or the note's own name when there is no title — and
a key function must return a comparable value. `title` is CONTENT, and
`array.sorted` panics on it; that panic is `_sort-rows`'s own message
(`src/select.typ`), not a generic Typst error, precisely because using
`title` here is the mistake a reader will make.

`kilo`'s title starts with a numeral and `lima`'s starts with a lower-case
letter, so the sequence below is a plain string sort — digit, then every
upper-case initial, then lower-case — and visibly not an order any reader
chose by hand. Compare it to the corpus's id order (`content/corpus.typ`) to
see that the key function actually ran rather than being silently ignored.

#slipshow(tags: "slip", order: r => r.label)

== Shortest note first

A key computed from the note rather than read off it: `r.body` is the note's
body flattened to plain text (`@rookery/core`'s `_body-plain`), so `.len()`
is its character count.

#slipshow(tags: "slip", order: r => r.body.len())

== Grouped by minted page

`r.page` is where THIS note's own minted page lives (`ideas/<name>.html`),
metadata no other field on the row carries. Every note in this corpus is
authored in `content/corpus.typ` and mints into the same `ideas/` directory,
so grouping by `r.page` here reproduces id order — the interesting case is a
project whose notes are pinned across several `note-dir:` sections, where
this groups them by section instead.

#slipshow(tags: "slip", order: r => r.page)
