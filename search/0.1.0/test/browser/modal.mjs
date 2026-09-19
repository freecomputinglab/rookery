// Real-engine assertions for `#search-modal`, against the built demo at
// ../../demo/rheo/build/html/ (see that project's check.sh for what the
// build itself asserts). Node with linkedom has no `<dialog>`, no top layer
// and no `fetch`, so the modal's actual behaviour — does the trigger open
// it, do rows render, does Escape close it, does a touch tap work, does a
// failed index still open it with a visible message — is otherwise asserted
// nowhere.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { serve, requireBuild, run } from "../../../../test/browser/harness.mjs";

const ROOT = new URL("../../demo/rheo/build/html/", import.meta.url).pathname;
requireBuild(`${ROOT}index.html`, "cd search/0.1.0/demo/rheo && just check");

// The request to abort in case 5 is read off the built page rather than
// hardcoded, so a future change to the asset's name or path does not leave
// that case silently asserting nothing.
const builtHtml = await readFile(`${ROOT}index.html`, "utf8");
const indexSrcMatch = builtHtml.match(/data-rookery-search-src="([^"]+)"/);
assert.ok(indexSrcMatch, "index.html carries no data-rookery-search-src to route");
const indexSrc = indexSrcMatch[1];

const DIALOG = "dialog[data-rookery-search]";

// A word from a REAL row's title, read off the modal's own (unfiltered) list
// rather than hardcoded, so the demo corpus can change without this suite
// drifting out of sync with it.
const wordFrom = (title) =>
  title.trim().split(/\s+/).find((w) => /^[A-Za-z]{3,}$/.test(w)) ?? title.trim();

const activeIsInput = () =>
  document.activeElement?.classList.contains("rookery-search-input") ?? false;

