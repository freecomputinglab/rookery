---
id: rk-cache-bib-keys-drop-dead-cite-walk-871b6099
short-id: '8'
title: Cache bib keys, drop dead cite walk
priority: 4
labels:
- chore-core-review
deps: []
closed: false
---
The bibliography key list is re-parsed out of the raw `.bib`/`.yml` bytes on
every single call, once per note render, per window, per nested expansion and
per page. Publish it once instead. The same change removes a dead pair of
functions that are the only other reader of that parse.

Touches: /home/lox/code/_fcl/rookery/core/0.1.0/src/state.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/src/pure.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/src/template.typ,
/home/lox/code/_fcl/rookery/core/0.1.0/src/bib.typ

## What is wrong

`_bib-keys()` (`src/state.typ:133-153`) converts every configured bibliography
source to a string with `str(s)` and runs
`text.matches(regex("@\\w+\\s*\\{\\s*([^,\\s]+)\\s*,"))` over the whole thing
(or `yaml(s).keys()` for a Hayagriva source). That is proportional to the size
of the author's bibliography file, and it is redone from scratch on every call.

Its live caller is `_own-cited-keys` (`src/bib.typ:114-125`), whose first line
is `let keys = _bib-keys()`. `_own-cited-keys` is called nine times across the
package and marrow — `src/idea.typ:437`, `src/idea.typ:466`,
`src/transclusion.typ:267`, `src/transclusion.typ:283`,
`src/transclusion.typ:387`, `src/transclusion.typ:397`, `src/window.typ:452`,
`src/template.typ:312`, and `.marrow.typ:371` — which works out to at least one
full re-parse per rendered note, one per rendered window, one per page, and one
per minted note page. A site with a hundred notes re-parses its bibliography
several hundred times per build.

The answer cannot change during a build: it is derived from the `arguments`
value `#show: rookery` publishes on `_bib` and from nothing else.

### The dead pair that comes out with it

`_cited-keys` (`src/state.typ:155-159`) has no callers at all. Confirmed by
grepping the whole repository for `_cited-keys`: the only hits are its own
definition and two comment mentions in `src/bib.typ` (lines 31 and 47). It is
not imported by `/home/lox/code/_fcl/rookery/core/0.1.0/test/units.typ` (whose
import list is lines 19-27), not imported by
`/home/lox/code/_fcl/rookery/core/0.1.0/.marrow.typ` (import list, line 92),
and not used by any other package in this repo.

`_cite-walk` (`src/pure.typ:182-201`) exists only to serve `_cited-keys` —
grepping the repository shows uses at `src/state.typ:158` and the recursion
inside `_cite-walk` itself, and nowhere else. The live citation walk is
`_cite-scan` in `src/bib.typ:53-97`, which is a different function and stays.

Line numbers are as of filing. If they have shifted, match the quoted text.

## Decisions already made — do not re-derive

- **The cache is a second state, not a change to `_bib`'s shape.**
  `test/units.typ:317-322` sets the bibliography by writing `_bib` directly
  (`#_bib.update(arguments((bytes("@article{smith2020,..."), bytes("jones2021:..."))))`)
  and never calls `rookery()`. So the cache must default to `none` and
  `_bib-keys()` must fall back to parsing when it is `none`, or that fixture
  breaks. Changing what `_bib` holds would break it outright.
