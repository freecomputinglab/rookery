// `#todo-table` — todo rows projected into @rookery/search's `#panel`, with the
// facets only this package can derive.
//
// `ready` AND `blocked` COME FROM `graph.typ` AND NOWHERE ELSE, so a panel that
// cannot press them is the one thing every consuming site ends up hand-rolling —
// which is the whole reason this file is the one import edge to @rookery/search:
// `#todos-search` needs nothing from that package (see its own header for which
// half of the old rule still holds), but a panel over the todo graph does.
//
// IT DELEGATES TO `#panel`, NOT TO `#filter-panel`, and that is what buys the pill
// GROUPS. @rookery/search's own `#filter-panel` has one pill row and one
// `pill-match` for all of it, so `epic-jobs` + `todo-p0` UNION under the default
// "any" — press two, get more — and return nothing at all under "all", two epics
// being mutually exclusive. `#panel`'s facet mode composes per group, so epic, tag,
// state and priority each become their own group for free.
//
// AND THE GROUPS DO NOT ALL COMPOSE ALIKE, which is the correction this file needed
// after shipping. "Within a facet the values OR .. and across facets they AND" was
// quoted here as though it were the whole of what a reader expects, and it is not: it
// is right for the STATE line, where `ready` and `p0` ask different questions, and
// wrong for the SUBJECT line, where `epic` and `tag` are one question in two
// projections and ANDing them returns nothing. `union:` below says which line is
// which — see the argument at the `panel(..)` call.
//
// THE `tag` GROUP IS WHY `multi:` EXISTS IN @rookery/search. The other three answer
// "which one" and fit a scalar; a todo's plain tags are a SET, and a pill per tag any
// listed todo carries is the group that needs no vocabulary declared anywhere — which
// was the last thing on this panel a site had to maintain by hand. See `_tags-of`.

#import "@rookery/search:0.1.0": panel
#import "@rookery/core:0.1.0": idea-row-body
#import "@rookery/timeline:0.1.0": deadline-of, scheduled-of
// AND AS A MODULE, for `countdown`/`days-until`: the parameter below is also called
// `countdown`, and a parameter and a function of the same name cannot both be
// reachable by that name inside the panel. Same reason `#upcoming` imports its own
// `when.typ` twice.
#import "@rookery/timeline:0.1.0" as _tl
#import "target.typ": *
#import "tags.typ": *
#import "todo.typ": epic-of
#import "graph.typ": *

// SHORT AND NUMERIC, matching @rookery/search's own `_fmt-day` and
// @rookery/timeline's exactly — `27.8.26`, unpadded — so a site running two of
// these lists on one page does not show two spellings of the same kind of date.
#let _fmt-day(d) = d.display("[day padding:none].[month padding:none].[year repr:last_two]")

// The ISO form for the `datetime` attribute — zero-padded, machine-facing, and
// deliberately not what the cell shows.
#let _iso(d) = d.display("[year]-[month]-[day]")

// IS THIS DATE BEHIND US. The LADDER of bands is @rookery/timeline's `countdown()`
// and stays there; what this reads is the SIGN of the same number, which is the one
// thing that ladder folds away (overdue and due-today are both `urgent` to it). A row
// with no date, or a panel with no `today:`, is not overdue — it is unmeasured.
#let _past(d, today) = d != none and today != none and _tl.days-until(d, today) < 0

// THE STATE FACET — where the declared status and the derived one meet.
//
// `status-of` (tags.typ) deliberately never answers "blocked": that is a question
// about the graph, and it says so. `is-ready`/`is-blocked` (graph.typ) never answer
// "in-progress": that is a declared fact, and no graph can derive it. One pill group
// needs one answer, so this is the order they resolve in.
//
// `in-progress` OUTRANKS `ready`, and that is the whole reason it is here rather than
// folded into `ready`: org-mode's STRT names the same distinction, and "someone is
// already on it" is the more useful thing to read off a list of what to pick up.
//
// The last rung is `scheduled` rather than `deferred`: it names the MECHANISM — a
// `scheduled` stage dated after `today` — and leaves `deferred` to mean what
// `status-of` already makes it mean, a todo declared as put off.
// THE GROUPS THAT ASK WHAT A TODO IS ABOUT, as against how far along it is. They are
// one question in two projections, so they OR with each other where `state` and
// `priority` AND — see the `union:` argument passed below.
#let _SUBJECT = ("epic", "tag")

