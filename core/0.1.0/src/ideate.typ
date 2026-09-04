// `#ideate` — every paragraph (or every section) in a body becomes a note.
//
// The one place in this package where a note is INFERRED rather than written.
// `#idea` is deliberate: a note exists where an author typed `#idea(..)`, and
// there is no "every heading is a note" rule anywhere (see `lib.typ`'s own
// header). `#ideate` does not change that — it is opt-in, per block or per
// document, and an author who does not call it never meets it.
//
//   #ideate[
//     First paragraph — one note.
//
//     Second paragraph — another.
//   ]
//
//   #show: rookery
//   #show: ideate
//
//   Every paragraph below is a note.
//
// ONE FUNCTION COVERS BOTH FORMS, and there is no second entry point to add.
// `#show: f` at the top level means `f(rest-of-the-document)`, so a plain
// function of one positional `content` argument already IS a show rule.
//
// ORDER MATTERS when both show rules are used. Written `#show: rookery` and then
// `#show: ideate`, Typst composes them `rookery(ideate(rest))` — `ideate` sees
// the raw markup and the template wraps its output, which is the order that
// works. The reverse hands `ideate` a body the template has already transformed.
//
// ---- Choosing what starts a note: `separator:` ---------------------------
//
// `separator:` decides where one note ends and the next begins. Two values are
// accepted, and nothing else:
//
//   #ideate[..]                                  // default: split on parbreak
//   #ideate(separator: heading(level: 2)[])[..]  // each `==` starts a note
//
// also as a show rule, which is the case that motivated this argument at all —
// a weeknotes-style document where every `==` section, not every paragraph, is
// the unit worth minting as a note:
//
//   #show: ideate.with(separator: heading(level: 2)[], tags: "weeknotes")
//
// THE EMPTY BODY IS NOT OPTIONAL. `heading(level: 2)` alone is illegal Typst
// (`error: missing argument: body`) — `heading` takes its body positionally,
// so the separator spec a caller writes is `heading(level: 2)[]`, empty
// brackets and all. This is the obvious thing to get wrong; Typst's own
// compiler reports the failure, not this file, so the panic added for every
// other bad `separator:` can't even fire for this particular mistake.
//
// A heading's level lives in one of TWO different fields depending on how it
// was written, MEASURED on typst 0.15.1 (see `_level-of` below):
//
//   written as                    | .fields()             | .at("level") | .at("depth")
//   ------------------------------|------------------------|--------------|-------------
//   `== Markup two` (markup)      | (depth: 2, body: ..)   | ABSENT       | 2
//   `#heading(level: 2)[x]`       | (level: 2, body: ..)   | 2            | ABSENT
//   `heading(level: 2)[]` (spec)  | (level: 2, body: [])   | 2            | ABSENT
//
// A markup heading — what a body being ideated actually contains — carries
// `depth`, never `level`; the `separator:` spec a caller writes carries
// `level`, never `depth`. Reading the same field off both sides would compare
// `level` to nothing and match no heading ever, so both sides go through
// `_level-of`, which checks `level` first and falls back to `depth`.
//
// PARBREAK DISCARDS ITS SEPARATOR; HEADING KEEPS IT. In parbreak mode the
// `parbreak()` between two paragraphs belongs to neither and is thrown away.
// In heading mode the matching heading STARTS the group that follows it
// instead: `== rookery` plus the bullets under it is one note, with the
// heading as that note's first line — not the closing line of whatever came
// before, and not dropped either. Content before the first matching heading
// still becomes its own group, an ordinary preamble note. A heading of a
// non-matching level (`===` while `separator:` asked for level 2) is not a
// separator and stays wherever it falls; `parbreak` itself is ordinary
// content in heading mode too, so a section with three paragraphs in it is
// still exactly one note.
//
// ---- The content tree this walks, MEASURED -------------------------------
//
// There is NO `par` element in a markup content tree; Typst builds those at
// layout time. What a `[..]` body actually holds, probed on prose with a
// heading and a bulleted list in it:
//
//   space, text[First para line one], space, text[still para one.],
//   parbreak(),
//   text[Second para.],
//   parbreak(),
//   heading(depth: 2, ..),
//   parbreak(),
//   text[Third para after heading.],
//   parbreak(),
//   item(..), space, item(..),
//   parbreak(),
//   text[Fourth.], space
//
// Four facts follow, and every branch below depends on one of them:
//
//   1. `parbreak()` is the ONLY separator. Splitting on it is how you find a
//      paragraph — there is nothing else to look for.
//   2. Block elements sit in that same flat run, each surrounded by parbreaks. A
//      heading is one child; a bulleted list is a run of `item` children
//      separated by `space`, with no wrapping `list` element at this level. So
//      splitting on parbreak alone keeps a list together, for free.
//   3. There are stray `space` children at the START and END of a `[..]` body,
//      from the newline after the opening bracket and before the closing one. A
//      naive split therefore yields whitespace-only groups, which must be
//      dropped or they mint empty notes.
//   4. A single-paragraph body is not a sequence at all and has no `.children`.
//      `c.has("children")` is the test.

