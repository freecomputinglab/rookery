---
id: rk-let-a-panel-pill-appear-more-than-once-f8c0b87f
short-id: f8
title: Let a panel pill appear more than once
priority: 3
labels:
- panel
- type:feature
deps: []
closed: true
---
`@rookery/search`'s `#panel` emits its filter pills in exactly one place — the pill block above the list — and `panel.js` assumes that, so each facet value has exactly one button on the page. `@rookery/todos` now wants the same pill to appear a second time INSIDE a row, as the row's own tag badge, so that a reader can press a tag where they read it rather than hunting for it in the block above. Two things stop that today: the pill markup is a closure private to `#panel`, so a consumer can only hand-copy it; and `panel.js` writes `aria-pressed` onto the clicked button alone, so two copies of one pill would disagree about whether the filter is on.

This bird makes a pill a REUSABLE OBJECT and makes pressed state a property of the FACET VALUE rather than of the button. It changes nothing about which rows a panel shows.

Touches: /home/lox/code/_fcl/rookery/search/0.1.0/src/panel.typ, /home/lox/code/_fcl/rookery/search/0.1.0/src/panel.js, /home/lox/code/_fcl/rookery/search/0.1.0/test/paneldupes.test.mjs

All paths below are under `/home/lox/code/_fcl/rookery/search/0.1.0/`.

## Decisions already made — do not re-derive

**Mirror, do not delegate.** The alternative was leaving the markup alone and having the consumer's own script forward a click from a row chip to the matching pill in the block. It was rejected: a forwarded click needs the consumer to reimplement the pill's look, its `cursor`, its focus ring and its keyboard behaviour, and a `<span>` with a click handler is not a button to assistive technology. A real second `<button class="panel-pill">` gets all of that for free, and the only thing that has to change is that `aria-pressed` is written to every copy instead of to one.

**`aria-pressed` stays the single source of truth.** `panel.js:346-347` already records that nothing carries a pressed CLASS, because a class would be a second source of truth and `search.css:860` keys off the attribute. Mirroring therefore means writing the attribute to every matching button — it does not mean introducing a class or a data attribute.

**Generic over both panel kinds.** `wirePanel` serves `#panel` (facet mode, pills carry `data-panel-facet` + `data-panel-value`) and `#filter-panel` (`data-panel-mode="tags"`, pills carry `data-panel-tag`). No duplicate pill exists in tag mode today, but the mirroring must be written for both so the two modes do not drift — the same reasoning `panel.js:144-148` gives for one wiring serving both.

**The exported helper takes the field and the value, not a row.** Its whole job is to emit one button whose attributes `panel.js` already knows how to read.

## Steps

1. `src/panel.typ`, lines 446-456, currently hold the pill markup as a closure local to `#panel`:

   ```typst
   let pill(field, value) = html.elem(
     "button",
     attrs: (
       type: "button",
       class: "panel-pill",
       "data-panel-facet": field,
       "data-panel-value": value,
       "aria-pressed": "false",
     ),
     value.replace("-", " "),
   )
   ```

   Lift it to a TOP-LEVEL `#let` named `facet-pill`, placed above `#panel` in the same file (anywhere before the function that uses it — a Typst closure captures the scope visible at definition time, which is why the order matters). Give it a `label:` argument defaulting to `auto`:

   ```typst
   #let facet-pill(field, value, label: auto) = html.elem(
     "button",
     attrs: (
       type: "button",
       class: "panel-pill",
       "data-panel-facet": field,
       "data-panel-value": value,
       "aria-pressed": "false",
     ),
     if label == auto { value.replace("-", " ") } else { label },
   )
   ```

   Write a short comment above it saying what it is for: the pill block below is one place a pill appears, and a consumer drawing a pill somewhere else (a badge inside a row) must emit the same markup or `panel.js` will not wire it. `src/lib.typ` star-imports `panel.typ`, so a top-level `#let` is exported from `@rookery/search:0.1.0` with no edit there.

2. Same file, in `#panel`: replace the deleted closure's call site. `group(f)` at lines 458-465 calls `pill(f, v)` — change that to `facet-pill(f, v)`. Nothing else in the file calls `pill`.

3. `src/panel.js`: add a mirroring helper inside `wirePanel`, after the `pressed` set is declared (line 183) and before the rows are read. `cssEscape` is already defined at the top of the file (lines 53-54) and is what the rehydrate path uses, because `CSS.escape` is absent under linkedom:

   ```js
   // ONE PILL, POSSIBLY SEVERAL BUTTONS. A facet value may be drawn more than
   // once on a panel — @rookery/todos draws a row's own tags as pills inside the
   // row — and `aria-pressed` is the state, so every copy has to carry the same
   // answer or the page shows one filter as both on and off.
   const mirror = (facet, value, on) => {
     const sel = tagMode
       ? `.panel-pill[data-panel-tag="${cssEscape(value)}"]`
       : `.panel-pill[data-panel-facet="${cssEscape(facet)}"][data-panel-value="${cssEscape(value)}"]`;
     for (const el of container.querySelectorAll(sel)) {
       el.setAttribute("aria-pressed", on ? "true" : "false");
     }
   };
   ```