const { origin, close } = await serve(ROOT);
try {
  await run("search-modal", async ({ browser, newPage }) => {
    // Cases 1-3 share one page: open, type a query, then Escape while it is
    // non-empty.
    const page = await newPage();
    await page.goto(`${origin}/index.html`);

    await page.click(".rookery-search-trigger");
    const dialog = page.locator(DIALOG);
    assert.equal(await dialog.evaluate((d) => d.open), true, "trigger did not open the dialog");
    assert.equal(await dialog.evaluate((d) => d.matches(":modal")), true, "dialog did not become :modal");
    const rectHeight = await dialog.evaluate((d) => d.getBoundingClientRect().height);
    assert.ok(rectHeight > 0, `dialog height is ${rectHeight}, wanted > 0`);
    assert.equal(await page.evaluate(activeIsInput), true, "the search input is not focused after opening");
    assert.equal(page.errors.length, 0, `page recorded errors on open: ${page.errors}`);

    const input = dialog.locator(".rookery-search-input");
    const rows = dialog.locator(".rookery-search-list .rookery-search-row");
    const firstTitle = await dialog.locator(".rookery-search-list .rookery-search-title").first().textContent();
    const word = wordFrom(firstTitle);
    await input.fill(word);
    await rows.first().waitFor();
    assert.ok((await rows.count()) > 0, `query "${word}", drawn from the corpus's own first row, produced no rows`);

    // A long title, id or tag must wrap or break inside the list pane rather
    // than push it wide — regression guard for the pane's overflow-x rule.
    // The built demo's own fixtures may be short enough that this never
    // failed before that rule existed; it still stands guard against a
    // future row wide enough to trigger it.
    const listOverflows = await dialog.evaluate((d) => {
      const list = d.querySelector(".rookery-search-list");
      return list.scrollWidth > list.clientWidth;
    });
    assert.equal(listOverflows, false, "the search list pane scrolls horizontally");

    // A non-empty query is load-bearing here: a focused `type="search"` input
    // with a value consumes the first Escape for its own clear action before
    // it reaches the dialog's cancel algorithm, which is why `modal.js`
    // handles Escape explicitly rather than leaving it to the dialog.
    await page.keyboard.press("Escape");
    assert.equal(await dialog.evaluate((d) => d.open), false, "Escape did not close the dialog");

    // Case 4: a touch tap on an emulated iPad, in its own context — half of
    // the reported bug (Safari on macOS and iPad both do nothing today).
    const touchContext = await browser.newContext({
      hasTouch: true,
      isMobile: true,
      viewport: { width: 820, height: 1180 },
    });
    const touchErrors = [];
    const touchPage = await touchContext.newPage();
    touchPage.on("pageerror", (err) => touchErrors.push(err));
    touchPage.on("console", (msg) => {
      if (msg.type() === "error") touchErrors.push(msg);
    });
    await touchPage.goto(`${origin}/index.html`);
    await touchPage.locator(".rookery-search-trigger").tap();
    const touchDialog = touchPage.locator(DIALOG);
    assert.equal(await touchDialog.evaluate((d) => d.open), true, "touch tap did not open the dialog");
    assert.equal(await touchDialog.evaluate((d) => d.matches(":modal")), true, "touch: dialog did not become :modal");
    const touchRectHeight = await touchDialog.evaluate((d) => d.getBoundingClientRect().height);
    assert.ok(touchRectHeight > 0, `touch: dialog height is ${touchRectHeight}, wanted > 0`);
    assert.equal(await touchPage.evaluate(activeIsInput), true, "touch: the search input is not focused after opening");
    assert.equal(touchErrors.length, 0, `touch: page recorded errors on open: ${touchErrors}`);
    await touchContext.close();

    // Case 5: the index fetch fails. The trigger must still open the dialog
    // — this is the reported Safari symptom, and it is fixed by wiring the
    // trigger before the index is awaited rather than after — and say so,
    // loudly: a visible message and a console warning, not a silently empty
    // list.
    const failPage = await newPage();
    const warnings = [];
    failPage.on("console", (msg) => {
      if (msg.type() === "warning") warnings.push(msg.text());
    });
    await failPage.route(`${origin}/${indexSrc}`, (route) => route.abort());
    await failPage.goto(`${origin}/index.html`);
    await failPage.click(".rookery-search-trigger");
    const failDialog = failPage.locator(DIALOG);
    assert.equal(await failDialog.evaluate((d) => d.open), true, "a failed index left the trigger inert");
    const preview = failDialog.locator(".rookery-search-preview");
    await preview.filter({ hasText: "Search index unavailable" }).waitFor({ timeout: 10_000 });
    assert.ok(
      warnings.some((w) => w.includes("@rookery/search")),
      `no console warning named @rookery/search; got ${JSON.stringify(warnings)}`,
    );

    // Case 6: the index fetch is merely SLOW, not failed. Opened while it is
    // still in flight, the dialog must say it is loading, not that nothing
    // matched — the pending state this bird distinguishes from the loaded
    // one above and the failed one in case 5.
    const slowPage = await newPage();
    await slowPage.route(`${origin}/${indexSrc}`, async (route) => {
      await new Promise((r) => setTimeout(r, 3000));
      await route.continue();
    });
    await slowPage.goto(`${origin}/index.html`);
    await slowPage.click(".rookery-search-trigger");
    const slowDialog = slowPage.locator(DIALOG);
    assert.equal(await slowDialog.evaluate((d) => d.open), true, "a slow index left the trigger inert");
    const slowPreview = slowDialog.locator(".rookery-search-preview");
    await slowPreview.filter({ hasText: "Loading search index" }).waitFor({ timeout: 2_000 });
    assert.equal(
      await slowPreview.evaluate((p) => p.textContent.includes("No match found")),
      false,
      "the pending preview reads \"No match found\" before the index has arrived",
    );
    assert.equal(
      await slowPreview.evaluate((p) => "rookerySearchLoading" in p.dataset),
      true,
      "the pending preview carries no data-rookery-search-loading attribute",
    );
    const slowRows = slowDialog.locator(".rookery-search-list .rookery-search-row");
    await slowRows.first().waitFor({ timeout: 10_000 });
    assert.ok((await slowRows.count()) > 0, "the index landed but the modal shows no rows");
    assert.equal(
      await slowPreview.evaluate((p) => "rookerySearchLoading" in p.dataset),
      false,
      "data-rookery-search-loading survives the index landing",
    );
    assert.equal(slowPage.errors.length, 0, `page recorded errors: ${slowPage.errors}`);
  });
} finally {
  await close();
}
