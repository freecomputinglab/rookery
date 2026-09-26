// The two public faces over `transclusion.typ`: `#window`, which shows a note
// inside another page, and `#idea-body`, which hands back one note's body as
// content for a caller to place itself.

#import "base.typ": *
#import "state.typ": *
#import "theme.typ": *
#import "urls.typ": *
#import "permalink.typ": *
#import "bib.typ": *
#import "transclusion.typ": *
#import "hyperlink.typ": *
#import "links.typ": *
#import "idea.typ": *

// `#window("etal")` transcludes the target note: its title, its permalink, and
// its stored (flattened) body, as one foldable block. `names` accepts a
// string, a label, or an array of either — bare (`"etal"`, `<etal>`) or full
// id (`"idea:etal"`, `<idea:etal>` — the same id `@idea:etal` resolves), see
// `_norm`. Reads the registry via `.final()`, not `.get()` — that is what
// lets a note defined in ANOTHER vertebra resolve, since the whole spine
// compiles as one Typst document.
//
// `tagged:` selects notes instead of naming them, and COMBINES with the names
// rather than replacing them: the window shows the union of what was named and
// what carries the tags, with a note that is both appearing once, where it was
// named. `match:` is "any" (the default) or "all". `filter:` is a predicate
// over the tag dictionary, ANDed with the `tagged:`/`match:` test rather than
// replacing it — it is what expresses exclusion or an OR of ANDs, which
// `tagged:`/`match:` alone cannot. Selection is always rookery-wide — the
// registry is the whole bundle's, so where the window sits makes no
// difference to what a tag or filter pulls in. At least one of a name,
// `tagged:` or `filter:` is required.
//
// `sort:` is `auto`, "date" or "lexicographic". `auto` keeps named ids in
// call-site order and appends the tag matches by id, so a window that names
// its notes and asks for no sort keeps them in call-site order; naming a
// sort orders the whole selection instead. See `_sort-ids`.
//
// A `#window` is pure presentation: it never registers, never advances the
// counter, and never re-registers a nested `#idea`. That guarantee is
// delivered by `_flatten` (defined above, next to `IK`/`WK`), not by any
// suppression logic here.
//
// `unfurl:` is the transclusion budget (see `_window-depth` for the whole
// scale): `0` transcludes nothing and renders this window as a LINK to the
// note's page, `1` renders the note and collapses a `#window` written inside it
// to its bare permalink, `n` unfurls n-1 levels of those as real windows.
// `auto`, the default, takes the document-wide setting from
// `#show: rookery.with(window-unfurl: n)` — which itself defaults to 1, the
// one-level rendering every document already has. Per call site, because
// "unfurl the whole tree here", "show it" and "just point at it" are all
// reasonable on the same page: an index that shows one note in full wants
// unfurl, a backlinks list of forty does not, and a dense index may want no
// transclusion at all.
//
// Nesting counts WINDOWS only. A `#idea` written inside a transcluded note is
// always rebuilt in full whatever the budget (that is `_flatten`'s IK rule,
// and it cannot cycle — an idea's body is finite and literally contains its
// nested ones), so `unfurl` measures exactly the thing that can cycle.
//
// Rendering — `folded`, `display.date`, `limit:`, click budget: `_window-content`.
#let window(
  ..args,
  limit: none,
  folded: false,
  // The eleven-key display dictionary `#idea` also takes (`_resolve-display`,
  // pure.typ). `#window` declares all eleven as flags too, for parity with
  // `#idea` and the `display:` dictionary, but only HONOURS seven of them —
  // `date`, `tags`, `frame`, `name`, `label`, `background`, `bibliography`.
  // `context`, `backlinks` and `title` describe a minted page, and a window
  // is not one, so all three ride along unused inside the `display:`
  // dictionary too. `right-gutter` rides along the same way, for a different
  // reason: a window never splits — its notes always float into its host
  // card's gutter (or, unwindowed, render vertically) — so the flag is
  // accepted for parity and never read.
  //
  // `bibliography` is a GROUP setting, unlike the other six: `auto` (the
  // default) leaves every rendered window with its own References block, as
  // before. A concrete `true`/`false` instead collapses the whole selection
  // to ONE combined block after the last window, `true` keeping it visible
  // and `false` hiding it — see the loop below for why it is still emitted
  // either way.
  display: (:),
  display-date: auto,
  display-tags: auto,
  // The same per-window switch `#idea` takes for a card: `false` drops the
  // window's left rule and indent and leaves everything else — the summary, the
  // disclosure, the body — exactly as it was. See `#idea`'s own comment.
  display-frame: auto,
  // `false` omits the `[idea:<name>]` permalink from the summary. With
  // `display-tags`/`display-date` also off the summary keeps only its title, and with
  // no title it keeps nothing — see `_permalink-tab` (permalink.typ).
  display-name: auto,
  // `false` names this window only if its note carries an AUTHORED title,
  // instead of falling back to the label derived from the note's first line.
  // For a window that RENDERS a note rather than referring to it — see
  // `_window-content`'s own comment on `name`.
  display-label: auto,
  // `false` renders this window with NO disclosure at all — no `<details>`,
  // no `<summary>`, nothing to click and nothing that can hide the body. For
  // a window that IS the thing being read, not a reference to it: a
  // slipshow's slide, where a stray click folding it shut would be a bug.
  // Distinct from `folded`, which sets the initial state of a disclosure
  // that exists — `folded` is inert when this is `false` (`_window-content`).
  foldable: true,
  // `false` drops the blank line a TITLELESS window's summary reserves for
  // where its title would go (`core.css`'s titleless-reservation rule) —
  // dead space above a slide's body. No effect on a titled window, which
  // never hit that reservation to begin with.
  reserve-title: true,
  // `false` drops the window's hover tint, independent of `display.frame`
  // (which takes the rule and indent but leaves the tint alone) — a slide
  // wants the frame gone and the tint kept, hence two switches.
  display-background: auto,
  // Accepted for parity with `#idea` and the `display:` dictionary; ignored
  // here, because `context`, `backlinks` and `title` describe a minted page,
  // and a window is not one.
  display-context: auto,
  display-backlinks: auto,
  display-title: auto,
  display-right-gutter: auto,
  display-bibliography: auto,
  // Whether this window COUNTS AS A LINK from wherever it sits to the note it
  // shows. `true` is right for an ordinary window written in a note's prose;
  // `false` is for a DERIVED view — a deck, an index, a preview — where the
  // window renders a note rather than pointing at it, so it should not fill
  // that note's Backlinks with pages nobody wrote a link on. It does NOT stop
  // the announce marker being emitted — see the marker itself below.
  backlink: true,
  unfurl: auto,
  tagged: none,
  match: "any",
  // A predicate over the idea's tag DICTIONARY, ANDed with `tagged:`/`match:`
  // rather than replacing them — what expresses a selection those two
  // cannot: exclusion, or an OR of ANDs.
  filter: none,
  sort: auto,
) = {
  assert(
    unfurl == auto or (type(unfurl) == int and unfurl >= 0),
    message: "@rookery/core: #window's `unfurl` must be auto or a non-negative "
      + "integer — `0` renders the note as a link to its own page, `1` (the "
      + "document default) renders it once and collapses any window inside it "
      + "to a permalink, `n` unfurls n-1 nested levels — got " + repr(unfurl),
  )
  // `>= 1`, not `>= 0`: a window showing nothing but an ellipsis truncates
  // nothing, so `limit: 0` reads as a mistake rather than a request.
  _assert-limit(limit, "#window's")
  _assert-tags(tagged, "#window's", what: "tagged")
  _assert-match(match, "#window's")
  assert(
    filter == none or type(filter) == function,
    message: "@rookery/core: #window's `filter` must be none or a "
      + "function taking the note's tag dictionary — got " + repr(filter),
  )
  assert(
    type(foldable) == bool,
    message: "@rookery/core: #window's `foldable` must be a bool — got " + repr(foldable),
  )
  assert(
    type(reserve-title) == bool,
    message: "@rookery/core: #window's `reserve-title` must be a bool — got "
      + repr(reserve-title),
  )
  assert(
    sort == auto or sort == "date" or sort == "lexicographic",
    message: "@rookery/core: #window's `sort` must be auto, \"date\" or "
      + "\"lexicographic\" — got " + repr(sort),
  )
  // `_resolve-display` already rejects a non-boolean dictionary value with
  // its own message, so a per-argument assert on any of the six flags it
  // also validates (`date`, `tags`, `frame`, `name`, `label`, `background`)
  // would be redundant for the dictionary path.
  let display = _resolve-display(
    display,
    (
      date: display-date, tags: display-tags, frame: display-frame,
      name: display-name, label: display-label, background: display-background,
      "context": display-context, backlinks: display-backlinks, title: display-title,
      "right-gutter": display-right-gutter, "bibliography": display-bibliography,
    ),
    "#window's",
  )
  // These six keys stay `auto` when unset, same as `context`/`backlinks`/
  // `title`: `#window` itself substitutes no built-in default for any of the
  // nine. `auto` means "use the document-wide `rookery(..)` setting", resolved
  // against state (`_display-final`, state.typ) at the point this window
  // actually renders: `_window-content` (transclusion.typ), which every
  // rendering path below reaches, whether directly or via `_flatten`'s WK
  // rule expanding a nested window later.
  // Variadic, not a plain positional: a positional parameter cannot carry a
  // default in typst, and `#window(tagged: "todo")` has to be callable with no
  // name at all. `#hyperlink` takes the same shape for the same reason.
  let pos = args.pos()
  // An argument sink accepts every named argument silently, so a misspelled
  // `display-*` flag would do nothing and report nothing — see `#hyperlink`
  // for the same check. Every named argument #window honours is now a
  // declared parameter, so anything arriving through the sink is unknown.
  let unknown = args.named().keys()
  assert(
    unknown.len() == 0,
    message: "@rookery/core: #window got unknown named argument(s) " + repr(unknown)
      + " — every argument #window honours is a declared one; the display "
      + "flags are display-background, display-backlinks, display-context, "
      + "display-date, display-frame, display-name, display-label, display-tags, "
      + "display-title, display-right-gutter and display-bibliography.",
  )
  assert(
    pos.len() <= 1,
    message: "@rookery/core: #window wants one name or one array of names — "
      + "#window((\"a\", \"b\")), not #window(\"a\", \"b\") — got "
      + str(pos.len()) + " positional arguments.",
  )
  assert(
    pos.len() == 1 or tagged != none or filter != none,
    message: "@rookery/core: #window needs something to show — name at least "
      + "one note, or pass `tagged:`/`filter:` to select them.",
  )
  let ids = if pos.len() == 0 { () } else {
    let names = pos.first()
    (if type(names) == array { names } else { (names,) }).map(_norm)
  }

  // A transclusion is a way of pointing at a note, so it has to show up in the
  // target's backlinks. `_outbound` walks a note's RAW body at registration,
  // where everything below is still an unevaluated `context` block with
  // nothing inspectable in it — so the names are announced up front, in an
  // invisible `metadata` element, where the walk can see them without
  // rendering anything.
  //
  // Bare names, not full ids: this runs outside `context`, so `_pfx()` is not
  // available here. `_outbound` re-adds the prefix, which it can.
  //
  // Only the NAMED ids can be announced here — a tag selection is not known
  // until the registry is readable, which needs `context`, and by then this
  // walk has already happened, so `_outbound`'s NOTE-level graph still gives a
  // tag-matched note no backlink (do not "fix" that by having `_outbound` read
  // the registry while it is still being built). The PAGE-level graph is
  // different: `_page-links` (outline.typ) runs at render time against the
  // final registry, so the tag/match selector rides the marker below and gets
  // resolved there instead.
  // LABELLED, so `query()` can find it as well as the content walk.
  //
  // `_page-outbound` walks a vertebra's content at `#show: rookery` time to
  // build its backlink beacon, and that walk CANNOT ENTER A CONTEXT BLOCK —
  // the body does not exist until layout. So a `#window` emitted from inside
  // one announces itself to nobody, and every note it transcludes loses its
  // backlink from the page transcluding it. Not a corner case: any package
  // that computes which notes to window must do so inside a context, since
  // reading the registry needs one (`@rookery/todos`'s ready-view builder is
  // one such caller).
  //
  // The label costs nothing here and lets `_page-links` pick these up by
  // query instead. THE MARKER STAYS OUTSIDE THE CONTEXT BLOCK BELOW: that is
  // what lets `_page-links` resolve which page it sits on from the marker's
  // own location rather than from a read inside this context (see
  // `_page-links` for why the positional read is the one that converges).
  // `backlink` RIDES THE PAYLOAD; the element is emitted either way, and that
  // is not a detail to tidy later. THREE readers walk this marker and only two
  // of them are backlinks:
  //
  //   - `_outbound` (links.typ) — the NOTE-level graph. Respects `backlink`.
  //   - `_page-outbound`/`_page-links` (outline.typ) — the PAGE-level graph, by
  //     content walk and by `query` respectively. Both respect `backlink`.
  //   - `_cite-scan` (bib.typ) — which needs only the marker's PRESENCE, to know
  //     a nested window is going to CLAIM some of the enclosing note's
  //     citations and render them itself. It must keep seeing this marker
  //     whatever `backlink` says: its own comment records that scanning for the
  //     WK figure instead "missed every window and left the empty heading in
  //     place", because that figure is built inside a `context` and does not
  //     exist at scan time.
  //
  // So skipping the emission for `backlink: false` would silently break
  // citation partitioning in any note that cites anything and windows anything.
  //
  // `tagged`/`match` ride along too, unchanged from what this call received,
  // because a selector is plain data and `_page-links` can resolve it once the
  // registry is final. `filter` cannot: it is a function (asserted above), and
  // nothing this package puts in `metadata` is one, so only whether it was
  // given rides along, as `filtered`. `tagged`/`match` are ANDed with `filter`
  // (see below), so a filtered window shows a narrower set than its tags alone
  // would — `filtered: true` tells every reader that the tag selector on its
  // own now overclaims, and to resolve nothing rather than announce a wrong
  // backlink.
  [#metadata((
    rookery-window: ids,
    backlink: backlink,
    tagged: tagged,
    match: match,
    filtered: filter != none,
  )) <rookery-window-mark>]

  context {
  let reg = _registry.final()

  // Named ids first, in call-site order, and the only ones that can be wrong:
  // a tag scan reads the registry it filters, so it cannot name a missing note.
  //
  // EXCLUDED IS NOT MISSING: a note this build dropped for its tags (see
  // `_resolve-excluded`, base.typ) is deliberately absent, so a `#window` on
  // it renders NOTHING rather than failing the build. Filtered out of
  // `named` here, so nothing below — the sort, the tag merge, the rendering
  // — ever sees it.
  //
  // A TYPO STILL PANICS, message unchanged: `_excluded-ids` (state.typ) is
  // what tells the two apart, so a misspelt name fails loudly rather than
  // silently rendering nothing.
  //
  // The `@idea:x` MARKUP form CANNOT BE RESCUED — it is a Typst `ref` to a
  // label minted by the very `#idea` that got removed, a hard `label does
  // not exist` error neither this package nor rheo can intercept, so an
  // author routes links to a note that may be excluded through `#window`,
  // `#hyperlink` or `#idea-href` instead. Minting a hidden anchor/label to
  // keep such refs resolving is rejected for the same reason exclusion
  // exists: it would leak the excluded note's id into the public build's
  // HTML.
  let gone = _excluded-ids.final()
  let named = ids.map(n => _pfx() + n).filter(id => {
    if id in reg { return true }
    if id in gone { return false }
    panic("@rookery/core: #window unknown note '" + id + "'")
  })

  // Tag and filter matches minus anything already named — a note that is both
  // shows once, in the position the author named it.
  let tagged = if tagged == none and filter == none { () } else {
    let pred = _tag-pred(tagged, match, filter: filter)
    if pred == none { () } else {
      reg
        .pairs()
        .filter(((_, rec)) => pred(rec.at("tags", default: (:))))
        .map(((id, _)) => id)
        .filter(id => id not in named)
        .sorted()
    }
  }

  // `auto` keeps the author's own order for what they named and appends the
  // tag matches; naming a sort orders the whole selection instead.
  let full-ids = if sort == auto { named + tagged } else {
    _sort-ids(named + tagged, reg, sort)
  }

  // `display-bibliography` is a GROUP setting on `#window`, resolved once for
  // the whole call rather than per id: every rendered window shares the same
  // `display` dictionary, so there is one answer for the whole selection.
  // `auto` (the built-in and the document-wide default) changes nothing — each
  // window keeps rendering its own References block, exactly as
  // `_window-content` has always done. A concrete `true`/`false` instead
  // suppresses every per-window block (`refs: false` below) and replaces them
  // with one combined block after the last window, carrying every cited key
  // the group's windows claimed, de-duplicated — `true` shows it, `false`
  // still emits it (so a trailing citation has a bibliography to claim it) but
  // marks it for CSS to hide.
  let bib = _display-final(display, ("bibliography",)).at("bibliography")
  let combine-bib = bib != auto
  let bib-keys = ()

  for id in full-ids {
    let rec = reg.at(id)

    // THIS CALL SITE'S OWN BUDGET, resolved once: `auto` takes the
    // document-wide setting. Both the unfurl-0 branch below and `windows-claim`
    // need the number rather than `auto`, and reading it twice invited them to
    // disagree.
    let d = if unfurl == auto { _window-depth.final() } else { unfurl }

    // The marker an ENCLOSING `_flatten` reads when this window turns out to
    // be nested inside a transcluded body. It carries the presentation
    // arguments as well as the id, so the collapse-or-expand decision up
    // there can rebuild this exact window rather than a default one. NOT
    // `unfurl`, though — the budget belongs to the scope doing the expanding,
    // not to the call site being expanded.
    //
    // The key is `rookery-window-id`, not `rookery-window`: that name is
    // taken by the announce marker above, and `_outbound`/`_page-links` both
    // test for it by exact key on any dictionary-valued metadata they walk.
    let marker = metadata((
      rookery-window-id: id,
      folded: folded,
      display: display,
      foldable: foldable,
      reserve-title: reserve-title,
      limit: limit,
    ))

    // UNFURL 0 — A LINK, NOT A TRANSCLUSION. The note's title, linked to the
    // note's own page, and nothing else: no summary row, no `<details>`, no
    // body, so there is no `_window-content` on this path at all.
    //
    // It wears the row shape a minted page already gives a PAGE it names —
    // `.idea-page-list`/`.idea-page-row`, built by `.marrow.typ`'s `page-list`
    // for Context and for the page half of Backlinks — rather than a third row
    // style of its own: "a pointer to somewhere you can read this" is the same
    // kind of thing here as it is there, and the stylesheet already draws it
    // (the same left rule and indent a window gets, no box).
    //
    // `_resolve-dest` for the href, the same resolution `_permalink` and
    // `#hyperlink` use, so this link cannot disagree with them about where a
    // note lives: the minted page where there is one, and the note's in-context
    // label where there is not (plain `typst compile`, the combined PDF).
    // A TITLELESS note has no title to link, so the permalink IS the row — the
    // same `[idea:x]` an unfurl-exhausted nested window collapses to.
    //
    // `limit:` and `folded:` are simply inert here, not an error: a link has no
    // body to truncate and nothing to fold. Both still ride on `marker`, so an
    // enclosing `_flatten` that DOES have budget rebuilds the full window with
    // them intact — the budget belongs to the scope doing the expanding, and
    // that is as true of `unfurl: 0` as of any other value.
    if d <= 0 {
      let shape = _window-link(id, rec)
      _bracket(figure(kind: WK, supplement: none, [#marker#shape]), WK)
      continue
    }

    let body = _body-at(rec, depth: unfurl)
    let split = _truncate-split(body, limit)

    // Combining: accumulate this window's own keys the same way
    // `_window-content` would have, rather than rendering its block — the
    // group's one combined block (after the loop) claims them instead.
    if combine-bib {
      bib-keys += if split.rest == none {
        _own-cited-keys(split.shown, windows-claim: d > 1)
      } else {
        _own-cited-keys(split.shown + parbreak() + split.rest, windows-claim: d > 1)
      }
    }

    // Bracketed: the body being shown belongs to the note it came from, so
    // its links must not read as links from whatever page is showing it.
    _bracket(
      figure(kind: WK, supplement: none, [
        #marker#_window-content(id, rec, split.shown, folded, display, foldable: foldable, reserve-title: reserve-title, windows-claim: d > 1, rest: split.rest, refs: not combine-bib)
      ]),
      WK,
    )
  }

  // ONE block for the whole group, after the LAST window — not one of the
  // `figure(kind: WK)`s above, so it is never mistaken for a nested window's
  // own. Empty when the group cited nothing, the same as any other
  // `_refs-block` call. `bib` is a concrete bool here (`combine-bib` guards
  // it), so the attribute is always the true/false CSS keys its hide rule on,
  // never `auto`.
  if combine-bib {
    _refs-block(bib-keys.dedup(), card: (bib: bib, gutter: none), attrs: (data-rookery-bibliography: if bib { "on" } else { "off" }))
  }
  }
}

//   #context idea-body("etal")                 // -> content, or a panic
//   #context idea-body("etal", limit: 3)        // first three blocks
//
// The note's body as the REAL Typst-rendered thing — links, styling,
// footnotes, citations — not the plain string `#ideas()`'s `body` field
// gives out. For a consumer that wants to show the actual note rather than
// tell about it, the way `@rookery/search`'s preview pane does: a
// `body` string can be matched and excerpted, and that is exactly what it is
// for, but a code block inside it reads as bare, unstyled source text with
// no separation from the prose around it — MEASURED as "Typst markup peeking
// through" the moment a note quotes any code at all. Rendering the real
// content fixes that at the root: the browser gets an actual `<pre><code>`,
// not a paragraph that happens to contain one.
//
// NOT `#window`, despite doing almost the same rendering underneath. Two
// differences, both load-bearing:
//
//   1. `#window` ANNOUNCES the note it shows, up front, via the same
//      `metadata((rookery-window: ids))` marker `_outbound` reads at
//      REGISTRATION time to build the backlinks graph — a note shown in a
//      `#window` counts as a link TO it from wherever the window sits. That
//      is correct for a window written into a note's own prose, and
//      catastrophic for a call site meant to run once per note on EVERY
//      page, as a search preview does: every page on the site would end up
//      "linking" to every note in the whole rookery. `idea-body` skips the
//      announcement entirely — it renders, and nothing more.
//   2. `#window` draws chrome: a summary line (title, permalink, date) and a
//      `<details>` disclosure. `idea-body` is body only, always fully shown
//      — a caller wanting a title has it already, from whatever listed the
//      note in the first place (`#ideas()`'s `text` field, here).
//
// STILL `_bracket`ed, the same edges `#window` draws, for the same reason
// `#window` needs them: `_page-links` walks a page's own outbound links by
// COUNTING BRACKET DEPTH (see `_edge`), and unbracketed content here would
// make every link inside every previewed note look like a link the page
// itself wrote — corrupting the page-backlinks half of `.marrow.typ`'s
// Backlinks section for every page that calls this.
//
// Wrapped in `.idea-window`/`.idea-window-body` — the same classes
// `#window` wraps its own body in — so it inherits every rule core.css
// already writes for prose inside a window: link colours, raw/code styling,
// list and footnote layout. A consumer never has to restyle any of that
// itself. `_themed` carries the document's theme along as an inline style,
// the same way every other container this package emits does, since a
// caller's own container (rookery-search's hidden preview templates, say)
// has no `.idea-*` ancestor to inherit the custom properties from.
//
// `limit:` truncates by BLOCK — a paragraph, a list — the same unit
// `#window`'s own `limit:` uses, because that is the unit that can be cut
// without leaving half a sentence. `none` (the default) shows the whole
// body.
//
// `unfurl` is the same transclusion budget `#window` takes (see
// `_window-depth`); `1` (the default) renders the body with any nested
// `#window` collapsed to its permalink rather than unfurled, which keeps a
// preview's own size bounded regardless of how deep the note it is showing
// nests. PINNED rather than `auto` for that reason, and `1` rather than `0`
// because this function's job is to render a body: `@rookery/search`'s
// preview pane calls it without passing `unfurl` at all, and a default of 0
// would turn every search preview into a link. (`unfurl: 0` here renders the
// body all the same — there is no chrome and no link shape to fall back to,
// which is `#window`'s job; it simply asks for no unfurling, as `1` does.)
//
// HTML/EPUB only, like `#window`'s own chrome — its only realistic consumer
// is a web preview, and `html.elem` is what builds the `.idea-window`
// wrapping. On a paged target the body still renders, just without that
// wrapping, so a stray direct call does not hard-error.
//
// Supplies its own `context` — it reads `_registry.final()` internally — so,
// unlike `idea-tag-names`/`idea-tag-value`/`ideas`/`tag-data`, it needs none from its
// caller and can be called anywhere.
#let idea-body(name, unfurl: 1, limit: none) = context {
  // `#window` and `idea-body` take these same two parameters with the same
  // meaning, so their assert messages have to agree — see `#window`'s own
  // asserts for the reason `limit` requires `>= 1`.
  assert(
    unfurl == auto or (type(unfurl) == int and unfurl >= 0),
    message: "@rookery/core: #idea-body's `unfurl` must be auto or a "
      + "non-negative integer — got " + repr(unfurl),
  )
  _assert-limit(limit, "#idea-body's")
  let id = _pfx() + _norm(name)
  let reg = _registry.final()
  if id not in reg {
    // EXCLUDED IS NOT MISSING, as above: an excluded note renders as nothing;
    // a typo still panics.
    if id in _excluded-ids.final() { return [] }
    panic("@rookery/core: #idea-body unknown note '" + id + "'")
  }
  let rec = reg.at(id)
  let body = _body-at(rec, depth: unfurl)
  let shown = _truncate(body, limit)
  let inner = _footnoted(shown) + _refs-block(_own-cited-keys(shown, windows-claim: unfurl > 1))
  if _target() == "html" or _target() == "epub" {
    // `idea-window-plain`: this render has no chrome by design (no summary,
    // no disclosure), so it should not carry `.idea-window`'s BOX either —
    // the border, padding and hover tint that make sense around an actual
    // on-page `#window`, not around a body a caller is embedding inside a
    // box of its own. See core.css for why this needs a second class
    // rather than a downstream override. `data-rookery` stays "window" (every
    // generic window rule still applies); `data-rookery-plain` is the boolean
    // flag core.css keys the two box-suppressing overrides on.
    _bracket(
      html.elem(
        "div",
        attrs: _themed((class: _c("window") + " " + _c("window-plain"), data-rookery: "window", data-rookery-plain: "plain")),
        html.elem("div", attrs: (class: _c("window-body"), data-rookery: "window-body"), inner),
      ),
      WK,
    )
  } else {
    _bracket(align(start, block(inner)), WK)
  }
}
