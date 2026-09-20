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
// The anchor INSIDE the permalink, not the permalink itself: core's
// `_permalink` puts `data-rookery` on a wrapping `<span>`, because Typst's
// `link()` renders a bare `<a href="..">` that carries none of the element's
// own attributes. This suite wants the anchor, for its `href` and its click.
const LABEL = '[data-rookery="label"] a';
const DETAILS = '[data-rookery="window-details"]';
const BODY = '[data-rookery="window-body"]';
// The drag handle `drag.js` requires a press to land inside.
const HANDLE = '[data-rookery="window-summary"]';

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

// A press point HIT-TESTED rather than assumed, because the three things that
// make a point draggable are all layout-dependent and this suite runs on three
// engines whose text metrics differ:
//
//   - it must land on THIS card. The demo's `"stack"` layout puts every card in
//     one column, so a font that renders cards taller than the stack's spacing
//     overlaps them, and a press aimed at one card's title can be taken by the
//     card painted over it — which moves the wrong card and leaves this one
//     exactly where it was.
//   - it must land inside the summary row, the handle `drag.js` requires.
//   - it must MISS the anchor inside the tab's `[data-rookery="label"]` permalink, and any other
//     interactive descendant, which `drag.js` bails on so their click survives.
//
// `elementFromPoint` answers all three from inside the page. Candidates walk
// across the title's FIRST client rect — the first line's own box, not the
// union `getBoundingClientRect` returns, whose centre falls between the lines
// when a title wraps.
//
// `scrollIntoViewIfNeeded` first: a raw client rect is viewport-relative, and a
// navigation leaving the page at a different offset (a `goBack` restoring
// scroll position, a reload) silently mis-aims a `page.mouse` call built from a
// stale box — unlike a locator's own `.click()`, which scrolls before it clicks.
//
// Returns `{ point }` or `{ point: null, tried }`, where `tried` says what each
// candidate hit. The caller turns that into its own failure message: a suite
// that cannot aim a press must say WHY rather than report a card that did not
// move.
const pressPoint = async (page, id) => {
  const card = cardLocator(page, id);
  await card.locator(TITLE).scrollIntoViewIfNeeded();
  return page.evaluate(
    ([id, TITLE, HANDLE]) => {
      const card = document.querySelector(`.pinboard-card[data-pinboard-id="${id}"]`);
      if (!card) return { point: null, tried: [`no card with id ${id}`] };
      const rect = card.querySelector(TITLE).getClientRects()[0];
      if (!rect) return { point: null, tried: ["the title has no client rect"] };
      const y = rect.y + rect.height / 2;
      const tried = [];
      // Right of centre first: the permalink sits BEFORE the title in the row,
      // so the far end of the first line is the point least likely to be under
      // it once metrics shift.
      for (const fraction of [0.75, 0.5, 0.9, 0.25]) {
        const x = rect.x + rect.width * fraction;
        const hit = document.elementFromPoint(x, y);
        if (!hit) {
          tried.push(`${fraction}: nothing at (${Math.round(x)}, ${Math.round(y)})`);
          continue;
        }
        const hitCard = hit.closest(".pinboard-card");
        const hitId = hitCard ? hitCard.dataset.pinboardId : null;
        if (hitId !== id) {
          tried.push(`${fraction}: landed on card ${hitId ?? "(none)"}`);
          continue;
        }
        if (!hit.closest(HANDLE)) {
          tried.push(`${fraction}: landed outside the summary row`);
          continue;
        }
        if (hit.closest("a, button, input")) {
          tried.push(`${fraction}: landed on an interactive ${hit.closest("a, button, input").tagName}`);
          continue;
        }
        return { point: { x, y }, tried };
      }
      return { point: null, tried };
    },
    [id, TITLE, HANDLE],
  );
};

