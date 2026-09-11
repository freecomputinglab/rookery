---
id: rk-show-todo-tags-as-clickable-row-pills-781080cf
short-id: '78'
title: Show todo tags as clickable row pills
priority: 2
labels:
- today-panel
- type:feature
deps:
- blocked-by:rk-let-a-panel-pill-appear-more-than-once-f8c0b87f
- blocked-by:rk-let-an-idea-row-badge-be-raw-content-a7c93322
closed: false
---
A `#today-panel` row shows a badge strip on the right — `ready`, `blocked`, the epic, the priority — and the todo's own plain tags are missing from it. They exist as pills in the block above the list, so a reader can filter by `phd`, but cannot see that THIS row is the `phd` one without reading the pills against the rows. The strip is where a reader already looks for what a row IS, and the tags belong in it.

Two things follow from putting them there. First, a tag badge that looks like a chip but filters nothing is a tease: a reader who can see `phd` on a row wants to press it. Second, a strip mixing chip-shaped badges and pill-shaped ones says two things in two conventions on one line. So: when this is on, EVERY badge in the strip becomes the same object as the filter pill above — same markup, same look, same press — and pressing one in a row presses the filter.

Behind a knob, default OFF for `#todo-table` and default ON for `#today-panel`. `src/table.typ:459-471` records why the multi-valued facets were not chipped in the first place, and the reason is real and unchanged: `.idea-row` is a `<gutter> 1fr auto auto` grid whose last track is the strip, so a chip per tag makes the strip as wide as the widest row's tag list and squeezes every title on the page to pay for it — on a worklist of several hundred rows carrying between one and six tags each. A DAY VIEW is the case where that cost does not apply: it is a handful of rows, read whole, not scrolled (`src/today.typ:109-112`). So the day view turns it on and the worklist does not.

Touches: /home/lox/code/_fcl/rookery/todos/0.1.0/src/table.typ, /home/lox/code/_fcl/rookery/todos/0.1.0/src/today.typ, /home/lox/code/_fcl/rookery/todos/0.1.0/src/todos.css, /home/lox/code/_fcl/rookery/todos/0.1.0/demo/rheo/check.sh, /home/lox/code/_fcl/rookery/todos/0.1.0/readme.md

All paths below are under `/home/lox/code/_fcl/rookery/todos/0.1.0/`.

## What the two birds this one depends on have already done

Do not re-derive or re-do either. Both are prerequisites and both have landed before you start.

**`rk-let-a-panel-pill-appear-more-than-once-f8c0b87f`** (in `@rookery/search`) exported a top-level function `facet-pill(field, value, label: auto)` from `@rookery/search:0.1.0`. It emits exactly the button the pill block emits:

```html
<button type="button" class="panel-pill" data-panel-facet="tag" data-panel-value="phd" aria-pressed="false">phd</button>
```

`label: auto` renders `value.replace("-", " ")`, which is what the pill block does. That bird also taught `panel.js` to write `aria-pressed` onto EVERY `.panel-pill` carrying the same facet and value, and its click loop already binds every `.panel-pill` inside the panel container — rows included. So a pill you draw inside a row is a fully wired filter with no JavaScript of your own: pressing it filters the list, presses its twin in the block above, and writes to the URL when `sync:` is set.

**`rk-let-an-idea-row-badge-be-raw-content-a7c93322`** (in `@rookery/core`) made `#idea-row-body`'s `badges:` accept an entry that is CONTENT as well as an entry that is a `(text: .., tag: ..)` dictionary. A dictionary still renders `<span class="idea-tag idea-tag-<tag>" data-rookery="tag">`; content is placed in the strip verbatim, and the caller owns its element and classes.

## Decisions already made — do not re-derive

**One knob, not two.** `badge-pills` turns on both halves at once: the multi-valued facets join the strip, AND every badge in the strip is drawn as a `facet-pill` instead of a chip. They are not separable in any way worth a second argument — chipped tags that are not pressable is the tease above, and pill-shaped state beside chip-shaped tags is the two-conventions problem.

**`#today-panel` defaults it ON.** That is a second default it changes on the way in, alongside `visible:`. The demo at `demo/rheo/content/index.typ:256` (`#today-panel(today: TODAY, noun: "todos")`) therefore picks the new behaviour up with no edit, which is what the VERIFY below reads.

