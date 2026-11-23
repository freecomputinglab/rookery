// Unit tests for the persistence store. `localStorage` does not exist under
// node, so each test stubs a minimal one on `globalThis` — a `Map` behind
// `getItem`/`setItem` for the happy paths, and a stub whose methods throw
// for the access-failure path `src/store.js` must survive.

import { strict as assert } from "node:assert";
import { test, beforeEach } from "node:test";

import { loadBoard, saveCard, storageKey } from "../src/store.js";

function useMapStorage() {
  const map = new Map();
  globalThis.localStorage = {
    getItem(key) {
      return map.has(key) ? map.get(key) : null;
    },
    setItem(key, value) {
      map.set(key, String(value));
    },
  };
}

function useThrowingStorage() {
  globalThis.localStorage = {
    getItem() {
      throw new Error("storage blocked");
    },
    setItem() {
      throw new Error("storage blocked");
    },
  };
}

beforeEach(() => {
  useMapStorage();
});

test("storageKey namespaces the board id", () => {
  assert.equal(storageKey("notes"), "rookery-pinboard:notes");
});

test("saveCard then loadBoard round-trips the entry", () => {
  saveCard("notes", "idea-a", { x: 10, y: 20, collapsed: false });
  assert.deepEqual(loadBoard("notes"), { "idea-a": { x: 10, y: 20, collapsed: false } });
});

test("saving one idea id leaves another id's entry untouched", () => {
  saveCard("notes", "idea-a", { x: 10, y: 20, collapsed: false });
  saveCard("notes", "idea-b", { x: 5, y: 6, collapsed: true });
  assert.deepEqual(loadBoard("notes"), {
    "idea-a": { x: 10, y: 20, collapsed: false },
    "idea-b": { x: 5, y: 6, collapsed: true },
  });
});

test("loadBoard on unparseable JSON returns an empty object rather than throwing", () => {
  globalThis.localStorage.setItem(storageKey("notes"), "{{{");
  assert.deepEqual(loadBoard("notes"), {});
});

test("loadBoard drops an entry whose x/y are not finite numbers", () => {
  globalThis.localStorage.setItem(storageKey("notes"), '{"a":{"x":"nope","y":3}}');
  assert.deepEqual(loadBoard("notes"), {});
});

test("loadBoard returns an empty object when storage throws on access", () => {
  useThrowingStorage();
  assert.deepEqual(loadBoard("notes"), {});
});
