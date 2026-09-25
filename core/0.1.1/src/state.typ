// The document-wide state this package publishes and reads back.
//
// One module because these share a discipline rather than a subject: each is a
// `state` (or a `counter`) written once by `#show: rookery` or by a note as it
// registers, and read everywhere else through `.final()`. The comments on the
// individual updates record which ones need the `_ =>` wrapper and why — that
// is the trap this grouping exists to keep in one place.
//
// Imports `base.typ` only.

#import "base.typ": *

//
// A note's id is `<prefix>:<name>`, `idea:` by default; `#show: rookery` (at
// the bottom of this file) changes it.
//
// The prefix is document-wide STATE rather than a parameter on `#idea`,
// because four separate places have to agree on it — `#idea` (minting the
// label), `#window` (looking one up), `_note-file` (deriving a minted page's
// slug from an id) and `.marrow.typ` (minting those pages) — and only
// `#idea`'s call site could ever pass an argument. One wrong reader and the
// id it builds simply does not exist.
//
// Read with `.final()`, NOT `.get()`. `#show: rookery` is applied per FILE
// (imports are per-file), so under rheo a spine sets the same prefix once per
// vertebra; a vertebra that forgot the template would, under `.get()`, mint
// `idea:` ids in the middle of an otherwise `note:` document, and a `#window`
// reaching across that boundary would panic on an id that was never
// registered. `.final()` collapses the whole document to ONE prefix (last
// writer wins), so every reader agrees no matter which file it sits in.
//
// EVERY caller of `_pfx` is therefore inside a `context` block already —
// `#idea`'s deferred body, `#window`, `_note-href` via `#idea`/`#window`/
// `#hyperlink`, and `.marrow.typ`'s own `#context`.
#let _prefix = state("rheo-idea-prefix", "idea")
#let _pfx() = _prefix.final() + ":"

// The minted-page directory: `idea-dir:` if the project set one, else `ideas`
// for the built-in `idea` prefix (the historical directory name, kept for
// every site that never touched `prefix:`), else the resolved prefix itself.
// NOT `prefix + "s"` — a project on `prefix: "maths"` gets `maths/`, not
// `mathss/`. Read with `.final()`, for the same reason as `_prefix` above.
#let _idea-dir = state("rheo-idea-dir", none)
#let _dir() = {
  let d = _idea-dir.final()
  if d != none { d } else if _prefix.final() == "idea" { "ideas" } else { _prefix.final() }
}

//
// `css-prefix:` if the project set one, else the resolved id `prefix` — so a
// project that renames `prefix` gets its classes renamed with it, and one that
// wants the id and the class to diverge sets `css-prefix` to pin the class
// stem independently. Read with `.final()`, for the same reason as `_prefix`.
//
// UNLIKE `_dir()`, there is no singular/plural special case: `idea-title`,
// `idea-tag-<t>` and every other class this package emits are already
// singular, so the built-in `idea` prefix yields exactly today's `idea-*`
// classes with nothing to special-case.
#let _css-prefix = state("rheo-idea-css-prefix", none)
#let _cls() = {
  let c = _css-prefix.final()
  if c != none { c } else { _prefix.final() }
}
// The shape every emit site wants: the bare stem for `idea`/`idea-box`, or
// `<stem>-<role>` for everything else, tag classes (`_c("tag-" + t)`) included.
#let _c(role) = if role == "" { _cls() } else { _cls() + "-" + role }

