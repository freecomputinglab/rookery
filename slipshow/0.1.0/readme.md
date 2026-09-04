# @rookery/slipshow

An endlessly scrolling presentation over `@rookery/core` ideas, in the spirit
of [slipshow](https://github.com/panglesd/slipshow). Each slip is a note:
`#slip` is an `#idea` variant, so a slide is rendered with core's own card
styling — the left rule and the tab that carries its permalink — and is
searchable, windowable and linkable exactly like any other idea in the
rookery. This package implements the slip MODEL — one continuously scrolling
document with a camera that moves between fully-rendered slides — with its
own camera engine, written from scratch. **It does not embed slipshow's own
JavaScript**, which has no maintained distribution meant to be dropped into
someone else's page.

**Camera-only, and that is worth saying plainly to a reader who knows
slipshow already.** A slip is fully rendered the moment it is shown; only the
viewport moves within it. There is no `pause`, no incremental build of a
slip's own content, and no step directives of any kind — the camera is the
only motion this package has.

**A deck does reveal itself one slip at a time, though, and that is the
default.** A slipshow opens EMPTY: no slip is on the page until the reader
presses for one, and each advance brings exactly one more into the document,
so the page grows as the presentation runs. This is a whole-slip reveal and
not slipshow's own `pause` — the boundary is always "everything up to the
current slip", never a point inside one — and going back takes slips away
again rather than leaving a trail. `#slipshow(reveal: false)` renders the
whole deck up front instead; see "`reveal:`" below.

**A slipshow is a FLAT ordered list of ideas.** An idea written literally
inside another's body — a nested `#idea`/`#slip` — is ordinary content: it
renders as part of the slip that contains it, never as a slip of its own.
`#slipshow` does not look inside a slip to find more slides.

```typst
#import "@rookery/core:0.1.0": rookery
#import "@rookery/slipshow:0.1.0": slip, slipshow
#show: rookery

#slipshow(slips: (
  slip("intro", title: [Welcome], fullscreen: true)[The opening slip.],
  slip("closing")[The last one.],
))
```

## Import both packages, in your own files

**A project using slipshow must import `@rookery/core` AND
`@rookery/slipshow` in its own `.typ` files.** This is the same requirement
`@rookery/search`'s readme states about itself, and for the identical reason:
rheo's package asset auto-detection only scans a project's own files for
package imports, not the packages those files' packages import in turn.
Importing only `@rookery/slipshow` and reaching core through it does not
register core with the build.

The cost is not cosmetic here, either. Without a direct import of core,
core's own `.marrow.typ` never runs and its stylesheet (`src/core.css`) is
never injected — and that stylesheet is what draws the card identity this
package's whole pitch rests on: the left rule, the tab, the permalink. A
slipshow built this way still scrolls and still camera-moves correctly (that
part is this package's own manifest, injected off the direct
`@rookery/slipshow` import), but every slip renders as unstyled text with no
border and no tab.

In practice this is free — a project with `#slip`/`#idea` calls in it already
imports core to write them. It is stated here because the failure is silent:
the build succeeds either way.

## `#slip` — a slide is a note

```typst
#slip(
  fullscreen: false,
  background: none,
  enter: none,
  order: none,
  class: none,
  row: none,
  max-width: none,
  tags: none,
  exclude-tags: (),
  show-frame: false,
  show-id: false,
  ..args,
)
```

`#slip` is `#idea` plus a handful of presentation options, folded into the
note's own tag dictionary (`src/tags.typ`'s `slip-tags`) — the only field on
a rookery record extensible enough to carry them through to a tag-queried
deck, which never sees the call site itself, only the registry row.

| option | type | default | what it does |
| --- | --- | --- | --- |
| `fullscreen` | `bool` | `false` | tags the note `slip-fullscreen`; the stylesheet stretches the slip to at least the viewport height and centers its content in it |
| `background` | `color`, `gradient`, or `image(..)` content | `none` | this slip's own background — see "Backgrounds" below |
| `enter` | one of the eight camera actions (see "Keyboard and mouse controls") | `none` (deck default) | overrides `#slipshow`'s deck-wide `enter:` for this one slip |
| `order` | `int` | `none` | this slip's `slip-order` — the default sort key for a tag-queried deck |
| `class` | `str` | `none` | appended to the rendered `<section>`'s class list |
| `row` | `int` | `none` | groups CONSECUTIVE slips sharing the same value into one `div.slip-row[data-row=..]` wrapper — overridden per-deck by `#slipshow`'s own `row:` key function, below, for a row that is computed rather than authored |
| `max-width` | `length`, `ratio`, or a raw-CSS `str` | `none` | a `max-width` declaration on the slip's own `<section>` — never `width`, so a narrower slip stays narrow rather than being stretched to fill the cap |
| `tags` | any of core's four tag forms | `none` | the caller's own tags, merged in LAST — a caller naming one of `#slip`'s own keys wins outright |
| `exclude-tags` | array of tag names | `()` | forwarded through to the underlying `#idea` — see below |
| `show-frame` | `bool` | `false` | `@rookery/core`'s own switch with its default INVERTED — no card left rule, no indent |
| `show-id` | `bool` | `false` | core's again, inverted — no `[idea:<name>]` permalink, and so no hat |
| `..args` | — | — | every other `#idea` argument (`title`, `level`, `created`, `show-date`, `show-tags`, …), forwarded untouched |

