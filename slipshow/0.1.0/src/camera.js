// Pure camera geometry for the slip presentation: given a measured element
// rect, a viewport, and an action name, computes the scroll position (and
// zoom) the camera should move to. No DOM access anywhere in this file —
// nothing reads `window`, `document`, or takes a live measurement — so every
// case here runs on plain numbers with no browser at all. `src/slipshow.js`
// is the counterpart: it measures the DOM, calls `targetFor`, and applies
// the result (with `window.scrollTo`, a CSS transform for `scale`, and a
// saved-position stack for `unfocus`).

// The five action names, in the exact vocabulary `ENTERS` in `src/tags.typ`
// uses — a `data-enter` attribute reaches `targetFor` unchanged, with no
// translation table anywhere between an authored tag and this switch.
const ACTIONS = ["scroll", "up", "down", "center", "focus"];

// `rect` is the element's position in DOCUMENT coordinates — `{ top, height }`
// measured from the top of the whole scrollable page — NOT viewport-relative.
// The controller converts a `getBoundingClientRect()` reading (which IS
// viewport-relative) before calling this, which is what keeps every formula
// below independent of the current scroll position; passing a
// viewport-relative rect here would silently double-count the scroll offset.
export const targetFor = (action, rect, viewport, opts = {}) => {
  const margin = opts.margin ?? 0;
  switch (action) {
    case "up":
      return { scrollTop: rect.top - margin, scale: 1 };
    case "down":
      return { scrollTop: rect.top + rect.height + margin - viewport.height, scale: 1 };
    case "center":
      return { scrollTop: rect.top + rect.height / 2 - viewport.height / 2, scale: 1 };
    case "scroll":
      // "entirely visible, if possible": when the element plus margin on
      // both sides fits inside the viewport, centring shows all of it.
      // Otherwise no scroll position shows the whole element, so this shows
      // its start and lets the rest run off the bottom.
      return rect.height + 2 * margin <= viewport.height
        ? targetFor("center", rect, viewport, opts)
        : targetFor("up", rect, viewport, opts);
    case "focus": {
      const { scrollTop } = targetFor("center", rect, viewport, opts);
      // A zero or negative height (an empty or malformed rect) has no
      // natural size to fill the viewport with, so scale stays 1 instead of
      // dividing by a non-positive number.
      const scale =
        rect.height <= 0 ? 1 : Math.min(viewport.height / (rect.height + 2 * margin), 1);
      return { scrollTop, scale };
    }
    default:
      throw new Error(
        `camera: unknown action "${action}" — expected one of ${ACTIONS.join(", ")}`,
      );
  }
};

// Clamps a target scroll position to what the document can actually show:
// never negative, never past the point where the viewport's bottom would run
// off the end of the page. Every target from `targetFor` must pass through
// this — a slip near either end of the document would otherwise compute a
// scrollTop outside `[0, docHeight - viewportHeight]`, and the browser would
// clamp it silently, so the engine would appear to do nothing when asked to
// move there.
export const clamp = (scrollTop, docHeight, viewportHeight) =>
  Math.min(Math.max(scrollTop, 0), Math.max(0, docHeight - viewportHeight));

// The position `unfocus` restores: whatever `focus` saved before it moved,
// or the top of the document at natural scale if nothing was saved (e.g.
// `unfocus` fires with no prior `focus`). The stack of saved positions lives
// in the controller, not here — this module holds no state of its own.
export const unfocusTarget = (saved) => saved ?? { scrollTop: 0, scale: 1 };
