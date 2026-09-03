// The preview pane's rich content: fetching a note's own minted page and
// extracting the part of it worth showing.
//
// `#search-modal` emits the JSON island and nothing else, so the pane's rendering
// is FETCHED: the selected note's minted page (`ideas/<slug>.html`, which
// rookery's `.marrow.typ` emits) is requested the first time that row is selected.
// Rendering every note's body into every page instead costs `notes × pages` Typst
// renders per build; a page rheo already emits costs the build nothing.

import { markTermsInNode } from "./marks.js";

// Keyed by href and holding the PROMISE, not the result: two quick selections of
// one row must share a single request, and a MISS has to be remembered too — as a
// resolved `null` — so a note whose page 404s is not re-fetched on every arrow key.
// Session-lived, a `Map` in module scope, gone on navigation.
export const previewCache = new Map();
// The note itself, lifted out of its minted page: every element between the
// page's heading and its `<footer class="idea-footer">` — body, footnotes,
// references. Not the heading, because the selected result row above the pane
// already carries the title and id; not the footer, because Context/Backlinks
// are navigation for that page rather than content of the note. `null` when the
// document holds no `h1.idea` (not a minted page) or the range is empty.
//
// THE RANGE STARTS AFTER THE HEAD WRAPPER, NOT AFTER THE `<h1>`, and the two are
// different elements: rookery wraps a minted page's permalink tab and its `<h1>`
// in one `<div class="idea-head" data-rookery="head">`, inside which the `<h1>` is
// the LAST child — so walking the heading's own siblings finds nothing at all. The
// fallback to the `<h1>` covers a page minted before that wrapper existed, where
// the heading is a top-level sibling of the body.
//
// THE HEAD LOOKUP MATCHES EITHER SHAPE (`.idea-head` OR `[data-rookery="head"]`)
// because this file previews a page FETCHED over the network, which may have been
// built by a core older than the `data-rookery` attributes — such a page carries
// only the class. A current core always emits both together (`_head` in
// `permalink.typ`), so matching either is what lets this file preview a page from
// either.
//
// Returned inside `<div class="idea-window idea-window-plain" data-rookery="window"
// data-rookery-plain="plain">` wrapping a `<div class="idea-window-body"
// data-rookery="window-body">`, wearing the heading container's own `style`. Every
// part of that is load-bearing. The nesting and the class names are exactly what
// rookery's `#idea-body` produces, so the stylesheet needs no new selectors —
// including the `[data-rookery="window-body"] > :first-child` margin rule, which
// counts on the extra level. THE ATTRIBUTES ARE ADDED HERE, not just the classes:
// this wrapper is built by this file rather than fetched, so it has to carry them
// itself for core.css's and search.css's attribute selectors — including the
// plain-window override — to apply to it at all. `data-rookery-plain` is rookery's
// modifier for "not a box", stripping the accent rule and hover tint a real
// `#window` draws, which a preview must not draw inside the pane's own frame. The
// style attribute carries `--idea-link-color` and the rest of the per-note theme
// properties, which on a minted page live on the heading container rather than on
// a `.idea-box`: take the siblings and leave that behind and the preview renders in
// rookery's default colours instead of the project's.
//
// Relative `href`/`src` values are resolved against the FETCHED page's URL, not
// left as written. A note's page sits in `ideas/`, the modal can be open on a
// vertebra at any depth, and a `../style.css` or `../index.html#loc-3` written
// for the first resolves somewhere else entirely in the second. Fragment-only
// links are left alone: they address content that travelled here too (a
// footnote marker and its footnote are both inside this range).
//
// `<script>` elements are dropped. A minted page's own scripts sit outside this
// range, so this guards against an author writing `html.elem("script", ..)`
// inside a note body rather than against anything routine — but a search
// preview should never run code merely to be looked at.
export const extractNote = (doc, pageUrl) => {
  // Matches either shape, exactly as the `.idea-head` lookup below does: the
  // class is a project's configurable `css-prefix:` hook and disappears the
  // moment a project renames its stem, so `data-rookery="idea"` is the
  // selector that survives that rename. `h1.idea` stays alongside it for a
  // page built by a core old enough to carry only the class.
  const h1 = doc.querySelector('h1.idea, h1[data-rookery="idea"]');
  if (h1 === null) return null;
  const head = h1.closest('.idea-head, [data-rookery="head"]') ?? h1;
  const box = document.createElement("div");
  box.className = "idea-window idea-window-plain";
  box.dataset.rookery = "window";
  box.dataset.rookeryPlain = "plain";
  const style = head.getAttribute("style") ?? h1.getAttribute("style");
  if (style !== null) box.setAttribute("style", style);
  const inner = document.createElement("div");
  inner.className = "idea-window-body";
  inner.dataset.rookery = "window-body";
  box.append(inner);
  for (let el = head.nextElementSibling; el !== null; el = el.nextElementSibling) {
    if (el.matches('footer.idea-footer, footer[data-rookery="footer"]')) break;
    inner.append(document.importNode(el, true));
  }
  if (inner.childNodes.length === 0) return null;
  for (const script of box.querySelectorAll("script")) script.remove();
  for (const el of box.querySelectorAll("[href], [src]")) {
    for (const attr of ["href", "src"]) {
      const raw = el.getAttribute(attr);
      if (raw === null || raw === "" || raw.startsWith("#")) continue;
      try {
        el.setAttribute(attr, new URL(raw, pageUrl).href);
      } catch {
        // Not a resolvable URL — leave the value exactly as the author wrote
        // it rather than guessing at a rewrite.
      }
    }
  }
  return box;
};
// One fetch-and-extract per href, memoised. Resolves to `extractNote`'s `<div>`
// or to `null`, and NEVER rejects: no server (a build opened over `file://`), a
// 404, a page that is not a minted note — all of them are a `null`, because the
// caller's answer to "no rich content" is the keyword row it renders instead,
// not an error to report.
export const fetchNote = (href) => {
  if (previewCache.has(href)) return previewCache.get(href);
  const pending = fetch(href)
    .then((res) => (res.ok ? res.text() : null))
    .then((html) =>
      html === null
        ? null
        : extractNote(
            new DOMParser().parseFromString(html, "text/html"),
            new URL(href, document.baseURI),
          ),
    )
    .catch(() => null);
  previewCache.set(href, pending);
  return pending;
};