//
// THE SCALE COUNTS LEVELS OF TRANSCLUSION, AND `0` IS NOT THE DEFAULT:
//
//   0   transcludes NOTHING. A `#window` renders as the note's title linked to
//       the note's own page — no summary, no disclosure, no body (see
//       `#window`'s unfurl-0 branch).
//   1   the default, and today's behaviour: the note renders once, and a
//       `#window` found INSIDE it collapses to a bare permalink (`_flatten`'s
//       WK rule).
//   n   unfurls n-1 further levels of nested windows, collapsing at the nth.
//
// Expanding a nested window with no budget is what makes a cycle — a
// self-window, or A-windows-B/B-windows-A — re-expand forever, and the budget
// is what makes bounded expansion safe. So every comparison against a depth in
// this file asks `> 1`, never `> 0`: the question is always "may I unfurl a
// window found INSIDE this one", and one level of that budget is already spent
// on rendering the window itself.
//
// Document-wide state for the same reason `_prefix` is (`#show: rookery` is
// applied per FILE, and a note written in one vertebra can be windowed from
// another), read with `.final()` so every reader agrees. `#window`'s own
// `unfurl:` argument overrides it per call site.
#let _window-depth = state("rheo-idea-window-depth", 1)
//
// Configured on the template, taking Typst's own `#bibliography` arguments so
// there is nothing new to learn:
//
//   #show: rookery.with(bibliography: arguments(
//     bytes(read("refs.bib")),
//     style: "chicago-author-date",
//   ))
//
// BYTES, NOT A PATH, and it is not a stylistic choice. Typst resolves a path
// relative to the FILE THE CALL APPEARS IN, and every call this package makes
// appears inside the package: `bibliography("refs.bib")` spread in here looks
// for the file next to `lib.typ`, and so does `read`. MEASURED —
// `file not found (searched at .../core/0.1.1/src/refs.bib)`. `bytes` carries
// its data rather than a path, so the author's own `read()` resolves at the
// author's own call site and everything downstream just works. `bytes` is one
// of the source types Typst's own `#bibliography` accepts, so this is still
// literally its argument list.
//
// Document-wide state for the same reason `_prefix` is: `#show: rookery` is
// applied per FILE, and a note written in one vertebra can be windowed from
// another. Read with `.final()` so every reader agrees.
//
// Holds an `arguments` value or `none`, spread straight into `bibliography(..)`
// by the beads that render the blocks.
#let _bib = state("rheo-idea-bib", none)

// The key list of the configured bibliography, published once by
// `#show: rookery` so `_own-cited-keys` does not re-parse the whole source
// on every note, window and page. `none` means "not published" — a document
// that writes `_bib` directly (the unit fixture) still gets the answer from
// the fallback parse below.
#let _bib-key-cache = state("rheo-idea-bib-keys", none)

// Every key in the configured source, as an array of strings.
//
// A KEY-EXISTENCE CHECK, NOT A PARSER. It reads no author, no date and no
// title, and nothing downstream may depend on it for rendering — Typst formats
// every citation and every bibliography entry. Its ONLY job is answering "does
// this idea cite anything", so an idea that cites nothing emits no empty block.
// Growing this into a BibTeX parser is an explicit non-goal: the package reuses
// Typst's bibliography infrastructure rather than reimplementing it.
#let _bib-keys() = {
  let cached = _bib-key-cache.final()
  if cached != none { return cached }
  _bib-keys-of(_bib.final())
}
//
// `.marrow.typ` mints one standalone page per note, and those pages are
// separate `#document`s spliced in at the BUNDLE ROOT — outside every
// vertebra, and so outside whatever `#show:` the project applies to its own
// pages. A minted page therefore has no site chrome unless the project hands
// one over, which is what this is for:
//
//   #show: rookery.with(idea-page-template: my-idea-page)
//
//   #let my-idea-page(id: none, note: (:), doc) = {
//     show: chrome.with(current-page: id)
//     doc
//   }
//
// `.marrow.typ` calls it as `tpl(id: <id>, note: <registry record>, page)`,
// wrapping the whole minted page — heading, body and footer — so the template
// sees exactly what a vertebra's own `#show:` would.
//
// WHY A STATE HOLDING A FUNCTION, which nothing else in this package does:
// the project cannot reach `.marrow.typ` and `.marrow.typ` cannot reach the
// project. Marrow's text is inlined into rheo's synthesized bundle root, so a
// relative `#import "template.typ"` there would resolve against the PROJECT
// root and, worse, name a file only one particular project has. A state is
// the only channel that runs from a vertebra to the bundle root.
//
// Register a NAMED top-level function, not an inline closure built inside the
// template that installs it: a fresh closure per vertebra puts a different
// value on the state timeline for each one, and `.final()` is then whichever
// file happens to be last. A named binding is one value however many
// vertebrae reference it.
//
// `.update(_ => f)`, never `.update(f)` — `state.update` treats a FUNCTION
// argument as an updater to call on the old value, so the plain form would
// call the project's template with the old state as its only argument and
// store the result. The wrapper is what makes the function a value.
#let _idea-page-template = state("rheo-idea-page-template", none)

