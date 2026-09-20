# @rookery/core

Atomic, interlinked, transcludable notes for Typst — Zettelkasten-style, and
rheo-aware where rheo is present.

A note exists ONLY where you write `#idea("name")[...]`. There is no document
show rule and no "every heading is a note" behaviour — a labeled heading is
just a labeled heading. `#idea[body]` (no name, no title) works too: a TITLED
one takes a slug of its title, and an untitled one takes a slug of its own
body instead — its own opening words, capped and suffixed with a short digest
so two notes that open the same way still land apart (see "Unnamed notes:
where their names come from"). Either way it names itself by its own opening
words wherever it is referred to (see "Derived labels"), and wears its name as
a permalink — `[idea:my-title]`-style for the titled one,
`[idea:<body-slug>-<digest>]`-style for the untitled one — which is how you
discover a generated name in order to paste it into a `#window`.

```typst
#import "@rookery/core:0.1.0": idea

#idea[A frictionless note — names itself from its own opening words.]
#idea("etal")[A pinned note — its name is always `idea:etal`.]
```

Full signature: `idea(level: 1, title: none, tags: (), tag: none, base-tags: none,
exclude-tags: (), created: none, display: (:), display-date: auto, display-tags: auto,
display-frame: auto, display-name: auto, display-label: auto, display-background: auto,
display-context: auto, display-backlinks: auto, display-title: auto, ..args)`, where
the sink accepts the body alone, `(name, body)`, or `(<name>, body)` — the name
may be a string or a Typst label, identically. All positionals may also be
omitted, giving an unnamed note with an empty body — this is how a
title-only note is written: `#idea(title: [hello])`.

`display-frame: false` drops the card's BOX — its left rule and the indent that goes
with it — and nothing else: the note still registers, still carries its tags and
its anchor, still renders its hat and its body. `display-name: false` drops the
`[idea:<name>]` permalink from the hat. See "Dropping a note's frame" below for
both, and "The `display:` dictionary" for how `display-frame`/`display-name` relate
to the `display: (..)` dictionary these two also read from.

## The `display:` dictionary

`#idea` and `#window` each take a `display:` dictionary alongside all nine
individual `display-*` arguments — `display-date`, `display-tags`,
`display-frame`, `display-name`, `display-label`, `display-background`,
`display-context`, `display-backlinks` and `display-title`. Both name the
same nine possible keys with the prefix dropped: `display: (frame: false,
tags: true)` sets the same thing as `display-frame: false, display-tags:
true`, and a call site can mix the two — the dictionary for several keys at
once, an individual argument for the one that needs to differ. A function
with no use for a key still accepts it and ignores it, on both spellings
alike: `#idea` does nothing with `display-label`/`display-background`, and
`#window` does nothing with `display-context`/`display-backlinks`/
`display-title`, because those three describe a minted page and a window is
not one.

**Precedence, lowest to highest:** core's built-in default, then the
document-wide `rookery(display: (..), ..)` setting — all nine keys have one —
then the call's own `display: (..)` dictionary, then an individual
`display-*` argument on that same call.
Each tier only ever fills in what the tier above it left unset: every
`display-*` argument on `#idea` and `#window` defaults to `auto`, meaning "no
opinion", which is what lets a lower tier show through. `#ideate` is the one
exception — its `display-frame`/`display-name` keep their inverted `false`
defaults, because `#ideate` is a caller with a real opinion (see "Its inverted
defaults" below), not the bottom of the stack.

```typst
#idea(display: (frame: false, tags: true), display-frame: true)[..]
// frame: true wins — the explicit argument beats the dictionary
```

## 0.1.0

This is the first release of `@rookery/core`, and of the seven packages that
sit beside it — `@rookery/bibtex`, `@rookery/cfps`, `@rookery/meetings`,
`@rookery/pinboard`, `@rookery/search`, `@rookery/slipshow` and
`@rookery/timeline`. The family is version-aligned, and they are meant to be
read and installed together: a project on `rookery:0.1.0` should be on
`rookery-search:0.1.0` too, because the idea registry's state key is NOT
versioned and two packages disagreeing about the record shape fail at compile
time rather than politely.

## Setup, and the `idea:` prefix

Nothing above needed any setup, and that stays true. One optional template
does all of it in a line, and is the only place anything is configurable:

```typst
#import "@rookery/core:0.1.0": rookery, idea, window
#show: rookery.with(
  prefix: "note",                 // names are now `note:etal`
  idea-dir: "ideas",              // ...but minted pages stay at `ideas/`
  css-prefix: none,               // ...and classes follow `prefix`: `note-title`, not `idea-title`
  window-unfurl: 2,               // a window inside a window unfurls one level
  theme: (
    link-color: "rgba(230, 140, 0, 0.16)",  // hover background on any link
    fold-color: "rgba(255, 190, 40, 0.07)", // ...and on a foldable block
    date-color: rgb("#a08a5a"),
  ),
)
```

`#show: rookery` does exactly eight things: it publishes the name prefix, the
minted-page directory (`idea-dir`, see "Standalone note pages" for how it
resolves), the CSS class stem (`css-prefix`, see just below), the
nested-window unfurl budget, the minted-page template
(`idea-page-template`, see "Standalone note pages"), the bibliography (see
"Bibliographies") and the theme, and it installs `show ref: hyperlink` (see
below and "Referencing a note") so `@idea:etal` renders the note rather than a bare
figure number. It sets no other styles and wraps `doc` in nothing. It emits
nothing of its own either, with one exception: a page that cites something
outside every idea gets a references block after its content, because a
citation no bibliography claims fails the build. On a document with no notes
in it, it is a no-op, and even the `ref` rule passes every non-rookery
reference straight through. Pass `refs: false` to keep the rest and skip that
rule.

`hyperlink-target-minted: true` (the default) sends `@idea:etal` to the note's
own minted page. Pass `hyperlink-target-minted: false` to make every
`@idea:etal` in the document link to the note's in-context anchor instead, the
same destination `#link(label("idea:etal"))` always uses. It is `#hyperlink`'s
own parameter of that name, handed straight to the installed rule, and is
ignored when `refs: false`, since there is then no installed rule for it to
configure.

`page-titles: "title"` (the default) names a page — in a minted note's
Context link and in its Backlinks list of pages — by rheo's own spine title
for it. Pass `page-titles: "path"` to name it by its source path instead,
content directory and extension dropped: rheo derives a spine title from a
page's file stem, so a project with one page per directory can end up with
many pages titled identically (every `index.typ` titled "Index"), where a
path is unique by construction. Document-wide, like the settings above it —
the last `#show: rookery` to run settles it for every minted page.

`prefix` must be a non-empty string with no `:` in it (the separator is added
for you). `idea-dir` must be `none` (the default) or a non-empty string with
no `/` or `:` in it — see "Standalone note pages" for what it does and, if you
already set a custom `prefix`, for a breaking change to read before you
upgrade.

**`css-prefix`** is the CSS class stem — `<stem>-title`, `<stem>-tag-<tag>`,
and every other class this package emits. It resolves the same two-step way
`idea-dir` does: `css-prefix:` when you set one, else the resolved `prefix` —
so `prefix: "note"` alone gets you `note-title`/`note-tag-<tag>` classes, not
`idea-*`, and setting `css-prefix` explicitly pins the class stem independent
of the name prefix (keep `idea-*` classes while renaming names, or the reverse).
It must be `none` (the default) or a non-empty string usable as a CSS class —
no whitespace, `.`, `#` or `:`.

**Your OWN stylesheet has to follow the stem you choose.** Rename `prefix`
with no `css-prefix:` override and every class in your project's CSS that
targeted `.idea-*` needs the same rename. The package's own styling never
goes through the class at all, though: `src/core.css` selects the
`data-rookery="..."` role attributes, which never change — so a renamed stem
can leave YOUR stylesheet's rules stranded, but it can never unstyle a page.

### Nested windows, and `window-unfurl`

`window-unfurl` counts **levels of transclusion**, and every number on the
scale means one thing:

| `window-unfurl` | what a `#window` renders |
| --- | --- |
| `0` | **a link only.** The note's title, linked to the note's own page — no summary row, no disclosure, no body. Nothing is transcluded anywhere in the document. |
| `1` | **the default.** The note renders once, and a `#window` written *inside* it collapses to its `[idea:etal]` permalink — the block you opened shows one note rather than a tree of them. |
| `n` | the note renders, and `n-1` further levels of nested windows unfurl as real windows, collapsing at the `n`th. |

`#window(..., unfurl: n)` overrides the document setting for one call site, and
that is per call site because all three readings are reasonable on the same
page: an index of forty backlinks wants the collapse, a dense index may want no
transclusion at all, and a homepage showing one note in full may want a level
or two.

A nested `#idea` — one note written literally inside another's body — is a
different thing and always renders in full, whatever the unfurl budget.

**Migrating from the old scale.** Before this, `0` was the default and `n`
unfurled `n` nested levels. Every number moved up by one, so **add one**: a
project that set `window-depth: 2` wants `3`. There is no automatic upgrade,
and a project that sets nothing is unaffected — the default renders exactly
what it always did.

The budget is what makes this safe. A note that windows itself, or two notes
that window each other, would otherwise expand forever; with an unfurl budget
they bottom out at the collapsed permalink, and there is no configuration that
can make them not.

The budget is not free — each level re-renders the transcluded note's body, so
`n` levels over a fan-out of `k` windows is `k^n` blocks in the page. Small
numbers.

A note's own **minted page** counts from one level further in, because a minted
page is not a transclusion: it shows the note as the page's own top level, so a
`#window` written in that note's body is a top-level window there and renders
with a top-level window's budget, exactly as it does on the page the note was
hatched in. What `window-unfurl` governs on a minted page is the windows nested
inside *those* — at the default of `1` they collapse to their permalinks. (At
`window-unfurl: 0` a minted page's own windows collapse to their permalinks too,
which is the link that setting asks for.) A minted page's **Context** and
**Backlinks** rows are pinned at `unfurl: 1` whatever the document sets: an index
of what points here is a list to scan, not prose to unfurl.

### The theme

Five colours, three lengths and one font — the whole of what the package will style
for you:

| key | what it colours | default |
| --- | --- | --- |
| `link-color` | hover background on **any** rookery link | `rgba(128, 0, 255, .12)` |
| `fold-color` | hover background on a foldable window block | `rgba(0, 100, 255, .05)` |
| `name-color` | the `[idea:etal]` permalink, the note's name | `gray` |
| `date-color` | an idea's/window's date, where shown | `gray` |
| `border-color` | the rule down a note, a window and an outline, and the tab that rules off the top of a card | falls back to `link-color` |
| `rule-width` | how **thick** every one of those rules is, markers included | `2px` |
| `pad` | the indent between a note's rule and its content, and a window's right padding | `0.5em` (halved under 600px) |
| `label-font` | the face every **hat** is set in — a note's name, and `#ideas-outline`'s title | `monospace` |
| `label-size` | the size every **hat** is set in — a note's name, and `#ideas-outline`'s title | `0.57rem` |

The first two are the look, and the contrast between them is the point. Both
are hover *backgrounds*, so they compare like with like: the lighter blue
belongs to the fold — a block that only opens and closes — and the stronger
purple to every link, which actually goes somewhere. (Forester makes the same
split with one blue at two alphas; two hues survive being read quickly.)

`link-color` reaches every link rookery is responsible for, not just the
permalink: an `@idea:other` reference, and an author's own link inside a note
or a transcluded copy of one. It is deliberately *not* a bare `a:hover` — this
stylesheet is injected into every page of a rheo project, and a package has no
business restyling a site's nav.

Each key is also a granular parameter of its own, and the granular form
**wins** over `theme:` — so the two compose:

```typst
#show: rookery.with(theme: MY-THEME, link-color: rgb("#ffd166"))
```

reads as "my theme, but that one colour". Precedence, least specific first:
the stylesheet's default → `theme:` → the granular argument. Anything left
unset at every level stays the stylesheet's default and nothing is emitted for
it.

Values are Typst colours, or raw CSS strings when you want something Typst's
colour type can't express (`"rgba(0, 100, 255, .1)"`, `"var(--accent)"`,
`"transparent"`). A misspelled key is a build error naming the valid ones, not
a silently ignored colour.

`rule-width` and `pad` are the exceptions, being lengths rather than colours: pass
a Typst length (`2pt`, `0.15em`) or a CSS length string (`"3px"`) — a string is the
only way to say `px`, which Typst has no literal for.

`rule-width` is deliberately ONE value for every line that frames a note, so a
card, a window, the tab across the top of both and `#ideas-outline`'s rule and row
markers can never disagree about their own weight. The separators above a footnotes
or references block are not governed by it: those are apparatus, not the frame.

`pad` is the matching ONE value for the indent — how far a note's content sits from
the rule beside it, and on a window how far it sits from the right edge, so the two
sides agree. Three other things measure the same distance in order to close the
frame's corner on that rule: the tab's own offset, the top rule's stub, and a folded
window's tint. They all read this, so a value of your own keeps the corner shut
rather than opening a notch in it.

`label-font` is the third exception, being neither a colour nor a length. A **hat**
is the stub of rule out of a frame's top-left corner with a label sitting on its
end — a note's `[idea:etal]` name wears one, and so does `#ideas-outline`'s
"Contents", because both label the frame they sit on. This is the face they are set
in, and it is deliberately the only `font-family` the package sets: your prose is
yours. Pass a CSS font stack as a string, or the family names as an array and the
commas are added for you:

```typst
#show: rookery.with(theme: (label-font: ("Berkeley Mono", "monospace")))
#show: rookery.with(label-font: "Berkeley Mono, monospace")   // identical
```

The default is `monospace`, the **generic** family — so out of the box a hat is
whatever monospace face the reader has configured, not one this package chose for
them. A name is machine text and a monospace face says so without a word of
explanation. A `#footnote` or references block's own heading is NOT a hat and does
not follow this: those label a list inside a note, not the note's frame.

The size a hat is set in travels with its face — a project theming `label-font`
should usually theme `label-size` alongside it, since both describe the same
object.

`label-size` is the fourth exception, a length like `rule-width`/`pad` but with a
twist: the primary way to set it is a **string in `rem`**, not a bare Typst
length, and that matters more here than for the other two. `--idea-label-size`
is not just cosmetic — the tab's lift, a window's summary lift, a folded
window's tint offset and the footer's own padding are all expressed as
`calc()`s against this same variable, so retheming it keeps the card's corner
shut instead of opening a notch. It is `rem`, deliberately, not `em`: a name is
one object wherever it appears, and `em` made it three visibly different
sizes depending on context — 0.57 of an `#idea` heading, 0.57 of a minted
page's `<h1>`, 0.57 of a window summary's body text (MEASURED, on
rookery.ohrg.org). `rem` keeps a hat one size everywhere; `em` does not. This
package doesn't police a theme's choice of unit — `em`, `px`, anything CSS
accepts is still a legal value — but a theme reaching for something other
than `rem` here is opting back into that per-context drift.

```typst
#show: rookery.with(theme: (label-size: "0.8rem"))
#show: rookery.with(label-size: "0.8rem")   // identical
```

Like the prefix, the theme is **one value for the whole document** — two
vertebrae asking for different themes get whichever the spine ends on, not one
each. Apply the same arguments in every vertebra.

**The prefix is ONE value for the whole document.** Under rheo, apply the
template in every vertebra that uses the package — imports are per-file, so a
vertebra that omits it loses the `ref` rule. It does not lose the prefix: a
file that never applies the template still mints names with whatever prefix the
document settled on, which is what keeps a `#window` across that boundary
resolving instead of panicking on a name nothing registered.

**CSS class names follow the prefix too, by default** — see `css-prefix`
above: the heading is `idea`/`idea-tag-<tag>` and the permalink is
`.idea-label` only where `prefix` reads `idea` (the default) or `css-prefix`
was set to pin it there deliberately.

## Dropping a note's frame

Full signature: `window(..args, limit: none, folded: false, display: (:), display-date: auto,
display-tags: auto, display-frame: auto, display-name: auto, display-label: auto,
foldable: true, reserve-title: true, display-background: auto, display-context: auto,
display-backlinks: auto, display-title: auto, backlink: true, unfurl: auto, tagged: none,
match: "any", filter: none, sort: auto)`. `display-context`, `display-backlinks` and `display-title` are
accepted for parity with `#idea` and the `display:` dictionary, and ignored here — they
describe a minted page, and a window is not one.

```typst
#idea("bare", display-frame: false)[A note with no left rule and no indent.]
#window("bare", display-frame: false)

#idea("quiet", display-name: false)[A note with no permalink, and so no hat at all.]
#window("quiet", display-name: false)
```

`display-frame:` is on both `#idea` and `#window`, `true` by default, and it governs
exactly one thing: the box a note wears — its `border-left` and the
`padding-left` that goes with it. Everything else is untouched. The note still
registers, still carries its tags and its classes, still renders its hat, its
title, its body, its footnotes and its references, and a window still opens and
closes.

**It is a per-note switch, not a theme setting.** `rule-width`, `border-color`
and `pad` (see "The theme" above) move the frame for the WHOLE document, which is
what you want when a site's notes should read lighter or heavier. This is for the
one note, or the one view, where the frame is wrong while every other note on the
site keeps it — a presentation being the case it was added for.
[`@rookery/slipshow`](../../slipshow/0.1.0) puts each slip in a `<section>` of its
own, and a card's frame inside that reads as a frame around a frame.

**The mechanism, because a project may need to know it.** The Typst side emits a
second attribute, `data-rookery-bare`, on the note's `[data-rookery="box"]` or
`[data-rookery="window"]` wrapper, and `src/core.css` carries the matching
override. **A project cannot do this from its own stylesheet**, however it writes
the selector: `core.css` is unlayered throughout, unlayered CSS beats layered CSS
regardless of specificity, so a downstream rule can never outrank
`[data-rookery="box"] { border-left: .. }` here. Winning requires being more
specific within this sheet, which is why the switch lives in the package. It is
the same trick `#idea-body` uses with `data-rookery-plain`, and the two are
deliberately separate attributes: `plain` means "a bare body was rendered, do not
draw a box around it" and applies to windows only; `bare` means "this note was
asked not to wear its frame" and applies to a card as well.

A project styling on it should select on the attribute
(`[data-rookery-bare]`), which is stable, rather than on any class.

### `display-name:` — and the whole hat with it

`display-name:` is on `#idea` and `#window` too, `true` by default, and it drops the
`[idea:<name>]` permalink — the chip that leads a card's hat and a window's
summary.

**On an ordinary note that also takes the whole hat away, and that is the point.**
A tab holds three things and all three are optional: the permalink, the tag pills
(`display-tags:`, off by default) and the date (`display-date:`, off by default). Turn
the permalink off on a note that has neither of the others and the tab has nothing
in it, and `[data-rookery="tab"]:empty { display: none }` in `src/core.css`
collapses it — the same trick `h*.idea:empty` plays for a titleless note's
heading. The `<span>` is still emitted: it is the element every other tab rule is
written against, and it comes straight back the moment a pill or a date is turned
on. So `#idea("x", display-name: false, display-tags: true, ..)` still shows its pills, in
a tab, exactly where they were.

**The cost, and it is a real one for an UNTITLED note: a permalink is the ONLY
way to discover its auto-generated name.** There is no `show heading` rule and
no template hook — the chip is it. A note written `#idea[..]` and rendered
with `display-name: false` therefore has a name nothing on the page reveals, so
nobody can write a `#window` for it. Give a note a name (`#idea("x")[..]`) if
it should stay linkable, or leave `display-name` on.

A TITLED note is cheaper to turn `display-name` off on: its name is a slug of the
title (see "Unnamed notes: where their names come from"), so anyone who can read
the title on the page can reconstruct `idea:<slug>` without the chip. Two
notes titled alike cannot both build this way — the second one fails at build
time rather than landing on a suffixed name the title alone couldn't predict.

### `display-label:` — an authored title, or nothing

`display-label:` is on `#window` alone, `true` by default, and it chooses which of a
record's TWO name fields the summary shows:

- **`label`** (the default) — the derived name: the authored title where there is
  one, else the first sixty characters of the note's own body.
- **`title`** (`display-label: false`) — the AUTHORED title only, and nothing at all
  for a note nobody titled.

The default is right for what a window usually is: a REFERENCE to another note,
whose summary is the clickable thing that names it, and which is often written
`folded: true` with nothing but that summary showing. A derived name is exactly
what that case wants.

**It is wrong where a window RENDERS a note rather than referring to it.** An
unfolded window sits directly above the body its label was derived from, so an
untitled note prints its own first line twice — once as the summary and once as
the first line of the prose beneath it. That is the case
[`@rookery/slipshow`](../../slipshow/0.1.0) hits on every slide.

**The trap: `display-label: false` with `folded: true`.** A titleless note then has an
empty summary, which is a disclosure control with nothing in it — nobody can
recognise it or click it with intent. Use the pair only where the notes are known
to be titled, or leave the window unfolded.

Nothing outside `#window` changes: `#ideas-outline`, `@rookery/search` and a
minted page's `<title>` all keep reading the derived `label`, because that is
what a note is CALLED. This is a per-window display switch, not a change to the
note's name.

### `foldable:` — a slide is not a disclosure

`foldable:` is on `#window` alone and `true` by default. `false` renders the
window with no disclosure at all: no `<details>`, no `<summary>`, nothing to
click and nothing that can hide the body.

It is not the same switch as `folded:`, and the pair is easy to conflate:

- **`folded:`** sets the INITIAL state of a disclosure that exists. A reader can
  still open or close it.
- **`foldable:`** decides whether there is a disclosure to begin with. `folded:`
  is inert once this is `false`, the same way it is already inert at `unfurl: 0`
  and on a paged target.

For a window that IS the thing being read rather than a pointer to it — a
[`@rookery/slipshow`](../../slipshow/0.1.0) slide, where a stray click that
folded the slide shut would be a bug and never an intention. The summary row
keeps its name and its title and stops advertising a click; the permalink inside
it is still a link and still navigates.

### `reserve-title:` — the blank line a titleless summary keeps

`reserve-title:` is on `#window` alone and `true` by default. It governs one
thing: the blank line a summary with NO title reserves where a title would have
gone. `false` drops it.

**It does nothing to a window whose note has a title.** The reservation only
ever applied to a summary with no title span, so a titled window keeps its
ordinary spacing whichever way this is set — including when it is also
`foldable: false`.

Reaching for it means you are already passing `display-label: false`: with the
default `display-label: true` a summary is essentially never titleless, because the
derived label stands in (see above). The pair `display-label: false` +
`reserve-title: false` is a slide — a titleless note renders as its body with a
bare name above it and no dead space between them, and a titled one renders with
its title and the normal spacing.

The reserved line exists for good reason everywhere else: two folded windows
side by side, one titled and one not, measured 26.02px against 8.02px, and the
short one read as cramped rather than as a smaller variant of its neighbour.
Keep it wherever windows sit in a row.

### `display-background:` — the hover tint, on its own switch

`display-background:` is on `#window` alone, `true` by default, and `false` drops
the window's hover tint.

It is independent of [`display-frame:`](#dropping-a-notes-frame), which takes the
left rule and the indent and leaves the tint alone. Both directions are wanted:
a slipshow slide asks for `display-frame: false` and KEEPS the tint, because the
frame is decoration and the tint is the slide answering a pointer. Nothing
implies anything else here — three switches, three decisions.

### `backlink:` — a view is not a reference

```typst
#window("etal")                    // a reference: this counts as a link
#window("etal", backlink: false)   // a rendering: it does not
```

A `#window` normally IS a reference. You wrote it in a note's prose, so that note
links to the one it transcludes, and `etal`'s Backlinks should say so.
`backlink:` is `true` by default for exactly that reason.

**A DERIVED view is not a reference.** A deck, an index, a preview pane: the
window renders a note it selected by query, and nobody wrote a link at all. Left
announcing, a page of twenty queried notes puts itself in twenty notes'
Backlinks, and a call site that runs once per note on EVERY page of a site — a
search preview — would make every page "link" to every note in the rookery. That
last case is why [`#idea-body`](#idea-body--one-notes-body-rendered) exists;
`backlink: false` is the same escape without giving up the chrome, the disclosure
or the body.

**What it does NOT do: stop the marker being emitted.** `#window` announces its
targets in a `metadata` element up front — the figure it eventually builds lives
inside a `context` block and does not exist yet when the graph is walked — and
THREE things read that marker, only two of which are backlinks:

| reader | what it wants | reads `backlink:`? |
| --- | --- | --- |
| `_outbound` (`src/links.typ`) | the note-level graph | yes |
| `_page-outbound` / `_page-links` (`src/outline.typ`) | the page-level graph | yes |
| `_cite-scan` (`src/bib.typ`) | that a nested window will CLAIM some of the enclosing note's citations | **no** |

So the flag rides inside the marker's payload rather than gating its emission.
Skipping the element would silently break citation partitioning in any note that
cites something and windows something — the enclosing note would claim citations
the window is about to render itself.

`_page-outbound` is worth one more sentence, because its case is not symmetric:
reaching the marker there both counts as a page link AND stops the walk, so that
the transcluded body's own links belong to that note rather than to the host
page. `backlink: false` drops only the first. The walk still stops, or a deck
page would inherit every link inside every note it shows.

**Both switches ride the nested-note payload.** A note written inside another
note's body is rebuilt from a `#metadata` record when its parent is transcluded or
minted, never from the original call site, so the resolved `display` dictionary's
`frame` and `name` keys are stored on that record and read back with a default of
`true`. A nested `#idea(display-name: false)` therefore stays bare when its parent
is windowed, and a record written before these keys existed reads as an ordinary
framed, permalinked note.

**A tag-selected window counts as a link too, once the registry is final.**
`#window(tagged: "phd")` counts as a link to every note the selection matched
— from the page the window sits on, and from the enclosing note when the
window is written inside one — exactly as `#window("etal")` counts as one to
`etal`. `#window(tagged: "phd", filter: ..)` counts as a link to nothing, and
neither does `#window(filter: ..)` alone: `tagged:` and `filter:` are ANDed at
the call site, but `filter:` is a function and nothing in a `metadata`
payload can carry one, so resolving the tag half alone would announce
backlinks from notes the window never actually showed — a missing backlink is
a smaller wrong than a fabricated one. `backlink: false` suppresses all of
it, tag selection included.

```typst
#window(tagged: "phd")                            // links to every match
#window(tagged: "phd", filter: t => "draft" in t) // no backlink at all
```

## `#ideate` — every paragraph a note

```typst
// as a function, on one block
#ideate[
  First paragraph — one note.

  Second paragraph — another.
]

// or as a document show rule
#show: rookery
#show: ideate

Every paragraph below is a note.
```

The one place in this package where a note is INFERRED rather than written. It is
opt-in — per block or per document — and changes nothing for a project that never
calls it: `#idea` stays deliberate, and there is still no "every heading is a
note" rule anywhere.

**One function serves both call forms.** `#show: f` at the top level means
`f(rest-of-the-document)`, so a plain function of one positional content argument
already IS a show rule. There is no second name to learn.

**Order matters when both show rules are used.** Write `#show: rookery` first and
`#show: ideate` second. Typst composes those as `rookery(ideate(rest))` — `ideate`
sees the raw markup and the template wraps its output, which is the order that
works. The reverse hands `ideate` a body the template has already transformed.

### What counts as a paragraph

There is no `par` element in a markup content tree; Typst builds those at layout
time. `#ideate` splits on `parbreak()`, which is the only separator markup
actually has, and that decides everything:

| in the body | what happens |
| --- | --- |
| a run of prose | one note |
| a bulleted or numbered list | ONE note — its items are children of the same run, with no parbreak between them |
| a figure, a code block, a raw block | one note |
| a heading alone | **passed through unchanged, not a note** |
| whitespace at the edges of a `[..]` body | dropped |
| a group holding nothing but whitespace and paragraph breaks | dropped |
| a group holding nothing an author wrote (a `context` or `metadata` node alone) | passed through unchanged, not a note |

A heading is structure: it names the run of notes under it, and wrapping it would
give you a card whose entire body is a title. A heading with prose beside it in
the same paragraph is not heading-only and does become a note.

`#ideate` works on ONE level — the paragraphs of the body it was handed. It does
not descend into them.

### Choosing what starts a note

`separator:` says where one note ends and the next begins. Four spellings are
accepted:

| `separator:` | what starts a note |
| --- | --- |
| `par` | every paragraph |
| `parbreak` | the same thing |
| `heading.where(level: 2)` | every `==` — any level |
| `none` | nothing splits — the whole body is ONE note — the default |

```typst
#ideate[..]                                      // default: the whole block is one note
#ideate(separator: heading.where(level: 2))[..]  // every `==` starts a note
#ideate(separator: par)[..]                      // one note per paragraph
```

The heading form is most useful as a show rule, the case that motivated the
argument at all:

```typst
#show: rookery
#show: ideate.with(separator: heading.where(level: 2), tags: "weeknotes")
```

**`par` names the split; it does not change it.** There is no `par` element in a
markup content tree — Typst builds paragraphs at layout time — so both par-mode
spellings still split on `parbreak()`. `par` is the honest name for what you are
asking for, `parbreak` the mechanism underneath.

**`heading(level: 2)` on its own is illegal Typst** — `error: missing argument:
body`, since `heading` takes its body positionally. It is the first thing anyone
tries. Typst's own compiler rejects it before `#ideate` is reached, so no error
message of ours can catch this particular mistake however well worded, and
`heading(level: 2)[]` — the bracketed version someone reaches for next — is
refused too, by `#ideate`'s own panic. `heading.where(level: 2)` is the
spelling to use instead: a selector has no accessors at all, so reading a level
back out of it means parsing its `repr()`. That parse is asserted in the test
suite, so a Typst release that changes the format fails the suite rather than
silently mis-splitting a document. A selector over another element, one
carrying extra fields, or one built with `.or(..)` is refused with a panic
rather than guessed at.

**`separator: none`**, the default, wraps everything in one note — it is `#idea`
with `#ideate`'s inverted defaults and its `tags:`, which is what turns a whole
page into a single note without writing `#idea` by hand — the common case for a
document-level `#show: ideate`, one page being one idea. In this mode a trailing
`context` or `metadata` node ends up inside the note rather than beside it, there
being only one group; it renders nothing.

The one note this mode mints has no heading of its own to title or name itself
by, so both default off `document.title`: the title IS `document.title`, and
the name is `slug(document.title)` — stable, unlike the body-derived form it
would otherwise fall to, which moves whenever the page's own content changes.
A `title:` passed to `#ideate` wins over this, and `#ideate-name` still wins
the name outright. With no document title set, this changes nothing: the note
mints titleless, under the body-derived fallback described in "Unnamed
notes: where their names come from", as always.

Under rheo, "no document title set" is the uncommon case. Rheo wraps every
page in its own `document(..)` and, for a page whose own content never calls
`#set document(title: ..)`, supplies a title derived from the page's path
instead of leaving it `none`. So a rheo site gets a stable, path-derived name
for every page's note without writing `#set document(..)` anywhere — the
titleless/body-derived fallback above is reached only by a page that somehow
has no title at all, not by the ordinary case of a page that simply never
set one.

In heading mode, the matching heading **starts** the group that follows it
rather than being discarded — the opposite of par mode's rule. `== rookery`
plus the bullets under it is one note, with the heading as its first line, not
the last line of whatever preceded it. Content before the first matching
heading is still a note of its own, an ordinary preamble. A heading of a
different level (`===` while `separator:` asked for level 2) is not a
separator and stays put, and `parbreak` itself is ordinary content in heading
mode too — a section with three paragraphs in it is still exactly one note.

Anything else passed as `separator:` — `heading` with no level, `pagebreak`,
`line`, `raw`, `heading.with(level: 2)`, `heading(level: 2)[]` — fails
`#ideate`'s own check with a panic naming the accepted forms.

### Titling and naming notes from their own heading

In heading mode, `title:` and `name:` each accept a function that reads each
section's separating heading and computes that note's own title or name:

```typst
#show: ideate.with(separator: heading.where(level: 2), title: (content, labels) => content, name: (content, labels) => slug(content))
```

`== Literate programming` then mints a note whose `title:` is
`[Literate programming]` — the heading's own content, references and all — and
whose name is `idea:literate-programming`, a slug of the heading's text
(lowercased, non-alphanumeric runs collapsed to one `-`). **The heading itself
leaves the note's body**: `#idea` already renders `title` as the note's own
heading, so leaving the source heading in place too would print it twice.

A `#ref` inside the heading contributes nothing to the SLUG — only the title
keeps it, as real content, resolved by whatever `show ref:` rule the document
installs. A heading worth naming a note after is worth writing in plain
words; a heading built entirely from a reference has nothing else to slug on
and fails `_slug`'s own empty-name check.

| | `none`/`auto` (default) | fixed value | function |
| --- | --- | --- | --- |
| `title:` | no title (today's behaviour) | the same content on every note | a function `(content, labels) => content` — each note's own computed title |
| `name:` | the unnamed-`#idea` fallback (today's behaviour) | — not accepted; see below | `(content, labels) => string` — a custom name computed per section |
| `tags:` | no tags | the same tags on every note | `(content, labels) => tags` — each note's own computed tags |

A name minted from a heading is a stable, chosen string rather than a
body-derived one — which is the reason to prefer a `name:` function for
anything worth linking to.

All heading-reading forms are **heading mode only**: with `separator: par` or
`separator: none` there is no heading to read, and any of them there fails with
a panic. A fixed `name:` is refused too, for a different reason — it would mint
every note in the body under one name — so `name:` accepts only `auto`, `heading`,
or a function. `title:` keeps accepting a fixed value, exactly as it always has:
every note minted gets that same title, sentinel or not.

Two sections in one `#ideate` call whose headings slug to the same name fail
with a panic naming both, rather than silently minting one over the other. A
second `#ideate` call, or another chapter elsewhere in the document, is not
covered by this check — see "Flat names, and why" below for cross-document name
collisions in general.

### Tagging a section with `#ideate-tag`

Tag a section by placing an `#ideate-tag(tags)` metadata beacon anywhere in that
section's own content. The beacon accepts the same four tag forms as `#idea`'s own
`tags:` — `none`, a string, an array of strings, or a dictionary (for valued tags):

```typst
#show: ideate.with(separator: heading.where(level: 2), tags: "weeknotes")

== Rookery

#ideate-tag("rookery")

Minted tagged both `weeknotes` and `rookery` — every other section here still
gets only `weeknotes`.
```

Place the beacon inline within a paragraph (so it belongs to that section's own
flat sequence, not nested inside a list item or `#strong[..]`). Under `separator:
par`, place it inline with the text it tags; under `separator: heading` or
`separator: none`, it can sit anywhere in the section's body. The beacon renders
nothing — it is pure apparatus, like the heading itself.

Multiple beacons in one section are allowed. Values are unioned document-order,
right-biased on key conflict (a later beacon's value for a key wins). `#ideate-tag`
works under ALL separator modes, not only heading mode — unlike the old
`<tag:x>` label approach, which worked only when a section had a separating
heading to label.

Valued tags (dictionaries) and multiple tags per section are now possible — no
ceiling on cardinality or value syntax.

### Tagging every section from its heading with a `tags:` function

`tags:` also accepts a **function** of `(content, labels)` — the same pair
`title:` and `name:` take — called once per section on the heading that starts
it. Where a plain `tags:` value puts the same tags on every note, a function
computes each section's own:

```typst
#import "@rookery/core:0.1.0": ideate, slug

#show: ideate.with(
  separator: heading.where(level: 2),
  tags: (content, labels) => (slug(content),),
)

== LIMINAL              // minted tagged `liminal`
== Digital Theory Lab   // minted tagged `digital-theory-lab`
```

The function returns any of the four tag forms — a string, an array, a
dictionary for valued tags, or `none` for no tag at all — and its result is
normalized exactly as a literal `tags:` would be.

The point is that ONE function can feed `title:`, `name:` and `tags:` at once, so
a note's name cannot drift from its tag, and a section titled something new needs
nothing declared anywhere to carry a tag of its own:

```typst
#let section(content, labels) = slug(content)

#show: ideate.with(
  separator: heading.where(level: 2),
  title: (content, labels) => content,
  name: (content, labels) => "26w37-" + section(content, labels),
  tags: section,
)
```

Three things follow from it reading the separating heading:

- It needs **heading mode**, like `title:` and `name:`, and panics under
  `separator: par`/`none` naming all three. A body split by paragraph tags every
  note the same, which a plain `tags:` value already says.
- The **preamble group** (content before the first separating heading) has no
  heading to pass, so the function is not called for it and it carries no tags —
  the same way a `name:` lambda leaves the preamble on the body-derived
  fallback.
- **`#ideate-tag` still wins.** Beacons are unioned after the function's result,
  so a section that computes `report` from its heading and also carries
  `#ideate-tag((report: "final"))` gets the valued one. The function is the rule;
  the beacon is the exception.

### Naming sections with a custom function

`name:` accepts a function that computes each section's name from its heading and
labels, substituting for the body-derived fallback.
The function receives two arguments:

- **`content`**: the separating heading's own body as raw Typst content — the
  same value a `title:` function receives. The caller decides how to
  project it: lowercasing and stripping punctuation (via `slug()`, exported from
  this package), keeping structure, or using it to index a table are all valid.
- **`labels`**: the heading's own Typst labels as an ARRAY. `()` for a bare
  heading, `(<tag:waterline>,)` for a single labelled one. A Typst element
  carries at most one label today, so the array is never longer than 1; it is an
  array so the signature does not change if that ever stops being true, and so
  a lambda never has to guard against two types.

The function must return the note's name as a **non-empty string**. Everything a
caller does with the heading content is their own business — whether it includes
a `#ref`, how it handles markup, and how it writes the result back are all
decisions a caller makes, and the function calls the shots.

```typst
#import "@rookery/core:0.1.0": ideate, slug

#show: ideate.with(
  separator: heading.where(level: 2),
  title: (content, labels) => content,
  name: (content, labels) => "26w37-" + slug(content),
)

== Waterline <tag:waterline>

Minted as `idea:26w37-waterline`.
```

The preamble group (content before the first separating heading) has no heading
to pass to the lambda and still mints under the body-derived fallback
described in "Unnamed notes: where their names come from". A lambda names the
sections; the preamble is unaffected.

**A `#ref` inside the heading contributes nothing to the lambda's input** —
`content` is the heading's raw body, and what the lambda sees of a reference is
its marker element, with no registry to resolve it against. A caller who wants
to resolve one themselves (e.g., to slugify a reference's target name instead of
its marker) can do so, but doing so inside a function that is itself about to
add to the registry carries a measurable risk: the registry's value can then
depend on this very node's own output, breaking `ideate`'s convergence. Do not
attempt it unless you have a very specific reason.

`slug()` is exported from this package and accepts either content or a string,
returning a URL-safe slug (lowercased, non-alphanumeric runs collapsed to one
hyphen, leading and trailing hyphens removed). It is the projection `ideate`
uses for its own names, and a convenient default for any lambda that wants to slug
the heading text:

```typst
name: (content, labels) => slug(content)
```

is the one-line function for naming every section after its own heading.

Two sections that call the lambda and produce the same name fail with a panic
naming both. A second `#ideate` call, or another
chapter elsewhere in the document, is not covered by this check — see "Flat
names, and why" below for cross-document name collisions in general.

### Its inverted defaults

`ideate(body, separator: none, title: none, name: auto, tags: (), display: (:), display-frame: false, display-name: false, ..args)`.

`separator: none` mints the WHOLE body as one note — the common case is a
document-level `#show: ideate` on a page that is one idea, and a caller
wanting one note per paragraph asks for it explicitly with
`separator: par`.

`display-frame` and `display-name` both invert `#idea`'s own defaults, and that
inversion is most of the reason the function is worth having: an inferred note
is not one anybody named, so a frame and a permalink around every paragraph is
chrome nobody asked for — and with no name, that permalink points at a sequence
number which means nothing to a reader. Pass `true` to either to get it back.
See "Dropping a note's frame" above for what each one governs.

`..args` forwards every other `#idea` argument to every note minted. `tags:` is
its own parameter rather than riding that sink — see "Tagging one section from
its own heading" below for why — but it is written exactly the same way, and
tags a whole block at once:

```typst
#ideate(tags: "slip")[..]     // every paragraph becomes a note tagged `slip`
```

**Every note minted this way has an AUTO-GENERATED name**, and with `display-name: false`
no visible permalink, so none of them is addressable by name. That is fine for a
block a tag query will pick up and wrong for anything anyone needs to link to; a
note that must be linkable is written by hand as `#idea("name")[..]`.

### A PDF is just the prose

On a paged target `#ideate` is a passthrough: it returns the markup it was given,
mints no note, wraps nothing, and registers nothing — `#ideas()` in that build
sees none of it. A PDF of a block of prose should be that block of prose. EPUB
takes the HTML path, since it is a rendering target with a stylesheet rather than
a page.

## Flat names, and why

`#idea("etal")` is the Typst label `<idea:etal>` everywhere — no handle or
filename prefix. That means a note KEEPS ITS NAME WHEN IT MOVES BETWEEN FILES:
nothing about `<idea:etal>` depends on which file it's written in. Names are
therefore globally unique by design; giving two notes the same name is a build
error naming it, as soon as anything (`#window`, `#hyperlink`) looks that
name up.

## Unnamed notes: where their names come from

An unnamed `#idea` mints its name from a ladder, tried top to bottom, stopping
at the first rung that yields a value — never from a running count of notes
seen so far, and never from where the note sits in the document:

```typst
#idea(title: [My Title])[..]                     // titled: mints idea:my-title
#idea[Loose reading notes on separation logic.]  // untitled: mints idea:loose-reading-445
```

The rungs:

1. **A pinned name wins outright**, over everything below:
   `#idea(<etal>, ..)` always mints `idea:etal`.
2. **A slug of the title**, if the note has one: lowercased, every run of
   non-alphanumeric characters collapsed to a single `-`, trimmed, and capped
   at 60 characters. A title that slugs to nothing (pure punctuation) or to
   digits only falls through to the next rung instead.
3. **A slug of the note's own body**, if it has no usable title: its opening
   words, lowercased and hyphenated, capped at 16 characters — never cut
   mid-word — plus a hyphen and a three-character digest of the note's own
   content (its title, body, tags, level, and display flags), so two notes
   that open the same way still land on different names.
4. **Nothing derivable** — no pinned name, no title, and a body with no
   readable text — fails the build asking for one.

A body that **begins with a URL** slugs from the URL's last path segment, not
its host — a reading list of bare links is a common shape, and a URL's
distinguishing part is at its end:

```typst
#idea[https://anil.recoil.org/papers/2024-hope-bastion]
```

mints `idea:2024-hope-kg9` — the tail `2024-hope-bastion`, capped at 16
characters at a whole word (`2024-hope`, not `2024-hope-bastion`; the slug
never cuts mid-word), plus its digest. Rung 3 names come out shorter than
the 16-character cap suggests whenever a word boundary falls short of it.

**Editing a titleless note's body changes its name.** Rung 3 is a pure
function of the note's own content, so a body that reads differently the
next time the project builds mints a different name. Pin a name
(`#idea(<some-name>, ..)`) on any note whose name must never move.

- A second note whose title slugs to a name already taken gets a numeric
  suffix instead of failing the build: the first note titled "My Title"
  mints `idea:my-title`, the second `idea:my-title-2`, the third
  `idea:my-title-3`, counted in the ORDER the notes appear in the document.
  Inserting a new "My Title" note before an existing `-2` shifts it to
  `-3` — the suffix counts occurrences, not a fixed identity, so it moves
  when a colliding note is added or removed earlier in the document. Pin a
  name (`#idea(<some-name>, title: [..])`) on any note whose name must never
  move regardless of what gets titled the same later. Rung 3 carries no such
  suffix: two notes identical in title, body, tags, level and display merge
  into one note instead of colliding, and two that differ in any of those
  already land on different names without needing one.
- A pinned name landing on a derived name some other note already reached, or
  two notes pinned to the same name, still fails the build outright rather
  than being disambiguated — a pin is a promise about the name, so retitling,
  renaming, or pinning explicitly is the only fix.

A derived name does not depend on document order or on where the note
sits in the tree: reordering the sections around it, or moving it, leaves
it untouched, because both the title slug and the body slug are computed
purely from the note's own title and body — never from a count of notes seen
so far and never from the note's authored position. The one exception is the
`-<n>` suffix above — that number counts how many earlier-registering notes
already claimed the same title slug, so it does shift when a colliding note
is inserted or removed ahead of it, even though the notes on either side of
it keep their own names. The same note also keeps its name when it is shown
again inside a `#window` or on a minted page, since both the title slug and
the body slug are pure functions of the note's own title, body, tags, level
and display — the same values every time, regardless of where a re-render
places it. `#ideate`'s heading-derived names follow the same rules above, but
not this suffix — it mints only through `#idea`.

**This changes existing URLs, again.** An untitled note that minted at
`ideas/<container>-1.html` under the retired container-ordinal scheme now
mints at `ideas/<body-slug>-<digest>.html` instead. An in-repo reference to
the old name fails to compile — loud, and caught at build time — but an
external link or a bookmark to the old page breaks silently. Pin a name
(`#idea(<some-name>, ..)[..]`) on a note if some old name needs to keep
resolving.

## Two modes

**Pure Typst, no rheo.** One root file `#include`s your note files; `#window`
and cross-references work because everything compiles as one document.
`--features html` is required for every build, even a plain PDF — see below.
HTML output needs `src/core.css` included manually (rheo does this for you
automatically, see below).

```typst
// root.typ
#include "notes.typ"
#include "more-notes.typ"
```

```sh
typst compile --features html root.typ root.pdf
typst compile --features html --format html root.typ root.html
```

**Under rheo.** Nothing extra to write — no `ctx:` parameter, and the `#show:
rookery` template is optional even here. Just `#import` and call
`#idea`/`#window` like any other
package. rheo adds exactly two things on top of the pure-Typst behaviour:
correct cross-PAGE hrefs (rheo puts each vertebra in its own output page,
which a plain Typst compile doesn't), and the stylesheet auto-injected via
this package's `[tool.rheo.html]` — no manual `<link>` needed.

`demo/pure/` in this repo is the pure-Typst side: no template at all, default
prefix, `show ref: hyperlink` wired up by hand. The rheo side lives in the sibling repo
**`rookery.ohrg.org`** — this package's documentation site, written with the
package it documents. It is the worked multi-vertebra example, including a
nested vertebra to exercise cross-page hrefs, a custom prefix and theme, and
`#show: rookery` applied once in a site template rather than repeated per
page.

## Referencing a note

Three ways, pick by how much ceremony you want:

- `#link(label("idea:etal"))[jump to it]` — a plain jump, works everywhere,
  always correct (in-page or cross-page).
- `#window("etal")` — transcludes the note: its title, its `[idea:etal]`
  permalink and its body, as one foldable block. Accepts a single name, a
  label, or an array of names (`#window(("etal", "second"))` renders both in
  order, each its own block). `limit: n` truncates the body to the first `n`
  content-level blocks (paragraphs, grouped list items, ...) plus an
  ellipsis, in every target. In HTML and EPUB the shown blocks are themselves
  the control: the preview and its ellipsis are a disclosure of their own,
  and opening it unfurls the rest of the note in place. `n` must be `none` or
  a positive integer: `limit: 0` would show an ellipsis and nothing else,
  which reads as a mistake rather than a request, so it is rejected along
  with negatives and non-integers.

  A limit cannot land mid-paragraph: one paragraph is one block however many
  inline runs it is made of, so a plain text run and the `raw` span beside it
  are never separated, and the space between them survives — so "three
  layers, `because`" keeps its space rather than losing it to a truncation
  cut.
  A block-level element (a heading, a table, a block quote) is still a block of
  its own, and the whitespace around it is still dropped, because that gap is
  drawn by margins rather than content.

  In HTML and EPUB, this second disclosure nests inside the window's own:
  clicking anywhere in the shown blocks, or on the ellipsis, unfurls the tail
  below them, and the ellipsis disappears once it has. While only the preview
  shows, the window keeps the fold tint (`--idea-fold-color`) it wears when
  closed, and loses it once the tail unfurls — `display-background: false`
  opts out of both, as it already does for the outer fold. The two
  disclosures stay independent of each other: a folded window's title row
  opens first to reveal the preview, and the preview then opens on its own to
  reveal the rest, so `folded:` and `limit:` remain exactly as orthogonal as
  before. A footnote written inside the shown portion is caught by the split:
  it renders once, bare, in the collapsed preview — picked up there by
  whatever footnote handling encloses the window, not the window's own —
  and once more, correctly numbered, in the window's own list once the body
  unfurls; that duplicate is the cost of numbering the whole note once,
  consistently, rather than splitting the count at a boundary that is no
  longer permanent. Under a paged target there is nothing to click, so the
  tail stays discarded and the ellipsis is the end of it, exactly as
  `limit:` has always behaved there.

  `folded: true` starts the block CLOSED. That is all it does: a folded window
  and an open one are the same block, so `limit:` stays meaningful under
  either and the two are orthogonal. Under a paged target, where there is
  nothing to click, `folded` is ignored and the body always shows.

  `display-date: true` shows the note's `created` date at the right-hand end of the
  hat, opposite the permalink — off by default. See "Dates" below.

  `display-tags: true` shows the note's tags as a row of pills in the hat, between
  the permalink and the date — off by default, same mechanism as `display-date`.
  See "Tags" below.

  `display-frame: false` drops the window's left rule and indent, the same switch
  `#idea` takes for a card, and leaves the summary, the disclosure and the body
  exactly as they were. `display-name: false` drops the permalink from the summary,
  the same switch again. See "Dropping a note's frame" above for both.

  `display-label: false` names this window only if its note carries an AUTHORED
  title, instead of falling back to the label derived from the note's first
  line — see "`display-label:` — an authored title, or nothing" above. It is a
  `#window` argument only: a card already prints the authored title alone.

  `backlink: false` renders the note without COUNTING as a link to it, so this
  window contributes nothing to the note's Backlinks — see "`backlink:` — a view
  is not a reference" above.

  The window's own wrapper wears the note's visible tags too, unconditionally
  — the same `.idea-tag-<key>` classes and the same `data-rookery-tags`
  attribute its card carries, whether or not `display-tags:` is set. A note
  transcluded by a `#window` is the note shown in place, so it styles the same
  way there as it does on its own page; an invisible tag (see "Tags" below)
  leaves no trace here either.

  `unfurl: 0` renders this window as a LINK to the note's page and transcludes
  nothing; `unfurl: 1` renders the note and collapses any `#window` written
  inside it; `unfurl: n` unfurls `n-1` levels of those. `auto` (the default)
  takes the document-wide `window-unfurl`, itself `1`. See "Nested windows, and
  `window-unfurl`" above.

  `tagged: ("phd",)` selects notes instead of naming them — and ADDS to the
  names rather than replacing them. `#window(<intro>, tagged: "phd")` shows
  Intro, then everything tagged `phd`; a note that is both named and tagged
  appears once, where you named it. At least one of a name, `tagged:` or
  `filter:` is required. `match:` is `"any"` (the default) or `"all"`, so
  `tagged: ("phd", "draft"), match: "all"` wants notes carrying both.

  `filter:` is a predicate of your own over the note's TAG DICTIONARY,
  returning a boolean, ANDed with `tagged:`/`match:` when both are given — both
  must hold, never either. It is what expresses a selection `tagged:`/`match:`
  cannot: exclusion, or an OR of ANDs. `t => "phd" in t` tests dictionary
  KEYS; `t.map(..)`, `t.any(..)`, `t.all(..)` and `t.at(0)` are not available
  on it — a dictionary has no `.any`/`.all` at all, and its `.at` takes a key,
  not an index.

  ```typst
  #window(filter: t => "phd" in t and "draft" not in t)
  ```

  Tag and filter selection are always rookery-wide: they read the whole
  registry, so they pull the same notes wherever the window sits. That is the
  point — an index written once keeps up as you add notes, instead of going
  quietly out of date the way a hand-listed set of names does.

  Whether the window counts as a link at all follows the same rule for
  `tagged:` as it does for a named note, and `filter:` breaks it — see
  "`backlink:` — a view is not a reference" above.

  `sort:` is `auto`, `"date"` or `"lexicographic"`. `auto` keeps the notes you
  named in the order you named them and appends the tag matches by name, so a
  window that names its notes reads exactly as it always has; naming a sort
  orders the whole selection instead. `"date"` is newest first on the minted
  date, undated notes last.

  One asymmetry to know about: a note you NAMED gets a backlink from the
  window, and a note the tags pulled in does not. A window announces what it
  points at before the registry can be read, and a tag match is not known that
  early — so the backlink simply cannot be recorded. Name a note explicitly if
  you want the link to travel back to it.

  See "The click budget" below for what clicking each part does.
- `@idea:etal` — the terse form, but on its own it renders as a bare figure
  NUMBER (Typst's stock `@` rendering for a labeled figure — a note's name
  lives on a hidden anchor figure). `#show: rookery` installs the rule that
  fixes this, so if you already applied the template there is nothing to do.
  Without it, apply the exported `hyperlink` by hand:

  ```typst
  #import "@rookery/core:0.1.0": idea, window, hyperlink
  #show ref: hyperlink
  ```

  With the rule applied, `@idea:etal` renders the note's title (linked)
  instead, cross-page too; a note with no title falls back to the bare name
  text rather than a number. References to anything else (an ordinary
  figure, a heading) pass through untouched — checking whether the reference
  actually resolves to a rookery note anchor is what lets `show ref:` be
  installed document-wide with no narrower selector, rather than something
  scoped only to `idea:` refs.

  **Custom text:** `@idea:etal[custom text]` (Typst's own ref-supplement
  syntax) overrides the title:

  ```typst
  @idea:etal[click here]
  ```

  **Where it links:** the rule goes to the note's own minted page — same as
  the permalink, falling back to the in-context anchor where no page is
  minted (plain `typst compile`, or the combined PDF). Pass
  `hyperlink-target-minted: false` to make `@idea:etal` link to the in-context
  anchor unconditionally, like `#link(label("idea:etal"))` does:

  ```typst
  #import "@rookery/core:0.1.0": idea, window, hyperlink
  #show ref: hyperlink.with(hyperlink-target-minted: false)
  ```

  It is the same parameter an explicit call takes —
  `#hyperlink("etal", hyperlink-target-minted: false)[see this]` — and
  `#show: rookery.with(hyperlink-target-minted: false)` does the same thing
  document-wide when you're using the template rather than installing the rule
  yourself.

## Outlining notes

`#ideas-outline()` lists every note in the rookery as a nested tree.

```typst
#import "@rookery/core:0.1.0": ideas-outline
#ideas-outline()
#ideas-outline(title: none, depth: 2)
#ideas-outline(title: [Everything])
```

Typst's own `#outline()` cannot do this: it lists `heading` elements, and a
note only becomes one on the paged target — on HTML/EPUB its title is a raw
`html.elem("h…")` with no Typst heading behind it. So `#outline()` would find
every note in a PDF and none in the primary targets. This is built off the
same query-time machinery backlinks already use, and works identically
everywhere.

The same call also works spelled `#outline(target: idea, ..)` — Typst's own
idiom for an outline over something other than headings
(`#outline(target: figure.where(kind: image))` is the built-in example).
Importing `@rookery/core` shadows `outline` in that file's scope for exactly
this reason: `#outline(target: idea)` forwards every other argument straight
to `#ideas-outline`, and any OTHER target proxies straight to Typst's own
`#outline` unchanged — same arguments, same defaults, same behaviour.

```typst
#outline(target: idea, tagged: "draft")   // the ideas outline
#outline()                              // Typst's own, over headings
```

`title` and `depth` mirror `#outline()`'s so the two read as one family:
`title: auto` prints "Contents", `none` omits it, anything else replaces it;
`depth` caps how many levels show, counting from 1 like Typst's heading
levels.

**Nesting is real containment** — one `#idea` written inside another's body —
not the author-set `level:`, which is a heading-size knob most notes never
touch. So the tree is right with no ceremony, matching `#idea`'s own "hatch
without ceremony" design. A note with no title of its own is listed under its
DERIVED label (see "Derived labels"), so an auto-numbered note is listed like
any other — only a note with an empty body is skipped, since there is then
nothing to name it by at all.

**`scope`** names the breadth, and is `"rookery"` (the default) or `"page"`.
`"rookery"` lists every note in the rookery — one tree, nested by the same
real containment; the whole spine compiles as one Typst document, so this
costs nothing extra, being a filter lifted rather than a second pass, and
entries link straight across pages. `"page"` narrows to only the notes
written on this page. `depth` composes with either and still means
containment levels, not pages. The default used to be page-only; an
upgrading reader who wants that back writes `#ideas-outline(scope: "page")`.

Pages come in **spine order** — the order you configured, via the directory
scan and `[[spine.section]]`, not the order the files happen to be named in —
with **`index.typ` first** wherever it exists. rheo already puts a nested
directory's `index.typ` first, as that directory's landing page; at the root
it treats `index.typ` as an ordinary leaf, so a rookery whose front door sorts
into the middle of the alphabet would otherwise have its index of everything
start somewhere in the middle. Hoisting it makes both levels read the same
way: landing page first.

Neither applies to a single-document target — the combined PDF, or plain
`typst compile`. There the outline follows the document, because reordering it
against the page sequence a reader is holding would be a lie, and it is also
why the two forms agree there rather than disagreeing about an order only one
of them applied.

It is deliberately not grouped under per-page headings. A note's name is flat
and travels between files precisely so a reader never has to know which file
holds it (see "Flat names, and why"); an index that led with filenames would put
that back.

Notes transcluded onto the page by a `#window` are never listed, at any depth
of nesting — they are echoes of notes stored (and usually written) elsewhere,
not this page's structure.

Where the output is a single document — the combined PDF, or plain `typst
compile` with no rheo — the two forms agree and both list everything. That is
the same set: there is only one page.

**`tagged:` and `match:`** are the same pair `#window` and `#ideas()` take,
through the same shared predicate: `tagged:` is `none`, a string or an array of
strings, `match:` is `"any"` (the default) or `"all"`. An empty array
(`tagged: ()`) is no filter at all rather than a filter matching nothing — asking
for none of the tags is not the same as asking for a tag no note has.

```typst
#ideas-outline(tagged: "todo")
#ideas-outline(tagged: ("todo", "phd"))               // ANY of them
#ideas-outline(tagged: ("todo", "phd"), match: "all") // ALL of them
#ideas-outline(title: [Open], filter: t => "todo" in t and "done" not in t)
```

**`filter:`** is a predicate of your own over the note's TAG DICTIONARY,
returning a boolean, ANDed with `tagged:`/`match:` when both are given — both must
hold, never either. It exists because `tagged:`/`match:` can say "any of these"
and "all of these" and nothing else: they cannot say `phd` but NOT `draft`, nor
`(phd AND draft) OR todo`. Keyword parameters for those would be a filter
language grown one special case at a time (`exclude:`, then `any-of:`, then
nested groups), and a Typst function value already is that language. It sees the
tag dictionary and nothing else — no title, no name, no depth.

Because it is the dictionary, a filter can select on a tag's VALUE and not
merely on its presence:

```typst
#ideas-outline(title: [Urgent], filter: t => t.at("priority", default: 9) <= 1)
```

`t => "phd" in t` works, because `in` tests keys. An array method does not:
`t.map(..)`, `t.any(..)`, `t.all(..)` and `t.at(0)` are unavailable, because a
dictionary has no `.any`/`.all` and its `.at` takes a key.

**A filter prunes AND PROMOTES.** A matching note whose parent does NOT match is
re-based to its nearest KEPT ancestor's level, so the tree never shows a hole
where an excluded parent was. MEASURED on `Top` (tagged `phd`) > `Mid`
(untagged) > `Deep` (tagged `phd`): `#ideas-outline(tagged: "phd")` renders `Top`
with `Deep` nested directly under it, one level shallower than the unfiltered
outline puts it. Keeping unmatched ancestors as unlinked scaffolding was
rejected — it would put notes in the index the filter said to exclude.

**`depth:` counts levels in the FILTERED tree**, because pruning happens BEFORE
the depth cap. MEASURED on the same three notes,
`#ideas-outline(tagged: "phd", depth: 1)` renders `Top` alone: `depth: 1` means
"the top level of what I asked for", not "whatever survived from the top level
of everything".

**A filtered outline that matches nothing renders NOTHING AT ALL, heading
included.** An unfiltered empty outline still prints its heading — that case is
unchanged, and the two differ on purpose. An empty unfiltered outline is an
answer ("here are this page's notes", there are none, the heading is the
sentence); an empty filtered one is a promise the filter already ruled out, and
a `#ideas-outline(title: [Todos], tagged: "todo")` carried on every section would
otherwise render a "Todos" heading over emptiness on every section without one.
`depth:` deliberately does not count as a filter here: it drops levels below the
first, so it cannot empty an outline that had anything in it at all.

## The corpus, as data

`#ideas()` hands you the whole rookery as a plain array of dictionaries. It is
the seam this package deliberately leaves open: everything above renders notes
the way rookery thinks they should be rendered, and this is where you take the
same material and do something else with it.

```typst
#import "@rookery/core:0.1.0": ideas, idea-href
#context {
  for e in ideas() {
    [#e.name — #e.text \ ]
    // e.body is a plain string too: [#e.body.slice(0, 80)] previews a note's
    // opening without rendering it.
  }
}
```

**It has to be called inside `#context`.** The registry is a Typst state, and
reading it whole means reading it at the end of the document, which is only
legal in a context block. `#ideas()` is not itself a context function, because
a context function can only return content — and the entire point is that this
one returns data you can sort, filter and count.

Each entry is:

- `id` — the note's full name, prefix included (`"idea:etal"`). The field
  is still called `id`; what it holds is the name in its prefixed form.
- `name` — the same name with the prefix stripped (`"etal"`), the form you write
  in `#window("etal")`.
- `title` — the title as content, or `none` for an untitled note.
- `text` — that title flattened to a plain string, `""` when there is none.
  Useful for matching, sorting and anything else that wants a string rather
  than something to render.
- `tags` — the note's tag NAMES as an array of strings, `()` when it has none.
  Every key, valued tags included; order is unspecified. `#idea-tag-names()` below asks
  the same question about one note; this is the bulk form, and the cheaper one
  when you are walking the whole rookery.
  The VALUES are deliberately NOT on this row, and that is load-bearing rather
  than tidiness: `@rookery/search` serializes these rows into a JSON index,
  and a value can be a `datetime` or content. Reach for `#tag-data()` when you
  want them.
- `body` — the note's body flattened to a plain string, `""` when there is
  none. Block boundaries (a paragraph break, a list item) collapse to a
  single space rather than gluing adjacent words together; a nested `#idea`'s
  own text is excluded (it registers separately and owns its text); a
  `#footnote`'s body is excluded too. A plain string, not the content:
  matchable and excerptable, but not renderable — that is the whole reason it
  exists where the content body still does not: `@rookery/search` ranks
  and previews full text against it, and a string can be matched and
  excerpted without turning every consumer into a second transclusion engine
  the way handing out the content itself would.
- `href` — a depth-relative link to the note's minted page, from wherever you
  are calling. See `#idea-href()` below.
- `page` — the same minted page, as a site-root-relative path instead — the
  same string `#idea-path()` returns, for a consumer with no page of its own
  to measure depth from (a feed, a sitemap). See `#idea-path()` below.
- `created` — the note's date, or `none`. There is no `updated` beside it —
  see "Dates".

`#ideas()` also takes `tagged:` and `match:` — the same pair `#window` takes, with
the same meanings and the same shared predicate behind them. `tagged:` is a single
string or an array; `match: "all"` demands every one of them where the default
`"any"` takes a note carrying at least one:

```typst
#context ideas(tagged: "phd")                            // tagged phd
#context ideas(tagged: ("phd", "draft"), match: "all")   // tagged both
```

An empty array (`tagged: ()`) is no filter rather than a filter matching nothing —
asking for none of the tags is not asking for a tag no note has. You could write
the `"any"` case yourself as `ideas().filter(e => "phd" in e.tags)`; the
parameter exists because it filters BEFORE each surviving row is built, and
because `#search-bar` builds its index internally where your `.filter` cannot
reach.

`filter:` is the same predicate `#window` takes — a function of your own over
the note's TAG DICTIONARY, ANDed with `tagged:`/`match:` when both are given.
See `#window`'s `filter:` above for the full explanation, including why the
predicate takes the dictionary rather than an array of names.

```typst
#context ideas(filter: t => "phd" in t and "draft" not in t)
```

`sort:` is `auto`, `"date"` or `"lexicographic"`. `auto` and `"lexicographic"`
both mean the array is ordered by name, not by the order notes were written or
the order their pages appear — a name order is the one order that is stable
across builds, and it makes a diff of generated output mean something.
`"date"` orders newest `created` first, undated notes last, same as
`#window(sort: "date")`.

A note's body AS CONTENT, its `raw` source and its backlinks are deliberately
absent from THIS array — only the plain-string form above is exposed here.
Handing out every note's content in bulk would turn every consumer into a
second transclusion engine — one that does not agree with `#window` about
folding, unfurl budget or dates. If you want a note rendered, render it with
`#window`, or — for the body alone, no chrome — with `#idea-body`, next.

### Three tiers of tag data

A row carries tag NAMES and no values, for the measured reason above. That is the
free tier and the default. Two more are available, and the narrow one is the
default so nobody pays for what they did not ask for:

| call | the row carries | cost |
|---|---|---|
| `ideas()` | tag names only | free |
| `ideas(index: SPEC)` | declared fields, asserted scalar | one walk, only what is named |
| `ideas(values: true)` | the whole tag dictionary, as `tags-dict` | the full value store |

The third is not new capability — it is exactly what `#tag-data()` returns. What
changes is that it arrives ATTACHED TO THE ROW instead of needing a keyed lookup
per row, and it is paid for only when asked:

```typst
#context for r in ideas(tagged: "submission", values: true) {
  // arbitrary values: a datetime to format, a path to render as `raw`, the full
  // key list to emit one CSS class per tag
  [#r.label — #r.tags-dict.at("date-deadline").display("[year]") \ ]
}
```

It composes with `tagged:`, which is what keeps it from being a cliff: the filter
narrows FIRST and values are attached only to the survivors, so the cost is
proportional to what you asked for rather than to the corpus.

`tags-dict` is a SEPARATE field and never a widening of `tags`, which stays a flat
array of names. That is not tidiness either: `@rookery/search` puts `row.tags`
straight into a JSON index and maps over it, so replacing the array with a
dictionary in place would reintroduce the content-blob failure the names-only rule
exists to prevent. And it is ABSENT rather than empty when you did not ask for it,
so you cannot read an empty dictionary off a row and conclude the note is
untagged.

### Projecting tag values: `#tag-index`

The middle tier. A projection DECLARES its fields up front and flattens each to a
SCALAR, which is what makes it safe to put values back on a row at all — the ban
exists because a value is *arbitrary*, and a projection makes them narrow and
checked:

```typst
#import "@rookery/core:0.1.0": ideas, tag-index

#let INDEX = tag-index((
  cycle:    (family: "cycle-"),                     // flat-tag family -> "26-27"
  kind:     (family: "venue-", one-of: KINDS),      // -> "postdoc"
  deadline: (key: "date-deadline", stamp: true),    // -> "20261101"
  stage:    (from: stage-of),                       // derived: a function of the tags
))

#context ideas(index: INDEX)   // rows carry .cycle .kind .deadline .stage
```

Three extractor forms, and no more:

- `(key: "<tag key>")` — that tag's value, or `none`.
- `(family: "<prefix>")` — the first flat tag whose key starts with the prefix,
  with the prefix stripped. `one-of: (..)` both restricts AND orders the
  candidates, so a note carrying two members of a family resolves to the earliest
  LISTED rather than to whichever key order happens to yield first. Tags are
  unordered, so without `one-of:` a two-member note is not deterministic.
- `(from: <function>)` — called with the note's whole tag dictionary, returns the
  scalar. This form is not a convenience. A derived value — "the current stage of
  a dated log", "how far this got" — is a COMPUTATION rather than a tag value, and
  the structure it reads can never ride on a row under the names-only rule. It is
  the only way such a value becomes filterable or sortable at all.

Any form may carry `stamp: true`, which turns a `datetime` into a zero-padded
`[year][month][day]` STRING. Two reasons, and the second is the useful one: a
`datetime` is not a scalar the assert accepts, and a fixed-width numeric string
sorts lexically in date order — so a projected date is a free sort key.

NOT `as:`. MEASURED on typst 0.15.1: `as` is a reserved keyword and
`(key: "x", as: "date")` fails to parse with "expected named or keyed pair, found
string", so the flag cannot wear the name that reads best.

**The scalar assert is the contract**, not a nicety, and it names the field that
broke it:

```
tag-index field `stage` produced content; a projected value must be a scalar
(str, int, float, bool, none) so it is safe to encode as JSON or as an HTML
attribute. A datetime wants `stamp: true`; content and arrays want a `from:`
that reduces them.
```

A field name colliding with a row field (`href`, `label`, `created`, …) is refused
too, rather than silently shadowing it and breaking every link on the page; so is
a spec naming two extractors at once.

**Build ONE index per page and pass it around.** Nothing here caches, because a
self-caching accessor would put back the very cost this exists to remove: a
project with four views on one page was opening each with its own `#tag-data()`
walk to read a handful of fields.

`@rookery/timeline` ships readers over its own tag dictionary — `stage-of`,
`stage-date`, `rung` — and a spec names one in a `from:`, so a package's key is
named once, in that package, rather than hardcoded here.

### `#idea-body` — one note's body, rendered

`#window`'s content, without the summary and the disclosure — for a consumer
that wants to SHOW a note's actual prose (links, styling, footnotes,
citations) rather than describe it in a string, one note at a time:

```typst
#import "@rookery/core:0.1.0": idea-body
#context idea-body("etal")                // the whole body
#context idea-body("etal", limit: 3)       // the first three blocks
```

`limit:` truncates by block, the same unit and the same "…" `#window`'s own
`limit:` uses — so a paragraph is one block here too, a limit cannot land inside
a sentence, and the same `none`-or-positive-integer rule applies. Unlike
`#window`, this truncation is never expandable: `#idea-body` renders a body
with no chrome — no summary, no disclosure — so there is nothing to hang the
tail on, and the dropped blocks stay dropped in every target.
`unfurl:` is the same transclusion budget `#window` takes, but is pinned to `1`
here rather than left at `auto` — a caller asking for one note's body is
usually about to show a LOT of them (`@rookery/search`'s preview pane
calls this once per note in the whole rookery), and letting each one unfurl its
own nested windows by the document's `window-unfurl` setting could blow that up
unpredictably. So the body renders with any nested `#window` collapsed to its
permalink. Pass `unfurl:` explicitly if you want more. (`unfurl: 0` renders the
body all the same: `#idea-body` has no chrome, so it has no link to fall back
to the way a `#window` at `0` does.)

**Why not just call `#window`?** `#window` ANNOUNCES the note it shows, the
same marker `#ideas()`'s backlink data reads at registration time — a note
shown in a `#window` counts as a link TO it from wherever the window sits.
Right for a window an author writes into their own prose; wrong for a
function meant to run once per note on every page, which would otherwise
leave every page "linking" to every note in the rookery. `#idea-body` skips
the announcement — it only renders.

This is bulk-safe in the way handing out every note's CONTENT from `#ideas()`
is not: `#idea-body` still renders one note at a time, on request, the same
permission `#window` has always given an author explicitly.

`#idea-href(name)` gives you the same link `href` carries, for a note you name
yourself:

```typst
#context idea-href("etal")   // -> "../ideas/etal.html"
```

It takes whatever `#window` takes — a bare name, a prefixed name, or a label — and
the string it returns is **relative to the page it was called on**, because
that is what an href in the output has to be. Do not compute one on a page and
use it on another.

Both `href` and `#idea-href` are `none` where nothing mints pages: plain
`typst compile` with no rheo, and the combined PDF target. `ideas()` itself
still works there and still lists everything, because the corpus does not
depend on rheo — only on links to pages that only rheo produces.

`#idea-path(name)` gives you the same page, but from the SITE ROOT rather than
from wherever you're calling — the `page` field above, computed on demand:

```typst
#context idea-path("etal")   // -> "ideas/etal.html"
```

Use it where `#idea-href` is the wrong shape: a caller with no page of its
own — a feed config, a sitemap, anything invoked once from shared code rather
than from a vertebra — has no "current page" to measure depth from, so a
depth-relative string built at the wrong call site would simply be wrong.
`page` and `#idea-path` are `none` under the same two conditions
`href`/`#idea-href` are.

This is the supported way to build behaviour on top of a rookery, and it
exists so that you do not have to reach into the package's internals to do it.
An index page, a feed, a "recently minted" list, a graph of the rookery: all
of them are a `for` loop over `ideas()`.

**Search is one of them, and it lives in `@rookery/search`** — fuzzy and
full-text ranking, a JSON index, an embeddable search bar, and an overlay
search modal — written entirely against `#ideas()`, `#idea-href()` and
`#idea-body()`. It is a separate package on purpose. A search box is only
worth having with JavaScript, and this package ships none: no `package.json`,
no build step, `typst.toml` pointing straight at `src/`. Keeping search out
keeps that true. Install it alongside rookery if you want it; nothing here
depends on it, and nothing here changes if you never do.

**A feed is another.** `@rheo/feeds` builds Atom feeds from sources — plain
functions `cfg => (entries)` — and a rookery reaches it two ways.

The direct way, and the one to reach for first: write a source that calls
`ideas(tagged:)` itself and maps its rows onto feeds's entry shape. Because
`page` above (and `#idea-path()`) is site-root-relative rather than
depth-relative, this works from a feed config exactly as it would from a
vertebra — there is no "current page" for a feed to measure a link from, and
none is needed. `@rheo/feeds`'s own readme, "Sourcing from another
package", carries the worked recipe verbatim, run against this package's
`ideas()`; the two packages import nothing from each other, in either
direction.

The other way is `@rheo/feeds`'s own `<feeds:item>` beacon protocol, for a
source with no accessor like `ideas()` to call at all — a hand-authored page
syndicating itself, or a package that cannot import rookery's internals. For
rookery's own notes this stays secondary: every note is already reachable
through `ideas()`, so a rookery-sourced feed should reach for the direct way
above first. It exists as an opt-in, `#show: rookery.with(syndicate: true)`
(default `false` — a package must not emit into another package's label
namespace unasked). Turned on, each minted note page (`ideas/<slug>.html`)
also carries a `#metadata((..)) <feeds:item>` beacon, so `@rheo/feeds`'s
`items()` picks it up with no import in either direction — rookery never
imports `@rheo/feeds`, and the beacon is inert (`#metadata` renders no HTML)
when nothing reads it. A note with neither `minted` nor `updated` never gets
one: Atom requires `<updated>`, so an undated beacon would only be an entry
`items()`/`resolve-entries` drops on the floor.

`demo/rheo` turns it on and asserts it: the demo's own vertebra queries the
beacons back and renders their payloads, and `check.sh` pins the count, the
titles and the minted paths. That query is half the point — the beacons are
emitted inside the minted pages, so reading them from a vertebra is what shows
rheo's introspection carries them across the bundle, which is the premise the
whole protocol rests on. Nothing in that demo imports `@rheo/feeds`.


## The click budget

Interaction is modelled on [Forester](https://www.forester-notes.org), and the
whole of it fits in two rules:

- **The summary of a `#window` folds and unfolds. That is all it does.** Click
  the title, the date, the space between them — the block opens or closes and
  nothing navigates.
- **The `[idea:etal]` permalink is the only link the package emits**, and it
  goes to the note's own page. It sits beside the title, or alone at the top
  of the window when the note has no title (the name doing double duty as its
  title). `#idea` renders the identical affordance beside its own heading, and
  a `#window` nested inside a transcluded body collapses to it once the unfurl
  budget runs out — so the rule holds at every level. Where the budget does
  reach, the nested window is a full window, summary and all, identical to the
  same `#window` written at the top level: still one link, still the permalink.

The disclosure is a native `<details>`/`<summary>`; the package ships no JS.
An `<a>` inside a `<summary>` does not break the toggle — only an `<a>` around
the whole summary does, which is why the body of a window is never wrapped in
one. There is no trailing "→" either: it was a second navigational affordance
competing with the permalink for the same click.

[`foldable: false`](#foldable--a-slide-is-not-a-disclosure) spends the first of
those two rules rather than bending it: there is no disclosure, so the summary
does nothing at all and stops offering a pointer. The second rule is untouched —
the permalink is still the only link, and still the whole click budget.

`src/core.css` carries just enough to make this read correctly — the
permalink grey and light, the disclosure marker hidden (the summary is
clickable as a whole, so a triangle at one end would misdescribe it), and two
hover states, both Forester's: a faint `rgba(0, 100, 255, .04)` on the block
to signal that it folds, and the same accent at `.1` on the permalink, twice
as strong because that one is a link.

Every one of those colours is `var(--x, <default>)`, and "The theme" above is
how you set the `--x`. It arrives as an inline custom property on the elements
that root a rookery subtree — `.idea-box`, `.idea-window`, a minted page's `<h1>`
— and inherits down to the permalink and the date. The default lives inside
the `var()` call, so an unconfigured document, and any reader that doesn't
understand custom properties, still gets the look above. The package emits no
`<style>` element and wraps the document in nothing, so there is no `:root` to
hang a variable on; this is the mechanism that needs neither.

Setting those properties in your own stylesheet works identically — they are
the same four properties, listed at the top of `src/core.css`.

A note carries a light left rule, blockquote-fashion, so a new `#idea` is
visible as one without a box or a background. `#idea` wraps itself in a
`<figure>` — the marker the package uses to find notes again — and browsers
indent that 40px by default; the stylesheet halves that and moves it onto the
note, so the rule sits at the text margin with the body indented from it. That
needs `figure:has(> .idea-box)`, since Typst emits a bare `<figure>` with no
class to hook; where `:has()` is unsupported the note simply sits further in.

`#ideas-outline` wears the same rule from the same property, one more rule per
nesting level, so a page's table of contents reads as part of the same
apparatus as the notes it lists. Its bullets are hairlines in that colour
rather than discs — drawn as a `border-top` on a zero-height `::before` (1px
whatever the font, and supported far more widely than `content` in `::marker`),
sitting on the font's own x-height via `vertical-align: middle` rather than a
guessed offset. This is the one thing the package emits with no themed
ancestor to inherit from, being a sibling of the notes rather than a
descendant, so the properties go inline on the outermost `<ul>`. Paged targets
get Typst's plain nested `list()` instead: there is no `.idea-box` rule there
for an outline to be in line with.

Override any of it; the classes are the contract (all of them built on the
resolved `css-prefix`/`prefix` stem — see "Setup" above; assumed here to be
the default `idea`): `.idea`, `.idea-box`,
`.idea-title`, `.idea-tab`, `.idea-label`, `.idea-date`, `.idea-tag`, `.idea-tag-<tag>`, `.idea-ref`,
`.idea-window`, `.idea-window-summary`, `.idea-window-title`,
`.idea-window-body`, `.idea-window-details`, `.idea-outline`,
`.idea-outline-row`, `.idea-outline-title`, on an idea that carries footnotes `.idea-fn-ref`,
`.idea-footnotes`, `.idea-footnotes-title`, `.idea-footnote-list`,
`.idea-footnote`, `.idea-fn-backlink`, on one that cites
`.idea-references` and on any page with citations of its own
`.idea-page-refs`, and on a minted note page
`.idea-footer`, `.idea-footer-title`, `.idea-context`, `.idea-backlinks`,
`.idea-page-list`, `.idea-page-row`, and around every note's header `.idea-head`.

An outline ROW carries the note's tags too, built the same way `#idea` builds
them for a note's heading, its card and a `#window` of it — one convention,
four emission sites, so a site that styles a todo note in the body can style
the same note's row in the index, or its window anywhere else. MEASURED: a
`todo`-tagged row is
`<li class="idea-outline-row idea-tag-todo">`, a two-tag note's row is
`<li class="idea-outline-row idea-tag-phd idea-tag-draft">`, and an untagged
note's row is exactly `<li class="idea-outline-row">`. Every key appears,
valued tags included, and the order between them is unspecified.
This is also the zero-API half of tag filtering: with the classes there, a site
can grey, badge or hide rows in its own CSS with no Typst-side filter at all.
The package ships NO default rule for any `.idea-tag-*` on the card or the note's
heading — a tag is free-form, not a recognised set, and styling one would
invent an opinion. A row's own marker is the exception, and only for a tag you
themed by name: `theme: (tags-color: ...)` publishes `--idea-tag-line` on that
tag's class, which the marker reads (see "Per-tag colour" below).

`.idea-tab` is a **hat**: a short stub of rule out of a frame's top-left corner
with a label sitting on its end, in the same `--idea-border-color` as the rule
beside it so the two meet at that corner, and in `--idea-label-font`. It appears
in three places — above a note's heading and above a window's title, where it
wraps the permalink in a `<span>`; and on `#ideas-outline`'s
`.idea-outline-title`, which carries `idea-tab` on the `<h4>` itself, because a
`<span>` may not contain a heading. A bare permalink standing in prose — a nested
window with no unfurl budget left — has no tab, because there is no frame for it to
rule off.

`.idea-outline-title` is that `<h4>`, and it is styled to uppercase at label size
rather than left to a site's heading scale: `font-variant: normal` and
`text-transform: uppercase` are asserted on the class, so a site setting
`h1..h6 { font-variant: small-caps }` cannot turn "Contents" into small caps
against the names beside it.

`.idea-head` is the element around the tab and the heading beneath it, in a card
and on a minted note page alike. It exists because the two have to be real
siblings for the stylesheet to close the gap between them, and loose content is
not reliably that: Typst's HTML export wraps a leading inline run in a `<p>` of
its own in some cards and not others. On a minted page, where there is no
`.idea-box`, it is also that page's theme container — the element a `theme:`
override lands on.

The two footer sections have the same shape — a heading with rows flowing down
from it — because they are the same kind of thing: places this note is
reachable from. A page cannot be a `#window`, having no note to fold open, so it
is a plain link wearing the row shape a `#window` gives a note (`.idea-page-row`
carries the same left rule and indent as `.idea-window`), which is what lets
Context, note backlinks and page backlinks read as one list of entries. A
`#window` at `unfurl: 0` wears the same row, for the same reason: at that budget
it is a pointer to somewhere the note can be read, not a transclusion of it.

**Not yet:** a hover-preview link (`#preview`) was tried and reverted — it
would have composed `@rheo/tooltip`, but rheo's package asset auto-detection
only scans a project's own `.typ` files for package imports, not the packages
those files' packages import in turn. That would have forced every project
using it to also import `@rheo/tooltip` directly just to get its JS
auto-injected — a leaky requirement, not worth the feature.

## Tags

A free-form set of tags, nothing more — there is no fixed or recognised set and
no `kind`/`type` parameter. Notes are flat; tags are tags, not a taxonomy, and
NOT a task tracker.

```typst
#idea("meeting-notes", tags: ("draft", "review"))[...]
```

Underneath, a note's tags are a DICTIONARY: keys are the tag names, values are
whatever you put there, and a plain tag's value is `none`. Four forms are
accepted and all normalize to that one shape, so write whichever is closer to
hand:

| you write | it becomes |
| --- | --- |
| `tags: none` | `(:)` |
| `tags: "draft"` | `(draft: none)` |
| `tags: ("draft", "review")` | `(draft: none, review: none)` |
| `tags: (draft: none, priority: 1)` | unchanged |

`("draft", "review")` and `(draft: none, review: none)` are therefore the same
record, and a pinned name written one way in one place and the other way in
another is not a duplicate-name collision.

A VALUED tag is how a tag carries metadata rather than only naming itself:

```typst
#idea("ship-it", tags: (draft: none, priority: 1, depends-on: ("fetch", "build")))[...]
```

That is the primitive `@rookery/todos` builds its dependency graph on, and
`@rookery/timeline` its `scheduled`/`deadline` dates. A value can be any
Typst value at all — an integer, an array, a `datetime`, content.

**Tags are UNORDERED.** Key order is unspecified and nothing may depend on
it; sort them yourself if you need a stable sequence.

**Naming a key.** A tag key becomes a CSS class fragment (`.idea-tag-<key>`),
so keep keys class-safe — alphanumerics and hyphens. A package contributing
tags to notes it does not own should NAMESPACE its keys with a hyphen prefix
(`todo-deps`, `date-deadline`) rather than claiming a bare generic name, since
two packages both wanting `depends-on` would silently collide.

Each tag becomes its own `idea-tag-<key>` CSS class on the note's heading and
card, alongside the base `idea` class — EVERY key, valued tags included — so
style them in your own stylesheet. A `#window` transcluding the note wears the
same classes on its own wrapper, alongside the base `idea-window` class — one
element per note, the same way the card carries them once.

**`display-tags: true`** on `#idea`/`#window` ALSO renders a note's tags as a row
of visible pills in the hat — the same `.idea-tab` the name and (with
`display-date: true`) the date sit on, in that fixed order: name, then tags, then
date. Off by default, the same mechanism as `display-date`:

```typst
#idea("meeting-notes", tags: ("draft", "review"), display-tags: true)[...]
#window("meeting-notes", display-tags: true) // pills again here, independently
```

An untagged note has no tags either way, so `display-tags: true` renders no pill
for it.

**Pills are FLAT TAGS ONLY** — those whose value is `none`. A valued tag keeps
its `.idea-tag-<key>` class everywhere, but gets no pill: `depends-on` rendered
as a pill would show its name and none of its dependencies, which is noise. A
package holding metadata in tags renders it its own way instead.

Each pill carries TWO classes: `.idea-tag`, the pill's own hook, and
`.idea-tag-<tag>` — the SAME class the note's heading and card already wear.
**`@rookery/search`'s own result-row chips wear it too** (alongside that
package's own `.rookery-search-tag`), so one project rule — `.idea-tag-draft {
color: ...; }` — styles that tag everywhere it shows up: the note's heading,
its card, an outline row, a hat pill, and a search result chip alike.

Five CSS custom properties style a tag. Two of them — `--idea-tag-size` and
`--idea-tag-radius` — have no `theme:` entry and use only the raw custom-property
mechanism, the same "your own stylesheet" pattern as `--idea-external-color`.
The other three are what `theme: (tags-color: (...))` (described below) sets
per-tag, as a rule on `.idea-tag-<tag>` in `@layer rookery-tags`. Being layered,
those generated rules beat the package's own CSS defaults and lose to YOUR
unlayered stylesheet — so a project can restate any of them for a themed tag:

| property | what it sets | default |
| --- | --- | --- |
| `--idea-tag-size` | the pill's font size | `--idea-label-size` (`0.57rem`) |
| `--idea-tag-radius` | the pill's corner radius | `999px` |
| `--idea-tag-color` | the pill's text colour | `--idea-name-color` (`gray`) |
| `--idea-tag-bg` | the pill's background | `rgba(128, 128, 128, 0.18)`, or `color-mix(in oklab, currentColor 14%, transparent)` where supported |
| `--idea-tag-line` | the colour of an outline row's marker, the tick off the outline's rule | `--idea-border-color`, else `--idea-link-color`. Set from a themed tag's `text` colour where it has one and its `background` otherwise |

### Per-tag colour: `tags-color`

Syntax, both value forms:

```typst
#show: rookery.with(theme: (
  tags-color: (
    draft: rgb("#3366ff"),                          // background only
    note: (background: rgb("#0000ff"), text: white), // background + text
    warn: (text: rgb("#aa0000")),                    // text only
  ),
))
```

A bare colour or CSS colour string is shorthand for `(background: ...)`. A tag with no entry in `tags-color` keeps the CSS default (`--idea-tag-bg`/`--idea-tag-color`, or your own project stylesheet rule) — `tags-color` only overrides the tags it names.

A `tags-color` KEY has to be usable as a CSS class — a letter or an underscore first, then letters, digits, hyphens and underscores — because the key becomes a selector. `tags-color: ("in progress": ...)` fails the build with a message naming the tag. A tag in a note's own `tags:` array is unconstrained, as before: the rule is about naming a colour for a tag, not about carrying one.

**Delivered as generated CSS rules, not as a style on the pill.** Each themed tag becomes one `.idea-tag-<tag>` rule setting `--idea-tag-bg`, `--idea-tag-color` and `--idea-tag-line`, wrapped in `@layer rookery-tags` and emitted once per page — by `#show: rookery` on every vertebra, and again on every page the package mints. So the colours reach every surface already wearing that class:

- the **hat pill** (`display-tags: true`);
- an **outline row's marker**, the hairline tick off the outline's own rule, through `--idea-tag-line`;
- **`@rookery/search`'s modal chips**, built in the browser and therefore beyond the reach of anything Typst could write inline.

It deliberately does NOT colour the **card**, the **note's heading**, or a **window's** own wrapper, which all stay a rule for your own stylesheet to write even though all three wear the `.idea-tag-<tag>` class. The pill already names the kind beside them, and colouring a note's own title (or its window) makes the page's typography argue with its prose.

Two consequences worth knowing:

- **A project stylesheet can override a themed pill.** The generated rules sit in a layer, and unlayered CSS beats layered CSS whatever the source order, so your own `.idea-tag-draft { --idea-tag-bg: ... }` wins.
- **A themed pill is NOT coloured in EPUB or PDF.** An EPUB here ships no stylesheet, so the `var()`s fall back to their defaults, and the paged target renders no hat at all. Accepted deliberately in exchange for the reach above, not overlooked.

Like the rest of `theme:`, this is **one value for the whole document** — apply the same arguments in every vertebra (see "The theme" above and "Setup").

`@rookery/search`'s own result-row chips DO pick up `tags-color`. That package renders them client-side from JavaScript, so no style Typst writes can reach them — but each chip carries `idea-tag-<tag>`, and `tags-color` arrives as a rule on that class, which applies whenever the chip enters the DOM. A chip reads `--idea-tag-bg`/`--idea-tag-color` behind its own `--rookery-search-tag-bg`/`--rookery-search-tag-color`, so a project styling every chip in the modal still wins over a themed tag.

### `tag:` and `base-tags:` — build your own constructors

`#idea` takes three tag arguments, and they differ in who writes them and
what they accept:

```typst
#idea(
  tag: "onlystring",                    // a string, or none
  base-tags: ("string", "or", "array"), // none, string, array or dictionary
  tags: "string-or-array",              // none, string, array or dictionary
)
```

`tags:` is the CALL SITE's. It REPLACES whatever a constructor bound, which
is why it is safe to name at a call site and unsafe to bind with `.with()`.
`base-tags:` and `tag:` are a CONSTRUCTOR's, and they MERGE under the call
site's `tags:` instead — this is what makes `idea.with(tag: ..)` a safe
`.with()` spelling:

```typst
#let note = idea.with(tag: "note")
#note("c", tags: ("draft",))[body]      // -> ("note", "draft")
```

Do NOT write `#let note = idea.with(tags: (note: none))`. An explicit `tags:`
at the call site OVERRIDES a default bound by `.with()`, so `#note("x", tags:
("draft",))` would silently drop `note` — the tag you reached for `#note` to
get. `tag:` and `base-tags:` are what express "merge, don't replace":

```typst
#let participant = idea.with(base-tags: ("person", "participant"))
#let todo = idea.with(base-tags: (todo: (state: "open")))
```

PRECEDENCE, lowest to highest: `tag:`, then `base-tags:`, then `tags:`. Where
two of them name the same tag, the higher one's value wins outright — there
is no deep merge.

`.with()` COMPOSES, which is what makes it safe to chain a project's own
exclusion binding underneath a constructor:

```typst
#let idea = idea.with(exclude-tags: EX)
#let note = idea.with(tag: "note")
```

`note` chains off the already-bound `idea`, so it inherits `EX` with nothing
named twice — see "Excluding notes from a build" below for why that matters.

A dictionary `base-tags:` binds a DEFAULT VALUE for a tag, for a constructor
whose tag means more than its own presence. A caller naming that tag
themselves still wins outright, with no deep merge:

```typst
#let flagged = idea.with(base-tags: (flag: "yes"))
#flagged("a")[...]                       // flag: "yes"
#flagged("b", tags: (flag: "no"))[...]   // flag: "no"
```

`@rookery/todos` builds its whole `#todo`/`#epic` surface on this.

### Reading tags back

A tag is not only a styling hook: the note records the tags it was created
with, and three accessors read them back.

`#context idea-tag-names(name)` gives the note's tag NAMES — every key, valued tags
included, in unspecified order:

```typst
#context idea-tag-names("y")   // -> ("todo", "draft")
```

`#context idea-tag-value(name, key, default: none)` gives ONE tag's value:

```typst
#context idea-tag-value("ship-it", "priority")           // -> 1
#context idea-tag-value("ship-it", "nope", default: 4)   // -> 4
```

A plain tag's value is `none`, which is indistinguishable from a `default:
none` on an absent key — ask `idea-tag-names` when the question is presence.

`#context tag-data()` gives every note's whole tag store at once, keyed by full
name:

```typst
#context tag-data()   // -> ("idea:ship-it": (draft: none, priority: 1), ..)
```

Use the bulk form when you are walking the corpus: `idea-tag-names` and `idea-tag-value`
each resolve the registry for ONE note, so N notes cost N reads, where one
`#ideas()` plus one `#tag-data()` covers everything and the two join on `id`.

All three take the same name forms as `#window` and `#hyperlink` — a bare name,
a prefixed name, or a label — and answer emptily for an untagged note and for a name
that does not exist. An unknown name is deliberately not an error: a caller asking what
something is tagged is filtering, not dereferencing, and a filter that panics
on the first miss is useless. That is what lets another package pick out a
tagged subset of your notes without reaching into rookery's internals.

Rookery uses this itself: `#window(tagged: ...)` transcludes every note carrying
a tag, alongside any it was given by name. See "Referencing a note" above.
`#ideas-outline(tagged: ..., match: ..., filter: ...)` narrows an INDEX the same
way — see "Outlining notes" above.

Filtering an index by a tag does not make tags a taxonomy or a task tracker
either, though it is the feature that most invites the opposite reading.
`tagged: "todo"` looks like a status field and is not one: nothing validates the
string, no tag is recognised or reserved, a note carrying `todo` means only that
you wrote `todo` on it, and a filter is a question asked at one call site rather
than a schema the rookery holds you to. Free-form array of strings, still.

## Excluding notes from a build

`exclude-tags:` drops a note from a build entirely, by tag. This is for a build
script producing DIFFERENT SUBSECTIONS of one rookery from one source tree — a
public static site with the `protected` notes removed, and a dev build that keeps
them.

An excluded note does not exist. Not hidden, not collapsed, not `display: none`:

- nothing is rendered where it was written;
- it is not in the registry, so it is absent from `#ideas()`, `#tag-data()` and
  `#ideas-outline`;
- no standalone page is minted for it, and it takes no row on `ideas/index.html`;
- it is not in `@rookery/search`'s index, so it cannot be found by search;
- it emits no `<feeds:item>` beacon, so it is not syndicated;
- it appears in no backlink list.

It also costs nothing. The gate runs before the note's marker is built, so an
excluded note is never flattened, never walked for links or footnotes or
citations, and never converted to plain text.

### Two channels, and how they compose

```
excluded = (declared UNION --input rookery-exclude) MINUS --input rookery-include
```

The DECLARED list is the baseline, which is what makes the published build correct
by default with no environment set at all. `rookery-include` is how a dev build
puts those notes back. `rookery-exclude` is how a build script carves a further
subsection without touching the project source. Both `--input` values are lists
of tag names separated by commas, whitespace, or both.

```typst
// content/lib.typ — the one place a project configures the package
#import "@rookery/core:0.1.0": idea as _idea

#let EX = ("protected", "private")
#let idea = _idea.with(exclude-tags: EX)
#let note = idea.with(tag: "note")
```

```sh
# the published build — nothing to pass, the declared list is the baseline
typst compile content/index.typ site/index.html

# the dev build — put them back
typst compile --input rookery-include=protected,private content/index.typ site/index.html
```

### Why one binding is enough

`.with()` chains off whatever it is applied to, so a constructor built on the
project's OWN bound `idea` — `idea.with(tag: "note")`, applied to the `idea`
already carrying `exclude-tags: EX` — inherits that exclusion with nothing
named twice. There is no second binding to forget, and so no way for `#note`
to go on hatching the very notes the project asked to exclude.

A constructor built from CORE's own package-scope `idea`, rather than a
project's rebound one, still does not see a project's `exclude-tags:` — the
hazard has not disappeared, it has moved to whoever builds the constructor. A
project always builds its own off its own bound `idea` now, so the hazard
only remains for a constructor a PACKAGE exports for others to call, which is
why `@rookery/slipshow`'s `#slip` still asks callers for `exclude-tags:`
explicitly rather than assuming it is covered.

### Why it is not `rookery.with(exclude-tags: ..)`

Because it cannot be. A `rookery.with()` argument becomes document-wide state,
state is read with `.final()`, and `.final()` requires a `#context` block — and
the gate has to run OUTSIDE one. Five separate things in this package find notes
by walking for `#idea`'s marker structurally, before realization, and a
`#context`-wrapped note is invisible to all five. So the exclusion list has to be
readable with no context, which means a function argument and `sys.inputs`.

`invisible-tags` below IS a `rookery.with()` argument, and the asymmetry is
deliberate rather than an inconsistency: that one is pure presentation, and every
site it touches already runs inside a `#context`.

### Under rheo

`rheo compile` forwards no `--input` today, so the two `sys.inputs` keys
currently reach a plain `typst compile` only. The DECLARED list works everywhere,
including under rheo, which is why it is the baseline rather than the override. A
`--input` flag and a `rheo.toml [inputs]` table are specced in rheo; nothing in
this package changes when they land.

### The one hazard: `@`-references

An `@idea:x` reference to an excluded note is a HARD TYPST ERROR — `label
<idea:x> does not exist in the document` — and this package cannot intercept it.
The label is minted by the very `#idea` that got removed, so by the time the
reference is resolved there is nothing there and no rookery code involved.

Everything else degrades gracefully instead:

| you wrote | excluded note | note that never existed |
| --- | --- | --- |
| `#window("x")` | renders nothing | panics `#window unknown note` |
| `#window(tagged: ..)` | not selected | — |
| `#idea-body("x")` | renders nothing | panics `#idea-body unknown note` |
| `#hyperlink("x")[text]` | renders `text`, unlinked | panics `#hyperlink unknown note` |

`#hyperlink` keeps its body because it sits inline in a sentence you wrote, and
deleting it would break the grammar around it. A genuine typo still fails loudly
in every case — telling "deliberately excluded from this build" apart from
"misspelt" is the whole point.

So: link to an excludable note with `#window`, `#hyperlink` or `#idea-href`,
never with `@`.

## Invisible tags

`invisible-tags:` suppresses a tag's visible traces without affecting anything
else about it:

```typst
#show: rookery.with(invisible-tags: ("private",))
```

It removes, everywhere:

- the PILL in a note's hat — on a card, in a `#window` summary, and on a minted
  note page (which shows its tags unconditionally, since nothing writes a
  `display-tags:` argument for a page the package mints);
- the `idea-tag-<tag>` CSS CLASS — on the heading, the card, a transcluded
  card, a `#window`'s own wrapper, and an `ideas/index.html` or
  `#ideas-outline` row;
- the generated `.idea-tag-<tag>` rule that a `theme: (tags-color: ..)` entry
  would otherwise emit for it.

The tag's name is then absent from the HTML altogether, which is the point: a
class alone is enough to tell a reader the tag is there.

It does NOT touch filtering. `#idea-tag-names`, `#idea-tag-value`, `#tag-data`,
`#ideas(tagged:, match:)`, `#window(tagged: ..)`, `#ideas-outline(tagged: ..)` and
`@rookery/search`'s index and tag query all still see an invisible tag. That
is what makes it usable as an `exclude-tags` key, and it is why the two features
compose.

### The pair they exist for

A `protected` tag keeps its pill: in a dev build it tells you something useful
about the note you are reading. A `private` tag is also kept out of the public
build, but it is authorial — you do not want private notes distinguishable from
protected ones anywhere — so it goes on `invisible-tags` as well.

```typst
#show: rookery.with(invisible-tags: ("private",))
```

```typst
// content/lib.typ
#let EX = ("protected", "private")
#let idea = _idea.with(exclude-tags: EX)
#let note = idea.with(tag: "note")
```

`protected` and `private` are both gone from the published build; in the dev
build both notes are present, `protected` wears its pill, and nothing anywhere
says `private`.

## Derived labels

A note with no `title:` gets a naming LABEL from its own body: the first 60
characters as plain text, with `...` appended when there is more.

```typst
#idea[A short body becomes the label verbatim.]
// label: "A short body becomes the label verbatim."

#idea[Deriving a label means a note is nameable with no ceremony at all.]
// label: "Deriving a label means a note is nameable with no ceremony a..."

#idea("etal", title: [Et al.])[...]     // an authored title is the label too
#idea("stub")[]                         // nothing to derive from: no label
```

**A LABEL, NOT A HEADING**, and the distinction is the whole design. A label is
what to call this note SOMEWHERE ELSE. It is *not* printed above the note's own
body, because the body is the thing the reader is already looking at — an authored
title never has that problem because it differs from the body, but a derived one
*is* the body.

Where the label is used:

| | |
| --- | --- |
| the note's minted page `<title>` | the browser tab, never beside the body |
| an `ideas/index.html` row | |
| an `#ideas-outline` entry | an untitled note is listed under its derived label, not skipped |
| a `<feeds:item>` title | |
| a `#window` summary | a folded window shows the summary alone |
| an unfurl-exhausted `#window` | a titled row rather than a bare `[idea:1]` |
| the text of `@idea:x` / `#hyperlink` | |
| `#ideas()`'s `label` field | for your own index, feed or graph |

Where it is deliberately NOT used — every place a heading sits above the body:
the note's own card, its minted page's `<h1>`, and a transcluded card's heading.
A titleless note's heading stays empty there; the element survives only to
carry the `id` anchor, and the stylesheet collapses it.

`#ideas()` therefore publishes three fields where it published two:

- `title` — the AUTHORED title as content, `none` when there is none. Unchanged.
- `text` — the same, flattened to a string, `""` when there is none. Unchanged.
- `label` — **never empty**: the authored title flattened, else the derived
  opening words, else the note's own `name`.

That last fallback is the point. Before it, a consumer wanting to name a note in a
list had to write `if r.text == "" { r.name } else { r.title }` — a real project
had **eight** copies of exactly that. Now it is `r.label`.

The details, all of which have a reason:

- **Whitespace collapses first**, so a multi-paragraph, multi-line body yields one
  clean line — the same normalization `#ideas()`'s `body` field uses.
- **An authored `title:` always wins**, and becomes the label too (flattened).
- **An EMPTY body gets no label**, and the note has none. `#idea("x")[]` is legal
  and has no text to name itself with, so it stays out of `#ideas-outline` and its
  minted page falls back to its slug.
- **60 characters means 60 grapheme clusters**, not bytes, so accented text, em
  dashes and Typst's own smart quotes count as a reader would count them — and
  none of them can split a character.
- **The limit is not configurable.** There is no argument for it on `#idea` and no
  key for it on `rookery.with()`.

## Dates

Resolution order, most specific first:

1. The `created:` argument passed to `#idea`, when given.
2. The containing document's own `#set document(date: ...)`.
3. Otherwise: no date is recorded. A date is never invented (no
   `datetime.today()`, no file mtimes, no VCS).

```typst
#set document(date: datetime(year: 2026, month: 1, day: 10))

#idea("a")[Inherits the document date.]
#idea("b", created: datetime(year: 2025, month: 5, day: 1))[Overridden, this note only.]
```

A date is always RESOLVED and stored on the note's registry record, but
rendering it is opt-in — `display-date: false` by default, on both `#idea` and
`#window`, so an unconfigured note's header is just the title and its name:

```typst
#idea("a", display-date: true)[Shows its date at the right-hand end of the hat.]
#window("a", display-date: true) // shows it again here, independently
```

**Where it renders is the hat** — the `.idea-tab` rule across the top of a card
or a window, with the name on the stub at the left end and the date pushed to the
far right. It is the frame's metadata, not a subtitle — `.idea-date` sits
inside `.idea-tab` wherever it appears, one class in one place, rather than
duplicated as a heading child on a card and a summary-row item on a window.
The top rule does not resume on the date's far side — the hat draws one stub,
to the left, and stops at the name.

**There is ONE date, and it is `created`.** There is no `updated` beside it,
even though the date a reader wants off the top of a card is arguably when
the note was last touched.

That argument is right, and this package was the wrong place to answer it. A
hand-maintained `updated:` is a second date the author has to remember, and one
that can contradict what actually happened to the note. So core keeps only the
date it can resolve without being told anything, and a note's LIFECYCLE belongs to
`@rookery/timeline`: it stores a dated log and derives last-touched from it.

```typst
#import "@rookery/timeline:0.1.0": updated-of
// the log's last entry where there is one, else this note's `created`
#context updated-of((..row, tags-dict: tag-data().at(row.id)))
```

A note's own minted page is the exception: there the date shows **always**, with
no `display-date:` to gate it — and its tags render as pills too, same hat, same
"always", no `display-tags:` to gate that either. Nobody writes an `#idea` call for
that page — `.marrow.typ` mints it from the registry — and a note's own page is
the one place its date and its tags are metadata rather than a decoration on
someone else's prose.

The two call-site settings are independent: passing `display-date: true` to a
`#window` surfaces the date even when the note's own `#idea` left it hidden, and
vice versa — nothing links them beyond both defaulting off.

On a paged target there is no hat to hang it on, so `#idea` and `#window` keep
printing the date where they always did; only *which* date it is has changed.

## Footnotes

A footnote belongs to the idea it was written in, not to the page that happens
to be showing it. Import `footnote` alongside `idea` and write it exactly as
you always have:

```typst
#import "@rookery/core:0.1.0": idea, footnote

#idea("etal")[A claim#footnote[The evidence.] worth qualifying.]
```

Numbering is per idea, so two notes on one page may each carry a footnote 1 —
the point rather than a collision, since a reader meets a note in the context
of one idea and a number counting the whole page would be counting something
they cannot see. The bodies render in a `Footnotes` block at the end of the
idea.

That block follows the note everywhere the note goes — the page it was hatched
in, every `#window` on it, its own minted page — and each of those gets its OWN
block with its own anchors. They have to be separate: a footnote reference is a
same-page fragment, so a window on another page needs its target on that page.
On a minted page the block sits between the body and the Context/Backlinks
footer, keeping the note's own apparatus attached to the note and leaving the
footer last as the way back out.

In HTML and EPUB, a `#window` with `limit:` lists every footnote in the note,
because the tail is not actually discarded there — it sits collapsed behind
the preview's own disclosure (see "Referencing a note"), and one written
inside the shown portion renders twice as a result: once bare, in the
collapsed preview, and once more, correctly numbered, in the list below once
the body unfurls. Under a paged target, where the tail really is dropped, the
block lists only the footnotes whose references survive the truncation, so a
shortened note there never shows an entry with nothing pointing at it.

**`#footnote` has to be imported to take effect**, and Typst imports are
per-file: every vertebra that writes a footnote needs `footnote` in its own
import list, the same way each one needs the template for the `ref` rule.
Omitting it fails the build with an error naming the import to add — the
alternative (Typst's own footnote behaviour: the body goes to the page's
endnote section, numbered page-wide, and the idea renders no block at all)
fails silently, which is worse than a loud build error for a mistake this
easy to make. A footnote in ordinary page prose,
outside any idea, is untouched by that check and still behaves exactly as
Typst's does: page-wide numbering, body in the page's own endnote section.
`#show: rookery` installs that fallback, so a document that never applies the
template and writes a rookery `#footnote` in bare prose renders nothing for it
— the same shape of caveat as `@idea:etal` rendering a bare figure number
without the template.

The reason this is a shadowed `#footnote` rather than a show rule over Typst's
own is that Typst's cannot be intercepted. Its HTML exporter collects footnote
bodies by introspection, so neither `show footnote: it => ...` nor
`show footnote: none` keeps a body out of the page's endnote section; the
import site is the only place the decision can be made.

## Bibliographies

One bibliography for the whole rookery, configured on the template with Typst's
own `#bibliography` arguments:

```typst
#show: rookery.with(bibliography: arguments(
  bytes(read("refs.bib")),
  style: "chicago-author-date",
))
```

**Bytes, not a path.** Typst resolves a path relative to the file the call
appears in, and every call this package makes appears inside the package — a
path would be looked for next to `lib.typ`. `bytes` carries its data instead, so
your own `read()` resolves against your own file. It is one of the source types
`#bibliography` already accepts, so this is still literally its argument list,
and a path is rejected up front with the `read()` form to write instead. Both
BibTeX and Hayagriva work; the format is recognised from the content, there
being no filename left to go on.

Like the prefix and the theme, it is one value for the whole document — see the
note under "Setup" for why, and apply the same arguments in every vertebra.

`style:` defaults to an author-date style when you pass none. Citation numbering
in Typst is document-wide and cannot be reset: CSL assigns the numbers and no
counter controls them, so under a numeric style the third idea on a page reads
`[3]`, and a note's own page can show its only reference as `[7]`. An
author-date style has no numbers and the question does not arise. A numeric
style is still honoured without complaint — this is a default, not a
restriction.

Every idea that cites anything renders its own `References` block at the end of
it, and an idea that cites nothing renders none: no empty heading. Like
footnotes, the block follows the note to each surface it appears on — its hatch
page, every `#window` on it, its minted page — each with its own copy, since a
citation link is a same-page fragment and a window on another page needs its
target on that page. On a minted page it sits between the body and the
Context/Backlinks footer.

Citations written in page prose, outside any idea, are collected into a
page-level `References` block after the page's content. Getting them there
takes a little machinery you may see in the markup: rookery emits an
unlabelled, usually empty claiming block before every idea, because Typst
assigns each citation to the nearest bibliography FOLLOWING it, and without one
a citation written above an idea would land in that idea's list. An idea never
sees the prose around it, so that block cannot be conditional.

The same rule decides what happens when an idea contains a `#window`: the
window's own block comes first and claims what precedes it, so a citation
written before a window in the same note is listed under the window rather than
under the note. It is the reader's next block either way.

**A window's citations resolve inside the window**, not on the note's own page.
Linking them across was tried and dropped: redirecting a citation means
de-registering it, a de-registered citation renders nothing, and the package
would then have to format the marker itself — which means reading authors and
dates out of your bibliography and reimplementing what Typst already does.
Rookery reads the key list and nothing else, only ever to answer "does this idea
cite anything"; Typst formats every citation and every entry.

## Standalone note pages (rheo only)

Importing this package mints one output page per note automatically, at
`<dir>/<id>.html` — e.g. `ideas/etal.html` for `<idea:etal>`, the prefix
stripped off whatever it is set to — via a package
`.marrow.typ` that rheo inlines at the bundle root. No `rheo.toml` entry and
no project file needed. Typst will print `warning: bundle export is
experimental` — expected, not a sign anything is wrong.

This is the part that needs **rheo >= 0.6.2**: inlining a package's
`.marrow.typ` landed there, and an older rheo passes over it in silence rather
than failing, so the symptom is not an error but an absence — no minted
pages, and links into them that resolve to nothing.

Each minted page shows the note's title and permalink name, then its body, then
a footer with two parts — each omitted, rather than left empty, when it has
nothing to say.

### Where pages are minted: `idea-dir`

`<dir>` above defaults to `"ideas"`, not to the prefix. This is deliberate,
resolved in order:

1. `idea-dir:`, when you set one;
2. else `"ideas"`, when `prefix` is left at its default `"idea"`;
3. else `prefix`, verbatim.

It is not simply `dir = prefix`, and not `prefix + "s"` either — pluralizing
`"maths"` would give you `mathss/`, not `maths/`. So the rule falls back to
the prefix only when you have actually changed it, and even then hands you
the prefix as-is:

```typst
#show: rookery.with(prefix: "maths")
// no idea-dir set -> pages mint at maths/<slug>.html, names read `maths:<slug>`
```

**Breaking, if you already set a custom `prefix`.** Before `idea-dir`
existed, every project minted to `ideas/` regardless of `prefix` — the
directory was a package constant. A project that set `prefix: "note"` (say)
and expects its pages to stay at `ideas/<slug>.html` must now set
`idea-dir: "ideas"` explicitly:

```typst
#show: rookery.with(prefix: "note", idea-dir: "ideas")
```

Leaving `idea-dir` unset moves every page in such a project to `note/`
instead. A project that never touched `prefix` is unaffected either way —
rule 2 above keeps it at `ideas/`.

### Turning the footer off: `display-context`, `display-backlinks`

Both default to `true`, so a page's footer is exactly what it always was
unless you say otherwise. Context is the link back to the vertebra a note was
written on; Backlinks is every note and page that links here. Turn either off
document-wide, independently of the other — nothing else about the page
changes:

```typst
#show: rookery.with(display-context: false, display-backlinks: false)
```

`#idea` (and `#note`/`#todo`/anything built with `idea.with(..)`) takes the same
two arguments, defaulting to `auto` — "use the document-wide setting above" —
so a single note can override either without changing it for the rest of the
rookery:

```typst
#idea("etal", display-context: false)[A note with no Context section, whatever
`rookery.with(display-context: ..)` says.]
```

### Hiding the minted page's heading: `display-title`

`display-title` governs a note's OWN MINTED PAGE ONLY. Defaults to `true`, so the
`<h1>` is exactly what it always was unless you say otherwise. It does not
touch anywhere else a note's title appears — a `#window` summary, an `@ref`,
and an `ideas/index.html` row all still call the note by its title (or
derived label) regardless of this setting, because that is how a reader finds
the note in the first place. Turn it off document-wide when a project's own
page chrome already names the note (a reading list entry, a session title in
a metadata table) and printing it again as a heading is redundant:

```typst
#show: rookery.with(display-title: false)
```

`#idea` takes the same argument, defaulting to `auto` — "use the
document-wide setting above" — so a single note can override it without
changing the rest of the rookery:

```typst
#idea("etal", display-title: false)[This note's own page has no `<h1>`, but a
`#window(<etal>)` elsewhere still shows its title.]
```

With `display-title: false` resolved, the minted page omits the `<h1>` entirely
rather than leaving an empty one — the name that would have been the heading's
anchor moves onto its `.idea-head` container instead, so a Context link from
another page's footer still lands on the note.

### A landing page for the whole rookery: `index-page`

`<dir>/` (see "Where pages are minted: `idea-dir`" — `ideas/` unless you set
`prefix` or `idea-dir`) is the parent directory of every permalink this
package mints, and the URL a reader will guess. Rookery mints
`<dir>/index.html` there by default: a heading, a count, and every note in the
rookery linked to **its own minted page**, carrying its date and its tags. The
rows wear `#ideas-outline`'s
classes — `.idea-outline`, `.idea-outline-row`, `.idea-tag-<tag>` — so a
stylesheet that already knows the outline knows this page too, and it needs no
CSS of its own. They are listed in name order, which is what `#ideas()` returns.

It is NOT `#ideas-outline()`, and the difference matters: the
outline links each row to the note's anchor on the vertebra that authored it,
which is right for a table of contents sitting on that page and wrong for a page
whose whole job is to index the minted ones.

Turn it off if a project already has its own index — a homepage built from
`#window(tagged: "post")`, say — and doesn't want a second one published under it:

```typst
#show: rookery.with(index-page: false)
```

The page goes through `idea-page-template` exactly as a note page does, so it
inherits your project's chrome. It is the one minted page that is not a note,
and the template sees that: `id` is `none` and `note` is an empty dictionary. A
template that assumes a string id needs one branch —
`core/0.1.0/demo/rheo/content/lib.typ` carries the two-line version.

### Giving minted pages your own chrome

A minted page is a separate document spliced in at the bundle root, *outside*
every vertebra — so it inherits nothing from the `#show:` your project applies
to its own pages, and by default has no site header or nav.
`idea-page-template` is how you hand one over:

```typst
// One named, top-level function...
#let idea-page(id: none, note: (:), doc) = {
  show: chrome.with(current-page: id)
  doc
}

// ...registered once, in the template every vertebra applies.
#show: rookery.with(idea-page-template: idea-page)
```

It is called once per note, wrapping the **whole** minted page — heading, body
and footer — so it sees exactly what a vertebra's own `#show:` would.

- `id` is the note's full name (`idea:etal`), the same string `#window` and
  `@idea:etal` name it by, and the natural "which page am I on" key.
- `note` is the note's registry record — `title`, `minted`, `updated`,
  `origin` (the handle of the page it was written in) and `links` — so a
  richer idea-page header needs no query.

Make it a **named top-level binding**, not a closure written inline inside the
template that registers it. The package holds it on a document-wide state, and
a fresh closure per vertebra puts a different value on that state's timeline
for each one; a named binding is one value however many vertebrae reference
it.

Apply your *chrome* from it rather than your whole page template, and split
that chrome out of the template if you have not already — otherwise the two
have to reference each other. A minted page also has no need to re-apply
`#show: rookery`: every vertebra has already set the prefix, theme and window
unfurl budget by the time one is minted.

Left unset, minted pages are bare, exactly as before.

**Context** is the page the note was *written* in:

```
Context: Rookery under Rheo
```

The link goes to the note's own anchor on that page, not to the top of it — a
minted page shows a note stripped of everything around it, and this is the way
back to the argument it was written inside. The name shown is rheo's own title
for that vertebra, so give a page a `#set document(title: ...)` or the footer
will read as its title-cased filename ("Index").

Where a note was written is captured at `#idea` time, because that is the only
moment anything knows it: a minted page is a separate document that inherits
nothing, and a `#window` can transclude a note onto any number of other pages.

**Backlinks** is everything that points at this note — an index of what refers
here. Three things count as pointing, all of which a reader would call a link:

```typst
#link(label("idea:etal"))[...]   // an explicit jump
@idea:etal                        // a reference
#window("etal")                    // a transclusion
```

An entry is whatever **directly** contains the link:

- a **note**, if the link is inside one — rendered as a folded `#window`, which
  you can open in place;
- otherwise the **page**, if the link is in its prose or in a page-level
  `#window` — rendered as a plain link, since there is no note to fold open.

Attribution is to the innermost container and stops there. A link inside a
note belongs to that note and not also to a note enclosing it, nor to the page
holding either. So a page whose only links to a note are inside its own notes
does not appear; those links are already listed, as notes. Each entry appears
once, however many times it links here.

The note's **own page never appears** — Context already names it, and says it
more precisely, linking to the note's anchor rather than to the top of the
page. A page that holds a note and also `#window`s it qualifies for both, which
is exactly the case this rule exists for.

A transcluded body counts for the note it came from, not for whichever page is
showing it — a note `#window`ed on five pages does not thereby give its own
outbound links to those five pages.

Note entries come from a map built at `#idea` time: each note's body is walked
once for outbound links, and the backlink list is that map inverted.
Registration is the only place that can happen, since a link is an element
buried in a content tree and there is no way to ask an element which note it
sits *inside* — which is exactly what a backlink asks. Page entries can't come
from there (a link in page prose belongs to no note), so they come from a
`query()` over the document instead, with `#idea` and `#window` bracketing their
content so a single ordered pass can tell depth 0 — the page itself — from
anything nested.

Where those pages exist, they are what the permalink points at — in `#idea`'s
heading, in a `#window`'s summary, and in a nested window's collapsed form alike,
since all three are the same affordance. The same-page `#id` fragment a
permalink would otherwise carry is a no-op for a reader already looking at
that heading; the minted page is what they actually want.

Hrefs are depth-relative to the page doing the linking (`../ideas/etal.html`
from a nested vertebra), and fall back to the note's in-page anchor when no
page is minted — under plain `typst compile`, or for the combined PDF.

What does NOT redirect is anything addressing the note's Typst label:
`#link(label("idea:etal"))` and `@idea:etal` still resolve to wherever `#idea`
was actually called. A minted page does NOT reuse the `idea:<id>` label (two
elements can't share one label without breaking `#link`/`#window`/
`#hyperlink` resolution), so the label keeps its original
home by construction.

Set `[html] auto_detect_packages = false` in `rheo.toml` to turn this off (it
disables every package-driven behaviour, not just this one). Skipped
automatically for the combined PDF target, which cannot create output files
at all.

## Building a package on core

Eight other packages in this repo build on `@rookery/core`, and three names
below are what they build on: a row shape shared by every list of notes, the
marker constants rookery's own output carries, and the rule that decides
whether a call needs its own `#context`. There is also an unwritten
convention, the *skin*, that two packages already follow.

### The row shape: `#idea-row` and `#idea-row-body`

`#idea-row` is one row shape for every list of notes — when, title, cells and
badges — shared by this package's own callers and reused, unmodified, by
`@rookery/search`'s filter panel, `@rookery/timeline`'s upcoming list and
`@rookery/todos`' table:

```typst
#import "@rookery/core:0.1.0": idea-row
#idea-row(
  when: [Jan 2],
  iso: "2026-01-02",
  title: [A note],
  href: "etal.html",
  cells: ([one cell], [another]),
  badges: ((text: [todo], tag: "todo"),),
)
```

It renders one `<li>`: a date cell (`when`, formatted as a `<time>` when
`iso` is given), the title (linked when `href` is given), one span per
`cells` entry, then a badge strip — a dictionary badge draws the same chip a
card or an outline row wears, and anything else is placed in the strip
verbatim, for the caller's own markup. It is HTML-only: a paged target
panics rather than laying out a grid it has no columns for, since every view
in this family already keeps its own `target() != "html"` branch that builds
a plain `list(..)` there instead. `tags:`, `extra:` and `attrs:` decorate the
`<li>` itself; `when-class:` and `when-attrs:` reach the date cell alone, one
level in — each merged UNDER the row's own computed classes, so a caller
cannot accidentally drop them.

`#idea-row-body` is the same row's children — the date cell through the
badge strip — WITHOUT the `<li>` wrapper (and without `tags:`, `extra:` or
`attrs:`, which describe the `<li>` a caller reaching for this function
already has). It exists because two of `@rookery/search`'s own widgets
disagree about who owns the list item: `#filter-panel` builds its own `<ul>`
and uses `#idea-row` itself as the `<li>`, while `#panel` — which
`@rookery/todos`' table builds on — wraps whatever its `render:` returns in
an `<li class="panel-row" data-<field>=..>` of its own, so a `#panel` row
built with `#idea-row` would nest one `<li>` inside another. `#idea-row` is
in fact `#idea-row-body` wrapped in exactly the `<li>` it draws.

This is the supported shape for a list of ideas: reach for one of these two
before hand-rolling a row's markup a fourth time.

### The marker constants: `IK`, `WK`, `FNK`

Rookery marks its own output with three constants, exported so another
package can recognise that output when it has to walk rendered content
rather than call one of this package's own accessors:

- `IK` (`"rheo-idea"`) is the `figure` `kind` an `#idea` wraps its whole card
  in.
- `WK` (`"rheo-idea-window"`) is the same for a `#window`.
- `FNK` is the label rookery's own `#footnote` marks its body with — a
  `<rkfn>` label, not a figure kind.

A walker that needs to find where an idea or a window sits inside a body of
rendered content, rather than looking a note up by name, matches
`figure(kind: IK)` or `figure(kind: WK)`. `@rookery/slipshow` does exactly
this, in `src/select.typ` and `src/marker.typ`, to recover a `#slip`'s own
options from a content value it was handed rather than a registry record it
could read instead. See "Limitations" below for the one case neither marker
reaches — an unplaced `#idea`/`#window` return value, whose `context`
wrapper keeps it unreadable until Typst places it.

### `#idea-key` — a name's label, as a string

`#idea-href` and `#idea-path` both turn a name into a URL by composing the
same two pieces: the configured prefix, and `name` normalized to a bare
slug. `#idea-key` is that composition on its own, for a caller that wants
the label name itself rather than a page URL — a `label(..)` call, or a
`#tag-data()` lookup, both of which key on this exact string:

```typst
#import "@rookery/core:0.1.0": idea-key
#context label(idea-key("etal"))                          // <idea:etal>
#context tag-data().at(idea-key("etal"), default: (:))     // that note's tags
```

It takes a bare name (`"etal"`), a full id (`"idea:etal"`), or a label
(`<etal>`, `<idea:etal>`) — whatever `idea-href` accepts — and always returns
a `str`, never a `label` and never `none`: unlike `idea-href`/`idea-path`,
resolving the prefix and normalizing the name need no rheo page to exist.
Like both of them it reads document-wide state, so it needs its own
`#context` at the call site.

### Reading data vs. rendering content: when a call needs its own `#context`

Four accessors read the registry and hand back DATA — an array, a
dictionary, a string — so the CALLER wraps each in `#context`:

```typst
#context ideas()
#context tag-data()
#context idea-tag-names("etal")
#context idea-tag-value("etal", "priority")
```

A Typst `context` block can only be a function's whole body if what the
function returns is content: a context block yields a context node, not a
plain value. So a function whose job is to return data cannot wrap itself in
one — it hands the read to whoever calls it, inside a `#context` block of
their own, and `.final()` state is only ever readable there.

Everything else that touches document-wide state and returns CONTENT —
`#idea-body`, `#idea-row`, `#ideas-outline` and `#ideate` among them — wraps
its own reads in `context` internally, so it can be called anywhere, with no
`#context` needed at the call site.

A package adding its own accessor over rookery's state follows the same
rule: return data, and let the caller supply `#context`; return content, and
supply it yourself.

### The skin contract

A **skin** is a package that re-exports core's names with its own decoration
added, so a project importing the skin instead of core gets extra behaviour
for free through the same names. Two packages here are skins, both by
convention rather than by anything core enforces:

- `@rookery/timeline` overrides `idea`, adding its own dated arguments.
- `@rookery/todos` overrides `window`, hiding closed todos from a
  transclusion by default.

Both re-export everything else, from what they skin, untouched.

Three rules hold a skin together:

- **A skin imports its PARENT skin, not core, when one exists.**
  `@rookery/todos` imports `@rookery/timeline`, not `@rookery/core`
  directly, so an idea written through todos still takes timeline's dated
  arguments as well as todos' own. Importing core there instead would
  silently drop them.
- **A skin overrides a name by re-exporting its own binding of it**,
  forwarding everything it does not itself consume through `..args` — a
  caller of the skinned name should not be able to tell, from its own
  arguments, that a skin sits between it and core.
- **A skin must not change what the name it overrides means, only what it
  can additionally be told.** `@rookery/timeline`'s `idea` is still `#idea`
  — a note, not something else — and `@rookery/todos`' `window` is still
  `#window`; each accepts everything the parent already accepted, plus its
  own addition.

A package building a skin of its own follows the same three rules against
whichever package it sits on top of.

## Limitations

- **`window-unfurl` is a RECURSION budget, and it is finite.** It counts how many
  levels of transclusion are allowed before links take over:

  | value | what happens |
  | --- | --- |
  | `0` | no windowing anywhere — every `#window` is a link row |
  | `1` | a window renders its note once; a window inside that body is a link row |
  | `n` | `n` levels render, level `n+1` is a link row |

  `1` is the default, and `unfurl: n` on one call site overrides it there. A
  bottomed-out window is ONE rendering wherever it ran out: the note's title,
  linked to its page, in the same row shape a page backlink uses — a titleless
  note falls back to its `[idea:x]` permalink, having nothing else to be named
  by. What is permanent is that the budget is finite: that is what makes
  self-windows and window cycles safe to compile. See "Nested windows, and
  `window-unfurl`" above.
- An author's own `<label>` written inside a note's body is duplicated if
  that note is transcluded elsewhere — a note owns exactly one name, attached
  by `#idea` itself.
- Backlinks appear on minted note pages, so under rheo only — see "Standalone
  note pages".
- Typst's own `#footnote` inside an idea is a build error, not a page-level
  escape hatch. Nothing can intercept it (see "Footnotes"), so the alternative
  was letting it silently put a note's body somewhere the note has no block.
  A page-level footnote still works everywhere outside an idea.
- Citation numbering is document-wide under a numeric style, so a note's own
  page can show its only reference as `[7]`. CSL assigns those numbers and no
  Typst counter resets them; an author-date style, the default, has none.
- A window's citations resolve to the window's own reference block rather than
  to the note's page — see "Bibliographies" for why linking them across is not
  available.
- **`#idea`'s return value cannot be introspected.** It resolves a note's name
  and registers it from inside a `context` block, so what `#idea(..)[..]`
  returns is itself a deferred `context` node — and a Typst `context` node's
  body is opaque to `.fields()` until Typst actually realizes it, which
  reading an unplaced content value never does. Walking the return value for
  its `figure(kind: IK)` marker (the one `#idea` uses to register itself)
  therefore finds nothing, silently — no error, just an empty result. The
  note still renders and registers correctly once PLACED; only introspection
  of the unplaced value fails. `#window` has the same property, for the same
  reason (it also wraps its body in `context`). A package that needs to read
  a note's own options back off a content value cannot sniff it out of an
  `#idea`/`#window` call this way — it must instead emit its own PLAIN
  `#metadata` marker as a sibling of the call, or read the registry by name.
  `@rookery/slipshow`'s `src/marker.typ` is a worked example: `#slip` emits a
  second, plain marker beside the deferred `#idea` call specifically so
  `slip-meta` can read it back unplaced.

## Requirements

- typst >= 0.15.
- `--features html` on EVERY build, not just HTML/EPUB output. `#idea` calls
  `std.target()` unconditionally, which typst gates behind that feature
  regardless of output format — even a plain PDF build needs the flag, or it
  hard-errors.
- rheo >= 0.6.2 — but only if you build with rheo at all. The rheo-only half of
  the package (minted note pages, the hrefs that point into them, backlinks)
  needs three fixes stacked on top of each other: 0.6.0 rewrites the reserved
  `rheo-page:<handle>` link destination that this package emits for every
  idea link (an older rheo passes it through untouched, a silent site-wide
  dead link); 0.6.1 resolves the `@rookery` namespace via `[packages.<ns>]`;
  and 0.6.2 fixes package location for a package fetched from a remote ref,
  which the two prior releases fail to find at all. An older rheo does not
  complain: it mints nothing, and every `@idea:etal` then links at a page
  that was never written. Plain `typst compile` is unaffected — the standalone
  half has no floor beyond typst itself, see "Two modes".

## Build and local development

Pure Typst, no build step: `typst.toml`'s entrypoint points straight at
`src/lib.typ` (and `src/core.css`), so editing `src/` takes effect
immediately — no `dist/`, no copy step to forget to re-run.

```sh
# from this directory (core/0.1.0), only if @rookery/core does not already resolve
mkdir -p ~/.cache/typst/packages/rookery/core
ln -s "$PWD" ~/.cache/typst/packages/rookery/core/0.1.0
```

Only needed once, and only if it doesn't already resolve. Note the link path
ends in the VERSION and must not exist yet: `ln -sfn TARGET DIR` onto a `DIR`
that already exists as a directory drops a self-referential link *inside* it
instead of replacing it, so `rm -rf` a stale entry before relinking.

No package-specific devShell either: this repo's own root `flake.nix`/`.envrc`
already provide `just` and `typst`, and direnv finds them by walking up from
anywhere under this directory. `demo/pure/` has its own `just watch` for
live-rebuild; for the rheo side, `just watch` in the `rookery.ohrg.org` repo
picks up edits to `src/` on the next rebuild, since the whole of this repo is
symlinked into the package cache as the `rookery` namespace.
