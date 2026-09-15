// The query language: one boolean CLAUSE TREE over a note's fields and its
// text, `&`/`|`/`!` composing a `field:value` clause with a bare word exactly
// as it composes two `field:value` clauses.
//
// The whole language and nothing else — a shunting-yard parse to RPN
// (`parse-tag-query`, `split-query` its entry point) and an evaluator over
// that RPN (`eval-clauses`). Refining the language means editing this file
// and its JavaScript twin, `src/tagquery.js`, and no other; `test/parity.mjs`
// pins the two case for case.
//
// `field` NAMES A GATING CLAUSE (`tags:draft`, prefix-matched against a note's
// tags, scoring `0`); a BARE WORD (empty field) is a SCORING clause, fuzzy- or
// body-matched against a row's text. `eval-clauses` in `rank.typ`/`score.js`
// is what resolves either kind and combines their scores — this module only
// parses and walks the tree.

#import "base.typ": *

//   tags:(a|b)&c        `&` binds tighter than `|`; `()` groups
//   tags:!draft         `!` negates, binds tightest, right-associative
//   tags:draft window   an unescaped SPACE is an implicit `&` — the note must
//                       be tagged draft AND its text must match "window"
//   tags:a\&b           `\` escapes the next cluster into the current atom
//   tags:in-progress    atoms and tags are BOTH folded, so `-`/`_`/space agree
//
// This is the READER'S axis, typed into the bar, and it is a different thing
// from `#search-ideas`' `tags:` PARAMETER, which an author fixes at build time.
// Both narrow the corpus before a single score is computed; neither makes a tag
// into a search term (see `#search-ideas`' comment).
//
// THE ESCAPE SET IS EXACTLY `( ) | & ! \` AND IS FROZEN. A tag containing one of
// those characters must be escaped in a query, and promoting some further
// character to an operator later would silently change what queries already
// written mean. Adding to this set is a breaking change, not a feature.
//
// SHUNTING-YARD RATHER THAN RECURSIVE DESCENT, for two reasons: an iterative
// parser emits an RPN token ARRAY, which the fixture can diff across the two
// languages as data exactly as it diffs scores; and it needs no recursion, so a
// deeply nested query cannot reach Typst's call-depth ceiling.
//
// A parse costs about 60 microseconds and a build does one, so nothing here is
// worth caching.

// The operator table. A DICTIONARY, not an array of operators plus a lookup:
// `c in _prec` is then a KEY test — precisely the question the tokenizer asks of
// each cluster — and the precedence it needs next is in the same structure.
#let _prec = ("!": 3, "&": 2, "|": 1)

// A bare atom whose UNFOLDED text is exactly `AND`, `OR` or `NOT`
// (case-insensitive) spells the operator it names — `escaped` (set when the
// atom consumed a `\`) exempts it, so `\AND` stays the atom "and". Run on
// the COMPLETE accumulated atom at push time, this rejects any substring: a
// word merely containing "and", like `android`, never reaches here as
// anything but the whole word.
#let _kw-op(raw, escaped) = {
  if escaped { return none }
  let up = upper(raw)
  if up == "AND" { "&" } else if up == "OR" { "|" } else if up == "NOT" { "!" } else { none }
}

// The precedence-climbing pop-then-push shared by every place an operator
// reaches the stack: an explicit `!`/`&`/`|` cluster, and a keyword or a
// leading `-` once either resolves to the operator it stands for. Isolated
// here so all three go through the identical climb.
#let _push-op(out, stack, op) = {
  let go = true
  while go and stack.len() > 0 {
    let top = stack.last()
    if top == "(" {
      go = false
    } else {
      // `!` at EQUAL precedence does NOT pop — the `op != "!"` below — its
      // right-associativity, matching the explicit-operator branch.
      let higher = if _prec.at(top) > _prec.at(op) {
        true
      } else if _prec.at(top) == _prec.at(op) and op != "!" { true } else { false }
      if higher { out.push(("op", stack.pop())) } else { go = false }
    }
  }
  stack.push(op)
  (out, stack)
}

