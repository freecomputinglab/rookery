// Marking matched terms inside rendered text, for the keyword row and the
// preview pane.

import { clusters, fold } from "./text.js";

// How many chips the keyword row shows. The compressed field can run to dozens of
// terms, and a 48-term row is a wall of boxes rather than a preview. Not a knob:
// it is an implementation detail of the modal, where `#search-index`'s
// `body-terms` is a public contract.
export const KEYWORD_LIMIT = 12;
// Every occurrence of every `terms` entry in `text`, folded and case-insensitive,
// merged where they overlap. UTF-16 string offsets throughout: nothing marked here
// — a title, an id, a keyword chip, a fetched note's text nodes — is ever diffed
// against a Typst counterpart, so cluster precision would buy nothing. `fold` is
// length-preserving, each folded character replacing exactly one, so an offset
// found in the FOLDED copy slices correctly out of `text` itself.
export const matchRanges = (text, terms) => {
  const folded = fold(text);
  const ranges = [];
  for (const term of terms) {
    if (term === "") continue;
    let from = 0;
    while (true) {
      const idx = folded.indexOf(term, from);
      if (idx === -1) break;
      ranges.push({ start: idx, end: idx + term.length });
      from = idx + term.length;
    }
  }
  if (ranges.length === 0) return [];
  ranges.sort((a, b) => a.start - b.start);
  const merged = [ranges[0]];
  for (const r of ranges.slice(1)) {
    const last = merged[merged.length - 1];
    if (r.start <= last.end) last.end = Math.max(last.end, r.end);
    else merged.push({ ...r });
  }
  return merged;
};
// Appends `text` into `container` as plain text nodes plus `<mark>`s for
// every range `matchRanges` found — never `innerHTML`, matching every other
// mark-insertion in this module.
export const appendMarked = (container, text, ranges) => {
  let cursor = 0;
  for (const r of ranges) {
    if (r.start > cursor) container.append(document.createTextNode(text.slice(cursor, r.start)));
    const mark = document.createElement("mark");
    mark.className = "rookery-search-mark";
    mark.textContent = text.slice(r.start, r.end);
    container.append(mark);
    cursor = r.end;
  }
  if (cursor < text.length) container.append(document.createTextNode(text.slice(cursor)));
};
// Wraps every occurrence of every `terms` entry inside `root`'s text nodes in
// a `<mark>`, walking the real DOM rather than reconstructing HTML from a
// string — `root` is author-written, Typst-rendered content lifted out of the
// note's own minted page, so there is real markup to preserve: a link's
// `href`, a code span's highlighting, and so on. Case-insensitive and
// `-`/`_`-folding, the same `fold()` every other match here uses.
export const markTermsInNode = (root, terms) => {
  if (terms.length === 0) return;
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  const textNodes = [];
  let n;
  while ((n = walker.nextNode()) !== null) textNodes.push(n);

  for (const textNode of textNodes) {
    const ranges = matchRanges(textNode.textContent, terms);
    if (ranges.length === 0) continue;
    const frag = document.createDocumentFragment();
    appendMarked(frag, textNode.textContent, ranges);
    textNode.replaceWith(frag);
  }
};
