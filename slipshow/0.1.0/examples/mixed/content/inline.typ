// The other explicit-array shape: ideas written inline in the `slips:` call
// rather than named. This is a genuinely different code path from
// `index.typ`'s — a name in `slips:` resolves through the registry
// (`select.typ`'s `_slip-lookup`), while inline content here has its options
// read back off the RENDERED markup by `marker.typ`'s `slip-tags-of`. One can
// break while the other passes, which is why this page exists alongside
// `index.typ` rather than instead of it.
//
// These three notes still take PINNED names (`intro`, `aside`, `outro`) —
// see `corpus.typ`'s header on why an auto id is never safe — even though
// nothing here looks them up by name. They also carry no `talk` tag: they
// join the same project-wide registry `tagged.typ` queries, and tagging them
// `talk` would silently grow that page's deck by three.
#import "lib.typ": template
#import "@rookery/core:0.1.0": idea
#import "@rookery/slipshow:0.1.0": slip, slipshow
#show: template

= A deck built from ideas written in place

The same explicit-array route as `index.typ`, but the array holds
already-rendered content instead of names. `#slip`'s options still have to
survive being read back out of that rendered markup rather than off a
registry row — the fullscreen slip below proves they do.

#slipshow(slips: (
  slip("intro", fullscreen: true)[Written right where the deck calls for it, not filed away by name.],
  idea("aside")[A plain `#idea`, inline, taking the deck's defaults exactly as it would from the registry.],
  slip("outro")[The options above came from the rendered markup, not a lookup.],
))
