// Real-engine assertions for the slipshow deck, against the built demo at
// ../../demo/rheo/build/html/ (see that project's check.sh for what the
// build itself asserts). None of `src/slipshow.js`'s DOM-driving functions —
// `init`, `syncReveal`, `applyScale`, `apply`, `goTo`, `onKeydown` — are
// exported or reachable from `test/reveal.test.mjs`'s pure-function suite,
// so this is the only place any of them runs at all. `src/edges.js`'s
// `redraw` is in the same position: `test/edges.test.mjs` covers only its
// pure geometry (`edgePath`, `railX`).
import assert from "node:assert/strict";
import { readFile, readdir } from "node:fs/promises";
import { serve, requireBuild, run } from "../../../../test/browser/harness.mjs";

const ROOT = new URL("../../demo/rheo/build/html/", import.meta.url).pathname;
requireBuild(`${ROOT}deck.html`, "cd slipshow/0.1.0 && just check");

const deckHtml = await readFile(`${ROOT}deck.html`, "utf8");

// The one slip in this deck with `data-enter="focus"`, read off the built
// page rather than hardcoded as `slip-3` — a future reshuffle of `deck.typ`'s
// slides must not silently point this suite at the wrong id. `focus` is the
// only action that can leave `deck.style.transform` non-empty (`camera.js`'s
// `targetFor` sets `scale !== 1` only there), so landing on this slip via its
// `#slip-<id>` fragment is what makes assertion 1 below meaningful: a plain
// load of `deck.html` never calls `apply()` at all (no fragment, `started`
// stays false), so its `transform` would stay unset regardless of whether
// `init()` ran.
const focusMatch = deckHtml.match(/<section[^>]*\bid="([^"]+)"[^>]*\bdata-enter="focus"/);
assert.ok(focusMatch, "deck.html carries no slip with data-enter=\"focus\" to land on");
const focusId = focusMatch[1];

// The built page (if any) carrying `data-slip-edges`, read from every file in
// the demo build rather than assumed to be `deck.html` — which page (if any)
// wires edges is not asserted anywhere else in this repo.
const builtFiles = (await readdir(ROOT)).filter((f) => f.endsWith(".html"));
let edgesFile = null;
for (const f of builtFiles) {
  const html = await readFile(`${ROOT}${f}`, "utf8");
  if (html.includes("data-slip-edges")) {
    edgesFile = f;
    break;
  }
}

const { origin, close } = await serve(ROOT);
try {
  await run("slipshow-deck", async ({ browser, newPage }) => {
    // A viewport shorter than the focus slip's own rendered height (~107px
    // at this width), so `targetFor("focus", ...)` computes a `scale < 1`
    // rather than capping at 1 — its cap is "never zoom past natural size",
    // not "always zoom to fill" (see `src/camera.js`'s comment on that
    // branch), so a viewport taller than the slip would leave `scale` at 1
    // and `deck.style.transform` empty regardless of whether `init()` ran.
    // Assertions 1-4 share this page; assertion 5 (edges) opens its own,
    // since it may be a different built file entirely.
    const context = await browser.newContext({ viewport: { width: 800, height: 80 } });
    const errors = [];
    const page = await context.newPage();
    page.on("pageerror", (err) => errors.push(err));
    page.on("console", (msg) => {
      if (msg.type() === "error") errors.push(msg);
    });

    await page.goto(`${origin}/deck.html#${focusId}`);
    const deck = page.locator("div.slipshow");

    // 1. The deck initialises.
    assert.equal(await page.locator("div.slipshow").count(), 1, "expected exactly one div.slipshow");
    const transform = await deck.evaluate((d) => d.style.transform);
    assert.ok(transform.length > 0, `deck.style.transform is empty after landing on #${focusId} — init() never ran`);
    assert.equal(errors.length, 0, `page recorded errors on load: ${errors}`);

    // 2. Reveal state is applied — the `#slip-<id>` fragment starts the deck
    // (`entersDeck`, `src/slipshow.js:74`) before this is read.
    assert.equal(
      await deck.evaluate((d) => d.classList.contains("slipshow-revealing")),
      true,
      "div.slipshow did not gain slipshow-revealing",
    );
    const revealedCount = async () => page.locator("section.slip.slip-revealed").count();
    const before = await revealedCount();
    assert.ok(before > 0, "no section.slip carries slip-revealed after landing on a fragment");

    // 3. A forward keypress advances the reveal by exactly one slip.
    await page.keyboard.press("ArrowRight");
    await page.waitForFunction(
      (n) => document.querySelectorAll("section.slip.slip-revealed").length !== n,
      before,
    );
    const after = await revealedCount();
    assert.equal(after, before + 1, `expected the revealed count to grow by 1 (was ${before}), got ${after}`);

    // 4. The camera scrolls: this deck has no `.slip-row`, so `apply()`
    // (`src/slipshow.js:161`) moves the page itself, not a row.
    const scrollBefore = await page.evaluate(() => window.scrollY);
    for (let i = 0; i < 3; i++) await page.keyboard.press("ArrowRight");
    await page.waitForFunction((y) => window.scrollY !== y, scrollBefore);
    const scrollAfter = await page.evaluate(() => window.scrollY);
    assert.notEqual(scrollAfter, scrollBefore, "window.scrollY did not change after advancing the deck");

    await context.close();

    // 5. The edge layer, drawn from real geometry — only reachable on a
    // built page that actually wires `data-slip-edges`, which the demo does
    // not (see the comment on `edgesFile` above).
    if (edgesFile === null) {
      assert.fail(
        "no page under demo/rheo/build/html/ carries data-slip-edges — " +
          "examples/dag/ wires the edges feature and demo/rheo/ does not, " +
          "so src/edges.js's redraw() and deckBox() have no built fixture " +
          "this suite can assert against. Not fixed here: adding edges to " +
          "the demo is a content decision for the operator, not this test.",
      );
    }
    const edgePage = await newPage();
    await edgePage.goto(`${origin}/${edgesFile}`);
    // Advance the deck fully so every slip is revealed (`offsetParent` is
    // non-null) — `collect()` (`src/edges.js:119`) drops an edge whose
    // either endpoint is still hidden by the progressive reveal.
    await edgePage.keyboard.press("End");
    const layer = edgePage.locator("div.slipshow > :first-child.slip-edges");
    await layer.waitFor();
    const paths = layer.locator("path.slip-edge");
    assert.ok((await paths.count()) > 0, `${edgesFile}: .slip-edges carries no path.slip-edge`);
    const d = await paths.first().getAttribute("d");
    assert.ok(d && d.length > 0 && d.startsWith("M"), `${edgesFile}: first path's d is not a valid path string: ${d}`);
  });
} finally {
  await close();
}
