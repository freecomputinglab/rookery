// Unit fixture for the pure, state-free helpers in `/src/lib.typ`.
//
// Every case below pins a MEASURED defect recorded in that file's own comments,
// named in the comment above the assertion. This is a regression suite: a case
// is here because the behaviour was once wrong, not to describe the API.
//
// Run it with `just test` from `rookery/0.6.0`. There is no runner and no JS:
// `assert.eq` fails the compile with a line number, which is the whole harness.
// `--features html` is mandatory even though nothing here compiles to HTML —
// `std.target` is gated by the feature rather than the output format, and
// `/src/lib.typ` reads it at import time (see lib.typ:24-35).
//
// SCOPE: helpers that are pure functions of their arguments, plus the two that
// read one document-wide state (`_note-file` via `_pfx`, `_bib-keys` via
// `_bib`). Anything needing `query`/`context` convergence — `#idea`, `#window`,
// `_page-links`, `_ideas-outline-data` — is out of scope here and belongs to the
// demo-based beads.

#import "/src/lib.typ": (
  _bib, _bib-keys, _blocks, _body-plain, _body-plain-with, _body-text, _cite-scan, _dedup-tag,
  _is-inline, _join, _merge-base-tags, _nest-outline, _norm, _norm-tags, _note-file, _outbound,
  _derived-title, _derived-title-with, _own-cited-keys, _plain, _plain-with, _rec-label, _ref-text, _resolve-excluded, _resolve-tags-color, _sort-ids,
  _project, _split-tag-list, _tag-pred, _truncate, _truncate-split, _blank, _heading-only, _level-of, _sel-level, _inert, _no-content, _slug, _id-slug, _name-slug, _h3, _b36, _ideate-tag-value, _ideate-name-value,
  _resolve-display, _DISPLAY-KEYS,
  footnote, idea, idea-href, idea-path, slug,
  tag-index, window,
)

// ---- _norm — bare name, full id, label, and a name with its own colon ------
// `_norm` splits on the FIRST colon only, so an id whose name contains one
// survives intact.
#assert.eq(_norm("etal"), "etal")
#assert.eq(_norm("idea:etal"), "etal")
#assert.eq(_norm(<idea:etal>), "etal")
#assert.eq(_norm("idea:a:b"), "a:b")

// ---- _norm-tags — four author-facing forms, one dictionary -----------------
// `("a", "b")` and `(a: none, b: none)` must be the SAME record, or two pins of
// one id written in different forms read as a duplicate-id collision.
#assert.eq(_norm-tags(none), (:))
#assert.eq(_norm-tags("a"), (a: none))
#assert.eq(_norm-tags(("a", "b")), (a: none, b: none))
#assert.eq(_norm-tags((a: 1)), (a: 1))
#assert.eq(_norm-tags(()), (:))
// Insertion order survives the fold. MEASURED: typst dictionaries iterate in
// insertion order, so `.keys()` here is authored order, not sorted order.
#assert.eq(_norm-tags(("zeta", "alpha")).keys(), ("zeta", "alpha"))

// ---- _dedup-tag — `#todo("x", tags: ("todo",))` must not double the tag ----
// A duplicate here reaches the heading as a duplicated `idea-tag-todo` class.
#assert.eq(_dedup-tag("todo", ("todo",)), (todo: none))
#assert.eq(_dedup-tag("todo", ()), (todo: none))
#assert.eq(_dedup-tag("note", ("draft",)), (note: none, draft: none))
#assert.eq(_dedup-tag("note", ("draft", "note")), (draft: none, note: none))
// The tag is PREPENDED, which is visible in key order.
#assert.eq(_dedup-tag("note", ("draft",)).keys(), ("note", "draft"))
// A caller's own value for the tag WINS OUTRIGHT over the factory default —
// no deep merge. This is the mechanism by which `#todo("x", tags: (todo: ..))`
// sets a value for the wrapper's own tag, and it is why the "already a key"
// guard must run before the merge: dict `+` is right-wins (MEASURED), so an
// unconditional merge would clobber the caller's value with the default.
#assert.eq(_dedup-tag("todo", (todo: (p: 1))), (todo: (p: 1)))
#assert.eq(_dedup-tag("todo", (todo: (p: 1)), value: "default"), (todo: (p: 1)))
// `value:` applies only when the caller did not name the tag at all.
#assert.eq(_dedup-tag("flag", ("draft",), value: "yes"), (flag: "yes", draft: none))
// A bare string `tags:` is normalized, so `tag in tags` is a KEY test and never
// a substring test — `_dedup-tag("raft", "draft")` must not think it is present.
#assert.eq(_dedup-tag("raft", "draft"), (raft: none, draft: none))

// ---- _merge-base-tags — a constructor's tags, under the caller's ------
// The trap this pins: `idea.with(tags: ("note",))` lets a caller's own
// `tags:` REPLACE the constructor's tag outright, so `#note("c", tags:
// ("draft",))` loses "note". `tag:`/`base-tags:` merge instead.
#assert.eq(_merge-base-tags("note", none), (note: none))
#assert.eq(_merge-base-tags("note", ("draft",)), (note: none, draft: none))
// Several tags keep the order the constructor named them in.
#assert.eq(
  _merge-base-tags(("person", "participant"), none),
  (person: none, participant: none),
)
// A dictionary base binds a VALUE per tag, which is what makes a
// one-tag `value:` restriction unnecessary.
#assert.eq(
  _merge-base-tags((todo: (state: "open"), draft: none), none),
  (todo: (state: "open"), draft: none),
)
// THE CALLER'S OWN VALUE FOR THE SAME TAG WINS OUTRIGHT — no deep merge.
#assert.eq(
  _merge-base-tags((todo: (state: "open")), (todo: (state: "done"))),
  (todo: (state: "done")),
)
// An absent base is the caller's tags, normalized and nothing else.
#assert.eq(_merge-base-tags(none, ("draft",)), (draft: none))
// NESTED, which is how `#idea` gets its three-way precedence:
// `tag:` under `base-tags:` under the caller's `tags:`.
#assert.eq(
  _merge-base-tags("low", _merge-base-tags(("mid",), ("high",))),
  (low: none, mid: none, high: none),
)
#assert.eq(
  _merge-base-tags((k: "low"), _merge-base-tags((k: "mid"), (k: "high"))),
  (k: "high"),
)

