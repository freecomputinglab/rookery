// `#ideate` — every paragraph (or every section) in a body becomes a note.
//
// The one place in this package where a note is INFERRED rather than written.
// `#idea` is deliberate: a note exists where an author typed `#idea(..)`, and
// there is no "every heading is a note" rule anywhere (see `lib.typ`'s own
// header). `#ideate` does not change that — it is opt-in, per block or per
// document, and an author who does not call it never meets it.
//
//   #ideate[
//     First paragraph.
//
//     Second paragraph — both together are ONE note.
//   ]
//
//   #show: rookery
//   #show: ideate.with(separator: par)
//
//   Every paragraph below is its own note.
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
// `separator:` decides where one note ends and the next begins. Four spellings
// are accepted, and nothing else:
//
//   par                       every paragraph is a note
//   parbreak                  the same thing
//   heading.where(level: 2)   every `==` starts a note — any level
//   none                      nothing splits: the whole body is ONE note (the default)
//
//   #ideate[..]                                         // default: the block is one note
//   #ideate(separator: heading.where(level: 2))[..]     // each `==` starts one
//   #ideate(separator: par)[..]                         // one note per paragraph
//
// also as a show rule, which is the case that motivated the argument at all — a
// weeknotes-style document where every `==` section, not every paragraph, is the
// unit worth minting as a note:
//
//   #show: ideate.with(separator: heading.where(level: 2), tags: "weeknotes")
//
// ---- Tagging: a value, a function, or a beacon ---------------------------
//
// `tags:` takes any of `#idea`'s own forms — `none`, a string, an array, a
// dictionary — and puts them on EVERY note the call mints. It also takes a
// FUNCTION of `(content, labels)`, the same pair `title:` and `name:` take,
// called once per section on the heading that starts it:
//
//   #show: ideate.with(
//     separator: heading.where(level: 2),
//     tags: (content, labels) => (slug(content),),
//   )
//
//   == LIMINAL      // minted tagged `liminal`
//   == Rheo         // minted tagged `rheo`
//
// The point is that ONE function can feed `title:`, `name:` and `tags:`, so a
// note's id cannot drift from its tag, and a section titled something new
// needs nothing declared anywhere to carry a tag of its own.
//
// It reads the SEPARATING HEADING, so like `title:` and `name:` it needs
// heading mode; the preamble group (no heading of its own) is not called and
// keeps whatever `tags:` would otherwise give it, which for a function is
// nothing. `#ideate-tag` remains the per-section override and works under
// every separator mode — it is unioned last, so a beacon beats the function.
//
// ---- Naming a note explicitly: `#ideate-id` ------------------------------
//
// `name:` as a function reads the SEPARATING HEADING, so it only works in
// heading mode — `separator: par` and `separator: none` have no heading to
// read one off. `#ideate-id(id)` is the id analogue of `#ideate-tag`: dropped
// anywhere in a section's own body, it names that note explicitly under ANY
// separator, `par` and `none` included:
//
//   #ideate(separator: none)[
//     A single-note body with no heading at all.
//     #ideate-id("fixed-name")
//   ]
//
// It wins over both the `auto` counter and a `name:` function outright — a
// beacon is a fixed value the caller wrote, not a derivation to fall back
// past. At most one per section: two `#ideate-id` beacons in one section is a
// build error, the note having no way to hold two ids at once.
//
// `par` NAMES THE SPLIT; IT DOES NOT CHANGE IT. There is no `par` element in a
// markup content tree (fact 1 below), so both par-mode spellings still split on
// `parbreak`. `par` is the honest name for what a caller is asking for and
// `parbreak` is the mechanism underneath; they are distinct values, so both are
// accepted by identity.
//
// `heading(level: 2)` and `heading(level: 2)[]` ARE BOTH REFUSED. The bare
// form is illegal Typst (`error: missing argument: body`) and never reaches
// this file at all — Typst's own compiler rejects it at the call site. The
// bracketed form reaches the `separator:` classification panic further down,
// inside `#let ideate(..)`. `heading.where(level: 2)` is the spelling to use
// for either.
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
//
// A fifth fact, not about markup at all, is explained beside `_inert` below.

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

