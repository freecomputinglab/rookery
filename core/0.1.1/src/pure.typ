// rookery — the PURE half: functions of their arguments and nothing else.
//
// What belongs here: a helper whose whole answer comes from what it is handed
// — a string, a content tree, an array. NO `state`, no `context`, no `query`,
// no `sys.inputs`, no target detection, no page handle, no prefix, no theme,
// no registry, no bibliography. Nothing in this file reads document state.
//
// What does NOT belong here: everything that does. Those helpers stay in
// `lib.typ`, whose ORDERING IS LOAD-BEARING — a `#let` closure captures the
// scope visible AT DEFINITION time — which is precisely the constraint this
// file's contents do not participate in.
//
// `lib.typ` re-exports every name here (`#import "pure.typ": *`), so the
// underscore-private ones stay importable from `"@rookery/core:0.1.1"` by
// name — `test/units.typ` imports twelve of them that way, and `.marrow.typ`
// imports seventeen of `lib.typ`'s own internals on the same footing.
//
// Order still matters WITHIN this file, for the same definition-time-capture
// reason: `_INLINE-FUNCS` -> `_is-inline` -> `_blocks` -> `_truncate`,
// `_join` -> `_body-text` -> `_body-plain` -> `_derived-title` -> `_rec-label`,
// and `IK`/`WK` above both footnote walkers.
//
// `_std-footnotes`'s `footnote` is TYPST'S BUILT-IN, deliberately: rookery
// defines its own `#footnote` far down in `lib.typ` and nothing here shadows
// the name. Do not import rookery's `footnote` into this file.

// Normalise a name (string or Typst label) to its bare string form, with no
// prefix. Strips a leading "prefix:" when present, so the bare form
// ("etal", <etal>) and the full id ("idea:etal", <idea:etal> — the same id
// `@idea:etal` resolves) name the same note either way: whichever is closer
// to hand — a fresh name to pin, or a full id copied from elsewhere — just
// works. Shared by `#idea` (pinning an explicit id), `#window` (looking one
// up), and `#hyperlink` (linking to one). Defined before the registry below
// because `hyperlink` needs both and must come before `_flatten`, which
// installs it as a `show ref:` rule.
#let _norm(name) = {
  let s = if type(name) == label { str(name) } else { name }
  let i = s.position(":")
  if i == none { s } else { s.slice(i + 1) }
}

// The `data-rookery-tags` attrs entry for a list of visible tag names, or an
// empty dictionary when there are none — the same emptiness the `idea-tag-<tag>`
// class list already degrades to. Shared by every site that builds both a tag
// class list and this attribute, so the two cannot disagree about which tags
// are on the element.
#let _tags-attr(names) = if names.len() == 0 { (:) } else { (data-rookery-tags: names.join(" ")) }

// The tag store is a DICTIONARY: keys are tag names, values are
// arbitrary Typst values, and a plain tag is one whose value is `none`. This is
// what lets a tag carry metadata — `(depends-on: ("a", "b"))` — instead of only
// naming itself, and it is the primitive `@rookery/todos` and
// `@rookery/timeline` build on.
//
// Four author-facing forms all land here and all normalize to that one shape,
// so nothing downstream has to ask which was written:
//
//   none            -> (:)
//   "draft"         -> (draft: none)
//   ("a", "b")      -> (a: none, b: none)
//   (a: 1, b: none) -> unchanged
//
// `("a", "b")` and `(a: none, b: none)` are therefore THE SAME registry record,
// which matters at `idea.typ`'s duplicate-id check: two pins of one id written
// in different forms must not read as a collision.
//
// Defined above BOTH its callers — `_tag-pred` just below and `_dedup-tag`
// further down — because a `#let` closure captures the scope visible AT
// DEFINITION time, so a helper defined after a caller is invisible to it.
#let _norm-tags(v) = {
  if v == none {
    (:)
  } else if type(v) == str {
    ((v): none)
  } else if type(v) == dictionary {
    v
  } else {
    v.fold((:), (d, t) => { d.insert(t, none); d })
  }
}

// A `sys.inputs` value is ALWAYS a string — Typst's own contract for
// `--input key=value`, not a choice this package made — so a LIST of tags
// arrives as one string and has to be split somewhere.
//
// COMMAS AND/OR WHITESPACE, in any mixture, because
// `--input rookery-exclude="private, protected"` and
// `--input rookery-exclude=private,protected` mean the same thing and neither
// caller should have to know which spelling this package parses.
//
// The `.filter(t => t != "")` is what makes a trailing comma, a doubled
// separator, a leading space and the empty string all harmless: an empty value
// means "no tags", never "one tag whose name is the empty string" — which would
// otherwise be a tag no note can carry and every note could be tested against.
//
// PURE, hence its place in this file: string in, array out, no `sys.inputs` and
// no state. The READ that feeds it is `_input-tags` in `base.typ`, where every
// read of that dictionary already lives.
#let _split-tag-list(s) = {
  if s == none { return () }
  s.split(regex("[,\\s]+")).filter(t => t != "")
}

// `tags` is `none`, a single string, an array of strings, or a dictionary —
// the same four forms `#idea` takes; `match` is "any" (the default) or "all".
// Returns a predicate over a note's own tag DICTIONARY, or `none` when there is
// nothing to filter by. An EMPTY `tags` is no filter at all rather than a
// filter matching nothing — asking for none of the tags is not the same as
// asking for a tag no note has.
//
// `filter` is a caller's OWN predicate over the same tag dict, ANDed with the
// `tags`/`match` one — both must hold, never either. NAMED and defaulting to
// `none`, offered by all three callers (`#window`, `ideas()`,
// `#ideas-outline`), because `tagged:`/`match:` can say "any of these" and "all
// of these" and nothing else. It cannot say `phd` but NOT `draft`, nor
// `(phd AND draft) OR todo`. Keyword parameters for those would be a filter
// language grown one special case at a time — `exclude:`, then
// `any-of:`/`all-of:`, then nested-array groups — and a Typst function value
// already IS that language, in the caller's hands.
//
// The predicate sees the TAG DICTIONARY and nothing else: no title, no id, no
// depth. Those are not tag filtering, and handing over a whole outline entry
// would make the entry's shape a public contract this package then has to keep.
//
// THE DICT, not an array of names — that is what lets a project filter on a
// tag's VALUE rather than only on its presence:
//
//   filter: t => t.at("priority", default: 4) <= 1
//
// A `filter:` predicate is therefore handed the tag DICTIONARY: `t => "phd" in
// t` tests dictionary KEYS, but `t.map(..)`, `t.any(..)`, `t.all(..)` and
// `t.at(0)` are not available on it — a dictionary has no `.any`/`.all` at
// all, and its `.at` takes a key, not an index.
//
// Still `none` when neither is set, and that matters — it is what lets
// `_prune-outline` skip its walk entirely for an unfiltered outline. Do not
// replace it with an always-true closure.
//
// Defined HERE, above every caller, rather than beside the first one to want
// it: a `#let` closure captures the scope visible AT DEFINITION time, so a
// helper defined further down is invisible to `#window`. `_blocks` carries the
// same note for the same reason. `#ideas-outline`'s tag filter reuses this —
// do not define a second copy next to it.
#let _tag-pred(tags, match, filter: none) = {
  let by-tags = if tags == none { none } else {
    // `.keys()`, and it is load-bearing rather than cosmetic. `_assert-tags`
    // now also accepts a dictionary, so `#window(tagged: (draft: none))` reaches
    // here with `want` a dict — and MEASURED, a typst dictionary has no `.any`
    // and no `.all`, so the two branches below would hard-error with
    // "type dictionary has no method any". `_norm-tags` folds str, array and
    // dict onto one shape and `.keys()` takes the names off it.
    let want = _norm-tags(tags).keys()
    if want.len() == 0 { none } else if match == "all" {
      t => want.all(x => x in t)
    } else {
      t => want.any(x => x in t)
    }
  }
  if by-tags == none and filter == none { none } else if filter == none {
    by-tags
  } else if by-tags == none {
    filter
  } else {
    t => by-tags(t) and filter(t)
  }
}