// Whether `.marrow.typ` should emit a `<feeds:item>` beacon alongside each
// minted note page — see the "syndicate" comment in `.marrow.typ` for the
// contract.
#let _syndicate = state("rheo-idea-syndicate", false)

// Whether `.marrow.typ` should mint an `ideas/index.html` landing page for the
// whole rookery.
//
// DEFAULT ON: `#rookery(..)` (template.typ) always publishes `index-page:
// true` unless a project overrides it. `#rookery(index-page: false)` turns it
// off — the call a project with its own index needs, since ohrg.org's
// homepage is a `#window(tagged: "post", ..)`, weeknotes' is the same, and
// neither wants a second index published under it. This state's own `false`
// initial value is only what a read sees before `#show: rookery` runs.
#let _index-page = state("rheo-idea-index-page", false)

// Whether `.marrow.typ` should render the Context section (a link back to
// the vertebra a note was written on) on each minted note page.
//
// DEFAULT ON, unlike `_index-page`: Context is how a reader who landed on a
// note's standalone page finds their way back to where it was written, and
// most projects want that by default.
//
// The binding is `_display-context` but the state key stays
// `rheo-idea-show-context`: the key is a runtime identifier shared across a
// compile, not a name a reader sees, so renaming it alongside the binding
// would be pure churn with a real chance of a silent mismatch.
#let _display-context = state("rheo-idea-show-context", true)

// Whether `.marrow.typ` should render the Backlinks section (every note and
// page that links here) on each minted note page. Same DEFAULT ON reasoning
// as `_display-context` above — this is the OTHER half of a minted page's
// navigational footer, not a separate feature with different defaults. Same
// binding/key naming split as `_display-context`, for the same reason.
#let _display-backlinks = state("rheo-idea-show-backlinks", true)

// Whether this vertebra harvests the backlink graph at all — each note's
// outbound links at registration and the page's own links. `false` is
// `rookery.with(backlinks: false)`: nothing is harvested, so `.marrow.typ`
// has nothing to invert and no minted page gets a Backlinks section.
// Stronger than `_display-backlinks`, which only hides the section.
#let _backlinks = state("rheo-idea-backlinks", true)

// Whether `.marrow.typ` should print the authored title as the `<h1>` on a
// note's own minted page. Same DEFAULT ON reasoning as
// `_display-context`/`_display-backlinks` above. Same binding/key naming
// split, for the same reason.
//
// MINTED PAGE ONLY. A `#window` summary, an `@ref` and an outline row all
// still call the note by its title (or derived label) regardless of this
// setting — this exists for a page whose own metadata already names the
// note (a reading, a session title) and does not want it repeated as a
// heading.
#let _display-title = state("rheo-idea-show-title", true)

// Whether `#idea`'s card and `#window`'s summary render a note's stored
// date, its tag pills, its box frame, and its permalink id — plus, on
// `#window` only, its derived label and its hover background. Same
// binding/key naming split as `_display-context` above. Centralising the
// built-in default here, rather than in `#idea`/`#window` themselves, is
// what lets `rookery(..)` set it once for the whole document instead of at
// every call site. The values match what `#idea`/`#window` always applied:
// only `date` and `tags` start off.
#let _display-background = state("rheo-idea-show-background", true)
#let _display-date = state("rheo-idea-show-date", false)
#let _display-frame = state("rheo-idea-show-frame", true)
#let _display-name = state("rheo-idea-show-name", true)
#let _display-label = state("rheo-idea-show-label", true)
#let _display-tags = state("rheo-idea-show-tags", false)

