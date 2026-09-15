// The rendered views — br's derived reports, as HTML over the graph.
//
// Every view here answers a question br answers with a subcommand: `todos-list`
// is `br list`, `todos-ready` is `br ready`, `todos-blocked` is `br blocked`,
// `todos-stale` is `br stale`, `todos-stats` is `br stats`. What is NOT here is
// br's MUTATION surface — `update`, `close`, `dep add` — because a status
// change in a static build is an edit to a `.typ` file.
//
// TWO RULES EVERY VIEW FOLLOWS:
//
//  1. It runs the cycle check before rendering. A cyclic graph has no order to
//     present, and this is half of what makes a cycle impossible to ship (the
//     other half is `#todos-validate()` for a project that renders no view).
//  2. It takes `today:` where it needs a reference date, and never calls
//     `datetime.today()`. That returns 1980-01-01 under a reproducible build
//     and DOES NOT ERROR — a stale-todo report built on it would silently list
//     the whole project. @rookery/timeline resolves `today:` against the
//     document date and panics when neither is available.

#import "@rookery/core:0.1.0": window
#import "@rookery/timeline:0.1.0": entries, is-overdue, updated-of
#import "target.typ": *
#import "tags.typ": *
#import "todo.typ": *
#import "graph.typ": *

// A row's own tag classes, so a project stylesheet can target
// `.idea-tag-todo-p0` or `.idea-tag-todo-closed` on a list row exactly as it
// targets them on a note's card. Same convention rookery's own outline rows
// use — one rule, three emission sites.
#let _row-classes(row, extra: ()) = (
  ("todo-row",) + extra + row.tags-dict.keys().map(k => "idea-tag-" + k)
).join(" ")

// A row's label: its title, or its name when untitled.
#let _label(row) = if row.title == none { raw(row.name) } else { row.title }

// One row: a link to the note, its label, and whatever trailing note the view
// wants to add.
//
// `href` is `none` where nothing mints pages (a plain `typst compile`, or rheo
// with minting off), so a row degrades to unlinked text rather than emitting a
// dead anchor. A PAGED target has no minted pages to link to at all, which is
// why its branch never builds one.
#let _row(row, extra: (), trailing: none) = html.elem(
  "li",
  attrs: (class: _row-classes(row, extra: extra)),
  {
    let label = _label(row)
    if row.href == none {
      html.elem("span", attrs: (class: "todo-row-title"), label)
    } else {
      html.elem(
        "a",
        attrs: (class: "todo-row-title", href: row.href),
        label,
      )
    }
    if trailing != none {
      html.elem("span", attrs: (class: "todo-row-note"), trailing)
    }
  },
)

// The same row on a paged target, as plain Typst content.
#let _row-paged(row, trailing: none) = {
  let label = _label(row)
  if row.closed { strike(label) } else { label }
  if trailing != none { [ #text(gray, trailing)] }
}

// The shared frame: an optional title, then the rows, then an empty-state line
// rather than a bare empty list — "nothing is blocked" is a useful answer and a
// silent gap is not.
#let _list(title, rows, empty, extra: (), trailing: r => none) = {
  if _is-markup() {
    return html.elem(
      "div",
      attrs: (class: "todo-view"),
      {
        if title != none {
          html.elem("div", attrs: (class: "todo-view-title"), title)
        }
        if rows.len() == 0 {
          html.elem("p", attrs: (class: "todo-view-empty"), empty)
        } else {
          html.elem(
            "ul",
            attrs: (class: "todo-list"),
            rows.map(r => _row(r, extra: extra, trailing: trailing(r))).join(),
          )
        }
      },
    )
  }
  // PAGED. `align(start)` is load-bearing, and it is the same trap rookery
  // documents at `idea.typ`'s paged branch: this content can sit inside a
  // Typst `figure`, and a figure CENTRES its body — which on a paged target
  // centred every row rather than leaving it at the text margin.
  align(start, {
    if title != none { strong(title); linebreak() }
    if rows.len() == 0 {
      text(gray, emph(empty))
    } else {
      list(..rows.map(r => _row-paged(r, trailing: trailing(r))))
    }
  })
}