// ONE `../` per `:` level of the CURRENT page's handle, mirroring rheo's own
// cross-vertebra link rule. Shared by `_note-href` and `_page-href` so a note
// href and a page href cannot disagree about depth.
#let _rel-prefix(handle) = {
  let depth = handle.split(":").len() - 1
  if depth == 0 { "" } else { range(depth).map(x => "../").join() }
}

// Every key in `cfg` (an `arguments` value shaped like `_bib`'s content, or
// `none`), as an array of strings. Pure function of its argument so
// `#show: rookery` can publish the result once instead of every caller
// re-parsing the source.
// The BibTeX entry-header pattern `_bib-keys-of` matches against — bound
// once rather than rebuilt per bibliography source.
#let _BIB-ENTRY-RE = regex("@\\w+\\s*\\{\\s*([^,\\s]+)\\s*,")

#let _bib-keys-of(cfg) = {
  if cfg == none { return () }
  let src = cfg.pos().first()
  let sources = if type(src) == array { src } else { (src,) }
  let keys = ()
  for s in sources {
    let text = str(s)
    // Format is detected from the CONTENT, since bytes carry no filename. A
    // Hayagriva file is a YAML mapping and has no `@type{` entry headers; a
    // BibTeX file is nothing but those.
    let entries = text.matches(_BIB-ENTRY-RE)
    if entries.len() > 0 {
      keys += entries.map(m => m.captures.first())
    } else {
      keys += yaml(s).keys()
    }
  }
  keys
}

// Prepends `tag`, unless the caller already passed it — a project's own
// `todo("x", tags: ("todo",))` must yield `(todo: none)`, not the tag twice,
// or the heading gets a duplicated CSS class. Defined before
// `_merge-base-tags` that calls it: a
// `#let` closure captures the scope visible AT DEFINITION time, so a forward
// reference to a not-yet-defined name fails at call time.
//
// `tags` is normalized here, not left to `#idea`'s own coercion: a wrapper
// calls this BEFORE `tags` ever reaches `#idea`, so a bare `tags: "draft"`
// would otherwise hit `tag in tags` as a SUBSTRING test rather than a key test.
//
// THE ORDER OF THE TWO BRANCHES IS LOAD-BEARING. MEASURED: dictionary `+`
// merges with the RIGHT side winning on a key collision, so an unconditional
// `((tag): value) + tags` would clobber a caller's own value for this tag with
// the default. The "already a key" guard therefore comes FIRST, and that guard
// is exactly the mechanism by which a caller supplies a value for the wrapper's
// own tag: a project's own `todo("x", tags: (todo: (state: "open")))` keeps
// `(state: "open")`. A caller's value wins OUTRIGHT — there is no deep merge.
//
// `value:` is the default `_merge-base-tags` passes for a key bound in a
// dictionary `base-tags:`. It only applies when the caller did not name the
// tag at all.
#let _dedup-tag(tag, tags, value: none) = {
  let tags = _norm-tags(tags)
  if tag in tags { tags } else { ((tag): value) + tags }
}

// The merge behind `#idea`'s `tag:` and `base-tags:`: `base` folds UNDER
// `tags`, so a key both sides name keeps the caller's value — `_dedup-tag`'s
// "already a key" guard is what decides that, which is why the higher side
// wins outright rather than deep-merging. The `.rev()` is there so keys come
// out in the order the constructor named them: `_dedup-tag` prepends, so the
// last one folded ends up first.
//
// It NESTS rather than taking a third argument, which is how `#idea` gets
// its three-way `tags:`/`base-tags:`/`tag:` precedence: the result of one
// call is the `tags` a second call folds under.
#let _merge-base-tags(base, tags) = {
  let base = _norm-tags(base)
  base.keys().rev().fold(
    _norm-tags(tags),
    (acc, t) => _dedup-tag(t, acc, value: base.at(t)),
  )
}

// "lexicographic" is by full id, the same order `ideas()` publishes. "date" is
// newest `created` first, undated notes last, ties broken by ASCENDING id.
//
// Built by grouping rather than by sorting twice: typst does not document
// `array.sorted` as stable, so a sort-by-id-then-sort-by-date pipeline cannot
// be relied on to keep the id order within a date. Dates are compared as
// zero-padded `[year][month][day]` strings, which sidesteps the question of
// how `datetime` orders as a sort key at all.
#let _sort-ids(ids, reg, sort) = {
  let by-id = ids.sorted()
  if sort != "date" { return by-id }
  // One `display()` per id: formatting the datetime is the cost here, and
  // grouping by date would otherwise redo it once per id per distinct date.
  let stamp-of(id) = {
    let m = reg.at(id).at("created", default: none)
    if m == none { none } else { m.display("[year][month][day]") }
  }
  let buckets = (:)
  let undated = ()
  for id in by-id {
    let s = stamp-of(id)
    if s == none { undated.push(id) } else {
      buckets.insert(s, buckets.at(s, default: ()) + (id,))
    }
  }
  // Each bucket is already id-ascending — `by-id` is, and appending keeps it —
  // so a date-descending walk of the keys yields id-ascending ties.
  let ordered = ()
  for s in buckets.keys().sorted().rev() { ordered += buckets.at(s) }
  ordered + undated
}

// Rebuilds a nested list from the flat `(depth, title, loc)` sequence above
// — a standard depth-tagged-list-to-tree pass. `wrap` builds ONE level's
// list container (`html.elem("ul", ..., ..)` or Typst's own `list`); `item`
// wraps one entry's own content plus its (possibly none) nested sublist.
// Shared by both targets so the tree-walk itself cannot drift between them.
//
// `wrap` is called as `wrap(items, root)`, `root` being true for the OUTERMOST
// list only. The theme's custom properties have to go on that one and inherit
// down: an outline is page-level chrome, a sibling of the notes rather than a
// descendant of any of them, so unlike everything else this package emits it
// has no `.idea-box`/`.idea-window` ancestor to inherit from. Putting them on
// every level instead would re-declare the same values once per nesting depth.
#let _nest-outline(entries, wrap, item) = {
  let build(entries, root: false) = {
    let items = ()
    let i = 0
    while i < entries.len() {
      let base = entries.at(i).depth
      let children = ()
      let j = i + 1
      while j < entries.len() and entries.at(j).depth > base {
        children.push(entries.at(j))
        j += 1
      }
      let sub = if children.len() == 0 { none } else { build(children) }
      items.push(item(entries.at(i), sub))
      i = j
    }
    wrap(items, root)
  }
  build(entries, root: true)
}