// `auto`, not a built-in boolean default: unlike every other display key,
// `right-gutter`'s `auto` is a real outcome, not a placeholder for one —
// it means "split only when the card holds a note", decided in CSS
// (`:has()`) rather than resolved to a boolean here. So the document-wide
// default `rookery(display-right-gutter:)` sets stays `auto` unless the
// project overrides it outright, and `_display-final` below is allowed to
// hand back `auto` for this one key.
#let _display-right-gutter = state("rheo-idea-show-right-gutter", auto)

// `bibliography`'s `auto` is a real outcome too, for the same reason:
// "follow the citations mode" (vertical shows References, horizontal
// hides it) is decided in CSS, not resolved to a boolean here.
#let _display-bibliography = state("rheo-idea-show-bibliography", auto)

// Every display key mapped to its own document-wide state, for
// `_display-final` below — one table instead of a chain of per-key
// comparisons at each call site.
#let _DISPLAY-STATES = (
  "context": _display-context,
  backlinks: _display-backlinks,
  background: _display-background,
  date: _display-date,
  frame: _display-frame,
  name: _display-name,
  label: _display-label,
  tags: _display-tags,
  title: _display-title,
  "right-gutter": _display-right-gutter,
  "bibliography": _display-bibliography,
)

// Resolves `auto` in an already-merged `display` dictionary (`_resolve-display`,
// pure.typ) against document-wide state, for exactly the keys named. Used at
// the point `#idea`'s card, `#window`'s summary, or a transcluded/minted
// card actually renders — rather than at registration — so what shows
// depends on the document's setting AT RENDER TIME, not on whatever it was
// when the note was written. A key `display` does not carry at all (a
// payload minted before that key existed) resolves the same way `auto`
// does, which is what lets an old payload fall back to today's document-wide
// setting rather than a value frozen at some earlier built-in default.
//
// Must be called inside a `context` block: every state read is `.final()`.
#let _display-final(display, keys) = {
  let r = (:)
  for k in keys {
    let v = display.at(k, default: auto)
    r.insert(k, if v == auto { _DISPLAY-STATES.at(k).final() } else { v })
  }
  r
}

// How `.marrow.typ` should NAME a vertebra in the Context and Backlinks
// sections of a minted note page.
//
//   "title"  rheo's own spine title for the page (the default)
//   "path"   the page's source path, content dir and extension dropped:
//            `digitaltheory/index`, `jobs/cfps`, `institutions`
//
// WHY "path" IS ON OFFER. rheo derives a spine title from the FILE STEM, so in
// a project with a page per directory every `index.typ` is titled "Index" and
// every `cfps.typ` is "Cfps" — while Context exists precisely to answer "where
// was this note written". That answer arrives identical for dozens of
// different pages. A path is longer and less pretty; it is also unique by
// construction.
//
// A PROJECT-LEVEL CHOICE, not a per-note one: this is document-wide state and
// marrow reads `.final()`, so the last vertebra to apply the template settles
// it for every minted page. A project wanting both would be asking one note's
// footer to disagree with another's about what a page is called.
#let _page-titles = state("rheo-idea-page-titles", "title")

// "vertical" (a Footnotes block under each idea) or "horizontal" (margin
// notes beside the text, HTML only). A PROJECT-LEVEL CHOICE for the same
// reason as `_page-titles` above: read with `.final()`, so the last vertebra
// to apply the template settles it for every rendering, marrow's minted pages
// included.
#let _footnote-mode = state("rheo-idea-footnote-mode", "vertical")

// "vertical" or "horizontal" for `@key`/`#cite` markers, same shape and same
// reason as `_footnote-mode` above — `citations: auto` (template.typ)
// resolves to `_footnote-mode`'s own value before this is published, so the
// two only disagree when a project sets `citations:` explicitly.
#let _citation-mode = state("rheo-idea-citation-mode", "vertical")

