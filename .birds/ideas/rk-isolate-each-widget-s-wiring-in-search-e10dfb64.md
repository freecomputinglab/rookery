---
id: rk-isolate-each-widget-s-wiring-in-search-e10dfb64
short-id: e1
title: Isolate each widget's wiring in search init
priority: 5
labels:
- fix-safari-search-modal
deps:
- blocked-by:rk-wire-search-triggers-before-the-index-7974cadf
closed: false
---
`init()` in `/home/lox/code/_fcl/rookery/search/0.1.0/src/search.js` (line 63) is
one unguarded async chain over every widget this package ships: `initPanels()` at
line 67, `initUrlSync()` at line 68, then the bars, then the modals and their
triggers. Nothing in it is wrapped, and `init` is called from a bare
`document.addEventListener("DOMContentLoaded", init)` at the bottom of the file
with no `.catch`.

So a single throw anywhere in that chain aborts everything after it and surfaces
only as an unhandled promise rejection, which most readers never see. One
malformed panel on one page silently kills that page's search modal; one
unexpected DOM shape in `wirePanel` kills every panel after it as well as the
search. The failure looks, from the reader's side, exactly like the Safari bug
report this bird's predecessor came from: a control that does nothing, with no
explanation.

`wirePanel` is the realistic thrower. It is 200 lines of DOM reading in
`/home/lox/code/_fcl/rookery/search/0.1.0/src/panel.js` (exported at line 135,
called in a loop by `initPanels` at the bottom of that file), and it indexes into
per-row value objects — `accepts()` at line 66 does
`row.values[field].has(v)` — on shapes the Typst side is trusted to have
produced. A page mixing an older build's markup with a newer script is enough.

The fix is one `try`/`catch` per independently useful widget, so a failure is
reported and contained rather than propagated.

Touches: /home/lox/code/_fcl/rookery/search/0.1.0/src/search.js, /home/lox/code/_fcl/rookery/search/0.1.0/src/panel.js

## Steps

1. In `/home/lox/code/_fcl/rookery/search/0.1.0/src/panel.js`, find `initPanels`
   at the end of the file:

   ```js
   export const initPanels = () => {
     let n = 0;
     for (const c of document.querySelectorAll(".panel")) wirePanel(c, n++);
   };
   ```

   Wrap each call so one bad panel cannot take the rest of the page with it:

   ```js
   // ONE PANEL'S FAILURE IS ONE PANEL'S. `wirePanel` reads shapes the Typst side
   // is trusted to have emitted, and a page mixing an older build's markup with
   // this script is enough to throw — which, uncaught, would also take the
   // search modal wired after it.
   export const initPanels = () => {
     let n = 0;
     for (const c of document.querySelectorAll(".panel")) {
       try {
         wirePanel(c, n++);
       } catch (err) {
         console.error("@rookery/search: a #panel could not be wired and is left as a plain list.", c, err);
       }
     }
   };
   ```

   A panel that fails to wire keeps `data-panel-ready="false"`, which
   `src/search.css` already styles as an ordinary complete list with no chrome —
   so the degraded state needs no new CSS.

2. In `/home/lox/code/_fcl/rookery/search/0.1.0/src/search.js`, guard the two
   unconditional initialisers at lines 67-68. Replace:

   ```js
     initPanels();
     initUrlSync();
   ```

   with:

   ```js
     // Guarded individually: panels, URL sync and search are independent
     // features that happen to share one entry point, and one of them failing
     // must not silently disable the other two.
     try { initPanels(); } catch (err) {
       console.error("@rookery/search: panels could not be initialised.", err);
     }
     try { initUrlSync(); } catch (err) {
       console.error("@rookery/search: URL sync could not be initialised.", err);
     }
   ```

3. Still in `search.js`, give the auto-init at the bottom of the file a rejection
   handler. The current tail is:

   ```js
   if (typeof document !== "undefined") {
     if (document.readyState === "loading") {
       document.addEventListener("DOMContentLoaded", init);
     } else {
       init();
     }
   }
   ```

   Make both paths report instead of rejecting into the void:

   ```js
   if (typeof document !== "undefined") {
     const boot = () => {
       init().catch((err) => {
         console.error("@rookery/search: initialisation failed.", err);
       });
     };
     if (document.readyState === "loading") {
       document.addEventListener("DOMContentLoaded", boot);
     } else {
       boot();
     }
   }
   ```

## Non-goals

- Do NOT wrap `wire` (the bar) or `wireModal` in their own try/catch. Both
  already return `null` on a markup shape they cannot use, and adding a catch
  around a function that does not throw is noise.
- Do NOT change what `initPanels` or `initUrlSync` do on the success path.
- Do NOT swallow anything silently. Every catch added here logs with
  `console.error` and names `@rookery/search`.
- Do NOT reorder the modal, trigger or keyboard wiring — that is the preceding
  bird's change and is already landed by the time this one flies.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery/search/0.1.0 && just test` — the node suite
   stays green. `test/paneldupes.test.mjs`, `test/panelsync.test.mjs`,
   `test/panelmulti.test.mjs`, `test/panelunion.test.mjs`,
   `test/panelquery.test.mjs`, `test/panelinput.test.mjs` and
   `test/filterpanel.test.mjs` all drive `wirePanel` and must be unaffected.
2. `cd /home/lox/code/_fcl/rookery/search/0.1.0 && just build` — vite still
   bundles `dist/lib.js`.
3. Read `src/search.js` and confirm that `init` is no longer referenced directly
   as an event listener, and that every call site of it has a `.catch`.
4. Read `src/panel.js` and confirm `wirePanel` is called inside a `try` and that
   `n++` still increments once per panel, failed ones included, so two surviving
   panels never share a generated list id.