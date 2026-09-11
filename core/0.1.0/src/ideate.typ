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
// `separator:` decides where one note ends and the next begins. Five spellings
// are accepted, and nothing else:
//
//   par                       every paragraph is a note (the default)
//   parbreak                  the same thing; the previous default, kept working
//   heading.where(level: 2)   every `==` starts a note — the bracket-free form
//   heading(level: 2)[]       the same, as an element; nothing to parse
//   none                      nothing splits: the whole body is ONE note
//
//   #ideate[..]                                         // default: by paragraph
//   #ideate(separator: heading.where(level: 2))[..]     // each `==` starts one
//   #ideate(separator: none)[..]                        // the block is one note
//
// also as a show rule, which is the case that motivated the argument at all — a
// weeknotes-style document where every `==` section, not every paragraph, is the
// unit worth minting as a note:
//
//   #show: ideate.with(separator: heading.where(level: 2), tags: "weeknotes")
//
// `par` NAMES THE SPLIT; IT DOES NOT CHANGE IT. There is no `par` element in a
// markup content tree (fact 1 below), so both par-mode spellings still split on
// `parbreak`. `par` is the honest name for what a caller is asking for and
// `parbreak` is the mechanism underneath; they are distinct values, so both are
// accepted by identity.
//
// `heading(level: 2)` BARE IS ILLEGAL TYPST — `error: missing argument: body`,
// since `heading` takes its body positionally. It is the first thing anyone
// tries, and it is exactly what `heading.where(level: 2)` exists to give them.
// Two consequences worth stating, because both look like oversights:
//
//   - Typst's own compiler reports that failure, not this file, so the panic
//     below cannot fire for this particular mistake however well it is worded.
//   - It cannot be fixed here either. The only route would be exporting a
//     `heading` of our own with an optional body, shadowing the element for
//     everyone who star-imports this package — and MEASURED, that breaks every
//     consumer's show rule outright: `#show heading: ..` over a plain function
//     is `error: only element functions can be used as selectors`.
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
// PAR MODE DISCARDS ITS SEPARATOR; HEADING KEEPS IT. In par mode the
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
//   5. NOT EVERY CHILD WAS WRITTEN BY THE AUTHOR. A body handed to `#ideate` as
//      a document show rule inside a rheo project ends with a trailing `context`
//      child — rheo's own page postamble, appended to every page. It renders
//      nothing, but it is not whitespace either, so fact 3's filter lets it
//      through and it used to mint one bodyless note per page. A group with
//      nothing an author wrote in it is emitted UNWRAPPED rather than minted or
//      dropped: dropping it would delete the postamble.

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

// A REFERENCE VALUE FOR THE CONTEXT ELEMENT, and there is no other way to get
// one: `context` is a Typst KEYWORD, not a function, so it cannot be named the
// way `text` or `metadata` can. Building one piece of content out of it and
// asking for its `.func()` yields the element function, which then compares
// equal to any context child. MEASURED: `[#context none].func()` reprs as
// `context`, and equals the `.func()` of a real context child.
#let _ctx-fn = [#context none].func()

// Emits nothing on its own and carries nothing an author wrote. Not blank — it
// has to survive — but not a note either.
//
// FACT 5, the one that is not about markup at all. A body handed to `#ideate`
// as a DOCUMENT SHOW RULE inside a rheo project ends with a trailing `context`
// child that the author never typed: rheo appends its own page postamble to
// every page. MEASURED on `waterline`'s `weeknotes.typ`, whose children ended
// `.. | parbreak | context | space` — so the final group was `(context, space)`,
// which `_blank` alone reads as non-blank, and every page in that build minted
// one extra note whose entire visible content was the empty `page-refs` block
// `#idea` emits for everything (`bib.typ`'s `_sweep-block`). An anonymous,
// bodyless note that a tag query returned beside the real ones.
//
// `metadata` is here for the same reason and needs no trick, being an ordinary
// function: `metadata(1).func() == metadata`.
#let _inert(c) = {
  let f = c.func()
  f == _ctx-fn or f == metadata
}

// Has this group anything an author wrote in it? THE ANSWER DECIDES EMIT VS
// MINT, not emit vs drop — see the emit loop for why the group still has to be
// rendered.
#let _no-content(group) = group.all(c => _blank(c) or _inert(c))

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