// ---- _join — `array.join()` returns none on an empty array -----------------
// The crash this pins: an empty-bodied note (`#idea("x")[]`) walked to a
// `sequence` with zero children, `.join()` gave `none`, and the caller's
// `.replace(...)` failed.
#assert.eq(_join(()), "")
#assert.eq(_join(("a", "b")), "ab")

// ---- #idea — the three legal positional shapes still compile ---------------
// A name-carrying positional plus a body, a bare body, and named arguments
// alone with no positionals at all, are the three shapes `#idea`'s own guard
// (idea.typ) allows through. A third positional is rejected there and cannot
// be pinned here as a regression, since Typst has no way to catch a panic
// from inside a document — the negative case is a manual VERIFY instead.
// Reaching the guard without it firing is the whole assertion: a wrong bound
// there fails this compile just as loudly as a real three-positional call
// would.
#context {
  let _named = idea(<idea-units-legal-named>, title: [Some Title])[body text]
  let _bare = idea[body text]
  let _bodiless = idea(title: [Some Title])
}

// ---- _plain — a `raw` span must contribute its text, not a hole ------------
// MEASURED defect: "The  marker" (two spaces) where `raw` fell through to "".
#assert.eq(_plain(none), "")
#assert.eq(_plain("x"), "x")
#assert.eq(_plain([The #raw("marker") marker]), "The marker marker")

// ---- _plain-with — a `ref` in a title is the caller's to name ---------------
// MEASURED defect: a derived title reading [Meeting with #ref(<idea:x>)]
// flattened to "Meeting with " — the reference contributed nothing, so every
// search hit and index row for the note dropped the name it was about.
// `_plain` is still the pure answer; `ideas()` passes a resolver that reads the
// target's own label.
#assert.eq(_plain([Meeting with #ref(<idea:doshi-velez-finale>)]), "Meeting with ")
#assert.eq(
  _plain-with([Meeting with #ref(<idea:doshi-velez-finale>)], it => "Finale Doshi-Velez"),
  "Meeting with Finale Doshi-Velez",
)
// The resolver sees the ELEMENT, target and supplement included, and a title
// that is nothing but a reference resolves whole.
#assert.eq(_plain-with(ref(<idea:etal>), it => str(it.target)), "idea:etal")
#assert.eq(
  _plain-with([A #ref(<idea:x>, supplement: [custom])], it => _plain(it.supplement)),
  "A custom",
)

// ---- _ref-text / _rec-label — one name for one note, everywhere ------------
// MEASURED defect: a meeting titled [Meeting with #ref(<idea:x>)] was called
// "Meeting with " in a window summary and a backlink, and "MeetingWith Bought
// large with the idea that a .." in the search index — the reference contributed
// nothing and the fallback reached for the body.
#let REG = (
  "idea:doshi-velez-finale": (title: [Finale Doshi-Velez], label: "Finale Doshi-Velez"),
  "idea:96": (title: [Meeting with #ref(<idea:doshi-velez-finale>)], label: "Meeting with "),
  "idea:97": (title: none, label: "Bought large with the idea that a .."),
  "idea:98": (title: none, label: none),
)
#assert.eq(_ref-text(REG)(ref(<idea:doshi-velez-finale>)), "Finale Doshi-Velez")
// A reference to something that is not a note names nothing.
#assert.eq(_ref-text(REG)(ref(<fig:plot>)), "")
#assert.eq(
  _rec-label(REG.at("idea:96"), _ref-text(REG)),
  "Meeting with Finale Doshi-Velez",
)
// No title: the registration-time label, which is the body's opening words.
#assert.eq(_rec-label(REG.at("idea:97"), _ref-text(REG)), "Bought large with the idea that a ..")
// No name at all — an empty body and no title. `none` for a caller rendering a
// name, the note's own name for `ideas()`, whose `label` is never empty.
#assert.eq(_rec-label(REG.at("idea:98"), _ref-text(REG)), none)
#assert.eq(_rec-label(REG.at("idea:98"), _ref-text(REG), fallback: "98"), "98")
// MEASURED defect: a titleless note whose BODY references another —
// `#todo[Write @idea:nz-man post]` — was called "Write post" on every worklist,
// index row, outline entry and search hit. Its `label` was flattened before
// there was a registry, and `_rec-label` read that field rather than deriving
// the body rung again with the resolver it holds.
#let TODO-REC = (
  title: none,
  label: "Write post",
  raw: [Write #ref(<idea:doshi-velez-finale>) post],
)
#assert.eq(_rec-label(TODO-REC, _ref-text(REG)), "Write Finale Doshi-Velez post")
// With no registry to hand the derived name agrees with the stored one, which
// is what keeps the last rung honest for a payload carrying no `raw` at all.
#assert.eq(_rec-label(TODO-REC, _ => ""), "Write post")
#assert.eq(_rec-label((title: none, label: "Write post"), _ref-text(REG)), "Write post")

// ---- _body-text / _body-plain — block boundaries, and the empty body -------
// MEASURED defect: "raw code.A second paragraph" — a `parbreak` contributed
// nothing, gluing two blocks into one word.
#assert.eq(_body-plain([]), "")
#assert.eq(_body-plain([A.#parbreak()B.]), "A. B.")
#assert.eq(
  _body-plain[
    - one
    - two
  ],
  "one two",
)
// `metadata` contributes nothing: `#idea`'s own marker sits inside the body.
#assert.eq(_body-plain([A#metadata((k: 1))B]), "AB")
// A `ref` in a body is the caller's to name, exactly as it is in a title, and
// the whitespace collapse is what closes the gap a dropped one leaves.
#assert.eq(_body-plain([Write #ref(<idea:x>) post]), "Write post")
#assert.eq(
  _body-plain-with([Write #ref(<idea:x>) post], it => "New Zealand's Second Smartest Man"),
  "Write New Zealand's Second Smartest Man post",
)

// ---- _blocks — the styled unwrap, item grouping, whitespace ---------------
// MEASURED REGRESSION (v6y.7): every registry body goes through `_flatten`,
// which wraps it in a `show`-rule scope Typst represents as a `styled` node
// with no children. Without the unwrap `_blocks` returned one block for every
// body, silently disabling `limit:` truncation everywhere.
// Built in a CODE block, not markup: `[#show ..; body]` puts the `styled` node
// under a leading space inside a sequence, where `_blocks` never had a problem.
// `_flatten` wraps the whole body, so the `styled` node is the ROOT — which is
// the shape that broke, and the shape this reproduces.
#let _styled-two-blocks = {
  show emph: it => it
  [First.#parbreak()Second.]
}
#assert.eq(_blocks(_styled-two-blocks).len(), 2)
// Consecutive `item`s are ONE block, so `limit:` cannot cut a list in half.
// Children here are `space text space parbreak space item space item space`, so
// this holds because a `space` between two items does not clear the run — see
// `_blocks`'s own comment on why a list's own punctuation space must survive.
#let _text-then-list = [
  Intro.
  #parbreak()
  - a
  - b
]
#assert.eq(_blocks(_text-then-list).len(), 2)
// A `parbreak` between two items DOES end the list — that is the one whitespace
// kind that still clears the run. Children: `space item parbreak item space`.
#let _list-parbreak-list = [
  - a

  - b
]
#assert.eq(_blocks(_list-parbreak-list).len(), 2)
// `+` and `/ term:` rows are `item` children too, so they group the same way.
#let _text-then-enum = [
  Intro.

  + one
  + two
]
#assert.eq(_blocks(_text-then-enum).len(), 2)
#let _text-then-terms = [
  Intro.

  / a: x
  / b: y
]
#assert.eq(_blocks(_text-then-terms).len(), 2)
// `space` and `parbreak` are separators, never blocks of their own.
#assert.eq(_blocks([A.#parbreak()#parbreak()B.]).len(), 2)
// A childless body is one block, itself.
#assert.eq(_blocks([A]).len(), 1)

