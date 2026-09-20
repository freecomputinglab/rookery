// `#idea` itself, the two tag-sugar wrappers over it, and `#footnote`.
//
// `#idea` is the package: everything else either feeds it (state, urls, the
// permalink) or reads what it registered (windows, the outline, `#ideas`).
// `#footnote` lives here because a footnote belongs to the idea it was written
// in — the same rule the citation walk in `bib.typ` enforces.

#import "base.typ": *
#import "state.typ": *
#import "theme.typ": *
#import "urls.typ": *
#import "permalink.typ": *
#import "bib.typ": *
#import "transclusion.typ": *
#import "hyperlink.typ": *
#import "links.typ": *

// ---- #idea — the note itself: validation, registration, rendering ---------
//
// `#idea[body]`, `#idea("name")[body]`, and `#idea(<name>)[body]` all work via
// an argument sink, since `#idea[body]` passes body as the first positional
// argument. A named note is pinned to that name outright. An unnamed note
// mints the slug of its own title, or, titleless, a slug of its own body
// with a short content digest appended — see the resolution order in the
// mint below. Either way the note gets: an `idea:<id>` Typst label on
// a hidden referenceable anchor, an HTML heading (only when `title` is given),
// and a registry entry carrying its raw body for `#window` to transclude later.
//
// Defined after `_outbound` above because it calls it at registration time, and
// a `#let` closure captures the scope visible AT DEFINITION time.

// `display-frame: false` DROPS THE CARD'S BOX — its left rule and the indent
// that goes with it — and nothing else: the note still registers, still
// carries its tags and its anchor, still renders its hat and its body. It is
// a per-note switch, where `rule-width`/`border-color`/`pad` in the theme move
// the frame for the whole document. The mechanism is a second attribute,
// `data-rookery-bare`, and a more-specific rule in `core.css`; see the comment
// on `data-rookery-plain` there for why a downstream stylesheet cannot do this
// from outside the package.
//
// `display-id: false` DROPS THE PERMALINK from the hat. With `display-tags`
// and `display-date` both already off by default, that leaves the tab empty
// and the hat disappears entirely — see `_permalink-tab` (permalink.typ) for
// how. The cost falls on an UNTITLED note, whose id is a bare counter value a
// permalink is the only way to discover; a titled note's id is the slug of
// its own title, so it stays guessable without one.
//
// `display:` and the nine `display-*` flags are resolved together by
// `_resolve-display` (pure.typ) into one dictionary: an explicit flag wins
// over the dictionary's own value for that key, which wins over `auto`. Every
// flag defaults to `auto`, and every one of the nine STAYS `auto` here when
// unset — none of them gets a built-in default substituted in this function
// any more. `context`, `backlinks` and `title` mean "use the document-wide
// setting", resolved later on the minted page; `date`, `tags`, `frame` and
// `id` mean the same thing one step earlier, resolved against document-wide
// state (`_display-final`, state.typ) at the point this note's own card
// renders, further down. `label` and `background` are accepted here too but
// unused by the card itself — they seed what a later `#window` falls back to
// when it does not override them.

// The string a titleless, untitled note's id is digested from. CAPS the
// hashed string: cost is linear in body size, measured at roughly 1.5 MB/s,
// so one very long body would otherwise be paid for on every note. The true
// length rides along so two bodies sharing a 4096-byte prefix still differ.
#let _digest-input(o) = {
  let r = repr(o)
  (if r.len() > 4096 { r.slice(0, 4096) } else { r }) + "#" + str(r.len())
}

