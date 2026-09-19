// display-parity.typ — proves that `#idea` and `#window` each accept all
// nine `display-*` flags, the ones a function has no use for included,
// without erroring and with no visible effect from the ones it ignores.
//
// A clean compile is the whole assertion. There is nothing to grep for: the
// point is that these calls do not panic and that both spellings of the
// display surface — a flag and the equivalent `display: (..)` key — are
// accepted everywhere, even where a function does nothing with the result.
#import "../../src/lib.typ": idea, rookery, window

#show: rookery

= Display flag parity

#idea(
  <parity>,
  display-date: false, display-tags: false, display-frame: false,
  display-id: false, display-label: false, display-background: false,
  display-context: false, display-backlinks: false, display-title: false,
)[PARITYBODY]

#window(
  "parity",
  display-date: false, display-tags: false, display-frame: false,
  display-id: false, display-label: false, display-background: false,
  display-context: false, display-backlinks: false, display-title: false,
)