//
//   #show: rookery.with(invisible-tags: ("private",))
//
// The complement to `exclude-tags` (see `_resolve-excluded`, base.typ), for a
// tag used at the BUILD level rather than as a label a reader should ever see.
//
// THE CASE THIS EXISTS FOR. A project has a `protected` tag (kept out of the
// public build) and a `private` tag (also kept out, but authorial — private
// notes must not be distinguishable from protected ones anywhere). `protected`
// KEEPS its pill, because in the dev build it tells the author something.
// `private` goes here, so there is no `private` pill and no `idea-tag-private`
// class in any build.
//
// SUPPRESSES BOTH THE PILL AND THE CLASS: the pill in a card's hat, a window
// summary's hat and a minted note page's hat; the `idea-tag-<tag>` class on the
// heading, the card, a transcluded card and an `ideas/index.html` row; and the
// generated `.idea-tag-<tag>` rule a `theme: (tags-color: ..)` entry would
// otherwise emit for it (`_tags-color-rules`, theme.typ). The tag name is then
// absent from the HTML altogether, which is the point — a class alone is enough
// to tell a reader the tag is there.
//
// DOES NOT TOUCH FILTERING, and must not: `idea-tag-names`, `idea-tag-value`, `tag-data`,
// `ideas(tagged:, match:)` and `#window(tagged: ..)` all still see an invisible tag,
// and so does `@rookery/search`'s index and tag query. That is what makes
// an invisible tag usable as an exclusion key at all — the two features compose
// precisely because this one is presentation-only.
//
// WHY THIS ONE MAY BE A `rookery.with()` STATE WHILE `exclude-tags` MAY NOT.
// Every site listed above already runs inside a `#context` block, so `.final()`
// is available with no restructuring. `exclude-tags` has to be readable with NO
// context, because its gate sits above the `figure(kind: IK)` marker that five
// structural walks depend on (see `#idea`'s gate). The asymmetry is deliberate
// — do not "unify" the two onto one surface.
#let _invisible-tags = state("rheo-idea-invisible-tags", ())

// Tag names minus the invisible ones.
//
// ONE HELPER FOR EVERY SITE, deliberately: the pill a note wears, the
// `idea-tag-<tag>` class it carries and the generated CSS rule for that class
// must never disagree about what is invisible, and a second copy of
// `t not in hidden` is how they would come to.
//
// DEFINED IN THIS FILE rather than beside its first caller, because the callers
// span the module graph — `theme.typ`'s `_tags-color-rules`, `permalink.typ`'s
// `_permalink-tab`, `idea.typ`, `transclusion.typ` and `.marrow.typ` — and
// `state.typ` is imported before all of them. A `#let` closure captures the
// scope visible AT DEFINITION time, so anywhere later would be invisible to
// something.
//
// Needs `#context`: it reads `_invisible-tags.final()`. Every caller is already
// inside one, which is the property that lets this be a state at all.
#let _visible-tags(names) = {
  let hidden = _invisible-tags.final()
  names.filter(t => t not in hidden)
}
//
// `#idea[body]`, `#idea("name")[body]`, and `#idea(<name>)[body]` all work via
// an argument sink, since `#idea[body]` passes body as the first positional
// argument. A named note is pinned to `<prefix>:<name>` outright. An unnamed
// note with a title mints the slug of that title. An unnamed note with no
// title (or a title too bare to slug) mints a slug of its own BODY instead,
// suffixed with a short digest so two notes with the same opening words
// still land on different ids — see `idea.typ`'s main mint for the full
// ladder. Either way the note gets: an `idea:<id>` Typst label on a hidden
// referenceable anchor, an HTML heading (only when `title` is given)
// carrying that id and an `idea`/`idea-tag-<tag>` class list, and a
// registry entry other beads (#window, #hyperlink) read from.
#let _registry = state("rheo-ideas", (:))

