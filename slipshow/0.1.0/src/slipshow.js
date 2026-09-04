// The slipshow controller: finds the deck's slips in the DOM, tracks which
// one is current, reveals the deck up to it, and moves the page there.
// `src/camera.js` computes WHERE to go from plain numbers; `src/edges.js`
// draws the connector curves between slip rails, and is called from here
// whenever what it drew could have moved; this module
// measures the DOM, calls it, and applies the result with
// `window.scrollTo` (or, inside a horizontally
// overflowing `.slip-row`, that row's own `scrollTo`) and a CSS transform for
// zoom. `src/slipshow.css` owns the deck's layout. All three are pinned to
// the DOM contract documented at the top of `src/slipshow.typ` — none of the
// class names, `data-*` attributes or element shapes below can change
// without changing all three together.
//
// Injected on every page of a rheo project, most of which are not
// presentations, so absent a `div.slipshow` this file finds nothing and
// returns silently rather than throwing or logging.

import { targetFor, clampTo, unfocusTarget } from "./camera.js";
import { redraw } from "./edges.js";

// Gap kept between a slip's edge and the viewport edge when the camera
// scrolls or zooms to it.
const MARGIN = 24;

const RESIZE_DEBOUNCE_MS = 150;

// A click inside any of these reaches its own handler rather than advancing
// the deck: real links and controls on a slip, and a queried note's own
// `<summary>` disclosure toggle (`#window`'s `<details open>` — see
// `src/slipshow.typ`).
const CLICK_IGNORE_SELECTOR = "a, summary, button, input, select, textarea, label";

const NEXT_KEYS = new Set(["ArrowRight", "ArrowDown", "PageDown", " "]);
const PREV_KEYS = new Set(["ArrowLeft", "ArrowUp", "PageUp"]);

let deck = null;
// One flat array in `data-index` order, one current index — a slip's row (if
// any) is read off `el.closest(".slip-row")` where it matters (`rowEnter`,
// `apply`) rather than tracked as a second axis of state. Next/previous
// still mean "the next slip in the deck", whether that slip sits beside the
// current one or below it, so `Home`, `End`, the hash lookup below and the
// reduced-motion path all stay one-dimensional with no row/column case.
let slips = [];
let currentIndex = 0;
let currentScale = 1;
let focusStack = [];
let reducedMotion = false;
let resizeTimer = null;
// Whether the reader has entered the deck. False until the first navigation
// on a deck opened without a `#slip-<id>` fragment, so that first press
// lands on the current slip rather than stepping past it. Flips back to
// false in `stop()`, when a backwards press off slip 0 leaves the deck.
let started = false;
// Whether this deck hides the slips the reader has not reached yet
// (`data-reveal="progressive"`, the default — see `src/slipshow.typ`'s
// header). Read once at init.
let revealing = false;

// The index of the LAST slip a progressive deck should be showing, given the
// two pieces of state that decide it. `-1` — show nothing — whenever `started`
// is false: before the reader's first press, and again after `stop()` sends
// them back out, so the deck is exactly as empty leaving as it was arriving.
// Exported for `test/reveal.test.mjs`; the off-by-one here is the whole
// behaviour, and it is the one part of the reveal that can be tested without
// a DOM.
export function revealThrough(hasStarted, index) {
  return hasStarted ? index : -1;
}

// True when a requested index would enter a not-yet-started deck: any index
// at or past `currentIndex` (a forward press, `Home`, `End`, a fragment
// landing), never one before it — a backwards press on an unentered deck
// stays a no-op rather than entering the deck.
export function entersDeck(hasStarted, currentIndex, index) {
  return !hasStarted && index >= currentIndex;
}

// True when a requested index would exit an already-started deck: a
// backwards press off slip 0, and only there — the one case `goTo`'s ordinary
// clamp would otherwise swallow, leaving `started` stuck true forever.
export function exitsDeck(hasStarted, currentIndex, index) {
  return hasStarted && index < 0 && currentIndex === 0;
}

