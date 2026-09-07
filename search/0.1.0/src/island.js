// Reading the index `#search-index` put on the page — a pointer at the build's
// one fetched `rookery/search/index.json`, or the JSON inline.
//
// WHICH ONE IS ON THE PAGE is read off the element, never guessed: the Typst
// side writes `data-rookery-search-src` under `mode: "asset"` and nothing under
// `mode: "inline"`. So a site switches modes without the script knowing which it
// chose, and a page carrying both (two bars, two modes) works.

// The inline form, kept synchronous and kept exported: it is part of the
// published `RookerySearch` surface, and a caller holding the JSON in the page
// has nothing to await.
export const readIndex = (elemId) => {
  const el = document.getElementById(elemId);
  if (el === null) return null;
  try {
    return JSON.parse(el.textContent);
  } catch {
    return null;
  }
};

// The mode-agnostic form. Resolves to the rows, or to `null` when there is no
// index element, the fetch fails, or the payload does not parse — the same
// "leave the input inert rather than throw" contract `readIndex` has.
//
// A ROW'S `href` COMES BACK PAGE-RELATIVE IN BOTH MODES. The inline island's
// hrefs were built against the page they sit in and need no adjustment. The
// fetched file is shared by every page and therefore carries site-root paths, so
// each row's href is joined onto the depth prefix that page published as
// `data-rookery-search-base`. Everything downstream of here — `bar.js`,
// `modal.js`, `preview.js` — reads `row.href` and cannot tell the modes apart.
export const loadIndex = async (elemId) => {
  const el = document.getElementById(elemId);
  if (el === null) return null;

  const src = el.dataset.rookerySearchSrc;
  if (src === undefined) return readIndex(elemId);

  const base = el.dataset.rookerySearchBase ?? "";
  try {
    const res = await fetch(src);
    if (!res.ok) return null;
    const rows = await res.json();
    if (!Array.isArray(rows)) return null;
    return base === "" ? rows : rows.map((row) => ({ ...row, href: base + row.href }));
  } catch {
    return null;
  }
};
