// `#show: rookery` — the setup, its validation, and its theme resolution.
//
// Last, and importable by nothing here: it reads every other module, which is
// what a template does. A `#let` closure captures the scope visible at
// definition time, so this file existing at the end of the import order is what
// lets it see `hyperlink` for the `show ref:` rule.

#import "base.typ": *
#import "state.typ": *
#import "validate.typ": *
#import "theme.typ": *
#import "urls.typ": *
#import "permalink.typ": *
#import "bib.typ": *
#import "transclusion.typ": *
#import "hyperlink.typ": *
#import "links.typ": *
#import "idea.typ": *
#import "window.typ": *
#import "outline.typ": *
#import "data.typ": *

// Every `#show: rookery` argument, checked before anything is published.
#let _validate-config(
  prefix,
  idea-dir,
  css-prefix,
  window-unfurl,
  idea-page-template,
  theme,
  bibliography,
  hyperlink-target-minted,
  syndicate,
  index-page,
  display-context,
  display-backlinks,
  display-background,
  display-date,
  display-frame,
  display-name,
  display-label,
  display-tags,
  display-title,
  display-right-gutter,
  page-titles,
  footnotes,
  invisible-tags,
) = {
  assert(
    type(prefix) == str and prefix != "" and not prefix.contains(":"),
    message: "@rookery/core: `prefix` must be a non-empty string containing no `:` "
      + "(the `:` between prefix and name is added for you) — got "
      + repr(prefix),
  )
  // Rejects `/` and `:` because both corrupt what is built from this: a `/`
  // inserts extra directory levels into the minted path, and `:` is the
  // separator in the rheo handle `<dir>:<slug>` minted alongside it.
  assert(
    idea-dir == none
      or (
        type(idea-dir) == str
          and idea-dir != ""
          and not idea-dir.contains("/")
          and not idea-dir.contains(":")
      ),
    message: "@rookery/core: `idea-dir` must be `none` or a non-empty string containing "
      + "no `/` or `:` — got " + repr(idea-dir),
  )
  // A `css-prefix` becomes a CSS class stem (`<stem>-title`, `<stem>-tag-<t>`,
  // ...), so it is rejected on the same grounds a raw CSS selector would be —
  // no whitespace, no `.`, no `#`, no `:`.
  assert(
    css-prefix == none
      or (
        type(css-prefix) == str
          and css-prefix != ""
          and not css-prefix.contains(regex("\\s"))
          and not css-prefix.contains(".")
          and not css-prefix.contains("#")
          and not css-prefix.contains(":")
      ),
    message: "@rookery/core: `css-prefix` must be `none` or a non-empty string usable as "
      + "a CSS class stem — no whitespace, `.`, `#` or `:` — got " + repr(css-prefix),
  )
  assert(
    type(window-unfurl) == int and window-unfurl >= 0,
    message: "@rookery/core: `window-unfurl` must be a non-negative integer — `0` "
      + "renders every #window as a link to the note's page, `1` (the default) "
      + "renders a windowed note once, `n` unfurls n-1 nested levels — got "
      + repr(window-unfurl),
  )
  assert(
    idea-page-template == none or type(idea-page-template) == function,
    message: "@rookery/core: `idea-page-template` must be a function taking "
      + "`(id: str, note: dictionary, doc)` — got " + repr(idea-page-template),
  )
  assert(
    type(theme) == dictionary,
    message: "@rookery/core: `theme` must be a dictionary of "
      + _THEME-KEYS.keys().join(", ") + ", tags-color" + " — got " + repr(theme),
  )
  assert(
    bibliography == none or type(bibliography) == arguments,
    message: "@rookery/core: `bibliography` must be an `arguments` value carrying "
      + "Typst's own #bibliography arguments, e.g. "
      + "`arguments(bytes(read(\"refs.bib\")), style: \"chicago-author-date\")` — got "
      + repr(bibliography),
  )
  // A PATH CANNOT WORK HERE, so say so rather than failing later with a
  // "file not found" naming a directory inside the package. Typst resolves a
  // path relative to the file the call appears in, and every call this package
  // makes is inside the package — see the note on `_bib`.
  if bibliography != none {
    let src = bibliography.pos().at(0, default: none)
    let sources = if type(src) == array { src } else { (src,) }
    for s in sources {
      assert(
        type(s) == bytes,
        message: "@rookery/core: `bibliography` sources must be `bytes`, not a path — "
          + "write `bytes(read(\"refs.bib\"))` so the path resolves against YOUR "
          + "file rather than against the package. Got " + repr(s),
      )
    }
  }
  assert(
    type(hyperlink-target-minted) == bool,
    message: "@rookery/core: `hyperlink-target-minted` must be a boolean — "
      + "`true` for the note's minted page, `false` for its in-context "
      + "anchor. Got " + repr(hyperlink-target-minted),
  )
  assert(
    type(syndicate) == bool,
    message: "@rookery/core: `syndicate` must be a boolean — got " + repr(syndicate),
  )
  assert(
    type(index-page) == bool,
    message: "@rookery/core: `index-page` must be a boolean — got " + repr(index-page),
  )
  assert(
    type(display-context) == bool,
    message: "@rookery/core: `display-context` must be a boolean — got " + repr(display-context),
  )
  assert(
    type(display-backlinks) == bool,
    message: "@rookery/core: `display-backlinks` must be a boolean — got " + repr(display-backlinks),
  )
  assert(
    type(display-background) == bool,
    message: "@rookery/core: `display-background` must be a boolean — got " + repr(display-background),
  )
  assert(
    type(display-date) == bool,
    message: "@rookery/core: `display-date` must be a boolean — got " + repr(display-date),
  )
  assert(
    type(display-frame) == bool,
    message: "@rookery/core: `display-frame` must be a boolean — got " + repr(display-frame),
  )
  assert(
    type(display-name) == bool,
    message: "@rookery/core: `display-name` must be a boolean — got " + repr(display-name),
  )
  assert(
    type(display-label) == bool,
    message: "@rookery/core: `display-label` must be a boolean — got " + repr(display-label),
  )
  assert(
    type(display-tags) == bool,
    message: "@rookery/core: `display-tags` must be a boolean — got " + repr(display-tags),
  )
  assert(
    type(display-title) == bool,
    message: "@rookery/core: `display-title` must be a boolean — got " + repr(display-title),
  )
  // Tri-state, unlike every other `display-*` flag above: `auto` survives
  // resolution here on purpose (state.typ's `_display-right-gutter` banner),
  // so this is the only display assert accepting it alongside a boolean.
  assert(
    display-right-gutter == auto or type(display-right-gutter) == bool,
    message: "@rookery/core: `display-right-gutter` must be auto, true or "
      + "false — got " + repr(display-right-gutter),
  )
  assert(
    page-titles == "title" or page-titles == "path",
    message: "@rookery/core: `page-titles` must be \"title\" (rheo's own spine "
      + "title for a page) or \"path\" (its source path, content dir and extension "
      + "dropped) — got " + repr(page-titles),
  )
  assert(
    footnotes == "vertical" or footnotes == "horizontal",
    message: "@rookery/core: `footnotes` must be \"vertical\" (a Footnotes block "
      + "under each idea) or \"horizontal\" (margin notes beside the text) — got "
      + repr(footnotes),
  )
  // THROUGH `_assert-tags`, the same helper every other tag-shaped argument in
  // this package uses, so `invisible-tags: "private"` needs no array ceremony and
  // a wrong type reads the same way here as it does on `#idea`'s own `tags:`.
  _assert-tags(invisible-tags, "`invisible-tags`")
}

