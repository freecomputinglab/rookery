// A hand-rolled BibTeX scanner: `@type{key, field = {..} | "..." | bare}`,
// nested braces, and `{{Protected Words}}` unwrapped. It does not expand
// `@string` macros, `#` concatenation, or LaTeX escapes — every value comes
// back as the literal text between its delimiters, squashed to single spaces.

#let _WS = (" ", "\t", "\n", "\r")

#let _skip-ws(cs, i) = {
  while i < cs.len() and cs.at(i) in _WS { i += 1 }
  i
}

// Newlines and runs of spaces flattened to one space: a `title = {..}` wrapped
// across three lines is one line of prose, and the indentation is the file's, not
// the title's.
#let _squash(s) = s.trim().split(regex("\\s+")).join(" ")

// One field value, from `i` sitting on its first non-space character. Returns
// `(value, next)` — Typst has no out-parameters, so every scanner here hands the
// cursor back rather than mutating one.
//
// BRACES ARE DROPPED, ALL OF THEM, not just the outer pair. In BibTeX an interior
// brace protects capitalization from the style rather than saying anything about
// the text, so `{{An}} Essay` is the words `An Essay` — with a depth count kept
// only to find where the value ends.
#let _read-value(cs, i) = {
  let n = cs.len()
  let out = ()
  if cs.at(i) == "{" {
    let depth = 0
    while i < n {
      let c = cs.at(i)
      if c == "{" {
        depth += 1
      } else if c == "}" {
        depth -= 1
        if depth == 0 {
          i += 1
          break
        }
      } else {
        out.push(c)
      }
      i += 1
    }
  } else if cs.at(i) == "\"" {
    i += 1
    while i < n and cs.at(i) != "\"" {
      out.push(cs.at(i))
      i += 1
    }
    if i < n { i += 1 }
  } else {
    // A bare value — `year = 2002`, `month = jan` — ends at the field separator.
    while i < n and not (cs.at(i) in (",", "}")) {
      out.push(cs.at(i))
      i += 1
    }
  }
  (out.join(), i)
}

// `key -> (field: value)`, field names lowercased. Characters are collected into an
// ARRAY and joined rather than appended to a string, `str + str` in a per-character
// loop being quadratic in the file's length.
#let parse-bib(src) = {
  let cs = src.clusters()
  let n = cs.len()
  let entries = (:)
  let i = 0
  while i < n {
    if cs.at(i) != "@" {
      i += 1
      continue
    }
    i += 1
    // The entry type, then its opening brace. Stopping at a newline as well keeps a
    // stray top-level `@` from swallowing the rest of the file; an `@` INSIDE a
    // value never reaches here, `_read-value` having consumed it.
    let entry-type = ()
    while i < n and not (cs.at(i) in ("{", "\n")) {
      entry-type.push(cs.at(i))
      i += 1
    }
    if i >= n or cs.at(i) != "{" { continue }
    let entry-type = lower(entry-type.join().trim())
    i += 1
    let key = ()
    while i < n and not (cs.at(i) in (",", "}")) {
      key.push(cs.at(i))
      i += 1
    }
    let key = key.join().trim()
    // `"entry-type"` under the key a BibTeX field name can never carry — a field name
    // cannot contain a hyphen — so this can't collide with a real field.
    let fields = ("entry-type": entry-type)
    while i < n {
      i = _skip-ws(cs, i)
      if i >= n { break }
      let c = cs.at(i)
      // The entry's own closing brace, which is also where a trailing comma lands.
      if c == "}" {
        i += 1
        break
      }
      if c == "," {
        i += 1
        continue
      }
      let name = ()
      while i < n and not (cs.at(i) in ("=", ",", "}")) {
        name.push(cs.at(i))
        i += 1
      }
      if i >= n or cs.at(i) != "=" { break }
      i += 1
      i = _skip-ws(cs, i)
      if i >= n { break }
      let (value, next) = _read-value(cs, i)
      i = next
      fields.insert(lower(name.join().trim()), _squash(value))
    }
    if key != "" { entries.insert(key, fields) }
  }
  entries
}