// Parse a WHOLE query into RPN. `(rpn: (("atom", field, str)|("op", str),
// ..), repaired: (str, ..))`.
//
// An atom token is a 3-TUPLE, `("atom", "tags", "draft")` for `tags:draft`,
// `("atom", "", "window")` for a bare word — and an op token stays the
// 2-TUPLE it always was, `("op", "&")`. Both are tuples rather than
// dictionaries: JSON-comparable and cheap, and the JavaScript port uses the
// same slots so the fixture can diff them as data.
//
// PARSING NEVER FAILS. Every malformed form repairs itself and records a reason:
// `tags:(a|` -> `["a" |]` + `unclosed-open`, `tags:)a` -> `["a"]` +
// `unmatched-close`, `tags:a&` -> `["a" &]` (a dangling operator that
// `eval-tag-query` then skips for want of operands). This is not laxity: in a
// live search box every prefix of a valid query is typed on the way to it, so
// `tags:(a|` MUST behave as `tags:a` rather than as an error. One lenient rule
// shared by both languages is also the only version of this that can be
// parity-tested — two different error paths could not be diffed. `repaired` is
// returned for a future affordance in the bar and has no consumer yet.
#let parse-tag-query(src) = {
  let cs = src.clusters()
  let out = ()
  let stack = ()
  let repaired = ()
  // `atom-field`/`atom-value` split one atom's text either side of its first
  // unescaped `:` — `split` tracks whether that colon has been seen yet, so
  // an escaped or a second `:` lands in `atom-value` rather than triggering a
  // second split (`a:b:c` is field `a`, value `b:c`). An atom with no colon at
  // all lands entirely in `atom-field`, pushed at each boundary below as a
  // field-less atom whose value is `atom-field`.
  let atom-field = ""
  let atom-value = ""
  let split = false
  // Whether the atom now being built consumed a `\` — an escaped atom is
  // never a keyword operator, so `_kw-op` skips it. Reset at every flush,
  // where a new atom starts.
  let atom-escaped = false
  // Whether the character just processed closed a group (`)`) — the other
  // shape, besides an atom still being built, that an implicit `&` below can
  // follow. Every other branch clears it, so it can never survive past an
  // unrelated character to make a later space look like it follows a group
  // that closed several characters ago.
  let after-close = false
  let i = 0
  let n = cs.len()
  while i < n {
    let c = cs.at(i)
    if c == "\\" {
      after-close = false
      // The escape takes the NEXT cluster literally into whichever
      // accumulator is current, whatever it is — that is what makes a tag
      // containing an operator, or a literal `:`, reachable at all. A
      // trailing `\` has nothing to escape, so it repairs rather than
      // reading past the end.
      if i + 1 < n {
        if split { atom-value += cs.at(i + 1) } else { atom-field += cs.at(i + 1) }
        atom-escaped = true
        i += 1
      } else {
        repaired.push("trailing-backslash")
      }
    } else if c == ":" and not split and atom-field != "" {
      after-close = false
      // The FIRST unescaped `:`, decided as the text accumulates rather than
      // by re-scanning a finished atom, which cannot tell an escaped `:`
      // from a real one. Only splits when a field name already sits in
      // `atom-field` — a leading `:` (`:draft`) has nothing before it, so it
      // stays a literal character of a bare text atom instead of becoming a
      // field clause with an empty name.
      split = true
    } else if c.trim() == "" {
      // `c.trim() == ""` is the whitespace test rather than a regex, so each side
      // keeps its own runtime's definition: Rust's `char::is_whitespace`, which
      // Typst's `trim` uses, and JavaScript's `String.trim` agree on everything a
      // search box realistically holds. They differ on U+FEFF, which JavaScript
      // trims and Rust does not, and the readme records that as a limitation.
      //
      // An unescaped run of whitespace is an implicit `&` — SQLite FTS5's own
      // grammar states this precedence: <https://www.sqlite.org/fts5.html> —
      // but ONLY between two real operands: an atom still being built, or a
      // group that just closed, before it, and an atom, `!` or `(` after it.
      // Leading, trailing and doubled whitespace are silently absorbed
      // instead of emitting anything, which is what lets a half-typed query
      // (a trailing space on the way to the next word) keep parsing.
      let precedes = split or atom-field != "" or after-close
      after-close = false
      if precedes {
        // Whether the flush below emitted an OPERATOR (a keyword atom
        // resolving to one) rather than an atom — if it did, the space
        // separates that operator from ITS OWN right operand, not two
        // operands from each other, so the implicit-`&` check below must not
        // run: `NOT a` would otherwise splice a spurious `&` between `!` and
        // `a`, and `a OR b` between `|` and `b`, corrupting both.
        let flushed-op = false
        if split {
          out.push(("atom", _fold(atom-field), _fold(atom-value)))
          atom-field = ""; atom-value = ""; split = false
        } else if atom-field != "" {
          let kw = _kw-op(atom-field, atom-escaped)
          if kw == none {
            out.push(("atom", "", _fold(atom-field)))
          } else {
            (out, stack) = _push-op(out, stack, kw)
            flushed-op = true
          }
          atom-field = ""
        }
        atom-escaped = false
        if not flushed-op {
          let j = i + 1
          while j < n and cs.at(j).trim() == "" { j += 1 }
          let follows = j < n and cs.at(j) != ")" and not (cs.at(j) in _prec and cs.at(j) != "!")
          if follows {
            // The same precedence-climbing pop every explicit operator below
            // does, at `&`'s own precedence — the only place that is
            // observable is `a|b c`, which must parse as `a | (b & c)` rather
            // than `(a|b) & c`.
            let go = true
            while go and stack.len() > 0 {
              let top = stack.last()
              if top == "(" {
                go = false
              } else if _prec.at(top) >= _prec.at("&") {
                out.push(("op", stack.pop()))
              } else { go = false }
            }
            stack.push("&")
          }
        }
      }
    } else if c == "(" {
      after-close = false
      if split {
        out.push(("atom", _fold(atom-field), _fold(atom-value)))
        atom-field = ""; atom-value = ""; split = false
      } else if atom-field != "" {
        let kw = _kw-op(atom-field, atom-escaped)
        if kw == none {
          out.push(("atom", "", _fold(atom-field)))
        } else {
          (out, stack) = _push-op(out, stack, kw)
        }
        atom-field = ""
      }
      atom-escaped = false
      stack.push("(")
    } else if c == ")" {
      if split {
        out.push(("atom", _fold(atom-field), _fold(atom-value)))
        atom-field = ""; atom-value = ""; split = false
      } else if atom-field != "" {
        let kw = _kw-op(atom-field, atom-escaped)
        if kw == none {
          out.push(("atom", "", _fold(atom-field)))
        } else {
          (out, stack) = _push-op(out, stack, kw)
        }
        atom-field = ""
      }
      atom-escaped = false
      let found = false
      while stack.len() > 0 and not found {
        let top = stack.pop()
        if top == "(" { found = true } else { out.push(("op", top)) }
      }
      if not found { repaired.push("unmatched-close") }
      // Only a GROUP THAT ACTUALLY CLOSED counts as an operand for the
      // whitespace rule above — a stray `)` with nothing to close is not one.
      after-close = found
    } else if c in _prec {
      after-close = false
      if split {
        out.push(("atom", _fold(atom-field), _fold(atom-value)))
        atom-field = ""; atom-value = ""; split = false
      } else if atom-field != "" {
        let kw = _kw-op(atom-field, atom-escaped)
        if kw == none {
          out.push(("atom", "", _fold(atom-field)))
        } else {
          (out, stack) = _push-op(out, stack, kw)
        }
        atom-field = ""
      }
      atom-escaped = false
      (out, stack) = _push-op(out, stack, c)
    } else if c == "-" and not split and atom-field == "" {
      // A `-` that OPENS an atom — nothing accumulated yet, so it cannot be
      // the hyphen inside a word like `in-progress` — spells `!`:
      // `-tags:draft` is `!tags:draft`, `window -depth` is `window & !depth`.
      after-close = false
      (out, stack) = _push-op(out, stack, "!")
    } else {
      after-close = false
      if split { atom-value += c } else { atom-field += c }
    }
    i += 1
  }
  // An atom is folded WHEN PUSHED, here and at each operator boundary above, so
  // the RPN carries folded atoms and `eval-tag-query` compares folded against
  // folded. Folding at push time rather than at compare time is what the
  // JavaScript port mirrors, and it means an atom is folded exactly once.
  if split {
    out.push(("atom", _fold(atom-field), _fold(atom-value)))
  } else if atom-field != "" {
    let kw = _kw-op(atom-field, atom-escaped)
    if kw == none {
      out.push(("atom", "", _fold(atom-field)))
    } else {
      (out, stack) = _push-op(out, stack, kw)
    }
  }
  while stack.len() > 0 {
    let top = stack.pop()
    if top == "(" { repaired.push("unclosed-open") } else { out.push(("op", top)) }
  }
  (rpn: out, repaired: repaired)
}