- **The parse moves to `pure.typ` as a function of its argument**, because that
  is where this package keeps helpers that read no document state (see that
  file's header). It takes the `arguments` value (or `none`) and returns an
  array of strings, so `rookery()` can call it with no context at all.
- **Keep the public name `_bib-keys()` and its signature.** `test/units.typ`
  imports it (line 20) and asserts `_bib-keys() == ("smith2020", "jones2021")`
  at line 321.

## Steps

1. In `/home/lox/code/_fcl/rookery/core/0.1.0/src/pure.typ`, add a new
   function that is the parse currently inlined in `_bib-keys`:

   ```typ
   #let _bib-keys-of(cfg) = {
     if cfg == none { return () }
     let src = cfg.pos().first()
     let sources = if type(src) == array { src } else { (src,) }
     let keys = ()
     for s in sources {
       let text = str(s)
       // Format is detected from the CONTENT, since bytes carry no filename. A
       // Hayagriva file is a YAML mapping and has no `@type{` entry headers; a
       // BibTeX file is nothing but those.
       let entries = text.matches(regex("@\\w+\\s*\\{\\s*([^,\\s]+)\\s*,"))
       if entries.len() > 0 {
         keys += entries.map(m => m.captures.first())
       } else {
         keys += yaml(s).keys()
       }
     }
     keys
   }
   ```

   Put it where `_cite-walk` is being deleted from (step 4), i.e. after
   `_rel-prefix` and before `_dedup-tag`. It depends on no other name in the
   file, so its position is free.

2. In `/home/lox/code/_fcl/rookery/core/0.1.0/src/state.typ`, immediately after
   the `_bib` state (line 123), add the cache state:

   ```typ
   // The key list of the configured bibliography, published once by
   // `#show: rookery` so `_own-cited-keys` does not re-parse the whole source
   // on every note, window and page. `none` means "not published" — a document
   // that writes `_bib` directly (the unit fixture) still gets the answer from
   // the fallback parse below.
   #let _bib-key-cache = state("rheo-idea-bib-keys", none)
   ```

3. Replace the body of `_bib-keys()` (`src/state.typ:133-153`) with the cache
   read plus the fallback, keeping its comment banner (lines 125-132) intact:

   ```typ
   #let _bib-keys() = {
     let cached = _bib-key-cache.final()
     if cached != none { return cached }
     _bib-keys-of(_bib.final())
   }
   ```

4. Delete `_cited-keys` entirely — `src/state.typ:155-159`, the whole
   `#let _cited-keys(body) = { ... }` block — and delete `_cite-walk` entirely
   from `src/pure.typ`, both its `#let _cite-walk(node) = { ... }` body (lines
   192-201) and the comment banner that belongs to it (lines 182-191, beginning
   "Every bibliography key cited in this content, in document order.").

5. In `/home/lox/code/_fcl/rookery/core/0.1.0/src/bib.typ`, two comment lines
   now name a function that no longer exists. Reword them minimally, changing
   nothing else in the file:
   - line 31, `// \`_cited-keys\` answers "what does this content cite", which is a CONTENT`
     — rewrite the sentence so it names `_cite-scan` (`src/bib.typ:53`), which
     is the walk that answers the content question here.
   - line 47, `// heading, which is precisely what \`_cited-keys\` exists to prevent, arriving`
     — replace `_cited-keys` with `_own-cited-keys`, which is the function that
     prevents the empty heading.

6. In `/home/lox/code/_fcl/rookery/core/0.1.0/src/template.typ`, inside
   `rookery()`, hoist the defaulted bibliography arguments out of the
   `_bib.update` closure (currently lines 180-184) and publish the cache beside
   it:

   ```typ
   let bib-args = if bibliography == none { none } else {
     let named = bibliography.named()
     if "style" not in named { named.insert("style", "chicago-author-date") }
     arguments(..bibliography.pos(), ..named)
   }
   _bib.update(_ => bib-args)
   // Parsed ONCE for the document. `_own-cited-keys` runs per note, per window
   // and per page, and the answer cannot change during a build.
   _bib-key-cache.update(_bib-keys-of(bib-args))
   ```

   Keep the existing comment block above `_bib.update` (lines 168-179,
   "Default the style to author-date...") where it is. Note the two different
   update forms and keep them as written: `_bib.update(_ => bib-args)` needs the
   `_ =>` wrapper because an `arguments` value must not be mistaken for an
   updater, while `_bib-key-cache.update(..)` takes the array directly — an
   array is not a function. That discipline is documented at
   `src/state.typ:194-197`.

## Do NOT

- Do not change what `_bib` holds, or its state key string `"rheo-idea-bib"`.
- Do not touch `_cite-scan` (`src/bib.typ:53`), `_own-cited-keys`
  (`src/bib.typ:114`), `_refs-block`, `_sweep-block` or `_bib-call`.
- Do not edit `test/units.typ`. It must pass unchanged; that is the point of
  the `none` default on the cache.
- Do not attempt to grow `_bib-keys-of` into a bibliography parser. It answers
  "does this key exist" and nothing else — Typst formats every citation and
  every entry (see the banner at `src/state.typ:125-132`).
- Do not reword any comment other than the two lines named in step 5. Separate
  birds cover the comment prose in these files.

## VERIFY

```sh
cd /home/lox/code/_fcl/rookery/core/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/pure && just build
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check-typst
```

Expected last lines: `units OK`, `demo/pure OK`, `demo/rheo OK`,
`demo/rheo (native) OK`. All four are green today.

The first exercises the FALLBACK path (`test/units.typ` writes `_bib` directly,
so the cache is `none`) and asserts the parsed keys. The third exercises the
CACHED path: `demo/rheo` configures a real bibliography and its `check.sh`
asserts on the references blocks a note renders, which are built from
`_own-cited-keys` and therefore from the cache.

Also confirm nothing still names the deleted functions:

```sh
cd /home/lox/code/_fcl/rookery && grep -rn "_cited-keys\|_cite-walk" --include=*.typ .
```

Expected: no output.