// The same level, read off a SELECTOR instead — `heading.where(level: 2)`, which
// is the bracket-free spelling and Typst's own idiom for naming a heading level.
//
// BY PARSING `repr`, WHICH IS NOT LAZINESS. A selector has no accessors at all:
// `type(heading.where(level: 2))` is `selector`, and `.at("level")` fails outright
// with `type selector has no method 'at'`. `repr()` is the only way in, MEASURED
// on typst 0.15.1 across every form worth trying:
//
//   heading.where(level: 2)                  -> `heading.where(level: 2)`
//   heading.where(depth: 2)                  -> `heading.where(depth: 2)`
//   heading.where(level: 10)                 -> `heading.where(level: 10)`
//   heading.where(level: 2, outlined: true)  -> `heading.where(level: 2, outlined: true)`
//   figure.where(kind: image)                -> `figure.where(kind: image)`
//   heading.where(level: 2).or(..level 3..)  -> `selector.or(heading.where(level: 3), heading.where(level: 2))`
//   selector(heading)                        -> `heading`
//
// Only the first three name a level, and the regex below matches exactly those —
// asserted in `test/units.typ`, so a Typst release that changes `repr`'s format
// fails the suite rather than silently mis-splitting somebody's deck.
//
// THE REST ARE REFUSED RATHER THAN GUESSED AT, and the last two say why that is
// not pedantry: `.or(..)` REORDERS its operands in the repr, so no honest reading
// of it survives, and `selector(heading)` reprs as a bare `heading` carrying no
// level at all.
#let _sel-level(sel) = {
  let r = repr(sel)
  let m = r.match(regex("^heading\.where\((level|depth): (\d+)\)$"))
  if m == none {
    panic(
      "ideate: `separator:` took the selector `"
        + r
        + "`, which does not name a plain heading level. Write "
        + "`heading.where(level: 2)` — one field, `level` or `depth`, holding a "
        + "whole number. A selector over another element, one carrying extra "
        + "fields, or one built with `.or(..)` cannot name a level and is refused "
        + "rather than guessed at.",
    )
  }
  int(m.captures.at(1))
}