// ---- _blocks — an inline run is ONE block, and keeps its spaces (akb) -------
// MEASURED DEFECT: children here are `text space raw space text`, and dropping
// every `space` made a truncating slice rejoin the runs as "layers,because".
// The whole paragraph is one block now, so `limit:` cannot land inside it, and
// the spaces survive either way.
#let _inline-raw = [Some text #raw("x") and more text here.]
#assert.eq(_blocks(_inline-raw).len(), 1)
#assert.eq(_body-plain(_blocks(_inline-raw).first()), "Some text x and more text here.")
// A block-level sibling still starts its own block, and the `space` before it
// is still dropped — that gap is drawn by margins, not content. Children:
// `space heading space text space`, and note there is NO `parbreak` between a
// heading and the paragraph after it, so the split cannot come from one.
#let _heading-then-text = [
  = Head
  Body text.
]
#assert.eq(_blocks(_heading-then-text).len(), 2)
// `#idea`'s own marker is `metadata`: invisible, and this assertion is what
// confirms it never takes a whole block — and therefore a whole `limit`
// slot — to itself.
#assert.eq(_blocks([A#metadata((k: 1))B]).len(), 1)
// A SMARTQUOTE IS INLINE, and nothing in a paragraph looks less like a block.
// MEASURED DEFECT, on `rookery.ohrg.org`'s packages shelf: a `#window(..,
// limit: 1)` whose body said "the reader's own browser" rendered it as THREE
// paragraphs — `the reader`, `‘`, `s own browser`. `repr(smartquote().func())`
// is `"smartquote"`, that name was in neither list, and unknown names default
// to BLOCK. The split also flipped the glyph: alone in a block of its own the
// quote has no preceding word, so Typst resolved it as an OPENING `‘` rather
// than the apostrophe it was written as.
#assert.eq(_blocks([the reader's own browser]).len(), 1)
// The same gap, on four more things written mid-sentence. `ref` is the one that
// matters most after the apostrophe: `@idea:etal` is a `ref`, so a transcluded
// sentence pointing at another note was cut in three wherever a `limit:` sent
// it through `_blocks`. Each of these MEASURED at 3 before the names went in.
#assert.eq(_blocks([see #ref(<lbl>) here]).len(), 1)
#assert.eq(_blocks([as #cite(<key>) says]).len(), 1)
#assert.eq(_blocks([a #smallcaps[b] c]).len(), 1)
#assert.eq(_blocks([a #sym.dash.em b]).len(), 1)

// ---- _blocks — an inert node never costs a block -------------------------
// MEASURED DEFECT, on `rookery.ohrg.org`'s packages shelf: every `#window(..,
// limit: 1)` there rendered as a bare `…` with no text at all. `_flatten`
// opens every registry body with `_scope.update(..)` and closes it with
// another, `repr(state.update(..).func())` is `"state-update"`, that name was
// in neither list, and unknown names default to BLOCK — so a one-paragraph
// body split as `[state-update, paragraph, state-update]`, `limit: 1` kept
// the INVISIBLE first block, and the paragraph went behind the ellipsis.
#let _st = state("units-inert", 0)
#let _ct = counter("units-inert")
// The shape of every flattened body: an update, the prose, an update.
#let _inert-wrapped = [#_st.update(v => v)One.#parbreak()Two.#_st.update(v => v)]
#assert.eq(_blocks(_inert-wrapped).len(), 2)
#assert.eq(_body-plain(_truncate(_inert-wrapped, 1)), "One. …")
// The leading update rides on the first block rather than being dropped: the
// push and the pop are what makes a relative id inside the body resolve, so
// truncation may not throw them away.
#assert.eq(_blocks(_inert-wrapped).first().children.len(), 2)
// A body opening on a BLOCK-level child is the case an inline classification
// would not have fixed — the update is inline, the list is not, so the two
// cannot merge into a run and the update would push a block of its own.
#let _inert-then-list = [#_st.update(v => v)
  - a
  - b
]
#assert.eq(_blocks(_inert-then-list).len(), 1)
// `counter.update` and `counter.step` are the same kind of node.
#assert.eq(_blocks([#_ct.update(1)#_ct.step()A.#parbreak()B.]).len(), 2)
// An inert node between two paragraphs still leaves two of them, and the one
// after the last block rides on it rather than standing as a third.
#assert.eq(_blocks([A.#parbreak()#_st.update(v => v)#parbreak()B.]).len(), 2)
#assert.eq(_blocks([A.#parbreak()B.#_st.update(v => v)]).len(), 2)
// Degenerate: a body that is nothing BUT updates still has to come back as
// something, or the content is simply lost.
#assert.eq(_blocks([#_st.update(v => v)#_ct.step()]).len(), 1)
// `raw`/`quote`/`equation` name both their forms, so they are asked, not looked
// up: the block form is a block, the inline form joins the run.
#assert(_is-inline(raw("x")))
#assert(not _is-inline(raw("x", block: true)))
#assert(_is-inline(quote[q]))
#assert(not _is-inline(quote(block: true)[q]))
#assert(_is-inline($x$))
#assert(not _is-inline($ x $))
// An unrecognised element is a block, so it keeps the pre-list behaviour.
#assert(not _is-inline(table(columns: 1, [a])))
#assert(not _is-inline(figure([a])))