// Evaluate a parsed `rpn` over CLAUSES rather than a bare boolean: each atom's
// verdict comes from `resolve(field, value)`, a caller-supplied function
// returning `(matched: bool, score: int)`, and the walk composes those pairs
// under the max-plus (arctic) semiring every production search engine uses —
// the same rule Lucene's `BooleanQuery` applies summing MUST/SHOULD scores
// while FILTER contributes zero, and Xapian's `OP_FILTER` takes its weight
// from the left side only:
//
// - an atom is whatever `resolve` says.
// - `a & b` matches on `a.matched and b.matched` and scores `a.score + b.score`.
// - `a | b` matches on `a.matched or b.matched` and scores the MAX over the
//   MATCHED sides only — an unmatched branch of `|` costs nothing.
// - `!a` matches on `not a.matched` and always scores `0`: a negated clause
//   gates but never contributes a score, positive or negative.
//
// `resolve` is what keeps this module free of any knowledge of tags, text or
// rows — `eval-tag-query` below supplies a tag-prefix resolver scoring `0`
// throughout, and a ranking caller can supply its own without a second copy
// of this walk. Integer arithmetic only: `+` and `max` over integers are
// exact in both this module and its JavaScript twin, `evalClauses` in
// `tagquery.js`, which is what lets `just parity` diff the two number for
// number.
//
// AN EMPTY RPN MEANS NO FILTER: `(matched: true, score: 0)` — an empty
// query, before a reader has typed anything at all.
//
// The two arity guards (`st.len() > 0`, `st.len() >= 2`) are the other half of
// "parsing never fails": a dangling operator from a repaired query is SKIPPED
// for want of operands rather than crashing the build or the bar. An
// underflowed stack falls back to `(matched: true, score: 0)`, the same
// answer an empty RPN gives.
//
// `resolve` MAY carry a THIRD field, `tier`, alongside `matched`/`score` —
// `_rank`/`search` use it to say which of two scoring rules produced a text
// clause's score (their own `_resolve` in `rank.typ`/`score.js`), and the walk
// threads it through `&`/`|` on the SAME pair rather than a second walk:
// `_tier-of` reads it as `"none"` where a caller's `resolve` omits it, which is
// every gating clause and `eval-tag-query`'s own resolver. `&` and a matching
// `|` take the tier of whichever side(s) actually matched, preferring `"name"`
// over `"body"` over `"none"` — the same reduction `_rank`'s comment spells
// out: any matched clause scoring in the name tier promotes the whole result.
// `!` scores `0` and carries tier `"none"`, matching that it never contributes
// a score either.
#let _tier-of(x) = x.at("tier", default: "none")
#let _tier-max(a, b) = if a == "name" or b == "name" { "name" } else if a == "body" or b == "body" { "body" } else { "none" }
#let eval-clauses(rpn, resolve) = {
  if rpn.len() == 0 { return (matched: true, score: 0) }
  let st = ()
  for tok in rpn {
    let kind = tok.at(0)
    if kind == "atom" {
      let (_, field, value) = tok
      st.push(resolve(field, value))
    } else {
      let v = tok.at(1)
      if v == "!" {
        if st.len() > 0 {
          let a = st.pop()
          st.push((matched: not a.matched, score: 0, tier: "none"))
        }
      } else if st.len() >= 2 {
        let b = st.pop()
        let a = st.pop()
        let (at, bt) = (_tier-of(a), _tier-of(b))
        if v == "&" {
          st.push((matched: a.matched and b.matched, score: a.score + b.score, tier: _tier-max(at, bt)))
        } else {
          let matched = a.matched or b.matched
          let score = if a.matched and b.matched {
            calc.max(a.score, b.score)
          } else if a.matched { a.score } else if b.matched { b.score } else { 0 }
          let tier = if a.matched and b.matched {
            _tier-max(at, bt)
          } else if a.matched { at } else if b.matched { bt } else { "none" }
          st.push((matched: matched, score: score, tier: tier))
        }
      }
    }
  }
  if st.len() == 0 { (matched: true, score: 0) } else { st.last() }
}