// Plain text of a title, for `ideas()`. Typst has no built-in
// content-to-string, so this walks the usual constructors: anything carrying
// `.text` (a `text` element, and also `raw`), a space element standing for
// " ", a sequence's `.children`, and anything else with a `.body` (strong,
// emph, link, ...) recursed into. Unknown leaves contribute nothing rather
// than erroring — a title is matched on, not rendered from, here.
//
// The `.has("text")` branch is deliberately broader than `c.func() == text`:
// MEASURED, a title like [The `#window` marker] flattened to "The  marker"
// under the narrow test, because `raw` carries `.text` and has neither
// children nor a body — silently making that note unfindable by the word in
// its own title. A math equation still contributes nothing.
//
// A `ref` IS THE ONE LEAF A CALLER CAN DECIDE FOR ITSELF, through `resolve`.
// It has no `.text`, no `.children` and no `.body`, so a title that names
// another note — [Meeting with #ref(<idea:x>)] — has nothing here to walk
// into: what a reference is worth in plain text is the NAME OF ITS TARGET,
// and only a caller holding the registry knows that. `_plain` below passes
// the pure answer, `_ => ""`, for a caller with no registry to resolve
// against; `ideas()` passes one that reads the target's own label.
#let _plain-with(c, resolve) = {
  if c == none { "" } else if type(c) == str { c } else if type(c) != content {
    ""
  } else if c.func() == ref { resolve(c)
  } else if c.has("text") { c.text
  } else if c.func() == smartquote {
    // `smartquote` is its own element with no `text`, `children` or `body`, so
    // it needs its own branch or every apostrophe and quotation mark in a
    // title vanishes from a note's plain text.
    //
    // ASCII, NOT THE CURLY GLYPH: `double: bool` is the element's only field,
    // so which curly form it renders as (opening or closing, which depends on
    // its position in the paragraph) is not knowable here. The straight form
    // is one deterministic answer, it is what the author typed in the source,
    // and it is what a reader searching for `Anil's` will type. A plain-text
    // projection is not the place to reproduce typography.
    if c.at("double", default: true) { "\"" } else { "'" }
  } else if c.func() == [ ].func() {
    " "
  } else if c.has("children") {
    c.children.map(x => _plain-with(x, resolve)).join()
  } else if c.has("body") {
    _plain-with(c.body, resolve)
  } else { "" }
}

// Plain text of a title with no registry to hand: a reference contributes
// nothing, every other leaf reads as it does above. The projection to reach
// for anywhere outside a `context` — `#idea` computes a note's `label` with
// it at registration time, before there is anything to resolve against.
#let _plain(c) = _plain-with(c, _ => "")

// `_plain-with`'s resolver for a document that HAS its registry: what a `ref`
// inside a title is worth in plain text is the NAME OF THE NOTE it points at.
// A title reading [Meeting with #ref(<idea:doshi-velez-finale>)] is then
// "Meeting with Finale Doshi-Velez" in an index row, a search hit and a
// reference's own link text, where `_plain` alone leaves "Meeting with ".
//
//   _plain-with(title, _ref-text(_registry.final()))
//
// `it.supplement` WINS where the author gave one — `@idea:x[custom text]` — the
// same preference and the same `auto` sentinel `#hyperlink`'s ref-mode carries.
//
// THE TARGET'S REGISTRATION-TIME `label`, never a re-flattening of its title,
// and that is what makes this total rather than merely usually-terminating: two
// notes whose titles reference each other would otherwise walk in a circle. A
// `label` is computed with the pure `_plain` before anything reaches the
// registry, so reading one cannot recurse.
//
// A REFERENCE TO SOMETHING THAT IS NOT A NOTE — an ordinary figure, a heading —
// contributes nothing, exactly as it did without the hook: there is no name here
// to take, and a raw `fig:x` in a search row is worse than the gap.
//
// PURE, taking the registry as an argument, so it can live beside the walker it
// parameterises rather than in whichever module first needed it: `ideas()` and
// `#hyperlink` both resolve the state themselves and pass the dictionary in.
#let _ref-text(reg) = it => {
  if it.at("supplement", default: auto) != auto {
    _plain(it.supplement)
  } else {
    let id = str(it.target)
    let rec = reg.at(id, default: none)
    if rec == none { "" } else {
      let l = rec.at("label", default: none)
      if l == none or l == "" { _norm(id) } else { l }
    }
  }
}

// Plain text of a note's BODY, for `ideas()`. Every registry body has been
// through `_flatten`, which wraps it in a `show`-rule scope that Typst
// represents as a `styled` node hanging off `.child` — unwrap that first,
// the same way `_blocks` above does. Otherwise follows `_plain`'s
// branches (`.has("text")`, a space element, `.children`, `.body`), except a
// `parbreak` or `item` emits a boundary space so blocks and list entries
// don't glue together the way `_plain`'s title walker would let them
// (MEASURED: without this, "raw code.A second paragraph" loses its
// paragraph break). `metadata` and anything unrecognised contribute "".
//
// BUG FIX, MEASURED: `array.join()` on an EMPTY array returns `none`, not
// `""` — an idea with an empty body (`#idea("x")[]`) has a `sequence` node
// with zero children, and the naive `c.children.map(_body-text).join()`
// therefore returned `none` and crashed the caller's `.replace(...)`. Both
// join call sites below go through `_join`, which special-cases the empty
// array.
#let _join(arr) = if arr.len() == 0 { "" } else { arr.join() }

// A `ref` IS THE SAME LEAF `_plain-with` PARAMETERISES, through the same
// `resolve` hook and for a sharper reason: a note with NO TITLE names itself by
// its body (`_derived-title` below), so `#idea("draft")[Write @idea:nz-man
// post]` is called "Write  post" on every worklist, index row and search hit
// unless whoever holds the registry can say what that reference is worth.
// MEASURED on exactly that note. `_body-text` below passes the pure answer,
// `_ => ""`,
// for a caller with no registry to resolve against; `_rec-label` and
// `ideas()` pass `_ref-text(reg)`.
#let _body-text-with(c, resolve) = {
  if c == none { "" } else if type(c) == str { c } else if type(c) != content {
    ""
  } else {
    let c = c
    while repr(c.func()) == "styled" { c = c.child }
    let f = repr(c.func())
    if c == none { "" } else if c.func() == metadata { "" } else if c.func() == ref {
      resolve(c)
    } else if f == "parbreak" {
      " "
    } else if f == "item" {
      let inner = if c.has("children") {
        _join(c.children.map(x => _body-text-with(x, resolve)))
      } else if c.has("body") { _body-text-with(c.body, resolve) } else { "" }
      " " + inner + " "
    } else if c.has("text") { c.text } else if c.func() == smartquote {
      // The same branch `_plain` above carries, for the same reason and with the
      // same ASCII decision — read its banner. A quote inside a note's BODY has to
      // survive too, or the search index drops it exactly as the title did.
      if c.at("double", default: true) { "\"" } else { "'" }
    } else if c.func() == [ ].func() { " " } else if c.has("children") {
      _join(c.children.map(x => _body-text-with(x, resolve)))
    } else if c.has("body") { _body-text-with(c.body, resolve) } else { "" }
  }
}