// ---- _truncate — the ONE `limit:` truncation, joined with a parbreak -------
#let _three-paras = [One.#parbreak()Two.#parbreak()Three.]
// `none` is not a truncation: the body comes back untouched, identity included,
// because the three call sites pass their own `limit:` straight through.
#assert(_truncate(_three-paras, none) == _three-paras)
// A limit at or above the block count is not one either.
#assert(_truncate(_three-paras, 3) == _three-paras)
#assert(_truncate(_three-paras, 9) == _three-paras)
// Below it: the kept blocks plus the ellipsis, and NOTHING dropped between them
// — the join re-inserts the `parbreak` `_blocks` discarded, which is what makes
// typst's HTML export emit one `<p>` per kept block instead of one run-on.
#assert.eq(_body-plain(_truncate(_three-paras, 2)), "One. Two. …")
#assert.eq(_blocks(_truncate(_three-paras, 2)).len(), 2)

// ---- _truncate-split — the same cut, both halves handed back --------------
// `_truncate` above is a thin wrapper over this: same three shapes, but `rest`
// survives instead of being thrown away behind an ellipsis.
#assert.eq(_truncate-split(_three-paras, none), (shown: _three-paras, rest: none))
#assert.eq(_truncate-split(_three-paras, 3).rest, none)
#assert.eq(_truncate-split(_three-paras, 9).rest, none)
#let _split-2 = _truncate-split(_three-paras, 2)
#assert.eq(_blocks(_split-2.shown).len(), 2)
#assert.eq(_body-plain(_split-2.shown), "One. Two.")
#assert.eq(_body-plain(_split-2.rest), "Three.")

// A dictionary `tags:` argument must work on the QUERY side too, now that
// `_assert-tags` accepts one: MEASURED, a typst dictionary has no `.any`/`.all`,
// so `_tag-pred` normalizes `want` to keys or hard-errors.
#assert.eq(_tag-pred((draft: none), "any")((draft: none, phd: 1)), true)
#assert.eq(_tag-pred((draft: none), "any")((phd: 1)), false)
#assert.eq(_tag-pred("draft", "any")((draft: none)), true)
#assert.eq(_tag-pred(("a", "b"), "all")((a: none, b: 2, c: none)), true)
#assert.eq(_tag-pred(("a", "b"), "all")((a: none,)), false)
// An empty dict is no filter at all, same as an empty array.
#assert.eq(_tag-pred((:), "any"), none)
// `in` tests KEYS, so a VALUED tag is presence-filterable by name.
#assert.eq(_tag-pred("priority", "any")((priority: 1)), true)

// ---- _tag-pred — an EMPTY tags array is no filter, not match-nothing ------
#assert.eq(_tag-pred(none, "any"), none)
#assert.eq(_tag-pred((), "any"), none)
#assert(_tag-pred("phd", "any")(("phd", "draft")))
#assert(not _tag-pred("phd", "any")(("draft",)))
#assert(_tag-pred(("a", "b"), "any")(("b",)))
#assert(not _tag-pred(("a", "b"), "all")(("b",)))
#assert(_tag-pred(("a", "b"), "all")(("a", "b", "c")))

// `filter:` alone (no `tags:`) still returns a predicate rather than `none`
// — this is what lets `#window`, `ideas()` and `#ideas-outline` select by
// `filter:` with no `tagged:` given.
#assert.ne(_tag-pred(none, "any", filter: t => "phd" in t), none)
#assert(_tag-pred(none, "any", filter: t => "phd" in t)((phd: none)))
#assert(not _tag-pred(none, "any", filter: t => "phd" in t)((draft: none)))
// `tags:` and `filter:` together are an AND, not an OR: either one failing
// rejects the idea.
#assert(_tag-pred("phd", "any", filter: t => "draft" in t)((phd: none, draft: none)))
#assert(not _tag-pred("phd", "any", filter: t => "draft" in t)((phd: none)))
#assert(not _tag-pred("phd", "any", filter: t => "draft" in t)((draft: none)))

// ---- _sort-ids — date-descending, undated last, ties ASCENDING by id ------
// The tie rule is why the function groups by stamp instead of sorting twice.
#let _reg = (
  "idea:a": (created: datetime(year: 2026, month: 1, day: 2)),
  "idea:b": (created: datetime(year: 2026, month: 3, day: 4)),
  "idea:c": (created: datetime(year: 2026, month: 1, day: 2)),
  "idea:d": (:),
)
#assert.eq(
  _sort-ids(("idea:d", "idea:c", "idea:b", "idea:a"), _reg, "date"),
  ("idea:b", "idea:a", "idea:c", "idea:d"),
)
#assert.eq(
  _sort-ids(("idea:b", "idea:d", "idea:a"), _reg, "lexicographic"),
  ("idea:a", "idea:b", "idea:d"),
)

// ---- _nest-outline — a level JUMP nests, it does not become a sibling -----
// The flat run is depth-tagged; a 1 -> 3 jump must still read as a child, which
// is what makes `_prune-outline`-style rebasing necessary rather than optional.
#assert.eq(
  _nest-outline(
    ((depth: 0, id: "a"), (depth: 1, id: "b"), (depth: 3, id: "c"), (depth: 0, id: "d")),
    (items, root) => items,
    (e, sub) => (id: e.id, sub: sub),
  ),
  (
    (id: "a", sub: ((id: "b", sub: ((id: "c", sub: none),)),)),
    (id: "d", sub: none),
  ),
)

