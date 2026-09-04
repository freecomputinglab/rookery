// `#search-modal`'s overlay: a two-pane listbox and preview over the island's
// rows, opened from a trigger or Ctrl-K.

import { renderRow } from "./row.js";
import { searchSplit } from "./score.js";
import { selection } from "./selection.js";
import { fetchNote } from "./preview.js";
import { markTermsInNode } from "./marks.js";
import { positiveAtoms, splitQuery } from "./tagquery.js";
import { queryTerms } from "./text.js";
import { readLimit } from "./limit.js";
import { renderKeywords } from "./keywords.js";

export const wireModal = (dialog, rows) => {
  const input = dialog.querySelector(".rookery-search-input");
  const list = dialog.querySelector(".rookery-search-list");
  const preview = dialog.querySelector(".rookery-search-preview");
  if (input === null || list === null || preview === null) return null;
  // 30, not `wire`'s 8, and deliberately so: a full-height overlay pane has room
  // a dropdown under an input does not, which is why `#search-modal`'s own
  // default is 30 (`src/lib.typ:416`) where `#search-bar`'s is 8. Do not tidy
  // the two into agreement.
  const limit = readLimit(dialog.dataset.rookerySearchLimit, 30);

  let hits = [];
  // Bumped by every `renderPreview`, so a `fetch` that lands after the reader
  // has moved on cannot paint over a later selection's pane. Arrow-keying down
  // a list of hits starts a request per row it passes through and those can
  // resolve in any order — without this, the slowest one wins the pane.
  let previewGen = 0;

  const renderPreview = () => {
    // `sel` is declared BELOW this function and read only when it runs, which is
    // always after `selection(..)` has returned it — the closure is what makes
    // that legal, and the alternative (threading the index through every caller)
    // would put two copies of "which row is active" in one file.
    const hit = hits[sel.index()];
    const gen = ++previewGen;
    preview.replaceChildren();
    // `replaceChildren` replaces CHILDREN, so the loading flag set below
    // outlives the content it belonged to unless it is deleted by hand. Cleared
    // on the way in, not only when a request settles: this path also runs for a
    // hit with no href to fetch, where nothing would ever clear it.
    delete preview.dataset.rookerySearchLoading;
    if (hit === undefined) return;

    // NO EXCERPT UP FRONT. The fetched rendering is the first and only text this
    // pane shows; until it lands there is the indicator below and nothing else.
    // Painting the island's text first would mean a visible reflow on EVERY
    // selection — plain text for a few milliseconds, then the same note again as
    // real content — and would pin that field to being readable prose rather than
    // a note's most distinctive terms.
    //
    // `renderKeywords` is the FAILED-FETCH fallback and nothing else: a build
    // opened over `file://`, a note whose page 404s, a hit with no href at all.
    // Those are the cases where no rendering is coming and the island's own terms
    // are the final answer.
    if (typeof hit.href !== "string" || hit.href === "") {
      renderKeywords(preview, hit, input.value);
      return;
    }
    // THE LOADING AFFORDANCE, and it is an attribute rather than an element: one
    // data attribute and one `::after` in the stylesheet keeps it out of the
    // content flow entirely — nothing to append, nothing to remove, and no
    // chance of it surviving a `replaceChildren` as a stray node.
    //
    // Set whenever there is an href, cache hit included: the indicator is the
    // pane's only content until the note lands, and a memoised href resolves on a
    // microtask — set and cleared inside one task, before a paint, so nothing
    // flashes.
    preview.dataset.rookerySearchLoading = "true";
    fetchNote(hit.href).then((box) => {
      // Cleared BEFORE the early return, so a miss stops the indicator too: a
      // 404, a `file://` build, a page that is not a minted note all resolve to
      // `null`, and an indicator left spinning would be promising a rendering
      // that is never coming. Guarded on the generation like the paint below it,
      // so a stale request cannot clear a later selection's indicator.
      if (gen === previewGen) delete preview.dataset.rookerySearchLoading;
      if (gen !== previewGen) return;
      // The fallback, and the ONLY place the keyword row is rendered for a hit
      // that had an href: the fetch is settled and it failed, so there is no
      // richer rendering coming and the island's own terms are the final answer.
      if (box === null) {
        renderKeywords(preview, hit, input.value);
        return;
      }
      // The residual, not the raw input: marking the fetched page for the literal
      // "tags:" would highlight an instruction rather than a match. Same rule as
      // both `render`s.
      const terms = queryTerms(splitQuery(input.value.trim()).text);
      // Cloned, not moved: the cache holds this `<div>` for the rest of the
      // session and `markTermsInNode` edits what it walks.
      const clone = box.cloneNode(true);
      markTermsInNode(clone, terms);
      preview.replaceChildren(clone);
    });
  };

  // Marks exactly one row selected (clamped, no wrap), names it as the input's
  // active descendant, scrolls it into view, and re-renders the preview to match.
  // The first three are `selection`'s, shared with `#search-bar`'s dropdown; the
  // preview is this surface's own, which is why it is passed in.
  //
  // `aria-controls` alongside, because `selection` has just given the list an id
  // and the combobox pattern this input already claims (`role="combobox"`,
  // `aria-expanded`) is incomplete without it. The dropdown wired its own at
  // `wire`; the modal never did.
  const sel = selection(list, input, () => renderPreview());
  input.setAttribute("aria-controls", list.id);
  const select = sel.select;

  const render = () => {
    const q = input.value.trim();
    list.replaceChildren();
    // CLEARED HERE, with the rows it referred to, and NOT left to `select(0)` at
    // the bottom: the no-hits path below returns before reaching it, which would
    // leave `aria-activedescendant` naming a row absent from the document.
    // `select(0)` sets it again on every path that has something to select.
    sel.clear();
    // EMPTY QUERY shows the corpus, not nothing: an empty query
    // already returns everything at score 0, dated rows newest-first ahead of
    // undated rows (which keep their id order) — see `dateCmp` — telescope's
    // empty-prompt behaviour, deliberately unlike `#search-bar`'s dropdown,
    // which stays shut on an empty query.
    //
    // With a `tags:` expression and no residual text, that becomes the whole
    // FILTERED corpus ranked the same way — the same sentence one level in.
    const split = splitQuery(q);
    hits = searchSplit(rows, split, limit);
    // The residual, not the raw input: see `wire`'s `render` above. Marking the
    // literal "tags:" in every note is the failure this avoids. And the tag
    // expression's positive atoms alongside, for the chips — this is the surface
    // where they are visible at all.
    const terms = queryTerms(split.text);
    const atoms = positiveAtoms(split.rpn);
    for (const hit of hits) {
      const row = renderRow(hit, terms, atoms);
      row.addEventListener("pointerenter", () => {
        select([...list.children].indexOf(row));
      });
      list.append(row);
    }
    // NO HITS: the pane is emptied HERE, because `select` cannot do it — it
    // returns on `els.length === 0` before reaching its `renderPreview()` call,
    // and `renderPreview` is the only thing that clears the pane. Otherwise a
    // query matching nothing leaves the LAST match's preview on screen beside an
    // empty result list. It does not belong inside `select`, which is about which
    // row is highlighted and is also called from `pointerenter` above, where there
    // is by construction a row to select.
    //
    // `previewGen` is bumped for the reason `renderPreview` bumps it: a `fetchNote`
    // begun for the previous query may still be in flight, and its `.then` paints
    // the pane unless the generation has moved on.
    if (hits.length === 0) {
      previewGen += 1;
      // The generation bump above orphans an in-flight request's paint, and an
      // orphaned `.then` clears no flag — so this path clears it, or the filler
      // sits under a spinner that never stops.
      delete preview.dataset.rookerySearchLoading;
      const empty = document.createElement("p");
      empty.className = "rookery-search-preview-empty";
      empty.textContent = "No match found";
      preview.replaceChildren(empty);
      return;
    }
    select(0);
  };

  input.addEventListener("input", render);

  dialog.addEventListener("keydown", (ev) => {
    if (ev.key === "ArrowDown" || (ev.ctrlKey && ev.key === "n")) {
      ev.preventDefault();
      sel.move(1);
    } else if (ev.key === "ArrowUp" || (ev.ctrlKey && ev.key === "p")) {
      ev.preventDefault();
      sel.move(-1);
    } else if (ev.key === "Enter") {
      ev.preventDefault();
      const hit = hits[sel.index()];
      if (hit !== undefined) window.location.href = hit.href;
    } else if (ev.key === "Escape") {
      // NOT left to native `<dialog>` Escape-to-close, despite that being the
      // usual advice: a focused `type="search"` input with a non-empty value
      // consumes Escape for its own default action, clearing the field, before it
      // reaches the dialog's cancel algorithm — so the modal would not close on
      // the first press. Closing explicitly here is reliable whatever the input
      // holds.
      ev.preventDefault();
      dialog.close();
    }
  });

  // A `<dialog>`'s backdrop clicks register on the dialog element itself, so
  // the click target must BE the dialog (not a descendant) before closing —
  // otherwise every click inside the panel would close it.
  dialog.addEventListener("click", (ev) => {
    if (ev.target === dialog) dialog.close();
  });

  // Resets selection state once the dialog has actually closed, by whatever
  // means — the explicit Escape handler above, a backdrop click, or a caller
  // closing it directly. `clear`, not `select(0)`: the list has not been
  // re-rendered yet, so there is no row 0 to point `aria-activedescendant` at,
  // and the next `open` re-renders and selects for itself.
  dialog.addEventListener("close", () => {
    sel.clear();
  });

  return {
    open: () => {
      dialog.showModal();
      render();
      // Select the input's contents (not clear it), so a reopen starts a
      // fresh query without losing what was there before.
      input.focus();
      input.select();
    },
  };
};