// What the board actually looks like, for a failure message. A drag that moved
// nothing is explained by the geometry around it — overlapping cards, a card
// somewhere other than where the stack should have put it — and none of that
// survives in `x moved 0`.
const boardGeometry = (page) =>
  page.$$eval(".pinboard-card", (cards) =>
    cards.map((c) => {
      const r = c.getBoundingClientRect();
      return `${c.dataset.pinboardId} @(${Math.round(r.x)},${Math.round(r.y)}) ${Math.round(r.width)}x${Math.round(r.height)}`;
    }),
  );

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
    return true;
  } catch {
    return false;
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
    const aim = await pressPoint(page, "idea:outline");
    assert.ok(
      aim.point,
      `no draggable point on idea:outline's handle — tried ${JSON.stringify(aim.tried)}; ` +
        `board: ${JSON.stringify(await boardGeometry(page))}`,
    );
    const start = aim.point;
    await page.mouse.move(start.x, start.y);
    await page.mouse.down();
    // EVERY STAGE OF THE GESTURE WAITS ON WHAT IT CAUSED, and the waits happen
    // while the pointer is still down — `mouse.up` ends the drag, so a move
    // still in flight when it fires is a move that never happens at all.
    await page.mouse.move(start.x + 20, start.y + 15, { steps: 3 });
    const started = await dragStarted(page, "idea:outline");
    await page.mouse.move(start.x + 45, start.y + 30, { steps: 3 });
    await page.mouse.move(start.x + 60, start.y + 40, { steps: 3 });
    await settleAt(page, "idea:outline", before.x + 60, 2);
    await page.mouse.up();
    const after = (await positions(page)).find((p) => p.id === "idea:outline");
    // The geometry and whether the press ever became a drag both go in the
    // message: "moved 0" on its own cannot tell a press that missed from a
    // press that landed and was ignored.
    const why =
      ` (drag ${started ? "started" : "NEVER STARTED"}; pressed (${Math.round(start.x)}, ` +
      `${Math.round(start.y)}); board: ${JSON.stringify(await boardGeometry(page))})`;
    assert.ok(Math.abs(after.x - before.x - 60) <= 2, `x moved ${after.x - before.x}, wanted ~60${why}`);
    assert.ok(Math.abs(after.y - before.y - 40) <= 2, `y moved ${after.y - before.y}, wanted ~40`);
    assert.equal(page.errors.length, 0, `page recorded errors during drag: ${page.errors}`);

    // The click that ends a real drag must not also toggle the card open —
    // `src/drag.js` suppresses it deliberately.
    assert.equal(await isOpen(outline), false, "the drag's ending click reopened the card");

    // Case 3: the note's own link still opens, and a drag never intercepts it.
    const counterargument = cardLocator(page, "idea:counterargument");
    const label = counterargument.locator(LABEL);
    // Resolved against the page rather than pasted onto the origin: core mints
    // a permalink relative to the page it sits on, so the href reads
    // `./ideas/<name>.html` from the root and `../..`-style from a nested one,
    // and neither concatenates into a URL the browser will report back.
    const href = await label.getAttribute("href");
    const target = new URL(href, page.url()).href;
    await label.click();
    await page.waitForURL(target);
    assert.equal(page.url(), target, `navigating the label landed on ${page.url()}, wanted ${target}`);
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
    // (`collapsed: true`); case 8 persists the open round trip instead.
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

    // Case 8: an OPEN card's disclosure survives a reload too, not just a
    // closed one — the gap Case 6's comment above flags. `counterargument`
    // has never been dragged or toggled, so its stored entry (if any) is
    // whatever `persist()` last wrote for it; open it here, reload, and
    // confirm `layOutBoard` restores the open state rather than defaulting
    // it back to `#pinboard`'s `folded: true`.
    const reopenPage = await newPage();
    await reopenPage.goto(`${origin}/index.html`);
    const counterargumentCard = cardLocator(reopenPage, "idea:counterargument");
    await counterargumentCard.locator(TITLE).click();
    assert.equal(await isOpen(counterargumentCard), true, "clicking the title did not open counterargument");
    await reopenPage.reload();
    assert.equal(
      await isOpen(cardLocator(reopenPage, "idea:counterargument")),
      true,
      "an open card's disclosure did not survive a reload",
    );
    assert.equal(reopenPage.errors.length, 0, `page recorded errors reopening a card: ${reopenPage.errors}`);
  });
} finally {
  await close();
}