**The priority label rule survives untouched.** `src/table.typ:473-474` drops the `priority` facet from the strip when the row draws its priority as a `P<n>` LABEL in the date cell, because the label IS that chip, moved — a row would otherwise say one thing twice at opposite ends. Keep that filter exactly as it is, whatever `badge-pills` is.

**No CSS fight.** `@rookery/core`'s chip rule (`[data-rookery="row-badges"] > [data-rookery="tag"]`, `core.css:1212-1234`) is UNLAYERED, and unlayered CSS beats layered CSS whatever the specificity — so `@layer todos` could never have restyled a chip into a pill. It does not have to: a `facet-pill` is a `<button class="panel-pill">` carrying no `data-rookery="tag"`, so that rule does not match it at all and `@rookery/search`'s own `.panel-pill` rules (`search.css:841-864`) style it exactly as they style the ones above the list. This is the whole reason the pill is its own element rather than a themed chip.

**No new JavaScript in this package.** `src/todos.js` is untouched and `typst.toml`'s script lists do not change.

## Steps

1. `src/table.typ:30`, the import, currently reads `#import "@rookery/search:0.1.0": panel`. Change it to `#import "@rookery/search:0.1.0": facet-pill, panel`.

2. `src/table.typ`, `#todo-table`'s signature: add a `badge-pills: false,` argument immediately after `undated-priority: true,` (line 264) and before `visible: 8,` (line 265). Document it in this file's register, saying: what it draws (every badge in the row's strip becomes the same pressable pill the block above draws, and the multi-valued facets — `tag`, the only entry in `_MULTI` at line 79 — join the strip); why it is OFF here (the grid-width argument at lines 459-471, restated, not merely cross-referenced); where it is ON (`#today-panel`); and that it does nothing under a caller-supplied `render:`, which owns the whole row.

3. `src/table.typ`, the `badges:` argument of the `idea-row-body(..)` call at lines 473-478. It currently reads:

   ```typst
   badges: facets
     .filter(f => f != "priority" or pri-label == none)
     .filter(f => f not in _MULTI)
     .map(f => r.at(f, default: none))
     .filter(v => v != none and v != "")
     .map(v => (text: v.replace("-", " "), tag: v)),
   ```

   Replace it with a loop, because a multi-valued facet contributes SEVERAL badges and `.flatten()` would flatten the `(facet, value)` pairs as well as the array of them:

   ```typst
   badges: {
     let out = ()
     for f in facets {
       // THE PRIORITY CHIP GOES WHERE THE LABEL IS DRAWN — unchanged, see above.
       if f == "priority" and pri-label != none { continue }
       // THE MULTI-VALUED FACETS JOIN THE STRIP ONLY UNDER `badge-pills`.
       if not badge-pills and f in _MULTI { continue }
       let v = r.at(f, default: none)
       let vals = if f in _MULTI {
         if v == none { () } else { v }
       } else if v == none { () } else { (v,) }
       for value in vals.filter(x => x != "") {
         out.push(if badge-pills {
           facet-pill(f, value)
         } else {
           (text: value.replace("-", " "), tag: value)
         })
       }
     }
     out
   },
   ```

   Keep the existing comment block at lines 459-472 and amend it rather than deleting it: the reasoning about the grid is still the reason the default is the default, and the paragraph saying the multi-valued ones are never chipped now has a stated exception.

   With `badge-pills: false` this must emit exactly what it emitted before — same badges, same order, same dictionaries — which is what VERIFY step 3 checks on the built page.

4. `src/today.typ`, `#today-panel`'s signature: add `badge-pills: true,` among the forwarded `#todo-table` knobs, immediately after `undated-priority: true,` (line 108). The comment at lines 94-97 says these are forwarded unchanged with the same defaults, so say in one sentence why this one is not: a day view is a handful of rows read whole, so the grid-width cost the worklist default avoids does not apply, and the tags a reader can see are the tags they can press.

5. `src/today.typ`, the `todo-table(..)` call: add `badge-pills: badge-pills,` after `undated-priority: undated-priority,` (line 150).

6. `src/todos.css`, inside the existing `@layer todos { .. }` block (it opens at line 18): add a rule keeping a two-word pill on one line in the strip. `.panel-pill` sets no `white-space`, and `in progress` is a real value, so a narrow row can break it in half:

   ```css
   /* A PILL IN A ROW'S BADGE STRIP, not in the block above it. `.panel-pill`
      (@rookery/search) styles it whole — this only stops a two-word value
      (`in progress`) breaking across two lines in a strip that is the grid's
      last `auto` track. Layered safely: core's unlayered chip rule matches
      `[data-rookery="tag"]` and a pill is not one, and search sets no
      `white-space`, so nothing competes with this. */
   [data-rookery="row-badges"] > .panel-pill {
     white-space: nowrap;
   }
   ```

7. `demo/rheo/check.sh`: add a python assertion block after the existing `TODAY` block (the one ending `sys.exit(bad)` / `TODAY`) and before the final `if [ "$fail" -eq 0 ]` line. Follow the file's existing shape exactly — `python3 - "$H/index.html" <<'PY' || fail=1`, a local `note()` that sets `bad`, a summary `print` on success. Slice the same two sections the file already slices, and assert:
   - In the today section (from `h.index("Today —")` to `h.index("The dependency graph", ..)`): at least one `<li class="panel-row` contains `class="panel-pill"` with `data-panel-facet="tag"`. The `ship` row is the one to name — the existing `TODAY` block already pins the panel's four rows as `mirror`, `invoice`, `renew`, `ship`, and the existing `PANEL` block pins `ship` as the row carrying both plain tags (`data-tag=" frontend phd "`). So assert that the row whose title href is `ideas/ship.html` carries pills for BOTH `frontend` and `phd`.
   - In the today section: every in-row pill ships `aria-pressed="false"`, so the no-JS page shows nothing as pressed.
   - In the `#todo-table` section (from `h.index("Filter them in groups")` to `h.index("Today —", ..)`): NO `<li class="panel-row` contains `panel-pill`. This is the default-unchanged claim, and it is the assertion that would catch the knob being wired the wrong way round.

8. `readme.md`: document the argument. In `## Grouped pills: #todo-table` (line 361 onward) add `badge-pills` to the knobs described, with the grid-width reason for its default. In `## A day view: #today-panel` (line 505 onward), line 522 currently reads "The one default it changes on the way in is `visible:`" — that sentence is now false and must be corrected to name both `visible:` and `badge-pills:`, with a sentence on what the day view's strip therefore shows and that pressing a tag in a row filters the list.

## Do NOT

- Do not change `#todo-table`'s default. A worklist of several hundred rows keeps the strip it has.
- Do not touch `src/todos.js`, `src/todo-search.js`, `src/layout.js` or `typst.toml`. This bird adds no JavaScript and ships no new script.
- Do not change `_MULTI` (line 79), `_tags-of` (lines 115-126), `_state-of` (lines 128-134), `tag-filter:`, `pill-rows:`, `facets:`, or anything about which pills the block above the list offers. The row's pills are drawn from the values the row already carries and must never be a different vocabulary from the block's.
- Do not edit `@rookery/search` or `@rookery/core`. Both were changed by the birds above; if `facet-pill` is not importable or a content badge does not render, stop and report it rather than patching another package from inside this flight.
- Do not add an `aria-label` scheme, a tooltip, or a "clear all filters" control. A row pill is the block's pill drawn a second time, nothing more.
- Do not change `/home/lox/code/waterline` or any other consuming site. `#today-panel`'s new default is what reaches them.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just test && just test-js` — both green. Neither suite covers the strip, so this is a regression check, not the proof.
2. `cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just check` — builds the demo with rheo and runs `demo/rheo/check.sh`, including the new block from step 7. It must print `demo/rheo OK`.
3. The default really is unchanged, asserted on bytes rather than by eye: before editing, run `cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just check` and save the built page with `cp demo/rheo/build/html/index.html /tmp/todos-before.html`. After the change, rebuild and compare ONLY the `#todo-table` section — `python3 -c "import re,sys; a=open('/tmp/todos-before.html').read(); b=open('demo/rheo/build/html/index.html').read(); f=lambda h: h[h.index('Filter them in groups'):h.index('Today —')]; print('SAME' if f(a)==f(b) else 'DIFFERENT')"` must print `SAME`.
4. `grep -c 'class="panel-pill"' demo/rheo/build/html/index.html` is strictly greater after the change than before, and the increase is all inside the today section.