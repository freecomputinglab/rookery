// One result row: the note's title, its tag pills, and the keyword row under it.

import { fold } from "./text.js";
import { KEYWORD_LIMIT, appendMarked, matchRanges } from "./marks.js";

// One `<a class="rookery-search-row">` per hit, carrying the title (or the id
// when untitled) and the bracketed id — bracketed because that is how an id
// reads everywhere else in a rookery: `[idea:etal]` beside a note's title, in
// a window's summary, in an outline row. Shared by the dropdown (`wire`) and
// the modal (`wireModal`) so the two never drift into building rows two ways.
//
// `terms` highlights every occurrence it finds in the title and id text, with the
// same `<mark>` the preview pane uses. It is a literal-substring highlight rather
// than a reconstruction of `fuzzy-score`'s SUBSEQUENCE match, so the two can
// disagree — a scattered subsequence match marks nothing — but a literal substring
// is what a reader typed most of the time, and marking that beats marking nothing.
//
// A TAGGED HIT ALSO GETS A SECOND LINE of tag pills, emitted here in the one
// shared row builder. The dropdown gets the same DOM and hides it in CSS
// (`.rookery-search-tags { display: none }`, shown again by
// `.rookery-search-list .rookery-search-tags`), which is the whole modal-only
// mechanism: no `showTags` parameter, no branch on the calling surface, no second
// row builder.
//
// The tags are why a `tags:` query is legible: an atom matches a tag by PREFIX, so
// `tags:note` also matches `notebook`, and a row showing its own tags explains its
// own presence in the list rather than reading as a mystery hit.
//
// `atoms` is `positiveAtoms(rpn)` — passed in rather than re-parsed here,
// because both callers already hold the split query. It is the THIRD argument
// the tag pills left room for, and it is only ever the positive atoms: a
// negation marks nothing (see `positiveAtoms`), and the residual TEXT `terms`
// never mark a chip, because the text query does not search tags and marking
// one would claim it does.
export const renderRow = (hit, terms, atoms = []) => {
  const a = document.createElement("a");
  a.className = "rookery-search-row";
  a.setAttribute("role", "option");
  a.href = hit.href;
  const title = document.createElement("span");
  title.className = "rookery-search-title";
  // NO `|| hit.name` FALLBACK: `text` is rookery's derived `label`, which is never
  // empty, so a fallback would be dead code hiding a real bug if the island ever
  // shipped `""`.
  const titleText = hit.text;
  appendMarked(title, titleText, matchRanges(titleText, terms));
  const id = document.createElement("span");
  id.className = "rookery-search-id";
  const idText = `[${hit.id}]`;
  appendMarked(id, idText, matchRanges(idText, terms));
  // A `<wbr>` BETWEEN THE TWO SPANS, and it is load-bearing rather than
  // cosmetic. `.rookery-search-id` is `white-space: nowrap`, and appending the
  // spans adjacently gives the line breaker no opportunity between them — so
  // it treats the title's last word plus the whole `[idea:<slug>]` id as one
  // unbreakable run. A bracketed slug is long, that run never fits, and the
  // breaker falls back to the last opportunity it does have: the space before
  // the title's final word, which then drops onto line two under the id.
  //
  // `<wbr>` adds no advance width, so the id's x position is unchanged and the gap
  // still comes from `.rookery-search-id`'s own `margin-left: 0.4em`. A space text
  // node would widen the gap by a word space, and
  // `.rookery-search-title { display: block }` would force the id onto its own
  // line in every row.
  a.append(title, document.createElement("wbr"), id);
  // `hit.tags ?? []` for the same reason `search` reads it that way: a note with no
  // tags has no key at all, `#search-index` omitting the field rather than shipping
  // `[]` per row.
  //
  // OMITTED ENTIRELY for an untagged note, never emitted empty. The modal's
  // list has a fixed max-height, so a blank second line on every untagged row
  // would cut the number of visible results for nothing; an untagged row stays
  // one line tall.
  //
  // `<span>`, never `<div>`/`<ul>`/`<li>`. This package's markup is phrasing
  // content only throughout (see `#search-bar`'s comment in `src/lib.typ`)
  // because a bar has to be placeable mid-sentence; a `display: flex` span is
  // how the second line is made.
  //
  // Each chip carries rookery's own `idea-tag-<tag>` class alongside this
  // package's, mirroring what rookery emits on a note's heading and box, so a
  // project already styling one of its tags gets the modal for free. A tag
  // containing a space emits a broken two-class `idea-tag-my tag` here, exactly as
  // it does in rookery — sanitising it here would disagree with rookery's own
  // output.
  //
  // A CHIP THAT IS EVIDENCE FOR THE QUERY IS MARKED, and only the PREFIX an
  // atom actually matched — `notebook` under `tags:note` shows `note` marked
  // and `book` plain, which is the whole point: the mark is what explains a
  // prefix match. The LONGEST matching atom wins, so `tags:note|noteb` marks
  // `noteb` rather than stopping at whichever atom came first in the RPN.
  //
  // `fold` is length-preserving (each folded character replaces exactly one —
  // see `matchRanges`), so an atom's length measured against the folded copy
  // slices correctly out of the chip's own text. That is what makes marking a
  // prefix safe with no cluster arithmetic.
  //
  // A chip that did NOT contribute gets no mark at all: no `atoms` entry is its
  // prefix, `ranges` is empty, and `appendMarked` degrades to a single text
  // node. Same `<mark class="rookery-search-mark">` as the title, the id, the
  // keyword chips and the fetched page, via the file's one mark-inserting pair.
  // `createElement`/`textContent` throughout, never `innerHTML` — a tag comes
  // out of the author's own notes and must never be able to inject markup.
  const tags = hit.tags ?? [];
  if (tags.length > 0) {
    const tagBox = document.createElement("span");
    tagBox.className = "rookery-search-tags";
    for (const t of tags) {
      const chip = document.createElement("span");
      chip.className = `rookery-search-tag idea-tag-${t}`;
      const folded = fold(t);
      let len = 0;
      for (const atom of atoms) {
        if (atom.length > len && folded.startsWith(atom)) len = atom.length;
      }
      appendMarked(chip, t, len === 0 ? [] : [{ start: 0, end: len }]);
      tagBox.append(chip);
    }
    a.append(tagBox);
  }
  return a;
};