// A body's plain text with no registry to hand: a reference contributes nothing,
// every other leaf reads as it does above. `#idea` computes a titleless note's
// registration-time `label` with it, before there is anything to resolve against.
#let _body-text(c) = _body-text-with(c, _ => "")

// Collapses `_body-text`'s raw walk into one search-ready string: runs of
// whitespace (including the boundary spaces `_body-text` inserts) become a
// single space, and the ends are trimmed. A resolved reference lands between two
// space elements, so the collapse is also what closes the gap a dropped one left.
#let _body-plain-with(c, resolve) = _body-text-with(c, resolve).replace(regex("\s+"), " ").trim()

#let _body-plain(c) = _body-plain-with(c, _ => "")

// The first `limit` characters of the body as plain text, with `...` appended
// when there is more body than that. `#idea` uses it whenever `title:` is
// `none`, so a titleless note is named everywhere a titled one is — its own
// minted page's `<title>`, an `ideas/index.html` row, a `#window` summary, a
// bottomed-out window link, an outline entry.
//
// `_body-plain` above is exactly the right source: it walks the body to text
// and collapses every whitespace run to one space, so a multi-block,
// multi-line body arrives here as one clean line with nothing to tidy
// afterwards.
//
// `.clusters()`, NEVER `s.slice(0, limit)`: Typst's `str.slice` takes BYTE
// offsets and panics when one lands inside a multi-byte character, so a body
// containing any non-ASCII text — an accent, an em dash, one of Typst's own
// smart quotes — would fail the build at a boundary invisible in the source.
// `.clusters()` returns grapheme clusters, so the count is what a reader
// means by "characters" and the slice is always safe.
//
// AN EMPTY BODY DERIVES NOTHING and stays `none`. `#idea("x")[]` is legal and
// has no text to name itself with; returning `""` would put an empty
// `<span class="idea-title">` in every such heading and defeat the
// `h*.idea:empty` rules in `core.css` that exist to collapse exactly that —
// the only case those rules are reached by.
//
// The limit is a parameter for the tests' sake, not a knob: `#idea` never
// passes one, and there is deliberately no way for a project to change it.
//
// TRUNCATION HAPPENS AFTER RESOLUTION, which is why the resolver rides this far
// down rather than stopping at `_body-plain-with`: a reference's target name is
// as much of the sixty characters as any other word, and cutting first would
// give one derived name under `_ => ""` and a differently-cut one under the
// registry.
#let _derived-title-with(raw, resolve, limit: 60) = {
  let s = _body-plain-with(raw, resolve)
  if s == "" { return none }
  let cs = s.clusters()
  if cs.len() <= limit { s } else { cs.slice(0, limit).join() + "..." }
}

#let _derived-title(raw, limit: 60) = _derived-title-with(raw, _ => "", limit: limit)

// WHAT TO CALL THE NOTE `rec` RECORDS, and never empty: its title as plain text,
// else its body's first sixty characters, else the `label` `#idea` derived at
// registration time, else the note's own name.
//
// `ref-text` is `_ref-text(reg)` wherever the registry is in hand and `_ => ""`
// where it is not. THE RESOLVER IS THE ARGUMENT rather than the registry so a
// caller walking the whole corpus resolves the state ONCE for the pass, which is
// the cost `ideas()` exists to keep to one — a per-row `_registry.final()` is
// exactly the walk-per-note that accessor's own comments warn about.
//
// EVERY PLACE THAT NAMES A NOTE READS THIS, so a search hit, an index row, a
// reference, a window's summary and a bottomed-out window row cannot drift
// apart: the `if t == "" { name } else { title }` chain was copied by hand
// before, and the copies disagreed the moment a title could contain a reference.
//
// THE BODY RUNG IS DERIVED HERE, not read off `rec.label`, and that is the whole
// reason this sits below `_derived-title-with` rather than above it. The stored
// `label` was flattened PURELY at registration time — `#idea` runs before any
// registry exists — so a titleless note whose body references another
// (`#idea("draft")[Write @idea:nz-man post]`) has "Write  post" stored, and a
// caller
// holding the registry that read that field would print the gap it can itself
// fill. Deriving it again with `ref-text` is what makes a reference worth its
// target's name in a note's derived name too, and the stored field stays as the
// last rung for a caller with no registry.
//
// STILL TOTAL, for the reason `_ref-text` gives: that resolver reads the
// TARGET's registration-time `label` and never re-flattens, so two notes naming
// each other in their bodies cannot walk in a circle any more than two naming
// each other in their titles can.
//
// `fallback:` IS WHAT A NOTE WITH NO NAME AT ALL COMES BACK AS — no title and an
// empty body, which `#idea("x")[]` legally is. `ideas()` passes the note's own
// name, its `label` field being documented as never empty; a caller RENDERING a
// name keeps the default `none`, where nothing-to-show is the real answer and
// `core.css` has rules (`h*.idea:empty`) that exist to collapse it.
//
// TAKES NO ID, which is what lets `#ideas-outline` share it: an outline entry
// reads the note's METADATA PAYLOAD rather than its registry record, and the
// payload carries no id. Nothing here needs one — the only caller wanting an id
// as its last resort is `ideas()`, which has it and passes it as the fallback.
// A payload carrying no `raw` either simply skips the body rung.
#let _rec-label(rec, ref-text, fallback: none) = {
  let t = _plain-with(rec.at("title", default: none), ref-text)
  if t != none and t != "" { return t }
  let d = _derived-title-with(rec.at("raw", default: none), ref-text)
  if d != none and d != "" { return d }
  let l = rec.at("label", default: none)
  if l == none or l == "" { fallback } else { l }
}

#let IK = "rheo-idea" // marker for an idea
#let WK = "rheo-idea-window" // marker for a window; defined here (not next to
// `#window` below) because `_flatten` needs both marker kinds and must be
// defined before `#idea`, which calls it at registration time.

