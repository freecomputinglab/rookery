// The smallest deck this package can render: three named slips, queried by
// their `slip` tag, with no options at all — the shape every other example
// under `examples/` builds on top of.
#import "lib.typ": template
#import "@rookery/slipshow:0.1.0": slip, slipshow
#show: template

#slip("opening")[Welcome. This deck has three slips and no options.]
#slip("middle")[Each `#slip` is a note the deck below queries by tag.]
#slip("closing")[The end.]

#slipshow(tags: "slip")
