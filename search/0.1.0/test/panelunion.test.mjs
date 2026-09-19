// `wirePanel`'s UNION GROUPS (`data-panel-union`), over a real DOM (linkedom).
//
// WHAT IT PINS, and why the bug it is written against was invisible. `#panel` ANDs
// across groups, which is right when each group asks a different question. @rookery/todos
// splits ONE question — what is this todo about — into `epic` and `tag`, and a todo
// carrying `epic-rheo` is deliberately given no `rheo` pill in the tag group. So pressing
// `rheo` and `birds` asked for a row that is BOTH, which no row is: two pills that each
// worked alone showed "nothing matches" together, on correct markup, with the build
// passing. Only a predicate test catches that.
//
// The last two tests are the boundary: an ordinary group still ANDs against a union
// group, and a union group with nothing pressed constrains nothing at all.
import { test } from "node:test";
import assert from "node:assert/strict";
import { parseHTML } from "linkedom";
import { wirePanel } from "../src/panel.js";

// The waterline shape, minimised: `epic` is scalar, `tag` is multi-valued, `state` is the
// group on the other line. No row has both `epic="rheo"` and `birds` among its tags —
// that is the point, and it is not a gap in the fixture.
const PANEL = `<!doctype html><body>
<div class="panel" data-panel-ready="false" data-panel-multi="tag" data-panel-union="epic tag">
<input class="panel-input" type="search">
<div class="panel-pills">
  <div class="panel-pill-row">
    <span class="panel-pill-group" data-panel-group="epic">
      <button class="panel-pill" data-panel-facet="epic" data-panel-value="rheo" aria-pressed="false">rheo</button>
      <button class="panel-pill" data-panel-facet="epic" data-panel-value="admin" aria-pressed="false">admin</button>
    </span>
    <span class="panel-pill-group" data-panel-group="tag">
      <button class="panel-pill" data-panel-facet="tag" data-panel-value="birds" aria-pressed="false">birds</button>
      <button class="panel-pill" data-panel-facet="tag" data-panel-value="homelab" aria-pressed="false">homelab</button>
    </span>
  </div>
  <div class="panel-pill-row">
    <span class="panel-pill-group" data-panel-group="state">
      <button class="panel-pill" data-panel-facet="state" data-panel-value="ready" aria-pressed="false">ready</button>
      <button class="panel-pill" data-panel-facet="state" data-panel-value="blocked" aria-pressed="false">blocked</button>
    </span>
  </div>
</div>
<p class="panel-count">4 rows</p>
<ul class="panel-results">
<li class="panel-row" data-panel-text="alpha" data-epic="rheo" data-tag="" data-state="ready">a</li>
<li class="panel-row" data-panel-text="beta" data-epic="code" data-tag=" birds " data-state="blocked">b</li>
<li class="panel-row" data-panel-text="gamma" data-epic="code" data-tag=" birds homelab " data-state="ready">c</li>
<li class="panel-row" data-panel-text="delta" data-epic="admin" data-tag="" data-state="ready">d</li>
</ul></div></body>`;

const wire = (html = PANEL) => {
  const { document } = parseHTML(html);
  globalThis.document = document;
  wirePanel(document.querySelector(".panel"), 0);
  return {
    press: (facet, value) =>
      document
        .querySelector(`.panel-pill[data-panel-facet="${facet}"][data-panel-value="${value}"]`)
        .dispatchEvent(new document.defaultView.Event("click")),
    shown: () =>
      [...document.querySelectorAll(".panel-row")]
        .filter((r) => !r.hidden)
        .map((r) => r.textContent)
        .sort(),
    count: () => document.querySelector(".panel-count").textContent,
  };
};

test("no pill pressed shows every row", () => {
  const p = wire();
  assert.deepEqual(p.shown(), ["a", "b", "c", "d"]);
  assert.equal(p.count(), "4 rows");
});

test("one union group pressed behaves exactly as it did — this changes nothing alone", () => {
  const p = wire();
  p.press("epic", "rheo");
  assert.deepEqual(p.shown(), ["a"]);
  p.press("epic", "rheo");
  p.press("tag", "birds");
  assert.deepEqual(p.shown(), ["b", "c"]);
});

test("two union groups OR — the bug, stated", () => {
  const p = wire();
  p.press("epic", "rheo");
  p.press("tag", "birds");
  // ANDed this is empty: no row is under `rheo` AND tagged `birds`. That is what the
  // panel used to show, on two pills that each worked alone.
  assert.deepEqual(p.shown(), ["a", "b", "c"]);
  assert.equal(p.count(), "3 of 4");
});

test("values still OR within each union group", () => {
  const p = wire();
  p.press("epic", "rheo");
  p.press("epic", "admin");
  p.press("tag", "homelab");
  assert.deepEqual(p.shown(), ["a", "c", "d"]);
});

test("an ordinary group still ANDs against the union ones", () => {
  const p = wire();
  p.press("epic", "rheo");
  p.press("tag", "birds");
  p.press("state", "ready");
  // `b` is under neither pressed subject alone — it is blocked, so the state group drops
  // it — and `a`/`c` are each a subject hit that is also ready.
  assert.deepEqual(p.shown(), ["a", "c"]);
});

test("a union group with nothing pressed constrains nothing", () => {
  const p = wire();
  p.press("state", "blocked");
  // Both union groups are empty, so the union clause must not be asked at all — the
  // failure mode being a declaration that hides every row until a subject is pressed.
  assert.deepEqual(p.shown(), ["b"]);
});

test("without data-panel-union the groups AND, exactly as before", () => {
  const p = wire(PANEL.replace(' data-panel-union="epic tag"', ""));
  p.press("epic", "rheo");
  p.press("tag", "birds");
  assert.deepEqual(p.shown(), []);
  assert.equal(p.count(), "nothing matches");
});