// THE FACETS THAT HOLD A SET rather than a value, in @rookery/search's `multi:` sense.
// One entry, and it is the reason that argument exists.
#let _MULTI = ("tag",)

// EVERY PLAIN TAG A LISTED TODO CARRIES, which is the one pill group that needs no
// vocabulary at all: a tag put on one todo today has a pill tomorrow, and nothing
// anywhere declares the list. That is the whole difference from `epic`, which answers
// "which one" and can therefore be a scalar.
//
// FLAT KEYS ONLY — `tags.at(k) == none` — and that is `tags.typ`'s own three-way split
// doing its job rather than a filter invented here. Surface 1 (flat, the key encodes
// the value) is the surface that "renders as a pill"; surface 2 (VALUED) is explicitly
// the one that renders none, because its value is a date, a URL, an id, a bag of
// metadata — something to filter BY KEY, not a name a pill can wear. So `timeline-log`,
// `todo-deps` and a site's own `cfp-venue` drop out by construction, with no list of
// exceptions to keep in step with anybody's model.
//
// THREE MORE THINGS ARE DROPPED, all of them facts another group already states:
//
//   `todo` and `todo-*` — the base key and this package's own encodings. `state` and
//   `priority` decode them properly; a `todo-p0` pill beside a `p0` one is the same
//   filter twice, and a `todo` pill selects every row there is.
//
//   `epic-*` — the `epic` group IS this, decoded.
//
//   a key whose `epic-<key>` is also present. A site minting a todo under an epic
//   writes BOTH keys (the bare one so the note reads as a legible pill and searches as
//   a free tag), so without this the epic's name would appear in two groups at once —
//   and pressing it in one but not the other reads as a contradiction, groups ANDing
//   across.
//
// `keep` IS THE SITE'S OWN NARROWING, and everything above is this package's. The four
// rules above are about the DATA MODEL and hold for every rookery there is; which of a
// project's own tag FAMILIES are worth a pill is a question only that project can
// answer, and the honest answer for one of them was "not `venue-*`, not `sort-*`" —
// families that exist to be read off a row rather than pressed. So it narrows and can
// only narrow: a `keep` that returned `true` for `timeline-log` still gets no pill,
// because a valued key has no name to wear.
#let _tags-of(tags, keep: none) = {
  tags
    .keys()
    .filter(k => (
      tags.at(k) == none
        and k != TODO-KEY
        and not k.starts-with("todo-")
        and not k.starts-with("epic-")
        and ("epic-" + k) not in tags
        and (keep == none or keep(k))
    ))
}

#let _state-of(row, graph, today) = {
  if row.closed { return "closed" }
  if is-blocked(row, graph) { return "blocked" }
  if row.status == "in-progress" { return "in-progress" }
  if is-ready(row, graph, today: today) { return "ready" }
  "scheduled"
}

