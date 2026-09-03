# `@rookery/slipshow` examples

Five rheo projects, one per capability: a deck composed through
`@rookery/search`, a mixed `#idea`/`#slip` deck, backgrounds and fullscreen,
metadata-driven ordering, and a `@rookery/todos` dependency DAG presented
horizontally. Each is both an EXAMPLE — copy one to start a presentation of
your own — and a TEST — CI compiles every one of them.

## Shape

Every example is a complete rheo project:

```
<name>/
  rheo.toml
  content/
    lib.typ    # shared imports + the one `#show: rookery.with(..)` every page applies
    ...        # the pages themselves
```

`lib.typ` is a library, not a page — `[spine] exclude = ["lib.typ"]` in
`rheo.toml` keeps it out of the built site. A page imports it and applies the
show rule once:

```typ
#import "lib.typ": template
#show: template
```

`examples/_template/` carries this shape with no content beyond the show
rule wrapper; it starts with `_` so `just examples` (below) skips it — a
template proves nothing by compiling, it exists to be copied.

## Building

One example, by hand:

```sh
cd examples/<name> && rheo compile .
```

then open `build/html/index.html` in a browser. All five, from the package
root:

```sh
just examples
```

`dag` is the one example that imports `@rookery/todos`, and unlike this
package `todos` is a BUILT package — its `dist/lib.js` has to exist before
rheo can resolve it. `just examples` above builds `slipshow` itself but not
its sibling, so on a checkout where `todos` has never been built, compile it
first: `cd ../../todos/0.1.0 && just build`.

## Self-contained

No example imports from another, and there is no shared `examples/lib.typ`
above them: each is written as if it were the only directory in the
checkout, so it can be copied out of this repo and run unchanged (modulo
however your project already resolves the `@rookery` namespace — see
`examples/_template/rheo.toml` for the override this repo's own copies need
and why).

## The one shared gotcha

Typst silently drops `grid` in HTML export. A table inside a slip must be a
borderless `table`, never a `grid`: a `grid` compiles clean, renders
correctly in a PDF build, and is EMPTY in the browser. Reach for `table` any
time an example needs tabular layout inside a slip.