// ---- _windows — the same rows, as folded transclusions --------------------
//
// `#todos-*(windows: true)` renders each row as a folded `#window` instead of a
// link, so a reader unfolds a todo's body in place rather than clicking through
// to its minted page.
//
// WHY THIS LIVES IN THE PACKAGE and not in a caller: `ready` and `blocked` are
// DERIVED from the dependency graph and the calendar (`is-ready`, `is-blocked`
// in `graph.typ`), never stored as tags — so no `#window(tags: ..)` selection
// can express them. Only code that has already computed the rows can hand
// `#window` the names, and that code is here.
//
// ONE `#window` CALL PER ROW, not one array call. `#window` does accept an
// array of names, and that form would cost one registry read instead of N —
// but it cannot interleave the per-row `trailing` note, and that note is the
// entire value of `#todos-blocked` ("blocked by X, Y"). The per-row cost is
// what `#window` already costs everywhere else it is used.
// THESE WINDOWS DO PRODUCE BACKLINKS, and that took a rookery fix. The backlink
// walk reads a page's content at `#show: rookery` time, which cannot enter a
// `context` block — and these views must run inside one, since the graph and
// the reference date resolve nowhere else. A window emitted from here therefore
// announced itself to nobody, and every note the view unfolded lost its
// backlink from the page unfolding it. MEASURED, then fixed in rookery by
// labelling `#window`'s announce marker and collecting those by `query()`,
// which sees them wherever the window was written.
//
// So a `windows: true` view is a real reference and shows up as one. Documented
// in the readme, because a busy index becomes a backlink on everything it
// lists.
#let _windows(title, rows, empty, trailing: r => none) = {
  // PAGED FIRST. A PDF or EPUB page has no fold to click, so those targets keep
  // the link list they already render. Deliberate, not a stub — see `_list`.
  if not _is-markup() { return _list(title, rows, empty, trailing: trailing) }

  html.elem(
    "div",
    attrs: (class: "todo-view todo-windows"),
    {
      if title != none {
        html.elem("div", attrs: (class: "todo-view-title"), title)
      }
      if rows.len() == 0 {
        html.elem("p", attrs: (class: "todo-view-empty"), empty)
      } else {
        rows
          .map(r => html.elem(
            "div",
            // NOT `_row-classes`, and this is the reason: that prepends
            // `todo-row`, which the stylesheet makes a baseline-aligned flex
            // row — and a `<details>` inside one lays out wrongly. A window row
            // is a block; it only wants the note's own tag classes.
            attrs: (
              class: (("todo-window-row",) + r.tags-dict.keys().map(k => "idea-tag-" + k)).join(" "),
            ),
            {
              window(r.name, folded: true)
              let note = trailing(r)
              if note != none {
                html.elem("span", attrs: (class: "todo-row-note"), note)
              }
            },
          ))
          .join()
      }
    },
  )
}

// By priority, most important first, then by name for a build-stable order.
// An unprioritised todo is priority 0 and so sorts last.
#let _by-priority(rows) = rows.sorted(key: r => (-r.priority, r.name))