4. Same file, the click loop at lines 348-366. It currently calls `pill.setAttribute("aria-pressed", ..)` in each branch of the toggle. Replace both of those with one `mirror` call after the set has been updated, so the attribute is written from the set rather than from the branch:

   ```js
   if (set.has(value)) set.delete(value);
   else set.add(value);
   mirror(pill.dataset.panelFacet, value, set.has(value));
   apply();
   persist();
   ```

   Leave the two early `return`s (`if (!set) return;`, `if (!value) return;`) exactly as they are. The loop itself still binds with `container.querySelectorAll(".panel-pill")`, which already reaches a pill drawn inside a row — the rows are inside the container — so no change is needed there.

5. Same file, the rehydrate block at lines 374-398. Both branches currently do `container.querySelector(..)` and `if (!pill) continue;`, then set the attribute on that one button. Rewrite each to add the value to the set and then call `mirror`, keeping the "a URL value naming a pill this markup does not carry is IGNORED" rule that the comment at lines 368-373 states. Test for absence with a `querySelectorAll` length, so the rule survives:

   ```js
   if (tagMode) {
     for (const v of st.values.get("t") ?? []) {
       const sel = `.panel-pill[data-panel-tag="${cssEscape(v)}"]`;
       if (container.querySelectorAll(sel).length === 0) continue;
       pressed.add(v);
       mirror(null, v, true);
     }
   } else {
     for (const [field, wanted] of st.values) {
       const set = facets.get(field);
       if (!set) continue;
       for (const v of wanted) {
         const sel = `.panel-pill[data-panel-facet="${cssEscape(field)}"][data-panel-value="${cssEscape(v)}"]`;
         if (container.querySelectorAll(sel).length === 0) continue;
         set.add(v);
         mirror(field, v, true);
       }
     }
   }
   ```

6. Add `test/paneldupes.test.mjs`, a new file so it conflicts with nothing. Copy the shape of `test/panelmulti.test.mjs` exactly — `import { parseHTML } from "linkedom"`, `import { wirePanel } from "../src/panel.js"`, a `PANEL` template string, a `wire()` helper that sets `globalThis.document` and dispatches `new document.defaultView.Event("click")`. Build a panel whose `state` group has a `ready` pill in the pill block AND a second `ready` pill inside one of the `.panel-row` list items, and assert:
   - pressing the pill in the BLOCK sets `aria-pressed="true"` on BOTH buttons;
   - pressing the pill inside the ROW sets `aria-pressed="true"` on both, and filters the list to the ready rows — i.e. an in-row pill is a working filter, not decoration;
   - pressing one copy and then the OTHER copy releases the filter (the set is toggled, not added to twice), and both buttons return to `aria-pressed="false"`;
   - with only one copy of a pill on the panel, behaviour is exactly as before: one press presses it, a second releases it.

## Do NOT

- Do not change `passesFacets`, `passesTags`, `accepts`, `apply`, or anything about which rows a panel shows. This bird is about button state only.
- Do not add a pressed CLASS, and do not stop using `aria-pressed`.
- Do not touch `src/search.css`. `.panel-pill` (lines 841-864) already styles any button carrying the class wherever it sits, which is the point.
- Do not touch `src/filter-panel.typ`, `src/urlstate.js`, or the sync format. The URL still carries one entry per pressed value, not one per button.
- Do not emit a pill anywhere new in this package — drawing one inside a row is `@rookery/todos`' job, in a separate bird.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery/search/0.1.0 && just test` — the whole `node --test test/*.test.mjs` suite is green, the new `paneldupes` file included. `panelmulti`, `panelsync`, `panelunion`, `panelinput` and `panelquery` must all still pass untouched: they each drive single-copy pills, which is the regression this could break.
2. `cd /home/lox/code/_fcl/rookery/search/0.1.0 && just build` succeeds (the JS change ships through `dist/lib.js`).
3. `grep -n 'facet-pill' src/panel.typ` shows the top-level `#let` and the call inside `group`, and `grep -c 'let pill(' src/panel.typ` returns 0 — the private closure is gone rather than left beside its replacement.
4. `bd show <this bird's id>` reports it in flight while you work; landing the flight retires it. Do not try to set a status.