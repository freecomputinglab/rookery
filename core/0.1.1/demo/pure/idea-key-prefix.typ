// A second root, separate from idea-key.typ: `prefix:` is document-wide
// state, so this is the only way to cover `idea-key` under a NON-DEFAULT
// prefix — the case the function exists for, since a hardcoded `"idea:"`
// is exactly what breaks once a project changes it.
//
// Build (PDF):  typst compile --features html --root ../.. idea-key-prefix.typ build/idea-key-prefix.pdf
// Build (HTML): typst compile --features html --format html --root ../.. idea-key-prefix.typ build/idea-key-prefix.html

#import "../../src/lib.typ": idea-key, rookery
#show: rookery.with(prefix: "note")

#context assert.eq(idea-key("etal"), "note:etal")
