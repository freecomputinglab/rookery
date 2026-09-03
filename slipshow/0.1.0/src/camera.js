// Pure camera geometry for the slip presentation: given a measured element
// rect, a viewport, and an action name, computes the scroll position (and
// zoom) the camera should move to. No DOM access anywhere in this file —
// nothing reads `window`, `document`, or takes a live measurement — so every
// case here runs on plain numbers with no browser at all. `src/slipshow.js`
// is the counterpart: it measures the DOM, calls `targetFor`, and applies
// the result (with `window.scrollTo`, a CSS transform for `scale`, and a
// saved-position stack for `unfocus`).

// The eight action names. `ENTERS` in `src/tags.typ` is the Typst half of the
// same vocabulary and holds the same eight, which is what lets a `data-enter`
// attribute reach `targetFor` unchanged, with no translation table between an
// authored tag and this switch. The two halves cannot be changed apart.
const ACTIONS = ["scroll", "up", "down", "center", "left", "right", "center-x", "focus"];

// `rect` is the element's position in DOCUMENT coordinates —
// `{ top, height, left, width }` measured from the top/left of the whole
// scrollable page — NOT viewport-relative. The controller converts a
// `getBoundingClientRect()` reading (which IS viewport-relative) before
// calling this, which is what keeps every formula below independent of the
// current scroll position; passing a viewport-relative rect here would
// silently double-count the scroll offset.
//
// `viewport` is `{ height, width, scrollLeft, scrollTop }`. The current
// scroll position is load-bearing, not decorative: a vertical action must
// leave the horizontal position untouched, and a horizontal action must
// leave nothing to a merge step, so both axes are threaded through every
// branch below even where a given action only moves one of them.
export const targetFor = (action, rect, viewport, opts = {}) => {
  const margin = opts.margin ?? 0;
  switch (action) {
    case "up":
      return { scrollLeft: viewport.scrollLeft, scrollTop: rect.top - margin, scale: 1 };
    case "down":
      return {
        scrollLeft: viewport.scrollLeft,
        scrollTop: rect.top + rect.height + margin - viewport.height,
        scale: 1,
      };
    case "center":
      return {
        scrollLeft: viewport.scrollLeft,
        scrollTop: rect.top + rect.height / 2 - viewport.height / 2,
        scale: 1,
      };
    case "scroll":
      // "entirely visible, if possible": when the element plus margin on
      // both sides fits inside the viewport, centring shows all of it.
      // Otherwise no scroll position shows the whole element, so this shows
      // its start and lets the rest run off the bottom.
      return rect.height + 2 * margin <= viewport.height
        ? targetFor("center", rect, viewport, opts)
        : targetFor("up", rect, viewport, opts);
    case "left": {
      const { scrollTop } = targetFor("scroll", rect, viewport, opts);
      return { scrollLeft: rect.left - margin, scrollTop, scale: 1 };
    }
    case "right": {
      const { scrollTop } = targetFor("scroll", rect, viewport, opts);
      return {
        scrollLeft: rect.left + rect.width + margin - viewport.width,
        scrollTop,
        scale: 1,
      };
    }
    case "center-x": {
      const { scrollTop } = targetFor("scroll", rect, viewport, opts);
      return {
        scrollLeft: rect.left + rect.width / 2 - viewport.width / 2,
        scrollTop,
        scale: 1,
      };
    }
    case "focus": {
      const { scrollLeft } = targetFor("center-x", rect, viewport, opts);
      const { scrollTop } = targetFor("center", rect, viewport, opts);
      // A zero or negative height/width (an empty or malformed rect) has no
      // natural size to fill the viewport with, so scale stays 1 instead of
      // dividing by a non-positive number.
      const scale =
        rect.height <= 0 || rect.width <= 0
          ? 1
          : Math.min(viewport.height / (rect.height + 2 * margin), 1);
      return { scrollLeft, scrollTop, scale };
    }
    default:
      throw new Error(
        `camera: unknown action "${action}" — expected one of ${ACTIONS.join(", ")}`,
      );
  }
};

// Clamps a target scroll position, on one axis, to what the document can
// actually show: never negative, never past the point where the viewport's
// far edge would run off the end of the page. Every target from `targetFor`
// must pass through this per axis — a slip near an edge of the document
// would otherwise compute a position outside `[0, docSize - viewportSize]`,
// and the browser would clamp it silently, so the engine would appear to do
// nothing when asked to move there.
export const clampTo = (pos, docSize, viewportSize) =>
  Math.min(Math.max(pos, 0), Math.max(0, docSize - viewportSize));

// `clamp` is the vertical-only name `src/slipshow.js` and the tests still
// reach `clampTo` by.
export const clamp = clampTo;

// The position `unfocus` restores: whatever `focus` saved before it moved,
// or the top-left of the document at natural scale if nothing was saved
// (e.g. `unfocus` fires with no prior `focus`). The stack of saved positions
// lives in the controller, not here — this module holds no state of its own.
export const unfocusTarget = (saved) => saved ?? { scrollLeft: 0, scrollTop: 0, scale: 1 };
