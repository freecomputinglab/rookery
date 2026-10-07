#import "lib.typ": demo, idea
#import "@rookery/core:0.1.1": labelled, window

#show: demo

= Labels inside an idea body

// The regression fixture for `labelled`: a plain `<label>` written straight
// into this body would place the SAME label twice in one compile — once
// here, once on `labelled-note`'s own minted page — and a `@lbl-eg`
// reference would fail the whole build. `labelled` attaches the label only
// at this canonical placement, so the reference below (and the one on the
// `#window` copy further down) resolves to this figure and nowhere else.
#idea("labelled-note", title: [Labelled note])[
  #labelled("lbl-eg", figure([Example body content.], caption: [an example]))

  See @lbl-eg for details.
]

// A second placement of the SAME body, via `#window` rather than the minted
// page — proving `labelled` also keeps the label out of a transcluded copy,
// not just the mint.
#window(<labelled-note>)

// A `labelled` figure written OUTSIDE any idea body at all, so the fixture
// also proves the helper works at the page's own top level, where there is
// no minted or windowed copy to collide with.
#labelled("lbl-plain", figure([Plain.], caption: [plain]))

See @lbl-plain.