// Typst's own `#footnote` CANNOT be intercepted. Its body is collected by the
// HTML exporter through introspection, independently of show rules, so neither
// `show footnote: it => ...` nor `show footnote: none` removes the entry from
// the page's `<section role="doc-endnotes">` — MEASURED both ways on typst
// 0.15.1. So rookery exports its own `#footnote` (below), which shadows
// `std.footnote` at the author's import site and carries its body on an
// invisible marker this package places itself.
//
// The marker is `metadata` + a label, NOT a `figure`. A figure is block-level
// and forced `</p><p>` breaks around the reference, taking it out of its
// sentence — MEASURED. `metadata` renders nothing and sits inline.
//
// Defined HERE — after IK/WK, before `_flatten` — for the reason `_blocks`
// below is: a `#let` closure captures the scope visible AT DEFINITION time,
// and both `_flatten`'s IK rule and `#idea` itself need these.
#let FNK = <rkfn>

// Every footnote body in this content, in document order.
//
// STOPS at a nested IK or WK marker. A `#idea` written inside another's body
// owns its footnotes and renders its own block for them; a nested `#window`
// likewise. Without this the parent would list its children's footnotes as
// well as its own, and every one would appear twice on the page.
//
// Does NOT descend into a metadata VALUE — only into content children — which
// is what keeps the raw bodies that IK/WK markers carry as metadata payloads
// out of the walk.
#let _footnotes(node) = {
  let out = ()
  if type(node) != content { return out }
  if node.func() == metadata {
    if type(node.value) == dictionary and "rookery-fn" in node.value {
      return (node.value.rookery-fn,)
    }
    return out
  }
  if node.func() == figure and node.at("kind", default: none) in (IK, WK) { return out }
  if node.has("children") { for k in node.children { out += _footnotes(k) } }
  else if node.has("body") { out += _footnotes(node.body) }
  else if node.has("child") { out += _footnotes(node.child) }
  out
}

// Rebuilds `node`, replacing each footnote marker with `mint(n)` — LITERAL
// CONTENT computed here, at construction time, rather than read from a
// `counter` through `context` at layout time (see `_footnoted`, bib.typ, for
// why a layout-time counter cannot be made to converge). `next` is the
// number to hand the first marker this call reaches; the function returns
// both the rebuilt node and the number to hand the NEXT one, so a caller
// walking several siblings threads it through in document order — which is
// what makes two footnotes with byte-identical bodies still number
// correctly: the walk counts occurrences, never matches them by content.
//
// `mint` is a plain `n => content` callback rather than a direct call to
// `_fn-ref`, because `_fn-ref` lives in `state.typ` and needs `_target()` —
// this file's own header forbids exactly that dependency, and `state.typ`
// imports `base.typ` (which re-exports this file), so the reverse import
// would be a cycle. `_footnoted` (bib.typ) is the caller and supplies
// `n => _fn-ref(b, n)`.
//
// Mirrors `_footnotes`' own shape: the same two stops (a footnote's body is
// a metadata PAYLOAD, never itself walked into; a nested IK/WK marker is
// left untouched, since that note or window numbers its own footnotes when
// IT renders) over the same three structural cases (children/body/child).
//
// Reattaches `node`'s own label to `built`, when it had one. `.fields()`
// carries a `label` entry for ANY labelled content, of ANY element type —
// MEASURED: `strong[Hi]<x>` reports `(.., label: <x>)` — and no element's
// constructor accepts `label` as an argument, so every reconstruction below
// removes it before calling one and this is what restores it afterward.
// `[#built#lbl]`, not `built + lbl` (REFUTED: "cannot add content and
// label") — writing the two adjacent in markup is what attaches a
// dynamically-held label the same way `<x>` attaches a literal one, and
// MEASURED it keeps `built`'s own `.func()` rather than wrapping it in a
// further sequence.
#let _relabel(built, node) = {
  if node.has("label") { [#built#(node.label)] } else { built }
}

// Reconstructs every intermediate node from `.fields()`, replacing only the
// slot the recursion descended through — the same generic reconstruction
// `_outbound` (links.typ) already relies on to walk through anything Typst
// or another show rule (a `styled` scope, `_flatten`'s among them) attaches
// to a node this package did not build itself. A FEW element constructors
// take more than their main content slot POSITIONALLY rather than by name —
// `styled`'s `styles`, `link`'s `dest`, `enum.item`'s `number` — and each is
// special-cased below, MEASURED against the alternative (`..fields` raises
// "the argument `<x>` is positional" for each).
#let _number-footnotes(node, next, mint) = {
  if type(node) != content { return (node: node, next: next) }
  if node.func() == metadata {
    if type(node.value) == dictionary and "rookery-fn" in node.value {
      return (node: mint(next), next: next + 1)
    }
    return (node: node, next: next)
  }
  if node.func() == figure and node.at("kind", default: none) in (IK, WK) {
    return (node: node, next: next)
  }
  if node.has("children") {
    let cur = next
    let kids = ()
    for k in node.children {
      let r = _number-footnotes(k, cur, mint)
      kids.push(r.node)
      cur = r.next
    }
    // `sequence` (plain markup concatenation) takes its children as ONE
    // array argument; every OTHER `.children`-bearing element (`grid`,
    // `table`, ...) is an ordinary constructor taking them variadically —
    // MEASURED: `(node.func())(kids)` on one of those raised "expected
    // content, found array".
    let built = if repr(node.func()) == "sequence" { (node.func())(kids) } else { (node.func())(..kids) }
    return (node: _relabel(built, node), next: cur)
  }
  if node.has("body") {
    let r = _number-footnotes(node.body, next, mint)
    let built = if node.func() == link {
      // `link(dest, body)` — TWO positional arguments, `dest` first.
      link(node.dest, r.node)
    } else if node.func() == enum.item {
      // `enum.item(body)`, or `enum.item(number, body)` when the author gave
      // this item an explicit number — `number` is present in `.fields()`
      // only then.
      if "number" in node.fields() { enum.item(node.number, r.node) } else { enum.item(r.node) }
    } else {
      let fields = node.fields()
      let _ = fields.remove("body")
      let _ = fields.remove("label", default: none)
      (node.func())(r.node, ..fields)
    }
    return (node: _relabel(built, node), next: r.next)
  }
  if node.has("child") {
    // The one type this reaches is `styled` — the wrapper a `show`/`set`
    // scope leaves on content, `_flatten`'s own scope among them (see the
    // banner on `_footnoted`, bib.typ).
    let r = _number-footnotes(node.child, next, mint)
    return (node: _relabel((node.func())(r.node, node.styles), node), next: r.next)
  }
  (node: node, next: next)
}

// Typst's OWN footnotes in a body — the ones this package cannot claim.
//
// `#footnote` above shadows `std.footnote` only at the author's IMPORT SITE, and
// Typst imports are per-file. A vertebra that writes `#footnote` without
// importing it from this package gets the builtin, and the build SUCCEEDS while
// putting the body somewhere else entirely: the page's endnote section,
// numbered page-wide, with no Footnotes block on the idea. MEASURED:
//
//     no import   idea-footnotes block=False   page endnotes=True
//     imported    idea-footnotes block=True    page endnotes=False
//
// `#idea` uses this to turn that silence into a build error. It cannot be fixed
// any other way — REFUTED, do not attempt: a rule installed by `#show: rookery`
// changes only how the marker renders, and the body is still collected into the
// endnote section behind it, because the HTML exporter gathers footnotes by
// introspection. MEASURED, the section was emitted and still contained the
// body. There is no way to rebind a builtin document-wide either; `#let` is
// file-scoped.
//
// Stops at a nested IK/WK marker for the same reason `_footnotes` does: a
// nested idea runs this check when IT registers, and should report its own
// violation rather than have its parent report it.
#let _std-footnotes(node) = {
  let out = ()
  if type(node) != content { return out }
  if node.func() == footnote { return (node,) }
  if node.func() == figure and node.at("kind", default: none) in (IK, WK) { return out }
  if node.has("children") { for k in node.children { out += _std-footnotes(k) } }
  else if node.has("body") { out += _std-footnotes(node.body) }
  else if node.has("child") { out += _std-footnotes(node.child) }
  out
}