#let idea(level: 1, title: none, tags: (), tag: none, base-tags: none, exclude-tags: (), created: none, display: (:), display-date: auto, display-tags: auto, display-frame: auto, display-id: auto, display-label: auto, display-background: auto, display-context: auto, display-backlinks: auto, display-title: auto, ..args) = {
  // Same leniency as `#window`/`#ideas-outline`/`#ideas`: a single tag needs
  // no array ceremony. Without this, a bare string reached `v.tags.map(...)`
  // below and further down at render time — str has no `.map`, so the error
  // surfaced as an opaque method-not-found far from the actual mistake.
  //
  // The normalized shape is a DICTIONARY: keys are tag names, values are
  // arbitrary Typst values, and a plain tag's value is `none`. `_norm-tags`
  // maps all four accepted forms onto it, so everything below reads `.keys()`
  // for the names and touches values only where it means to.
  // THREE WAYS TO PUT TAGS ON A NOTE, lowest to highest precedence: `tag:`
  // and `base-tags:` are a CONSTRUCTOR's, merged rather than replaced, so
  // `idea.with(tag: "note")` keeps its tag when a call site names `tags:` of
  // its own — `tags:` is the CALL SITE's, and it replaces outright.
  //
  // `base-tags:` takes several tags at once, for a family that is a narrowing
  // of a broader one rather than a thing of its own —
  // `idea.with(base-tags: ("person", "participant"))` — so every note the
  // constructor mints is reachable as `person` too, which is what a
  // `#window(tagged: "person")` or a `tag-index("person")` has to see for the
  // narrower family to belong to the wider one at all.
  //
  // A caller's own value for a tag WINS OUTRIGHT over a constructor's default —
  // `#todo("x", tags: (todo: (state: "open")))` keeps `(state: "open")` even
  // though the `todo` constructor bound its own default for that key — and
  // there is no deep merge between the two.
  _assert-tags(tags, "#idea's")
  _assert-tags(base-tags, "#idea's", what: "base-tags")
  assert(
    tag == none or type(tag) == str,
    message: "@rookery/core: #idea's `tag` must be a single tag name as a "
      + "string — pass several as `base-tags: (\"a\", \"b\")` — got "
      + repr(tag),
  )
  let display = _resolve-display(
    display,
    (
      "context": display-context, backlinks: display-backlinks, background: display-background,
      date: display-date, frame: display-frame, id: display-id, label: display-label,
      tags: display-tags, title: display-title,
    ),
    "#idea's",
  )
  let tags = _merge-base-tags(tag, _merge-base-tags(base-tags, tags))
  let pos = args.pos()
  // An argument sink accepts every named argument silently, so a misspelled
  // `display-*` flag would do nothing and report nothing — see `#hyperlink`
  // for the same check. Every named argument #idea honours is now a declared
  // parameter, so anything arriving through the sink is unknown.
  let unknown = args.named().keys()
  assert(
    unknown.len() == 0,
    message: "@rookery/core: #idea got unknown named argument(s) " + repr(unknown)
      + " — every argument #idea honours is a declared one; the display flags "
      + "are display-background, display-backlinks, display-context, "
      + "display-date, display-frame, display-id, display-label, display-tags "
      + "and display-title.",
  )
  // Variadic, not a plain positional: a positional parameter cannot carry a
  // default in Typst, and `#idea[body]` has to be callable with no name at
  // all. The same sink is also what lets the body itself be absent —
  // `#idea(title: [T])` arrives here with zero positionals. `#window` and
  // `#hyperlink` take the same shape for the same reason.
  assert(
    pos.len() <= 2,
    message: "@rookery/core: #idea takes an optional name and an optional "
      + "body — #idea(<x>, title: [T])[body], not #idea(<x>, [T])[body]. "
      + "A title is a named argument; a third positional is silently the "
      + "one that gets dropped — got "
      + str(pos.len()) + " positional arguments.",
  )
  let (name, body) = if pos.len() == 0 {
    (none, [])
  } else if pos.len() == 1 {
    (none, pos.at(0))
  } else {
    (pos.at(0), pos.at(1))
  }
  let named = name != none
  let base = if named { _norm(name) } else { none }

  // THE EXCLUSION GATE sits ABOVE the `figure(kind: IK)` below rather than
  // beside it. A note carrying an excluded tag is not hidden, it is ABSENT: no
  // figure, no metadata, no registry entry, no Typst label, no minted page, no
  // `ideas()` row, no search-index entry, no feeds beacon, no outline entry, no
  // backlink. FIVE things walk for that marker STRUCTURALLY, before
  // realization — `_flatten`'s IK rule (transclusion.typ), `_outbound`
  // (links.typ), `_std-footnotes` and `_footnotes` (pure.typ), and
  // `_ideas-outline-data`'s `query()` (outline.typ) — so the marker must never
  // exist rather than exist and be suppressed, which is why the decision reads
  // no `#context`: `_resolve-excluded` (base.typ) takes `sys.inputs` and a
  // plain argument instead of a state.
  //
  // TAG KEYS, so a VALUED tag excludes exactly as a plain one does — a tag
  // carrying metadata is no less a tag, the same rule `cls` below follows.
  let excluded = _resolve-excluded(exclude-tags)
  if tags.keys().any(t => t in excluded) {
    return {
      if named {
        // THE ID GOES ON `_excluded-ids`, named notes only — an unnamed note
        // has no id anything could link to by name. That state is what lets
        // `#window`/`#hyperlink`/`#idea-body` tell "deliberately excluded from
        // this build" from "typo" and degrade instead of panicking, and it
        // holds STRINGS only: no body, title or tags to flatten or serialize.
        context {
          // Built HERE rather than inside the `update` closure below: an
          // updater closure runs LAZILY, at `.final()` time, where context is
          // unknown, so a `_pfx()` call inside it fails with "can only be used
          // when context is known" the moment any reader resolves this state.
          let id = _pfx() + base
          _excluded-ids.update(r => if id in r { r } else { r + (id,) })
        }
      }
    }
  }

  // ---- TITLE vs LABEL, and the distinction is the whole point ---------------
  //
  // A note travels under two names:
  //
  //   `title`  the AUTHORED title, `none` when the author gave none. This is what
  //            gets PRINTED AS A HEADING above the note's own body — its card, its
  //            minted page's `<h1>`, a transcluded card's heading.
  //
  //   `label`  what to CALL this note somewhere else: a browser tab, an
  //            `ideas/index.html` row, an `#ideas-outline` entry, a feed item, the
  //            text of a link to it. Authored title flattened to plain text, else
  //            the first 60 characters of the body (`_derived-title`, pure.typ),
  //            else `none`.
  //
  // WHY THEY CANNOT BE ONE VALUE: an AUTHORED title differs from the body, so
  // printing it adds information; a DERIVED one IS the body, so printing it as a
  // heading too puts the same text on the card twice. A derived name is only
  // ever useful where the body is absent.
  //
  // A STRING, never content, so a consumer can put it in an attribute, a
  // `lower(..)`, a sort key or a JSON index without asking what shape it is.
  //
  // Resolved out here — above the figure, outside every `#context` — so one value
  // reaches BOTH channels a note's names travel by: the `#metadata` payload just
  // below (read by `_flatten`'s IK rule and by `#ideas-outline`) and the registry
  // record in the context block further down. It can live here because
  // `_derived-title` and `_plain` are PURE: no state, no context, no query.
  // NOT NAMED `label`, and this is a hard trap rather than a style choice: a local
  // `let label = ..` SHADOWS Typst's built-in `label()` function for the rest of
  // this function, and `#label(id)` further down (the note's referenceable anchor)
  // then fails with `expected function, found string`. MEASURED: it broke every
  // cross-page `@idea:x` and `#link(label("idea:x"))` in the demo at once, with an
  // error pointing at the anchor rather than at the shadowing binding. The RECORD
  // FIELD is still called `label` — that is the public name — but the local is not.
  let note-label = if title != none { _plain(title) } else { _derived-title(body) }

  // The marker wraps the whole idea. Its body carries the RAW body as
  // metadata so a later _flatten can render a nested idea's content without
  // re-registering it. The figure sits inside a `context` block so the id
  // can be resolved ONCE, above the metadata payload, and reused by the
  // registry update further down rather than recomputed.
  //
  // A consequence for callers: this makes `#idea`'s own return value a
  // deferred `context` node, opaque to `.fields()` until Typst realizes it —
  // so a caller cannot walk an unplaced `#idea` value for the IK marker (see
  // `slipshow/0.1.0/src/marker.typ` for a package that hit this and worked
  // around it with a sibling marker).
  context {
    // Resolution order: a NAMED note keeps its pinned id unconditionally —
    // a pin is a promise about the id and must never be silently moved. An
    // unnamed note with a title mints the slug of that title, with NO probe
    // of any kind — a pure function of the title, so it reproduces
    // identically at every re-render (a `#window`, a minted page, a nested
    // transclusion re-placing this note's stored body elsewhere). An unnamed
    // note with no title, or one whose title cannot name a note (`_id-slug`
    // returns `none`), mints a slug of its own BODY instead (`_name-slug`,
    // pure.typ), with a three-character digest of the note's own occupant
    // tuple appended (`_h3`, pure.typ) so two notes whose bodies open the
    // same way still land on different ids. Both the slug and the digest are
    // pure functions of values already fixed by this call site, so this
    // reproduces too, unlike a document position or a probe of ids taken so
    // far, either of which mints a fresh value at every new place a stored
    // body lands. A note with no name, no title, and a body that yields no
    // readable text panics outright — there is nothing left to derive an id
    // from.
    //
    // A collision has two shapes now, told apart by whether either side is
    // PINNED. Two titles slugging the same no longer panics: the second,
    // third, ... note to derive one slug gets a numeric `-<n>` suffix,
    // counted in document order, from `_slug-peek`/`_slug-record`
    // (state.typ) just below. That suffix IS position-dependent — inserting
    // a new colliding note earlier shifts every later `-<n>` down by one —
    // which is exactly what this comment used to say made a suffix
    // unusable. It is used anyway now: a build that panics is worse than a
    // URL that occasionally moves, and `#idea(<name>, ..)` is how an author
    // opts a note out of ever moving.
    //
    // Everything else still panics below, unchanged: two notes pinned to the
    // same name, or a derived id — a title slug (suffixed or not), or a body
    // slug and digest — landing on an already-pinned one. A pinned id is a
    // promise about the id and must never be silently moved.
    let slug = if not named and title != none { _id-slug(_plain(title)) } else { none }
    // WHAT MAKES THIS NOTE THE NOTE IT IS, for `_slug-peek`/`_slug-record`
    // (state.typ) to recognise a replay of it as itself rather than as a new
    // colliding note, and for `_digest-input` (above) to digest below. Built
    // ONLY from values already fixed by this call site — the authored
    // title, the raw body, the normalized tags, the heading level, the
    // resolved display flags — never from `id`, `slug-n`, or anything else
    // that depends on WHERE or WHEN this rendering is happening, since any
    // of those would reintroduce exactly the render-position dependence
    // this is meant to remove. `body` is the raw argument, not
    // `_flatten(body, ..)`: two calls of THIS SAME site always pass the
    // identical value, whether laid out at its own position, inside a
    // `#window`, or on this note's minted page — see state.typ's banner for
    // why that is what makes a replay recognisable at all.
    let occupant = (title: title, body: body, tags: tags, level: level, display: display)
    // `none` unless this note actually needs a body-derived id — a pure
    // function of `occupant`, so it reproduces identically at every replay.
    // `_plain` returns `none`, not `""`, for genuinely empty content (an
    // empty `[]` has no children to fall back on, unlike a lone space) —
    // guarded here since `_name-slug` expects a string.
    let plain-body = _plain(body)
    let body-slug = if not named and slug == none {
      _name-slug(if plain-body == none { "" } else { plain-body })
    } else { none }
    // `none` unless this note actually needs a slug suffix — same reason:
    // computed here as plain data, recorded below only once `id` no longer
    // needs to share a value with that write.
    let slug-n = if slug != none { _slug-peek(slug, occupant) } else { none }
    let id = if named {
      _pfx() + base
    } else if slug != none {
      _pfx() + slug + (if slug-n > 1 { "-" + str(slug-n) } else { "" })
    } else if body-slug != none {
      _pfx() + body-slug + "-" + _h3(_digest-input(occupant))
    } else {
      panic(
        "@rookery/core: this note has no name, no title, and a body that yields no "
          + "readable text, so no id can be derived for it. Give it a name — "
          + "`#idea(<some-name>, ..)` — or a `title:`.",
      )
    }
    // Recorded whether or not a suffix was actually needed (slug-n == 1
    // still records), so the NEXT note sharing this slug counts correctly —
    // see `_slug-record`'s own banner (state.typ) for the pure-updater
    // discipline. Idempotent per `occupant`, so replaying this same note
    // through a `#window` or a minted page never grows this slug's list a
    // second time.
    if slug != none {
      _slug-record(slug, occupant)
    }
    // `own-id` is this note's own bare id (no `_pfx()`) — passed to
    // `_flatten` below (transclusion.typ) alongside this note's body.
    let own-id = id.trim(_pfx(), at: start)
    figure(kind: IK, supplement: none, [
    // `title`/`named`/`base`/`level`/`tags`/`id` let `_flatten`'s IK rule
    // rebuild this note's own heading+box when it is shown nested inside a
    // transcluded/minted parent, without re-running the context block below
    // (which would re-register the note).
    //
    // `tags` here is the DICTIONARY — `_flatten`'s IK rule and `#ideas-outline`
    // both read it back and must take `.keys()` for names.
    // `title` is the AUTHORED one — `_flatten`'s IK rule PRINTS it as a heading, so
    // it must never be the derived label (see the banner above). `label` rides
    // along for `#ideas-outline`, which NAMES rather than renders.
    // `display` rides along for the same reason every other field here does:
    // `_flatten`'s IK rule rebuilds this note's card from THIS payload, never
    // from the call site, so a presentation switch missing from it is
    // silently lost the moment the note is shown nested inside a transcluded
    // or minted parent — the card would come back framed and permalinked
    // when its author asked for neither. `id` was resolved at this note's
    // ORIGINAL site, above, so `_flatten`'s IK rule can give even an
    // auto-numbered nested note a correct permalink.
    #metadata((body: body, title: title, label: note-label, named: named, base: base, id: id, level: level, tags: tags, display: display))
    #context {
      // The four RENDER-TIME keys, resolved HERE against document-wide state
      // rather than a built-in default — this is the note's own card
      // rendering, so it is the point of use `_display-final`'s banner
      // describes. `context`/`backlinks`/`title` are not resolved here: this
      // card never reads them, only `.marrow.typ`'s minted page does.
      let rdisplay = _display-final(display, ("date", "tags", "frame", "id"))

      // Resolution order, most specific first: the explicit created:
      // argument, then the containing document's own
      // `#set document(date:)`, else no date. MEASURED: a document with no
      // date set yields `auto`, NOT `none` — must be tested for explicitly.
      // Resolved HERE, outside the state.update() closure below: anything
      // contextual fails inside that closure with "can only be used when
      // context is known", since it runs lazily at `.final()` time.
      let doc-date = {
        let d = document.date
        if d == auto { none } else { d }
      }
      let resolved-created = if created != none { created } else { doc-date }

      // `rdisplay.date` gates display only — the date is always RESOLVED and
      // stored on the registry record above, so a #window of this note can
      // still show it even when the note's own hat (here) does not.
      //
      // `created`, and ONLY `created`: resolved here from the explicit argument,
      // else the containing document's own `#set document(date:)`. A note's
      // LIFECYCLE is `@rookery/timeline`'s subject, not core's — it stores a
      // dated log and derives last-touched from it.
      let date = if rdisplay.date and resolved-created != none {
        resolved-created.display("[year]-[month]-[day]")
      } else { none }

      // The note's CONTEXT: the handle of the page this `#idea` was written
      // in, captured HERE because this is the only moment anything knows it.
      // A minted note page is a separate `#document` and inherits nothing from
      // its origin, and `#window` can transclude a note into any number of other
      // pages — so "where was this written" has to be recorded at the call
      // site or it is gone.
      //
      // `state("rheo-handle")` is published per page by rheo's own
      // `rheo-page-init`. `.get()`, not `.final()`: the point is the handle
      // HERE, at this position in the spine, not wherever the document ends.
      // Non-str (a plain `typst compile`, where nothing publishes it) means no
      // context to record — `.marrow.typ`, the only reader, does not run there
      // anyway.
      let handle = state("rheo-handle").get()
      let origin = if type(handle) == str { handle } else { none }

      // Store the FLATTENED body plus the title, resolved dates and origin, so
      // a #window is pure presentation and any number of windows cost nothing, and
      // `#hyperlink`'s ref-mode can render a note's title without re-deriving
      // it. A duplicate EXPLICIT id only errors if something
      // observes the registry (e.g. #window or a ref) — an identical
      // re-insertion is a re-emission, not a collision.
      // A Typst footnote in here is one this package cannot claim: its body
      // would go to the page's endnote section instead of this idea's block,
      // and the build would otherwise SUCCEED while doing it. Checked at
      // registration rather than at render, so it runs once per idea however
      // many windows transclude it, and so the error names the authoring
      // mistake rather than firing from whatever page happens to window the
      // note.
      if _std-footnotes(body).len() > 0 {
        panic(
          "@rookery/core: `#footnote` inside an idea is Typst's, not rookery's — "
            + "its body would land in the page's endnote section instead of this "
            + "idea's Footnotes block. Add `footnote` to your import: "
            + "`#import \"@rookery/core:0.1.0\": idea, footnote`.",
        )
      }

      // Outbound links, filtered to real note ids and deduped, with a
      // self-link dropped — a note is not its own backlink. Walked from the
      // RAW body, before `_flatten`: flattening rewrites `#window` markers into
      // permalinks, which would turn every transclusion into an
      // indistinguishable `link` and lose the ones nested inside other notes.
      let links = _outbound(body)
        .filter(t => t.starts-with(_pfx()) and t != id)
        .dedup()

      // Tag-selected windows in this note's body, deferred to `.marrow.typ`
      // for expansion once the registry is final — see `_outbound-tag-selectors`.
      let tag-links = _outbound-tag-selectors(body)

      // `raw` is the body BEFORE flattening, kept alongside the flattened one
      // so a `#window` with a nested-window budget can re-flatten at a smaller
      // depth (see `_body-at`). Re-flattening the FLATTENED body would be
      // wrong: its WK markers have already been reduced to permalinks by the
      // depth-0 rule baked into it, so there would be nothing left to expand.
      //
      // `tags` is the normalized DICTIONARY, stored as `#idea` received it —
      // already deduped, because `tag:` and `base-tags:` fold under a caller's
      // own `tags:` via `_merge-base-tags`/`_dedup-tag` before this point.
      // TAGS ARE UNORDERED: key order is unspecified and nothing may depend
      // on it.
      //
      // It takes part in the identity comparison below: typst dictionary `==`
      // is ORDER-INSENSITIVE, so two pins of one id whose tags differ only in
      // key order do not collide, which is correct since order carries no
      // meaning. Two whose tag VALUES differ do collide, the same as when
      // `raw` or `origin` differ.
      // TWO FIELDS, not one: `title` is the authored one and is what gets printed
      // as a heading; `label` is what to call this note elsewhere. See the banner
      // above the figure for why conflating them printed the body twice.
      let rec = (
        title: title,
        label: note-label,
        raw: body,
        // `id:` is `_flatten`'s own parameter (transclusion.typ) — it fed a
        // per-note mint context that no longer exists now that an unnamed
        // note's id is a pure function of its own content. `_flatten`
        // itself ignores it now; left threaded through here rather than
        // pulled out of every caller.
        body: _flatten(body, id: own-id),
        created: resolved-created,
        origin: origin,
        links: links,
        tag-links: tag-links,
        tags: tags,
        // `display` carries `context`/`backlinks`/`title` as `auto` (the
        // default) when unset, meaning "use the document-wide
        // `rookery.with(display-context:, display-backlinks:, display-title:)"
        // setting" — `.marrow.typ` reads these off the record ONLY for the
        // minted page (the footer for the first two, the `<h1>` for the
        // third) and falls back to the document default when the value is
        // `auto`. `true`/`false` here overrides that default for THIS note
        // alone.
        display: display,
      )
      _registry.update(r => {
        let existing = r.at(id, default: none)
        if id in r and existing != rec {
          panic(
            "@rookery/core: duplicate note id " + id + " — already registered"
              + (if existing.origin != none { " in " + existing.origin } else { "" })
              + ", registered again" + (if origin != none { " in " + origin } else { "" })
              + ". An id must be unique whether it was pinned by name or derived"
              + " from a title — a pinned id and a title-derived id collide just"
              + " like two pinned ids would. Retitle or rename one of the two"
              + " notes, or pin the derived one explicitly with #idea(<some-name>, title: [..]).",
          )
        }
        r.insert(id, rec)
        r
      })

      // Hidden referenceable anchor. VERIFIED: a locally scoped
      // `show ...: none` still hides it while leaving it referenceable, in-page
      // AND cross-page; it exports as <span id="loc-N">, and typst's own bundle
      // export turns a cross-vertebra #link(label(id)) into
      // ../<page>.html#loc-N.
      {
        show figure.where(kind: "rheo-idea-anchor"): none
        [#figure([], kind: "rheo-idea-anchor", supplement: none)#label(id)]
      }

      // THE AUTHORED TITLE ONLY. A titleless note renders an EMPTY heading —
      // the element survives to carry the `id` anchor and `h*.idea:empty`
      // collapses it. Putting the derived label here is what printed the body
      // twice; see the banner above the figure.
      // CLASSES COVER EVERY KEY, valued tags included: `.idea-tag-<key>` is the
      // hook a project styles a tag by, and a tag that carries metadata is no
      // less a tag for it. Only the PILLS below are restricted to flat tags.
      // INVISIBLE TAGS DROP OUT OF THE CLASS LIST TOO, not only out of the pill:
      // `idea-tag-<tag>` in the HTML names the tag just as plainly as a pill does,
      // and it is the hook a stylesheet (or a `tags-color` rule) reaches it by.
      // See `_invisible-tags`/`_visible-tags` (state.typ).
      let visible = _visible-tags(tags.keys())
      let cls = (_c(""),) + visible.map(l => _c("tag-" + l))
      // The flat tags — those whose value is `none`. This is what
      // `rdisplay.tags` renders as pills: a valued tag's name alone says nothing useful in a
      // pill (`depends-on` with no dependencies shown), so a package carrying
      // metadata in tags renders it it own way instead of polluting the hat.
      let flat-tags = tags.pairs().filter(((_, v)) => v == none).map(((k, _)) => k)
      if _target() == "html" or _target() == "epub" {
        // The permalink is the only way to discover an UNTITLED note's
        // auto-generated id —
        // there is no `show heading` rule and no template to hook into, so
        // `#idea` emits it directly, always (even with no title), showing
        // the FULL `idea:name` id so it is copy-pasteable straight into
        // `#window("...")`. `#window` renders the identical affordance in its own
        // summary; both go through `_permalink-tab`.
        //
        // ABOVE the heading, not inside it: the id is the card's top rule (see
        // `_permalink-tab` and `.idea-tab`), so a titleless note needs no
        // special case — the tab is the same either way. The title keeps its
        // span, which nothing styles by default: it stays a hook a project can
        // reach for, and `#window`'s summary wraps its title the same way.
        //
        // THE DATE IS IN THE TAB TOO, at its far right, not a child of the
        // heading: it belongs to the frame rather than to the sentence, which
        // keeps a titleless note's heading empty even when dated (see the note
        // below on `h*.idea:empty`).
        //
        // The heading element survives even with NO children — a titleless note.
        // Its `id` attribute is the note's in-page anchor, the destination of every
        // `@idea:etal` fragment link, so dropping the element would break them;
        // `h*.idea:empty` in the stylesheet is what keeps it from taking any space.
        // Passes `handle` (already read above, for `origin`) straight into
        // `_note-href` rather than letting the tab's own `_permalink` read
        // `state("rheo-handle")` a second time from this same context — see
        // `_note-href`'s own banner (urls.typ) for why the second read, not
        // the id, was what `state("rheo-handle")` was reported unstable at.
        // `page-href == none` mirrors `_permalink`'s own fallback exactly,
        // since passing an explicit href bypasses that fallback.
        let own-href = {
          let page-href = _note-href(id, handle: handle)
          if page-href == none { "#" + id } else { page-href }
        }
        let header = _head(
          _permalink-tab(
            id,
            href: own-href,
            tags: if rdisplay.tags { flat-tags } else { () },
            date: date,
            display-id: rdisplay.id,
          ),
          html.elem(
            "h" + str(level + 1),
            attrs: (id: id, class: cls.join(" "), data-rookery: "idea")
              + _tags-attr(visible),
            if title == none { [] } else {
              html.elem("span", attrs: (class: _c("title"), data-rookery: "title"), title)
            },
          ),
        )
        // Header and body wrap together in one card, HTML/EPUB only — no box
        // for a paged target. The box classes mirror `cls` (tags included)
        // so a tag can style the whole card, not just the heading; the
        // heading's own class list (above) is untouched for existing
        // stylesheets.
        let box-cls = (_c("box"),) + visible.map(l => _c("tag-" + l))
        _sweep-block()
        // Bracketed so a link written INSIDE this note counts as the note's,
        // not as its page's — see `_edge`.
        //
        // THE REFERENCES BLOCK GOES INSIDE THE CARD, beside the footnotes block
        // rather than under the card's floor. Both are apparatus for this note,
        // and the card's `border-left` and `padding-left` are what say so: a
        // block outside the card sits flush against the page's own margin
        // instead of the note's text margin. Document order is unchanged by the
        // move, which is what leaves Typst's POSITIONAL citation partitioning
        // alone — the block still follows the body, so it still claims exactly
        // this note's citations.
        _bracket(
          html.elem(
            "div",
            // `data-rookery-bare` ONLY when the frame is off — an unconditional
            // attribute with a `"false"` value would still match
            // `[data-rookery-bare]`, so a framed card omits the attribute
            // entirely rather than set it false.
            attrs: _themed(
              (class: box-cls.join(" "), data-rookery: "box")
                + (if rdisplay.frame { (:) } else { ("data-rookery-bare": "bare") })
                + _tags-attr(visible),
            ),
            header + _footnoted(body) + _refs-block(_own-cited-keys(body)),
          ),
          IK,
        )
      } else {
        // `align(start)`, and it is load-bearing: this whole branch renders
        // INSIDE the `figure(kind: IK)` that marks the note, and a Typst
        // figure CENTRES its body. On html/epub that is inert — the figure
        // exports as `<figure>` and CSS decides — but on a paged target it
        // centres every note in the document: headings, prose, raw blocks and
        // all, while the same content outside a figure is left-aligned.
        //
        // `start`, not `left`: it follows text direction, so an RTL document
        // is not forced the wrong way round. The figure is not optional — it
        // is the marker `_flatten`, `_outbound` and `#ideas-outline` all find
        // notes by — so undoing its alignment is the fix, not removing it.
        // The paged target needs these just as much as HTML does, and it is
        // not cosmetic there: a citation with no bibliography anywhere is a
        // HARD ERROR (`label <key> does not exist in the document`), so a
        // combined PDF fails to build without them.
        _sweep-block()
        _bracket(align(start, {
          if title != none { heading(depth: level, title) }
          if date != none { text(gray, date); linebreak() }
          _footnoted(body)
        }) + _refs-block(_own-cited-keys(body)), IK)
      }
    }
    ])
  }
}

