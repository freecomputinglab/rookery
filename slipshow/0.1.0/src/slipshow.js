// The slipshow controller: finds the deck's slips in the DOM, tracks which
// one is current, and moves the page there. `src/camera.js` computes WHERE
// to go from plain numbers; this module measures the DOM, calls it, and
// applies the result with `window.scrollTo` and a CSS transform for zoom.
// `src/slipshow.css` owns the deck's layout. All three are pinned to the DOM
// contract documented at the top of `src/slipshow.typ` — none of the class
// names, `data-*` attributes or element shapes below can change without
// changing all three together.
//
// Injected on every page of a rheo project, most of which are not
// presentations, so absent a `div.slipshow` this file finds nothing and
// returns silently rather than throwing or logging.

import { targetFor, clampTo, unfocusTarget } from "./camera.js";

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
let slips = [];
let currentIndex = 0;
let currentScale = 1;
let focusStack = [];
let reducedMotion = false;
let resizeTimer = null;
// Whether the camera has run at all. False until the first navigation on a
// deck opened without a `#slip-<id>` fragment, so that first press lands on
// the current slip rather than stepping past it.
let started = false;

// A slip's own `data-enter`, else the deck's default, else "scroll" — the
// same chain `src/slipshow.typ` documents for the attribute's absence
// meaning "inherit".
function actionFor(el) {
  return el.dataset.enter ?? deck.dataset.enter ?? "scroll";
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
  const action = actionFor(el);
  const target = targetFor(action, documentRect(el), currentViewport(), { margin: MARGIN });

  if (recordFocus && action === "focus" && target.scale !== 1) {
    // Saved BEFORE moving: what `unfocus` restores is where the camera was
    // before this focus, not where it is going.
    focusStack.push({ scrollLeft: window.scrollX, scrollTop: window.scrollY, scale: currentScale });
  }

  const top = clampTo(target.scrollTop, document.documentElement.scrollHeight, window.innerHeight);
  const left = clampTo(target.scrollLeft, document.documentElement.scrollWidth, window.innerWidth);
  window.scrollTo({ top, left, behavior: scrollBehavior() });
  applyScale(target.scale, el);

  // `replaceState`, not a `location.hash` assignment: the latter pushes a
  // history entry per slip, so navigating the deck would fill the back
  // button with one entry per stop.
  history.replaceState(null, "", "#" + el.id);
}

function goTo(index) {
  if (!started) {
    started = true;
    apply(slips[currentIndex], { recordFocus: true });
    return;
  }
  const clamped = Math.min(Math.max(index, 0), slips.length - 1);
  if (clamped === currentIndex) return;
  currentIndex = clamped;
  apply(slips[currentIndex], { recordFocus: true });
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

function onClick(event) {
  if (event.target.closest(CLICK_IGNORE_SELECTOR)) return;
  goTo(currentIndex + 1);
}

function onResize() {
  clearTimeout(resizeTimer);
  resizeTimer = setTimeout(reposition, RESIZE_DEBOUNCE_MS);
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
}

if (typeof document !== "undefined") {
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
}
