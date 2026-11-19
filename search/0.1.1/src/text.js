// Text normalisation shared by every matcher: case and punctuation folding,
// grapheme clustering, and the cache in front of it.

export const fold = (s) => s.toLowerCase().replaceAll("-", " ").replaceAll("_", " ");
// EXTENDED GRAPHEME CLUSTERS, because that is what Typst counts. `str.clusters()`
// there is UAX #29; a spread (`[...s]`) here is UTF-16 CODE POINTS, and the two
// part company on every cluster wider than one code point:
//
//     "e" + "́"        1 cluster   vs 2 code points
//     "❤️"                  1 cluster   vs 2 code points
//     the family ZWJ emoji  1 cluster   vs 7 code points
//
// The difference reaches the score globally rather than locally: `hc.length` feeds
// the length-difference bonus and `first` the near-start bonus, so one such
// sequence anywhere in a hay moves every query against it. Typst is the reference
// — a reader perceives `é` as one character, and the bonuses are about how much of
// a perceived string a query covered — and the generated parity suite disagrees on
// 73 of 250 cases when this is a spread.
//
// A FIXED LOCALE, not `undefined`. Grapheme segmentation is script-driven rather
// than locale-tailored, so `"en"` does not change the answer for any script, and
// pinning it keeps the fixture under node's locale and a reader's browser under
// any other from coming out differently.
//
// SEGMENTING COSTS ABOUT 14x A SPREAD, so the hay is memoised and the query is
// not: one keystroke over 400 rows and three scored fields is 4.35ms segmented
// against 0.30ms memoised — inside a frame here, outside one on a slower machine
// or a larger rookery.
//
// THE HAY IS THE RIGHT KEY AND THE QUERY IS NOT. A hay is one of a bounded set —
// the island's rows, folded — so the cache tops out at rows x fields and every
// keystroke after the first is a hit. A query is new text on every keystroke, so
// caching it would grow without bound for no hit at all: `clustersCached` is for
// the hay only, and `clusters` serves everything else.
const SEGMENTER = new Intl.Segmenter("en", { granularity: "grapheme" });
export const clusters = (s) => [...SEGMENTER.segment(s)].map((g) => g.segment);
// THE HIGHLIGHT-TERM RULE, shared by the result row's title and id, the keyword
// chips and the fetched preview: a query folded, split on spaces, empties
// dropped. Callers pass the RESIDUAL text of a query rather than the raw input,
// so a `tags:` expression is never marked as though a note contained it.
export const queryTerms = (s) => fold(s).split(" ").filter((t) => t !== "");

const CLUSTER_CACHE = new Map();
export const clustersCached = (s) => {
  let v = CLUSTER_CACHE.get(s);
  if (v === undefined) {
    v = clusters(s);
    CLUSTER_CACHE.set(s, v);
  }
  return v;
};
