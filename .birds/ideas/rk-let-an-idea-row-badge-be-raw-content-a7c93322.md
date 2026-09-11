---
id: rk-let-an-idea-row-badge-be-raw-content-a7c93322
short-id: a7
title: 'Let an #idea-row badge be raw content'
priority: 3
labels:
- idea-row
- type:feature
deps: []
closed: false
---
`#idea-row-body`'s badge strip can only draw one kind of thing: a `<span class="idea-tag idea-tag-<tag>">`, built from a `(text: .., tag: ..)` dictionary. That is right for a chip, and wrong for the one case now in front of it — `@rookery/todos` wants a row's tags drawn as `@rookery/search`'s own filter pills, which are `<button>`s carrying `data-panel-*` attributes, so that pressing a tag where you read it presses the filter.

There is no way to get that through `badges:` today, and the alternatives are both bad. Re-emitting the row's four spans in the consumer so it can own the strip is the fifth hand copy this file's header (lines 1-26) exists to prevent. Bolting the pill into `badges:` as a fourth special case would make the row ask questions about what a badge means, which is exactly what "cells arrive formatted" (lines 22-26) says it must not do.

So: let a badge entry BE CONTENT. A dictionary keeps doing exactly what it does now; anything else is placed in the strip verbatim and the caller owns its element, its classes and its attributes. This is the same hole `when-class:`/`when-attrs:` already are one level in (lines 55-67), opened for the same consumer and for the same reason.

Touches: /home/lox/code/_fcl/rookery/core/0.1.0/src/row.typ

All paths below are under `/home/lox/code/_fcl/rookery/core/0.1.0/`.

## Decisions already made — do not re-derive

**Content, not a second dictionary key.** A `(elem: .., attrs: .., class: ..)` badge shape would put a small markup DSL in this file and still not cover the next case. Content covers every case and adds no vocabulary: the strip is a `<span class="idea-row-badges">` and a caller puts whatever it wants inside it.

**Additive and byte-identical by default.** Every existing caller passes dictionaries — `@rookery/search`'s `src/filter-panel.typ:280`, `@rookery/timeline`'s `src/upcoming.typ:409`, `@rookery/todos`' `src/table.typ:473`. With dictionaries in, the emitted markup after this change must be exactly what it was before.

**No styling change.** `src/core.css:1212-1234` styles a chip through `[data-rookery="row-badges"] > [data-rookery="tag"]`, i.e. on the CHILD's own attribute — so a content badge that is not a `[data-rookery="tag"]` simply does not match it and takes whatever its own package styles it with. That is deliberate and needs no CSS edit here. Note for your own awareness: that rule is UNLAYERED, so a downstream package's layered rule cannot override the properties it sets — which is precisely why the todos pill has to be its own element rather than a restyled chip.

**The empty-strip rule stands.** `badges.len() > 0` (line 120) still decides whether the strip is emitted at all, for the reason lines 107-109 give: an empty `<span>` still takes a grid track and costs a whole line on a narrow row.

## Steps

1. `src/row.typ`, the badge strip at lines 120-135. The `.map(b => html.elem(..))` currently assumes every entry is a dictionary. Branch on the type instead, leaving the dictionary arm exactly as it is:

   ```typst
   badges
     .map(b => if type(b) == dictionary {
       html.elem(
         "span",
         attrs: (class: _c("tag") + " " + _c("tag-" + b.tag), data-rookery: "tag", data-rookery-tags: b.tag),
         b.text,
       )
     } else { b })
     .join()
   ```

   Keep the existing comment about `data-rookery-tags` being inlined rather than shared with `_tags-attr` on the dictionary arm, where it belongs.

2. Same file, document the hole in the comment block above the strip (lines 107-119) and in the `badges:` argument's own documentation. Say, in this file's register: a badge is a `(text: .., tag: ..)` dictionary for the ordinary chip, OR content, which is placed in the strip verbatim. Give the reason — a consumer needing a badge that is a BUTTON (a pressable filter pill) can have one without re-emitting the row's four spans to get at the strip — and state the boundary: the row still asks nothing about what a badge means, and core styles only the chip form.

3. `#idea-row` (lines 144-192) passes `badges:` straight through to `#idea-row-body` and needs no edit. Confirm that by reading it; do not change it.

## Do NOT

- Do not change the `<span class="idea-row-badges">` wrapper, its classes, or the `badges.len() > 0` guard.
- Do not add CSS. `src/core.css` keeps exactly the rules it has.
- Do not touch `when`, `iso`, `soft`, `when-class`, `when-attrs`, `title`, `href` or `cells`.
- Do not update any consumer in this repo. `@rookery/search`, `@rookery/timeline` and `@rookery/todos` all pass dictionaries and must keep working untouched; drawing a pill in a row is a separate bird in `@rookery/todos`.
- Do not add a JavaScript file to this package. Core ships no JS and that rule (lines 19-20) is not what this bird relaxes.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery/core/0.1.0 && just test` — both fixture compiles are green.
2. `cd /home/lox/code/_fcl/rookery/core/0.1.0 && rheo compile demo/rheo && ./demo/rheo/check.sh` — the demo still builds and its output assertions pass. This is the check that would catch a broken dictionary arm, since the demo's rows carry ordinary chips.
3. The dictionary path is unchanged in the OUTPUT, not merely in the source: after the demo build above, `grep -c 'data-rookery="tag"' demo/rheo/build/html/index.html` returns the same number it did before your edit. Record that number by running the grep on the built page BEFORE you edit `src/row.typ`.
4. `cd /home/lox/code/_fcl/rookery/timeline/0.1.0 && just test` (and `just check` if that recipe exists) — `#upcoming` is the other in-repo caller of `badges:` and must be unaffected.