// Split a body into block-level chunks for `limit:` truncation. A naive
// `body.children.slice(0, limit)` is WRONG: whitespace (`space`/`parbreak`)
// children make it select nothing, and list items are bare `item` children
// with no wrapping `list` element, so a naive slice also cuts lists in half.
// This groups consecutive `item`s into one block and drops whitespace,
// comparing `repr(c.func())` against "space"/"parbreak"/"item"/"styled"
// because none of those has a public element function to compare against
// directly.
//
// A `space` BETWEEN two `item`s is list punctuation, not a boundary — every
// markup list carries one there — while a `parbreak` between them genuinely
// ends the list, so only `parbreak` resets the run; both still emit no block
// of their own. `item` covers all three list kinds (`-`, `+` and `/ term:`
// items are all `item` children), so one branch groups all three.
//
// Every registry body has been through `_flatten`, which wraps it in a
// `show`-rule scope that Typst represents as a `styled` node exposing the
// wrapped content as `.child`, not the `sequence` it wraps — unwrapped first,
// below, the same way `_body-text` above does.
//
// A `space` between two INLINE siblings is separator content, not noise, and
// is kept: dropping it rejoins two runs with nothing between them. Between
// BLOCK-level siblings the gap is drawn by margins rather than content, so
// there the node is dropped. Inline siblings therefore ACCUMULATE into one
// block, keeping the `space` nodes between them, and only a block-level
// sibling starts a new one — which also makes a one-paragraph body count as
// ONE block, so `limit: n` counts the blocks the name promises rather than
// cutting a sentence in half.
//
// Inline and block are told apart BY NAME, because Typst exposes no
// predicate: `raw`, `quote` and `equation` each name both their inline and
// their block form, so those three are asked for their own `block` field
// instead. UNKNOWN NAMES DEFAULT TO BLOCK, deliberately — an element missing
// from the list then behaves exactly as every element did before the list
// existed, so the worst a gap in it can do is leave one dropped space rather
// than merge two real blocks into one.
//
// INERT NODES ARE THE EXCEPTION TO THAT DEFAULT, and they have to be: a
// `state.update`/`counter.update` renders NOTHING, so a body whose first
// child is one has its first block spent on something invisible, and
// `limit: 1` then shows an empty block and hides the real first paragraph
// behind the ellipsis. MEASURED on `rookery.ohrg.org`'s packages shelf, where
// every window came out as a bare `…` with no text, from exactly this: a
// state update sitting as a transcluded body's own first child. It cannot
// simply be dropped either — whatever it updates still needs the write to
// land — so it is HELD and rides on the next block instead, which is the
// one place it can sit without either being lost or counting for one.
// FIVE NAMES ADDED AT ONCE, all of them things an author writes in the middle
// of a sentence without thinking of them as elements at all: `smartquote`,
// `ref`, `cite`, `smallcaps` and `symbol`.
//
// `smartquote` is the one a reader sees first, because every apostrophe typed
// is one of these. Left to the block default it cut a paragraph in three at
// each `'`, and the quote — alone in a block with no word in front of it —
// then resolved as an OPENING `‘` rather than the apostrophe it was written
// as. MEASURED on `rookery.ohrg.org`'s packages shelf: "the reader's own
// browser" came out as three paragraphs reading `the reader`, `‘`,
// `s own browser`.
//
// `ref` is the same defect on this family's own syntax: `@idea:etal` is a
// `ref`, so any transcluded sentence that pointed at another note was cut in
// three the moment a `limit:` sent it through here. `cite`, `smallcaps` and
// `symbol` complete the sweep — each was MEASURED at 3 blocks for
// `[a #smallcaps[b] c]` and its two siblings.
//
// `context` IS DELIBERATELY NOT HERE, though it splits the same way. A context
// block can hold block-level content, so calling it inline would merge two real
// blocks into one — and that is the failure this list's own default is written
// to avoid (see above: a missing name costs a dropped space, a wrong name costs
// a merge). An author writing `#context` mid-sentence pays one spurious split;
// that is the cheaper error of the two.
#let _INLINE-FUNCS = (
  "text", "emph", "strong", "link", "footnote", "super", "sub", "strike",
  "underline", "overline", "highlight", "box", "h", "linebreak", "metadata",
  "sequence", "styled", "smartquote", "ref", "cite", "smallcaps", "symbol",
)
#let _INERT-FUNCS = ("state-update", "counter-update")
#let _is-inline(c) = {
  let f = repr(c.func())
  if f in ("raw", "quote", "equation") { return not c.at("block", default: false) }
  f in _INLINE-FUNCS
}
// The held children, in the order they were written, as the content to put
// back in front of whatever child flushes them. A `space` survives only into
// an INLINE neighbour (see above: between blocks the gap is drawn by margins,
// not content); an inert node survives into either, because dropping it would
// drop a state update the body needs.
#let _held-content(held, inline) = {
  let kept = held.filter(h => inline or h.inert).map(h => h.node)
  kept.sum(default: [])
}
#let _blocks(body) = {
  let body = body
  while repr(body.func()) == "styled" { body = body.child }
  if not body.has("children") { return (body,) }
  let out = ()
  let prev-item = false
  let prev-inline = false
  // The children seen since the last kept one that emit nothing of their own
  // — `space` nodes and inert nodes — each tagged with which of the two it
  // is, held back until the next kept child says how to treat them.
  let held = ()
  for c in body.children {
    let f = repr(c.func())
    if f == "space" { held.push((node: c, inert: false)); continue }
    if f == "parbreak" {
      prev-item = false
      prev-inline = false
      // The gap goes, the inert nodes stay: a `parbreak` ends a block, and
      // an update written before it still has to reach the next one.
      held = held.filter(h => h.inert)
      continue
    }
    if f in _INERT-FUNCS { held.push((node: c, inert: true)); continue }
    if f == "item" {
      let lead = _held-content(held, false)
      if prev-item { out.at(-1) = out.at(-1) + lead + c } else { out.push(lead + c) }
      prev-item = true
      prev-inline = false
      held = ()
      continue
    }
    let inline = _is-inline(c)
    if inline and prev-inline {
      out.at(-1) = out.at(-1) + _held-content(held, true) + c
    } else {
      out.push(_held-content(held, false) + c)
    }
    prev-item = false
    prev-inline = inline
    held = ()
  }
  // Whatever is still held when the children run out emits nothing, so it
  // cannot stand as a block of its own: it rides on the last one — or IS the
  // whole body, in the degenerate case of a body that is nothing but updates.
  let tail = held.filter(h => h.inert)
  if tail.len() > 0 {
    let t = tail.map(h => h.node).sum()
    if out.len() == 0 { out.push(t) } else { out.at(-1) = out.at(-1) + t }
  }
  out
}

