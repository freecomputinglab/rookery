// @rookery/search — fuzzy search over a rookery.
//
// Reads the corpus through `@rookery/core`'s public primitives and never touches
// its internals: `ideas()` for the notes, `note-href()` for links. Nothing here
// renders a note's body — the modal's preview pane fetches the note's own minted
// page at runtime — so the build cost is one pass over the registry per page
// rather than one body render per note per page.
//
// Two layers:
//   - `search-ideas(query)` is pure Typst and works under plain `typst compile`,
//     for a static list of matches with no JavaScript.
//   - `search-index()`, `search-bar()` and `search-modal()` are rheo only. Their
//     script is injected by rheo from this manifest's `js_scripts`, and the index
//     links to minted note pages, which only rheo produces.
//
// A BUILT PACKAGE, unlike `@rookery/core`: `dist/lib.js` comes from `just build`,
// so an edit to `src/*.js` takes effect only after a rebuild. The Typst
// entrypoint and the stylesheet are read from `src/` directly.
#import "@rookery/core:0.1.0": ideas, note-href

// THE ENTRYPOINT IS A MANIFEST. Every name this package exports lives in one of
// the modules below, and `#import "x.typ": *` re-exports transitively — so
// `@rookery/search:0.1.0` is a single import for a project, and `.marrow.typ`
// resolves `_compress-corpus`, `_corpus-cache` and `_corpus-key` by name.
//
// THE ORDER IS THE DEPENDENCY ORDER, and it is load-bearing: a `#let` closure
// captures the scope visible at definition time, and Typst has no cycles to fall
// back on. A line in the wrong place still builds as a package and still passes
// both suites, failing only on a real site with `unknown variable: ..` — which is
// why `rheo compile` over a demo project is one of this package's checks.
#import "base.typ": *
#import "tagquery.typ": *
// Before `rank.typ`, whose `_rank` calls `fuzzy-score` and `body-score`.
#import "score.typ": *
#import "rank.typ": *
#import "lookup.typ": *
// Before `corpus.typ`, whose `#search-index` calls `_compress-corpus`.
#import "compress.typ": *
#import "corpus.typ": *
#import "ui.typ": *
#import "panel.typ": *
// After `panel.typ`, whose `_panel-shell` draws `#filter-panel`'s chrome.
#import "filter-panel.typ": *
