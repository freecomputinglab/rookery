// `wirePanel`'s URL SYNC (`sync:`/`data-panel-sync`), over a real DOM (linkedom)
// with `history` and `location` stubbed by hand — linkedom supplies neither, and
// `commit`'s whole job is writing through them.
//
// THE STUB'S `replaceState` UPDATES ITS OWN `location.search`, the way a real
// browser's does, so a widget's second write in one test sees its first rather
// than a query string frozen at wire time.
//
// EVERY TEST CLAIMS ITS OWN KEY. `claimKey` (`urlstate.js`) is a process-wide
// singleton with no reset, and `node --test` runs every test in this file in one
// process, so reusing a key across tests would make every test after the first
// look like a second widget claiming an already-synced namespace.
import { test } from "node:test";
import assert from "node:assert/strict";
import { parseHTML } from "linkedom";
import { wirePanel } from "../src/panel.js";

let keySeq = 0;
const nextKey = (base) => `${base}${keySeq++}`;

// Three rows over one facet group, `state`, so both the text box and a pill can
// be exercised on the same fixture. `key` of `null` omits `data-panel-sync`
// entirely, for the panel that never opts in.
const facetPanel = (key) => `<!doctype html><body>
<div class="panel" data-panel-ready="false"${key ? ` data-panel-sync="${key}"` : ""}>
<input class="panel-input" type="search">
<div class="panel-pills">
  <span class="panel-pill-group" data-panel-group="state">
    <button class="panel-pill" data-panel-facet="state" data-panel-value="ready" aria-pressed="false">ready</button>
    <button class="panel-pill" data-panel-facet="state" data-panel-value="blocked" aria-pressed="false">blocked</button>
  </span>
</div>
<p class="panel-count">3 rows</p>
<ul class="panel-results">
<li class="panel-row" data-panel-text="alpha abstract" data-state="ready">a</li>
<li class="panel-row" data-panel-text="beta reference" data-state="blocked">b</li>
<li class="panel-row" data-panel-text="gamma chore" data-state="ready">c</li>
</ul></div></body>`;

// `#filter-panel`'s shape: `data-panel-mode="tags"`, pills carrying
// `data-panel-tag` with no group wrapper, rows carrying `data-panel-tags`.
const tagPanel = (key) => `<!doctype html><body>
<div class="panel" data-panel-ready="false" data-panel-mode="tags" data-panel-sync="${key}">
<input class="panel-input" type="search">
<div class="panel-pills">
  <button class="panel-pill" data-panel-tag="urgent" aria-pressed="false">urgent</button>
  <button class="panel-pill" data-panel-tag="idea" aria-pressed="false">idea</button>
</div>
<p class="panel-count">2 rows</p>
<ul class="panel-results">
<li class="panel-row" data-panel-text="alpha" data-panel-tags=" urgent ">a</li>
<li class="panel-row" data-panel-text="beta" data-panel-tags=" idea ">b</li>
</ul></div></body>`;

let captured;

const wire = (html, search = "") => {
  captured = null;
  globalThis.location = { pathname: "/index.html", search, hash: "" };
  globalThis.history = {
    replaceState: (_state, _title, url) => {
      captured = url;
      const q = url.indexOf("?");
      const h = url.indexOf("#");
      const end = h === -1 ? url.length : h;
      globalThis.location.search = q === -1 ? "" : url.slice(q, end);
    },
  };
  const { document } = parseHTML(html);
  globalThis.document = document;
  wirePanel(document.querySelector(".panel"), 0);
  const input = document.querySelector(".panel-input");
  return {
    document,
    input,
    type: (v) => {
      input.value = v;
      input.dispatchEvent(new document.defaultView.Event("input"));
    },
    escape: () => {
      const ev = new document.defaultView.Event("keydown");
      ev.key = "Escape";
      input.dispatchEvent(ev);
    },
    press: (facet, value) =>
      document
        .querySelector(`.panel-pill[data-panel-facet="${facet}"][data-panel-value="${value}"]`)
        .dispatchEvent(new document.defaultView.Event("click")),
    pressTag: (tag) =>
      document
        .querySelector(`.panel-pill[data-panel-tag="${tag}"]`)
        .dispatchEvent(new document.defaultView.Event("click")),
    shown: () =>
      [...document.querySelectorAll(".panel-row")]
        .filter((r) => !r.hidden)
        .map((r) => r.textContent)
        .sort(),
    count: () => document.querySelector(".panel-count").textContent,
  };
};

