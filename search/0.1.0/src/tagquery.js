// The query language, ported from `src/tagquery.typ`: one boolean clause tree
// over a note's fields and its text, shunting-yard to RPN, an evaluator, and
// the atom extractor the UI marks pills with.
//
// THE WHOLE LANGUAGE AND NOTHING ELSE: `splitQuery` is the entry point.
// `field` names a GATING clause (`tags:draft`); a bare word (empty field) is
// a SCORING clause over a row's text — `eval-clauses` in `score.js` is what
// resolves either kind, this module only parses and walks the tree. Each
// language has one module for the language and one for the scorer, so
// refining the syntax means editing this file and `src/tagquery.typ`.
//
// Every rule here has a Typst twin and `test/parity.mjs` pins the two together
// case for case.

import { clusters, fold } from "./text.js";

// `_prec`'s twin, plus the associativity table it does not need: Typst spells
// `!`'s right-associativity as a literal `c != "!"` in the pop test, which
// reads as an accident rather than a rule, so it is named here.
export const OPS = { "!": 3, "&": 2, "|": 1 };
export const RIGHT = { "!": true };
// `_kw-op`'s twin: a bare atom whose UNFOLDED text is exactly `AND`, `OR` or
// `NOT` (case-insensitive) spells the operator it names — `escaped` (set
// when the atom consumed a `\`) exempts it. Run on the complete accumulated
// atom, so a word merely containing "and", like `android`, never matches.
const kwOp = (raw, escaped) => {
  if (escaped) return null;
  const up = raw.toUpperCase();
  return up === "AND" ? "&" : up === "OR" ? "|" : up === "NOT" ? "!" : null;
};
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
// dialect.
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
  // Whether the atom now being built consumed a `\` — an escaped atom is
  // never a keyword operator, so `kwOp` skips it. Reset at every flush,
  // where a new atom starts.
  let escaped = false;
  // Whether the character just processed closed a group (`)`) — the other
  // shape an implicit `&` below can follow, besides an atom still being
  // built. Cleared by every other branch, so it can never survive past an
  // unrelated character.
  let afterClose = false;
  // Returns whether it pushed an OPERATOR (a keyword atom resolving to one)
  // rather than an atom — the whitespace branch below needs to know, so a
  // space right after `NOT`/`AND`/`OR` is never mistaken for a space between
  // two operands.
  const flushAtom = () => {
    let wasOp = false;
    if (split) {
      out.push({ t: "atom", f: fold(field), v: fold(value) });
    } else if (field !== "") {
      const kw = kwOp(field, escaped);
      if (kw === null) out.push({ t: "atom", f: "", v: fold(field) });
      else { pushOp(kw); wasOp = true; }
    }
    field = "";
    value = "";
    split = false;
    escaped = false;
    return wasOp;
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
      afterClose = false;
      if (i + 1 < cs.length) {
        if (split) value += cs[i + 1]; else field += cs[i + 1];
        escaped = true;
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
    if (c === ":" && !split && field !== "") { afterClose = false; split = true; continue; }
    if (c.trim() === "") {
      // An unescaped run of whitespace is an implicit `&` — SQLite FTS5's own
      // grammar states this precedence — but ONLY between two real operands:
      // an atom still being built, or a group that just closed, before it,
      // and an atom, `!` or `(` after it. Leading, trailing and doubled
      // whitespace are silently absorbed instead of emitting anything.
      const precedes = split || field !== "" || afterClose;
      afterClose = false;
      if (precedes) {
        const wasOp = flushAtom();
        if (!wasOp) {
          let j = i + 1;
          while (j < cs.length && cs[j].trim() === "") j++;
          const follows = j < cs.length && cs[j] !== ")" && !(cs[j] in OPS && cs[j] !== "!");
          if (follows) pushOp("&");
        }
      }
      continue;
    }
    if (c === "(") { afterClose = false; flushAtom(); stack.push("("); continue; }
    if (c === ")") {
      flushAtom();
      let found = false;
      while (stack.length) {
        const top = stack.pop();
        if (top === "(") { found = true; break; }
        out.push({ t: "op", v: top });
      }
      if (!found) repaired.push("unmatched-close");
      // Only a GROUP THAT ACTUALLY CLOSED counts as an operand for the
      // whitespace rule above — a stray `)` with nothing to close is not one.
      afterClose = found;
      continue;
    }
    if (c in OPS) { afterClose = false; flushAtom(); pushOp(c); continue; }
    // A `-` that OPENS an atom — nothing accumulated yet, so it cannot be the
    // hyphen inside a word like `in-progress` — spells `!`: `-tags:draft` is
    // `!tags:draft`, `window -depth` is `window & !depth`.
    if (c === "-" && !split && field === "") { afterClose = false; pushOp("!"); continue; }
    afterClose = false;
    if (split) value += c; else field += c;
  }
  flushAtom();
  while (stack.length) {
    const top = stack.pop();
    if (top === "(") repaired.push("unclosed-open");
    else out.push({ t: "op", v: top });
  }
  return { rpn: out, repaired };
};
// Port of `split-query`. THE ENTRY POINT: every clause, gating or scoring,
// lives in the returned `rpn` — there is no separate residual text, because
// a bare word is itself a clause `eval-clauses` composes with a field clause
// exactly as it composes two field clauses.
export const splitQuery = (q) => parseTagQuery(q);
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
//
// `resolve` MAY carry a THIRD field, `tier`, on `{matched, score}` — the
// twin of `_tier-of`/`_tier-max` in `tagquery.typ`'s own comment. Missing
// reads as `"none"`, which is every gating clause and `evalTagQuery`'s own
// resolver; `&` and a matching `|` promote to whichever matched side scored
// in the `"name"` tier, else `"body"`, else `"none"`; `!` always carries
// `"none"`.
const _tierOf = (x) => x.tier ?? "none";
const _tierMax = (a, b) => (a === "name" || b === "name" ? "name" : a === "body" || b === "body" ? "body" : "none");
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
      st.push({ matched: !a.matched, score: 0, tier: "none" });
      continue;
    }
    if (st.length < 2) continue;
    const b = st.pop();
    const a = st.pop();
    const at = _tierOf(a);
    const bt = _tierOf(b);
    if (tok.v === "&") {
      st.push({ matched: a.matched && b.matched, score: a.score + b.score, tier: _tierMax(at, bt) });
      continue;
    }
    const matched = a.matched || b.matched;
    const score = a.matched && b.matched
      ? Math.max(a.score, b.score)
      : a.matched ? a.score : b.matched ? b.score : 0;
    const tier = a.matched && b.matched ? _tierMax(at, bt) : a.matched ? at : b.matched ? bt : "none";
    st.push({ matched, score, tier });
  }
  return st.length === 0 ? { matched: true, score: 0 } : st[st.length - 1];
};
// Port of `eval-tag-query`. `tags` must already be folded. A thin call to
// `evalClauses` above: tags gate and never score, so `resolve` always
// returns `score: 0` and only `matched` is read.
//
// AN EMPTY VALUE IS NO CONSTRAINT rather than a membership test against an
// empty string: `tags.some(tg => tg.startsWith(""))` is true for a TAGGED
// note but false for an untagged one, and a half-typed `tags:` (a field with
// nothing after its colon) is meant to filter nothing at all, tagged or not.
export const evalTagQuery = (rpn, tags) =>
  evalClauses(rpn, (field, value) => ({
    matched: value === "" || tags.some((tg) => tg === value || tg.startsWith(value)),
    score: 0,
  })).matched;