// Resolve a tags-color dictionary: each tag maps to either a colour/CSS-string
// (shorthand for background-only) or a dictionary with optional background/text keys.
// Returns a normalized dict with all colours converted to CSS hex strings.
#let _resolve-tags-color(tags-color) = {
  assert(
    type(tags-color) == dictionary,
    message: "@rookery/core: theme `tags-color` must be a dictionary — got "
      + repr(tags-color),
  )

  // Reusable colour converter: Typst color -> hex, string passthrough, else fail.
  let _css-color(key, value) = if type(value) == color {
    value.to-hex()
  } else if type(value) == str {
    value
  } else {
    panic(
      "@rookery/core: theme `tags-color` entry for \"" + key + "\" must be "
        + "a colour, a CSS colour string, or a dictionary with `background`/`text` keys — got "
        + repr(value),
    )
  }

  let resolved = (:)
  for (tag, value) in tags-color {
    // A THEMED TAG NAME IS A SELECTOR, which is why this is checked here and
    // not left to the free-form `tags:` array on `#idea`. A tag becomes the
    // class `idea-tag-<tag>` on the note, and a themed one ALSO becomes a
    // generated `.idea-tag-<tag>` rule (`_tags-color-rules`, theme.typ), so a
    // name carrying a space, a `.`, a `#`, a `:` or a leading digit either
    // breaks the stylesheet or matches the wrong elements. The sibling defect
    // one step upstream is already recorded in `_permalink-tab`
    // (permalink.typ): a tag with a space emits a broken two-class attribute,
    // `class="idea-tag idea-tag-my tag"`.
    //
    // REJECTED rather than escaped. Escaping an arbitrary name for a CSS
    // selector is a second, subtler spelling of every tag — the class attribute
    // would have to agree with it everywhere, including in a project's own
    // stylesheet, where the author writes the name by hand.
    //
    // An UNTHEMED tag is unconstrained, as before: this is about `tags-color`
    // KEYS, and a note may carry any string it likes as long as no colour is
    // asked for it by name.
    assert(
      tag.matches(regex("^[A-Za-z_][A-Za-z0-9_-]*$")).len() == 1,
      message: "@rookery/core: theme `tags-color` key \"" + tag + "\" is not usable "
        + "as a CSS class — a themed tag becomes the class `idea-tag-<tag>` and a "
        + "generated `.idea-tag-<tag>` rule, so it must start with a letter or an "
        + "underscore and carry only letters, digits, hyphens and underscores",
    )
    if type(value) == color or type(value) == str {
      // Shorthand: scalar colour/string -> background-only dict
      resolved.insert(tag, (background: _css-color(tag, value)))
    } else if type(value) == dictionary {
      // Dictionary form: validate and normalize
      let normalized = (:)
      for (key, val) in value {
        assert(
          key == "background" or key == "text",
          message: "@rookery/core: theme `tags-color` entry for \"" + tag + "\" has "
            + "unknown key `" + key + "` — valid keys are `background` and `text`",
        )
        normalized.insert(key, _css-color(tag + "." + key, val))
      }
      assert(
        normalized.len() > 0,
        message: "@rookery/core: theme `tags-color` entry for \"" + tag + "\" is an "
          + "empty dictionary — at least one of `background` or `text` must be present",
      )
      resolved.insert(tag, normalized)
    } else {
      panic(
        "@rookery/core: theme `tags-color` entry for \"" + tag + "\" must be "
          + "a colour, a CSS colour string, or a dictionary with `background`/`text` keys — got "
          + repr(value),
      )
    }
  }
  resolved
}

