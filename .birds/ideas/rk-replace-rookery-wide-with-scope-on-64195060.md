---
id: rk-replace-rookery-wide-with-scope-on-64195060
short-id: '641'
title: Replace rookery-wide with scope on outlines
priority: 3
labels:
- feat-outline-scope
deps:
- blocked-by:rk-unify-the-display-argument-surface-4fc02118
closed: true
---
Touches: core/0.1.0/src/outline.typ, core/0.1.0/readme.md, core/0.1.0/demo/pure/theme.typ, core/0.1.0/demo/rheo/content/relations.typ, core/0.1.0/demo/rheo/content/index.typ, core/0.1.0/demo/rheo/content/sub/deeper/page.typ, core/0.1.0/demo/rheo/check.sh, search/0.1.0/demo/rheo/content/index.typ

`#ideas-outline` scopes itself with `rookery-wide: false` — page-only by default, whole rookery
on request. Both halves of that are wrong once the outline is filtered. A tag selection reads
the whole registry, so `#ideas-outline(tags: "draft")` asks a rookery-wide question and then
discards every answer not written on the current page, which is rarely what the author meant
and reports nothing when it empties the list. And the name is a negative: the useful reading of
`rookery-wide: false` is "narrowed to this page", which the spelling states backwards.

Replace it with `scope:`, a string naming the breadth, defaulting to the whole rookery:

```typ
#ideas-outline()                      // every idea in the rookery
#ideas-outline(scope: "page")         // only the ideas written on this page
#ideas-outline(tags: "draft")         // every draft in the rookery — composes
```

**Why a string rather than a boolean.** This package already uses small string enums for
arguments that name a mode, and booleans only for on/off switches: `match: "any"` / `"all"`,
`#window`'s `sort: auto` / `"date"` / `"lexicographic"`, `#rookery`'s `page-titles: "title"`.
Scope is a mode, not a switch — a later `"branch"` or `"file"` value costs nothing here, where
a second boolean would have to contradict the first. `"page"` rather than `"file"` because
"page" is the word this package uses throughout for the unit an idea is written on: `page-titles`,
`_page-links`, `_page-href`, and "minted page" everywhere in the readme.

**THIS FLIPS A DEFAULT, and that is the point rather than a side effect.** A bare
`#ideas-outline()` lists the whole rookery after this change where it listed one page's ideas
before. Every call site in this repo is named in the steps below and must be updated so its
rendered output does not change; the one that genuinely wanted the page gets `scope: "page"`.

## Steps

1. **Replace the public argument.** Find the signature:

   ```
   rg -n 'let ideas-outline' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   One hit as of filing, `outline.typ` line 449; the parameter list runs over the next few
   lines with `rookery-wide: false,` at line 452. Replace that parameter with `scope: "rookery",`,
   keeping its position in the list.

2. **Replace its assert.** Directly inside the same function:

   ```
   rg -n 'must be a boolean' /home/lox/code/_fcl/rookery/core/0.1.0/src/outline.typ
   ```

   One hit as of filing, line 464, the `#ideas-outline's rookery-wide must be a boolean`
   message. A string enum needs a different check — model it on `#window`'s `sort` assert
   (`rg -n "sort. must be auto" /home/lox/code/_fcl/rookery/core/0.1.0/src/window.typ`, one hit,
   line 137 as of filing), which lists the legal values in its message:

   ```typ
   assert(
     scope == "rookery" or scope == "page",
     message: "@rookery/core: #ideas-outline's `scope` must be \"rookery\" — every idea in "
       + "the rookery, the default — or \"page\", only those written on this page. Got "
       + repr(scope),
   )
   ```

3. **Invert once, at the boundary, and nowhere else.** The private data pass keeps its own
   spelling:

   ```
   rg -n '_ideas-outline-data\(' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   Two hits as of filing — the definition at `outline.typ` line 247
   (`#let _ideas-outline-data(rookery-wide: false)`) and the call at line 475, inside
   `#ideas-outline`. Change ONLY the call, to
   `_ideas-outline-data(rookery-wide: scope == "rookery")`, with a one-line comment saying the
   public argument names the breadth and the private one is the boolean that breadth resolves
   to. Leave the definition's parameter name, its two internal uses (lines 297 and 373 as of
   filing) and the comments around them alone — a deliberate decision, not an oversight to tidy.

4. **Update the public doc comment above the function.** Find it:

   ```
   rg -n 'lists EVERY idea in the rookery instead of' /home/lox/code/_fcl/rookery/core/0.1.0/src
   ```

   One hit as of filing, `outline.typ` line 405, in the header block above `#ideas-outline`.
   Rewrite that passage to describe the argument as it now stands: the whole rookery is the
   default, `scope: "page"` narrows to the ideas written on this page, and `depth` composes with
   either. Keep the existing sentence explaining this costs nothing extra — the spine compiles
   as one Typst document, so it is a filter being lifted rather than a second pass.