`fullscreen`, `enter`, `order`, `class` and `row` are each type-checked at the
`#slip()` call site and panic naming the bad value. `background` is the one
exception: it is left untouched here — `#slip`/`slip-tags` have no business
interpreting a colour, a gradient or an image — and is checked instead where
it is actually rendered, inside `#slipshow`. A `#slip` call with a bad
background type therefore builds without complaint; the panic fires when the
deck renders that slip.

### A slip is bare by default, wherever it renders

`show-frame` and `show-id` are `@rookery/core` arguments, and `#slip` only
changes their defaults — the same inversion `#slipshow` makes for a queried slip
(see "A slip wears no card chrome" below), and it has to be made in both places
because the two routes render at different times. `#slipshow` renders a QUERIED
slip itself and can pass whatever it likes; an explicit-array slip was already
rendered at its own `#slip(..)` call site, long before any deck saw it, so no
deck-level setting can reach inside it. Setting the default on `#slip` is what
makes the array route agree with the query route.

**A `#slip` is therefore bare where it is AUTHORED too**, not only inside a deck.
That is intended rather than a side effect: a `#slip` written on a page usually
renders twice — once inline where it sits, once inside the deck that queries it
back — and the two copies should look the same. Pass `show-frame: true` /
`show-id: true` to get core's ordinary card back for one slip.

`show-label` is deliberately absent: it is a `#window` argument, and a card
already prints the authored title alone, so there is no derived label for a
`#slip` to suppress.

`foldable` and `reserve-title` are absent for the same reason, and it is the
same reason twice: both are `#window` arguments, and an authored `#slip` renders
as a CARD, which has no disclosure and no summary row at all — so there is
nothing to make unfoldable and no reserved title line to drop. They apply to the
queried route, where `#slipshow` renders each slip through `#window`, and that
is where the deck sets them.

All three of `#idea`'s id forms work identically on `#slip`: a bare body with
an auto-generated id (`#slip[..]`), a string name (`#slip("intro")[..]`), or
a label (`#slip(<intro>)[..]`).

**A plain `#idea` is usable in a slipshow too**, and simply takes the deck's
defaults: no fullscreen, no background, the deck's own `enter:`, and it sorts
last under the default `slip-order` since it carries no `slip-order` tag at
all. `#slip` exists only for a note that wants presentation options of its
own — see `demo/rheo/content/index.typ`'s `plain-note` for a worked example
of a bare `#idea` tagged `slip` by hand and rendered inside a deck alongside
notes built with `#slip`.

### `exclude-tags` — pass the same list to `#slip` as to `#idea`