#import "base.typ": *
#import "idea.typ": *

// Is this child nothing but whitespace? `space` is the element Typst emits for
// a line break or a run of spaces in markup; a `text` element can also be blank.
// Both have to count, or fact 3's stray children survive the filter.
//
// `parbreak` COUNTS TOO, and it is heading mode that needs it. In parbreak mode
// a `parbreak` is the separator and so never lands inside a group at all, which
// is why this went unnoticed for as long as parbreak was the only mode. In
// heading mode a parbreak is ordinary content, and the blank line that precedes
// the FIRST `==` of a body therefore becomes a group of exactly one parbreak —
// non-blank by the old test, not heading-only either, so it minted a note whose
// entire content was a paragraph break. MEASURED as a spurious third `.idea-box`
// on a two-section document, and it is the normal case rather than an edge one:
// almost every body has a blank line before its first heading. Nothing is lost
// by dropping such a group — a parbreak between two notes is spacing, and the
// boxes bring their own.
#let _blank(c) = {
  let f = c.func()
  if f == [ ].func() { return true }
  if f == parbreak { return true }
  if f == text { return c.at("text", default: "").trim() == "" }
  false
}

// A group that is nothing but a heading is STRUCTURE, not a note: it names the
// run of notes under it, and wrapping it would produce a card whose entire body
// is a title. Everything else a group can be — prose, a list, a figure, a code
// block, a raw block — is content, and becomes a note.
#let _heading-only(group) = {
  let real = group.filter(c => not _blank(c))
  real.len() == 1 and real.first().func() == heading
}

// A heading's level lives in one of TWO different fields, MEASURED on typst
// 0.15.1, depending on how the heading was written:
//
//   written as                    | .fields()          | .at("level") | .at("depth")
//   ------------------------------|---------------------|--------------|-------------
//   `== Markup two` (markup)      | (depth: 2, body: ..) | ABSENT      | 2
//   `=== Markup three` (markup)   | (depth: 3, body: ..) | ABSENT      | 3
//   `#heading(level: 2)[x]`       | (level: 2, body: ..) | 2           | ABSENT
//   `heading(level: 2)[]` (a      | (level: 2, body: []) | 2           | ABSENT
//     `separator:` spec)
//
// A markup heading — which is what a body being ideated actually contains —
// carries `depth` and NO `level`, while a `separator:` spec a caller writes
// carries `level` and NO `depth`. Comparing `level` to `level` would match
// nothing. So read an effective level off BOTH sides with this one helper:
// `level` if present, else `depth`, else `1`.
#let _level-of(h) = h.at("level", default: h.at("depth", default: 1))