//
// A title-derived slug that collides with an earlier one gets a numeric
// `-<n>` suffix, counted in document order, and this dict is what counts it:
// slug string to the OCCUPANTS that
// have taken it so far, each an `occupant` value describing the note that
// took a slot (see `idea.typ`'s main mint for what one holds). A PINNED id
// (`#idea(<name>, ..)`) never touches this state at all — see `idea.typ`'s
// main mint, where `slug` is `none` whenever `named` is true — so two pinned
// notes sharing a name still panic exactly as before.
//
// SLUG TO A LIST OF OCCUPANTS, not slug to a bare count: a note's body is
// re-laid-out wherever `@rookery/core`'s own transclusion places it — a
// `#window`, a minted page, a nested `_flatten` — and each of those
// placements re-runs this same mint block for the SAME note. A bare counter
// cannot tell that replay apart from a genuinely new colliding note, so it
// counted every replay as one more occupant and handed the replayed note a
// fresh, ever-growing suffix — MEASURED on a real site: a single untitled
// dated meeting, transcluded from more than one page, gained a `-2` it had
// not earned, and the number kept climbing across compile attempts as
// Typst's own convergence loop replayed it again. A list of occupants fixes
// this by recording WHO holds each slot: `_slug-peek` finds this note's own
// prior slot before minting a new one, and `_slug-record` appends only when
// this note is not already in the list — so replaying a note any number of
// times leaves it in the SAME slot it first took.
#let _slug-count = state("rookery-idea-slug-count", (:))

// Split into a peek and a record, because `_slug-count.update()`'s return
// value is CONTENT that has to join whatever the caller is placing, never a
// plain value bound alongside `id`, so a single function cannot both hand
// back a number AND perform the write.
//
// `_slug-peek(slug, occupant)` counts from 1 — the note asking is always the
// Nth to want this slug, so `n == 1` mints bare and `n > 1` mints `-<n>`.
// `occupant` is checked against every occupant already recorded under this
// slug: a match returns THAT occupant's own position (1-based), unearned by
// a replay, and no match returns the next free position, exactly as a first
// arrival always has. `occupant` must be a plain value built from what the
// note IS — never from where or when it is being rendered — or a replay
// would fail to match its own earlier occupant and this fix would not hold.
//
// Typst content equality cannot tell two occupants holding perfectly
// identical values apart from one occupant seen twice (`.position()` finds
// the first match either way) — so two notes sharing a title AND every field
// `occupant` carries collapse onto the same slot instead of minting a second
// one. Accepted: nothing about such a pair distinguishes them to a reader
// either, and the alternative — falling back to document position to tell
// them apart — is the exact instability this rewrite removes.
#let _slug-peek(slug, occupant) = {
  let occupants = _slug-count.get().at(slug, default: ())
  let i = occupants.position(o => o == occupant)
  if i == none { occupants.len() + 1 } else { i + 1 }
}

// Pure function of ITS OWN ARGUMENTS ONLY (`s` and `occupant`), never of the
// `n` `_slug-peek` already read from a separate, earlier `.get()` —
// MEASURED: an updater that closes over a value read from the same state a
// moment earlier costs one more Typst compile attempt per note sharing the
// key before the state converges; rederiving the position from `s` itself
// costs none, however many notes share one slug.
//
// Appends `occupant` only when it is not already on this slug's list —
// idempotent per note, so a note replayed any number of times still
// contributes exactly one occupant and keeps the slot `_slug-peek` first
// handed it.
#let _slug-record(slug, occupant) = {
  _slug-count.update(s => {
    let occupants = s.at(slug, default: ())
    if occupants.any(o => o == occupant) {
      s
    } else {
      s.insert(slug, occupants + (occupant,))
      s
    }
  })
}

//
// Every NAMED note `#idea`'s exclusion gate dropped from this build, as a plain
// ARRAY OF STRINGS of full ids — no bodies, titles, tags or dates, which is
// what keeps an excluded note genuinely free rather than merely invisible.
// See `_resolve-excluded` (base.typ) for what excludes a note and why.
//
// ITS ONLY JOB is telling a consumer a note the build removed on purpose from
// one that never existed: `#window`, `#hyperlink` and `#idea-body` otherwise
// treat both identically and panic `unknown note`, so this lets them render
// nothing (or the bare id) for an excluded target while a genuine typo still
// panics.
//
// UNNAMED NOTES ARE NOT HERE, and cannot be: an auto-numbered note has no id
// anything could name it by.
//
// Read with `.final()`, like `_registry` and `_prefix` above and for the same
// reason: a note may be excluded in one file and linked from another.
#let _excluded-ids = state("rheo-ideas-excluded", ())

