#import "lib.typ": demo
#import "@rookery/core:0.1.0": ideate

#show: demo

= Ideated by heading

// A weeknotes-shaped vertebra: every `==` mints its own note, titled and
// named by its own heading rather than by a fixed title and the package
// counter. `check.sh` looks for each section's slug as a minted page under
// `ideas/`, and for the source heading NOT surviving into that page's body —
// `#idea` already renders `title` as the note's own heading, so leaving the
// source heading in place too would print it twice.
#show: ideate.with(separator: heading.where(level: 2), title: heading, name: heading)

== Literate programming

A section on writing programs to be read, minted as its own note titled and
named after this very heading rather than by the package's auto-incrementing
counter.

== Fuzzy search ranking

A second section, proving the slug this heading mints under does not collide
with the first one's.

== Testing edge cases <sec:one>

A third section, so this fixture has more than the bare minimum needed to
prove the ids don't collide. Its heading carries a label too — `<sec:one>` —
proving a label without the `tag:` prefix is left alone: no extra tag on this
note, and no panic either.

// A fourth section, whose heading carries a `<tag:rookery>` label. Minted
// with that one extra tag on top of whatever `tags:` this call already
// applies (nothing, here) — every other section above has none at all.
== Rookery <tag:rookery>

A fourth section, tagged `rookery` by its own heading's label rather than by
anything passed to `#ideate` itself.
