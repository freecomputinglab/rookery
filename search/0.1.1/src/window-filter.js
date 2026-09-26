// Wires `#window`'s own filter chrome (`display-filter: true` in
// `@rookery/core`). Core emits the container, the text box and the pills —
// it ships no JavaScript, so every control sits there inert until this file
// attaches. `core.css` hides the controls behind
// `[data-rookery="window-filter"]:not([data-rookery-ready])`, so wiring is
// also what reveals them.
//
// ONE CONTAINER PER `[data-rookery="window-filter"]`. Its controls div holds
// the text box and the pills; every OTHER direct child is one `<figure>`
// window. A window's tag-carrying element is either a full window root
// (`[data-rookery="window"]`) or, at `unfurl: 0`, a link row
// (`li[data-rookery-window-link]`) — `_window-link`'s bottomed-out shape —
// and both carry `data-rookery-tags` the same space-joined way a `#panel`
// row does. A figure with neither counts as untagged, matching no pill and
// blocking none.
//
// REUSES `passesTags` FROM `panel.js` rather than re-deriving the "any" pill
// rule: a second pill widens, exactly as it does for `#filter-panel`, and one
// predicate should say so once.
//
// ONLY DIRECT CHILDREN of the container are read as windows. A window nested
// inside a transcluded body sits deeper than that and is never a candidate
// for filtering on its own — filtering the outer window is enough to hide it
// too.

import { passesTags } from "./panel.js";

// The title text to match, and the tag set to test pills against, read off
// one figure. `full` wins over the link-row shape because a figure only ever
// carries one or the other — `unfurl: 0` renders the link row, anything else
// the full window.
const describe = (figure) => {
  const full = figure.querySelector('[data-rookery="window"]');
  if (full !== null) {
    const titleEl = full.querySelector('[data-rookery="window-title"]');
    const title = titleEl !== null ? titleEl.textContent : figure.textContent;
    const raw = full.getAttribute("data-rookery-tags") ?? "";
    return { title, tags: new Set(raw.split(" ").filter(Boolean)) };
  }
  const link = figure.querySelector("li[data-rookery-window-link]");
  if (link !== null) {
    const a = [...link.children].find((el) => el.tagName === "A") ?? null;
    const title = a !== null ? a.textContent : figure.textContent;
    const raw = link.getAttribute("data-rookery-tags") ?? "";
    return { title, tags: new Set(raw.split(" ").filter(Boolean)) };
  }
  // No tag-carrying element: still has a title to match text against, but no
  // tag can ever select it — an empty set already means "matches no pill".
  return { title: figure.textContent, tags: new Set() };
};

// Wires one container. Returns `null`, wiring nothing, when it is already
// marked ready — a live-reload morph can hand `initWindowFilters` the same
// container twice, and a second pass must not double-bind a pill's click
// handler (one press would then toggle `aria-pressed` on and back off,
// looking like nothing happened).
export const wireWindowFilter = (container) => {
  if (container.hasAttribute("data-rookery-ready")) return null;

  const input = container.querySelector('[data-rookery="window-filter-input"]');
  const figures = [...container.children].filter((el) => el.tagName === "FIGURE");
  const rows = figures.map((figure) => {
    const { title, tags } = describe(figure);
    return { figure, title: title.trim().toLowerCase(), tags };
  });

  // Read once, same as `#panel`'s rows: filtering only ever toggles `hidden`
  // on the figures already in `rows`, never re-queries the container.
  const pressed = new Set();

  const apply = () => {
    const needle = (input?.value ?? "").trim().toLowerCase();
    for (const row of rows) {
      const textOk = needle === "" || row.title.includes(needle);
      // AND with the pills — see `panel.js`'s `apply` for why that composition
      // is the only one that is not surprising.
      row.figure.hidden = !(textOk && passesTags(row, pressed, "any"));
    }
  };

  if (input !== null) {
    input.addEventListener("input", apply);
  }

  const pillByTag = new Map();
  for (const pill of container.querySelectorAll('[data-rookery="window-filter-pill"]')) {
    const tag = pill.getAttribute("data-rookery-filter-tag");
    if (!tag) continue;
    pillByTag.set(tag, pill);
    pill.addEventListener("click", () => {
      if (pressed.has(tag)) pressed.delete(tag);
      else pressed.add(tag);
      pill.setAttribute("aria-pressed", pressed.has(tag) ? "true" : "false");
      apply();
    });
  }

  // A tag chip in an entry's hat becomes that tag's pill's second button,
  // but only when the pill exists — a chip for a tag the filter offers no
  // pill for (e.g. `post` where every entry carries it) stays untouched and
  // inert. Only DIRECT-CHILD figures are read, the same rule `describe`
  // already follows, so a chip belonging to a window nested inside a
  // transcluded body is left alone — filtering the outer window already
  // hides it.
  for (const figure of figures) {
    for (const chip of figure.querySelectorAll('[data-rookery="tab"] > [data-rookery="tag"]')) {
      const tag = chip.getAttribute("data-rookery-tags");
      if (tag && pillByTag.has(tag)) chip.setAttribute("data-rookery-filter-chip", "");
    }
  }

  // ONE delegated listener for every chip, rather than one per chip: a
  // chip's matching pill already owns the toggle logic, so a chip click just
  // replays that pill's own `.click()` — the two paths are literally one.
  // `preventDefault`/`stopPropagation` come first because a click on a chip
  // is otherwise swallowed two different ways: a link row's stretched
  // overlay anchor still receives it beneath the chip (search.css lifts the
  // chip above the overlay, but the browser still needs telling not to
  // follow the link), and inside a full window the chip sits inside
  // `<summary>`, so without `stopPropagation` the same click also toggles
  // the window open or closed.
  container.addEventListener("click", (event) => {
    const chip = event.target.closest("[data-rookery-filter-chip]");
    if (chip === null || !container.contains(chip)) return;
    const tag = chip.getAttribute("data-rookery-tags");
    const pill = tag ? pillByTag.get(tag) : undefined;
    if (pill === undefined) return;
    event.preventDefault();
    event.stopPropagation();
    pill.click();
  });

  // Marked ready LAST, after every listener is bound and the first `apply()`
  // has run — the same order `wirePanel` marks `data-panel-ready`, so a
  // container never reads as live before it actually is. The chip listener
  // sits on the container itself, so this same early return also stops a
  // second `wireWindowFilter` pass from binding it twice.
  container.setAttribute("data-rookery-ready", "ready");
  apply();
  return { container, apply };
};

// EVERY CONTAINER'S FAILURE IS ITS OWN. One malformed container must not take
// the rest down with it, the same reasoning `initPanels` states for `#panel`.
export const initWindowFilters = (root = document) => {
  for (const container of root.querySelectorAll('[data-rookery="window-filter"]')) {
    try {
      wireWindowFilter(container);
    } catch (err) {
      console.error(
        "@rookery/search: a #window filter could not be wired and is left inert.",
        container,
        err,
      );
    }
  }
};
