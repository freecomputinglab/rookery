// `#panel` — a filter-and-sort widget over a `tag-index` projection.
//
// WHY IT IS HERE AND NOT IN CORE. @rookery/core ships no JavaScript at all, and
// this repo's CLAUDE.md records that as deliberate: "search is only worth having
// with JavaScript, and rookery is the one package here that ships none", which is
// why search was split out in the first place. A panel is the same case, and this
// package already has the vite build, the fuzzy scorer and an import of rookery.
//
// WHAT IT REPLACES. One fuzzy subsequence scorer was being written three times
// across two packages and a consuming site — `src/score.js` here,
// `todo-search.js` in @rookery/todos, and a site's own hand-rolled copy
// whose comment said outright that it was "Ported from `todo-search.js`" — with
// three near-identical Typst halves above them, each existing because
// `#todos-search` renders its pill row internally with no hook to add a facet to.
// A panel closes both gaps: facets are DECLARED, and a derived value reaches a
// facet through a projection.
//
//   #let INDEX = tag-index((sort: (family: "sort-"), state: (from: ..)))
//   #panel(
//     rows: ideas(tags: "submission", index: INDEX),
//     facets: ("sort", "state"),
//     sort: "deadline",
//     visible: 5,
//     render: r => [#r.label],
//   )
//
// NO JSON ISLAND, and this is a rule rather than an implementation detail. Every
// faceted or searched field rides as a `data-<field>` attribute on the row
// carrying it, so the payload and the markup cannot disagree — and with no
// JavaScript the rendering is a complete readable list rather than an empty
// container waiting to be filled. The projection's scalar guarantee is exactly
// what makes that generic instead of hand-written per widget.
//
// ONE FACET MAY HOLD A SET rather than a value — `multi: ("tag",)` — and that is the
// one departure from the scalar rule, made where the rule was costing a whole kind of
// pill. A note's tags are not a scalar, and the only pill row that could offer them
// was `#filter-panel`'s tag mode, which has no groups at all. Such a field rides as a
// space-padded token list and its group ORs like any other, so a tag group composes
// with the scalar ones instead of replacing them. Everything else still asserts.
//
// PANELS TAKE AN INDEX, THEY NEVER BUILD ONE. A page builds one projection and
// passes the projected rows to everything on it. A self-building panel would put
// back the per-view walk of the value store that `tag-index` exists to remove.

#import "base.typ": *

// The scalar rule, policed HERE rather than at the accessor. `ideas(values: true)`
// may legitimately carry arbitrary values for Typst-side rendering — a datetime to
// format, content to place — and this is the boundary where such a value would
// otherwise be stringified into an HTML attribute and read back as nonsense.
#let _attr(field, value) = {
  if value == none { return "" }
  assert(
    type(value) in (str, int, float, bool),
    message: "@rookery/search: panel field `"
      + field
      + "` holds "
      + repr(type(value))
      + ", which cannot become an HTML attribute. A faceted or sorted field must be "
      + "a scalar — project it through `tag-index(..)` first, and note that "
      + "`ideas(values: true)`'s `tags-dict` is for Typst-side rendering only.",
  )
  if type(value) == bool { if value { "true" } else { "false" } } else { str(value) }
}

// A MULTI-VALUED FACET'S ATTRIBUTE — the values joined and PADDED WITH A SPACE AT
// BOTH ENDS, which is the shape `#filter-panel`'s own `data-panel-tags` has taken
// since it shipped. Same shape, so `panel.js` tokenizes both with one line and the
// padding keeps a substring test from half-matching a value that is another's prefix.
//
// A VALUE MAY NOT CONTAIN WHITESPACE, asserted rather than escaped: a space would
// split one value into two tokens, and the pill for the half neither matches anything
// nor says why. A tag or a projected key never has one; a label might, and the caller
// wanting labels as pills wants a slug beside them.
//
// EMPTY IS `""` rather than a lone space, so a row carrying none of the facet's values
// emits the same empty attribute a scalar facet does.
#let _multi-attr(field, values) = {
  if values == none { return "" }
  assert(
    type(values) == array,
    message: "@rookery/search: panel field `"
      + field
      + "` is declared in `multi:`, so it must hold an ARRAY of scalars — got "
      + repr(type(values))
      + ". A single-valued facet does not belong in `multi:`.",
  )
  if values.len() == 0 { return "" }
  let out = values.map(v => _attr(field, v))
  for v in out {
    assert(
      v.split(" ").len() == 1 and v.split("\n").len() == 1 and v.split("\t").len() == 1,
      message: "@rookery/search: panel field `"
        + field
        + "` is multi-valued, so its values ride in ONE space-separated attribute — "
        + "and " + repr(v) + " carries whitespace, which would split it into two "
        + "tokens the pills cannot match. Project a slug instead.",
    )
  }
  " " + out.join(" ") + " "
}