// The ONE `limit:` truncation — first `limit` blocks of a body, then a grey
// ellipsis — shared by `_flatten`'s WK expansion, `#window` and `#idea-body`.
// It lived as three verbatim copies, which is exactly the drift the rest of
// this file factors things out to prevent. Defined HERE, beside `_blocks`
// rather than beside `#window`, because a `#let` closure captures the scope
// visible AT DEFINITION time and `_flatten` (below) is one of the three
// callers. A `none` limit means no truncation; the callers assert away `0` and
// negatives before reaching this, so it validates nothing itself.
//
// Joined with `parbreak()`, not with nothing. `_blocks` drops the `parbreak`
// children that separated the blocks — right, because a block is not its
// separator — and putting them back is this join's job. MEASURED before it did:
// a two-block truncation rendered as
// `Only three layers, <code>because</code> derived.Second paragraph here. …`,
// one run of inline content with no space, no break, and no `<p>` wrappers at
// all, where the same note UNtruncated emits one `<p>` per paragraph. Typst's
// HTML export decides paragraphs by the `parbreak`s it finds, so restoring them
// restores the `<p>`s with them.
//
// No separator before the ellipsis, so it trails the last kept block rather
// than standing apart from it. MEASURED, and the two cases differ for a reason:
// after a paragraph it lands INSIDE that `<p>`, which reads as "this paragraph
// continues"; after a grouped list it comes out as its own `<p>` after the
// `</ul>`, because an ellipsis cannot sit inside a list. Both are right.
//
// `_truncate-split` is the same cut, but hands back both halves instead of
// discarding the tail — a caller that wants to make the cut reversible (an
// in-place disclosure, say) needs `rest` kept alive rather than thrown away
// behind an ellipsis. `_truncate` is a thin wrapper over it so the two stay
// bit-for-bit in agreement.
#let _truncate-split(body, limit) = {
  if limit == none { return (shown: body, rest: none) }
  let bs = _blocks(body)
  if bs.len() <= limit { return (shown: body, rest: none) }
  (
    shown: bs.slice(0, limit).join(parbreak()),
    rest: bs.slice(limit).join(parbreak()),
  )
}

#let _truncate(body, limit) = {
  let split = _truncate-split(body, limit)
  if split.rest == none { split.shown } else {
    split.shown + [#text(gray)[ ... ]]
  }
}

// `tags`, `match` and `limit` are checked identically by several functions,
// so each lives here once rather than as its own copy of the assert and its
// message.
//
// `where` is the caller's own name as it already appears in the message —
// "#idea", "#ideas'", "#window's" — so the text a reader sees is byte for byte
// what it was. Pass the possessive exactly as the original wrote it, apostrophe
// included: `#ideas'` and `#idea's` are both correct English for their nouns,
// and matching the old text matters more than regularising it.
//
// ONLY THE ONES WITH SEVERAL CALLERS live here. `depth` deliberately does NOT:
// `#window` and `#idea-body` accept `auto or int >= 0` while `#ideas-outline`
// accepts `none or int >= 1`, and `#window`'s message spends four lines
// explaining what each depth renders. Three different checks that happen to
// share a parameter name are not one check, and folding them would either lose
// that explanation or attach it to functions it does not describe.
#let _assert-tags(v, where, what: "tags") = assert(
  v == none
    or type(v) == str
    or type(v) == dictionary
    or (type(v) == array and v.all(t => type(t) == str)),
  message: "@rookery/core: " + where + " `" + what + "` must be none, a "
    + "string, an array of strings, or a dictionary — got " + repr(v),
)

#let _assert-match(v, where) = assert(
  v == "any" or v == "all",
  message: "@rookery/core: " + where + " `match` must be \"any\" or \"all\" — got "
    + repr(v),
)

// The block-count form: `none` or a positive integer, shared by `#window` and
// `#idea-body`, which truncate the same way and say so the same way.
#let _assert-limit(v, where) = assert(
  v == none or (type(v) == int and v >= 1),
  message: "@rookery/core: " + where + " `limit` must be none or a positive "
    + "integer (the number of leading blocks to show) — got " + repr(v),
)

// The ten keys a `display:` dictionary and its matching `display-*`
// arguments may set. `#idea` and `#window` each use a different subset of
// these — the union lives here once so the validation and the panic message
// below share one list instead of drifting apart.
#let _DISPLAY-KEYS = (
  "context", "backlinks", "background", "date", "frame",
  "name", "label", "tags", "title", "right-gutter",
)

// Merges a `display:` dictionary with a set of individual `display-*`
// override flags into one dictionary carrying all ten `_DISPLAY-KEYS`,
// always. For each key, an override in `flags` that is not `auto` wins;
// otherwise `dict`'s own value for that key is used, if present; otherwise
// the result is `auto`.
//
// `auto` survives in the result rather than being resolved to a boolean:
// it means the caller expressed no preference, and what that implies differs
// by key — `context`, `backlinks` and `title` fall back to a document-wide
// setting read much later on the minted page, while the rest fall back to a
// built-in default chosen by the caller. Resolving `auto` here would erase
// that distinction, so this function must not do it.
//
// `where` is the caller's own name as it already appears in other messages
// in this file — `"#idea's"`, `"#window's"`.
#let _resolve-display(dict, flags, where) = {
  for key in dict.keys() {
    if key not in _DISPLAY-KEYS {
      panic(
        "@rookery/core: " + where + " `display` dictionary has an unknown key "
          + repr(key) + " — valid keys are " + repr(_DISPLAY-KEYS),
      )
    }
    let v = dict.at(key)
    if v != true and v != false and v != auto {
      panic(
        "@rookery/core: " + where + " `display` dictionary's " + repr(key)
          + " must be true, false or auto — got " + repr(v),
      )
    }
  }
  let result = (:)
  for key in _DISPLAY-KEYS {
    let flag = flags.at(key, default: auto)
    result.insert(
      key,
      if flag != auto { flag } else if key in dict { dict.at(key) } else { auto },
    )
  }
  result
}

// A URL-safe slug from a heading's plain text: lowercased, every run of
// characters outside `[a-z0-9]` collapsed to one `-`, with no leading or
// trailing `-`. `#ideate` callers pass this to a `name:` function to name a
// section's note after its own heading, so inserting or reordering sections
// does not renumber every id after it the way the package counter would.
//
// A heading of nothing but punctuation slugs to the empty string, which is a
// caller error rather than a silent id — an unnamed note already has a
// well-defined identity (the counter), so minting one under an empty name
// would be worse than refusing.
#let _slug(s) = {
  let out = lower(s).replace(regex("[^a-z0-9]+"), "-").trim("-")
  if out == "" {
    panic(
      "@rookery/core: text could not be slugged to a name — nothing is left once "
        + "punctuation is stripped. Got: " + repr(s),
    )
  }
  out
}

