// Real-engine assertions for `#pinboard`, against the built demo at
// ../../demo/rheo/build/html/. Node with linkedom has no pointer capture, no
// layout and no `localStorage`, so the board's actual behaviour — does it
// boot into a real position, does a drag track the pointer, does the note's
// own link still open, does a collapse toggle actually change rendered
// height, does the arrangement survive a reload — is otherwise asserted
// nowhere.
//
// The demo's board uses the package's default layout, `"stack"`: every card
// the store has nothing for lands in one column at x=0, in ids() order, so a
// freshly booted board's cards share an x and differ only in y. Every
// assertion below is written against that, not against the older `"flow"`
// wrapping-grid arrangement.
//
// A card is a `@rookery/core` `#window` with NO disclosure open by default
// (`#pinboard`'s `folded: true`), so on a fresh board every card's
// `[data-rookery="window-details"]` starts WITHOUT `open` — there is no
// `.pinboard-card-toggle` button and no `aria-expanded` anywhere in the
// markup; the disclosure is native `<details>`/`<summary>`, toggled by
// clicking the row and read back by the `open` attribute alone.
import assert from "node:assert/strict";
import { serve, requireBuild, run } from "../../../../test/browser/harness.mjs";

const ROOT = new URL("../../demo/rheo/build/html/", import.meta.url).pathname;
requireBuild(`${ROOT}index.html`, "cd pinboard/0.1.0 && just check");

const CARD = ".pinboard-card";
const TITLE = '[data-rookery="window-title"]';
const LABEL = 'a[data-rookery="label"]';
const DETAILS = '[data-rookery="window-details"]';
const BODY = '[data-rookery="window-body"]';

const cardLocator = (page, id) => page.locator(`${CARD}[data-pinboard-id="${id}"]`);

const positions = (page) =>
  page.$$eval(CARD, (cards) =>
    cards.map((c) => ({
      id: c.dataset.pinboardId,
      x: parseFloat(c.style.getPropertyValue("--pin-x")),
      y: parseFloat(c.style.getPropertyValue("--pin-y")),
    })),
  );

const isOpen = (card) => card.locator(DETAILS).evaluate((d) => d.hasAttribute("open"));

const clearStorage = (page) => page.evaluate(() => localStorage.clear());

// A press in the middle of the title span never lands on the tab's `<a
// data-rookery="label">` link, which sits before it in the same summary row —
// so this is the one point in a card's handle that is always safe for a real
// drag press. `scrollIntoViewIfNeeded` first: a raw `boundingBox()` reports
// viewport-relative coordinates, and a navigation that leaves the page
// scrolled to a different offset (a `goBack` restoring scroll position, a
// reload) silently mis-aims a `page.mouse` call built from a stale box —
// unlike a locator's own `.click()`, which scrolls before it clicks.
const titleCenter = async (card) => {
  const title = card.locator(TITLE);
  await title.scrollIntoViewIfNeeded();
  const box = await title.boundingBox();
  return { x: box.x + box.width / 2, y: box.y + box.height / 2 };
};

// `page.mouse.move` resolves when the event is DISPATCHED, not when the page
// has handled it, so the last move of a drag can still be in flight when the
// card's position is read back. Gecko's protocol is asynchronous enough for
// that to land a card one interpolated step short of where the drag ended —
// a real failure to wait, not a bug in `drag.js`.
//
// Falls through on timeout rather than raising, so the assertion that follows
// reports the position it actually found instead of a timeout that says
// nothing about how far the card moved.
// `drag.js` sets `data-dragging` on the card the moment a press crosses
// DRAG_THRESHOLD, so this is the gesture's own report that it became a drag
// rather than a click. Waiting on it before the remaining moves is what keeps
// a slow engine from reaching `mouse.up` with the press still undecided — a
// card that never moved at all, rather than one that moved too little.
//
// Falls through on timeout for the same reason as `settleAt`.
const dragStarted = async (page, id) => {
  try {
    await page
      .locator(`.pinboard-card[data-pinboard-id="${id}"][data-dragging]`)
      .waitFor({ state: "attached", timeout: 2000 });
  } catch {
    /* the assertion below is the diagnostic */
  }
};

const settleAt = async (page, id, wantX, tolerance) => {
  try {
    await page.waitForFunction(
      ([id, wantX, tolerance]) => {
        const card = document.querySelector(`.pinboard-card[data-pinboard-id="${id}"]`);
        if (!card) return false;
        return Math.abs(parseFloat(card.style.getPropertyValue("--pin-x")) - wantX) <= tolerance;
      },
      [id, wantX, tolerance],
      { timeout: 2000 },
    );
  } catch {
    /* the assertion below is the diagnostic */
  }
};

// Two frames with nothing arriving, which is what lets a "the card did NOT
// move" assertion mean it: an in-flight pointermove would otherwise land
// after the read and the check would pass without having tested anything.
const flushFrames = (page) =>
  page.evaluate(
    () => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))),
  );

