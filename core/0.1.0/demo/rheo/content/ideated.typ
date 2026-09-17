#import "lib.typ": demo
#import "@rookery/core:0.1.0": ideate, ideate-tag, slug

#show: demo

= Ideated by heading

// A weeknotes-shaped vertebra: every `==` mints its own note, titled and
// named by its own heading rather than by a fixed title and the package
// counter. `check.sh` looks for each section's slug as a minted page under
// `ideas/`, and for the source heading NOT surviving into that page's body —
// `#idea` already renders `title` as the note's own heading, so leaving the
// source heading in place too would print it twice.
#show: ideate.with(separator: heading.where(level: 2), title: (content, labels) => content, name: (content, labels) => slug(content))

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

// AN EMPTY SECTION IS STILL A NOTE, and this one has nothing under it on
// purpose. A stub heading an author has not filled in yet is a note they wrote,
// so it mints titled and bodyless rather than being emitted as a bare heading —
// otherwise a chapter of stubs pins only the sections that happen to have a
// sentence in them. NOT THE LAST SECTION in this file, deliberately: the last
// group carries rheo's trailing `context` postamble (fact 5 in `ideate.typ`),
// which would make it mint whatever the heading-only rule says and so prove
// nothing.
== An empty section

== Rookery

A fourth section, tagged `rookery` by an `#ideate-tag` beacon placed in its own
body.

#ideate-tag("rookery")
