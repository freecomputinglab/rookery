#import "cfp.typ": *
#import "cfp.typ" as _cfp
#import "panel.typ": *

// `cfps(kinds:)` STILL RESOLVES TO ONE FACTORY, not two. `cfp.typ`'s own
// `cfps(kinds:)` cannot build `panel:` itself: doing so needs `panel.typ`,
// which imports `cfp.typ` for its constants and `real-stage-of`/`cfp-state` —
// a package cycle either way round. So this module SHADOWS the star-imported
// `cfps` with one that calls straight through to `cfp.typ`'s own (reached here
// via the aliased import, since the shadow below cannot see itself) and merges
// in `panel:` — the same "a later top-level `#let` shadows a star-imported
// name" device `@rookery/timeline`'s own `lib.typ` uses to decorate
// `idea`.
#let cfps(kinds: (:)) = (.._cfp.cfps(kinds: kinds), panel: _make-panel(kinds))