// A group that is nothing but a heading is STRUCTURE, not a note: it names the
// run of notes under it, and wrapping it would produce a card whose entire body
// is a title. Everything else a group can be — prose, a list, a figure, a code
// block, a raw block — is content, and becomes a note.
//
// `want:` IS THE ONE EXCEPTION, and it is what makes a heading-separated
// document's note set match its heading set. In heading mode the separator
// heading STARTS its group, so a group holding nothing but that heading is an
// empty SECTION — a note an author wrote and has not filled in yet — not a
// structural title standing over other notes. Dropping it deleted the section
// from `#ideas()` and so from every pinboard, outline and index, which read the
// registry: a chapter of stub headings pinned only the headings that happened to
// have a sentence under them. Such a group mints, titled and bodyless.
//
// A heading of any OTHER level alone stays structure (`= Part One` over a run of
// `==` sections; a stray `===` in the preamble group), and `want: none` — par
// mode, `none` mode, and the unit tests' own default — keeps the old rule whole.
#let _heading-only(group, want: none) = {
  let real = group.filter(c => not _blank(c))
  if real.len() != 1 { return false }
  let only = real.first()
  if only.func() != heading { return false }
  want == none or _level-of(only) != want
}

// A REFERENCE VALUE FOR THE CONTEXT ELEMENT, and there is no other way to get
// one: `context` is a Typst KEYWORD, not a function, so it cannot be named the
// way `text` or `metadata` can. Building one piece of content out of it and
// asking for its `.func()` yields the element function, which then compares
// equal to any context child. MEASURED: `[#context none].func()` reprs as
// `context`, and equals the `.func()` of a real context child.
#let _ctx-fn = [#context none].func()

// Extract the tag value from a `#ideate-tag` metadata beacon, or `none` if this
// child is not a beacon. A beacon carries `metadata` with a dictionary value
// holding the key `rookery-ideate-tags`.
#let _ideate-tag-value(c) = {
  if c.func() != metadata { return none }
  if type(c.value) != dictionary { return none }
  if "rookery-ideate-tags" not in c.value { return none }
  c.value.rookery-ideate-tags
}

// Extract the id value from an `#ideate-id` metadata beacon, or `none` if
// this child is not one. Mirrors `_ideate-tag-value` exactly.
#let _ideate-id-value(c) = {
  if c.func() != metadata { return none }
  if type(c.value) != dictionary { return none }
  if "rookery-ideate-id" not in c.value { return none }
  c.value.rookery-ideate-id
}

// Strip beacons from a group before joining for the minted body. Beacons are
// apparatus (like the lead heading), not authored content.
#let _strip-beacons(children) = children.filter(c => _ideate-tag-value(c) == none and _ideate-id-value(c) == none)