// Public slug function: converts content or a string to a URL-safe slug.
// Takes raw content (like a heading's body) or a string, and returns the
// slugged form suitable for use as an id component.
#let slug(content) = _slug(_plain(content))

// A title-derived note id, or `none` if the title cannot supply one — the
// caller's cue to fall back to the body-derived name instead. Duplicates
// `_slug`'s one-line regex rather than calling it: `_slug` panics on the
// empty case, and that is the one case this function exists to handle
// gracefully.
//
// `none` on three inputs, each for a different reason: an empty result (the
// title is pure punctuation — the same case `_slug` panics on, but an id
// has a safe fallback where a heading name does not); a purely-numeric
// result, which reads as a bare number rather than as a name (`_name-slug`
// rejects one for the same reason, so neither rung can mint `idea:2024`);
// and a result still empty after the length cap strips a trailing `-` left
// by cutting mid-word.
//
// The cap exists because an id becomes a filename (`ideas/<id>.html`) — a
// 200-character title must not become a 200-character path segment.
#let _id-slug(s, limit: 60) = {
  let out = lower(s).replace(regex("[^a-z0-9]+"), "-").trim("-")
  if out == "" { return none }
  if out.match(regex("^[0-9]+$")) != none { return none }
  if out.len() > limit { out = out.slice(0, limit).trim("-", at: end) }
  if out == "" { none } else { out }
}

// Base36 digits, low to high — `_b36`'s alphabet.
#let _B36-DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"

// Renders a non-negative integer in lowercase base36, left-padded with `0`
// to exactly `width` characters. A value too wide for `width` keeps its
// LOW-order digits rather than its high ones: `_h3` below wants a fixed-width
// tail, not a faithful base36 rendering of the whole accumulator.
#let _b36(n, width) = {
  let digits = if n == 0 { "0" } else { "" }
  let v = n
  while v > 0 {
    digits = _B36-DIGITS.at(calc.rem(v, 36)) + digits
    v = calc.div-euclid(v, 36)
  }
  if digits.len() < width {
    digits = "0" * (width - digits.len()) + digits
  } else if digits.len() > width {
    digits = digits.slice(digits.len() - width)
  }
  digits
}

// A three-character base36 digest of a string: djb2, reduced modulo
// 2147483647 at every step so `acc * 33` never leaves Typst's i64 range.
// Typst ships no hash of its own — neither `std` nor `calc` has one — hence
// hand-rolled. Not cryptographic: it exists to tell apart two notes whose
// slugs would otherwise collide, not to authenticate anything. The caller
// caps the input string; this does no capping of its own.
#let _h3(s) = {
  let acc = 5381
  for b in array(bytes(s)) { acc = calc.rem(acc * 33 + b, 2147483647) }
  _b36(acc, 3)
}

// Words `_name-slug` drops from the FRONT of a result, and only the front —
// "the-two-towers" keeps its "two" once "the" goes. These are the words a
// title or sentence casually opens with, not a general English stopword
// list.
#let _NAME-SLUG-STOPWORDS = (
  "the", "a", "an", "and", "or", "of", "to", "in", "on", "at", "is", "are",
  "was", "were", "be", "been", "it", "its", "this", "that", "for", "with",
  "as", "by", "from",
)

// A content-derived slug, or `none` where the content cannot safely name a
// note — the same `none`-not-panic contract as `_id-slug`, for the same
// reason: a caller falls back to something else (a counter, `_id-slug`'s own
// title slug) rather than crash on ordinary content like a bare URL or a
// punctuation-only line.
//
// `s` is already-projected plain text (`_plain(c)`), capped by the caller —
// this function does no capping of its own.
//
// A string that STARTS WITH a URL scheme is special-cased first: a reading
// list of saved links is a common shape, and a URL's distinguishing part is
// its tail, not its host — otherwise every link under one domain would slug
// to that same host and collide. A scheme appearing mid-string instead of at
// the start skips this substitution and is caught below by the
// https/http/www word-drop.
//
// What is left — the URL's tail, or the original text unchanged — becomes
// lowercase words joined by `-`; a leading filler word is dropped (the
// stopword list above), any leftover leading scheme-shaped word is dropped
// too, and the result keeps whole words from the start while it stays within
// `limit` characters. Nothing is ever truncated mid-word, except a first
// word that alone exceeds `limit` — hard-truncated, since there is nothing
// shorter to fall back to.
#let _name-slug(s, limit: 16) = {
  let trimmed = s.trim()
  if trimmed.starts-with("http://") or trimmed.starts-with("https://") {
    let m = trimmed.match(regex("^\S+"))
    let url = if m != none { m.text } else { trimmed }
    let rest = url.replace(regex("^https?://"), "")
    if rest.ends-with("/") { rest = rest.slice(0, -1) }
    let segs = rest.split(regex("[/?#]")).filter(seg => seg != "")
    segs = segs.map(seg => seg.replace(regex("\.(html|htm|pdf|php|asp|aspx)$"), ""))
    segs = segs.filter(seg => seg.match(regex("^[0-9.]+$")) == none)
    s = if segs.len() == 0 { "" } else { segs.last() }
  }

  let out = lower(s).replace(regex("[^a-z0-9]+"), "-").trim("-")
  let words = out.split("-").filter(w => w != "")

  while words.len() > 1 and _NAME-SLUG-STOPWORDS.contains(words.first()) {
    words = words.slice(1)
  }
  while words.len() > 0 and (
    words.first() == "https" or words.first() == "http" or words.first() == "www"
  ) {
    words = words.slice(1)
  }
  if words.len() == 0 { return none }

  let result = words.first()
  if result.len() > limit {
    result = result.slice(0, limit)
  } else {
    for w in words.slice(1) {
      let candidate = result + "-" + w
      if candidate.len() > limit { break }
      result = candidate
    }
  }

  if result.match(regex("^[0-9]+$")) != none { none } else { result }
}

// Public metadata beacon for ideate tags: wrap tag(s) to emit from a section's own
// content. `tags` accepts the same four forms as `#idea`'s own `tags:` — `none`,
// a string, an array of strings, or a dictionary — and is normalized by `_norm-tags`
// when read back in the beacon scanner. Place inline within a paragraph to tag
// the next-nearest group, or anywhere in a section's body under `separator: heading`.
#let ideate-tag(tags) = [#metadata((rookery-ideate-tags: tags))]

// Public metadata beacon for a fixed ideate id: wrap a string to name a
// section's note explicitly, overriding the `auto` counter (or a `name:`
// function's derived slug) for that one section. Place inline within a
// paragraph, or anywhere in a section's body under any separator — unlike
// `name:` as a function, this beacon does not require `separator: heading`,
// since it carries its own value rather than reading one off a heading.
#let ideate-name(name) = [#metadata((rookery-ideate-name: name))]
