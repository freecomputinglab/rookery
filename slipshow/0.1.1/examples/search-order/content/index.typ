// The boolean-query deck: `method&!draft` selects every note tagged `method`
// that is NOT also tagged `draft` — the calibration write-ups that have left
// draft status, whatever their `result`/`archive` tags besides. See
// `content/corpus.typ` for the tags each note carries.
//
// The grammar (`&`, `|`, `!`, `()`) lives entirely in `@rookery/search`;
// `@rookery/slipshow` depends on nothing but `@rookery/core` and knows only
// that `tags:` accepts a predicate over a tag dictionary. `t.keys()` is the
// one line of adaptation a caller supplies: `eval-tag-query` wants a flat
// array of (already-folded) tag names, and `#slipshow`'s `tags:` predicate
// hands the whole dictionary instead — that seam is why this example exists.
#import "lib.typ": template, slipshow, parse-tag-query, eval-tag-query
#show: template

= Composed by a boolean tag query

The query below, `method&!draft`, selects every note tagged `method` that is
not also tagged `draft` — whatever `result`/`archive` tags it carries besides.
The boolean grammar (`&`, `|`, `!`, `()`) belongs entirely to `@rookery/search`;
`@rookery/slipshow` depends on nothing but `@rookery/core` and only knows that
`tags:` accepts a predicate function over a note's tags — the predicate is the
seam that lets the two compose with no package-level edge between them.

#slipshow(tags: t => eval-tag-query(parse-tag-query("method&!draft").rpn, t.keys()))