// The atoms whose PRESENCE on a note is evidence for the query, walked over
// the RPN with a stack of sets: `!` replaces the set below it with the empty
// set (nothing is evidence for an absence), `&`/`|` union the two below, and
// the surviving top-of-stack set is the answer. `keep(tok)` decides which
// atoms seed a non-empty set in the first place — everything else about the
// walk is shared between the two callers below.
const _evidenceAtoms = (rpn, keep) => {
  const st = [];
  for (const tok of rpn) {
    if (tok.t === "atom") {
      st.push(keep(tok) ? new Set([tok.v]) : new Set());
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
// TEXT clauses only (`f === ""`) — a gating clause marks nothing, because
// there is no body text for it to highlight. This is what marks the TITLE
// and ID in a result row: every bare word the query positively requires,
// the same set `queryTerms` used to build out of the old residual text.
//
// Lenient exactly as `evalTagQuery` is — a missing operand is skipped, never
// thrown on, because a live search box types every prefix of a valid query on
// the way to it.
//
// NO PARITY REQUIREMENT: there is no Typst counterpart, and none is wanted.
// `#search-ideas` returns data; which chip to highlight is presentation, and
// the Typst side renders no chips.
//
// PRESENTATION ONLY, and subordinate: if this and `evalTagQuery`/`evalClauses`
// ever disagree about a note, the evaluator is right by definition — it
// decides which rows exist, this only decides what is marked on one.
export const positiveAtoms = (rpn) => _evidenceAtoms(rpn, (t) => t.f === "");
// TAG clauses only (`f === "tags"`) — the sibling of `positiveAtoms` above,
// for marking a result row's own TAG PILLS rather than its title. A pill is
// evidence for the query only when an atom actually named the `tags` field,
// which is what `tags:note|noteb` marks `noteb` for and a bare `note` in the
// query text does not.
export const positiveTagAtoms = (rpn) => _evidenceAtoms(rpn, (t) => t.f === "tags");