// ---- _note-file — the path mirrors the `ideas:<slug>` handle --------------
// Reads `_pfx()`, hence the `context`. Only the DEFAULT prefix is exercised:
// `_pfx` resolves `_prefix.final()`, which is document-wide, so a fixture
// cannot hold two prefixes at once — an override belongs to a demo build.
#context {
  assert.eq(_note-file("idea:etal"), "ideas/etal.html")
  assert.eq(_note-file("etal"), "ideas/etal.html")
}

// ---- idea-href / idea-path — none with no rheo context --------------------
// Neither was covered here before: this fixture compiles WITHOUT rheo (no
// `sys.inputs.rheo-context`), which is exactly the condition both must
// return `none` under, rather than a path to a page nothing minted.
#context {
  assert.eq(idea-href("etal"), none)
  assert.eq(idea-path("etal"), none)
}

// ---- _bib-keys — BibTeX headers, and the Hayagriva-YAML fallback ----------
// A KEY-EXISTENCE CHECK, not a parser: format is detected from CONTENT, because
// `bytes` carry no filename. Both branches in one call, since `_bib` is
// document-wide and its first positional may be an ARRAY of sources.
#_bib.update(arguments((
  bytes("@article{smith2020,\n  title = {A Title},\n  author = {Smith},\n}\n"),
  bytes("jones2021:\n  type: article\n  title: Another Title\n"),
)))
#context {
  assert.eq(_bib-keys(), ("smith2020", "jones2021"))
}

// ---- _cite-scan / _outbound — a `#footnote`'s body is a metadata payload ---
// A `#footnote` stores its body inside `metadata((rookery-fn: body))`, and both
// walks descend into it rather than stopping at metadata that is not a window
// marker: an idea whose only citation sits in a footnote still gets its
// author-date marker and references block, and a `#window` written inside a
// footnote still registers its outbound link, so the windowed note still gets
// that backlink. Both walks share the same descent.
//
// `_own-cited-keys` filters against `_bib-keys()`, so these run after the
// `_bib.update` above.
#context {
  let cited = [Prose #footnote[A note citing @smith2020.] and more prose.]
  assert.eq(_cite-scan(cited), ((kind: "cite", key: "smith2020"),))
  assert.eq(_own-cited-keys(cited), ("smith2020",))

  // Counted once. The payload is the only place the citation is seen: the
  // rendered footnote `_footnoted` appends is never scanned again.
  assert.eq(_cite-scan(cited).len(), 1)

  // A nested idea still claims its own. The outer body keeps the key from ITS
  // footnote and none from the inner one, which renders its own block.
  let nested = [
    Outer #idea("units-fn-inner")[Inner #footnote[cites @smith2020.]]
    tail #footnote[cites @jones2021.]
  ]
  assert.eq(_own-cited-keys(nested), ("jones2021",))

  assert.eq(_outbound([See #footnote[#window("etal")] here.]), ("idea:etal",))
}

// ---- _resolve-tags-color — dict validation and normalisation ------
// String shorthand -> background-only dict
#assert.eq(_resolve-tags-color((draft: rgb("#ff0000"))), (draft: (background: "#ff0000")))
// CSS colour string shorthand
#assert.eq(_resolve-tags-color((note: "#00ff00")), (note: (background: "#00ff00")))
// Dict form with both keys
#assert.eq(
  _resolve-tags-color((todo: (background: rgb("#0000ff"), text: rgb("#ffffff")))),
  (todo: (background: "#0000ff", text: "#ffffff")),
)
// Dict form, text only
#assert.eq(_resolve-tags-color((warn: (text: "#000"))), (warn: (text: "#000")))
// Dict form, background only (via dict)
#assert.eq(_resolve-tags-color((info: (background: rgb("#ffff00")))), (info: (background: "#ffff00")))
// Multiple tags
#assert.eq(
  _resolve-tags-color((
    draft: rgb("#ff0000"),
    note: (background: rgb("#00ff00"), text: "#ffffff"),
  )),
  (
    draft: (background: "#ff0000"),
    note: (background: "#00ff00", text: "#ffffff"),
  ),
)
// A KEY IS A SELECTOR, so the key is checked against the CSS-identifier shape a
// generated `.idea-tag-<tag>` rule needs. Hyphens and underscores are the two
// separators a real tag actually uses, and both are legal INSIDE a name; an
// underscore is legal as the first character too, a digit is not.
#assert.eq(
  _resolve-tags-color(("in-progress": rgb("#ff0000"))),
  ("in-progress": (background: "#ff0000")),
)
#assert.eq(_resolve-tags-color((my_tag: "#0f0")), (my_tag: (background: "#0f0")))
// NO NEGATIVE CASES HERE, and that is the harness rather than an oversight: a
// failed `assert` aborts the whole compile, and this fixture has no
// `#assert.fails` to catch one. A rejected key is exercised by hand instead —
// `tags-color: ("my tag": rgb("#f00"))` in demo/pure/root.typ fails the build
// with the message naming the key.

// ---- _split-tag-list — one `--input` value as tag names --------------------
// A `sys.inputs` value is ALWAYS a string, so a LIST of tags arrives as one
// string. Commas and whitespace in any mixture, because a caller should not
// have to know which spelling this package parses.
#assert.eq(_split-tag-list("a, b  c"), ("a", "b", "c"))
#assert.eq(_split-tag-list("a,b,c"), ("a", "b", "c"))
#assert.eq(_split-tag-list("solo"), ("solo",))
// `none` is an ABSENT key, and the empty string is an empty value — both mean
// "no tags", never one tag whose name is the empty string. Such a tag is one no
// note can carry while every note could be tested against it.
#assert.eq(_split-tag-list(none), ())
#assert.eq(_split-tag-list(""), ())
#assert.eq(_split-tag-list(" , "), ())
// A trailing comma and a doubled separator are harmless for the same reason.
#assert.eq(_split-tag-list("a,,b,"), ("a", "b"))