const { origin, close } = await serve(ROOT);
try {
  await run("pinboard-board", async ({ newPage }) => {
    // Case 1: the board boots into real, distinct positions with no error.
    const page = await newPage();
    await page.goto(`${origin}/index.html`);
    await clearStorage(page);
    await page.reload();

    const booted = await positions(page);
    assert.equal(booted.length, 4, `expected 4 cards, got ${booted.length}`);
    for (const p of booted) {
      assert.ok(Number.isFinite(p.x) && Number.isFinite(p.y), `card ${p.id} has no numeric position`);
    }
    const seen = new Set();
    for (const p of booted) {
      const key = `${p.x},${p.y}`;
      assert.ok(!seen.has(key), `two cards share position ${key}`);
      seen.add(key);
    }
    assert.equal(page.errors.length, 0, `page recorded errors on boot: ${page.errors}`);

    // Every card starts closed: `#pinboard`'s `folded: true` default, with
    // no stored entry yet to override it.
    for (const p of booted) {
      const open = await isOpen(cardLocator(page, p.id));
      assert.equal(open, false, `card ${p.id} started open, wanted closed (folded: true default)`);
    }

    // Case 2: a real drag on the handle moves the card by the pointer delta.
    const outline = cardLocator(page, "idea:outline");
    const before = (await positions(page)).find((p) => p.id === "idea:outline");
    const start = await titleCenter(outline);
    await page.mouse.move(start.x, start.y);
    await page.mouse.down();
    // EVERY STAGE OF THE GESTURE WAITS ON WHAT IT CAUSED, and the waits happen
    // while the pointer is still down — `mouse.up` ends the drag, so a move
    // still in flight when it fires is a move that never happens at all.
    await page.mouse.move(start.x + 20, start.y + 15, { steps: 3 });
    await dragStarted(page, "idea:outline");
    await page.mouse.move(start.x + 45, start.y + 30, { steps: 3 });
    await page.mouse.move(start.x + 60, start.y + 40, { steps: 3 });
    await settleAt(page, "idea:outline", before.x + 60, 2);
    await page.mouse.up();
    const after = (await positions(page)).find((p) => p.id === "idea:outline");
    assert.ok(Math.abs(after.x - before.x - 60) <= 2, `x moved ${after.x - before.x}, wanted ~60`);
    assert.ok(Math.abs(after.y - before.y - 40) <= 2, `y moved ${after.y - before.y}, wanted ~40`);
    assert.equal(page.errors.length, 0, `page recorded errors during drag: ${page.errors}`);

    // The click that ends a real drag must not also toggle the card open —
    // `src/drag.js` suppresses it deliberately.
    assert.equal(await isOpen(outline), false, "the drag's ending click reopened the card");

    // Case 3: the note's own link still opens, and a drag never intercepts it.
    const counterargument = cardLocator(page, "idea:counterargument");
    const label = counterargument.locator(LABEL);
    const href = await label.getAttribute("href");
    await label.click();
    await page.waitForURL(`${origin}/${href}`);
    assert.ok(page.url().endsWith(href), `navigating the label landed on ${page.url()}, wanted ${href}`);
    await page.goBack();
    await page.waitForURL(`${origin}/index.html`);

    // Case 4: a press that opens the card, then a drag started from the
    // card's own body (not its handle), must not move it at all.
    const interview = cardLocator(page, "idea:interview");
    await interview.locator(TITLE).click();
    assert.equal(await isOpen(interview), true, "clicking the title did not open the card");

    const beforeBody = (await positions(page)).find((p) => p.id === "idea:interview");
    const interviewBody = interview.locator(BODY);
    await interviewBody.scrollIntoViewIfNeeded();
    const bodyBox = await interviewBody.boundingBox();
    assert.ok(bodyBox, "an opened card's body has no bounding box");
    const bodyPoint = { x: bodyBox.x + bodyBox.width / 2, y: bodyBox.y + bodyBox.height / 2 };
    await page.mouse.move(bodyPoint.x, bodyPoint.y);
    await page.mouse.down();
    await page.mouse.move(bodyPoint.x + 100, bodyPoint.y, { steps: 5 });
    await page.mouse.up();
    await flushFrames(page);
    const afterBody = (await positions(page)).find((p) => p.id === "idea:interview");
    assert.deepEqual(afterBody, beforeBody, "a press on the card body moved the card");

    // Closes interview again: case 6 below persists the closed round trip
    // (`collapsed: true`), which `src/pinboard.js` restores explicitly. An
    // OPEN card's stored `collapsed: false` is written by the same `persist`
    // call but never read back — `layOutBoard` only ever calls
    // `setCollapsed(card, true)`, never `setCollapsed(card, false)` — so a
    // card left open here would silently render closed again after a
    // reload. That is a real gap in `src/pinboard.js`, not something this
    // suite's job is to paper over by asserting it away.
    await interview.locator(TITLE).click();
    assert.equal(await isOpen(interview), false, "closing the title did not close the card again");

    // Case 5: the collapse toggle actually changes rendered height, and
    // reverses cleanly.
    const scene = cardLocator(page, "idea:scene-one");
    await scene.scrollIntoViewIfNeeded();
    const closedHeight = (await scene.boundingBox()).height;
    const sceneTitle = scene.locator(TITLE);
    await sceneTitle.click();
    assert.equal(await isOpen(scene), true, "clicking the title did not open scene-one");
    const openHeight = (await scene.boundingBox()).height;
    assert.ok(openHeight > closedHeight, `opened height ${openHeight} not greater than closed height ${closedHeight}`);
    await sceneTitle.click();
    assert.equal(await isOpen(scene), false, "a second click did not close scene-one again");
    const reclosedHeight = (await scene.boundingBox()).height;
    assert.ok(
      Math.abs(reclosedHeight - closedHeight) <= 1,
      `reclosed height ${reclosedHeight} does not match original closed height ${closedHeight}`,
    );
    assert.equal(page.errors.length, 0, `page recorded errors toggling collapse: ${page.errors}`);

    // Case 6: the arrangement survives a reload, and a fresh page in the
    // same context (a `bfcache`-restored page is not what this measures,
    // but a fresh navigation reading the same store is the part that
    // matters — the store, not the page instance, is what has to persist).
    // Checked only for `outline`, `interview` and `scene-one`: each has a
    // real stored entry now, from the drag and the two collapse toggles
    // above. `counterargument` was only ever navigated away from and back
    // to — no drag, no collapse — so the store has nothing for it, and a
    // reload legitimately recomputes its position as an unplaced card among
    // whichever others are still unplaced; asserting it stays put would be
    // asserting a coincidence, not the store's behaviour.
    const stored = {
      outline: (await positions(page)).find((p) => p.id === "idea:outline"),
      interview: (await positions(page)).find((p) => p.id === "idea:interview"),
      scene: (await positions(page)).find((p) => p.id === "idea:scene-one"),
    };
    assert.equal(await isOpen(outline), false, "outline should still be closed going into the reload");
    assert.equal(await isOpen(interview), false, "interview should still be closed going into the reload");
    assert.equal(await isOpen(scene), false, "scene-one should still be closed going into the reload");

    const assertPersisted = async (target) => {
      const got = await positions(target);
      assert.deepEqual(got.find((p) => p.id === "idea:outline"), stored.outline, "outline's position did not persist");
      assert.deepEqual(
        got.find((p) => p.id === "idea:interview"),
        stored.interview,
        "interview's position did not persist",
      );
      assert.deepEqual(
        got.find((p) => p.id === "idea:scene-one"),
        stored.scene,
        "scene-one's position did not persist",
      );
      assert.equal(await isOpen(cardLocator(target, "idea:outline")), false, "outline's closed state did not persist");
      assert.equal(
        await isOpen(cardLocator(target, "idea:interview")),
        false,
        "interview's closed state did not persist",
      );
      assert.equal(await isOpen(cardLocator(target, "idea:scene-one")), false, "scene-one's closed state did not persist");
    };

    await page.reload();
    await assertPersisted(page);
    assert.equal(page.errors.length, 0, `page recorded errors after reload: ${page.errors}`);

    const freshPage = await newPage();
    await freshPage.goto(`${origin}/index.html`);
    await assertPersisted(freshPage);
    assert.equal(freshPage.errors.length, 0, `fresh page recorded errors: ${freshPage.errors}`);

    // Case 7: a card the store has nothing for is still placed, with a
    // position of its own distinct from a card the store names explicitly.
    const seedPage = await newPage();
    await seedPage.goto(`${origin}/index.html`);
    await clearStorage(seedPage);
    await seedPage.evaluate(() => {
      localStorage.setItem(
        "rookery-pinboard:default",
        JSON.stringify({ "idea:outline": { x: 900, y: 900, collapsed: false } }),
      );
    });
    await seedPage.reload();

    const seeded = await positions(seedPage);
    const seededOutline = seeded.find((p) => p.id === "idea:outline");
    assert.equal(seededOutline.x, 900, "a stored x was not honoured on reload");
    assert.equal(seededOutline.y, 900, "a stored y was not honoured on reload");

    const unplaced = seeded.filter((p) => p.id !== "idea:outline");
    assert.equal(unplaced.length, 3, `expected 3 unplaced cards, got ${unplaced.length}`);
    const unplacedKeys = new Set();
    for (const p of unplaced) {
      assert.ok(Number.isFinite(p.x) && Number.isFinite(p.y), `unplaced card ${p.id} has no numeric position`);
      const key = `${p.x},${p.y}`;
      assert.ok(!unplacedKeys.has(key), `two unplaced cards share position ${key}`);
      assert.notEqual(key, "900,900", `unplaced card ${p.id} landed on the stored card's own position`);
      unplacedKeys.add(key);
    }
    assert.equal(seedPage.errors.length, 0, `page recorded errors placing an unseen card: ${seedPage.errors}`);
  });
} finally {
  await close();
}
