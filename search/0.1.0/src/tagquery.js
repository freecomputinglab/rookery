// The `tags:` query language, ported from `src/tagquery.typ`: the prefix that
// opens an expression, shunting-yard to RPN, an evaluator, and the atom extractor
// the UI marks pills with.
//
// THE WHOLE LANGUAGE AND NOTHING ELSE: `splitQuery` is the entry point and the only
// place the `tags:` prefix is recognised. Each language has one module for the
// language and one for the scorer, so refining the syntax means editing this file
// and `src/tagquery.typ`.
//
// Every rule here has a Typst twin and `test/parity.mjs` pins the two together
// case for case.

import { clusters, fold } from "./text.js";

// `_prec`'s twin, plus the associativity table it does not need: Typst spells
// `!`'s right-associativity as a literal `c != "!"` in the pop test, which
// reads as an accident rather than a rule, so it is named here.
export const OPS = { "!": 3, "&": 2, "|": 1 };
export const RIGHT = { "!": true };
// THE ONE PREFIX THAT OPENS A TAG EXPRESSION, named rather than spelled inline so
// that the test for it and the slice past it cannot disagree by a character.
export const TAG_PREFIX = "tags:";
// Port of `parse-tag-query` in src/tagquery.typ. Shunting-yard to RPN,
// iterative (no recursion), tokens as small objects: an atom carries `f`
// (field, `""` for a bare word) and `v` (value); an op carries only `v`.
// NEVER throws: every malformed form repairs, because a live search box
// types every prefix of a valid query on the way to it.
//
// `clusters(src)`, matching Typst's `.clusters()` — never index the string, and
// never spread it either: a spread is code points, which is a different count and
// was the drift `clusters` above exists to end. `c.trim() === ""` mirrors Typst's
// `c.trim() == ""` rather than a `/\s/` test, so each side's whitespace
// definition stays tied to its own runtime's trim instead of to a regex
// dialect. Typst guards the residual slice because `array.join()` on an EMPTY
// array is `none` there; `[].join("")` is `""` here, so the guard is
// unnecessary and the two still agree on a query ending in a bare space.
//
// The `i++` in the escape branch consumes the escaped cluster, which is why
// this stays a `for` and not a `for...of`.
export const parseTagQuery = (src) => {
  const cs = clusters(src);
  const out = [];
  const stack = [];
  const repaired = [];
  // `field`/`value` split one atom's text either side of its first unescaped
  // `:` — `split` tracks whether that colon has been seen yet, so an escaped
  // or a second `:` lands in `value` rather than triggering a second split
  // (`a:b:c` is field `a`, value `b:c`). An atom with no colon at all lands
  // entirely in `field`, flushed as a field-less atom whose value is `field`.
  let field = "";
  let value = "";
  let split = false;
  let residual = "";
  const flushAtom = () => {
    if (split) {
      out.push({ t: "atom", f: fold(field), v: fold(value) });
    } else if (field !== "") {
      out.push({ t: "atom", f: "", v: fold(field) });
    }
    field = "";
    value = "";
    split = false;
  };
  const pushOp = (op) => {
    while (stack.length) {
      const top = stack[stack.length - 1];
      if (top === "(") break;
      const higher = OPS[top] > OPS[op] || (OPS[top] === OPS[op] && !RIGHT[op]);
      if (!higher) break;
      out.push({ t: "op", v: stack.pop() });
    }
    stack.push(op);
  };
  for (let i = 0; i < cs.length; i++) {
    const c = cs[i];
    if (c === "\\") {
      if (i + 1 < cs.length) {
        if (split) value += cs[i + 1]; else field += cs[i + 1];
        i++;
      } else repaired.push("trailing-backslash");
      continue;
    }
    // The FIRST unescaped `:`, decided as the text accumulates rather than by
    // re-scanning a finished atom, which cannot tell an escaped `:` from a
    // real one. Only splits when a field name already sits in `field` — a
    // leading `:` (`:draft`) has nothing before it, so it stays a literal
    // character of a bare text atom instead of becoming a field clause with
    // an empty name.
    if (c === ":" && !split && field !== "") { split = true; continue; }
    if (c.trim() === "") { residual = cs.slice(i + 1).join(""); break; }
    if (c === "(") { flushAtom(); stack.push("("); continue; }
    if (c === ")") {
      flushAtom();
      let found = false;
      while (stack.length) {
        const top = stack.pop();
        if (top === "(") { found = true; break; }
        out.push({ t: "op", v: top });
      }
      if (!found) repaired.push("unmatched-close");
      continue;
    }
    if (c in OPS) { flushAtom(); pushOp(c); continue; }
    if (split) value += c; else field += c;
  }
  flushAtom();
  while (stack.length) {
    const top = stack.pop();
    if (top === "(") repaired.push("unclosed-open");
    else out.push({ t: "op", v: top });
  }
  return { rpn: out, residual: residual.trim(), repaired };
};
// Port of `split-query`. THE ENTRY POINT: only a LEADING `tags:` is recognised, so
// a note body containing "tags:" can never be mistaken for a filter, and the
// non-tags branch returns `q` UNTOUCHED rather than trimmed — the scorers fold and
// split their own query, so trimming here would only be a second place for the two
// languages to disagree about whitespace.
//
// `TAG_PREFIX.length` rather than a literal `5`, so the prefix and the slice cannot
// drift apart.
export const splitQuery = (q) => {
  const s = q.replace(/^\s+/, "");
  if (!s.toLowerCase().startsWith(TAG_PREFIX)) return { rpn: [], text: q, repaired: [] };
  const { rpn, residual, repaired } = parseTagQuery(s.slice(TAG_PREFIX.length));
  return { rpn, text: residual, repaired };
};
// Port of `eval-clauses`. Walks the RPN over clauses rather than a bare
// boolean: each atom's verdict comes from `resolve(field, value)`, returning
// `{matched, score}`, and the walk composes those pairs under the max-plus
// (arctic) semiring every production search engine uses — `a & b` matches on
// both and scores their sum, `a | b` matches on either and scores the MAX
// over the MATCHED sides only (an unmatched branch costs nothing), and `!a`
// matches on the negation and always scores `0` (a negated clause gates but
// never contributes a score). `resolve` keeps this function free of any
// knowledge of tags, text or rows; `evalTagQuery` below supplies a
// tag-prefix resolver scoring `0` throughout.
//
// An empty RPN is NO FILTER (`{matched: true, score: 0}`), and a binary op
// with too few operands is skipped — that is what makes a half-typed
// `tags:a&` behave as `tags:a`. INTEGER ARITHMETIC ONLY, matching
// `eval-clauses` in `tagquery.typ`, which is what lets `just parity` diff the
// two number for number.
export const evalClauses = (rpn, resolve) => {
  if (rpn.length === 0) return { matched: true, score: 0 };
  const st = [];
  for (const tok of rpn) {
    if (tok.t === "atom") {
      st.push(resolve(tok.f, tok.v));
      continue;
    }
    if (tok.v === "!") {
      if (st.length === 0) continue;
      const a = st.pop();
      st.push({ matched: !a.matched, score: 0 });
      continue;
    }
    if (st.length < 2) continue;
    const b = st.pop();
    const a = st.pop();
    if (tok.v === "&") {
      st.push({ matched: a.matched && b.matched, score: a.score + b.score });
      continue;
    }
    const matched = a.matched || b.matched;
    const score = a.matched && b.matched
      ? Math.max(a.score, b.score)
      : a.matched ? a.score : b.matched ? b.score : 0;
    st.push({ matched, score });
  }
  return st.length === 0 ? { matched: true, score: 0 } : st[st.length - 1];
};
// Port of `eval-tag-query`. `tags` must already be folded. A thin call to
// `evalClauses` above: tags gate and never score, so `resolve` always
// returns `score: 0` and only `matched` is read.
export const evalTagQuery = (rpn, tags) =>
  evalClauses(rpn, (field, value) => ({
    matched: tags.some((tg) => tg === value || tg.startsWith(value)),
    score: 0,
  })).matched;
