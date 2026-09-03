#import "/src/lib.typ": todo-graph, layer-of

#let row(name, deps: ()) = (name: name, deps: deps, closed: false, tags-dict: (:))
#layer-of(todo-graph(rows: (row("c", deps: ("d",)), row("d", deps: ("c",)))))