A project excluding tags from a build (`@rookery/core`'s readme, "Excluding
notes from a build") has to bind BOTH constructors to the same
`exclude-tags:` list, for the reason core's own `tagged-idea` banner gives:
`tagged-idea` (which `#slip` is built on) returns a closure that calls the
`idea` captured in package scope, so binding a project's own `idea` alone
does not reach a wrapper built with `tagged-idea` — a project's `#slip` would
go on hatching notes the project meant to exclude. `#slip` takes
`exclude-tags:` for exactly this reason, and needs the same list `idea`
itself gets:

```typst
#import "@rookery/core:0.1.0": idea as _idea
#import "@rookery/slipshow:0.1.0": slip as _slip

#let EX = ("protected",)
#let idea = _idea.with(exclude-tags: EX)
#let slip = _slip.with(exclude-tags: EX)
```

## `#slipshow` — the deck container

```typst
#slipshow(
  slips: none,
  tags: none,
  where: none,
  match: "any",
  order: "slip-order",
  reverse: false,
  row: none,
  enter: "scroll",
  reveal: true,
  show-frame: false,
  show-id: false,
  show-label: false,
  foldable: false,
  reserve-title: false,
  backlink: false,
)
```

`#slipshow` resolves its slip list from exactly ONE of two routes and renders
the result. Giving neither route, or both, panics naming which:

- **`slips:`** — an explicit, already-ordered array.
- **`tags:` and/or `where:`** — a query over the registry, sorted by `order:`.

`enter:` is the deck-wide default camera action, one of the eight named in
"Keyboard and mouse controls" below (`"scroll"` by default); a bad value
panics naming the valid set.

`reveal:` is the progressive reveal, `true` by default — see its own section
below.

`show-frame:`, `show-id:`, `show-label:`, `foldable:` and `reserve-title:` are
`@rookery/core`'s own chrome switches with their defaults inverted — see "A slip
wears no card chrome" below.

`foldable: false` and `reserve-title: false` are the two that make a slip read
as a slide rather than as a reference to a note:

- **`foldable: false`** — a slide is not a disclosure. There is no
  `<details>`/`<summary>`, so nothing can fold a slide shut under a stray click
  and the summary row stops offering a pointer. The `[idea:<name>]` permalink
  inside it is still a link and still navigates. Pass `foldable: true` for a
  deck you want to collapse.
- **`reserve-title: false`** — no blank line above a titleless slide. Because
  this deck also sets `show-label: false`, a note with no AUTHORED title has a
  genuinely empty summary, and the line core reserves for a title there is dead
  space above the body. **A slide whose note DOES have a title still shows it,
  with core's ordinary spacing** — the reservation only ever applied to a
  summary with no title at all. Either way the slide is not foldable; the two
  switches are independent.

The hover tint is deliberately LEFT ALONE, at core's `show-background: true`. It
is how a slide answers a pointer, and it is independent of `show-frame`, which
this deck does turn off — so there is no `show-background` argument here, since
its only value would be core's default.

`backlink:` is core's own too, also inverted: a deck does not count as a link to
the notes it shows — see "A deck is not a reference" below.

### A slip wears no card chrome

```typst
#slipshow(tags: "slip")                      // bare slips, the default
#slipshow(tags: "slip", show-frame: true)    // put the card's rule back
```

A queried slip is transcluded through `#window`, so it arrives as a full
`@rookery/core` card unless told otherwise. Inside a presentation all of that
card's chrome is noise, so `#slipshow` passes three of core's own arguments with
their defaults **inverted**:

| argument | here | in core | what `false` drops |
| --- | --- | --- | --- |
| `show-frame` | `false` | `true` | the card's left rule and its indent |
| `show-id` | `false` | `true` | the `[idea:<name>]` permalink, and with it the whole hat |
| `show-label` | `false` | `true` | the title derived from a note's first line; an AUTHORED title still shows |

The reasoning, one line each: a slip's `<section>` is already the visual unit, so
a card frame inside it reads as a frame around a frame; the `[idea:47]` chip above
every slide is machinery a reader of a deck has no use for; and an untitled note's
derived label sits directly above the very first line it was derived from, so the
slide prints that line twice.

**These are core's knobs, not this package's.** Nothing here draws or hides any of
it — `@rookery/core`'s readme documents what each one does and its own stylesheet
does the hiding. `#slipshow` only chooses different defaults and forwards them.

**One cost, inherited from core and worth repeating:** the permalink is the ONLY
way to discover an AUTO-GENERATED id. A deck of unnamed notes rendered with
`show-id: false` therefore has no ids a reader can copy into a `#window` or a
`#slip-<id>` fragment. Give the slips explicit names if they should be linkable.

### A deck is not a reference

```typst
#slipshow(tags: "slip")                   // announces nothing, the default
#slipshow(tags: "slip", backlink: true)   // the deck page counts as a link
```

A queried slip is transcluded through `#window`, and a `#window` normally
announces the note it shows: you wrote it in a note's prose, so that note links
to this one. A deck is not that. It is a VIEW of notes that already live
somewhere else — `demo/rheo/content/index.typ` puts it as "always an additional
view onto content that already lives somewhere, never its only home" — and
nobody wrote a link at all. Left announcing, a page of twenty queried notes puts
itself in twenty notes' Backlinks.

So `backlink:` is `false` here where core's own default is `true`. A deck whose
whole point IS to point at those notes — an index page, a reading list — passes
`true`.

**Nothing about this is visible in the markup**, which is worth saying because it
makes the behaviour hard to check by eye. The flag travels inside the announce
marker `#window` emits, and that marker is emitted whatever its value: a third
reader needs it to know a nested window will claim the enclosing note's
citations. `@rookery/core`'s readme has the full account under "`backlink:` — a
view is not a reference".

**The array route is unaffected**, and not because it opts out: an entry that is
already-rendered `#slip(..)` content never went through `#window`, so it never
announced anything in the first place. An entry given by NAME does go through
`#window` and follows the deck.

### `reveal:` — the deck opens empty

```typst
#slipshow(tags: "slip")                 // opens empty, one slip per advance
#slipshow(tags: "slip", reveal: false)  // the whole deck rendered up front
```

By default a slipshow shows **no slips at all** when the page loads, and
reveals them one at a time as the reader advances: the first press puts up the
first slip, the second press the second, and so on. The boundary is always the
CURRENT slip — `←` and `Home` hide what they move back past rather than leaving
it on the page, and `End` reveals the whole deck at once because that is where
the current slip now is. Opening on a `#slip-<id>` fragment reveals everything
up to and including the slip it names, so a permalink into the middle of a deck
still lands on a page with the run-up to it in place.

**A hidden slip is `display: none` and takes up no room**, so a page carrying a
deck is exactly as long as the slips currently on it. That is the point rather
than an implementation detail: the alternative — hiding a slip in place —
leaves a twenty-slip deck opening as one screen of content and nineteen screens
of blank page, and every camera target the engine computes is measured against
a document that is mostly nothing.

Three consequences worth knowing before turning it on for a deck, or off:

- **Click-to-advance cannot START a revealing deck.** The click handler is
  bound to `div.slipshow`, which has no area at all while the deck is empty, so
  the first move has to come from the keyboard (`→`, `↓`, `Space`, …). Click
  works normally from the first slip onwards. Listening on the document instead
  would let a click on a page's own heading or margin scroll a reader into a
  deck they had not asked to enter, which is the same thing the load-time
  camera rule below refuses to do.
- **The hiding is done by the controller, not by the markup.** `#slipshow`
  renders the identical DOM either way and only sets `data-reveal` on the deck
  root; `src/slipshow.js` adds a `slipshow-revealing` class at startup and a
  `slip-revealed` class per revealed slip, and `src/slipshow.css` hides on
  those. So a reader whose JavaScript never ran — a blocked script, an EPUB
  reader that executes none — gets the whole deck rendered rather than a blank
  page with no key that would fill it.
- **A PDF prints every slip**, `reveal:` or not: the paged branch has no camera
  to have arrived at one, exactly as it has no rows and no backgrounds.

`reveal:` is a `bool`; anything else panics naming it.

### The explicit array: `slips:`

An array whose elements may be already-rendered content, note NAMES (a
string or a label), or a mix of both:

```typst
#slipshow(slips: (
  slip("intro", title: [Written in the order it runs], fullscreen: true)[
    An explicit array is already ordered by construction.
  ],
  "a-note-authored-elsewhere",   // resolved against the registry by name
  slip("centered", enter: "center")[Overrides the deck default for one slip.],
))
```

A `str`/label element is looked up against the registry; a name matching
nothing PANICS rather than being silently skipped, because a named slip is an
assertion about what the presentation contains — a dropped slide should stop
the build, not slip through it. Anything else in the array is read as
content directly, exactly as it always has been.

**The three chrome arguments reach the tag-query route only.** An entry in a
`slips:` array that is already-rendered `#slip(..)` content was rendered before
`#slipshow` ever saw it, so a deck-level setting cannot reach inside it; such a
slip carries whatever its own `#slip(..)` call asked for — which is bare by
default too, since `#slip` inverts the same two defaults at its own call site
(see "A slip is bare by default, wherever it renders" above). An entry given by
NAME goes through `#window` like any queried slip and does follow the deck.

**`order:` and `reverse:` are refused if given a non-default value alongside
`slips:`** — an explicit array is already in the order it was written, so
there is nothing left for either to do. Drop them, or switch to `tags:`/
`where:` if the deck should be reordered.

**Passing `window(name)` inside a `slips:` array silently drops every
`#slip` option.** This is worth stating outright because nothing about it
errors: `#window` wraps its whole body in a `context { .. }` block, and a
Typst context block's content is opaque until it is evaluated — the code
that reads a slip's options back out of rendered content finds nothing
inside the unevaluated context and falls back to no options at all. The deck
still compiles and renders; `fullscreen`, `background`, `enter` and every
other `#slip` key are just gone. Pass the bare NAME instead
(`#slipshow(slips: (n1, n2))`, not `#slipshow(slips: (window(n1),
window(n2)))`) — a name defers rendering, and therefore defers context
evaluation, to the point where `#slipshow` reads the note's options straight
off its registry row rather than sniffing them out of content.

### Querying the registry: `tags:`, `where:`, `match:`

```typst
// a plain tag, or an array with `match:`
#slipshow(tags: "slip")
#slipshow(tags: ("slip", "demo"), match: "all")

// a predicate over the tag dictionary
#slipshow(tags: t => "slip" in t and "slip-fullscreen" in t)

// a predicate over the WHOLE row — fields `tags:` cannot see
#slipshow(where: r => r.page == "methods")

// both compose: `tags:` narrows first, `where:` narrows the survivors
#slipshow(tags: "slip", where: r => r.created != none)
```

`tags:` is `none`, a plain tag name or array (forwarded straight to core's
`#ideas(tags:, match:)`, along with `match:`, `"any"` by default), OR a
**predicate function** taking a note's tag dictionary and returning a bool —
see "The `a&b` query language" below for what that predicate route is for.
`match:` is ignored when `tags:` is a function: a predicate walks
`ideas(values: true)` itself and has no use for it.

`where:` is a predicate over the WHOLE registry row — `id`, `name`, `title`,
`text`, `label`, `tags` (the flat name array), `tags-dict` (the full
dictionary), `body`, `href`, `page`, `created` — for a selection `tags:`
cannot express at all: by date, by page, by title text, by body content.
`tags:` and `where:` may be given together; `tags:` runs first as core's own
cheap filter, and `where:` narrows whatever survives it.

### `order:` — four forms, all sorted through the same tie-break

- an **array of note names/ids** — position in that array is the sort key; a
  row named nowhere in it sorts last, in id order;
- **`"created"`** — ascending by the row's own `created` date;
- **`"slip-order"`** (the default) — ascending by the note's own `slip-order`
  tag (set through `#slip(order: n)`);
- a **key function** — `row => <comparable>`, called once per row over the
  WHOLE row (the same shape `where:` sees), returning an `int`, `float`,
  `str` or `datetime`. Every row's key must be the same type — Typst cannot
  compare values of different types — and `row.title` (content) is rejected
  with a hint to use `row.label` or `row.text` instead.

Every form treats "no key" the same way — an unmatched array position, no
`created`, no `slip-order` tag, a key function returning `none` — as LAST, in
id order, whatever `reverse:` says: `reverse: true` reverses only the KEYED
rows, so an undated note in a reverse-chronological deck stays the note with
no date rather than jumping to the front. `reverse:` is a `bool`, `false` by
default.

### `row:` — a key function for a COMPUTED row

```typst
#context {
  let layer = layer-of(todo-graph())   // @rookery/todos
  slipshow(tags: "todo", row: r => layer.at(r.name, default: none), order: ..)
}
```

Same shape as `order:`'s key-function form — a function called once per row,
over the WHOLE row — but for GROUPING instead of sorting: its return value
overrides that note's own `slip-row` tag for the purpose of `div.slip-row`
wrapping, without touching the note's tags or the deck's order at all.
`none`, or `row:` left at its default, falls back to the note's own
`slip-row` tag (set through `#slip(row: n)`); anything but an `int` or `none`
panics naming `row`.

This is the extension point for a deck whose rows are DERIVED rather than
authored — a dependency-graph layer, a date bucket, any group-by over a
field `#slip`'s own `row:` argument cannot see, because that argument only
ever runs at the call site, never over a note queried back out of the
registry. `row:` composes with either route (`slips:` as well as `tags:`/
`where:`): it groups whatever the route resolved, it does not reorder it, so
a caller still sorts (`order:`) so a row's members sit adjacent.

### `class:` — a key function for a COMPUTED class

```typst
#context {
  let keys = todo-slip-keys(todo-graph())   // @rookery/todos
  slipshow(tags: "todo", class: keys.class, row: keys.row, order: keys.order)
}
```

`class:`'s shape is `row:`'s, redirected: a function called once per row,
over the WHOLE row, but for a slip's CLASS LIST instead of its grouping. It
returns a `str` or `none`; anything else panics naming `class`. A
SPACE-SEPARATED string is several classes, since the result is appended to
the rendered `<section>`'s class list and joined into that one `class`
attribute verbatim (`_slip-attrs`, `src/slipshow.typ`).

The two share their override rule too, worth restating precisely: `class:`
beats a note's own `slip-class` tag by KEY PRESENCE, not value, exactly as
`row:` beats `slip-row` one section above. A `class:` function that computes
`none` for a note means "no class" — not "fall back to whatever tag it
carries" — because the key lands on every entry the function actually ran
on, and `#slipshow`'s `_entry-class` (`slipshow.typ`) tells "ran and said
none" apart from "never ran" by that presence alone. Leave `class:` at its
default and a note's own `slip-class` tag renders untouched.

`class:` composes with EITHER route, `slips:` included, unlike `order:`/
`reverse:` — which `slips:` refuses outright (see "The explicit array"
above) — because it neither selects nor reorders anything an explicit
array would otherwise conflict over.

This exists for a class that cannot be a tag because it is derived from
something outside the note itself. `@rookery/todos`' `ready` and `blocked`
are exactly that, and `class:` is the only route by which they reach a
slide's `<section>` at all — see that package's readme, "Horizontal decks:
#todo-slipshow".

### `edges:` — a key function for the slides a slide points at

```typst
#context {
  let keys = todo-slip-keys(todo-graph())   // @rookery/todos
  slipshow(tags: "todo", edges: keys.edges, class: keys.class, row: keys.row, order: keys.order)
}
```

The third of the computed key functions, and the only one whose result is a
LIST: a function called once per queried slide, over the WHOLE registry row,
returning an array of NOTE NAMES — each a `str` or a `label` — or `none`.
Anything else panics naming `edges`. A label arrives normalized to its string
form, so `("a", <b>)` and `("a", "b")` are the same answer.

**A name the deck does not show is DROPPED, not an error.** A deck is
frequently a slice of a corpus — `examples/dag/content/open-only.typ` is
exactly that — so a slide pointing at a note this deck happens not to show is
ordinary rather than a mistake, and so is a name that resolves to nothing at
all. This is deliberately the opposite of `slips:`'s own unknown-name panic
("The explicit array", above): there a name is an assertion about what the
deck CONTAINS, here it is a fact about a graph the deck is only a view of.

What reaches the DOM is `data-slip-edges` on the slide's own `<section>`: a
space-separated list of the ELEMENT IDS of the slides pointed at, already
restricted to slides this deck shows. It is absent entirely when nothing
survives the drop — an empty attribute would claim the slide points at
nothing in particular, which is a different thing from no edges having been
computed for it. There is no `slip-edges` tag to fall back to and there could
not be: which slides a slide depends on is a fact about a graph only the
deck's caller knows.

`edges:` composes with EITHER route, `slips:` included, for the same reason
`row:` and `class:` do — it neither selects nor reorders anything. What is
drawn from the attribute is "The connector curves" under "Customising the
CSS" below.

## The `a&b` query language

`tags:` accepting a predicate function is the extension point for a full
boolean grammar over tags, with no dependency on `@rookery/search` at all —
the grammar lives there, this package only needs the function shape:

```typst
#import "@rookery/search:0.1.0": parse-tag-query, eval-tag-query
#slipshow(tags: t => eval-tag-query(parse-tag-query("a&b").rpn, t.keys()))
```

`t.keys()`, and not `t`: a `tags:` predicate receives the note's tag
DICTIONARY, while `eval-tag-query` walks an array of tag NAMES (`tags.any(..)`
in `@rookery/search`'s `tagquery.typ`), and the keys are that array. Handing
the dictionary straight over fails the compile with `type dictionary has no
method 'any'` — loudly, at least, rather than quietly selecting the wrong
notes. `examples/search-order/` is the worked version.

`@rookery/slipshow` does not import `@rookery/search`, and does not need to.
Without it installed, a project still has explicit orderings (`slips:` with
an array, or `order:`'s array/function forms) and core's own `tags:`/
`match: "any"|"all"` — a predicate is one more way in, not the only one.

## The tag surface

Every `#slip` option lives in the note's own tag dictionary
(`src/tags.typ`), which is what makes it filterable and stylable with no
special-casing beyond tags a project already knows how to work with.

**Flat keys** — present or absent, value `none`, render as a pill wherever
`show-tags: true` is set, and each emits an `.idea-tag-<key>` CSS class on
whatever renders the slip. That is BOTH routes, not only the inline one:
`_render-slip` (`src/slipshow.typ`) renders an already-rendered `slips:`
array entry as its own inline `#idea`/`#slip` card, and renders every entry
resolved BY NAME — a `slips:` array of strings/labels, or the whole
`tags:`/`where:` query route — through `#window`. A `#window`'s own wrapper
wears the same `.idea-tag-<key>` classes and the matching
`data-rookery-tags` its card does, so a deck built from a tag query — the
common case, and the one every example here uses — carries this class on
every slip exactly as an explicit inline deck does:

| key | set by |
| --- | --- |
| `slip` | every `#slip` call, and `#idea(tags: ("slip": none))` by hand — the key a deck's `tags:`/`where:` query filters on |
| `slip-fullscreen` | `#slip(fullscreen: true)` |
| `slip-enter-<action>` | `#slip(enter: <action>)`, one of the eight camera actions |

**Valued keys** — present-filterable by key, but carry no pill (a valued tag
never gets one, the same rule core states for a tag like `depends-on`):

| key | set by |
| --- | --- |
| `slip-background` | `#slip(background: ..)` |
| `slip-order` | `#slip(order: ..)` |
| `slip-class` | `#slip(class: ..)` |
| `slip-row` | `#slip(row: ..)` |
| `slip-max-width` | `#slip(max-width: ..)` |

Flat keys are filterable by core's own `#ideas(tags:)`/`#window(tags:)` and
by `@rookery/search`'s `tags:draft`-style query language exactly like any
other tag — `tags:slip-fullscreen` finds every fullscreen slip in a rookery
without this package's help. A project reading these off a tag dictionary
directly (say, walking `ideas(values: true)` itself to style or list slips)
can use this package's own accessors rather than re-deriving the key names:
`is-slip(tags)`, `is-fullscreen(tags)`, `enter-of(tags)`, `background-of(tags)`,
`order-of(tags)`, `class-of(tags)`, `row-of(tags)`, `max-width-of(tags)` —
each takes the tag DICTIONARY (`row.tags-dict`), not a note name, the same
convention `src/tags.typ` uses throughout.

## Keyboard and mouse controls

Reachable from the keyboard and from a click, both bound in
`src/slipshow.js`:

| input | what it does |
| --- | --- |
| `→` / `↓` / `Page Down` / `Space` | advance to the next slip |
| `←` / `↑` / `Page Up` | go back to the previous slip |
| `Home` | jump to the first slip |
| `End` | jump to the last slip |
| `Esc` | **unfocus** — return the camera to wherever it was before the last `focus` action moved it (a stack, so repeated focuses undo in the reverse order); a no-op if nothing was ever focused |
| click anywhere inside the deck | advance to the next slip |

On a revealing deck (the default) every one of these also brings the deck up
to wherever it lands: forwards reveals, backwards hides again, and `End`
reveals the lot. Only the click has a starting condition — an empty deck has
nothing to click, so the first move is a keypress. See "`reveal:`" above.

Keyboard shortcuts are ignored outright while a modifier (`Ctrl`/`Alt`/
`Meta`/`Shift`) is held, and while focus sits in an `<input>`, a `<textarea>`
or any `contenteditable` element — a reader typing into a form on a slip
keeps their keystrokes.

Two behaviours are worth calling out because they are easy to assume
otherwise:

- **A click on a link, a `summary`, or a form control does not advance the
  deck.** The click-ignore list is `a, summary, button, input, select,
  textarea, label` — real navigation, a queried note's own `#window`
  disclosure toggle, and ordinary form controls all reach their own handler
  first, and only a click landing outside all of them advances the camera.
- **The camera does not move at all on page load unless the URL carries a
  `#slip-<id>` fragment matching one of the deck's own slip ids.** A page
  carrying a slipshow usually has its own heading and prose above the deck,
  and scrolling that out of view before the reader has pressed anything
  would be the deck taking over a page it only occupies part of. When a
  matching fragment IS present, the camera runs on load and jumps straight
  there. Either way, the very first press or click lands the camera on
  whichever slip is already current (the first slip, or the one the
  fragment named) rather than skipping past it to the next one — and on a
  revealing deck that press is also what puts that slip on the page in the
  first place.

There is no mouse binding beyond click-to-advance — no click-to-go-back, no
scroll-wheel binding, no drag. Ordinary scrolling (wheel, trackpad, the
scrollbar) still works exactly as it does on any page; it simply isn't a
navigation gesture this package assigns a meaning to.

The camera respects `prefers-reduced-motion: reduce` — a scroll or a
focus-zoom jumps instead of animating — and every move is clamped to what
the document can actually show, so a slip near either end of the page never
computes a target the browser would have to clamp silently on its own.

## Backgrounds

`#slip(background: ..)` takes a Typst VALUE, never a path string:

```typst
#slip(background: rgb("#eef4ea"))[A solid colour.]
#slip(background: gradient.linear(blue, purple))[A gradient.]
#slip(background: image("cover.png"))[An image.]
```

- A **`color`** becomes an inline `background: <hex>` declaration on the
  slip's own `<section>`.
- A **`gradient`** becomes an inline `background: <css-gradient-function>`
  declaration, translated stop-for-stop and angle-for-angle from Typst's own
  gradient math — linear, radial and conic all work, and a gradient's colour
  SPACE carries across too (`oklab`, `oklch`, Typst's `rgb` as CSS `srgb`,
  and `hsl` all have a direct CSS equivalent and are named explicitly;
  anything else falls back to plain sRGB interpolation rather than being
  resampled to fake it).
- **`image(..)` content** becomes a `div.slip-bg` layer — the section's own
  first child — wrapping whatever `<img>` Typst's HTML export produces for
  that image, rather than a CSS declaration at all.

Anything else panics, naming the value it was given; a bare string gets a
hint pointing at the fix (`background: image("cover.png")`, not
`background: "cover.png"`).

**Why an image is a layer, and not a CSS `background-image` with a `url(..)`
pointing at it.** An inline `style` attribute has nowhere to put a project
image path it could resolve correctly at build time: rheo copies no project
images into the build unless a `copy` glob names them, rewrites no `url(..)`
inside a stylesheet, and the page a slip's inline style sits on can be at any
depth in a site, so one relative URL written once in Typst has no single
correct value across every page it might end up on. Typst's own HTML export
already sidesteps all three problems for `#image` — it inlines the image as
a self-contained base64 `data:` URI with no path at all — so `#slip`'s job
is only to keep that already-resolved `<img>` where a browser will paint it
behind the slip's own content, which is what `div.slip-bg` is for.
**A project needs no `copy` glob for a slip background** — the image is
never a separate file in the build output at all, it is bytes inside the
page.

## Customising the CSS

The package stylesheet loads automatically once a project imports
`@rookery/slipshow` directly (`[tool.rheo.html] css_stylesheet =
"src/slipshow.css"` in the manifest — see "Import both packages" above for
why the direct import matters). A project layers its own rules on top the
ordinary rheo way, in its own `rheo.toml`:

```toml
[[html.assets]]
css_stylesheet = "style.css"
```

— see [rheo's own docs](https://rheo.ohrg.org) for the asset-config
mechanism itself; a package's `css_stylesheet` is additive, so this is one
more stylesheet linked alongside it rather than something to replace.

### A slip's own spacing

**A slip has no padding and no margin by default**: it is exactly its card,
and the rhythm between two slips is whatever `@rookery/core` already gives two
cards in a column. Three custom properties move that, set on `.slipshow` (or
anywhere above the slips) in a project's own stylesheet:

| property | default | what it does |
| --- | --- | --- |
| `--slip-pad` | `0` | the slip's own `padding`, and therefore how far a `background:` extends past its content |
| `--slip-gap` | `0` | the slip's `margin-bottom` — the space between one slip and the next |
| `--slip-scroll-margin` | `1.5rem` | how far above the viewport's top edge a programmatic scroll lands a slip |

```css
/* the airy frame this package shipped before decks opened empty */
.slipshow {
  --slip-pad: 3rem 1.5rem;
  --slip-gap: 3rem;
}
```

The default is zero because a progressive deck (`reveal:`, above) is walked
one slip at a time: a frame sized for a page showing every slip at once reads,
on a page showing exactly one, as a screen of empty space with a note
somewhere in it. `--slip-scroll-margin` is the one that stays a real number,
and it matters MORE at zero padding — the `up` and `left` camera actions land
a slip's top edge at the viewport edge, and with no padding standing in for it
the card would butt straight against the top of the window.

### A slip's own left rule

A slip also carries an opt-in left-rule channel, three more custom properties
set the same way as the three above:

| property | default | what it does |
| --- | --- | --- |
| `--slip-rule-width` | `0` | the slip's own `border-inline-start-width` |
| `--slip-rule-color` | `transparent` | the slip's own `border-inline-start-color` |
| `--slip-rule-gap` | `0` | `padding-inline-start`, the space between the rule and the slip's content |

All three default to inert, so a deck setting none of them renders
byte-identical to a slip with no rule at all. This package sets no colour and
names no status here — a consuming package such as `@rookery/todos` sets the
three to colour a slip's edge by its own vocabulary (`ready`/`blocked`/etc.),
which is otherwise unreachable: the card inside a slip has its own left
border, owned by `@rookery/core`, and `core.css` is unlayered throughout, so a
downstream package's layered rule can never beat one there regardless of
specificity (see that file's own comment on its border rule, marked
MEASURED).

A row's own internal spacing is separate and unchanged: `.slip-row`'s `gap`
reads core's `--idea-pad`, since several cards side by side want the rhythm a
themed project already gives a card's content beside its rule.

The slip DOM contract — `div.slipshow`, `section.slip`, `div.slip-row
[data-row]`, `div.slip-bg`, and the
`data-enter`/`data-reveal`/`data-index`/`data-row` attributes carried on them
— is documented in full at the top of `src/slipshow.typ`; that comment is the
one place the exact markup is pinned, and `src/slipshow.css`/
`src/slipshow.js` are both written against it.

Two classes in that contract are written at RUNTIME rather than by the Typst
side, and a project's own stylesheet can style on them: `slipshow-revealing`
on the deck root, meaning the controller is alive and the reveal is in force,
and `slip-revealed` on each slip up to the current one. Overriding
`.slipshow-revealing .slip:not(.slip-revealed)` is how a project changes what
an unreached slip looks like — dimmed instead of gone, say — rather than
turning the feature off, which is `reveal: false`'s job.

`src/slipshow.css` reaches a slip's own content — a `#slip`/`#idea` card, or
a transcluded `#window` — only through core's `[data-rookery="box"]`/
`[data-rookery="window"]` role attributes, never through the
`.idea-box`/`.idea-window` classes: the classes are core's renameable public
hook, the attributes are its stable one. A project's own stylesheet reaching
into a core element from outside either package should do the same —
select on `[data-rookery="..."]`, not `.idea-*`. Core's own `--idea-*`
custom properties (documented in `@rookery/core`'s readme, "The theme") are
still the tokens to reuse for anything that IS a card's chrome — a slip's
border, its tab, its label size — where this package's own deck-level rules
(the rhythm between slips, fullscreen height, background sizing) are new
dimensions of the deck itself and deliberately do not borrow from them.

### The connector curves

A deck whose slides declare `edges:` (above) draws them. One curve per edge,
leaving the BOTTOM of the source slide's left rule and arriving at the TOP of
the target's, stroked with a gradient running from the source rail's colour
to the target's. Reading down the deck then reads the graph: the rails are
the nodes, the curves are the edges.

The colours are whatever the rails already are — each stop is read off its
endpoint's resolved `border-inline-start-color`, so this package names no
status here any more than it does on the rule itself. Two properties tune
the stroke, set the same way as the rule's three:

| property | default | what it does |
| --- | --- | --- |
| `--slip-edge-width` | `--slip-rule-width` | the curve's `stroke-width`, so by default a curve is exactly as thick as the rails it joins |
| `--slip-edge-opacity` | `0.85` | the curve's `opacity` |

**The layer is script-drawn** (`src/edges.js`), so a reader whose JavaScript
never ran gets the rails and no curves at all: the deck still reads, it just
does not draw its own graph. Nothing about the markup differs — the
declaration is in `data-slip-edges` either way.

Two cases where a declared edge is deliberately NOT drawn, both ordinary
states of a live deck rather than errors:

- **an endpoint the progressive reveal has not shown yet** (`reveal:`,
  above). A hidden slide has no position, so its curves appear as the reader
  advances rather than being drawn to empty space.
- **two endpoints in the same row.** A row is a set of slides that depend on
  nothing from each other, so a same-row edge means a deck's `row:` and its
  `edges:` disagree, and a curve doubling back into its own row would assert
  a shape the layout is already denying.

One known limitation: a `.slip-row` is its own horizontal scroll container
and this layer spans every row, so a curve crossing a scrolled row is drawn
in full rather than clipped to it.

## This is a built package

`@rookery/slipshow` resolves through `dist/lib.js` for its JavaScript: an
edit to `src/camera.js`, `src/edges.js` or `src/slipshow.js` does nothing
until `just build` runs, the same fact `@rookery/search`'s own readme states about itself. The
Typst entrypoint and the stylesheet are the opposite — `src/lib.typ` and
`src/slipshow.css` are read straight out of `src/`, so an edit to `#slip`,
`#slipshow` or the CSS takes effect immediately, with nothing to rebuild.

## Examples and demo

`examples/` holds a set of complete, runnable rheo projects, one per
capability — see `examples/readme.md` for the exact shape of each and `just
examples` to build all of them at once; every one is self-contained and can
be copied out of this repo and run unchanged.

`demo/rheo/` is this package's own CI fixture: a small rookery exercising
both definition routes side by side — `index.typ` builds its deck from a tag
query, `explicit.typ` from an explicit array, `predicate.typ` from a `tags:`
predicate function — plus the paged-target fallback. `deck.typ` there is the
realistic dozen-slip presentation this package is built for, worth reading
end to end for how `#slip`'s options come together on real content.
