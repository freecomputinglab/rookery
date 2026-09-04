// The tag route over a tag BOTH kinds carry. See `content/corpus.typ` for
// the ten notes it draws from — this page's `#slipshow` sees every one of
// them, because `ideas()` is project-wide.
#import "lib.typ": template
#import "@rookery/slipshow:0.1.0": slipshow
#show: template

= A deck built by querying a tag

`#slipshow(tags: "slip")` would select only the five `#slip`-authored notes
below, because a plain `#idea` carries no `slip` tag at all. Querying on a
tag the author put on both kinds instead — `talk`, here — is how a mixed deck
is selected without naming a single note.

#slipshow(tags: "talk")
