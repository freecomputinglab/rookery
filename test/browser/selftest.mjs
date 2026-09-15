// Proves the flake wiring, the Playwright resolution, the static server and
// the engine loop all work together, before any package ships a real suite.
import { mkdtemp, writeFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import assert from "node:assert/strict";
import { serve, run } from "./harness.mjs";

const dir = await mkdtemp(path.join(tmpdir(), "rookery-browser-selftest-"));
await writeFile(
  path.join(dir, "index.html"),
  "<!doctype html>\n<title>selftest</title>\n<p>ok</p>\n",
);

const { origin, close } = await serve(dir);
try {
  await run("selftest", async ({ newPage }) => {
    const page = await newPage();
    await page.goto(origin);
    assert.equal(await page.title(), "selftest");
  });
} finally {
  await close();
  await rm(dir, { recursive: true });
}