// ---- #idea-tag-names / #idea-tag-value — reading an idea's tags ------------------------
//
//
//   #context idea-tag-names("etal")   // -> ("note", "draft")
//
// Takes a bare name, a full id or a Typst label — whatever `_norm` accepts,
// which is the same set of forms `#window` and `#hyperlink` take. Returns the
// note's tag NAMES as a flat array, and `()` both for an untagged note and for
// an id that does not exist — a missing note is not an error here, because a
// caller asking "what is this tagged" is filtering, not dereferencing.
//
// EVERY key, valued tags included: a tag that carries metadata is still a tag,
// and this is the "what is this tagged" question. KEY ORDER IS UNSPECIFIED —
// tags are unordered, and nothing may depend on the sequence.
//
// The VALUES are deliberately not here. `idea-tag-value` below fetches one, and
// `tag-data` (data.typ) fetches the whole store in bulk.
//
// Must be called INSIDE a `#context` block: it reads `_registry.final()`. It
// is not itself a context function, because a context function may only
// return content and the whole point here is to return data.
#let idea-tag-names(name) = {
  let id = _pfx() + _norm(name)
  _registry.final().at(id, default: (:)).at("tags", default: (:)).keys()
}

// One tag's VALUE on one note:
//
//   #context idea-tag-value("etal", "priority")            // -> 1
//   #context idea-tag-value("etal", "nope", default: 4)    // -> 4
//
// Takes the same name forms `idea-tag-names` takes. Returns `default` when the note
// does not exist, or exists without that key — a missing note is not an error,
// for the same reason it is not one in `idea-tag-names`.
//
// A PLAIN TAG'S VALUE IS `none`, which is indistinguishable from `default:
// none` on a key that is absent. Ask `idea-tag-names` (or `tag-data`) when the
// question is presence rather than value; this function answers "what is it
// set to", and a plain tag is set to nothing.
//
// Must be called INSIDE a `#context` block, same as `idea-tag-names`.
#let idea-tag-value(name, key, default: none) = {
  let id = _pfx() + _norm(name)
  _registry.final().at(id, default: (:)).at("tags", default: (:)).at(key, default: default)
}

// ---- #footnote — shadows Typst's, scoped to the enclosing idea ------------
//
// Import it alongside `#idea` and write footnotes exactly as before:
//
//   #import "@rookery/core:0.1.0": idea, footnote
//   #idea("etal")[A claim#footnote[The evidence.] worth qualifying.]
//
// Emits nothing on its own — it is an invisible marker. Inside an idea,
// `_footnoted` claims it, numbers it against that idea and lists its body in
// the idea's own Footnotes block. Outside one, the document-wide rule
// `#show: rookery` installs falls back to `std.footnote`, so a footnote in
// ordinary page prose behaves exactly like Typst's: page-wide numbering, body
// in the page's endnote section.
//
// It must NOT call `std.footnote`, step a counter, or emit a `<sup>` — all of
// that belongs to whichever show rule claims the marker, and doing any of it
// here would put a real footnote element in the document that nothing can
// then remove (see the note on FNK above).
#let footnote(body) = [#metadata((rookery-fn: body))<rkfn>]