5. **Update the readme.** Find the mentions:

   ```
   rg -n 'rookery-wide' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   Four hits as of filing. Line 1125 is prose about `#window`'s tag selection being rookery-wide
   — leave the claim, check it still reads correctly beside the new argument. Line 1194 is an
   `#ideas-outline(title: [Everything], rookery-wide: true)` example, which now drops the
   argument. Line 1217 is the `**rookery-wide: true**` documentation paragraph, which becomes the
   `scope` paragraph, states both values and says plainly which is the default. Line 2509 is
   prose contrasting something with `#ideas-outline(rookery-wide: true)` and needs the new
   spelling. In the `scope` paragraph, add one sentence recording that the default changed and
   what an upgrading reader writes to get the old behaviour back.

6. **Update the call sites that asked for the whole rookery.** They all become argument-free,
   since that is now the default:

   ```
   rg -n 'ideas-outline\(.*rookery-wide: true' /home/lox/code/_fcl/rookery
   ```

   Eight hits as of filing: `core/0.1.0/demo/pure/theme.typ:28`,
   `core/0.1.0/demo/rheo/content/relations.typ:43` and `:44`,
   `core/0.1.0/demo/rheo/content/sub/deeper/page.typ:135`, `:138` and `:141`,
   `core/0.1.0/demo/rheo/content/index.typ:105`, and
   `search/0.1.0/demo/rheo/content/index.typ:67`. Drop `rookery-wide: true,` from each, keeping
   every other argument exactly as it is. Where a comment above one explains the argument —
   `relations.typ` line 41 and `sub/deeper/page.typ` lines 129-134 as of filing — rewrite the
   comment to match, since those comments are about which form is being shown.

7. **Update the one call site that wanted the page.** In the same demo page:

   ```
   rg -n "ideas-outline\(title: \[This page" /home/lox/code/_fcl/rookery
   ```

   One hit as of filing, `core/0.1.0/demo/rheo/content/sub/deeper/page.typ` line 132. It is the
   page-scoped half of a pair that demo deliberately shows side by side, so it becomes
   `#ideas-outline(title: [This page's ideas], scope: "page")` — with the argument, not without.
   Its rendered output must not change.

8. **Update the demo's assertion comments.** `core/0.1.0/demo/rheo/check.sh` asserts that the
   page form and the rookery form differ:

   ```
   rg -n 'rookery-wide' /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo/check.sh
   ```

   Three hits as of filing, lines 405, 420 and 423 — two comments and one `print` message. The
   assertions themselves are about the OUTPUT and stay exactly as they are; update the wording
   so it names the two forms as they are now spelled.

## Non-goals

- **Do not rename `_ideas-outline-data`'s own parameter**, nor the `rookery-wide` reads at
  `outline.typ` lines 297 and 373. Step 3 is the whole of the inversion.
- **Do not give `#window` or `ideas()` a `scope` argument.** Both read the whole registry and
  have no page notion to narrow to; adding one is a feature, not this rename.
- **Do not add `filter:` or `sort:` anywhere.** A separate bird covers the selection arguments.
- **Do not add an `#outline` front door.** A separate bird adds `#outline(target: idea)` on top
  of this one.
- **Do not keep `rookery-wide` as an accepted alias.** One spelling. A call site passing the old
  name should fail, and it will: `#ideas-outline` has no argument sink, so Typst rejects an
  unknown argument by itself.
- **Do not edit another repo.** See the heads-up below.

## VERIFY

1. `cd core/0.1.0 && just test` — prints `units OK`.
2. `cd core/0.1.0/demo/pure && just build` — succeeds.
3. `cd core/0.1.0/demo/rheo && just check` — succeeds, including the assertions about the
   page-scoped and rookery-wide outlines differing. (Needs the `rheo` binary, present at
   `~/.cargo/bin/rheo` when this bird was filed; if it is genuinely missing, say so in the
   report rather than skipping quietly.)
4. `cd search/0.1.0/demo/rheo && just check`, or `just build` if that demo has no `check`
   recipe — succeeds with the edited call site.
5. `rg -n 'rookery-wide' core/0.1.0/src/outline.typ` returns only the private helper's own hits
   — nothing inside `#ideas-outline`'s parameter list or its assert.
6. `bd status <this bird's id>` reports `retired` after the flight lands.

## Heads-up, out of scope for this flight

`rookery.ohrg.org` — a SEPARATE repo at `/home/lox/code/_fcl/rookery.ohrg.org`, not this one —
calls a bare `#ideas-outline()` on four pages (`content/reference.typ`, `content/concepts.typ`,
`content/faq.typ`, `content/packages/core.typ` as of filing) and `rookery-wide: true` on two
more in `content/concepts.typ`. Every bare call there silently becomes a whole-rookery outline
once this lands. Do not edit that repo from this flight; report this line with the landing so
the operator can sequence the site's update.