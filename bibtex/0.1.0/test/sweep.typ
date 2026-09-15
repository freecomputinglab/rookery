// The RENDERED half of the `all()` fixture — the sweep that mints a note for
// every bibliography key a hand-written `#citation` has not already claimed.
// `units.typ` covers `bibtex(..)`'s shape; this covers what `all()` actually
// registers, which needs `#show: rookery` and a real note registry to read
// back — a page without it renders no note chrome at all.
//
// Two entries: `badiou2002` is claimed by hand, with an authored body;
// `smith2020` is left for `all()`, which mints it with the empty body a swept
// note always gets (see `lib.typ`'s comment on why that body is load-bearing).
#import "@rookery/core:0.1.0": rookery, ideas
#import "/src/lib.typ": bibtex

#let BIB = "@book{badiou2002,\n  title = {Ethics},\n}\n\n@article{smith2020,\n  title = {A Paper},\n}\n"
#let refs = bibtex(BIB)

#show: rookery

// Parenthesized field access, not `#refs.citation(..)`: Typst 0.15.1 refuses
// to call a dictionary VALUE with method syntax (`cannot directly call
// dictionary keys as functions`) — `bibtex(..)` returns a plain dictionary of
// functions, not an object with methods, so every call here needs the
// `(refs.field)(..)` form.
#(refs.citation)("badiou2002")[A hand-written body.]
#(refs.all)()

// One `<div class="sweep-row">` per registered note, id and body in their own
// spans (rather than joined with a text separator, which HTML's whitespace
// collapsing would mangle for the empty-body row) — for `check.sh` to grep.
// `ideas()` reads the registry itself, so this is a faithful count of what
// actually registered, not merely of what this file asked to mint.
#context {
  for i in ideas() {
    html.elem("div", attrs: (class: "sweep-row"), {
      html.elem("span", attrs: (class: "sweep-id"), i.id)
      html.elem("span", attrs: (class: "sweep-body"), i.body)
    })
  }
}