// Puts `slip-revealed` on every slip up to `revealThrough`'s answer and takes
// it off the rest. A no-op on a `data-reveal="all"` deck, so every caller can
// call it unconditionally.
//
// IDEMPOTENT AND WHOLE-DECK, rather than adding the one class that changed:
// going backwards has to take classes OFF again — the deck's rule is "nothing
// beyond the active slip", not "everything visited so far" — and a `Home` or a
// fragment landing can move the boundary by any number of slips at once.
function syncReveal() {
  if (!revealing) return;
  const through = revealThrough(started, currentIndex);
  slips.forEach((s, i) => s.classList.toggle("slip-revealed", i <= through));
}

// A slip's own `data-enter`, else "left" for a non-first slip in a row (see
// `rowEnter`), else the deck's default, else "scroll" — the same chain
// `src/slipshow.typ` documents for the attribute's absence meaning "inherit",
// with the row-aware step inserted ahead of the deck default.
function actionFor(el) {
  return el.dataset.enter ?? rowEnter(el) ?? deck.dataset.enter ?? "scroll";
}

// A slip inside a `.slip-row` that is not the row's first slip is reached by
// moving along the row rather than down the page, so it defaults to "left"
// there instead of falling through to the deck default. The row's first slip
// is reached by moving down, so it keeps the deck default like a slip
// outside any row. This is the only place in the package where an action is
// inferred rather than authored on the slip or configured on the deck.
function rowEnter(el) {
  const row = el.closest(".slip-row");
  return row && row.querySelector(".slip") !== el ? "left" : undefined;
}

function scrollBehavior() {
  return reducedMotion ? "auto" : "smooth";
}

// `getBoundingClientRect()` is viewport-relative; `camera.js` wants document
// coordinates, so the current scroll position is added back in on both axes.
function documentRect(el) {
  const r = el.getBoundingClientRect();
  return { top: r.top + window.scrollY, height: r.height, left: r.left + window.scrollX, width: r.width };
}

function currentViewport() {
  return {
    height: window.innerHeight,
    width: window.innerWidth,
    scrollLeft: window.scrollX,
    scrollTop: window.scrollY,
  };
}

// Scales the deck around `el`'s centre, or clears the transform when the
// target scale is natural. The origin is `el`'s centre relative to the
// deck's own untransformed box — the coordinate space CSS `transform-origin`
// expects — not a document or viewport position.
function applyScale(scale, el) {
  if (scale === 1) {
    deck.style.transform = "";
    deck.style.transformOrigin = "";
  } else {
    const deckRect = deck.getBoundingClientRect();
    const slipRect = el.getBoundingClientRect();
    const originX = slipRect.left - deckRect.left + slipRect.width / 2;
    const originY = slipRect.top - deckRect.top + slipRect.height / 2;
    deck.style.transformOrigin = `${originX}px ${originY}px`;
    deck.style.transform = `scale(${scale})`;
  }
  currentScale = scale;
}

