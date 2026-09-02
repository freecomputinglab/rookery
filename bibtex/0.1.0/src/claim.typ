// The two states behind `bibtex(..)`'s split between minting and claiming.
//
// `_claimed` cannot be a read of core's own note registry: `ideas()` reads
// `_registry.final()`, and `all()` (lib.typ) FEEDS that registry by minting
// notes into it — asking the registry "is this key taken" from inside the
// sweep that writes it is circular, and Typst's own state resolution refuses
// to converge on a loop like that. A separate state breaks the cycle: `all()`
// only ever READS `_claimed`, and `citation` (lib.typ) is the only writer.
//
// `_swept` guards `all()` against a second call — see `all()`'s own comment
// for why it must be read with `.get()`, never `.final()`.
#let _claimed = state("rookery-bibtex-claimed", ())
#let _swept = state("rookery-bibtex-swept", 0)
