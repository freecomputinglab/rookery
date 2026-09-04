// `#ideate` — every paragraph in a body becomes a note.
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
#let _blank(c) = {
  let f = c.func()
  if f == [ ].func() { return true }
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

// WRAPPED IN `context`, and it has to be: the paged passthrough below asks
// which target this is, and `_target()` reads `std.target()`, which Typst only
// answers inside a context block. Everything else here is pure content
// arithmetic — no state, no query, no layout — so the block introduces no
// convergence risk of its own; `#idea` does its own registration inside a
// context of its own already, and nesting one more changes nothing about that.
#let ideate(body, show-frame: false, show-id: false, ..args) = context {
  // A PAGED TARGET GETS THE MARKUP IT WAS GIVEN. No note is minted, nothing is
  // wrapped, and `#ideas()` in that build sees nothing from here — a PDF of a
  // block of prose should be that block of prose. The same shape
  // `@rookery/slipshow` uses for its own paged branch, and for the same reason:
  // the whole apparatus is an HTML concern.
  //
  // Tested exactly as `idea.typ` tests it, EPUB included — EPUB gets the cards,
  // since it is a rendering target with a stylesheet rather than a page.
  if not (_target() == "html" or _target() == "epub") { return body }

  // `show-frame`/`show-id` default to FALSE here, inverting `#idea`'s own
  // defaults. That inversion is most of the reason this function is worth
  // having: an inferred note is not one anybody named, so a frame and a
  // permalink around every paragraph is chrome nobody asked for — and with no
  // name, the permalink points at a sequence number that means nothing to a
  // reader. Both are ordinary `#idea` arguments; pass `true` to get them back.
  let mint = idea.with(show-frame: show-frame, show-id: show-id, ..args)

  // Fact 4: one paragraph, no sequence, nothing to split.
  if not body.has("children") { return mint(body) }

  // Fact 1: split on `parbreak`, dropping the separators themselves.
  let groups = ()
  let current = ()
  for child in body.children {
    if child.func() == parbreak {
      groups.push(current)
      current = ()
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