// One pill per value ANY LISTED ROW ACTUALLY HAS, never per value the vocabulary
// permits: a pill for a value nothing carries is a filter that could only ever
// return nothing. Values are sorted so the pill row is stable across builds —
// `ideas()` is ordered by id, but the set of values a facet takes is not.
//
// A MULTI-VALUED FIELD IS FLATTENED FIRST, so the group offers the UNION of what the
// listed rows carry — which is the whole point of such a facet: a value nothing
// carries has no pill, and a value one new row introduces gets one with no vocabulary
// declared anywhere.
#let _facet-values(rows, field, multi: false) = {
  let vals = rows.map(r => r.at(field, default: none))
  let vals = if multi {
    vals.map(v => if v == none { () } else { v }).flatten()
  } else { vals }
  vals
    .filter(v => v != none and v != "")
    .map(v => _attr(field, v))
    .dedup()
    .sorted()
}

#let panel(
  rows: (),
  // Projected field names to offer as pill groups, in the order given. Each
  // becomes one group of `aria-pressed` buttons.
  facets: (),
  // WHICH OF THOSE FACETS HOLD A SET RATHER THAN A VALUE. A field named here is
  // projected as an ARRAY of scalars, gets one pill per distinct value ANY listed row
  // carries, and a row survives the group if it carries ANY pressed value.
  //
  // WHY IT IS A SEPARATE LIST rather than inferred from the projected type: a facet
  // whose rows happen to be single-element arrays would silently switch predicates,
  // and the JS half has to be told which attributes to tokenize before it reads the
  // first row. Declared once, both halves agree.
  //
  // WHAT IT BUYS. A scalar facet can only ask "which one is it" — one epic, one sort,
  // one state. A note's TAGS are not that shape, and `#filter-panel`'s tag mode, which
  // is, has a single undifferentiated pill row and no groups. This is the missing
  // third case: a tag group that composes with the scalar ones beside it under the
  // ordinary group rules, rather than replacing them. HOW it composes with them is
  // `union:` below — this argument only says the group holds a set.
  multi: (),
  // WHICH GROUPS ANSWER ONE QUESTION, and therefore OR WITH EACH OTHER rather than
  // ANDing. Every other group composes as it always did: a row must satisfy each of
  // them, and — if any group named here has a pill pressed — at least ONE of these.
  //
  //   union: ("epic", "tag"),
  //
  // WHY IT IS NEEDED AT ALL, given "OR within, AND across" is the rule this widget was
  // written around. That rule is right when each group asks a DIFFERENT question: a
  // state and a priority narrow together and a reader pressing both means the
  // conjunction. It is wrong when one question arrives as two projections. @rookery/todos
  // splits what a todo is ABOUT into `epic` and `tag` — a todo carrying `epic-rheo`
  // never also gets a `rheo` pill in the tag group, since the epic group already says it
  // — so `rheo` and `birds`, two subjects sitting side by side on one line, ANDed into
  // an empty list on every corpus anyone has. The reader's reading of two subject pills
  // is "either", and that is what this declares.
  //
  // NOT A REPLACEMENT FOR `multi:`, which is about one group holding a SET per row. A
  // multi-valued group already ORs internally; this says how a group composes with the
  // groups BESIDE it, and the two are freely combined — @rookery/todos' `tag` group is
  // both.
  //
  // WHY NOT MERGE THE GROUPS INSTEAD. Because they are genuinely two: they are derived
  // differently (one off `epic-*`, one off the flat keys), they chip differently, and a
  // reader wants the epics gathered rather than strewn through an alphabetical tag row.
  // What was wrong was never the grouping, only the composition — so only the
  // composition is declared.
  //
  // A SINGLE ENTRY IS A NO-OP, by construction: one pressed union group behaves exactly
  // as it did. So this only ever changes the two-groups-pressed case.
  union: (),
  // HOW THE GROUPS ARE LAID OUT, and nothing else — which facets exist is still
  // `facets:` alone. `none` is one row holding every group, which is what this
  // function has always emitted. Otherwise an array of
  // `(label: none, facets: (..))`, one line of pills each:
  //
  //   facet-rows: (
  //     (facets: ("epic",)),
  //     (label: [todo states:], facets: ("state", "priority")),
  //   )
  //
  // WHY LAYOUT IS A SEPARATE ARGUMENT rather than nesting `facets:` itself: the
  // flat list is what a row's `data-<field>` attributes and `render:` are built
  // from, and folding presentation into it would make every caller that never
  // wanted two lines write the nesting anyway.
  facet-rows: none,
  // A projected field to order by, ascending. A date projected with
  // `stamp: true` is a zero-padded `[year][month][day]` string, so this is a
  // plain string sort in date order — see `tag-index`.
  sort: none,
  // Rows with no value for the sort field go LAST rather than first. A missing
  // date is not an early one, and an undated row floating to the top of a list
  // sorted by deadline reads as urgent when it is merely unset.
  descending: false,
  // How many rows are VISIBLE before the list scrolls. NOT a data cap: every row
  // stays in the markup. A consuming site had capped its list and hidden the
  // rest, and its own comment records why that was abandoned — it "made the box
  // a preview of the corpus rather than the corpus — you could not reach the
  // thirty-third place without narrowing the query enough to lift it into the
  // top five, and if you did not know its name you could not narrow at all".
  //
  // `none` MEANS IT DOES NOT SCROLL: the list flows down the page for as long as
  // there are matching rows. `#filter-panel` has taken this since it was written —
  // a scroll box earns its place in a widget a reader opens to find one thing, and
  // not in a page's main list, where it cuts a row in half and hides the rest behind
  // a gesture nothing advertises. This function was the odd one out, and `str(none)`
  // is what a caller trying it hit.
  visible: 8,
  // The haystack the text input filters on, per row. Defaults to the row's own
  // label, name and body — searching the BODY is what finds a note by a phrase
  // inside it rather than by its title.
  haystack: none,
  // EVERY TAG THE ROW'S NOTE CARRIES, as an adapter returning an array of names.
  // It rides as `data-panel-all-tags` so the input can take a `tags:` expression —
  // the same language the search bar takes.
  //
  // NOT THE FACETS, AND NOT THE PILLS. A facet is a projection of one question; the
  // pills are whichever values a group offers. A tag expression asks about the note
  // itself, so it needs the whole set — including the tags `tag-filter:` kept out of
  // the pill row, which is most of them on a real site.
  //
  // AN ADAPTER, because a projected row need not have kept its tags at all. The
  // default is `_row-tags`, which reads rookery's own two tag shapes, so a caller
  // may pass rows from `ideas()` or from `ideas(values: true)` and neither needs
  // to say which.
  //
  // A ROW WITH NEITHER FIELD GETS AN EMPTY SET, and therefore matches no tag
  // expression at all. That is correct rather than merely convenient: a row whose
  // tags are unknown must not pass a filter it was never tested against.
  tags: none,
  // How to draw one row. Content, free-form: this package renders the chrome and
  // the row's own markup is the site's business.
  render: r => [#r.at("label", default: r.at("name", default: ""))],
  // EXTRA CLASSES ON THE `<li>`, per row — an adapter, not a list, because the
  // classes worth adding are the row's own (`idea-tag-<tag>`) rather than the
  // panel's. Mirrors `#idea-row`'s `extra:`, and exists for the same reason
  // `#idea-row` has `attrs:`: without it a caller rendering the shared row shape
  // through `render:` cannot also wear `.idea-row`, which is the GRID
  // (`grid-template-columns: <gutter> 1fr auto auto`) and not decoration. This
  // package's own stylesheet already expects both shapes — see
  // `.panel-row:not(.idea-row)`. `#filter-panel` never needed this: it builds its
  // own `<ul>` and uses `#idea-row` AS the `<li>`.
  row-class: none,
  placeholder: "Filter",
  // Plural noun for the live count, e.g. "12 submissions".
  noun: "rows",
  empty: [Nothing here.],
) = {
  // A FACET IN `facets:` BUT IN NO ROW keeps its `data-<field>` on every row and
  // loses its pills, which is a filter the reader cannot see and cannot press —
  // the one failure mode this shape has, and invisible in the output. Checked
  // both ways, because a row naming a facet that does not exist is the same
  // typo seen from the other side.
  if facet-rows != none {
    let placed = facet-rows.map(r => r.at("facets", default: ())).flatten()
    for f in facets {
      assert(
        placed.contains(f),
        message: "@rookery/search: #panel's facet `" + f + "` is in `facets:` but "
          + "in no `facet-rows:` entry, so it would render no pills at all. Put it in "
          + "a row, or drop it from `facets:`.",
      )
    }
    for f in placed {
      assert(
        facets.contains(f),
        message: "@rookery/search: #panel's `facet-rows:` names `" + f + "`, which "
          + "is not in `facets:` — nothing projects it, so it has no values to offer.",
      )
    }
  }

  // SAME TYPO, THE THIRD WAY ROUND. A `multi:` entry that no facet matches would
  // tokenize an attribute nothing emits, which is silent in the output exactly like
  // the `facet-rows:` mismatch above.
  for f in multi {
    assert(
      facets.contains(f),
      message: "@rookery/search: #panel's `multi:` names `" + f + "`, which is not in "
        + "`facets:` — nothing projects it, so it has neither pills nor an attribute.",
    )
  }

  // SAME TYPO, THE FOURTH WAY ROUND, and this one is the quietest of the lot: a `union:`
  // entry naming no facet changes the composition of nothing at all, so the panel renders
  // correctly and goes on ANDing the two groups the caller meant to join.
  for f in union {
    assert(
      facets.contains(f),
      message: "@rookery/search: #panel's `union:` names `" + f + "`, which is not in "
        + "`facets:` — there is no group by that name to compose with anything.",
    )
  }

  // A SET CANNOT BE AN ORDER. `sort:` is compared as one padded string per row, so a
  // multi-valued field there would sort by its first value and read as arbitrary.
  //
  // `repr`, NOT `str`: an `assert` message is evaluated whether or not the condition
  // holds, and `str(none)` PANICS — "expected integer, float, .. found none", with no
  // mention of this assertion or of `sort:`. The default `sort: none` would have hit it
  // on every panel that orders by nothing, which is most of them. Same trap the
  // `visible:` comment below records a caller falling into.
  assert(
    sort == none or not multi.contains(sort),
    message: "@rookery/search: #panel's `sort:` is " + repr(sort) + ", which is also "
      + "in `multi:` — a field holding a SET has no single value to order rows by. "
      + "Project a scalar to sort on.",
  )

  let hay = if haystack != none { haystack } else { _row-haystack }

  // `_row-tags` reads rookery's two tag shapes, preferring `tags-dict` — which is
  // what makes a `@rookery/todos` row, which always carries one, work without a
  // caller saying so.
  let tags-of = if tags != none { tags } else { _row-tags }

  let rows = if sort == none { rows } else {
    // `\u{ffff}` sorts after every ordinary character, which puts the unset rows
    // last in one comparison rather than needing a second partition. The same
    // string-key device the date stamps use, for the same reason.
    let key = r => {
      let v = r.at(sort, default: none)
      if v == none { "\u{ffff}" } else { _attr(sort, v) }
    }
    let s = rows.sorted(key: key)
    if descending { s.rev() } else { s }
  }

  // PAGED/EPUB: there is no input to type into and no pill to press, so the same
  // rows render as an ordinary list. Every view in this package takes this branch
  // for the same reason.
  if target() != "html" {
    if rows.len() == 0 { return text(gray, emph(empty)) }
    return list(..rows.map(render))
  }

  if rows.len() == 0 {
    return html.elem("p", attrs: (class: "panel-empty"), empty)
  }

  let pill(field, value) = html.elem(
    "button",
    attrs: (
      type: "button",
      class: "panel-pill",
      "data-panel-facet": field,
      "data-panel-value": value,
      "aria-pressed": "false",
    ),
    value.replace("-", " "),
  )

  html.elem(
    "div",
    attrs: (
      // `panel-flow` IS THE UNCAPPED CASE, as a class rather than as an absent custom
      // property: CSS cannot test whether `--panel-rows` was set, so the stylesheet
      // needs something positive to hang "no max-height" on. Same device, same class,
      // as `#filter-panel`.
      class: if visible == none { "panel panel-flow" } else { "panel" },
      // `false` until the script has wired itself up. The stylesheet hides the
      // input, the pills and the scroll cap while it says so, which is how the
      // widget degrades: with no JavaScript the chrome that would do nothing
      // never appears, and what is left is an ordinary complete list.
      "data-panel-ready": "false",
      // WHICH ATTRIBUTES HOLD A SET, for the script — the one thing it cannot read off
      // the markup, a padded `" a b "` and a scalar `"a b"` being indistinguishable
      // once written. Absent when no facet is multi-valued, so an older page's markup
      // reads exactly as it always did.
      ..if multi.len() == 0 { (:) } else { ("data-panel-multi": multi.join(" ")) },
      // WHICH GROUPS OR WITH EACH OTHER — see `union:`. Emitted only when declared, so
      // a panel that never asked for it carries the markup it always did and the script
      // reads the plain AND.
      ..if union.len() == 0 { (:) } else { ("data-panel-union": union.join(" ")) },
      // The visible height goes to CSS as a custom property rather than as a
      // rule, so the number lives once, here, in the call that sets it.
      ..if visible == none { (:) } else { (style: "--panel-rows: " + str(visible)) },
    ),
    {
      html.elem(
        "input",
        attrs: (
          class: "panel-input",
          type: "search",
          placeholder: placeholder,
          "aria-label": placeholder,
          autocomplete: "off",
        ),
      )
      let group(f) = {
        let vals = _facet-values(rows, f, multi: multi.contains(f))
        html.elem(
          "span",
          attrs: (class: "panel-pill-group", "data-panel-group": f),
          vals.map(v => pill(f, v)).join(),
        )
      }

      if facets.len() > 0 {
        html.elem(
          "div",
          attrs: (class: "panel-pills", role: "group", "aria-label": "Refine"),
          if facet-rows == none {
            facets.map(group).join()
          } else {
            // ONE `div` PER ROW, and the groups keep their own element inside it —
            // `panel.js` finds them with a DESCENDANT selector
            // (`.panel-pill-group`, `.panel-pill`), so a layer of layout between the
            // panel and its groups changes nothing about the wiring.
            facet-rows
              .map(r => html.elem(
                "div",
                attrs: (class: "panel-pill-row"),
                {
                  let l = r.at("label", default: none)
                  if l != none {
                    html.elem("span", attrs: (class: "panel-pill-label"), l)
                  }
                  r.at("facets", default: ()).map(group).join()
                },
              ))
              .join()
          },
        )
      }
      html.elem(
        "p",
        attrs: (class: "panel-count", "aria-live": "polite"),
        str(rows.len()) + " " + noun,
      )
      html.elem(
        "ul",
        attrs: (class: "panel-results"),
        rows
          .map(r => html.elem(
            "li",
            attrs: (
              (
                // `panel-row` FIRST and unconditionally: the script and the
                // stylesheet both hang off it, so a `row-class` adapter cannot
                // drop it by returning the wrong thing.
                class: (
                  ("panel-row",) + if row-class == none { () } else { row-class(r) }
                ).join(" "),
                "data-panel-text": lower(hay(r)),
                // EVERY TAG THE NOTE CARRIES, for the input's `tags:` expression.
                // Unconditional, and `""` where the note has none — a row missing the
                // attribute and a row with no tags must be indistinguishable, so the
                // script has one case rather than two.
                //
                // `_multi-attr` rather than a hand-rolled join, so the space padding
                // is the same shape `data-panel-tags` has and the script tokenizes
                // both with one line.
                //
                // NOT CASE-FOLDED HERE. `evalTagQuery` needs folded tags and the
                // script folds them at read time; folding in Typst too would put one
                // rule in two languages for one attribute.
                "data-panel-all-tags": _multi-attr("tags", tags-of(r)),
              )
                // One `data-<field>` per faceted field, on the row carrying it.
                // No JSON island: the payload IS the markup. A multi-valued field
                // rides as its padded token list rather than as one value.
                + facets
                  .map(f => (
                    "data-" + f,
                    if multi.contains(f) {
                      _multi-attr(f, r.at(f, default: ()))
                    } else { _attr(f, r.at(f, default: none)) },
                  ))
                  .to-dict()
            ),
            render(r),
          ))
          .join(),
      )
    },
  )
}