// Measures `el`, asks `camera.js` where its action wants to go, and moves
// there. Shared by navigation (`goTo`) and by a resize's re-measurement of
// whichever slip is already current — `recordFocus` is false for the
// latter, since a resize does not enter a new focus.
function apply(el, { recordFocus }) {
  // FIRST, and before a single measurement: a slip the reveal is about to
  // show is `display: none` until this runs, so its rect is all zeroes and
  // the document is shorter than it is about to be. Both `documentRect`
  // below and the `scrollHeight` clamp further down read layout, which
  // flushes the class change synchronously, so the numbers they get are the
  // ones the reader will see.
  syncReveal();

  const action = actionFor(el);
  const rect = documentRect(el);
  const viewport = currentViewport();
  const target = targetFor(action, rect, viewport, { margin: MARGIN });

  if (recordFocus && action === "focus" && target.scale !== 1) {
    // Saved BEFORE moving: what `unfocus` restores is where the camera was
    // before this focus, not where it is going.
    focusStack.push({ scrollLeft: window.scrollX, scrollTop: window.scrollY, scale: currentScale });
  }

  const top = clampTo(target.scrollTop, document.documentElement.scrollHeight, window.innerHeight);
  const behavior = scrollBehavior();

  // Re-checked on every move rather than cached: a row's scrollability
  // depends on the viewport width (a row that fits at desktop width
  // overflows on a phone), and `.slip-row` scrolls itself sideways on
  // overflow (`overflow-x: auto`, `src/slipshow.css`) instead of growing the
  // page, so `window.scrollTo` cannot reach a slip buried in an overflowing
  // row at all — the row has to be scrolled directly. The row-local target
  // reuses `targetFor` with the slip's offset WITHIN the row standing in for
  // its document `left`, and the row's own width standing in for the
  // viewport, so the same per-action formula that positions the slip on the
  // page (left/right/center-x) also positions it inside the row.
  const row = el.closest(".slip-row");
  if (row && row.scrollWidth > row.clientWidth) {
    const rowRect = { top: rect.top, height: rect.height, left: el.offsetLeft - row.offsetLeft, width: rect.width };
    const rowViewport = { height: viewport.height, width: row.clientWidth, scrollLeft: row.scrollLeft, scrollTop: viewport.scrollTop };
    const rowTarget = targetFor(action, rowRect, rowViewport, { margin: MARGIN });
    const left = clampTo(rowTarget.scrollLeft, row.scrollWidth, row.clientWidth);
    row.scrollTo({ left, behavior });
    window.scrollTo({ top, behavior });
  } else {
    const left = clampTo(target.scrollLeft, document.documentElement.scrollWidth, window.innerWidth);
    window.scrollTo({ top, left, behavior });
  }

  applyScale(target.scale, el);

  // `replaceState`, not a `location.hash` assignment: the latter pushes a
  // history entry per slip, so navigating the deck would fill the back
  // button with one entry per stop.
  history.replaceState(null, "", "#" + el.id);
}

// The connector layer (`src/edges.js`), redrawn wherever what it drew could
// have moved: a reveal change (a slide appearing or disappearing moves every
// slide below it), a resize, and a row scrolling itself sideways. An
// early-returning no-op path needs none — nothing moved.
function redrawEdges() {
  if (deck) redraw(deck);
}

function goTo(index) {
  if (!started) {
    if (!entersDeck(started, currentIndex, index)) return;
    started = true;
    apply(slips[currentIndex], { recordFocus: true });
    redrawEdges();
    return;
  }
  if (exitsDeck(started, currentIndex, index)) {
    stop();
    return;
  }
  const clamped = Math.min(Math.max(index, 0), slips.length - 1);
  if (clamped === currentIndex) return;
  currentIndex = clamped;
  apply(slips[currentIndex], { recordFocus: true });
  redrawEdges();
}

// Leaves the deck: undoes `started`, collapses the reveal back to nothing,
// and scrolls to the deck's own top edge instead of past slip 0.
// `syncReveal()` runs BEFORE the `getBoundingClientRect()` read below, same
// as `apply` (see its comment) — it is what collapses every slip back to
// `display: none`, so the rect measures where the deck's top will land once
// empty, not where it sat while slip 0 was still shown. The `replaceState`
// carries no fragment, so a reload lands above the deck instead of
// re-entering it at `#slip-<id>` (`init` reads that fragment back).
function stop() {
  started = false;
  focusStack = [];
  currentIndex = 0;
  syncReveal();
  applyScale(1, slips[0]);
  history.replaceState(null, "", location.pathname + location.search);
  const top = clampTo(
    deck.getBoundingClientRect().top + window.scrollY - MARGIN,
    document.documentElement.scrollHeight,
    window.innerHeight,
  );
  window.scrollTo({ top, behavior: scrollBehavior() });
  redrawEdges();
}

// Re-targets the current slip without changing it — a resize can change its
// height (a fullscreen slip sized to the viewport, wrapped text reflowing),
// so the camera's last measurement is stale.
function reposition() {
  // Nothing to re-target until the camera has run: a resize must not scroll
  // a page whose reader has not yet entered the deck.
  if (!started) return;
  apply(slips[currentIndex], { recordFocus: false });
}