// ---- #todos-list — br `list` -----------------------------------------------
//
// The general, filterable view. Its parameter vocabulary deliberately mirrors
// rookery's own `#ideas-outline` — `tags:`, `match:`, `filter:`, `limit:`,
// `title:` — so an author meets ONE idiom rather than two that nearly agree.
//
// `filter:` receives the tag DICTIONARY, as it does in rookery 0.5.0, so it can
// select on a value: `filter: t => t.at("todo-metadata", default: (:)).at(
// "assignee", default: none) == "lox"`.
#let todos-list(
  title: none,
  tags: none,
  match: "any",
  filter: none,
  limit: none,
  closed: true,
  windows: false,
) = context {
  let rows = todos()
  let graph = todo-graph(rows: rows)
  assert-acyclic(graph)
  if not closed { rows = rows.filter(r => not r.closed) }
  if tags != none {
    let want = if std.type(tags) == str { (tags,) } else { tags }
    rows = rows.filter(r => if match == "all" {
      want.all(t => t in r.tags-dict)
    } else {
      want.any(t => t in r.tags-dict)
    })
  }
  if filter != none { rows = rows.filter(r => filter(r.tags-dict)) }
  rows = _by-priority(rows)
  if limit != none { rows = rows.slice(0, calc.min(limit, rows.len())) }
  if windows { _windows(title, rows, [No todos.]) } else { _list(title, rows, [No todos.]) }
}

// ---- #todos-ready — br `ready` ---------------------------------------------
//
// Open, unblocked, and not deferred past `today`. The deferral clause is what
// makes this br's `ready` rather than merely "not blocked" — see `is-ready`.
#let todos-ready(title: none, today: none, limit: none, windows: false) = context {
  let all = todos()
  let graph = todo-graph(rows: all)
  assert-acyclic(graph)
  let rows = _by-priority(all.filter(r => is-ready(r, graph, today: today)))
  if limit != none { rows = rows.slice(0, calc.min(limit, rows.len())) }
  // `extra:` is dropped on the windows path: `todo-row-ready` styles the
  // border-left of a flex row, and a window row is neither.
  if windows {
    _windows(title, rows, [Nothing is ready.])
  } else {
    _list(title, rows, [Nothing is ready.], extra: ("todo-row-ready",))
  }
}

// ---- #todos-blocked — br `blocked` -----------------------------------------
//
// Open todos with at least one unclosed dependency, EACH NAMING WHAT BLOCKS IT.
// The naming is the whole value of the view: a list of blocked things without
// their blockers tells you nothing you could act on.
#let todos-blocked(title: none, windows: false) = context {
  let all = todos()
  let graph = todo-graph(rows: all)
  assert-acyclic(graph)
  let rows = _by-priority(
    all.filter(r => not r.closed and is-blocked(r, graph)),
  )
  let why = r => [blocked by #blockers-of(r, graph).join(", ")]
  if windows {
    _windows(title, rows, [Nothing is blocked.], trailing: why)
  } else {
    _list(
      title,
      rows,
      [Nothing is blocked.],
      extra: ("todo-row-blocked",),
      trailing: why,
    )
  }
}

// ---- #todos-stale — br `stale` ---------------------------------------------
//
// Open todos untouched for more than `older-than` days.
//
// MEASURES WHAT IT CLAIMS TO: it reads @rookery/timeline's
// `updated-of(row)`, the last entry in the todo's own dated log,
// falling back to `created`. A todo that was deferred, activated or
// otherwise touched says so, because touching it puts an entry in the log.
//
// A todo with NO date at all is still not stale: nothing is known about when it
// was touched, and reporting silence as staleness would flag every undated
// project wholesale.
#let todos-stale(title: none, today: none, older-than: 30, windows: false) = context {
  let all = todos()
  let graph = todo-graph(rows: all)
  assert-acyclic(graph)
  assert(
    std.type(older-than) == int and older-than >= 0,
    message: "@rookery/todos: `older-than` must be a non-negative integer "
      + "number of days — got " + repr(older-than),
  )
  // "Untouched since `updated` + N days" is the same question as "is that date
  // in the past", so it goes through rookery-timeline's `is-overdue` rather than a
  // second date comparison written here. That keeps ONE answer to "what is
  // now" in the whole stack — including its panic when there is none, and its
  // MEASURED handling of an unset document date, which is `auto` and not
  // `none`.
  // Built through `entries(deadline: ..)` rather than by hand-writing a tag key:
  // the deadline is a STAGE in the log now, not a key of its own, and naming the
  // storage shape here would be this view knowing something only rookery-timeline
  // should.
  let stale(u) = is-overdue(entries(deadline: u + duration(days: older-than)), today: today)
  let touched = r => updated-of(r)
  let rows = all.filter(r => {
    if r.closed { return false }
    let u = touched(r)
    if u == none { return false }
    stale(u)
  })
  let when = r => [last touched #touched(r).display("[year]-[month]-[day]")]
  if windows {
    _windows(title, _by-priority(rows), [Nothing is stale.], trailing: when)
  } else {
    _list(
      title,
      _by-priority(rows),
      [Nothing is stale.],
      extra: ("todo-row-stale",),
      trailing: when,
    )
  }
}