// The theme dictionary as CSS, from both the `theme:` dictionary and the
// granular arguments beside it.
//
// Returns the resolved dictionary rather than publishing it, so the state
// update stays in `rookery` with the seven others.
#let _resolve-theme(
  theme,
  link-color,
  fold-color,
  name-color,
  date-color,
  border-color,
  rule-width,
  pad,
  label-font,
  label-size,
  right-gutter,
) = {
  // One converter for both sources, so `theme: (link-color: c)` and
  // `link-color: c` cannot disagree about what a value may be.
  //
  // THREE KINDS OF VALUE, not two. Colours are the default and the majority;
  // `rule-width`/`pad`/`label-size` are LENGTHS; `label-font` is a FONT STACK,
  // which is neither — it is CSS text this package cannot validate and must
  // not mangle, so it is passed straight through. An array is accepted and
  // joined with `", "`, because a stack is what a font is and writing it as
  // `("Berkeley Mono", "monospace")` reads better than embedding the commas
  // in a string.
  //
  // The LENGTH branch: `repr` on a Typst length gives exactly the CSS it needs —
  // `2pt` -> "2pt", `0.15em` -> "0.15em" — so both spellings work and neither
  // needs a unit table here. A string passes through for the units Typst has no
  // literal for, `px` above all, which is what a hairline wants.
  let css(key, value) = if key == "right-gutter" {
    // A UNITLESS number, not a percentage: CSS's own `calc()` cannot mix `%`
    // and unitless factors the way the gutter's algebra needs (core.css), so
    // the ratio is divided down to a bare number here, once, rather than at
    // every rule that reads `--idea-right-gutter`.
    assert(
      type(value) == ratio and value > 0% and value < 100%,
      message: "@rookery/core: `right-gutter` must be a ratio between 0% and "
        + "100%, e.g. 40% — got " + repr(value),
    )
    str(value / 100%)
  } else if key == "label-font" {
    assert(
      type(value) == str or (type(value) == array and value.all(f => type(f) == str)),
      message: "@rookery/core: theme `label-font` must be a CSS font stack as a "
        + "string (\"Berkeley Mono, monospace\") or an array of family names "
        + "((\"Berkeley Mono\", \"monospace\")) — got " + repr(value),
    )
    if type(value) == array { value.join(", ") } else { value }
  } else if key in ("rule-width", "pad", "label-size") {
    // For `label-size` specifically, the STRING path is the primary one,
    // unlike `rule-width`/`pad` where a Typst length is more commonly used —
    // this key's whole point is staying in `rem` (see the readme), and Typst
    // has no `rem` literal, so `"0.8rem"` rather than a length is expected to
    // be the normal spelling here.
    assert(
      type(value) == length or type(value) == str,
      message: "@rookery/core: theme `" + key + "` must be a length (2pt, 0.15em) "
        + "or a CSS length string (\"3px\") — got " + repr(value),
    )
    if type(value) == length { repr(value) } else { value }
  } else {
    assert(
      type(value) == color or type(value) == str,
      message: "@rookery/core: theme `" + key + "` must be a colour or a CSS "
        + "colour string — got " + repr(value),
    )
    if type(value) == color { value.to-hex() } else { value }
  }

  let resolved = (:)
  for (key, value) in theme {
    assert(
      key in _THEME-KEYS or key == "tags-color",
      message: "@rookery/core: unknown theme key `" + key + "` — valid keys are "
        + _THEME-KEYS.keys().join(", ") + ", tags-color",
    )
    if key == "tags-color" {
      if value != none { resolved.insert("tags-color", _resolve-tags-color(value)) }
    } else if value != none {
      resolved.insert(key, css(key, value))
    }
  }
  // Granular arguments last: they override whatever `theme:` set.
  for (key, value) in (
    link-color: link-color,
    fold-color: fold-color,
    name-color: name-color,
    date-color: date-color,
    border-color: border-color,
    rule-width: rule-width,
    pad: pad,
    label-font: label-font,
    label-size: label-size,
    right-gutter: right-gutter,
  ) {
    if value != none { resolved.insert(key, css(key, value)) }
  }
  resolved
}