// The atoms whose PRESENCE on a note is evidence for the query — i.e. every
// atom not negated. Walked over the RPN with the same small stack
// `evalTagQuery` uses, so a `!` consumes the atom below it. Nothing here
// reproduces the boolean result; a chip is marked when it is evidence, not
// when it is decisive.
//
// Per stack slot the SET of atoms that produced it: `!` replaces that set with
// the empty set (nothing on the row is evidence for an absence — there is no
// element to mark), `&`/`|` union the two below, and the surviving
// top-of-stack set is the answer. So `!draft` yields nothing, `a|b` yields
// both (a note carrying both is satisfied twice and both chips are evidence),
// and `!(draft|todo)&note` yields only `note`.
//
// Lenient exactly as `evalTagQuery` is — a missing operand is skipped, never
// thrown on, because a live search box types every prefix of a valid query on
// the way to it.
//
// NO PARITY REQUIREMENT: there is no Typst counterpart, and none is wanted.
// `#search-ideas` returns data; which chip to highlight is presentation, and
// the Typst side renders no chips.
//
// PRESENTATION ONLY, and subordinate: if this and `evalTagQuery` ever disagree
// about a note, `evalTagQuery` is right by definition — it decides which rows
// exist, this only decides what is marked on one.
export const positiveAtoms = (rpn) => {
  const st = [];
  for (const tok of rpn) {
    if (tok.t === "atom") {
      st.push(new Set([tok.v]));
      continue;
    }
    if (tok.v === "!") {
      if (st.length === 0) continue;
      st.pop();
      st.push(new Set());
      continue;
    }
    if (st.length < 2) continue;
    const b = st.pop();
    const a = st.pop();
    st.push(new Set([...a, ...b]));
  }
  return st.length === 0 ? [] : [...st[st.length - 1]];
};