// ---- #todos-stats — br `stats` / `count` -----------------------------------
//
// Totals by status, priority and type, over every todo in the rookery.
#let todos-stats(title: none, today: none) = context {
  let rows = todos()
  let graph = todo-graph(rows: rows)
  assert-acyclic(graph)
  let count(pred) = rows.filter(pred).len()

  // Built once as (key, value) pairs, rendered twice — so the two targets
  // cannot report different numbers.
  let pairs = (
    ("total", rows.len()),
    ("open", count(r => not r.closed)),
    ("closed", count(r => r.closed)),
    ("blocked", count(r => not r.closed and is-blocked(r, graph))),
    ("ready", count(r => is-ready(r, graph, today: today))),
  )
  for n in rows.map(r => r.priority).filter(p => p > 0).dedup().sorted().rev() {
    pairs.push(("p" + str(n), count(r => r.priority == n)))
  }
  for t in TYPES {
    let c = count(r => r.kind == t)
    if c > 0 { pairs.push((t, c)) }
  }

  if not _is-markup() {
    // `align(start)` for the same figure-centring reason as `_list` above.
    return align(start, {
      if title != none { strong(title); linebreak() }
      pairs.map(((key, value)) => text(gray, key) + " " + str(value)).join(", ")
    })
  }

  let cell(k, v) = html.elem(
    "li",
    attrs: (class: "todo-stat"),
    html.elem("span", attrs: (class: "todo-stat-key"), k)
      + html.elem("span", attrs: (class: "todo-stat-value"), str(v)),
  )

  html.elem(
    "div",
    attrs: (class: "todo-view todo-stats"),
    {
      if title != none {
        html.elem("div", attrs: (class: "todo-view-title"), title)
      }
      html.elem(
        "ul",
        attrs: (class: "todo-stat-list"),
        pairs.map(((key, value)) => cell(key, value)).join(),
      )
    },
  )
}

