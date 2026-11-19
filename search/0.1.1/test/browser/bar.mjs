// Real-engine assertions for `#search-bar`'s dropdown, against the built demo
// at ../../demo/rheo/build/html/ (see that project's check.sh for what the
// build itself asserts). Node with linkedom has no text-caret model, no real
// focus/blur, and no `fetch`, so the behaviour that matters most here — does
// an arrow key move the selection without moving the caret, does Enter really
// navigate, does a `pointerdown` outside the bar dismiss it before focus
// moves, does the preview pane render a fetched note — is otherwise asserted
// nowhere.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { serve, requireBuild, run } from "../../../../test/browser/harness.mjs";

const ROOT = new URL("../../demo/rheo/build/html/", import.meta.url).pathname;
requireBuild(`${ROOT}index.html`, "cd search/0.1.1/demo/rheo && just check");

// The query is read off the built index rather than hardcoded, so the demo
// corpus can change without this suite drifting out of sync with it. The
// bar's dropdown is closed until the reader types, so there is no rendered
// row to read a title off as `modal.mjs` does — the index JSON that feeds
// every row is read directly instead.
//
// Cases 3 and 4 need the query to match more than one row — advancing a
// selection and going back is meaningless over a single hit — so this picks
// the word (3+ letters) that recurs across the most DISTINCT row titles,
// rather than a single row's own first word.
const builtHtml = await readFile(`${ROOT}index.html`, "utf8");
const indexSrcMatch = builtHtml.match(/data-rookery-search-src="([^"]+)"/);
assert.ok(indexSrcMatch, "index.html carries no data-rookery-search-src to route");
const index = JSON.parse(await readFile(`${ROOT}${indexSrcMatch[1]}`, "utf8"));
assert.ok(index.length > 0, "the built index carries no rows");
const rowCounts = new Map();
for (const row of index) {
  for (const w of new Set(row.text.toLowerCase().match(/[a-z]{3,}/g) ?? [])) {
    rowCounts.set(w, (rowCounts.get(w) ?? 0) + 1);
  }
}
let QUERY = null;
let best = 0;
for (const [w, c] of rowCounts) {
  if (c > best) {
    best = c;
    QUERY = w;
  }
}
assert.ok(QUERY !== null && best >= 2, "no word recurs across at least two rows of the built index");

const BAR = "[data-rookery-search]:not(dialog)";

const { origin, close } = await serve(ROOT);
try {
  await run("search-bar", async ({ newPage }) => {
    const page = await newPage();
    await page.goto(`${origin}/index.html`);

    const bar = page.locator(BAR);
    const input = bar.locator(".rookery-search-input");
    const rows = bar.locator(".rookery-search-results .rookery-search-row");

    const isOpen = () => bar.evaluate((el) => el.dataset.rookerySearchOpen);
    const ariaExpanded = () => input.getAttribute("aria-expanded");

    // Case 1: opens on typing, closes on an empty query.
    await input.click();
    await input.fill(QUERY);
    await rows.first().waitFor();
    assert.equal(await isOpen(), "true", `typing "${QUERY}" did not open the dropdown`);
    assert.equal(await ariaExpanded(), "true", "aria-expanded did not follow the open dropdown");
    assert.ok((await rows.count()) > 0, `query "${QUERY}", drawn from the index's own first row, produced no rows`);

    await input.fill("");
    assert.equal(await isOpen(), "false", "clearing the query did not close the dropdown");
    assert.equal(await ariaExpanded(), "false", "aria-expanded did not follow the closed dropdown");

    // Case 2: ArrowDown moves the selection and leaves the caret alone —
    // `bar.js`'s `ev.preventDefault()` on the arrow branches exists for
    // exactly this, and it is untestable without a real caret.
    await input.fill(QUERY);
    await rows.first().waitFor();
    await input.evaluate((el) => el.setSelectionRange(0, 0));
    const caretBefore = await input.evaluate((el) => el.selectionStart);
    await input.press("ArrowDown");
    const selected = bar.locator('.rookery-search-row[data-rookery-search-selected="true"]');
    assert.equal(await selected.count(), 1, "ArrowDown did not select exactly one row");
    const caretAfter = await input.evaluate((el) => el.selectionStart);
    assert.equal(caretAfter, caretBefore, "ArrowDown moved the text caret instead of the selection");

    // Case 3: Ctrl-n/Ctrl-p move the selection too, the same pair the modal
    // takes.
    const selectedIndex = () =>
      rows.evaluateAll((els) => els.findIndex((el) => el.dataset.rookerySearchSelected === "true"));
    const beforeCtrlN = await selectedIndex();
    await input.press("Control+n");
    assert.equal(await selectedIndex(), beforeCtrlN + 1, "Control+n did not advance the selection");
    await input.press("Control+p");
    assert.equal(await selectedIndex(), beforeCtrlN, "Control+p did not move the selection back");

    // Case 4: Enter navigates to the selected row's own href.
    const href = await selected.evaluate((el) => el.href);
    await Promise.all([page.waitForURL(href), input.press("Enter")]);
    assert.equal(page.url(), href, "Enter did not navigate to the selected row's href");

    await page.goto(`${origin}/index.html`);

    // Case 5: a press outside the bar dismisses it without losing the query,
    // and a dismissed dropdown stays shut until new typing — even a click
    // back into the input. `bar.js` chooses `pointerdown` over `click`
    // because it fires before focus moves, so this uses the page's own mouse
    // rather than `element.dispatchEvent` to reproduce that ordering for real.
    await input.click();
    await input.fill(QUERY);
    await rows.first().waitFor();
    assert.equal(await isOpen(), "true", "reopening before case 5 failed");
    await page.mouse.click(2, 2);
    assert.equal(await isOpen(), "false", "a press outside the bar did not dismiss it");
    assert.equal(await input.inputValue(), QUERY, "dismissing the dropdown lost the reader's query");
    await input.click();
    assert.equal(await isOpen(), "false", "clicking back into the input reopened a dismissed dropdown");

    // Case 6: the preview pane fetches a note's real rendering, reached
    // through the modal (opened only as the route to that pane — this suite
    // asserts nothing about the modal's own open/close behaviour, which is
    // `test/browser/modal.mjs`'s).
    await page.click(".rookery-search-trigger");
    const dialog = page.locator("dialog[data-rookery-search]");
    const modalInput = dialog.locator(".rookery-search-input");
    await modalInput.fill(QUERY);
    const preview = dialog.locator(".rookery-search-preview");
    const window_ = preview.locator("div.idea-window.idea-window-plain");
    await window_.waitFor({ timeout: 10_000 });
    assert.ok((await window_.evaluate((el) => el.childNodes.length)) > 0, "the fetched note rendering has no children");
    assert.equal(
      await preview.evaluate((el) => "rookerySearchLoading" in el.dataset),
      false,
      "the preview pane is still marked loading once the fetch has settled",
    );
  });
} finally {
  await close();
}
