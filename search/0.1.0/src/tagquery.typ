// The `tags:` query language: a boolean expression over a note's tags.
//
// The whole language and nothing else — the prefix that opens an expression
// (`split-query`), a shunting-yard parse to RPN, and an evaluator over that RPN.
// Refining the language means editing this file and its JavaScript twin,
// `src/tagquery.js`, and no other; `test/parity.mjs` pins the two case for case,
// `parse-tag-query` against `parseTagQuery` and `split-query` against
// `splitQuery`.

#import "base.typ": *

//   tags:(a|b)&c        `&` binds tighter than `|`; `()` groups
//   tags:!draft         `!` negates, binds tightest, right-associative
//   tags:draft window   an unescaped SPACE ends the tag expression; the rest
//                       ("window") is the residual text query
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

// Parse everything after `tags:` into RPN, plus the text that followed the
// expression. `(rpn: (("atom", field, str)|("op", str), ..), residual: str,
// repaired: (str, ..))`.
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
  let residual = ""
  let i = 0
  let n = cs.len()
  let stop = false
  while i < n and not stop {
    let c = cs.at(i)
    if c == "\\" {
      // The escape takes the NEXT cluster literally into whichever
      // accumulator is current, whatever it is — that is what makes a tag
      // containing an operator, or a literal `:`, reachable at all. A
      // trailing `\` has nothing to escape, so it repairs rather than
      // reading past the end.
      if i + 1 < n {
        if split { atom-value += cs.at(i + 1) } else { atom-field += cs.at(i + 1) }
        i += 1
      } else {
        repaired.push("trailing-backslash")
      }
    } else if c == ":" and not split and atom-field != "" {
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
      // `array.join()` on an EMPTY array returns `none` in Typst, not `""`, and
      // the empty slice is reached by a query whose last cluster is the separating
      // space (`tags:draft `, typed on the way to `tags:draft window`) — hence the
      // length test rather than handing `none` to `.trim()`. JavaScript's
      // `slice(i + 1).join("")` yields `""` unaided, so the ports agree.
      let rest = cs.slice(i + 1)
      residual = if rest.len() == 0 { "" } else { rest.join("") }
      stop = true
    } else if c == "(" {
      if split {
        out.push(("atom", _fold(atom-field), _fold(atom-value)))
        atom-field = ""; atom-value = ""; split = false
      } else if atom-field != "" {
        out.push(("atom", "", _fold(atom-field)))
        atom-field = ""
      }
      stack.push("(")
    } else if c == ")" {
      if split {
        out.push(("atom", _fold(atom-field), _fold(atom-value)))
        atom-field = ""; atom-value = ""; split = false
      } else if atom-field != "" {
        out.push(("atom", "", _fold(atom-field)))
        atom-field = ""
      }
      let found = false
      while stack.len() > 0 and not found {
        let top = stack.pop()
        if top == "(" { found = true } else { out.push(("op", top)) }
      }
      if not found { repaired.push("unmatched-close") }
    } else if c in _prec {
      if split {
        out.push(("atom", _fold(atom-field), _fold(atom-value)))
        atom-field = ""; atom-value = ""; split = false
      } else if atom-field != "" {
        out.push(("atom", "", _fold(atom-field)))
        atom-field = ""
      }
      let go = true
      while go and stack.len() > 0 {
        let top = stack.last()
        if top == "(" {
          go = false
        } else {
          // `!` at EQUAL precedence does NOT pop — the `c != "!"` below — which is
          // its right-associativity, and what makes `!!a` parse instead of
          // emitting a `!` with no operand under it.
          let higher = if _prec.at(top) > _prec.at(c) {
            true
          } else if _prec.at(top) == _prec.at(c) and c != "!" { true } else { false }
          if higher { out.push(("op", stack.pop())) } else { go = false }
        }
      }
      stack.push(c)
    } else {
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
    out.push(("atom", "", _fold(atom-field)))
  }
  while stack.len() > 0 {
    let top = stack.pop()
    if top == "(" { repaired.push("unclosed-open") } else { out.push(("op", top)) }
  }
  (rpn: out, residual: residual.trim(), repaired: repaired)
}

// Evaluate a parsed `rpn` against ONE note's tags — `true` when the note passes
// the filter. `tags` must already be folded by the caller (`_fold` each of
// them): the RPN's atoms were folded at push time, and folding one side only
// would make `in-progress` unfindable by "in progress".
//
// AN EMPTY RPN MEANS NO FILTER, everything matches, so a bare `tags:` lists the
// whole corpus rather than nothing — the state the bar is in for one keystroke
// every time a reader starts a tag query.
//
// An atom matches a tag by PREFIX on the folded form, not exact equality, so
// `tags:note` matches `note`, `notebook` and `notes`. Deliberate: the bar and
// the modal are incremental, and exact matching shows an empty list for every
// keystroke of a tag until it is complete. The tags rendered on each result row
// are what disambiguates.
//
// The two arity guards (`st.len() > 0`, `st.len() >= 2`) are the other half of
// "parsing never fails": a dangling operator from a repaired query is SKIPPED
// for want of operands rather than crashing the build or the bar. An underflowed
// stack falls back to `true`, i.e. to no filter, which is the same answer an
// empty RPN gives.
#let eval-tag-query(rpn, tags) = {
  if rpn.len() == 0 { return true }
  let st = ()
  for tok in rpn {
    // `..` swallows an atom's middle FIELD slot, which this evaluator
    // ignores for now — a 3-tuple atom and a 2-tuple op both destructure to
    // their first (kind) and last (value/operator) slot.
    let (kind, .., v) = tok
    if kind == "atom" {
      st.push(tags.any(tg => tg == v or tg.starts-with(v)))
    } else if v == "!" {
      if st.len() > 0 { st.push(not st.pop()) }
    } else if st.len() >= 2 {
      let b = st.pop()
      let a = st.pop()
      st.push(if v == "&" { a and b } else { a or b })
    }
  }
  if st.len() == 0 { true } else { st.last() }
}

// Split a reader's raw query into its tag filter and its text part:
// `(rpn: (..), text: str, repaired: (..))`. This is the one entry point a UI
// needs — `parse-tag-query` and `eval-tag-query` are exported for a caller doing
// something else with the pieces.
//
// The prefix test is case-insensitive (`TAGS:note` works) but only leading
// whitespace is trimmed before it, so `tags:` must open the query: a mid-query
// `tags:` is text, matching how a person reads it. `slice(5)` is safe on byte
// offsets because `tags:` is five ASCII bytes.
//
// The non-tags branch returns `q` UNTOUCHED rather than trimmed — `fuzzy-score`
// and `body-score` fold and split their own query, so trimming here would only
// be a second place for the two languages to disagree about whitespace.
#let split-query(q) = {
  let s = q.trim(at: start)
  if lower(s).starts-with("tags:") {
    let r = parse-tag-query(s.slice(5))
    (rpn: r.rpn, text: r.residual, repaired: r.repaired)
  } else {
    (rpn: (), text: q, repaired: ())
  }
}