// ---- _resolve-excluded — declared UNION exclude MINUS include --------------
// With no `--input` given (which is how `just test` compiles this fixture), the
// result is the declared list and nothing else. `test/inputs.typ` is the
// fixture that exercises the two `sys.inputs` keys, because they cannot be set
// from here.
#assert.eq(_resolve-excluded(none), ())
#assert.eq(_resolve-excluded(()), ())
// The SAME four forms `#idea`'s `tags:` takes, since this routes through
// `_norm-tags` — so `exclude-tags: "private"` needs no array ceremony.
#assert.eq(_resolve-excluded("x"), ("x",))
#assert.eq(_resolve-excluded(("x", "y")), ("x", "y"))
#assert.eq(_resolve-excluded((x: none, y: none)), ("x", "y"))
// A VALUED tag excludes exactly as a plain one does: the names are the keys, and
// a tag carrying metadata is no less a tag (the rule `cls` in idea.typ follows).
#assert.eq(_resolve-excluded((x: (owner: "me"))), ("x",))
// Deduped, so a tag named twice is one tag.
#assert.eq(_resolve-excluded(("x", "x")), ("x",))

// ---- _derived-title — a titleless note names itself by its body -------------
// An EMPTY body derives nothing and stays `none`: `#idea("x")[]` has no text to
// name itself with, and `""` would put an empty `.idea-title` span in the
// heading, defeating the `h*.idea:empty` rules that exist to collapse it.
#assert.eq(_derived-title([]), none)
#assert.eq(_derived-title(none), none)
// Under the limit: the body verbatim, no ellipsis.
#assert.eq(_derived-title([Short body.]), "Short body.")
// EXACTLY at the limit is not over it — an off-by-one here appends `...` to a
// title that was already complete.
#assert.eq(_derived-title([#("a" * 60)]), "a" * 60)
#assert.eq(_derived-title([#("a" * 61)]), "a" * 60 + "...")
// Whitespace collapses first (via `_body-plain`), so a multi-block body arrives
// as one clean line rather than carrying the source's own line breaks.
#assert.eq(_derived-title([A.#parbreak()B.]), "A. B.")
#assert.eq(
  _derived-title[
    - one
    - two
  ],
  "one two",
)
// NON-ASCII MUST NOT PANIC, and must count as CHARACTERS rather than bytes.
// `str.slice` takes byte offsets and hard-errors mid-character, which is why
// `_derived-title` slices `.clusters()`; each of these is >60 bytes and <=60
// clusters, so a byte-based slice would either panic or truncate early.
#assert.eq(_derived-title([héllo wörld]), "héllo wörld")
#assert.eq(_derived-title([#("é" * 40)]), "é" * 40)
#assert.eq(_derived-title([#("é" * 61)]), "é" * 60 + "...")
// The limit is a parameter for these tests only — `#idea` never passes one.
#assert.eq(_derived-title([abcdef], limit: 3), "abc...")
// TRUNCATION HAPPENS AFTER RESOLUTION: a reference's target name is as much of
// the sixty characters as any other word, so cutting first would give one
// derived name with a registry and a differently-cut one without.
#assert.eq(
  _derived-title-with([Write #ref(<idea:x>) post], it => "b" * 60),
  "Write " + "b" * 54 + "...",
)

// ---- _plain / _body-text — a smart quote is its own element ----------------
// A `smartquote` renders as its ASCII form in plain text (see the sibling
// banner in `pure.typ` on `_plain-with`'s own `smartquote` branch): every
// apostrophe and quotation mark survives in a note's plain text, which is
// what search matches against. ASCII rather than the curly glyph, because
// open-vs-close depends on position and the element carries only `double`.
#assert.eq(_plain([Anil's]), "Anil's")
#assert.eq(_plain([Read "this"]), "Read \"this\"")
#assert.eq(_plain([Read Anil's 'Rumour is the exploit']), "Read Anil's 'Rumour is the exploit'")
#assert.eq(_body-plain([He said "no" and Anil's reply]), "He said \"no\" and Anil's reply")
// Mixed with markup the walk already handled, so the new branch composes rather
// than short-circuiting the others.
#assert.eq(_body-plain([A #raw("x") isn't B]), "A x isn't B")

// ---- tag-index — a declared projection, flattened to SCALARS --------------
// The scalar rule is the contract, so it is tested by its refusals as much as by
// its results: a projected value must be safe to encode as JSON or as an HTML
// attribute, and the only thing that guarantees that is the assert.
#let _tags-a = (
  "cycle-26-27": none,
  "venue-postdoc": none,
  "date-deadline": datetime(year: 2026, month: 11, day: 1),
)
#let _spec = (
  cycle: (family: "cycle-"),
  kind: (family: "venue-", one-of: ("postdoc", "tenuretrack")),
  deadline: (key: "date-deadline", stamp: true),
)
#assert.eq(
  _project(tag-index(_spec), _tags-a),
  (cycle: "26-27", kind: "postdoc", deadline: "20261101"),
)
// A note carrying none of the tags projects `none` per field — an ABSENT fact,
// not a missing key, so a consumer reads `r.cycle == none` rather than probing.
#assert.eq(
  _project(tag-index(_spec), (:)),
  (cycle: none, kind: none, deadline: none),
)
// `one-of:` ORDERS the family, which is what makes two members of one family
// resolve deterministically — tags are unordered as of 0.5.0.
#assert.eq(
  _project(
    tag-index((kind: (family: "venue-", one-of: ("tenuretrack", "postdoc")))),
    ("venue-postdoc": none, "venue-tenuretrack": none),
  ),
  (kind: "tenuretrack"),
)
// `from:` — a COMPUTATION over the tag dictionary, the only way a value that
// cannot ride on a row (an array, a log) becomes filterable.
#assert.eq(
  _project(
    tag-index((n: (from: t => t.keys().len()))),
    _tags-a,
  ),
  (n: 3),
)
// A dateless field with `stamp: true` stays none rather than panicking: absence
// is not a type error.
#assert.eq(_project(tag-index((d: (key: "nope", stamp: true))), _tags-a), (d: none))
// `_project(none, ..)` is the no-index case and merges into nothing.
#assert.eq(_project(none, _tags-a), (:))

