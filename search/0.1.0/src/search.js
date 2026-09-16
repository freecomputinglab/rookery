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


import { readIndex, loadIndex } from "./island.js";
import { wire } from "./bar.js";
import { wireModal } from "./modal.js";
import { initPanels, wirePanel } from "./panel.js";
// IMPORTED AS WELL AS RE-EXPORTED. `export { x } from "./y.js"` forwards `x`
// without binding it here, so the global at the bottom — which names these
// values — needs the import too. The `export` lines below stay exactly as they
// were: the public module surface is not what changed.
import { fold, clusters } from "./text.js";
import {
  splitQuery,
  parseTagQuery,
  evalTagQuery,
  evalClauses,
  positiveAtoms,
  positiveTagAtoms,
} from "./tagquery.js";
import { score, bodyScore, search } from "./score.js";
import { readSync, writeSync, readParam, writeParam, commit, claimKey, debounce } from "./urlstate.js";
import { initUrlSync, wireRadioGroup } from "./urlsync.js";

export { fold, clusters } from "./text.js";
export { splitQuery, parseTagQuery, evalTagQuery, evalClauses, positiveAtoms, positiveTagAtoms } from "./tagquery.js";
export { score, bodyScore, search } from "./score.js";
export { readIndex, loadIndex } from "./island.js";
export { initPanels, wirePanel } from "./panel.js";
export { readSync, writeSync, readParam, writeParam, commit, claimKey, debounce } from "./urlstate.js";
export { initUrlSync, wireRadioGroup } from "./urlsync.js";

// ASYNC, because `mode: "asset"` fetches the index rather than reading it out
// of the page. `initPanels()` still runs synchronously ahead of the first
// await, so a page's panels are live on first paint whatever the network does.
// Everything that needs ROWS — the bars, the modals, the Ctrl+K binding —
// necessarily waits for them, and until they land a search input is inert in
// exactly the way it already is on a page carrying no index at all.
// `navigator.platform` is deprecated but is the only field that separates
// macOS and iPadOS from everything else in every shipping browser today;
// `userAgentData.platform` is not implemented in Safari, which is precisely
// the browser this has to be right for. Guarded for node, where the parity
// fixture imports this module and there is no navigator.
const APPLE =
  typeof navigator !== "undefined" &&
  /Mac|iPhone|iPad|iPod/.test(navigator.platform ?? "");

export const init = async () => {
  // Panels are wired FIRST and unconditionally, because they are independent of
  // the search bar: a page may carry panels and no bar at all, and the early
  // return below would otherwise skip them.
  // Guarded individually: panels, URL sync and search are independent
  // features that happen to share one entry point, and one of them failing
  // must not silently disable the other two.
  try { initPanels(); } catch (err) {
    console.error("@rookery/search: panels could not be initialised.", err);
  }
  try { initUrlSync(); } catch (err) {
    console.error("@rookery/search: URL sync could not be initialised.", err);
  }

  // The dialog ALSO carries `data-rookery-search` (it shares the bar's
  // island-lookup attribute), so the bar query must exclude it — otherwise a
  // page with both a bar and a modal would wire the dialog as a second,
  // broken dropdown.
  const roots = document.querySelectorAll("[data-rookery-search]:not(dialog)");
  const dialogs = document.querySelectorAll("dialog[data-rookery-search]");
  if (roots.length === 0 && dialogs.length === 0) return;

  // WIRED BEFORE THE INDEX IS FETCHED, and that ordering is the whole point:
  // a trigger registered after an `await` is a dead button whenever the fetch
  // fails, with nothing on screen and nothing in the console to say so. A modal
  // opened before the index lands reports that it is still loading; `setRows`
  // below fills it in.
  const modals = new Map();
  for (const dialog of dialogs) {
    const elemId = dialog.dataset.rookerySearch || "rookery-search-index";
    const modal = wireModal(dialog);
    if (modal !== null) modals.set(elemId, modal);
  }
  if (modals.size > 0) {
    for (const trigger of document.querySelectorAll(".rookery-search-trigger")) {
      const modal = modals.get(trigger.dataset.rookerySearchModal);
      if (modal === undefined) continue;
      trigger.addEventListener("click", () => modal.open());
      // THE HINT FOLLOWS THE PLATFORM, because the binding already does: the
      // keydown listener below opens on `ctrlKey || metaKey`, and on a Mac or
      // an iPad the discoverable modifier is Command — Control-K there is a
      // text-field binding that eats the keystroke before the page sees it.
      // The markup says `Ctrl K` because Typst builds one page for every
      // visitor and cannot know which is reading it.
      const key = trigger.querySelector(".rookery-search-key");
      if (key !== null && APPLE) key.textContent = "⌘ K";
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
  }

  // Shared across bars AND modals, so a page with both fetches and parses the
  // index once. Holds the PROMISE, not the rows: two bars naming the same
  // island must await one fetch, not race two.
  const cache = new Map();
  const rowsFor = (elemId) => {
    if (!cache.has(elemId)) cache.set(elemId, loadIndex(elemId));
    return cache.get(elemId);
  };

  const bars = [];
  let n = 0;
  for (const root of roots) {
    const elemId = root.dataset.rookerySearch || "rookery-search-index";
    const rows = await rowsFor(elemId);
    // No index for this bar (a site placed one with `index: false` and no
    // other bar emitted it, the build emitted none, or the asset could not be
    // fetched) — leave the input inert rather than throwing.
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

  // Each wired modal is fed its rows once the index settles — or fed `null`
  // when it never does, which is what turns its empty state into the
  // unavailable-index message rather than a plain "no match found".
  for (const [elemId, modal] of modals) modal.setRows(await rowsFor(elemId));
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
    splitQuery,
    parseTagQuery,
    evalTagQuery,
    evalClauses,
    positiveAtoms,
    positiveTagAtoms,
    score,
    bodyScore,
    search,
    readIndex,
    loadIndex,
    initPanels,
    wirePanel,
    readSync,
    writeSync,
    readParam,
    writeParam,
    commit,
    claimKey,
    debounce,
    initUrlSync,
    wireRadioGroup,
    init,
  };
}

// Auto-init in a browser. Guarded so the parity fixture can `import` this module
// under node, where there is no document and nothing to wire.
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
