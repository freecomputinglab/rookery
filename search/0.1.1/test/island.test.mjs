// `loadIndex(elemId)` — the mode-agnostic index reader. It has to answer two
// shapes of page from the same element id: an inline island carrying the JSON
// (`mode: "inline"`), and a pointer at the build's one fetched file
// (`mode: "asset"`). The mode is read off `data-rookery-search-src`, never
// guessed, so these tests fix that attribute's meaning as the contract.
//
// THE REBASING IS THE PART WORTH PINNING. A fetched index is shared by every
// page, so it carries site-root hrefs; the inline island's are measured from
// the page it sits in. `loadIndex` joins the fetched rows onto the page's own
// `data-rookery-search-base` prefix, and everything downstream reads `row.href`
// without knowing which mode produced it. A wrong prefix here is a site of
// broken links that no Typst test can see.
import { test } from "node:test";
import assert from "node:assert/strict";
import { parseHTML } from "linkedom";
import { readIndex, loadIndex } from "../src/island.js";

const ROWS = [
  { id: "idea:etal", name: "etal", text: "Et al", href: "ideas/etal.html" },
  { id: "idea:flat", name: "flat", text: "Flat", href: "ideas/flat.html" },
];

// One page per test, installed as the global `document` the way a real page is.
const page = (body) => {
  const { document } = parseHTML(`<!doctype html><body>${body}</body>`);
  globalThis.document = document;
};

// `fetch` is global in node 18+, so a stub has to be installed and removed
// rather than injected. `calls` is what proves the fetch happened at all.
const stubFetch = (impl) => {
  const calls = [];
  globalThis.fetch = async (url) => {
    calls.push(url);
    return impl(url);
  };
  return calls;
};

const ok = (value) => ({ ok: true, json: async () => value });

test("loadIndex: no element for the id is null, not a throw", async () => {
  page(`<div></div>`);
  assert.equal(await loadIndex("rookery-search-index"), null);
});

test("loadIndex: an inline island is parsed in place, with no fetch", async () => {
  page(
    `<script type="application/json" id="rookery-search-index">${JSON.stringify(ROWS)}</script>`,
  );
  const calls = stubFetch(() => ok([]));
  assert.deepEqual(await loadIndex("rookery-search-index"), ROWS);
  assert.equal(calls.length, 0);
});

test("loadIndex: unparseable inline JSON is null, not a throw", async () => {
  page(`<script type="application/json" id="rookery-search-index">{not json</script>`);
  assert.equal(await loadIndex("rookery-search-index"), null);
});

test("loadIndex: a pointer fetches its src and rebases every href onto the page's base", async () => {
  page(
    `<script type="application/json" id="rookery-search-index"
       data-rookery-search-src="../rookery/search/index.json"
       data-rookery-search-base="../"></script>`,
  );
  const calls = stubFetch(() => ok(ROWS));
  const rows = await loadIndex("rookery-search-index");
  assert.deepEqual(calls, ["../rookery/search/index.json"]);
  assert.deepEqual(
    rows.map((r) => r.href),
    ["../ideas/etal.html", "../ideas/flat.html"],
  );
  // Every other field survives the rebasing untouched.
  assert.equal(rows[0].id, "idea:etal");
  assert.equal(rows[0].text, "Et al");
});

test("loadIndex: an empty base leaves hrefs exactly as fetched (a root page)", async () => {
  page(
    `<script type="application/json" id="rookery-search-index"
       data-rookery-search-src="rookery/search/index.json"
       data-rookery-search-base=""></script>`,
  );
  stubFetch(() => ok(ROWS));
  assert.deepEqual(await loadIndex("rookery-search-index"), ROWS);
});

test("loadIndex: a missing base is read as the root, not as undefined", async () => {
  page(
    `<script type="application/json" id="rookery-search-index"
       data-rookery-search-src="rookery/search/index.json"></script>`,
  );
  stubFetch(() => ok(ROWS));
  const rows = await loadIndex("rookery-search-index");
  assert.deepEqual(
    rows.map((r) => r.href),
    ["ideas/etal.html", "ideas/flat.html"],
  );
});

test("loadIndex: a failed fetch is null — the bar goes inert, the page does not throw", async () => {
  page(
    `<script type="application/json" id="rookery-search-index"
       data-rookery-search-src="rookery/search/index.json"></script>`,
  );
  stubFetch(() => ({ ok: false, json: async () => ({}) }));
  assert.equal(await loadIndex("rookery-search-index"), null);
});

test("loadIndex: a rejected fetch (offline, file://) is null", async () => {
  page(
    `<script type="application/json" id="rookery-search-index"
       data-rookery-search-src="rookery/search/index.json"></script>`,
  );
  globalThis.fetch = async () => {
    throw new TypeError("Failed to fetch");
  };
  assert.equal(await loadIndex("rookery-search-index"), null);
});

test("loadIndex: a payload that is not an array is null", async () => {
  page(
    `<script type="application/json" id="rookery-search-index"
       data-rookery-search-src="rookery/search/index.json"></script>`,
  );
  stubFetch(() => ok({ rows: ROWS }));
  assert.equal(await loadIndex("rookery-search-index"), null);
});

test("readIndex stays synchronous and inline-only, being a published surface", () => {
  page(
    `<script type="application/json" id="rookery-search-index">${JSON.stringify(ROWS)}</script>`,
  );
  assert.deepEqual(readIndex("rookery-search-index"), ROWS);
});
