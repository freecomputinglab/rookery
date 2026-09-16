// `wirePanel`'s TEXT INPUT, over a real DOM (linkedom), because the bug this pins was
// invisible to every other kind of test here.
//
// WHAT IT WAS. `apply()` read `const s = ok ? score(row.text, q) : -1` and hid a row on
// `s < 0`. But `score` returns `null` for no match — its own header says so — and
// `null < 0` is FALSE in JavaScript. So a non-matching row was kept: the input reordered
// the list and filtered nothing, in BOTH panel kinds, from the day `#panel` shipped.
//
// WHY NOTHING CAUGHT IT. The unit suite pins `score` (which was right), the parity
// harness compares the JS scorer against the Typst one (also right), and the demo's
// `check.sh` greps the BUILT MARKUP, where the input has not been typed into. The
// defect lived in the one line joining a correct scorer to a correct list, and only a
// DOM test that types can see it.
//
// A SECOND DEFECT the same DOM shape pins: `resolve` scored the whole
// `data-panel-text` haystack (label + name + body) by SUBSEQUENCE, which is the
// right rule for a short title but matches almost any query against a body long
// enough — a subsequence of thousands of characters is not a rare event. The
// last test below fixes a fixture row long enough to show the difference: a
// query that is a subsequence of the body's characters but not a substring of
// any of its words must NOT match.
import { test } from "node:test";
import assert from "node:assert/strict";
import { parseHTML } from "linkedom";
import { wirePanel } from "../src/panel.js";

const PANEL = `<!doctype html><body><div class="panel" data-panel-ready="false">
<input class="panel-input" type="search"><p class="panel-count">3 rows</p><ul class="panel-results">
<li class="panel-row" data-panel-text="alpha abstract">a</li>
<li class="panel-row" data-panel-text="beta reference">b</li>
<li class="panel-row" data-panel-text="gamma chore">c</li>
</ul></div></body>`;

const wire = () => {
  const { document } = parseHTML(PANEL);
  globalThis.document = document;
  wirePanel(document.querySelector(".panel"), 0);
  const input = document.querySelector(".panel-input");
  return {
    document,
    type: (v) => {
      input.value = v;
      input.dispatchEvent(new document.defaultView.Event("input"));
    },
    shown: () =>
      [...document.querySelectorAll(".panel-row")]
        .filter((r) => !r.hidden)
        .map((r) => r.textContent),
    count: () => document.querySelector(".panel-count").textContent,
  };
};

test("an empty query shows every row, in the build-time order", () => {
  const p = wire();
  assert.deepEqual(p.shown(), ["a", "b", "c"]);
  assert.equal(p.count(), "3 rows");
});

test("a query HIDES the rows it does not match", () => {
  const p = wire();
  p.type("abstract");
  assert.deepEqual(p.shown(), ["a"]);
  assert.equal(p.count(), "1 of 3");
});

test("a query matching nothing hides everything and says so", () => {
  const p = wire();
  p.type("zzz");
  assert.deepEqual(p.shown(), []);
  assert.equal(p.count(), "nothing matches");
});

test("clearing the query restores every row", () => {
  const p = wire();
  p.type("abstract");
  p.type("");
  assert.deepEqual(p.shown(), ["a", "b", "c"]);
  assert.equal(p.count(), "3 rows");
});

test("a long body is matched by substring, not subsequence", () => {
  const { document } = parseHTML(`<!doctype html><body><div class="panel" data-panel-ready="false">
<input class="panel-input" type="search"><p class="panel-count">2 rows</p><ul class="panel-results">
<li class="panel-row" data-panel-name="alpha" data-panel-text="a long paragraph of ordinary prose about typesetting and rivers">a</li>
<li class="panel-row" data-panel-name="beta" data-panel-text="another note entirely, on birds and their flights">b</li>
</ul></div></body>`);
  globalThis.document = document;
  wirePanel(document.querySelector(".panel"), 0);
  const input = document.querySelector(".panel-input");
  const shown = () => [...document.querySelectorAll(".panel-row")]
    .filter((r) => !r.hidden).map((r) => r.textContent);
  // `lprs` is a subsequence of row a's body and a substring of no word in it.
  input.value = "lprs";
  input.dispatchEvent(new document.defaultView.Event("input"));
  assert.deepEqual(shown(), []);
  input.value = "rivers";
  input.dispatchEvent(new document.defaultView.Event("input"));
  assert.deepEqual(shown(), ["a"]);
});