// Emits nothing on its own and carries nothing an author wrote. Not blank — it
// has to survive — but not a note either.
//
// FACT 5, the one that is not about markup at all. A body handed to `#ideate`
// as a document show rule under rheo ends with a trailing `context` child that
// the author never typed — rheo's own page postamble, appended to every page.
// It is neither authored content nor whitespace, so fact 3's blank filter lets
// it through, and a group holding only this (and stray whitespace) is emitted
// UNWRAPPED rather than minted or dropped: minting it would produce an
// anonymous, bodyless note; dropping it would delete the postamble.
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
#let ideate(body, separator: none, title: none, name: auto, tags: (), show-frame: false, show-id: false, ..args) = context {
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
  // `par` NAMES THE SPLIT, IT DOES NOT CHANGE IT. There is no `par` element in a
  // markup content tree (fact 1), so both par-mode spellings still split on
  // `parbreak`. `par` is simply the honest name for what a caller is asking
  // for; `parbreak` is the mechanism underneath. They are distinct values
  // (`par == parbreak` is `false`), so both can be accepted by identity.
  //
  // `heading(level: 2)` bare cannot reach here — Typst rejects it at the call
  // site (see the file header). `heading.with(level: 2)` is a `function` whose
  // bound arguments cannot be read back, so it is refused too rather than
  // guessed at.
  let none-mode = separator == none
  let heading-mode = type(separator) == selector
  let par-mode = type(separator) == function and (separator == par or separator == parbreak)
  if not (none-mode or heading-mode or par-mode) {
    panic(
      "ideate: `separator:` must be one of `par` (every paragraph becomes a "
        + "note), `parbreak` (the same thing), `heading.where(level: 2)` (every "
        + "heading of that level starts a note — any level, and `depth:` works "
        + "in place of `level:`), or `none` (nothing splits — the whole body is "
        + "one note). `heading(level: 2)[]` is written `heading.where(level: 2)` "
        + "instead. Got: "
        + repr(separator),
    )
  }
  let want = if heading-mode { _sel-level(separator) }

  let title-fn = type(title) == function
  let name-fn = type(name) == function
  let tags-fn = type(tags) == function

  // Every NON-FUNCTION `tags:` form, normalized ONCE into the same dictionary
  // shape `#idea` itself normalizes `tags:` into (`_norm-tags`, `pure.typ`) —
  // so a group's own `#ideate-tag` beacons (the emit loop below) union straight
  // into an already-normal dictionary rather than reconciling four different
  // input shapes per group.
  //
  // A FUNCTION HAS NO VALUE TO NORMALIZE HERE: it computes a per-section value
  // the emit loop normalizes as it goes, and there is no document-wide tag to
  // fall back on, so the base is empty. Handing `_norm-tags` the function
  // instead fails inside the array branch with `cannot access fields on
  // user-defined functions`, which names neither this argument nor this call.
  let base-tags = if tags-fn { (:) } else { _norm-tags(tags) }

  if name != auto and not name-fn {
    panic(
      "ideate: `name:` must be `auto` (the package counter — the default) or a "
        + "function of `(content, labels)` returning the note's id as a string. "
        + "A fixed name would mint every note in this body under one id. Got: "
        + repr(name),
    )
  }
  if (title-fn or name-fn or tags-fn) and not heading-mode {
    panic(
      "ideate: `title:`, `name:` and `tags:` functions all read the heading "
        + "that STARTS each note, so they need `separator: heading.where(level: "
        + "2)` (or another level) — with the separator actually given here there "
        + "is no heading to read. A body split by paragraph tags every note the "
        + "same, which a plain `tags:` value already says; `#ideate-tag` tags "
        + "one section under any separator. Got separator: " + repr(separator),
    )
  }

  // `show-frame`/`show-id` default to FALSE here, inverting `#idea`'s own
  // defaults. That inversion is most of the reason this function is worth
  // having: an inferred note is not one anybody named, so a frame and a
  // permalink around every paragraph is chrome nobody asked for — and with no
  // name, the permalink points at a sequence number that means nothing to a
  // reader. Both are ordinary `#idea` arguments; pass `true` to get them back.
  //
  // `title:` is forwarded only when it is NOT a function — a function
  // computes a PER-SECTION title, so it must not be forwarded as a fixed
  // value to every group. Forwarding `title: none` when it was never given is
  // identical to today's behaviour: `#idea`'s own default for that argument
  // is already `none`.
  //
  // `tags: base-tags` is bound here as every note's DEFAULT, and the emit
  // loop below overrides it per group with that group's own tags — an
  // explicit `tags:` at a call site overrides a value bound by `.with()`,
  // which is what lets a group carrying an `#ideate-tag` beacon (or a `tags:`
  // function that reads its heading) mint with tags of its own while every
  // other group still gets exactly this one.
  let mint = idea.with(
    show-frame: show-frame,
    show-id: show-id,
    tags: base-tags,
    ..(if title-fn { (:) } else { (title: title) }),
    ..args,
  )

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
  // One consequence worth stating rather than leaving to be discovered: in
  // `none` mode the trailing `context` postamble of fact 5 sits INSIDE the note
  // rather than beside it, there being only one group and that group having
  // content. It renders nothing, and leaving it in place beats reordering an
  // author's children to hoist it out.
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
  //
  // Slugs minted so far BY THIS CALL, so two sections here that read the same
  // name panic instead of silently sharing an id. A second `#ideate` call, or
  // another chapter elsewhere in the document, is not this call's problem —
  // see the readme for why that collision is left for a caller to notice.
  let seen-slugs = ()
  for group in groups {
    if group.all(_blank) { continue }
    if _no-content(group) {
      group.join()
    } else if _heading-only(group, want: want) {
      group.join()
    } else {
      // A group's own separating heading is its first non-blank child — heading
      // mode pushes the matching heading into the fresh group, so it leads
      // every group except the preamble group, which has none at all. Found by
      // POSITION, since two sections can carry identical heading content, and
      // only in heading mode — par mode and `none` mode split on `parbreak`
      // (or not at all), so no group there has a separating heading to find.
      let lead-i = if heading-mode { group.position(c => not _blank(c)) } else { none }
      let lead = if lead-i == none { none } else { group.at(lead-i) }
      let lead-heading = if lead != none and lead.func() == heading and _level-of(lead) == want { lead } else { none }

      // HOISTED OUT of the titling branch below, where it used to live: a
      // `tags:` function reads the same two arguments and is called for groups
      // that branch never reaches.
      let labels = if lead-heading == none { () } else {
        (lead-heading.at("label", default: none),).filter(l => l != none)
      }

      // A `tags:` FUNCTION IS PER-SECTION, computed from the heading that
      // starts this group — the same `(content, labels)` pair `title:` and
      // `name:` take, so one function can feed all three and a note's id
      // cannot drift from its tag. The preamble group has no heading to read
      // and is left with the base tags alone rather than called with `none`.
      let fn-tags = if tags-fn and lead-heading != none {
        _norm-tags((tags)(lead-heading.body, labels))
      } else { (:) }

      // A beacon inside the heading never reaches the fold below, so the section
      // would mint untagged (or unnamed) with nothing to say one was asked for.
      if lead-heading != none {
        let hb = lead-heading.body
        let kids = if hb.has("children") { hb.children } else { (hb,) }
        if kids.any(c => _ideate-tag-value(c) != none) {
          panic(
            "@rookery/core: #ideate-tag inside a heading is never read — move it to "
              + "its own line BENEATH the heading, as a sibling. Heading: "
              + repr(hb),
          )
        }
        if kids.any(c => _ideate-id-value(c) != none) {
          panic(
            "@rookery/core: #ideate-id inside a heading is never read — move it to "
              + "its own line BENEATH the heading, as a sibling. Heading: "
              + repr(hb),
          )
        }
      }

      // Scan the group for `#ideate-tag` metadata beacons and union their values
      // into the base tags, right-biased on key conflict (later beacons win).
      // Works under any separator mode, not just heading mode.
      let beacon-tags = group.fold((:), (acc, c) => {
        let v = _ideate-tag-value(c)
        if v == none { acc } else { acc + _norm-tags(v) }
      })
      // BEACONS LAST, so they stay the per-section override they are under a
      // plain `tags:` — a section that computes `report` from its heading and
      // also carries `#ideate-tag((report: "final"))` gets the valued one.
      let group-tags = base-tags + fn-tags + beacon-tags

      // `#ideate-id` names this one section explicitly, under ANY separator —
      // it is the only id mechanism that also works in `par` and `none` mode,
      // where there is no heading for a `name:` function to read. At most one
      // per section: two would mean the note has two ids, and neither wins.
      let beacon-ids = group.fold((), (acc, c) => {
        let v = _ideate-id-value(c)
        if v == none { acc } else { acc + (v,) }
      })
      if beacon-ids.len() > 1 {
        panic(
          "ideate: more than one #ideate-id beacon in one section — got "
            + repr(beacon-ids) + ". Only one id per note.",
        )
      }
      let beacon-id = beacon-ids.at(0, default: none)

      if not (title-fn or name-fn) or lead-heading == none {
        // Neither function computes the heading, or this group (the preamble) has
        // none of its own to title or name by — minted exactly as it would be
        // with neither function given, carrying its own tag (if any) either way.
        // A `#ideate-id` beacon still wins the id over the `auto` counter here —
        // this is the branch `par` and `none` mode always take, having no
        // heading to feed a `name:` function at all.
        let content = _strip-beacons(group).join()
        if beacon-id == none {
          mint(content, tags: group-tags)
        } else {
          if beacon-id in seen-slugs {
            panic(
              "ideate: two sections in this body slug to the same name, \""
                + beacon-id + "\" — retitle the section, or its earlier "
                + "namesake so each mints under its own id.",
            )
          }
          seen-slugs.push(beacon-id)
          mint(beacon-id, content, tags: group-tags)
        }
      } else {
        let rest = _strip-beacons(group.slice(0, lead-i) + group.slice(lead-i + 1)).join()
        let title-arg = if title-fn { (title: (title)(lead-heading.body, labels)) } else { (:) }
        // A beacon id wins over a `name:` function outright — it is a fixed
        // value the caller wrote, not a derivation to fall back past.
        let name-value = if beacon-id != none {
          beacon-id
        } else if name-fn {
          let out = (name)(lead-heading.body, labels)
          if type(out) != str or out == "" {
            panic(
              "ideate: `name:`'s function must return this note's id as a "
                + "non-empty string. Got: " + repr(out),
            )
          }
          out
        } else {
          none
        }
        if name-value == none {
          mint(rest, ..title-arg, tags: group-tags)
        } else {
          if name-value in seen-slugs {
            panic(
              "ideate: two sections in this body slug to the same name, \""
                + name-value + "\" — retitle the section, or its earlier "
                + "namesake so each mints under its own id.",
            )
          }
          seen-slugs.push(name-value)
          mint(name-value, rest, ..title-arg, tags: group-tags)
        }
      }
    }
  }
}