//   #import "@rookery/core:0.1.1": rookery, idea, window
//   #show: rookery.with(
//     prefix: "note",
//     theme: (link-color: rgb("#ffe08a"), fold-color: rgb("#fffbe8")),
//   )
//
// Does exactly five things, and deliberately nothing else:
//
//   1. publishes `prefix` (so `#idea("etal")` mints `<note:etal>`), `idea-dir`
//      (where `.marrow.typ` mints that note's own page; `none`, the default,
//      resolves through `_dir()` in state.typ) and `css-prefix` (the class
//      stem every emitted element wears; `none`, the default, falls back to
//      `prefix` through `_cls()` in state.typ);
//   2. publishes `window-unfurl`, the document-wide transclusion budget (see
//      `_window-depth` for the whole scale; `1`, the default, renders a
//      windowed note once and collapses a `#window` nested inside it to its
//      permalink, which is the behaviour every existing document already has,
//      while `0` transcludes nothing and renders every `#window` as a link to
//      the note's page). A `#window(..., unfurl: n)` overrides it per call
//      site;
//   3. publishes `idea-page-template`, the project's own chrome for the
//      standalone pages `.marrow.typ` mints (see `_idea-page-template`;
//      `none`, the default, mints them bare as before);
//   4. publishes the theme — every colour the package will set for you;
//   5. installs `show ref: hyperlink` (carrying `hyperlink-target-minted:`
//      through to it, see below), so `@note:etal` renders the note rather
//      than a bare figure number.
//
// It does NOT transform the document. It sets no page/text/heading style,
// wraps `doc` in no container, and emits nothing of its own — `#show:
// rookery` on a document with no notes in it is a no-op. The blast radius is
// exactly one element type: `ref`. Even there the installed rule passes every
// reference that is NOT a rookery note straight through untouched (its `else
// { it }` branch — see `#hyperlink` above), so an ordinary `@fig:x` in the
// same document is unaffected.
//
// WHY NOT NARROWER — i.e. a rule scoped to `#idea` alone. The prefix cannot
// ride on a show rule over idea markers, because `#window` and `.marrow.typ`
// need the same value and neither is inside an idea. It has to be state (see
// `_prefix` at the top of this file), and a plain function CANNOT install the
// `ref` rule: a `show` inside a function body scopes to the content that body
// returns, not to the document that later inserts it. Hence a template — kept
// as thin as a template can be.
//
// THEME. `theme:` takes the whole set at once; the granular parameters named
// after each key take one at a time and WIN over `theme`, so the two compose:
//
//   #show: rookery.with(theme: DARK, link-color: rgb("#ff0"))
//
// reads as "the dark theme, but that one colour". Precedence, least specific
// first: `core.css`'s own default -> `theme:` -> the granular parameter.
// Anything left unset at every level stays a CSS default and is not emitted.
//
// Each value is a Typst colour or a raw CSS string. A colour is converted with
// `.to-hex()` HERE, once, rather than at every element: this is the only place
// that knows the value is destined for CSS. A string passes through untouched,
// which is what makes `rgba(…)`, `var(--accent)`, `transparent` and any other
// CSS-valid value available — Typst's colour type cannot express those.
//
// An unknown `theme:` key is an ERROR naming the valid ones, rather than a
// silently ignored typo: a misspelled colour that just does not apply is
// exactly the kind of thing an author would chase through their own
// stylesheet first.
//
// `refs: false` opts out of (3) alone, for an author who wants stock `@`
// behaviour or their own `show ref` rule. The `show` sits INSIDE the branch,
// wrapping `doc` there: a `show` in an `if` block's body scopes to that block,
// so hoisting it out of the branch would scope it to nothing at all.
//
// `hyperlink-target-minted` is `#hyperlink`'s own parameter of that name,
// handed straight to the installed rule: `true` (the default) sends every
// `@idea:etal` in the document to the note's minted page, `false` to its
// in-context anchor, where the note was hatched. Only meaningful alongside
// `refs: true`; ignored (with no error) when `refs: false`, since there is
// then no installed rule for it to configure — an author who set `refs:
// false` already opted into supplying their own `show ref` rule, whichever
// target it picks.
//
// `footnotes:` picks how `#footnote` bodies render: "vertical" (the default)
// lists them in a Footnotes block under each idea; "horizontal" sets each
// one in the right margin, beside the line its marker sits on. Only the HTML
// target sees the difference — paged and epub always render the vertical
// block. A PROJECT-WIDE choice like `page-titles` above, read with
// `.final()`, so the last vertebra to apply the template settles it for
// every idea and window, marrow's minted pages included. Under "horizontal"
// a card holding a margin note splits into a text column and a right gutter
// the notes float into — see `display-right-gutter:` and `right-gutter:`
// below for the split and its width.
//
// "horizontal" also moves citations to the margin: each `@key`/`#cite`
// marker keeps its normal inline form, and beside it a margin note carries
// the full reference. The idea's References block is still emitted (a
// citation with nothing to claim it is a Typst error) but hidden, since the
// margin notes already show what it would have listed.
//
// `display-right-gutter:` is the document-wide default for the per-idea
// `display-right-gutter` flag (`#idea`, idea.typ): `auto` (the default)
// splits a card only when it holds a margin note; `true` splits every
// top-level card regardless; `false` never splits, and that idea's
// footnotes and citations fall back to the vertical blocks even under
// "horizontal". `right-gutter:` sets the split's width as a fraction of the
// card, e.g. `right-gutter: 40%` — `theme.typ`'s `--idea-right-gutter`.
//
// `#gutter` (gutter.typ) places a block of its own at the top of that same
// gutter — a contents panel before the ideas, an aside inside one idea's own
// body — and pushes the notes that follow it down rather than under it.
// `sticky: true` pins it to the viewport while the page scrolls past. A
// page-level `#gutter` only reads correctly beside cards that split, so a
// page using one should set `display-right-gutter: true` above.
//
// Defined last in this file because a `#let` closure captures the scope
// visible AT DEFINITION time — `hyperlink` must already exist.
#let rookery(
  prefix: "idea",
  idea-dir: none,
  css-prefix: none,
  window-unfurl: 1,
  idea-page-template: none,
  bibliography: none,
  theme: (:),
  link-color: none,
  fold-color: none,
  name-color: none,
  date-color: none,
  border-color: none,
  rule-width: none,
  pad: none,
  label-font: none,
  label-size: none,
  right-gutter: none,
  refs: true,
  hyperlink-target-minted: true,
  syndicate: false,
  index-page: true,
  display: (:),
  display-context: auto,
  display-backlinks: auto,
  display-background: auto,
  display-date: auto,
  display-frame: auto,
  display-name: auto,
  display-label: auto,
  display-tags: auto,
  display-title: auto,
  display-right-gutter: auto,
  page-titles: "title",
  footnotes: "vertical",
  invisible-tags: (),
  doc,
) = {
  // `rookery(..)` accepts all ten `_DISPLAY-KEYS` now — every one of them
  // has a document-wide tier, resolved below and published to its own state
  // (state.typ), and read back at the point a card, a window or a minted
  // page renders.
  for key in display.keys() {
    if key not in _DISPLAY-KEYS {
      panic(
        "@rookery/core: #rookery's `display` dictionary has an unknown key "
          + repr(key) + " — valid keys are " + repr(_DISPLAY-KEYS),
      )
    }
  }
  let display = _resolve-display(
    display,
    (
      "context": display-context, backlinks: display-backlinks, background: display-background,
      date: display-date, frame: display-frame, name: display-name, label: display-label,
      tags: display-tags, title: display-title, "right-gutter": display-right-gutter,
    ),
    "#rookery's",
  )
  // The document-wide tier is the bottom of the stack, so here `auto` IS
  // resolved to a boolean — unlike in `#idea`/`#window`, nothing further
  // down reads `auto` as "defer to something else". Each default matches the
  // built-in `#idea`/`#window` always applied — see `_display-background`
  // and its siblings, state.typ, for why only `date` and `tags` start off.
  //
  // `right-gutter` is the one key left OUT of this collapse: its `auto` is a
  // real, per-idea outcome — "split only when the card holds a note" — not a
  // placeholder for a built-in default, so the document-wide tier passes it
  // through unresolved (state.typ's `_display-right-gutter` banner).
  let display = display + (
    "context": if display.context == auto { true } else { display.context },
    backlinks: if display.backlinks == auto { true } else { display.backlinks },
    background: if display.background == auto { true } else { display.background },
    date: if display.date == auto { false } else { display.date },
    frame: if display.frame == auto { true } else { display.frame },
    name: if display.name == auto { true } else { display.name },
    label: if display.label == auto { true } else { display.label },
    tags: if display.tags == auto { false } else { display.tags },
    title: if display.title == auto { true } else { display.title },
  )
  _validate-config(
    prefix,
    idea-dir,
    css-prefix,
    window-unfurl,
    idea-page-template,
    theme,
    bibliography,
    hyperlink-target-minted,
    syndicate,
    index-page,
    display.context,
    display.backlinks,
    display.background,
    display.date,
    display.frame,
    display.name,
    display.label,
    display.tags,
    display.title,
    display.at("right-gutter"),
    page-titles,
    footnotes,
    invisible-tags,
  )
  let resolved = _resolve-theme(
    theme,
    link-color,
    fold-color,
    name-color,
    date-color,
    border-color,
    rule-width,
    pad,
    label-font,
    label-size,
    right-gutter,
  )


  _prefix.update(prefix)
  _idea-dir.update(idea-dir)
  _css-prefix.update(css-prefix)
  _window-depth.update(window-unfurl)
  // Default the style to author-date, and ONLY when the author passed none.
  //
  // WHY: citation numbering is document-wide and cannot be reset. `counter(
  // bibliography).update(0)` does nothing — CSL assigns the numbers, not a
  // Typst counter — so under a numeric style the third idea on a page reads
  // `[3]` and a standalone page can show its only reference as `[7]`. MEASURED.
  // An author-date style has no numbers and the problem does not arise. A
  // numeric style is still honoured without complaint: this is a default, not
  // a restriction.
  //
  // `_ => v`, never a bare value that happens to be callable — see
  // `_idea-page-template` for why `state.update` needs the wrapper.
  let bib-args = if bibliography == none { none } else {
    let named = bibliography.named()
    if "style" not in named { named.insert("style", "chicago-author-date") }
    arguments(..bibliography.pos(), ..named)
  }
  _bib.update(_ => bib-args)
  // Parsed ONCE for the document. `_own-cited-keys` runs per note, per window
  // and per page, and the answer cannot change during a build.
  _bib-key-cache.update(_bib-keys-of(bib-args))
  // `_ => f`, not `f` — see `_idea-page-template`.
  _idea-page-template.update(_ => idea-page-template)
  _syndicate.update(syndicate)
  _index-page.update(index-page)
  _display-context.update(display.context)
  _display-backlinks.update(display.backlinks)
  _display-background.update(display.background)
  _display-date.update(display.date)
  _display-frame.update(display.frame)
  _display-name.update(display.name)
  _display-label.update(display.label)
  _display-tags.update(display.tags)
  _display-title.update(display.title)
  _display-right-gutter.update(display.at("right-gutter"))
  _page-titles.update(page-titles)
  _footnote-mode.update(footnotes)
  // Normalized to a flat array of NAMES here, once, so `_visible-tags` can do a
  // plain `t not in hidden` on every call rather than re-deriving the shape.
  // `.update(value)` and never `.update(_ => value)` — an array is not a
  // function, so the wrapper `_idea-page-template` needs would store a closure
  // (see `_syndicate`, state.typ).
  _invisible-tags.update(_norm-tags(invisible-tags).keys())
  _theme.update(resolved)
  // DOCUMENT-SCOPE theme publication, ADDITIVE to the per-container INLINE
  // styling `_themed` applies everywhere it is used (see that function and
  // its callers) — this does not replace them, it gives
  // anything ELSE on the page a `:root` to inherit from. Custom properties
  // inherit DOWN the DOM, but only from an ancestor that carries them, which
  // is why a document-scope `:root` block is emitted in addition to the
  // per-container inline styles: a sibling element with no rookery ancestor (a
  // `<dialog>` in a site's own header, a search bar not nested inside a note)
  // would otherwise see nothing.
  //
  // EXACTLY ONCE PER OUTPUT PAGE: `#show: rookery` is applied PER FILE, and
  // under rheo one FILE is one VERTEBRA is one OUTPUT PAGE (the same fact
  // `_prefix`/`_bib`/`_theme` above are already document-wide state for) —
  // so one call to this function is one page, and this line runs exactly
  // once per call. `demo/rheo/content/lib.typ` is the shape every multi-page
  // project already uses: ONE shared `#show: rookery.with(..)` wrapper that
  // EVERY vertebra applies, so every page gets its own `<style>`, all of them
  // carrying the same document-wide `.final()` theme. A minted note page
  // (`.marrow.typ`) is a separate `#document` that never calls `rookery()`
  // again, so it is untouched by this — same as it always was.
  //
  // Reuses `_theme-style()` rather than re-deriving anything: it already
  // returns `none` for an unconfigured theme, so an unthemed project's
  // `<style>` count stays exactly zero, matching the promise inline theming
  // already keeps ("an unconfigured document emits nothing extra at all").
  //
  // TWO BLOCKS, ONE `<style>`. The `:root` block carries the document-wide
  // theme; the second is the per-tag `@layer rookery-tags` block that delivers
  // `theme: (tags-color: ..)` as generated `.idea-tag-<tag>` rules
  // (`_tags-color-rules`, theme.typ — read its banner for why a rule and why the
  // layer). They are independent: a project may configure either, both or
  // neither, and the element is emitted only when at least one has something to
  // say, so the zero-`<style>` promise above still holds for an unthemed
  // document.
  //
  // GATED to html/epub, exactly like every other `html.elem` call in this
  // file: `html.elem` renders nothing meaningful on the paged (PDF) target,
  // and unconditionally calling it there is what `demo/pure`'s two PDF roots
  // exist to catch.
  context {
    if _target() == "html" or _target() == "epub" {
      let root = _theme-style()
      let tags = _tags-color-rules()
      if root != none or tags != none {
        html.elem(
          "style",
          (if root != none { ":root { " + root + "; }" } else { "" })
            + (if tags != none { tags } else { "" }),
        )
      }
    }
  }
  // THE PAGE-LEVEL LINK BEACON, one per vertebra: which notes THIS page links to
  // in its own prose, for the page half of a minted page's backlink list. Read
  // `_page-links`'s banner in outline.typ for why this is beaconed rather than
  // swept out of the document with `query`.
  //
  // HERE, in the template, because this is the only place holding the whole page:
  // `doc` is the vertebra's entire content, and "what does this page link to
  // outside any note" is answerable from that content tree alone, with no
  // introspection. The same asymmetry the trailing-citations block below relies
  // on, for the same reason — an idea never sees the prose around it.
  //
  // EXACTLY ONCE PER OUTPUT PAGE, on the same grounds as the `<style>` block
  // above: `#show: rookery` is applied per FILE, and under rheo one file is one
  // vertebra is one output page. A minted note page never calls `rookery()` again
  // — it applies the project's `idea-page-template` — so it publishes no beacon,
  // and that is what keeps `query(<rookery-page-links>)` a selector marrow's own
  // output cannot grow.
  //
  // Not gated on target: the beacon renders nothing anywhere, and the paged build
  // answers the same question about the same page.
  context _page-links-beacon(doc)
  // Two notes sharing a name, checked here rather than left to `.marrow.typ`,
  // because a project with no marrow (no rheo at all) never reaches that
  // file. Guarded on `_rheo-ctx()`: under rheo `.marrow.typ` already runs
  // this once at bundle root, and `#show: rookery` applies once per
  // vertebra, so an unguarded call here would run it once per page instead.
  //
  // Rendered inline, on this vertebra's own page: an ordinary page (unlike
  // rheo's bundle root) always allows visible content, so a warning for a
  // pair of identical notes shows up right where they were written.
  if _rheo-ctx() == none {
    context { for w in _assert-unique-names() { _dup-warning-content(w) } }
  }
  // The fallback for a rookery `#footnote` written OUTSIDE any idea: page-wide
  // numbering and a body in the page's own endnote section, exactly as Typst's
  // own footnote behaves. `#idea` installs a nested rule that wins over this
  // one inside a note — MEASURED.
  //
  // Installed unconditionally: `refs: false` is about the `show ref:` rule
  // only, and a document that opted out of reference rendering has not thereby
  // opted out of footnotes.
  show FNK: it => std.footnote(it.value.rookery-fn)
  if refs {
    show ref: hyperlink.with(hyperlink-target-minted: hyperlink-target-minted)
    doc
  } else {
    doc
  }
  // TRAILING PROSE CITATIONS. A citation in page prose before an idea is
  // claimed by that idea's sweep block, but one written after the LAST idea or
  // window on the page has nothing following it — and a citation no
  // bibliography claims is a hard error (`label <key> does not exist in the
  // document`), so this is required for the page to build at all, not polish.
  //
  // `_own-cited-keys(doc)` is exactly the right question here, and it is the
  // same one an idea asks about its own body: every `#idea` and `#window` on
  // the page is a claimant, so what survives the last of them is precisely the
  // trailing prose. Both always render at page level, hence the default
  // `windows-claim: true`.
  //
  // The template CAN ask this where `#idea` cannot: it receives the whole page
  // as `doc`, whereas an idea never sees the prose around it. That asymmetry is
  // why the sweep block before each idea has to be unconditional while this one
  // does not.
  //
  // Emitted only when something is actually left, so `#show: rookery` keeps its
  // promise to emit nothing of its own on a page with no notes — and on any
  // page with no configured bibliography, since `_own-cited-keys` is then empty.
  context {
    let own = _own-cited-keys(doc)
    if own.len() > 0 {
      if _target() == "html" or _target() == "epub" {
        html.elem("div", attrs: (data-rookery: "page-refs", class: _c("page-refs")), _bib-call([References]))
      } else {
        _bib-call([References])
      }
    }
  }
}