test("rehydrates the filter box from `<key>.q` and filters on first paint", () => {
  const key = nextKey("todos");
  const p = wire(facetPanel(key), `${key}.q=abstract`);
  assert.equal(p.input.value, "abstract");
  assert.deepEqual(p.shown(), ["a"]);
  assert.equal(p.count(), "1 of 3");
});

test("rehydrates a pressed pill from `<key>.<field>`, filtering with no click dispatched", () => {
  const key = nextKey("todos");
  const p = wire(facetPanel(key), `${key}.state=ready`);
  const pill = p.document.querySelector('.panel-pill[data-panel-facet="state"][data-panel-value="ready"]');
  assert.equal(pill.getAttribute("aria-pressed"), "true");
  assert.deepEqual(p.shown(), ["a", "c"]);
  assert.equal(p.count(), "2 of 3");
});

test("a URL value naming no pill on the page is ignored, not applied", () => {
  const key = nextKey("todos");
  const p = wire(facetPanel(key), `${key}.state=nonexistent`);
  assert.deepEqual(p.shown(), ["a", "b", "c"]);
  for (const pill of p.document.querySelectorAll(".panel-pill")) {
    assert.equal(pill.getAttribute("aria-pressed"), "false");
  }
});

test("pressing a pill persists it to `<key>.<field>`, and pressing again removes it", () => {
  const key = nextKey("todos");
  const p = wire(facetPanel(key));
  p.press("state", "ready");
  assert.match(captured, new RegExp(`${key}\\.state=ready`));
  p.press("state", "ready");
  assert.doesNotMatch(captured, new RegExp(`${key}\\.state`));
});

test("typing persists `<key>.q` after the debounce; Escape clears it immediately", async () => {
  const key = nextKey("todos");
  const p = wire(facetPanel(key));
  p.type("reference");
  // Nothing yet — the write is debounced, not synchronous with the keystroke.
  assert.equal(captured, null);
  await new Promise((resolve) => setTimeout(resolve, 250));
  assert.match(captured, new RegExp(`${key}\\.q=reference`));
  p.escape();
  assert.doesNotMatch(captured, new RegExp(`${key}\\.q`));
});

test("persisting merges into the existing query string rather than replacing it", () => {
  const key = nextKey("todos");
  const p = wire(facetPanel(key), "tab=todos&other.q=x");
  p.press("state", "ready");
  assert.match(captured, /tab=todos/);
  assert.match(captured, /other\.q=x/);
  assert.match(captured, new RegExp(`${key}\\.state=ready`));
});

test("a panel with no `sync:` never touches the address bar", () => {
  const p = wire(facetPanel(null));
  p.type("abstract");
  assert.equal(captured, null);
  p.press("state", "ready");
  assert.equal(captured, null);
});

test("tag mode persists a pressed pill to `<key>.t` and rehydrates it back", () => {
  const writeKey = nextKey("ideas");
  const w = wire(tagPanel(writeKey));
  w.pressTag("urgent");
  assert.match(captured, new RegExp(`${writeKey}\\.t=urgent`));

  // A fresh widget under its own key, standing in for the next page load: the
  // written state is read back the same way `readSync` was just proven to write it.
  const readKey = nextKey("ideas");
  const r = wire(tagPanel(readKey), `${readKey}.t=urgent`);
  assert.equal(r.document.querySelector('.panel-pill[data-panel-tag="urgent"]').getAttribute("aria-pressed"), "true");
  assert.deepEqual(r.shown(), ["a"]);
});