function unfocus() {
  if (focusStack.length === 0) return;
  const target = unfocusTarget(focusStack.pop());
  const top = clampTo(target.scrollTop, document.documentElement.scrollHeight, window.innerHeight);
  const left = clampTo(target.scrollLeft, document.documentElement.scrollWidth, window.innerWidth);
  window.scrollTo({ top, left, behavior: scrollBehavior() });
  applyScale(target.scale, slips[currentIndex]);
}

function isEditableTarget(el) {
  return el != null && (el.tagName === "INPUT" || el.tagName === "TEXTAREA" || el.isContentEditable);
}

function onKeydown(event) {
  if (isEditableTarget(event.target)) return;
  if (event.ctrlKey || event.altKey || event.metaKey || event.shiftKey) return;

  if (NEXT_KEYS.has(event.key)) {
    event.preventDefault();
    goTo(currentIndex + 1);
  } else if (PREV_KEYS.has(event.key)) {
    event.preventDefault();
    goTo(currentIndex - 1);
  } else if (event.key === "Home") {
    event.preventDefault();
    goTo(0);
  } else if (event.key === "End") {
    event.preventDefault();
    goTo(slips.length - 1);
  } else if (event.key === "Escape") {
    unfocus();
  }
}

// BOUND ON THE DECK, which on a progressive deck has no area at all until
// the first slip is up — so click-to-advance cannot be what STARTS such a
// deck, and the first move has to come from the keyboard. That is the
// trade the empty opening buys, and the alternative is worse: listening on
// the document instead would let a click on a page's own heading or margin
// scroll a deck the reader had not asked to enter, which is exactly what
// the load-time camera rule below refuses to do.
function onClick(event) {
  if (event.target.closest(CLICK_IGNORE_SELECTOR)) return;
  goTo(currentIndex + 1);
}

function onResize() {
  clearTimeout(resizeTimer);
  resizeTimer = setTimeout(() => {
    reposition();
    redrawEdges();
  }, RESIZE_DEBOUNCE_MS);
}

function init() {
  const found = document.querySelector("div.slipshow");
  if (!found) return;
  deck = found;

  slips = Array.from(deck.querySelectorAll("section.slip")).sort(
    (a, b) => Number(a.dataset.index) - Number(b.dataset.index),
  );
  if (slips.length === 0) return;

  reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // THE HIDING IS TURNED ON FROM HERE, not from the stylesheet's own
  // selectors, and that is deliberate: `slipshow-revealing` is the marker
  // that this controller is alive, so a reader whose JavaScript never ran (a
  // script blocked, an EPUB reader that executes none) gets the whole deck
  // rendered rather than a page that is permanently empty and has no key
  // that would fill it.
  //
  // A missing `data-reveal` reads as progressive, matching `#slipshow`'s own
  // default: the Typst side always writes the attribute, so the only markup
  // without one is older than this file, and defaulting the other way would
  // silently opt such a page out of the behaviour it is about to be rebuilt
  // with anyway.
  revealing = deck.dataset.reveal !== "all";
  if (revealing) {
    deck.classList.add("slipshow-revealing");
    // With `started` still false this reveals NOTHING, which is the point:
    // the deck occupies no height at all until the reader's first press.
    syncReveal();
  }

  // A `#slip-<id>` fragment is a request to open the deck there, so the
  // camera runs on load. WITHOUT one it does not: a page carrying a deck
  // usually carries its own heading and prose above it, and scrolling that
  // out of view before the reader has pressed anything is the deck taking
  // over a page it only occupies part of.
  const hashIndex = slips.findIndex((s) => s.id === window.location.hash.slice(1));
  currentIndex = hashIndex === -1 ? 0 : hashIndex;
  if (hashIndex !== -1) {
    started = true;
    apply(slips[currentIndex], { recordFocus: false });
  }

  document.addEventListener("keydown", onKeydown);
  deck.addEventListener("click", onClick);
  window.addEventListener("resize", onResize);

  // A row scrolling sideways moves its slides' rails under curves anchored
  // outside it, and a row's scroll reaches no other listener here.
  for (const row of deck.querySelectorAll(".slip-row")) {
    row.addEventListener("scroll", redrawEdges, { passive: true });
  }

  redrawEdges();
}

if (typeof document !== "undefined") {
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
}
