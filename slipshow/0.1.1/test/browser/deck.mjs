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
requireBuild(`${ROOT}deck.html`, "cd slipshow/0.1.1 && just check");

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

// The built page carrying `data-slip-edges`, found by reading every file in
// each build rather than assumed to be a particular one — which page wires
// edges is not asserted anywhere else in this repo.
//
// TWO ROOTS, because the demo does not wire edges and `examples/dag/` does:
// the feature's only built fixture lives in that example's own build, which
// `just examples` produces and CI runs before the browser suites. Served from
// its own root below, since a page can only be loaded from the server rooted
// at the directory holding it.
// EVERY such page, not the first: a deck can wire edges and still draw none —
// `across.html` points at slips on other pages, which `collect()` drops — so
// the page that proves `redraw()` is the first candidate that yields a path,
// decided in the browser below rather than guessed from the markup here.
const EDGE_ROOTS = [ROOT, new URL("../../examples/dag/build/html/", import.meta.url).pathname];
const edgeCandidates = [];
for (const root of EDGE_ROOTS) {
  let entries;
  try {
    entries = await readdir(root);
  } catch {
    continue;
  }
  for (const f of entries.filter((f) => f.endsWith(".html"))) {
    const html = await readFile(`${root}${f}`, "utf8");
    if (html.includes("data-slip-edges")) edgeCandidates.push({ root, file: f });
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

    // 3. REHYDRATE PRESERVES POSITION AND ZOOM rather than resetting to
    // slide 0 — the regression the TEARDOWN/WIRE/RESTORE split in
    // `src/slipshow.js` exists to avoid. Run HERE, on the freshly-landed
    // focus slip, while the deck is still actually zoomed (`transform` from
    // step 1) — a later slip reached with a plain "scroll" action
    // legitimately resets scale to 1 on its own, and rehydrating only after
    // navigating there would prove nothing about zoom restoration.
    //
    // rheo's dev server morphs a content edit into the live DOM without
    // re-running this module (`docs/contract.md`), simulated here by
    // swapping the live `div.slipshow` for a fresh parse of the SAME
    // pre-hydration markup this suite already fetched into `deckHtml` —
    // exactly what a morph leaves behind before calling `__rheoRehydrate`.
    // The two checks right after the swap prove the swap itself, not the
    // rehydrate, wiped the runtime state — without them the assertions
    // below could pass on a page carrying no rehydrate hook at all.
    const hashBeforeMorph = await page.evaluate(() => location.hash);
    await deck.evaluate((d, html) => {
      const fresh = new DOMParser().parseFromString(html, "text/html").querySelector("div.slipshow");
      d.replaceWith(fresh);
    }, deckHtml);
    assert.equal(await revealedCount(), 0, "the simulated morph did not clear slip-revealed");
    assert.equal(
      await page.locator("div.slipshow").evaluate((d) => d.classList.contains("slipshow-revealing")),
      false,
      "the simulated morph did not clear slipshow-revealing",
    );

    await page.evaluate(() => {
      for (const fn of globalThis.__rheoRehydrate ?? []) fn();
    });

    assert.equal(
      await page.evaluate(() => location.hash),
      hashBeforeMorph,
      "rehydrate changed the URL fragment instead of restoring the pre-morph slide",
    );
    assert.equal(
      await revealedCount(),
      before,
      `rehydrate should restore ${before} revealed slips, got a different count — the deck reset instead of resuming`,
    );
    const transformAfterRehydrate = await page.locator("div.slipshow").evaluate((d) => d.style.transform);
    assert.ok(transformAfterRehydrate.length > 0, "rehydrate did not restore the zoom transform");

    // 4. A forward keypress after rehydrate still advances the reveal by
    // exactly one slip — proof the PREVIOUS pass's listener was dropped
    // rather than left bound alongside the new one, since a double-bound
    // keydown would advance by two.
    await page.keyboard.press("ArrowRight");
    await page.waitForFunction(
      (n) => document.querySelectorAll("section.slip.slip-revealed").length !== n,
      before,
    );
    const after = await revealedCount();
    assert.equal(after, before + 1, `expected the revealed count to grow by 1 (was ${before}), got ${after}`);

    // 5. The camera scrolls: this deck has no `.slip-row`, so `apply()`
    // (`src/slipshow.js:161`) moves the page itself, not a row.
    const scrollBefore = await page.evaluate(() => window.scrollY);
    for (let i = 0; i < 3; i++) await page.keyboard.press("ArrowRight");
    await page.waitForFunction((y) => window.scrollY !== y, scrollBefore);
    const scrollAfter = await page.evaluate(() => window.scrollY);
    assert.notEqual(scrollAfter, scrollBefore, "window.scrollY did not change after advancing the deck");

    await context.close();

    // 6. The edge layer, drawn from real geometry — reachable only on a built
    // page that actually wires `data-slip-edges` (see the comment on
    // `EDGE_ROOTS` above for which build that is).
    assert.ok(
      edgeCandidates.length > 0,
      "no page under demo/rheo/build/html/ or examples/dag/build/html/ carries " +
        "data-slip-edges, so src/edges.js's redraw() and deckBox() have no " +
        "built fixture this suite can assert against — run " +
        "`cd slipshow/0.1.1 && just examples` to build the example that wires it",
    );
    let drawn = null;
    for (const candidate of edgeCandidates) {
      const own = candidate.root === ROOT ? null : await serve(candidate.root);
      const edgePage = await newPage();
      try {
        await edgePage.goto(`${own ? own.origin : origin}/${candidate.file}`);
        // Advance the deck fully so every slip is revealed (`offsetParent` is
        // non-null) — `collect()` (`src/edges.js:119`) drops an edge whose
        // either endpoint is still hidden by the progressive reveal.
        //
        // TWICE, because `goTo` ignores its index while `started` is false: the
        // first press only enters the deck at slip 0, and the second is the one
        // that jumps to the last slip.
        await edgePage.keyboard.press("End");
        await edgePage.keyboard.press("End");
        const layer = edgePage.locator("div.slipshow > :first-child.slip-edges");
        await layer.waitFor();
        const paths = layer.locator("path.slip-edge");
        if ((await paths.count()) > 0) {
          drawn = { file: candidate.file, d: await paths.first().getAttribute("d") };
        }
      } finally {
        if (own) await own.close();
      }
      if (drawn) break;
    }
    assert.ok(
      drawn,
      `none of ${edgeCandidates.map((c) => c.file).join(", ")} drew a path.slip-edge`,
    );
    assert.ok(
      drawn.d && drawn.d.length > 0 && drawn.d.startsWith("M"),
      `${drawn.file}: first path's d is not a valid path string: ${drawn.d}`,
    );
  });
} finally {
  await close();
}
