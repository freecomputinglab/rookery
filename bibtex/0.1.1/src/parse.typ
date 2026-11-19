// A hand-rolled BibTeX scanner: `@type{key, field = {..} | "..." | bare}`,
// nested braces, and `{{Protected Words}}` unwrapped. It does not expand
// `@string` macros, `#` concatenation, or LaTeX escapes — every value comes
// back as the literal text between its delimiters, squashed to single spaces.

// Newlines and runs of spaces flattened to one space: a `title = {..}` wrapped
// across three lines is one line of prose, and the indentation is the file's, not
// the title's.
#let _squash(s) = s.trim().split(regex("\\s+")).join(" ")

#let _BRACES = regex("[{}]")
#let _HEAD = regex("^@([A-Za-z]+)\\s*\\{\\s*([^,\\s]+)\\s*,")
#let _FIELD = regex("^[\\s,]*([A-Za-z][A-Za-z0-9_\\-]*)\\s*=\\s*")

// One field value, from `s` sitting on its first character. Returns `(value, next)`
// — Typst has no out-parameters, so every scanner here hands the cursor back rather
// than mutating one.
//
// A braced value is found by jumping between brace positions rather than walking
// its characters one at a time: `s.matches(_BRACES)` is a single native pass over
// the whole value, and depth-counting then loops over BRACES — usually two or
// four — instead of over every character the value contains. This is what lets a
// 16,000-character `abstract` parse at all: a per-character `while` loop is capped
// at 10,000 iterations by Typst itself.
//
// BRACES ARE DROPPED, ALL OF THEM, not just the outer pair. In BibTeX an interior
// brace protects capitalization from the style rather than saying anything about
// the text, so `{{An}} Essay` is the words `An Essay`.
#let _value(s) = {
  if s.starts-with("{") {
    let depth = 0
    let end = none
    for m in s.matches(_BRACES) {
      if m.text == "{" { depth += 1 } else {
        depth -= 1
        if depth == 0 { end = m.start; break }
      }
    }
    if end == none { return (s.slice(1).replace("{", "").replace("}", ""), s.len()) }
    (s.slice(1, end).replace("{", "").replace("}", ""), end + 1)
  } else if s.starts-with("\"") {
    let q = s.slice(1).position("\"")
    if q == none { return (s.slice(1), s.len()) }
    (s.slice(1, q + 1), q + 2)
  } else {
    // A bare value — `year = 2002`, `month = jan` — ends at the field separator.
    let e = s.position(regex("[,}]"))
    if e == none { return (s, s.len()) }
    (s.slice(0, e), e)
  }
}

// One `@type{key, ..}` chunk, as `bib-chunks` below hands it out, parsed into
// `(key, fields)` — `field: value`, field names lowercased, values squashed. `none`
// if `chunk` doesn't even start with a recognizable entry head.
//
// `"entry-type"` sits under a key a real BibTeX field name can never carry — a
// field name cannot contain a hyphen — so it can't collide with a field the entry
// actually has.
#let parse-entry(chunk) = {
  let m = chunk.match(_HEAD)
  if m == none { return none }
  let fields = ("entry-type": lower(m.captures.at(0)))
  let rest = chunk.slice(m.end)
  while true {
    let fm = rest.match(_FIELD)
    if fm == none { break }
    let after = rest.slice(fm.end)
    let (value, next) = _value(after)
    fields.insert(lower(fm.captures.at(0)), _squash(value))
    rest = after.slice(next)
  }
  (m.captures.at(1).trim(), fields)
}

// `key -> that entry's own source text`, one native `str.split` over the whole
// file rather than a per-character scan — this is where nearly all of the
// speedup over a character-at-a-time reader comes from, since every entry then
// gets its own small chunk to parse instead of sharing one array with an element
// per character in the file.
//
// Splitting on `"\n@"` costs nothing measurable (it's native Rust) at the price of
// one known gap: a braced value containing a line that itself starts with `@`
// would be cut in the wrong place. BibTeX exports don't wrap values that way (a
// wrapped value is indented), so this is an acceptable trade.
#let bib-chunks(src) = {
  let out = (:)
  // The leading `"\n"` makes the file's OWN first entry break on the same `\n@`
  // as every other one, so it isn't handed to `parse-entry` with a doubled `@`.
  for chunk in ("\n" + src).split("\n@") {
    let c = chunk.position(",")
    if c == none { continue }
    let head = chunk.slice(0, c)
    let b = head.position("{")
    if b == none { continue }
    out.insert(head.slice(b + 1).trim(), "@" + chunk)
  }
  out
}

// `key -> (field: value)`, field names lowercased. Splits the file into entries
// first (`bib-chunks`) and parses each one on its own (`parse-entry`) rather than
// scanning the whole file through one shared array of its characters.
#let parse-bib(src) = {
  let out = (:)
  for (key, chunk) in bib-chunks(src) {
    let e = parse-entry(chunk)
    if e != none { out.insert(e.at(0), e.at(1)) }
  }
  out
}
