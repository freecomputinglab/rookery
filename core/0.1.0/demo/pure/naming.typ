// naming.typ — content-derived ids for a titleless, unnamed note: a body
// slug (whole words, capped at 16 characters) plus a three-character content
// digest, and the URL-tail rule that keeps two links under the same host
// from colliding on one slug.
//
// COVERS what no unit test can reach: the SAME note reaching the SAME id
// wherever its body is rendered again — nested inside another note, and
// transcluded through `#window` — which only shows up once a note's body is
// actually rendered a second time.

#import "../../src/lib.typ": idea, window

= Content-derived names

// An ordinary titleless note. Its opening two words alone reach the
// 16-character cap, so its id's slug is exactly `notebook-margins`. Tagged
// so the `#window` below can find it without a name to call it by —
// tagging a note is not naming it.
#idea(tags: "windowed")[Notebook margins are where the real thinking
  happens, not the fair copy.]

// A titleless note whose body BEGINS with a bare URL. The slug source is the
// URL's TAIL — here, only its last path segment, `unikernels` — not its
// host.
#idea[https://anil.recoil.org/projects/unikernels]

// A second titleless note under the SAME host, a different path. Slugging
// left-to-right from the host would give both notes the same slug,
// `anil-recoil-org`; the tail rule instead reaches past the shared host to
// each URL's own last segment, landing this one on `2024-hope` instead.
#idea[https://anil.recoil.org/papers/2024-hope-bastion]

// A titleless note NESTED inside another note's body. Under the ordinal-
// based scheme this took its parent's own id with a counter appended
// (`nn-parent-1`); it now derives an id from its own body like any other
// titleless note, and carries none of its parent's name.
#idea("nn-parent", title: [A note with a nested note inside it])[
  #idea[Filed here with no name of its own, sitting inside its parent
    instead of borrowing the parent's id and a number.]
]

// `#window` renders the first note's body a SECOND time. What matters is
// that both renderings resolve to the exact same id — the one thing a unit
// test, which never renders anything twice, cannot see.
#window(tagged: "windowed")