// WRAPPED IN `context`, and it has to be: the paged passthrough below asks
// which target this is, and `_target()` reads `std.target()`, which Typst only
// answers inside a context block. Everything else here is pure content
// arithmetic — no state, no query, no layout — so the block introduces no
// convergence risk of its own; `#idea` does its own registration inside a
// context of its own already, and nesting one more changes nothing about that.
#let ideate(body, separator: par, show-frame: false, show-id: false, ..args) = context {
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
  // Five spellings, four modes:
  //
  //   par                       every paragraph is a note (the default)
  //   parbreak                  the same thing; the previous default, kept working
  //   heading.where(level: 2)   every `==` starts a note — the bracket-free form
  //   heading(level: 2)[]       the same, as an element; nothing to parse
  //   none                      nothing splits: the whole body is ONE note
  //
  // `par` NAMES THE SPLIT, IT DOES NOT CHANGE IT. There is no `par` element in a
  // markup content tree (fact 1) — MEASURED, `[One.\n\nTwo.]` holds
  // `space, text, parbreak, text, space` and no `par` anywhere — so both par-mode
  // spellings still split on `parbreak`. `par` is simply the honest name for what
  // a caller is asking for; `parbreak` is the mechanism underneath. They are
  // distinct values (`par == parbreak` is `false`), so both can be accepted by
  // identity.
  //
  // `heading(level: 2)` BARE IS ILLEGAL TYPST and never reaches here: `heading`
  // takes its body positionally, so it fails at the call site with `missing
  // argument: body`. That is what the selector form is FOR. It cannot be fixed
  // here either — the only way would be exporting a `heading` of our own with an
  // optional body, which shadows the element for everyone star-importing this
  // package, and MEASURED that breaks every consumer's `#show heading:` rule with
  // `only element functions can be used as selectors`. `heading.with(level: 2)`
  // is a `function` whose bound arguments cannot be read back, so it stays
  // unsupported too.
  //
  // Classified ONCE, before even the single-paragraph early return below: a bad
  // separator must be rejected even when there is nothing to split, or a caller
  // only discovers the typo on the one body that happens to have two paragraphs.
  let none-mode = separator == none
  let heading-elem = type(separator) == content and separator.func() == heading
  let heading-sel = type(separator) == selector
  let heading-mode = heading-elem or heading-sel
  let par-mode = type(separator) == function and (separator == par or separator == parbreak)
  if not (none-mode or heading-mode or par-mode) {
    panic(
      "ideate: `separator:` must be one of `par` (the default — every paragraph "
        + "becomes a note), `parbreak` (the same thing), `heading.where(level: 2)` "
        + "or `heading(level: 2)[]` (every heading of that level starts a note), or "
        + "`none` (nothing splits — the whole body is one note). Note the empty "
        + "body on that fourth form: `heading(level: 2)` on its own is illegal "
        + "Typst (`missing argument: body`), since `heading` takes its body "
        + "positionally — which is what `heading.where(level: 2)` is for. Got: "
        + repr(separator),
    )
  }
  let want = if heading-elem { _level-of(separator) } else if heading-sel { _sel-level(separator) }

  // `show-frame`/`show-id` default to FALSE here, inverting `#idea`'s own
  // defaults. That inversion is most of the reason this function is worth
  // having: an inferred note is not one anybody named, so a frame and a
  // permalink around every paragraph is chrome nobody asked for — and with no
  // name, the permalink points at a sequence number that means nothing to a
  // reader. Both are ordinary `#idea` arguments; pass `true` to get them back.
  let mint = idea.with(show-frame: show-frame, show-id: show-id, ..args)

  // Fact 4: one paragraph, no sequence, nothing to split.
  if not body.has("children") { return mint(body) }

  // Split into groups. In par mode (fact 1) the separator is `parbreak` and is
  // DISCARDED, the new group starting empty — unchanged from before `separator:`
  // existed. In heading mode the rule is the OPPOSITE: the separator STARTS its
  // group rather than being discarded, because `== rookery` and the bullets under
  // it are one note, with the heading as its first line. So on a match the child
  // goes into the fresh group, not the one being closed. Content before the first
  // matching heading is a preamble group like any other — it is not dropped or
  // treated specially. A heading of a non-matching level, and `parbreak` itself,
  // are ordinary content in heading mode: a section with three paragraphs in it
  // is ONE note.
  //
  // `none` MODE NEVER ENTERS THE LOOP: one group holding every child, handed to
  // the same emit rules below. Nothing needs a separate mint path — a single
  // group with content in it is minted, which is the whole of what `none` means.
  //
  // One honest consequence, and it is worth stating rather than discovering: in
  // `none` mode the trailing `context` postamble of fact 5 sits INSIDE the note
  // rather than beside it, there being only one group and that group having
  // content. It renders nothing, it is what `#ideate` did for every note before
  // `_no-content` existed, and leaving it in place beats reordering an author's
  // children to hoist it out.
  let groups = if none-mode { (body.children,) } else {
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
    groups
  }

  // THE ORDER OF THESE THREE TESTS IS LOAD-BEARING.
  //
  // The all-blank skip stays FIRST, and it is the only one that DROPS. Fact 3's
  // stray whitespace is an artefact of the markup rather than anything an author
  // wrote, so re-emitting it would put the artefact back.
  //
  // The no-content test is SECOND and EMITS rather than drops, which is the
  // whole point of separating it from the one above. The obvious fix for fact 5
  // — teach `_blank` about `context` so the all-blank skip catches it — is
  // WRONG: that `continue` discards the group, and the trailing context is
  // rheo's own page postamble. Losing it would silently break whatever it
  // registers. So the group is rendered exactly as written, just not wrapped in
  // a note nobody wrote.
  //
  // `_heading-only` is LAST and has the same shape for the same reason: a
  // heading names the run of notes under it and is emitted bare rather than
  // becoming a card whose entire body is a title.
  for group in groups {
    if group.all(_blank) { continue }
    if _no-content(group) {
      group.join()
    } else if _heading-only(group) {
      group.join()
    } else {
      mint(group.join())
    }
  }
}
