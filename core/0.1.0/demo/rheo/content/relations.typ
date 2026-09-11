#import "lib.typ": demo, idea
#import "@rookery/core:0.1.0": ideas-outline, window, hyperlink
#show ref: hyperlink
#show: demo

= Relations: auto-ids, references, prune and promote

// The tagged note sits inside a TITLED but UNTAGGED one, which is what makes
// the pair of `#ideas-outline` calls below demonstrate PRUNE AND PROMOTE: the
// parent shows in the unfiltered index and does not match the filter, so
// under `tags: "phd"` it is pruned and the child re-based to the top level
// rather than left dangling at a depth with no parent above it.
#idea(title: [Auto note])[
  An auto-id note, referenced below by its label rather than by name.

  #idea("pinned", title: [Pinned], tags: ("phd", "draft"))[
    A pinned note, referenced from prose further down this page.
  ]
]

A plain link to the label `#idea` sets on every note: #link(label("idea:pinned"))[jump to the pinned note].
Same thing via `#hyperlink`: #hyperlink("pinned")[jump to the pinned note].

// Without `#show ref: hyperlink` above, `@idea:pinned` would resolve (the
// `<idea:pinned>` label exists as soon as `#idea("pinned")` runs) but render
// as a bare FIGURE NUMBER — Typst's default `@` rendering for a labeled
// figure, not the note's title. With the rule applied, it renders the note's
// title instead, linked, and an ordinary `@`-reference to a real figure
// elsewhere passes through unaffected.
Terse form, now that hyperlink is applied as the ref rule: @idea:pinned

A transcluded window of the same note:

#window("pinned")

// Two indexes of the same notes, side by side, because the PAIR is what
// shows the filter's one surprising rule. Unfiltered, "Pinned" sits one
// level down, inside the untitled note that contains it. Filtered to `phd`,
// that parent does not match — so it is pruned and "Pinned" is PROMOTED to
// the top level, rather than left dangling at a depth with no parent above
// it. `rookery-wide: true` on both, since this rookery's other notes live on
// other vertebrae.
#ideas-outline(title: [Everything], rookery-wide: true)
#ideas-outline(title: [Tagged phd], rookery-wide: true, tags: "phd")
