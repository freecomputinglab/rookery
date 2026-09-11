// The RENDERED half of the `show-fields:` fixture — asserts on the actual
// markup a hidden field disappears from, not merely on the filter behind it
// (`units.typ` covers that in isolation). The factory hides `doi` and
// `urldate`; `refs.fields(..)` takes no override, so what renders here is the
// factory default reaching `fields-block` through `lib.typ`'s threading.
#import "/src/lib.typ": bibtex

#let BIB = "@article{hidden2020,\n  title = {A Paper},\n  author = {Jane Smith},\n  year = {2020},\n  doi = {10.5555/x},\n  urldate = {2024-01-01},\n}\n"
#let refs = bibtex(BIB, show-fields: ("doi": false, "urldate": false))

#(refs.fields)("hidden2020")
