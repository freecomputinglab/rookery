// The active option, shared by the bar and the modal: exactly one row of a
// `role="listbox"` marked, and the `role="combobox"` input told which.
//
// ONE implementation for both surfaces, because it is one job — mark the active
// row, name it on the input, keep it in view. They differ only in what FOLLOWS a
// selection, the modal repainting its preview pane and the bar doing nothing, so
// that is the parameter.
//
// `-1` MEANS NO ACTIVE OPTION, and it is a real state rather than a sentinel for
// zero. The modal opens on a selected first row, its preview pane needing
// something to show; the bar must not, its dropdown sitting under a field the
// reader is still typing in, where a pre-highlighted row would claim Enter goes
// somewhere before they have looked. So the bar clears to `-1` on every render and
// the first ArrowDown lands on row 0.
//
// CLAMPED, NEVER WRAPPED, at both ends: arrowing past the last row keeps the last
// row. A wrap in a list whose length changes on every keystroke loses the reader's
// place. From `-1`, ArrowUp clamps to row 0 too, so the first press activates the
// list either way.
//
// `aria-activedescendant` is on the INPUT, which is where the combobox pattern
// puts it and the only place it can be: focus never leaves the field on either
// surface, so a screen reader learns the current option from that attribute or not
// at all. It needs per-row ids, which cannot live in the markup — a bar is
// placeable more than once on a page — so they are assigned here from the list's
// own id, itself assigned at runtime for the same reason.
let listSeq = 0;
export const selection = (list, input, onSelect = null) => {
  if (list.id === "") list.id = `rookery-search-list-${listSeq++}`;
  let selected = -1;

  const rows = () => list.querySelectorAll(".rookery-search-row");

  // Selecting nothing: the attribute is REMOVED rather than set empty, because an
  // empty `aria-activedescendant` is a reference to an element with no id rather
  // than the absence of one.
  const clear = () => {
    selected = -1;
    input.removeAttribute("aria-activedescendant");
    for (const el of rows()) {
      el.setAttribute("aria-selected", "false");
      el.removeAttribute("data-rookery-search-selected");
    }
  };

  const select = (i) => {
    const els = rows();
    if (els.length === 0) {
      clear();
      return;
    }
    const previous = selected;
    selected = Math.max(0, Math.min(i, els.length - 1));
    // IDS ARE WRITTEN ONLY WHERE THEY ARE WRONG. Every row needs
    // `<list>-opt-<index>` for `aria-activedescendant` to name it, and after a
    // re-render the fresh rows have none — but an unchanged list is the common
    // case, and an arrow key through it should not rewrite every id it passes.
    for (const [idx, el] of els.entries()) {
      const want = `${list.id}-opt-${idx}`;
      if (el.id !== want) el.id = want;
    }
    // TWO ROWS CHANGE PER MOVE — the one leaving and the one arriving — so an
    // arrow key writes two attributes rather than two per row. From NO SELECTION
    // the whole list is written once instead: every row has to state its own
    // `aria-selected`, and a freshly rendered row carries none, so a screen reader
    // would otherwise read a list where only one row said anything.
    if (previous < 0) {
      for (const [idx, el] of els.entries()) {
        if (idx === selected) continue;
        el.setAttribute("aria-selected", "false");
        el.removeAttribute("data-rookery-search-selected");
      }
    } else if (previous < els.length && previous !== selected) {
      els[previous].setAttribute("aria-selected", "false");
      els[previous].removeAttribute("data-rookery-search-selected");
    }
    els[selected].setAttribute("aria-selected", "true");
    els[selected].setAttribute("data-rookery-search-selected", "true");
    input.setAttribute("aria-activedescendant", els[selected].id);
    els[selected].scrollIntoView({ block: "nearest" });
    if (onSelect !== null) onSelect();
  };

  return {
    select,
    clear,
    // `selected + d` through `select`, so the clamp is in one place.
    move: (d) => select(selected + d),
    index: () => selected,
    current: () => rows()[selected] ?? null,
  };
};