// ---- #ideate's three pure predicates -------------------------------------
//
// `#ideate` itself cannot be asserted here — this fixture compiles to a PAGED
// target, where it is a deliberate passthrough — but the decisions that shape
// its output are pure functions of one content value, so they can be.
//
// `_blank`: the whitespace children a `[..]` body carries at its edges, which
// would otherwise mint an empty note per block.
#assert(_blank([ ]))
#assert(_blank(text("   ")))
#assert(not _blank(text("word")))
#assert(not _blank(heading(depth: 2)[A heading]))
// A PARBREAK IS BLANK, and heading mode is what needs it: there a parbreak is
// ordinary content, so the blank line before a body's first `==` forms a group
// of one parbreak, and that group is blank rather than minting a note holding
// nothing but a paragraph break. In parbreak mode the separator never lands
// inside a group, so this changes nothing there.
#assert(_blank(parbreak()))
#assert(_heading-only((parbreak(), heading(depth: 2)[A heading])))

// `_inert`/`_no-content`: rheo appends a trailing `context` child to every page
// body, which renders nothing yet is not whitespace, so `_no-content` treats
// it as inert rather than as a note's own body. Such a group is emitted
// unwrapped, never dropped: the postamble has to survive.
#assert(_inert([#context none]))
#assert(_inert(metadata(1)))
#assert(not _inert(text("word")))
#assert(not _inert(heading(depth: 2)[A heading]))
#assert(_no-content(([#context none], [ ])))
#assert(_no-content((metadata(1), parbreak())))
#assert(not _no-content(([#context none], text("word"))))

// `_level-of`: a markup heading carries `depth` and no `level`, while a
// `separator:` spec written `heading(level: 2)[]` carries `level` and no
// `depth`. One helper reads both sides or the comparison matches nothing.
#assert.eq(_level-of(heading(depth: 2)[Markup two]), 2)
#assert.eq(_level-of(heading(depth: 3)[Markup three]), 3)
#assert.eq(_level-of(heading(level: 2)[Explicit two]), 2)
#assert.eq(_level-of(heading(level: 2)[]), 2)

// `_sel-level`: the bracket-free `heading.where(level: 2)` spelling. A selector
// has NO accessors — `.at("level")` is `type selector has no method 'at'` — so
// its level can only be read out of `repr()`. These assertions are what make
// that parse safe: a Typst release that changes `repr`'s format fails here,
// rather than silently mis-splitting somebody's document.
#assert.eq(_sel-level(heading.where(level: 1)), 1)
#assert.eq(_sel-level(heading.where(level: 2)), 2)
#assert.eq(_sel-level(heading.where(depth: 3)), 3)
#assert.eq(_sel-level(heading.where(level: 10)), 10)

// `_heading-only`: a group that is nothing but a heading is structure, not a
// note. Surrounding whitespace does not change that; a heading with prose
// beside it in the same group is an ordinary group and does become a note.
#assert(_heading-only((heading(depth: 2)[A heading],)))
#assert(_heading-only(([ ], heading(depth: 2)[A heading], [ ])))
#assert(not _heading-only((text("prose"),)))
#assert(not _heading-only((heading(depth: 2)[A heading], text("prose"))))
#assert(not _heading-only(()))
// `want:` — AN EMPTY SECTION IS STILL A NOTE. In heading mode the separator
// heading starts its own group, so a group holding nothing but a heading of
// THAT level is a section an author has not filled in yet, and minting it is
// what keeps a chapter's note set equal to its heading set: a stub `== Title`
// stays in `#ideas()`, and so in every pinboard and outline. A heading of any
// other level alone remains structure.
#assert(not _heading-only((heading(depth: 2)[Empty section],), want: 2))
#assert(not _heading-only(([ ], heading(depth: 2)[Empty section], parbreak()), want: 2))
#assert(_heading-only((heading(depth: 1)[Part One],), want: 2))
#assert(_heading-only((heading(depth: 3)[A subsection],), want: 2))

// ---- _slug — a heading's plain text as a URL-safe name ---------------------
//
// `#ideate`'s `name: heading` sentinel names a note after the slug of the
// heading that starts it, so an id survives inserting or reordering sections.
//
// Ordinary words: lowercased, spaces collapsed to single hyphens.
#assert.eq(_slug("The Art of Computer Programming"), "the-art-of-computer-programming")
// Mixed case throughout, not only a leading capital.
#assert.eq(_slug("WEB and the two tangles"), "web-and-the-two-tangles")
// Punctuation becomes a hyphen, and a RUN of it collapses to exactly one —
// two separate punctuation marks must not leave a double hyphen behind.
#assert.eq(_slug("Fuzzy search: ranking, scoring & sorting"), "fuzzy-search-ranking-scoring-sorting")
// Leading and trailing punctuation is TRIMMED, not turned into a leading or
// trailing hyphen.
#assert.eq(_slug("--Leading and trailing--"), "leading-and-trailing")
#assert.eq(_slug("  Padded with spaces  "), "padded-with-spaces")
// A heading of nothing but punctuation panics rather than slugging to the
// empty string — a caller error, not a silent id. Not asserted here: a panic
// aborts the whole compile, so this file's `assert.eq` harness (which needs
// the compile to finish) cannot observe one — see this file's own header.

// ---- slug — public function to slug content or strings ---------------------
//
// `slug` takes raw content (like a heading's body) or a string and returns the
// URL-safe slugged form, the same as `_slug` but accepting content directly.
#assert.eq(slug([Waterline]), "waterline")
#assert.eq(slug([Week 37: Intro]), "week-37-intro")
#assert.eq(slug("already a string"), "already-a-string")

