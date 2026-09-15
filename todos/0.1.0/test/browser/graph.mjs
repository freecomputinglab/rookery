// Real-engine assertions for the dependency graph (`src/todos.js`'s
// `render`) and the `#todos-search` filter, against the built demo at
// ../../demo/rheo/build/html/ (see that project's check.sh for what the
// build itself asserts). `test/layout.test.mjs` covers the pure arithmetic
// (`layer`, `place`, `rows`) that decides where a node goes; nothing exercises
// `render` itself turning that arithmetic into an SVG a real engine paints.
import assert from "node:assert/strict";
import { serve, requireBuild, run } from "../../../../test/browser/harness.mjs";

const ROOT = new URL("../../demo/rheo/build/html/", import.meta.url).pathname;
requireBuild(`${ROOT}index.html`, "cd todos/0.1.0 && just check");

const { origin, close } = await serve(ROOT);
try {
  await run("todos-graph", async ({ newPage }) => {
    const page = await newPage();
    await page.goto(`${origin}/index.html`);

    // 1. The graph replaces its fallback, and `render` ran without throwing.
    // The demo renders more than one `.todo-graph` (an epic-scoped graph
    // alongside the full one), so every assertion below is scoped to the
    // FIRST graph's own container rather than the whole page.
    const graphs = page.locator(".todo-graph");
    const graphCount = await graphs.count();
    assert.ok(graphCount >= 1, "expected at least one .todo-graph container");
    const graph = graphs.first();
    const svg = graph.locator("svg.todo-graph-svg");
    await svg.waitFor();
    assert.equal(await svg.count(), 1, "expected exactly one svg.todo-graph-svg in the first .todo-graph");
    const fallback = graph.locator(".todo-graph-fallback");
    const fallbackCount = await fallback.count();
    if (fallbackCount > 0) {
      assert.equal(
        await fallback.first().isVisible(),
        false,
        "the fallback list is still visible alongside the rendered graph",
      );
    }
    assert.equal(page.errors.length, 0, `page recorded errors: ${page.errors}`);

    // 2. Nodes are drawn and positioned: layout.js's arithmetic reached the
    // screen, rather than every node landing at the origin.
    const boxes = graph.locator("g.todo-graph-box");
    const boxCount = await boxes.count();
    assert.ok(boxCount >= 3, `expected at least 3 g.todo-graph-box, got ${boxCount}`);
    const positions = [];
    for (let i = 0; i < boxCount; i++) {
      const box = boxes.nth(i);
      assert.equal(await box.locator("rect.todo-graph-rect").count(), 1, `box ${i} has no rect.todo-graph-rect`);
      assert.equal(await box.locator("text.todo-graph-label").count(), 1, `box ${i} has no text.todo-graph-label`);
      const rect = await box.evaluate((n) => n.getBoundingClientRect());
      positions.push(`${rect.left},${rect.top}`);
    }
    assert.equal(new Set(positions).size, positions.length, `boxes share a top-left position: ${positions}`);

    // 3. Edges resolve to their arrowhead.
    const edges = graph.locator("path.todo-graph-edge");
    const edgeCount = await edges.count();
    assert.ok(edgeCount >= 1, "expected at least one path.todo-graph-edge");
    const firstEdge = edges.first();
    const d = await firstEdge.getAttribute("d");
    assert.ok(d && d.length > 0, `first edge's d is empty: ${d}`);
    const markerEnd = await firstEdge.evaluate((n) => getComputedStyle(n).markerEnd);
    assert.notEqual(markerEnd, "none", "the edge's marker-end resolves to none — #todo-graph-arrow is unreferenced");

    // 4. A node links somewhere (not followed).
    const links = graph.locator("a.todo-graph-link");
    assert.ok((await links.count()) >= 1, "expected at least one a.todo-graph-link");
    const href = await links.first().getAttribute("href");
    assert.ok(href && href.length > 0, `first a.todo-graph-link's href is empty: ${href}`);

    // 5. A filtered row is actually invisible — the on-screen-only bug
    // demo/rheo/check.sh's CSS grep only approximates.
    const search = page.locator(".todo-search").first();
    await search.waitFor();
    const rows = search.locator(".todo-search-row");
    const rowCount = await rows.count();
    assert.ok(rowCount >= 2, `expected at least 2 .todo-search-row to pick a discriminating query, got ${rowCount}`);
    const texts = [];
    for (let i = 0; i < rowCount; i++) {
      texts.push(await rows.nth(i).getAttribute("data-todo-text"));
    }
    const target = texts.find((t) => t && texts.some((other) => other !== t));
    assert.ok(target, `could not find two distinct data-todo-text values among ${JSON.stringify(texts)}`);
    const query = target.trim().split(/\s+/)[0];
    const excludedBefore = texts.filter((t) => !t || !t.toLowerCase().includes(query.toLowerCase()));
    assert.ok(excludedBefore.length > 0, `query "${query}" (the first word of "${target}") matches every row`);

    const input = search.locator(".todo-search-input");
    await input.fill(query);
    await page.waitForFunction(
      (q) => {
        const rowsNow = document.querySelectorAll(".todo-search-row");
        return [...rowsNow].some((r) => r.hidden);
      },
      query,
    );
    let excludedRow = null;
    for (let i = 0; i < rowCount; i++) {
      const row = rows.nth(i);
      if (await row.evaluate((n) => n.hidden)) {
        excludedRow = row;
        break;
      }
    }
    assert.ok(excludedRow, `no .todo-search-row gained the hidden attribute after filtering by "${query}"`);
    const height = await excludedRow.evaluate((n) => n.getBoundingClientRect().height);
    assert.equal(height, 0, `an excluded .todo-search-row has height ${height}, wanted 0`);
  });
} finally {
  await close();
}
