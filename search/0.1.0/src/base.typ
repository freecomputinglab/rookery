// Target detection, text folding, row readers and the argument validators more
// than one public function needs.
//
// Every other module imports this one and it imports nothing, which is what
// keeps the module graph a DAG.

// `_rheo-ctx`/`_target` are a copy of rookery's own pair, not an import of it:
// they are six lines of `sys.inputs` read, and `sys.inputs` is readable from any
// package's scope, so the copy behaves identically without rookery widening its
// public surface. Keep the two in step.
//
// `std.target()` reports EPUB as "html" where rheo's context distinguishes the
// two, hence the context first. `std.target()` rather than a bare `target()`,
// because rheo injects its `target()` polyfill into each vertebra's scope and not
// into package scope — and that read requires `--features html`, which every
// build of a project using this package therefore needs.
#let _rheo-ctx() = sys.inputs.at("rheo-context", default: none)

#let _target() = {
  let c = _rheo-ctx()
  if c != none and "target" in c { c.target } else { std.target() }
}

// Where `.marrow.typ` writes the one shared index, from the SITE ROOT. It sits
// beside this package's own scripts, which rheo copies to `rookery/search/`
// from the manifest's `[tool.rheo.source.html]` list, so the index and the code
// that fetches it land in one directory.
#let _index-asset-path = "rookery/search/index.json"

// ONE `../` per `:` level of the CURRENT page's handle — the depth rule rheo
// and `@rookery/core`'s own `_rel-prefix` both apply. A deliberate copy of
// three lines rather than an import of a private name, exactly as `_rheo-ctx`
// above copies its pair; keep the two in step.
//
// `""` off a rheo build, which is right for both callers: `mode: "asset"`
// needs rheo to have minted the asset at all, and a bare relative path is the
// least wrong answer where there is no page depth to measure.
//
// Needs `#context`: it reads the per-page `rheo-handle` state rheo publishes.
#let _page-base() = {
  let h = state("rheo-handle").get()
  if type(h) != str { return "" }
  let depth = h.split(":").len() - 1
  if depth == 0 { "" } else { range(depth).map(x => "../").join() }
}

// THE THEME IS INHERITED, NOT COPIED. This package's stylesheet reads rookery's
// custom properties ahead of its own literals —
// `var(--rookery-search-border, var(--idea-border-color, ...))` and friends — so a
// site that themes its notes tints the search UI to match with no second
// configuration. Rookery publishes the configured theme once per page as a
// document-scope `<style>:root { --idea-*: ...; }</style>` rule, and custom
// properties inherit from `:root` down the whole DOM, so `#search-bar` and
// `#search-modal` resolve it with no inline style and no private copy of the
// table — neither element has a `.idea-*` ancestor to inherit from.

// Lowercase, with `-`/`_` read as a space. Applied to the HAYSTACK AND THE QUERY,
// which is what makes an id findable by how a person types it: the note
// `flat-ids` matches "flat ids", and the literal "flat-ids" still matches, both
// sides collapsing to the same thing. Folding only the haystack would break the
// second case, the query's `-` finding no `-` left to match.
//
// Deliberately NOT accent-folding: "cafe" does not match "Café", and fixing that
// means Unicode normalisation the JavaScript port would have to reproduce
// exactly. The readme records it as a known limitation.
#let _fold(s) = lower(s).replace("-", " ").replace("_", " ")

// A row's own tag NAMES. `ideas()` gives `tags` as an array of names and
// `values: true` adds `tags-dict`, whose keys are those same names, so reading
// either means a caller may pass rows from either call. A row with neither
// field is untagged, and therefore matches no tag expression at all.
#let _row-tags(r) = {
  let d = r.at("tags-dict", default: none)
  if d != none { return d.keys() }
  let t = r.at("tags", default: ())
  if type(t) == dictionary { t.keys() } else { t }
}

// The default haystack a text input filters on: the row's label, name and body,
// joined. Searching the BODY is what finds a note by a phrase inside it rather
// than by its title.
#let _row-haystack(r) = (
  r.at("label", default: ""),
  r.at("name", default: ""),
  r.at("body", default: ""),
).filter(s => s != "" and s != none).join(" ")

// A `datetime` as the zero-padded `[year][month][day]` string every date sort
// here compares, or `none` for an undated row. The padding is what makes a
// plain string sort a date sort, with no `datetime` comparison anywhere.
#let _date-stamp(d) = if d == none { none } else { d.display("[year][month][day]") }

// `tags`, `match` and `body-search` are checked identically by several public
// functions, so the check and its message live here once. `where` is the caller's
// own name as it appears in the message, possessive included — `#search-ideas'`
// and `#search-index's` are both correct for their nouns.
//
// A deliberate copy of `@rookery/core`'s three rather than an import: these
// messages say `@rookery/search:` and belong to this package. `limit` and `class`
// are checked in `_search-ui-common` instead, being the UI surfaces' pair;
// `#search-ideas`' `limit` is a different check again, accepting 0 where the UI's
// does not.
#let _assert-tags(v, where) = assert(
  v == none
    or type(v) == str
    or (type(v) == array and v.all(t => type(t) == str)),
  message: "@rookery/search: " + where + " `tags` must be none, a "
    + "string, or an array of strings — got " + repr(v),
)

#let _assert-match(v, where) = assert(
  v == "any" or v == "all",
  message: "@rookery/search: " + where + " `match` must be \"any\" or "
    + "\"all\" — got " + repr(v),
)

#let _assert-bool(v, name, where) = assert(
  type(v) == bool,
  message: "@rookery/search: " + where + " `" + name + "` must be a "
    + "boolean — got " + repr(v),
)

// The message names the trade rather than only the two words, because the wrong
// value here is a performance cliff rather than a typo: a site that meant
// `"asset"` and wrote something else gets the island in every page.
#let _assert-mode(v, where) = assert(
  v == "asset" or v == "inline",
  message: "@rookery/search: " + where + " `mode` must be \"asset\" (one "
    + "fetched index, needs http(s)://) or \"inline\" (the index in every "
    + "page, works from file://) — got " + repr(v),
)