// ---- _id-slug — pins the title-derived note id contract --------------------
//
// Unlike the section above, these pin a new contract rather than guard a
// regression: `_id-slug` returns `none` (not a panic) wherever a title cannot
// safely name a note, so callers fall back to the counter.
//
// Ordinary words slug the same way `_slug` does.
#assert.eq(_id-slug("My Title"), "my-title")
// A run of punctuation still collapses to one hyphen.
#assert.eq(_id-slug("Fuzzy search: ranking & scoring"), "fuzzy-search-ranking-scoring")
// Pure punctuation slugs to nothing — `none`, not a panic.
#assert.eq(_id-slug("!!!"), none)
// The empty string is the same case.
#assert.eq(_id-slug(""), none)
// A purely-numeric slug is refused: it would collide with the unnamed-note
// counter's own namespace (`1`, `2`, `3`, …).
#assert.eq(_id-slug("42"), none)
// Numeric text mixed with words is not purely numeric, so it is kept.
#assert.eq(_id-slug("Chapter 42"), "chapter-42")
// A slug longer than the cap is truncated to exactly `limit` characters.
#assert.eq(_id-slug("a" * 80).len(), 60)
// The cap is configurable per call.
#assert.eq(_id-slug("abc", limit: 2), "ab")

// ---- _name-slug — content-derived slug for a note's third naming rung -----
//
// A string beginning with a URL scheme is special-cased to the URL's own
// tail, not its host: a reading list of bare links needs its distinguishing
// part, which is the LAST meaningful path segment, not the domain every
// entry shares.
//
// A purely-numeric path segment ("2026", "09", "11" from a dated blog URL)
// is dropped before taking the tail, and a trailing `.html`-style extension
// is stripped from each segment first. With the numeric date segments gone,
// the tail is "a-severe-misalignment"; the leading stopword "a" is then
// dropped by the same rule as the next case, and "misalignment" does not
// fit within the default 16-character limit once "severe" is already
// there, so it is left off rather than truncated mid-word.
#assert.eq(_name-slug("https://terrytao.wordpress.com/2026/09/11/a-severe-misalignment/"), "severe")
// A tail with no trailing date segments keeps its whole self, as long as it
// fits the limit — "unikernels" alone is well under 16 characters.
#assert.eq(_name-slug("https://anil.recoil.org/projects/unikernels"), "unikernels")
// A tail on the day-numbered rather than date-numbered case: "2024" is not
// dropped (only ^[0-9.]+$ PATH SEGMENTS are, not words inside a segment that
// survives), so the words are "2024", "hope", "bastion" — but the joined
// tail is 17 characters, over the default limit, so the whole-word cutoff
// keeps only "2024-hope" and leaves "bastion" off.
#assert.eq(_name-slug("https://anil.recoil.org/papers/2024-hope-bastion"), "2024-hope")
// A non-URL sentence: the leading stopword "the" is dropped, then the
// result keeps whole words up to the 16-character limit.
#assert.eq(_name-slug("The scorer lives in score.typ"), "scorer-lives-in")
// A string that mentions "https"/"www" as ordinary words, not a scheme
// (no "://"), skips the URL substitution entirely — but each of "https" and
// "www" is still dropped as a leading scheme-shaped word, one at a time,
// leaving the first ordinary word.
#assert.eq(_name-slug("https www example"), "example")
// The empty string has no words to keep.
#assert.eq(_name-slug(""), none)
// A purely-numeric result is refused, the same rule `_id-slug` applies.
#assert.eq(_name-slug("12345"), none)

// ---- _h3 / _b36 — the content-digest half of the naming ladder ------------
//
// `_h3` always returns exactly three characters, regardless of input.
#assert.eq(_h3("abc").len(), 3)
// Deterministic: the same string hashes the same way every time.
#assert.eq(_h3("abc"), _h3("abc"))
// `_b36` pads a small number out to the requested width with leading zeros.
#assert.eq(_b36(0, 3), "000")

// ---- _ideate-tag-value — extract tag value from `#ideate-tag` beacon -------
//
// A beacon carries `metadata` with a dictionary value holding `rookery-ideate-tags`.
// The predicate returns the raw payload value (caller normalizes with `_norm-tags`),
// or `none` for non-beacons.
#assert.eq(_ideate-tag-value([#metadata((rookery-ideate-tags: "rookery"))]), "rookery")
// Array of tag strings.
#assert.eq(_ideate-tag-value([#metadata((rookery-ideate-tags: ("a", "b")))]), ("a", "b"))
// Plain metadata with different key: not a beacon.
#assert.eq(_ideate-tag-value([#metadata((other: 1))]), none)
// Non-metadata content: not a beacon.
#assert.eq(_ideate-tag-value([text]), none)

// ---- _ideate-name-value — extract name value from an `#ideate-name` beacon ------
//
// Mirrors `_ideate-tag-value` exactly, over the `rookery-ideate-name` key.
#assert.eq(_ideate-name-value([#metadata((rookery-ideate-name: "fixed-name"))]), "fixed-name")
// Plain metadata with a different key: not a name beacon.
#assert.eq(_ideate-name-value([#metadata((other: 1))]), none)
// A tag beacon is not a name beacon, and vice versa — the two keys are read
// independently, so a section can carry both without either shadowing the
// other.
#assert.eq(_ideate-name-value([#metadata((rookery-ideate-tags: "rookery"))]), none)
// Non-metadata content: not a beacon.
#assert.eq(_ideate-name-value([text]), none)

// ---- _resolve-display — merges a `display:` dict with `display-*` flags ---
//
// All eleven keys are always present, `auto` where nobody had an opinion.
#assert.eq(_resolve-display((:), (:), "#t").len(), 11)
#assert.eq(_resolve-display((:), (:), "#t").frame, auto)
// The dictionary supplies a value.
#assert.eq(_resolve-display((frame: false), (:), "#t").frame, false)
// An individual flag WINS over the dictionary.
#assert.eq(_resolve-display((frame: false), (frame: true), "#t").frame, true)
// A flag left `auto` does NOT override the dictionary.
#assert.eq(_resolve-display((frame: false), (frame: auto), "#t").frame, false)
// `auto` is a legal dictionary value and stays `auto`.
#assert.eq(_resolve-display((title: auto), (:), "#t").title, auto)
// Keys nobody mentioned are still present and still `auto`.
#assert.eq(_resolve-display((frame: false), (:), "#t").backlinks, auto)
// An unknown key in `dict` panics rather than passing through silently — not
// asserted here: a panic aborts the compile, so this file's `assert.eq`
// harness cannot observe one (see this file's own header).
// A dictionary value that is neither `true`, `false` nor `auto` panics the
// same way, for the same reason.
