// `passesTags(row, pressed, mode)` — the predicate behind `#filter-panel`'s pills.
//
// TWO COMPOSITIONS, and the default is "any". A row survives if it carries ANY pressed
// tag, so a second pill WIDENS; `"all"` keeps only a row carrying every pressed tag, so
// it narrows. The default is "any" because the tags a pill row is built from are usually
// mutually exclusive in practice — one epic per todo — and intersecting two of those
// returns nothing at all.
//
// Everything else about the two panel kinds — the input, the count, the reordering — is
// one shared `wirePanel`, which is why this is the only new predicate to pin.
import { test } from "node:test";
import assert from "node:assert/strict";
import { parseHTML } from "linkedom";
import { passesTags } from "./internal.mjs";
import { wirePanel } from "../src/panel.js";

// A row as `wirePanel` builds it: the tag names off `data-panel-tags`, as a Set.
const row = (...tags) => ({ tags: new Set(tags) });

test("no pills pressed passes every row, in both modes", () => {
  const pressed = new Set();
  for (const mode of ["any", "all"]) {
    assert.equal(passesTags(row(), pressed, mode), true);
    assert.equal(passesTags(row("ready"), pressed, mode), true);
  }
});

test("one pill keeps only its carriers, in both modes", () => {
  const pressed = new Set(["ready"]);
  for (const mode of ["any", "all"]) {
    assert.equal(passesTags(row("ready"), pressed, mode), true);
    assert.equal(passesTags(row("ready", "epic-jobs"), pressed, mode), true);
    assert.equal(passesTags(row("blocked"), pressed, mode), false);
    assert.equal(passesTags(row(), pressed, mode), false);
  }
});

// THE DEFAULT. Two pills UNION: pressing a second one widens the result, which is what
// makes a row of mutually exclusive tags (one epic per todo) usable at all.
test("two pills UNION by default — carrying either is enough", () => {
  const pressed = new Set(["ready", "epic-jobs"]);
  assert.equal(passesTags(row("ready", "epic-jobs"), pressed, "any"), true);
  assert.equal(passesTags(row("ready"), pressed, "any"), true);
  assert.equal(passesTags(row("epic-jobs"), pressed, "any"), true);
  assert.equal(passesTags(row("blocked"), pressed, "any"), false);
});

// AN UNRECOGNISED MODE FALLS BACK TO THE DEFAULT rather than throwing: the value comes
// off a DOM attribute, and a page carrying a typo should still filter.
test("anything that is not \"all\" composes as \"any\"", () => {
  const pressed = new Set(["ready", "epic-jobs"]);
  for (const mode of ["any", undefined, "", "ALL", "every"]) {
    assert.equal(passesTags(row("ready"), pressed, mode), true);
  }
});

test("`all` INTERSECTS — carrying one of the two is not enough", () => {
  const pressed = new Set(["ready", "epic-jobs"]);
  assert.equal(passesTags(row("ready", "epic-jobs"), pressed, "all"), true);
  assert.equal(passesTags(row("ready"), pressed, "all"), false);
  assert.equal(passesTags(row("epic-jobs"), pressed, "all"), false);
});

// THE PREFIX CASE, and the reason the Typst side space-pads `data-panel-tags` at both
// ends: an implementation testing the raw attribute with `includes("epic")` would
// match ` epic-jobs `. Splitting on spaces into a Set makes a half-match impossible,
// and this test is what keeps it that way if the parsing is ever "optimised" back to a
// substring test.
test("a tag that is another's prefix does not half-match", () => {
  for (const mode of ["any", "all"]) {
    assert.equal(passesTags(row("epic-jobs"), new Set(["epic"]), mode), false);
    assert.equal(passesTags(row("epic"), new Set(["epic-jobs"]), mode), false);
    assert.equal(passesTags(row("epic", "epic-jobs"), new Set(["epic"]), mode), true);
  }
});

// `body-index:` — THE PANEL LOOKS A ROW'S BODY TERMS UP IN THE PAGE'S SEARCH
// INDEX AT RUNTIME, rather than scoring `data-panel-text`, which under this mode
// the Typst side no longer fills with the row's body at all (pinned by the
// Typst-side parity suite, not here). What is unpinned on the JS side is the
// JOIN: reading `data-panel-body-index`, fetching/parsing the index once, and
// keying each row's body tier off its own `data-panel-id` rather than its
// `data-panel-text`.
//
// TWO ROWS: `a`'s id is in the index with a body containing "justification";
// `b`'s is not in the index at all. Neither row's NAME contains the probe word,
// so a match can only come through the body tier.
const BODY_INDEX_PANEL = (indexScript) => `<!doctype html><body>
<div class="panel" data-panel-ready="false" data-panel-mode="tags" data-panel-body-index="rookery-search-index">
<input class="panel-input" type="search">
<p class="panel-count">2 rows</p>
<ul class="panel-results">
<li class="panel-row" data-panel-text="alpha" data-panel-name="alpha" data-panel-id="idea:a">a</li>
<li class="panel-row" data-panel-text="beta" data-panel-name="beta" data-panel-id="idea:b">b</li>
</ul></div>
${indexScript}
</body>`;

// One microtask tick resolves `readIndex`'s own promise; a second runs the
// `.then()` chained onto it inside `wirePanel`. A macrotask flush (`setTimeout`)
// clears both without the test needing to know that count.
const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

const wireBodyIndex = async (indexScript) => {
  const { document } = parseHTML(BODY_INDEX_PANEL(indexScript));
  globalThis.document = document;
  wirePanel(document.querySelector(".panel"), 0);
  await flush();
  const input = document.querySelector(".panel-input");
  return {
    type: (v) => {
      input.value = v;
      input.dispatchEvent(new document.defaultView.Event("input"));
    },
    shown: () =>
      [...document.querySelectorAll(".panel-row")]
        .filter((r) => !r.hidden)
        .map((r) => r.textContent)
        .sort(),
  };
};

test("body-index: a row whose id maps to body terms containing a word matches through the body tier", async () => {
  const p = await wireBodyIndex(
    `<script type="application/json" id="rookery-search-index">`
      + `[{"id":"idea:a","body":"justification clause"}]</script>`,
  );
  p.type("justif");
  assert.deepEqual(p.shown(), ["a"]);
});

test("body-index: the same row with an empty map does not match the body tier", async () => {
  // No `#search-index` element at all — `loadIndex` resolves `null` and the map
  // stays empty, so the body tier of every row matches nothing.
  const p = await wireBodyIndex("");
  p.type("justif");
  assert.deepEqual(p.shown(), []);
});

test("body-index: a name match still matches with an empty map", async () => {
  const p = await wireBodyIndex("");
  p.type("alpha");
  assert.deepEqual(p.shown(), ["a"]);
});
