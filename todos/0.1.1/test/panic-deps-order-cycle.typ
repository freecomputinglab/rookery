#import "/src/table.typ": _deps-order

#let row(name, deps: ()) = (name: name, deps: deps, closed: false, tags-dict: (:), priority: 0)
#_deps-order((row("c", deps: ("d",)), row("d", deps: ("c",))))
