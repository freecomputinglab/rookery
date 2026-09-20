---
id: rk-add-outline-target-idea-front-door-52bfc795
short-id: '52'
title: 'Add outline(target: idea) front door'
priority: 3
labels:
- feat-outline-target-idea
deps:
- blocked-by:rk-replace-rookery-wide-with-scope-on-64195060
closed: true
---
Touches: core/0.1.0/src/outline.typ, core/0.1.0/readme.md, core/0.1.0/demo/rheo/content/relations.typ

`@rookery/core` exports `#ideas-outline(..)` for a table of contents over ideas and leaves
Typst's `#outline(..)` alone. Typst's own idiom for an outline over something that is not a
heading is a `target:` argument — `#outline(target: figure.where(kind: image))` — so the rookery
spelling should be `#outline(target: idea)`, with every other target handed straight to Typst.

This bird adds that front door. `#ideas-outline` STAYS, exported and unchanged, as the
implementation and as the name that needs no argument.

**Depends on the bird that replaces `rookery-wide:` with `scope:` on `#ideas-outline`.** That
one lands first; this one forwards whatever argument list `#ideas-outline` has when it flies. If
you find `rookery-wide:` still in `#ideas-outline`'s signature, the dependency has not landed —
report that rather than working around it.

Two facts make the dispatch straightforward, both already true in this package:

- **Comparing a function value by identity works and is already done here.** `#ideate` accepts
  `separator: par` and tests it with `separator == par or separator == parbreak`
  (`core/0.1.0/src/ideate.typ` line 361 as of filing). `target == idea` is the same test.
- **`std.` is reachable and already used.** `core/0.1.0/src/template.typ` line 674 calls
  `std.footnote(..)`, `core/0.1.0/src/base.typ` line 24 calls `std.target()`.

## Steps

1. **Find where the new function goes.** `#ideas-outline`'s signature:

   ```
   rg -n 'let ideas-outline' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   One hit as of filing, `outline.typ` line 449. Read it through to its closing brace. The new
   `outline` goes immediately after it, at the end of the file: a Typst `#let` closure captures
   the scope visible at definition time, and this one calls `ideas-outline`.

2. **`idea` is already in scope in this file.** `outline.typ` opens with a run of imports
   including `#import "idea.typ": *` (line 14 as of filing). Add no import. If that line has
   gone, report the miss rather than adding an import of your own — the import order in this
   package is load-bearing and documented in `src/lib.typ`.

3. **Write the function**, with its own header comment in the file's style. Say what it is and
   why the dispatch is on a bare function value rather than a selector; do not narrate the
   change or name a bird, per the comment rules in the repo's `CLAUDE.md`.

   ```typ
   #let outline(target: heading, ..args) = {
     assert(
       args.pos().len() == 0,
       message: "@rookery/core: #outline takes no positional arguments — got "
         + str(args.pos().len()) + ".",
     )
     if target == idea { return ideas-outline(..args) }
     let idea-only = args.named().keys().filter(k => k in ("tags", "match", "filter", "scope"))
     assert(
       idea-only.len() == 0,
       message: "@rookery/core: #outline got " + repr(idea-only) + ", which only an outline "
         + "over ideas takes — write #outline(target: idea, ..) for that, or drop the "
         + "argument for Typst's own outline over headings.",
     )
     std.outline(target: target, ..args)
   }
   ```

   Two things in there are load-bearing and belong in the comment. **`std.outline`, never a bare
   `outline(..)`**: from this `#let` onwards the bare name means THIS function, so an unqualified
   call recurses forever. And **the `idea-only` check exists because the arguments are silently
   wrong otherwise** — `#outline(tags: "draft")` with no target would forward `tags:` to
   `std.outline`, which fails with Typst's own message naming `outline`, confusing because the
   author did write `outline`. `scope` is in that list for the same reason as the other three: it
   means nothing to a heading outline.

4. **Update the comment that says Typst's outline cannot do this.** Find it:

   ```
   rg -n "Typst.s own .#outline" /home/lox/code/_fcl/rookery/core/0.1.0/src/outline.typ
   ```

   Hits at lines 172, 176, 391 and 397 as of filing; the one to edit is the header block above
   `#ideas-outline` starting at line 172. Its explanation stays correct and stays where it is —
   an idea is a Typst `heading` only on the paged target, so a heading-targeted outline would see
   every idea on PDF and none on HTML. Add one sentence saying `#outline(target: idea)` is the
   front door onto this function and that every other target proxies to Typst's own. Leave the
   comments at 391 and 397 alone; they are about the outline's own title, not about targets.

5. **Document it in the readme.** Find the `#ideas-outline` section:

   ```
   rg -n 'ideas-outline\(\). lists the current page' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   One hit as of filing, line 1188. Add a short passage giving both spellings as equivalent and
   stating the rule for the proxy: with any target but `idea`, `#outline` IS Typst's — arguments,
   defaults and behaviour. Two example lines are enough:

   ```typst
   #outline(target: idea, tags: "draft")   // the ideas outline
   #outline()                              // Typst's own, over headings
   ```

   Say plainly that importing `@rookery/core` shadows `outline` in that file's scope, since a
   reader who did not expect a shadow needs to be told where it came from.

6. **Cover both branches in the rheo demo.** The page that already exercises outlines:

   ```
   rg -n 'ideas-outline\(title: \[Tagged phd\]' /home/lox/code/_fcl/rookery
   ```

   One hit as of filing, `core/0.1.0/demo/rheo/content/relations.typ` line 44. Below it add two
   calls — `#outline(target: idea, tags: "phd")` and a bare `#outline()` — so both branches
   compile in a real build. Leave the `#ideas-outline` calls above them exactly as they are:
   they are what proves the older spelling still works.

## Non-goals

- **Do not remove, rename or deprecate `#ideas-outline`.** It stays the implementation and a
  supported public name. No forwarding shim, no warning, no "prefer this" note in its comment.
- **Do not make the ideas branch accept a selector.** `target: idea` is the bare function value.
  A `heading.where(..)`-shaped selector over ideas is not something this package offers.
- **Do not change `#ideas-outline`'s own arguments** — not their names, not their defaults, not
  their asserts. This bird only routes.
- **Do not touch `#footnote`** or the `show FNK:` rule in `template.typ`. Core's other shadow is
  unrelated.
- **Do not add `#outline` to `.marrow.typ`'s import list** (`core/0.1.0/.marrow.typ`, one 33-name
  import). It calls no outline.

## VERIFY

1. `cd core/0.1.0 && just test` — prints `units OK`.
2. `cd core/0.1.0/demo/pure && just build` — succeeds. It star-imports core, so this is the check
   that a new public name named `outline` breaks no existing scope.
3. `cd core/0.1.0/demo/rheo && just check` — succeeds, exercising both new calls. (Needs the
   `rheo` binary, present at `~/.cargo/bin/rheo` when this bird was filed; if it is genuinely
   missing, say so in the report rather than skipping quietly.)
4. The heading branch really is Typst's. From `core/0.1.0`:

   ```
   mkdir -p demo/pure/build
   printf '#import "/src/lib.typ": *\n#show: rookery\n= A heading\n#outline()\n' > demo/pure/build/outline-proxy.typ
   typst compile --features html --root . --format pdf demo/pure/build/outline-proxy.typ /dev/null
   ```

   Must exit zero. Then `rm demo/pure/build/outline-proxy.typ`.
5. The rejection fires: the same three lines with `#outline(tags: "x")` as the body must exit
   non-zero with a message naming `target: idea`. Delete the scratch file afterwards.
6. `bd status <this bird's id>` reports `retired` after the flight lands.