// Stepped ONCE per rendered idea box. It exists only so two renderings of the
// SAME body on one output page (its own `#idea`, plus a `#window` on it) get
// distinct HTML ids. Document-wide and monotonic — uniqueness within a page is
// all that is asked of it, so it never resets.
#let _fn-block = counter("rheo-idea-fn-block")

// There is no counter of any kind for the visible footnote number: it is not
// a position in a laid-out document, only a position within one body's own
// footnotes, which is already known the moment that body is in hand — see
// `_footnoted` (bib.typ) and `_number-footnotes` (pure.typ), which decide it
// there, once, rather than through a `context`-gated read.

// The inline reference. `b` is this rendering's block number, `n` the
// footnote's number within it; together they name both anchors.
#let _fn-ref(b, n) = {
  let tag = str(b) + "-" + str(n)
  if _target() == "html" or _target() == "epub" {
    html.elem(
      "sup",
      attrs: (class: _c("fn-ref"), id: "fnref-" + tag, data-rookery: "fn-ref"),
      html.elem("a", attrs: (href: "#fn-" + tag), str(n)),
    )
  } else {
    super(str(n))
  }
}

// The margin note beside a footnote marker, emitted alongside
// `_fn-block-html` (bib.typ) rather than instead of it — core.css decides
// which of the two a reader sees. Its id is prefixed `sn-`, not `fn-`: the
// bottom block's own `<li>` keeps `id="fn-{tag}"`, and the two must stay
// distinct since both are always in the document. A `span`, not a `div`: it
// is placed inline, inside the paragraph the marker sits in, and CSS
// `float`s it into the margin from there.
// `refs` names the works a citation INSIDE this footnote's own body cites
// (`_footnote-cite-keys`, bib.typ) — its citation marker already sits
// mid-sentence in `body`, so CSS cannot move it to the note's end, and this
// appends the full references there instead. Emitted whenever `refs` is
// non-empty, in every mode: core.css decides whether a reader sees it.
#let _fn-side(b, n, body, refs: ()) = {
  let tag = str(b) + "-" + str(n)
  let refs-block = if refs.len() == 0 { [] } else {
    html.elem(
      "span",
      attrs: (class: _c("sidenote-refs"), data-rookery: "sidenote-refs"),
      refs
        .map(k => html.elem("span", attrs: (data-rookery: "sidenote-ref"), cite(label(k), form: "full")))
        .join(),
    )
  }
  html.elem(
    "span",
    attrs: (class: _c("sidenote"), id: "sn-" + tag, data-rookery: "sidenote"),
    html.elem("span", attrs: (class: _c("sidenote-number"), data-rookery: "sidenote-number"), str(n))
      + [ ]
      + body
      + refs-block,
  )
}

// The block itself, at the end of the idea's body. Empty content when there is
// nothing to list: an idea with no footnotes emits no block and no heading.
#let _fn-block-html(notes, b) = {
  if notes.len() == 0 { return [] }
  if _target() == "html" or _target() == "epub" {
    html.elem(
      "div",
      attrs: (class: _c("footnotes"), data-rookery: "footnotes"),
      html.elem("h4", attrs: (class: _c("footnotes-title"), data-rookery: "footnotes-title"), [Footnotes])
        + html.elem(
          "ol",
          attrs: (class: _c("footnote-list"), data-rookery: "footnote-list"),
          notes
            .enumerate()
            .map(((i, body)) => {
              let tag = str(b) + "-" + str(i + 1)
              html.elem(
                "li",
                attrs: (class: _c("footnote"), id: "fn-" + tag, data-rookery: "footnote"),
                html.elem(
                  "a",
                  attrs: (class: _c("fn-backlink"), href: "#fnref-" + tag, data-rookery: "fn-backlink"),
                  "^",
                )
                  + " "
                  + body,
              )
            })
            .join(),
        ),
    )
  } else {
    // Paged target: no ids and no anchors, neither of which means anything in
    // a PDF. The block still renders, so an idea reads the same everywhere.
    [*Footnotes*] + enum(..notes)
  }
}