// Evaluate a parsed `rpn` against ONE note's tags — `true` when the note passes
// the filter. `tags` must already be folded by the caller (`_fold` each of
// them): the RPN's atoms were folded at push time, and folding one side only
// would make `in-progress` unfindable by "in progress".
//
// An atom matches a tag by PREFIX on the folded form, not exact equality, so
// `tags:note` matches `note`, `notebook` and `notes`. Deliberate: the bar and
// the modal are incremental, and exact matching shows an empty list for every
// keystroke of a tag until it is complete. The tags rendered on each result row
// are what disambiguates.
//
// A thin call to `eval-clauses` above: tags gate and never score, so `resolve`
// always returns `score: 0` and only `matched` is read.
//
// AN EMPTY VALUE IS NO CONSTRAINT rather than a set membership test against an
// empty string: `tags.any(tg => tg.starts-with(""))` is true for any TAGGED
// note but false for an untagged one, since there is no element for `.any` to
// find — and a half-typed `tags:` (an atom with a field but nothing after its
// colon) is meant to filter nothing at all, tagged or not.
#let eval-tag-query(rpn, tags) = {
  eval-clauses(rpn, (field, value) => (
    matched: value == "" or tags.any(tg => tg == value or tg.starts-with(value)),
    score: 0,
  )).matched
}

// Split a reader's raw query into its clause tree: `(rpn: (..), repaired:
// (..))`. THE ONE ENTRY POINT A UI NEEDS — every clause, gating or scoring,
// lives in `rpn`; there is no separate residual text any more, because a bare
// word is itself a clause (`("atom", "", value)`) that `eval-clauses` can
// compose with a field clause via `&`, `|` and `!` exactly as it composes two
// field clauses. `parse-tag-query` and `eval-tag-query`/`eval-clauses` are
// exported for a caller doing something else with the pieces.
#let split-query(q) = parse-tag-query(q)