// WRAPPED IN `context`, and it has to be: the paged passthrough below asks
// which target this is, and `_target()` reads `std.target()`, which Typst only
// answers inside a context block. Everything else here is pure content
// arithmetic — no state, no query, no layout — so the block introduces no
// convergence risk of its own; `#idea` does its own registration inside a
// context of its own already, and nesting one more changes nothing about that.
#let ideate(body, separator: parbreak, show-frame: false, show-id: false, ..args) = context {
  // A PAGED TARGET GETS THE MARKUP IT WAS GIVEN. No note is minted, nothing is
  // wrapped, and `#ideas()` in that build sees nothing from here — a PDF of a
  // block of prose should be that block of prose. The same shape
  // `@rookery/slipshow` uses for its own paged branch, and for the same reason:
  // the whole apparatus is an HTML concern.
  //
  // Tested exactly as `idea.typ` tests it, EPUB included — EPUB gets the cards,
  // since it is a rendering target with a stylesheet rather than a page.
  if not (_target() == "html" or _target() == "epub") { return body }

  // Classify `separator:` ONCE, before even the single-paragraph early return
  // below — a bad separator must be rejected even when there is nothing to
  // split, or a caller only discovers the typo on the one body that happens to
  // have more than one paragraph in it.
  //
  // Two shapes are accepted:
  //   - the function `parbreak` itself (the default) — compares equal by
  //     identity, since a function is an ordinary comparable value here.
  //   - a `content` value whose `.func()` is `heading` — i.e. an actual heading
  //     element, not the function or a selector. `heading(level: 2)` alone is
  //     ILLEGAL Typst (`missing argument: body`, since `heading` takes its body
  //     positionally) and never reaches here; Typst's own compiler rejects it
  //     before this code runs. `heading.with(level: 2)` is a `function` whose
  //     bound arguments cannot be read back, and `heading.where(level: 2)` is a
  //     `selector` with no readable level either — neither is a `content`, so
  //     both fall into the panic below along with everything else.
  let heading-mode = type(separator) == content and separator.func() == heading
  let parbreak-mode = type(separator) == function and separator == parbreak
  if not (heading-mode or parbreak-mode) {
    panic(
      "ideate: `separator:` must be either `parbreak` (the default — every "
        + "paragraph becomes a note) or a heading element carrying a level, "
        + "written `heading(level: 2)[]`. Note the empty body: `heading(level: 2)` "
        + "on its own is illegal Typst (`missing argument: body`), since `heading` "
        + "takes its body positionally. Got: "
        + repr(separator),
    )
  }
  let want = if heading-mode { _level-of(separator) }

  // `show-frame`/`show-id` default to FALSE here, inverting `#idea`'s own
  // defaults. That inversion is most of the reason this function is worth
  // having: an inferred note is not one anybody named, so a frame and a
  // permalink around every paragraph is chrome nobody asked for — and with no
  // name, the permalink points at a sequence number that means nothing to a
  // reader. Both are ordinary `#idea` arguments; pass `true` to get them back.
  let mint = idea.with(show-frame: show-frame, show-id: show-id, ..args)

  // Fact 4: one paragraph, no sequence, nothing to split.
  if not body.has("children") { return mint(body) }

  // Split into groups. In parbreak mode (fact 1) the separator is discarded
  // and the new group starts empty — unchanged from before `separator:`
  // existed. In heading mode the rule is the OPPOSITE: the separator STARTS
  // its group rather than being discarded, because `== rookery` and the
  // bullets under it are one note, with the heading as its first line. So on
  // a match the child goes into the fresh group, not the one being closed.
  // Content before the first matching heading is a preamble group like any
  // other — it is not dropped or treated specially. A heading of a
  // non-matching level, and `parbreak` itself, are ordinary content in
  // heading mode: a section with three paragraphs in it is ONE note.
  let groups = ()
  let current = ()
  for child in body.children {
    let is-separator = if heading-mode {
      child.func() == heading and _level-of(child) == want
    } else {
      child.func() == parbreak
    }
    if is-separator {
      groups.push(current)
      current = if heading-mode { (child,) } else { () }
    } else {
      current.push(child)
    }
  }
  groups.push(current)

  for group in groups {
    // Fact 3: a whitespace-only group is an artefact of the markup, not a
    // paragraph the author wrote.
    if group.all(_blank) { continue }
    if _heading-only(group) {
      group.join()
    } else {
      mint(group.join())
    }
  }
}
