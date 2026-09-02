// The keyword row: the failed-fetch fallback in `#search-modal`'s preview pane,
// and the one place the island's compressed `body` field is reader-facing.

import { KEYWORD_LIMIT, appendMarked, matchRanges } from "./marks.js";
import { fold } from "./text.js";

// THE KEYWORD ROW — the failed-fetch fallback, and the ONE place the
// compressed index is reader-facing. The island's `body` field is not prose:
// it is that note's most distinctive terms, space-joined in weight order.
// MEASURED on a weeknotes copy: `"entry actual notes general introductory site
// first weeknotes wrote post posted blog writing"`. There is nothing there to
// excerpt, which is why the excerpt is gone rather than merely demoted.
//
// CHIPS, NOT A PARAGRAPH. Set as running text that string reads as debug
// output that leaked into the UI; one box per term says "these are the note's
// terms" without needing a caption to say it. It also makes the ORDER visible
// as an order: the compression pass already sorts by weight, so display order
// is meaningful — most distinctive first.
//
// Except that a term the reader's query matched is hoisted ahead of the
// unmatched ones among the shown terms. Weight order is the default, but a
// matched term is WHY this note is on screen, and it must not be the one term
// the cap cut off. Sliced to `KEYWORD_LIMIT` after the hoist for that reason.
//
// The line above the row says why a bag of words is the preview at all —
// without it a reader is left to infer that the pane failed rather than that
// this is the intended rendering. It reuses `.rookery-search-preview-empty`
// rather than earning a class of its own: it is the same KIND of line as "No
// preview" and "No match found" — muted, italic, a note ABOUT the pane rather
// than content in it.
//
// AN EMPTY BODY KEEPS THE PLAIN "No preview" LINE, and it is a real case, not
// a defensive one — MEASURED: a genuinely empty note ships an empty `body`,
// and `body-search: false` omits the field from every row. An empty chip row
// would be a frame with nothing in it above a sentence explaining nothing.
//
// `createElement`/`textContent` throughout, never `innerHTML`, for the reason
// the module header gives: a term comes out of the author's own notes and must
// never be able to inject markup. `<mark>` is the only markup here and
// `appendMarked` is what appends it — the same element and class a result row
// and a fetched note's text nodes are marked with, so a match looks identical
// wherever the reader meets it.
export function renderKeywords(preview, hit, queryValue) {
  const terms = (hit.body ?? "").split(" ").filter((t) => t !== "");
  if (terms.length === 0) {
    const empty = document.createElement("p");
    empty.className = "rookery-search-preview-empty";
    empty.textContent = "No preview";
    preview.append(empty);
    return;
  }
  const queryTerms = fold(queryValue.trim()).split(" ").filter((t) => t !== "");
  // The ranges are carried alongside each term rather than recomputed for the
  // chips: whether a term matched IS whether it has any ranges, so one
  // `matchRanges` per term answers both the hoist and the marking.
  const matched = [];
  const rest = [];
  for (const term of terms) {
    const ranges = matchRanges(term, queryTerms);
    (ranges.length > 0 ? matched : rest).push({ term, ranges });
  }
  const why = document.createElement("p");
  why.className = "rookery-search-preview-empty";
  why.textContent = "This note’s page could not be loaded — showing its keywords instead.";
  const row = document.createElement("div");
  row.className = "rookery-search-keywords";
  for (const { term, ranges } of [...matched, ...rest].slice(0, KEYWORD_LIMIT)) {
    const chip = document.createElement("span");
    chip.className = "rookery-search-keyword";
    appendMarked(chip, term, ranges);
    row.append(chip);
  }
  preview.append(why, row);
}
