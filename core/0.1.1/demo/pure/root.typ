// Native Typst demo — no rheo involved. Most of @rookery/core's feature
// coverage now lives in `demo/rheo/native.typ`, the SAME package compiled the
// SAME way (plain `typst compile`, no rheo), over a rookery with real content
// and real cross-vertebra transclusion instead of a standalone fixture. What
// stays here is what that move could not take with it: `card-gap.typ` and
// `folded-height.typ`, two CSS regression fixtures that need PIXEL
// measurement to assert at all — no automated check in either demo can do
// that, so they stay small and isolated rather than diluting the rookery's
// narrative content with shapes that exist only for a stylesheet's sake.
//
// MEASURED 2026-08-13: typst 0.15.1's `typst` CLI (nixpkgs) has NO way to
// invoke the multi-document "bundle" target the epic's design notes describe
// (`#document(...)` as a constructor errors "constructing a document is only
// supported in the bundle target", and neither `--features bundle` nor
// `--format bundle` exist on this build's `compile` subcommand — verified via
// `typst compile --help`). So this demo is a single compiled document
// (#include, not #document-per-page) rather than a true multi-page bundle;
// #link/#window below resolve as in-page fragments (`#loc-N`), not cross-page
// hrefs. Cross-page href/transclusion behaviour is exercised instead by the
// documentation site in the sibling repo `rookery.ohrg.org`, which produces
// real multi-page HTML via `rheo compile`.
//
// Because there is no rheo here, the CSS is NOT auto-injected — a real HTML
// deployment would need to include ../../src/core.css manually (rheo does
// this for you via [tool.rheo.html]).
//
// Build (PDF):  typst compile --features html --root ../.. root.typ build/root.pdf
// Build (HTML): typst compile --features html --format html --root ../.. root.typ build/root.html
#import "../../src/lib.typ": rookery
#show: rookery

#include "card-gap.typ"
#include "folded-height.typ"
