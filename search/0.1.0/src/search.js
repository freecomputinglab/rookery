// @rookery/search — the search bar's behaviour. RHEO ONLY: this file is
// injected by rheo via `[tool.rheo.html] js_scripts` in the package manifest,
// and it reads an index whose hrefs point at pages only rheo mints. Under plain
// `typst compile` nothing injects it, `#search-bar` emits nothing, and the
// Typst-side `search-ideas` remains the supported path.
//
// Built with vite into `dist/lib.js` as an IIFE bundle exposing the global
// `RookerySearch`, the shape every other JS package here ships. An ES module in
// `src/` and a global at runtime: the module form is what lets the parity fixture
// import it under node, the global is what lets a site build its own UI on this
// ranking instead of forking it. The bottom of this file publishes that same
// global in source mode, where vite is not involved.
//
// No dependencies, and it should stay that way — vite is bundling one file.
//
// PARITY. Every exported ranking function has a Typst twin — `score` against
// `fuzzy-score`, `bodyScore` against `body-score`, the `tags:` parser and
// evaluator against theirs — and `just parity` enforces it, feeding fixtures
// through both languages and diffing the results. Change one side, change the
// other, re-run the fixture.
//
// EMBEDDING. Every bar on the page is found by its `data-rookery-search`
// attribute, whose VALUE is the id of the island it reads. So several bars can
// share one island, or point at different ones, and none of them needs an id of
// its own — ids are assigned here at runtime, because markup that carries a
// hardcoded id cannot be placed twice on a page.


import { readIndex } from "./island.js";
import { wire } from "./bar.js";
import { wireModal } from "./modal.js";
import { initPanels, wirePanel } from "./panel.js";
// IMPORTED AS WELL AS RE-EXPORTED. `export { x } from "./y.js"` forwards `x`
// without binding it here, so the global at the bottom — which names these
// values — needs the import too. The `export` lines below stay exactly as they
// were: the public module surface is not what changed.
import { fold, clusters } from "./text.js";
import {
  TAG_PREFIX,
  splitQuery,
  parseTagQuery,
  evalTagQuery,
  positiveAtoms,
} from "./tagquery.js";
import { score, bodyScore, search } from "./score.js";

export { fold, clusters } from "./text.js";
export { TAG_PREFIX, splitQuery, parseTagQuery, evalTagQuery, positiveAtoms } from "./tagquery.js";
export { score, bodyScore, search } from "./score.js";
export { readIndex } from "./island.js";
export { initPanels, wirePanel } from "./panel.js";

export const init = () => {
  // Panels are wired FIRST and unconditionally, because they are independent of
  // the search bar: a page may carry panels and no bar at all, and the early
  // return below would otherwise skip them.
  initPanels();

  // The dialog ALSO carries `data-rookery-search` (it shares the bar's
  // island-lookup attribute), so the bar query must exclude it — otherwise a
  // page with both a bar and a modal would wire the dialog as a second,
  // broken dropdown.
  const roots = document.querySelectorAll("[data-rookery-search]:not(dialog)");
  const dialogs = document.querySelectorAll("dialog[data-rookery-search]");
  if (roots.length === 0 && dialogs.length === 0) return;

  // Shared across bars AND modals, so a page with both parses the JSON once.
  const cache = new Map();

  const bars = [];
  let n = 0;
  for (const root of roots) {
    const elemId = root.dataset.rookerySearch || "rookery-search-index";
    if (!cache.has(elemId)) cache.set(elemId, readIndex(elemId));
    const rows = cache.get(elemId);
    // No island for this bar (a site placed one with `index: false` and no
    // other bar emitted it, or the build emitted none) — leave the input inert
    // rather than throwing.
    if (rows === null) continue;
    const bar = wire(root, rows, n++);
    if (bar) bars.push(bar);
  }
  if (bars.length > 0) {
    // ONE listener for every bar on the page, not one each: the question a
    // click asks is "which bars was this outside of", and that is naturally a
    // single pass. Two bars therefore close independently and correctly — a
    // click on one is outside the other, and dismisses only it.
    //
    // `pointerdown`, not `click`: it fires before focus moves, so the dropdown
    // is dismissed by the time the reader's press lands and nothing flickers. A
    // result link is INSIDE its own bar, so following one never counts as a click
    // outside and navigation is unaffected.
    document.addEventListener("pointerdown", (ev) => {
      for (const bar of bars) {
        if (!bar.root.contains(ev.target)) bar.dismiss();
      }
    });
  }

  const modals = new Map();
  for (const dialog of dialogs) {
    const elemId = dialog.dataset.rookerySearch || "rookery-search-index";
    if (!cache.has(elemId)) cache.set(elemId, readIndex(elemId));
    const rows = cache.get(elemId);
    if (rows === null) continue;
    const modal = wireModal(dialog, rows);
    if (modal !== null) modals.set(elemId, modal);
  }
  if (modals.size === 0) return;

  for (const trigger of document.querySelectorAll(".rookery-search-trigger")) {
    const modal = modals.get(trigger.dataset.rookerySearchModal);
    if (modal === undefined) continue;
    trigger.addEventListener("click", () => modal.open());
  }

  // Registered once per page, not once per modal — opens the FIRST modal in
  // document order, matching telescope's own convention of one global
  // shortcut. `preventDefault()` because Ctrl+K is a browser binding in some
  // browsers and the page must win here.
  document.addEventListener("keydown", (ev) => {
    if (!(ev.ctrlKey || ev.metaKey) || ev.key.toLowerCase() !== "k") return;
    // A reader typing in some other field means the literal keystroke, not
    // the shortcut.
    const t = ev.target;
    if (t.tagName === "INPUT" || t.tagName === "TEXTAREA" || t.isContentEditable) return;
    ev.preventDefault();
    modals.values().next().value?.open();
  });
};
// THE GLOBAL, PUBLISHED IN SOURCE MODE TOO. `vite.config.js` builds an IIFE named
// `RookerySearch`, so a release carries this object; a project consuming `src/*.js`
// through a repo-backed namespace gets ES modules, and this assignment is what
// gives it the same surface. The surface is a property of the package rather than
// of how it was installed.
//
// `??=` so the IIFE's own assignment wins where both run, and guarded on
// `typeof document` rather than on `window`, because node imports this module in
// the parity harness and must NOT be handed a global — a node suite that saw one
// could not tell the two modes apart.
//
// BEFORE the auto-init below, so anything `init()` reaches, and any other
// package's own DOMContentLoaded handler, finds the global already standing.
if (typeof document !== "undefined") {
  globalThis.RookerySearch ??= {
    fold,
    clusters,
    TAG_PREFIX,
    splitQuery,
    parseTagQuery,
    evalTagQuery,
    positiveAtoms,
    score,
    bodyScore,
    search,
    readIndex,
    initPanels,
    wirePanel,
    init,
  };
}

// Auto-init in a browser. Guarded so the parity fixture can `import` this module
// under node, where there is no document and nothing to wire.
if (typeof document !== "undefined") {
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
}