// ---- #todo-graph-view — the DAG, as a page element ------------------------
//
// Emits a container plus a `<script type="application/json">` payload holding
// the graph, which `todos.js` lays out and draws client-side. Same
// shape @rookery/search uses for its search index, and for the same
// reason: Typst has no layout engine for a directed graph, and a JSON payload
// beside the element it belongs to is the cheapest handoff there is.
//
// THE PAYLOAD IS JSON-SAFE BY CONSTRUCTION — strings, numbers, booleans and
// arrays only, never a raw tag value. A value can be a `datetime` or content,
// and MEASURED: `json.encode` of content does NOT error, it silently emits a
// structural blob like `{"func":"text","text":"hi"}`. That would bloat the page
// rather than fail loudly, so dates are stamped to `[year][month][day]` strings
// here — the same convention rookery-search already uses — and the metadata bag
// is left out entirely.
//
// DEGRADES WITHOUT JAVASCRIPT. The container ships the node list as ordinary
// linked markup, which the script replaces once it runs. A reader with JS off,
// and every paged or EPUB target, still gets the todos and their dependencies
// as readable text rather than an empty box.
#let todo-graph-view(title: none, today: none, closed: true) = context {
  let graph = todo-graph()
  // A cyclic graph has no layered layout, and a cycle is already a build error
  // — this is the view half of that guarantee.
  assert-acyclic(graph)

  // ONE slice, feeding all three renderings — the paged branch, the JSON
  // payload and the no-JS fallback — so they cannot disagree about what is on
  // the page. Before this they each reached for their own source.
  let (rows, edges) = graph-slice(graph, closed: closed)

  // The dep names still on the page, for the "depends on ..." notes below.
  // Naming a dependency whose box the SLICE removed is exactly what the edge
  // filter exists to prevent, so the prose is filtered with it.
  //
  // A DANGLING DEP IS KEPT, and the distinction is the whole reason this reads
  // `d not in graph.nodes` rather than just `d in shown-names`. A dep naming a
  // note that does not exist never had a box to point at, in any slice — it was
  // named here before `closed:` existed and it still is, so `closed: true`
  // stays byte-identical to the output before this parameter. Filtering it too
  // would silently drop the only place a dangling dep surfaces in this view.
  // (`#todos-validate` reports it separately, and the graph payload still
  // carries it under `unresolved`.)
  let shown-names = rows.map(r => (r.name, true)).to-dict()
  let shown-deps(r) = r.deps.filter(d => d not in graph.nodes or d in shown-names)

  // PAGED TARGET: there is no layout engine for a directed graph Typst-side
  // and no JavaScript to draw one, so the paged rendering IS the fallback list
  // the HTML branch already builds for readers with JS off. Same content, and
  // the only honest thing a PDF can show.
  //
  // `align(start)` for the reason rookery documents at `idea.typ`'s own paged
  // branch: a Typst figure centres its body, and this can sit inside one.
  if not _is-markup() {
    return align(start, {
      if title != none { strong(title); linebreak() }
      list(..rows.map(r => {
        let label = if r.text == "" { raw(r.name) } else { r.title }
        if r.closed { strike(label) } else { label }
        let d = shown-deps(r)
        if d.len() > 0 { [ #text(gray, "depends on " + d.join(", "))] }
      }))
    })
  }

  let stamp(d) = if d == none { none } else { d.display("[year][month][day]") }

  let nodes = rows.map(r => {
    let n = (
      name: r.name,
      id: r.id,
      title: if r.text == "" { r.name } else { r.text },
      status: if r.closed { "closed" } else if is-blocked(r, graph) {
        "blocked"
      } else if is-ready(r, graph, today: today) { "ready" } else { r.status },
    )
    if r.href != none { n.insert("href", r.href) }
    if r.priority != none { n.insert("priority", r.priority) }
    if r.kind != none { n.insert("type", r.kind) }
    let c = stamp(r.closed-on)
    if c != none { n.insert("closed", c) }
    n
  })

  let payload = (
    nodes: nodes,
    edges: edges.map(((from, to)) => (from: from, to: to)),
    unresolved: graph.unresolved.map(((from, dep)) => (from: from, to: dep)),
  )

  html.elem(
    "div",
    attrs: (class: "todo-graph"),
    {
      if title != none {
        html.elem("div", attrs: (class: "todo-view-title"), title)
      }
      html.elem(
        "script",
        attrs: (type: "application/json", class: "todo-graph-data"),
        json.encode(payload, pretty: false),
      )
      // The no-JS fallback, and the thing the script replaces.
      html.elem(
        "ul",
        attrs: (class: "todo-graph-fallback"),
        rows
          .map(r => {
            let label = if r.text == "" { r.name } else { r.text }
            html.elem(
              "li",
              attrs: (class: (("todo-graph-node",) + r.tags-dict.keys().map(k => "idea-tag-" + k)).join(" ")),
              {
                if r.href == none {
                  html.elem("span", attrs: (class: "todo-row-title"), label)
                } else {
                  html.elem("a", attrs: (class: "todo-row-title", href: r.href), label)
                }
                let d = shown-deps(r)
                if d.len() > 0 {
                  html.elem(
                    "span",
                    attrs: (class: "todo-row-note"),
                    "depends on " + d.join(", "),
                  )
                }
              },
            )
          })
          .join(),
      )
    },
  )
}