#let todo-table(
  // Pre-computed rows, in `todos()` shape. `none` walks the registry itself, which is
  // what a page wanting "every open todo" means.
  rows: none,
  // THE SET THE DEPENDENCY GRAPH IS BUILT FROM, where `rows:` is only the set that
  // gets LISTED. `none` (the default) means "the same as `rows:`", which is what
  // this function has always done.
  //
  // A LISTED TODO'S BLOCKER IS VERY OFTEN CLOSED, and a blocker missing from the
  // graph reads to `is-blocked` as "not blocking" — quietly promoting a blocked
  // todo to ready. A caller passing a pre-narrowed `rows:` (one epic's todos, say)
  // must pass the whole corpus too, or every row it lists comes out ready
  // regardless of what actually blocks it.
  corpus: none,
  // The reference date `is-ready` defers against. Passed through to
  // @rookery/timeline, which panics if neither this nor a document date is
  // available — NOTHING HERE CALLS `datetime.today()`, which returns 1980-01-01 under
  // a reproducible build and does not error while doing it.
  today: none,
  // The pill groups, in order. Each is a field this function projects below; a caller
  // dropping one gets a narrower panel, not a broken one.
  //
  // WHICH GROUPS EXIST, and nothing about where they sit: `pill-rows:` below declares
  // the lines. Within one line the group order is that line's own `facets:` entry.
  //
  // `tag` IS IN THE DEFAULT, and that is the point of it: every plain tag on every
  // listed todo gets a pill, so a site that invents a tag gets the filter for free
  // rather than editing a list somewhere. A caller who wants the old three drops it.
  facets: ("epic", "tag", "state", "priority"),
  // WHICH TAGS EARN A PILL, as a predicate over the tag KEY — `k => bool`, `none` for
  // all of them. It NARROWS the `tag` group and cannot widen it: this package's own
  // four rules (see `_tags-of`) are about the data model and run first regardless.
  //
  //   tag-filter: k => not k.starts-with("venue-")
  //
  // WHY A PREDICATE AND NOT A LIST OF NAMES OR PREFIXES. The group's whole value is
  // that nothing declares it — a tag written today has a pill tomorrow — and a list of
  // names to exclude is that same maintenance burden back again, one entry per tag
  // instead of per pill. What a site actually wants to exclude is a FAMILY, and the
  // families it has are its own business: `venue-*` and `sort-*` on one site, a naming
  // scheme nothing here can anticipate on the next. A predicate says it in one line
  // and needs no vocabulary from this package at all.
  //
  // NOT `filter:`, which is the row test above. A tag is not a row, and one panel may
  // well want both.
  //
  // THE SAME ARGUMENT NAME @rookery/search's own `#filter-panel` takes, deliberately.
  // The two derivations differ — that one offers every tag its rows carry, this one
  // drops the todo namespace and the epics first — but "which tags earn a pill" is one
  // question, so a site holds the predicate in one `let` and hands it to both panels
  // rather than keeping two lists in step.
  tag-filter: none,
  // THE PILL LAYOUT: one entry per line of pills, `(label: <content or none>,
  // facets: (<group names>))`, the same shape @rookery/search's `#panel` takes for
  // its own `facet-rows:` so that the two read alike.
  //
  // `label` IS OPTIONAL, and a line without one is simply a row of pills — the `tag`
  // line takes that shape, being whatever subject pills the epic group did not
  // already offer.
  //
  // WHY THREE LINES BY DEFAULT. `epic` and `tag` say what a todo is ABOUT while
  // `state` and `priority` say how far along it is, and one undifferentiated row asks
  // a reader to know which pill is which kind. The epics are a short, named
  // vocabulary worth prefacing; the tags are open-ended; the states are the other
  // question entirely.
  //
  // A ROW WHOSE FACETS ARE ALL ABSENT FROM `facets:` IS DROPPED rather than rendered
  // as a blank line, so narrowing `facets:` needs no matching edit here.
  pill-rows: (
    (label: [epic:], facets: ("epic",)),
    (facets: ("tag",)),
    (label: [todo states:], facets: ("state", "priority")),
  ),
  // WHICH ROWS ARE ROWS, before any pill is pressed. The default is the only one that
  // is always right — a closed todo is not outstanding work. A site with a second way
  // of finishing (a call answered before its deadline lapsed, say) passes its own.
  filter: none,
  // THE DATE IS AN ADAPTER, as it is in rookery-search's own panel. The default is the
  // todo-shaped one: a deadline where there is one, else the scheduled date, which is
  // the question a list of outstanding work is actually asking.
  when: none,
  // `"soonest"` (the default here, where rookery-search defaults to `"newest"`) puts
  // the earliest date first, because a deadline already behind you is the most urgent
  // thing on the page. Undated rows sort last either way — see `#panel`.
  order: "soonest",
  // HOW LONG YOU HAVE, as a WASH ON THE DATE CELL — the same three bands
  // @rookery/timeline draws on `#upcoming`, off the same `countdown()`, on the
  // same family `--rookery-heat-*` ramp. What differs is where the colour lands: that
  // view draws a chip, this one paints the date. The phrase rides as a tooltip.
  //
  // ON BY DEFAULT here, where `#upcoming`'s flag is off: a panel of OUTSTANDING WORK
  // is read for what is due next, which is the question the band answers. A row
  // further off than a fortnight draws no band from the countdown — priority is the
  // fallback there, see `draw` below — and a row with no date draws nothing at all.
  //
  // IT NEEDS A `today:`. Nothing in this package may call `datetime.today()` (it
  // returns 1980-01-01 under a reproducible build and does not error), and unlike the
  // predicates in `when.typ` a countdown has no tag dictionary to resolve a
  // document-date fallback from — so with no `today:` passed, no row is measured and
  // no countdown band drawn (priority still bands where it applies).
  countdown: true,
  // WHETHER A ROW WHOSE DATE HAS PASSED IS LISTED AT ALL. `true` lists it and paints
  // its date cell the `overdue` band — solid rather than a wash, the one band above
  // the countdown's three; `false` drops it from the panel entirely.
  //
  // ON BY DEFAULT, because a deadline behind you is the most pressing thing a worklist
  // has to say. `false` is for a panel read as "what is coming": a site that logs its
  // lapsed work elsewhere, or one whose todos accumulate dates nobody means to honour,
  // where a permanent red bar at the top of the list stops being read.
  //
  // IT NEEDS A `today:` for the same reason `countdown:` does — with no reference date
  // no row is measured, so nothing is dropped and no overdue band is drawn.
  overdue: true,
  // WHAT AN UNDATED ROW DOES WITH ITS PRIORITY. `true` gives the priority both of the
  // jobs a date would have done: it ORDERS the undated rows among themselves (the
  // highest priority first, an unprioritised row last) and it stands IN THE DATE CELL
  // as a `P<n>` label on the priority ramp's own colour, where the priority earns a
  // rung. `false` leaves them in registry order with an empty cell.
  //
  // ONLY WHERE THERE IS NO DATE. A dated row is ordered and banded by its date, which
  // is the firmer statement; priority washes such a row only where the countdown has
  // nothing to say (see `draw` below), and never writes a label over the date.
  //
  // A ROW'S RUNG is its priority's index among the priorities in use, clamped at the
  // ramp's fixed three steps — RELATIVE to the scale rather than to an absolute
  // number — so every prioritised row earns a rung, and everything from the
  // third-hottest priority downward shares the coolest one. Only an unprioritised row
  // (priority 0) keeps an empty cell.
  undated-priority: true,
  visible: 8,
  placeholder: "Filter",
  noun: "todos",
  empty: [Nothing here.],
  haystack: none,
  // OPT IN to mirroring the filter box and pressed pills into the URL, the
  // same knob `#panel` takes below — see there for the full contract. `<key>.q`
  // is the filter box; `<key>.epic`, `<key>.tag`, `<key>.state` and
  // `<key>.priority` are this widget's four pill groups, one repeated param
  // per pressed value. `none` (the default) puts no URL state on the page;
  // set, the key must be unique on it.
  sync: none,
  // Override the whole row. The default is `#idea-row-body`; this exists for the
  // caller with a genuinely different row, not as the ordinary path.
  render: none,
) = context {
  assert(
    order in ("newest", "soonest"),
    message: "@rookery/todos: #todo-table's `order` must be \"newest\" (the most "
      + "recent date first) or \"soonest\" (the earliest first) — got "
      + repr(order),
  )

  let all = if rows != none { rows } else { todos() }
  // THE GRAPH IS BUILT FROM THE CORPUS, not from the listed rows, and that is
  // load-bearing: a todo's blocker is very often closed, and a closed row dropped
  // before the graph is built would leave the blocker unresolvable — which
  // `is-blocked` reads as "not blocking", quietly promoting a blocked todo to ready.
  // `corpus:` defaults to `none`, meaning "the same as `rows:`", which is what this
  // function has always done — a caller narrowing `rows:` below the corpus has to
  // say so explicitly by passing both.
  let graph = todo-graph(rows: if corpus != none { corpus } else { all })
  // ONCE, not per row: `priority-rung` places a priority on the ramp relative to
  // this scale, and the scale itself does not change while rendering one panel.
  let scale = priority-scale()

  let keep = if filter != none { filter } else { r => not r.closed }
  let when = if when != none { when } else {
    r => {
      let d = deadline-of(r.tags-dict)
      if d != none { d } else { scheduled-of(r.tags-dict) }
    }
  }

  // EVERY PROJECTED FIELD IS A SCALAR — bar the one declared in `multi:` — which
  // `#panel`'s `_attr` asserts: each one becomes an HTML attribute the script reads
  // back, and a dictionary or a datetime there would stringify into nonsense. The raw
  // datetime rides as `when-date` — not a facet, so never projected into an attribute —
  // because `render:` needs to format it and the sort key is a string.
  // PRIORITY ORDER, APPLIED BEFORE `#panel`'s DATE SORT, which is what makes it the
  // tie-break rather than a competing order: that sort keys every undated row alike
  // (one sentinel sorting after every date) and Typst's `sorted` is stable, so the
  // order they arrive in is the order they keep. `#panel`'s script tie-breaks on the
  // row's markup index for the same reason, so the arrangement survives filtering.
  //
  // REVERSED UNDER `"newest"`, because that order reverses the whole list — without
  // this the tie-break would come out least-important-first exactly when the caller
  // asked for the most pressing thing at the top.
  let ranked = if not undated-priority { all.filter(keep) } else {
    let rank = r => -r.priority
    let s = all.filter(keep).sorted(key: rank)
    if order == "newest" { s.rev() } else { s }
  }

  let rows = ranked
    .map(r => {
      let d = when(r)
      (
        ..r,
        state: _state-of(r, graph, today),
        epic: epic-of(r.tags-dict),
        // AN ARRAY, the one non-scalar field here, and legal because `tag` is named in
        // `multi:` below. Sorting is @rookery/search's job: it dedups and sorts the
        // union across every listed row, so the pill order is stable across builds.
        tag: _tags-of(r.tags-dict, keep: tag-filter),
        // A pill reading "p7" says what the number is, and a pill reading "0" would
        // read as a count of something — so priority 0, the unprioritised default,
        // projects to no pill at all.
        priority: if r.priority == 0 { none } else { "p" + str(r.priority) },
        // A ZERO-PADDED `[year][month][day]` STRING, because `#panel` sorts its sort
        // field as a plain string — which is date order exactly when it is padded.
        when: if d == none { none } else { d.display("[year][month][day]") },
        when-date: d,
      )
    })
    .filter(r => overdue or not _past(r.at("when-date", default: none), today))

  let draw = if render != none { render } else {
    r => {
      let d = r.at("when-date", default: none)
      // PAGED/EPUB: `#panel` keeps its own `target()` branch, but it still calls
      // `render:` there — and `#idea-row-body` is `html.elem` all the way down, which
      // on a paged target contributes NOTHING. So the fallback lives here rather than
      // in the panel: an empty `list(..)` item per todo is exactly the silence
      // `target.typ`'s header says this package exists to end.
      // THE COUNTDOWN IS @rookery/timeline's, not this package's: `countdown`
      // maps whole days onto the three bands and the words for them, and deriving a
      // second copy of `if days <= 7` here is exactly how two surfaces drift apart.
      let c = if countdown and d != none and today != none {
        _tl.countdown(_tl.days-until(d, today))
      } else { none }
      if not _is-markup() {
        // EVERY RUNG HERE, not just the ramp's three: on paper the label is
        // information rather than colour, and the argument for stopping at p2 is an
        // argument about washes.
        let pri = r.at("priority", default: none)
        return {
          if d != none { [#_fmt-day(d) — ] } else if undated-priority and pri != none {
            [#upper(pri) — ]
          }
          r.at("label", default: r.at("name", default: ""))
          // THE SAME WORDS, NO COLOUR, which is what `#upcoming`'s paged branch does
          // too: a printed page has no chip to tint, and red ink is a decision about
          // the page rather than about the deadline.
          if c != none { [ #text(gray, "(" + c.text + ")")] }
        }
      }
      // THE BAND IS THE DATE CELL, not a fifth thing beside it. It was a chip on the
      // badge strip, which made the strip say two different kinds of thing at once —
      // what this todo IS (its facets) and how soon it is due — and spent a chip slot
      // on a reading the eye takes without words. So the colour paints the date's own
      // background and the phrase becomes a tooltip: the colour is the reading at a
      // glance, the words are there for whoever asks. `#upcoming` keeps its chips —
      // that view has a different grid and a different question.
      //
      // OVERDUE IS THE FOURTH BAND, and it is this package's own: `countdown()` folds
      // a date behind you into `urgent` along with today and tomorrow, which is right
      // for a chip saying how long you have and wrong for a worklist, where "late" and
      // "due today" are different instructions. It rides on `countdown:` like the other
      // three — a caller turning the washes off gets no colour at all.
      let band = if c == none { none } else if _past(d, today) {
        "todo-when-overdue"
      } else { "todo-when-" + c.level }
      // PRIORITY, ONLY WHERE THE COUNTDOWN HAS NOTHING TO SAY. A todo three weeks out
      // earns no countdown band, so its priority would otherwise be invisible next to
      // one sitting on a cooler rung — which is the gap this closes, on the same cell
      // rather than a second one. Where both could apply the countdown WINS: a
      // deadline actually due soon is the more pressing read regardless of how it was
      // prioritised.
      //
      // `p` HERE IS THE PROJECTED STRING (`"p7"`), not the number — the map above
      // turned it into one so it could ride as a facet attribute. `rung` places it on
      // the fixed three-step ramp relative to the OTHER priorities in use, since the
      // number itself is unbounded and means nothing on its own.
      let p = r.at("priority", default: none)
      let rung = priority-rung(if p == none { none } else { int(p.slice(1)) }, scale)
      let pri-band = if band != none or d == none or rung == none {
        none
      } else { "todo-when-rung-" + str(rung) }
      // THE UNDATED ROW'S OWN CELL: not a wash behind an empty column but the priority
      // itself, written where the date would be. Uppercase because it is a label
      // rather than the lowercase pill spelling — and blank only for an unprioritised
      // row, which earns no rung.
      let pri-label = if not undated-priority or d != none or rung == none {
        none
      } else { "P" + p.slice(1) }
      // A ROW WITH NO DATE AND NO LABEL GETS NEITHER. A wash behind an em dash says
      // nothing. Where the label IS drawn the words are redundant with it, so no
      // tooltip either.
      let phrase = if c != none { c.text } else if pri-band != none {
        "priority " + p.slice(1)
      } else { none }
      idea-row-body(
        when: if d != none { _fmt-day(d) } else { pri-label },
        iso: if d == none { none } else { _iso(d) },
        // `when-class:`/`when-attrs:` ARE @rookery/core's OWN HOLE for exactly this
        // (see `row.typ`): the caller computes the band, the row still asks nothing
        // about what a date means. With no band, neither is passed and the cell's
        // markup is what it always was.
        // THE LABEL WEARS TWO CLASSES: its ramp rung, the same `todo-when-rung-<n>` a
        // dated row's wash uses, plus `todo-when-priority` — which is what tells the
        // stylesheet this cell holds a priority rather than a date, and so takes the
        // rung's colour as INK on the wash instead of a wash alone.
        when-class: if band != none { (band,) } else if pri-band != none {
          (pri-band,)
        } else if pri-label != none {
          ("todo-when-priority", "todo-when-rung-" + str(rung))
        } else { () },
        // `data-countdown` carries the words for the drawn tooltip; `aria-label` says
        // them to a reader who cannot see a colour. Not `title:` — a native tooltip
        // cannot be styled and would open BESIDE the drawn one rather than instead of
        // it. `tabindex` is what makes the tooltip reachable without a pointer, which
        // is also how it opens on a touch screen.
        when-attrs: if phrase == none { (:) } else {
          (
            "data-countdown": phrase,
            "aria-label": _fmt-day(d) + ", " + phrase,
            "tabindex": "0",
          )
        },
        title: r.at("label", default: r.at("name", default: "")),
        href: r.at("href", default: none),
        // ONE CHIP PER SINGLE-VALUED FACET THIS ROW HAS A VALUE FOR, in the caller's
        // facet order, so the chips read in the same order as the pill groups above
        // them. The strip is about facets and nothing else — urgency is the date cell's
        // job now.
        //
        // THE MULTI-VALUED ONES ARE NOT CHIPPED, which is a decision about the GRID
        // rather than about tags. `.idea-row` is `<gutter> 1fr auto auto` and the strip
        // is that last `auto`: a chip per tag makes the strip as wide as the widest
        // row's tag list and squeezes every title on the page to pay for it, on a list
        // whose rows carry between one and six. The row already wears every tag as an
        // `idea-tag-<tag>` class (`row-class` below), so a site theming by tag still
        // can, and the pills say which tag is being filtered on.
        //
        // THE PRIORITY CHIP GOES WHERE THE LABEL IS DRAWN, because the label IS that
        // chip, moved: an undated row carrying `P0` in the date column and a `p0`
        // badge on the strip says one thing twice, at opposite ends of the row.
        badges: facets
          .filter(f => f != "priority" or pri-label == none)
          .filter(f => f not in _MULTI)
          .map(f => r.at(f, default: none))
          .filter(v => v != none and v != "")
          .map(v => (text: v.replace("-", " "), tag: v)),
      )
    }
  }

  // THE LAYOUT `pill-rows:` DECLARES, intersected with the groups that actually
  // exist. The intersection is load-bearing: `#panel` asserts that every name in
  // `facet-rows:` is also in `facets:`, so a caller narrowing `facets:` would
  // otherwise trip an assertion about a group they had just chosen not to have. A
  // line left with no groups is dropped rather than rendered blank.
  let facet-rows = pill-rows
    .map(r => (
      label: r.at("label", default: none),
      facets: r.at("facets", default: ()).filter(f => f in facets),
    ))
    .filter(r => r.facets.len() > 0)

  // EVERY GROUP MUST LAND SOMEWHERE, because `#panel` asserts the same from its side:
  // a facet in `facets:` and in no row renders no pills at all, which is a filter the
  // reader can neither see nor press.
  for f in facets {
    assert(
      facet-rows.any(r => r.facets.contains(f)),
      message: "@rookery/todos: #todo-table's facet `" + f + "` is in `facets:` but "
        + "in no `pill-rows:` entry, so it would render no pills. Put it in a row, or "
        + "drop it from `facets:`.",
    )
  }

  panel(
    rows: rows,
    facets: facets,
    // INTERSECTED WITH `facets:` rather than passed whole, because `#panel` asserts
    // that every `multi:` entry is a facet — and a caller narrowing `facets:` to the
    // three scalar groups would otherwise trip an assertion about a group they had
    // just chosen not to have.
    multi: facets.filter(f => f in _MULTI),
    // THE SUBJECT GROUPS OR WITH EACH OTHER, where `state` and `priority` go on ANDing.
    // `epic` and `tag` are ONE QUESTION — what is this todo about — arriving as two
    // projections, and the split is not the reader's: a todo under `epic-rheo` gets its
    // `rheo` pill in the epic group and none in the tag group (`_tags-of` drops a key
    // whose `epic-<key>` is present, so the name is never offered twice), while a plain
    // `birds` can only ever be a tag. Pressing the two therefore asked for a todo whose
    // epic is `rheo` AND whose tags include `birds`, which no todo is or ever will be —
    // two subjects that were the same question composing as though they were different
    // ones.
    //
    // NAMED BY `_SUBJECT` rather than derived from the layout, now that the layout is
    // a caller's to declare: which groups ask ONE question is a fact about the todo
    // model, not about how many lines the pills are drawn on. Intersected with
    // `facets:` for the reason `multi:` above is.
    union: facets.filter(f => f in _SUBJECT),
    facet-rows: facet-rows,
    sort: "when",
    descending: order == "newest",
    // WHAT `#idea-row` WOULD HAVE PUT ON THE `<li>` ITSELF. `#panel` owns the list
    // item here, so the row's own classes arrive this way instead: `idea-row` is the
    // GRID the body's four spans are laid out on, and `idea-tag-<tag>` is what every
    // other rookery surface already themes a note by.
    row-class: r => (
      ("idea-row",) + r.at("tags-dict", default: (:)).keys().map(t => "idea-tag-" + t)
    ),
    visible: visible,
    placeholder: placeholder,
    noun: noun,
    empty: empty,
    haystack: haystack,
    sync: sync,
    render: draw,
  )
}
