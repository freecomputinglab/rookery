// `urlsync.js` — a radio group's selection synced to one query-string param —
// exercised over a real DOM (linkedom), because `wireRadioGroup` reads and
// writes `location`/`history` directly and neither exists on linkedom's own
// window. Both are stubbed by hand, the same move `panelinput.test.mjs`
// makes for `document`.
//
// Each test claims its own key: `claimKey` remembers every key claimed for
// the life of the module, which is the whole file's run, so reusing a key
// across tests would make the second wiring a refusal rather than a fresh
// claim.
import { test } from "node:test";
import assert from "node:assert/strict";
import { parseHTML } from "linkedom";
import { wireRadioGroup } from "../src/urlsync.js";

let captured = null;

const reset = (search = "") => {
  captured = null;
  globalThis.location = { pathname: "/index.html", search, hash: "" };
  globalThis.history = {
    replaceState: (_state, _title, url) => {
      captured = url;
    },
  };
};

const TABS = `<!doctype html><body><div class="tabs" data-rookery-url-radio="tab">
<input type="radio" class="tab-radio" name="tabs-index" value="today" checked>
<input type="radio" class="tab-radio" name="tabs-index" value="todos">
<input type="radio" class="tab-radio" name="tabs-index" value="ideas">
</div></body>`;

const wireTabs = (key) => {
  const { document } = parseHTML(TABS);
  globalThis.document = document;
  const container = document.querySelector(".tabs");
  const result = wireRadioGroup(container, key);
  const radios = [...document.querySelectorAll(".tab-radio")];
  return {
    result,
    checked: () => radios.map((r) => r.checked),
    change: (i) => radios[i].dispatchEvent(new document.defaultView.Event("change")),
  };
};

test("a matching param overrides the markup's checked default", () => {
  reset("tab-restore=todos");
  const { checked } = wireTabs("tab-restore");
  assert.deepEqual(checked(), [false, true, false]);
});

test("a param naming no radio leaves the markup's own default standing", () => {
  reset("tab-stale=nope");
  const { document } = parseHTML(TABS);
  globalThis.document = document;
  const container = document.querySelector(".tabs");
  const radios = [...document.querySelectorAll(".tab-radio")];
  const before = radios.map((r) => r.checked);
  wireRadioGroup(container, "tab-stale");
  // linkedom does not reflect the `checked` CONTENT attribute onto the
  // `.checked` IDL property on its own, so the only environment-agnostic way
  // to prove nothing was touched is to show wiring left every radio exactly
  // as it found it.
  assert.deepEqual(radios.map((r) => r.checked), before);
});

test("wiring alone writes nothing to the URL", () => {
  reset();
  wireTabs("tab-noop");
  assert.equal(captured, null);
});

test("a change on a radio writes its value under the given key", () => {
  reset();
  const { change } = wireTabs("tab-change");
  change(2);
  assert.match(captured, /tab-change=ideas/);
});

test("a change merges with an existing param instead of replacing the query string", () => {
  reset("todos.q=x");
  const { change } = wireTabs("tab-merge");
  change(1);
  assert.match(captured, /todos\.q=x/);
  assert.match(captured, /tab-merge=todos/);
});

test("a group whose radios carry no `value` attribute syncs nothing", () => {
  reset();
  const { document } = parseHTML(`<!doctype html><body><div class="tabs" data-rookery-url-radio="tab">
<input type="radio" class="tab-radio" name="tabs-index" checked>
<input type="radio" class="tab-radio" name="tabs-index">
</div></body>`);
  globalThis.document = document;
  const container = document.querySelector(".tabs");
  const result = wireRadioGroup(container, "tab-novalue");
  assert.equal(result, null);
  const radios = [...document.querySelectorAll(".tab-radio")];
  radios[1].dispatchEvent(new document.defaultView.Event("change"));
  assert.equal(captured, null);
});

test("a second container claiming an already-claimed key is refused and stays unwired", () => {
  reset();
  const { document } = parseHTML(`<!doctype html><body>
<div class="one" data-rookery-url-radio="tab-dup">
  <input type="radio" class="tab-radio" name="a" value="x" checked>
  <input type="radio" class="tab-radio" name="a" value="y">
</div>
<div class="two" data-rookery-url-radio="tab-dup">
  <input type="radio" class="tab-radio" name="b" value="p" checked>
  <input type="radio" class="tab-radio" name="b" value="q">
</div>
</body>`);
  globalThis.document = document;
  const first = document.querySelector(".one");
  const second = document.querySelector(".two");
  assert.notEqual(wireRadioGroup(first, "tab-dup"), null);
  assert.equal(wireRadioGroup(second, "tab-dup"), null);
  const secondRadios = [...second.querySelectorAll(".tab-radio")];
  secondRadios[1].dispatchEvent(new document.defaultView.Event("change"));
  assert.equal(captured, null);
});
