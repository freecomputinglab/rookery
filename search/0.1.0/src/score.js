// Scoring and ordering: the fuzzy matcher, the body matcher, the date tie-break
// and the two-tier `search`.
//
// The other half of the parity contract with the Typst side.

import { clusters, clustersCached, fold } from "./text.js";
// The query language belongs to `tagquery.js`; this file only uses it.
import { evalClauses, splitQuery } from "./tagquery.js";
// Port of `fuzzy-score`. `null` (Typst `none`) when the query's characters do
// not all appear in `hay` in order; otherwise an integer, higher better.
export const score = (hay, query) => {
  const h = fold(hay);
  const q = fold(query);
  if (q === "") return 0;
  // Cached on the folded HAY, fresh on the query — see `clustersCached`.
  const hc = clustersCached(h);
  const qc = clusters(q);
  let i = 0;
  let first = null;
  let prev = null;
  let points = 0;
  for (const ch of qc) {
    let found = null;
    for (let j = i; j < hc.length; j++) {
      if (hc[j] === ch) {
        found = j;
        break;
      }
    }
    if (found === null) return null;
    if (first === null) first = found;
    points += prev !== null && found === prev + 1 ? 3 : 1;
    prev = found;
    i = found + 1;
  }
  if (h.startsWith(q)) points += 10;
  else if (h.includes(q)) points += 5;
  points += Math.max(0, 5 - first);
  points += Math.max(0, 10 - (hc.length - qc.length));
  return points;
};
// Port of `body-score`: an AND match over a note's body, which here is always
// the COMPRESSED TERM STRING `#search-index` ships — that note's most
// distinctive terms, space-joined in weight order. `null` unless every
// whitespace-split query term is a substring of some term in that list, so a
// prefix query still lands (`justif` finds `justification`).
//
// The score is RANK, since position is the weight: per query term,
// `max(1, 10 - floor(rank / 4))` for the first term containing it, plus 3 when
// the query term IS one of the terms exactly. See `body-score` in `src/lib.typ`
// for the measurements and for every choice below; this is the port, not the
// record.
//
// NO PHRASE BONUS and no cluster counting: no phrase survives compression, and a
// rank is a term INDEX, which both languages count identically for free.
//
// `toLowerCase()`, NOT `fold()`: folding turns `-`/`_` into spaces, which would
// split `rheo-context` into two query terms and lose the exact-match bonus.
// Deliberate, and mirrored in `body-score` — the compression preserves `.` and
// `-` inside a term precisely so a reader can type them.
export const bodyScore = (body, query) => {
  const h = body.toLowerCase();
  const q = query.toLowerCase();
  if (q.trim() === "") return null;
  const terms = q.split(" ").filter((t) => t !== "");
  if (terms.length === 0) return null;
  const kept = h.split(" ").filter((t) => t !== "");
  let points = 0;
  for (const term of terms) {
    let rank = null;
    for (let i = 0; i < kept.length; i++) {
      if (kept[i].includes(term)) {
        rank = i;
        break;
      }
    }
    if (rank === null) return null;
    points += Math.max(1, 10 - Math.floor(rank / 4));
    if (kept.includes(term)) points += 3;
  }
  return points;
};
// Same rule as `search-ideas`: match on the id AND the title first (tier 0),
// take the better of the two; failing that, match on the body (tier 1) via
// `bodyScore`. Every tier-0 row ranks above every tier-1 row; within a tier,
// best score first, ties broken by id so the order is stable.
//
// `row.body` MISSING IS THE WHOLE IMPLEMENTATION OF `body-search: false`:
// `#search-index(body-search: false)` omits the field, this reads it as `""`, and
// `bodyScore("", q)` is `null` for every non-empty query, so no row can reach tier
// 1 and the browser searches ids and titles only. Keep the `?? ""` and keep
// `bodyScore` returning `null` for an absent term — between them the switch needs
// no JavaScript counterpart.
// THE QUERY IS PARSED ONCE INTO A CLAUSE TREE, before the loop, and every row
// is scored against that SAME tree via `evalClauses`/`_resolve` below — a
// `tags:` clause gates and never scores, a text clause scores and gates on
// whether it matched at all. `_rank`'s Typst twin does exactly this, in the
// same place and the same order, which is what `tier parity` pins.
//
// A `tags:` CLAUSE ADDS NO THIRD TIER AND NO SCORE BONUS: it always resolves
// to `score: 0`, so `tags:draft` alone never perturbs which of the two tiers
// a row lands in or where it sorts within one. A tag says WHICH notes are
// candidates; a text clause says how they rank.
//
// `row.tags ?? []` for the same reason `row.body ?? ""` is there: an older
// island, or a row for a note with no tags, simply has no key — `#search-index`
// omits it rather than shipping `[]` per row.
//
// A TREE WITH NO TEXT CLAUSE IS THE BROWSE LISTING. With `tags:draft` alone
// every atom's field is `tags`, so every clause scores `0` and every survivor
// ties in the name tier. `hasText` below is what tells `dateCmp` to break that
// tie by `row.created` instead: newest first, undated last, the twin of
// `_rank`'s date branch in `src/rank.typ`. A tree with a text clause breaks
// ties by id alone.
//
// `row.created` is ALREADY the zero-padded `"[year][month][day]"` stamp
// `#search-index` ships, never a raw date, so a lexicographic string comparison is
// a numeric-order comparison and nothing here parses anything.
const dateCmp = (a, b) => {
  if (a.created == null && b.created == null) return 0;
  if (a.created == null) return 1;
  if (b.created == null) return -1;
  return a.created < b.created ? 1 : a.created > b.created ? -1 : 0;
};
// Resolves one clause against one row, for `evalClauses` — `_resolve`'s twin
// in `src/rank.typ`, whose own comment has the fuller account. A `tags:`
// field is the folded-prefix gate; every other field, and a bare word (the
// same fallback with an empty prefix), is a TEXT clause scored by
// `textScore(field + ":" + value)` — the rule that keeps a note id like
// `idea:flat-ids` findable as `idea:flat` even though `idea` names no field
// this module knows, rather than silently matching everything.
// The best of several `score`/`bodyScore` answers, `null` unless at least
// one of them is — `_resolve`'s twin in `src/rank.typ` has the fuller
// account of why `row.id` joins `row.name`/`row.text` here.
const _best = (scores) => scores.reduce((best, s) => (s == null ? best : best == null ? s : Math.max(best, s)), null);
const _resolve = (textScore, tags) => (field, value) => {
  if (field === "tags") {
    // AN EMPTY VALUE IS NO CONSTRAINT: see `evalTagQuery`'s own comment for
    // why a bare `tags:` must not read as "tagged with the empty string".
    return {
      matched: value === "" || tags.some((tg) => tg === value || tg.startsWith(value)),
      score: 0,
    };
  }
  const s = textScore(field === "" ? value : `${field}:${value}`);
  return s == null ? { matched: false, score: 0 } : { matched: true, score: s };
};
// `search` SPLITS THE QUERY; `searchSplit` takes one already split, for a caller
// that needs the same `{ rpn }` to mark its rows with. Splitting twice per
// keystroke is the alternative, and it puts the entry point to the language in two
// layers of one render.
//
// INTERNAL: `src/search.js` exports `search` and not this, the package's public
// JavaScript surface being what that entrypoint exports.
export const searchSplit = (rows, split, limit) => {
  const { rpn } = split;
  // WHETHER THE TREE CARRIES A TEXT CLAUSE — the browse-listing question a
  // bare `q === ""` used to answer, generalised to a tree where a
  // `tags:`-only query (every atom's field is `tags`) is exactly as
  // score-free as an empty one.
  const hasText = rpn.some((tok) => tok.t === "atom" && tok.f !== "tags");
  const out = [];
  for (const row of rows) {
    const tags = (row.tags ?? []).map(fold);
    // ONE `evalClauses` CALL PER TIER, not a predicate-then-score sequence: a
    // gating clause (`tags:`) and a scoring clause are resolved by the SAME
    // walk, so `tags:draft window` gates on `draft` and scores `window` in
    // one pass.
    // `row.id` JOINS `row.name`/`row.text` here — always `"idea:" + row.name`,
    // so a reader typing that literal colon (`idea:flat` for `idea:flat-ids`)
    // still subsequence-matches it. See `_resolve`'s own comment in
    // `src/rank.typ` for why it rarely wins the max on its own.
    const nameEval = evalClauses(rpn, _resolve((v) => {
      const sText = row.text === "" ? null : score(row.text, v);
      return _best([score(row.name, v), sText, score(row.id ?? "", v)]);
    }, tags));
    if (nameEval.matched) {
      out.push({ ...row, score: nameEval.score, kind: "name" });
      continue;
    }
    const bodyEval = evalClauses(rpn, _resolve((v) => bodyScore(row.body ?? "", v), tags));
    if (bodyEval.matched) out.push({ ...row, score: bodyEval.score, kind: "body" });
  }
  const tier = (hit) => (hit.kind === "name" ? 0 : 1);
  out.sort(
    (a, b) =>
      tier(a) - tier(b) ||
      b.score - a.score ||
      (hasText ? 0 : dateCmp(a, b)) ||
      (a.id < b.id ? -1 : a.id > b.id ? 1 : 0),
  );
  return limit == null ? out : out.slice(0, limit);
};

export const search = (rows, query, limit) => searchSplit(rows, splitQuery(query), limit);
