// `#search-bar`'s dropdown: a combobox over the island's rows, opening under the
// input as the reader types.

import { renderRow } from "./row.js";
import { search } from "./score.js";
import { selection } from "./selection.js";
import { positiveAtoms, splitQuery } from "./tagquery.js";
import { fold } from "./text.js";
import { readLimit } from "./limit.js";

export const wire = (root, rows, n) => {
  const input = root.querySelector(".rookery-search-input");
  const list = root.querySelector(".rookery-search-results");
  if (input === null || list === null) return;
  const limit = readLimit(root.dataset.rookerySearchLimit, 8);

  // Assigned here, not in the markup: a bar has to be placeable more than once
  // on a page, and duplicate ids would break both `aria-controls` and any CSS
  // or script keyed off them.
  list.id = `rookery-search-listbox-${n}`;
  input.setAttribute("aria-controls", list.id);

  // Set by a click outside this bar, cleared the moment the reader types
  // again. It is a separate piece of state from "the query is empty", because
  // a dismissed dropdown must STAY shut while its query is still in the input
  // — including when the reader clicks back into the field. Only new typing
  // brings it back, which is the one unambiguous signal that they want it.
  let dismissed = false;

  const sel = selection(list, input);

  const render = () => {
    const q = input.value.trim();
    list.replaceChildren();
    // BEFORE the early return below, not after the rows are appended: the rows
    // this cleared against are already gone, and a closed dropdown must not leave
    // the input pointing at an option that no longer exists.
    sel.clear();
    const open = q !== "" && !dismissed;
    root.dataset.rookerySearchOpen = open ? "true" : "false";
    input.setAttribute("aria-expanded", open ? "true" : "false");
    if (!open) return;
    // HIGHLIGHT TERMS COME FROM THE RESIDUAL, not the raw input: a query of
    // `tags:draft window` must mark "window" and never the literal "tags:draft",
    // which is an instruction rather than something any note contains.
    //
    // Note the `open` test above still reads the RAW input, on purpose — a bare
    // `tags:draft` with no residual text should open the dropdown, and it is
    // non-empty even though its residual is "".
    //
    // The tag expression's POSITIVE atoms travel beside them, so a chip an atom
    // prefix-matched is marked too. Computed once per render, not per row.
    const { rpn, text } = splitQuery(q);
    const terms = fold(text).split(" ").filter((t) => t !== "");
    const atoms = positiveAtoms(rpn);
    for (const hit of search(rows, q, limit)) {
      list.append(renderRow(hit, terms, atoms));
    }
  };

  input.addEventListener("input", () => {
    dismissed = false;
    render();
  });
  input.addEventListener("keydown", (ev) => {
    // ArrowDown/ArrowUp plus Ctrl-n/Ctrl-p, the same pair the modal takes, so a
    // reader does not have to learn two sets of keys for one search.
    //
    // `preventDefault` on the arrows because a `type="search"` input would
    // otherwise move the text caret to the end or the start of the value — the
    // arrows belong to the list while the list is open, which is exactly what
    // `open` tests. With the dropdown shut they are the caret's again.
    const open = root.dataset.rookerySearchOpen === "true";
    if (open && (ev.key === "ArrowDown" || (ev.ctrlKey && ev.key === "n"))) {
      ev.preventDefault();
      sel.move(1);
    } else if (open && (ev.key === "ArrowUp" || (ev.ctrlKey && ev.key === "p"))) {
      ev.preventDefault();
      sel.move(-1);
    } else if (ev.key === "Enter") {
      // THE HREF COMES OFF THE ROW, not out of a parallel `hits` array the way
      // the modal reads it: the row IS an `<a>`, so its `href` property is the
      // resolved URL and there is no second copy of the result list to keep in
      // step with the DOM. Enter with nothing selected is left alone — the field
      // may be inside a form, and swallowing a submit no reader asked us to
      // swallow is worse than doing nothing.
      const row = sel.current();
      if (row !== null) {
        ev.preventDefault();
        window.location.href = row.href;
      }
    } else if (ev.key === "Escape") {
      input.value = "";
      dismissed = false;
      render();
      input.blur();
    }
  });

  return {
    root,
    // Called for every click that lands outside this bar. Leaves the query in
    // the input: the reader dismissed a dropdown, they did not ask to lose
    // what they had typed.
    dismiss: () => {
      if (dismissed) return;
      dismissed = true;
      render();
    },
  };
};
