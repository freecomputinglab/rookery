// The only file in this repo that knows how to find Playwright or how to
// serve a directory. A suite imports `loadPlaywright`/`serve`/`requireBuild`/
// `run` and writes its own assertions with `node:assert/strict`, the same
// module the existing `*.test.mjs` files use.
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";

// `PLAYWRIGHT_CORE` is set by the root devShell to the nixpkgs
// `playwright-driver` derivation, which is the playwright-core package.
// Imported by absolute path because node ignores NODE_PATH for ES modules.
// The fallback is for a plain `node_modules` install, which is how CI gets it.
export const loadPlaywright = async () => {
  const core = process.env.PLAYWRIGHT_CORE;
  return core ? import(`${core}/index.mjs`) : import("playwright-core");
};

const CONTENT_TYPES = {
  ".html": "text/html",
  ".js": "text/javascript",
  ".mjs": "text/javascript",
  ".json": "application/json",
  ".css": "text/css",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".woff2": "font/woff2",
};

// Serves `dir` on an ephemeral port. Every request is resolved against `dir`
// and refused if the resolved path does not start with `dir`, so a `..`
// cannot escape it. A wrong content type on `.js`/`.mjs` is fatal — every
// engine refuses a module script not served as JavaScript — hence the
// explicit table above instead of leaning on a default.
export const serve = async (dir) => {
  const root = path.resolve(dir);
  const server = createServer(async (req, res) => {
    const url = new URL(req.url, "http://localhost");
    let reqPath = decodeURIComponent(url.pathname);
    if (reqPath.endsWith("/")) reqPath += "index.html";
    const resolved = path.resolve(root, "." + reqPath);
    if (resolved !== root && !resolved.startsWith(root + path.sep)) {
      res.writeHead(404, { "Content-Type": "text/plain" });
      res.end("not found");
      return;
    }
    try {
      const body = await readFile(resolved);
      const type = CONTENT_TYPES[path.extname(resolved)] ?? "application/octet-stream";
      res.writeHead(200, { "Content-Type": type });
      res.end(body);
    } catch {
      res.writeHead(404, { "Content-Type": "text/plain" });
      res.end("not found");
    }
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const { port } = server.address();
  return {
    origin: `http://127.0.0.1:${port}`,
    close: () => new Promise((resolve) => server.close(resolve)),
  };
};

// A suite asserts against a real `rheo compile` output rather than a
// hand-written page. This is what turns a forgotten build into a legible
// message instead of a confusing 404.
export const requireBuild = (filePath, hint) => {
  if (!existsSync(filePath)) {
    console.error(`browser: ${filePath} is missing — run ${hint} first`);
    process.exit(1);
  }
};

// WebKit first: it is the engine this repo cannot otherwise run, so a
// failure there should be the first thing printed.
const ALL_ENGINES = ["webkit", "chromium", "firefox"];

// `ROOKERY_BROWSER_ENGINES` narrows that list, as a comma-separated subset.
// Unset — every local run — means all three.
//
// CI sets it to `webkit,chromium`. Gecko is excluded there and NOT because its
// results are unwanted: it is the one engine whose synthetic pointer input is
// unreliable on a GitHub runner. `pinboard-board`'s drag case reported a card
// moving 55px of a 60px drag on one run and not moving at all on the next,
// while both other engines passed every time and Gecko itself passes locally.
// Waiting on the gesture's own `data-dragging` marker for two seconds did not
// change it, which is what rules out a slow runner as the cause.
//
// Every assertion still runs, on two engines. Run the full three before
// touching `src/drag.js`, `src/camera.js` or anything else pointer-driven:
//
//     just browser
const ENGINES = process.env.ROOKERY_BROWSER_ENGINES
  ? process.env.ROOKERY_BROWSER_ENGINES.split(",")
      .map((e) => e.trim())
      .filter(Boolean)
  : ALL_ENGINES;

// A list that narrows to nothing would report every suite as passing without
// launching a browser, which is worse than any failure it could hide.
if (ENGINES.length === 0) {
  console.error("browser: ROOKERY_BROWSER_ENGINES is set but names no engine");
  process.exit(1);
}

const unknown = ENGINES.filter((e) => !ALL_ENGINES.includes(e));
if (unknown.length > 0) {
  console.error(
    `browser: ROOKERY_BROWSER_ENGINES names no such engine: ${unknown.join(", ")} ` +
      `(known: ${ALL_ENGINES.join(", ")})`,
  );
  process.exit(1);
}

export const run = async (suiteName, fn) => {
  const { webkit, chromium, firefox } = await loadPlaywright();
  const launchers = { webkit, chromium, firefox };
  for (const engine of ENGINES) {
    const browser = await launchers[engine].launch();
    try {
      const context = await browser.newContext();
      const newPage = async () => {
        const page = await context.newPage();
        const errors = [];
        page.on("pageerror", (err) => errors.push(err));
        page.on("console", (msg) => {
          if (msg.type() === "error") errors.push(msg);
        });
        page.errors = errors;
        return page;
      };
      await fn({ browser, engine, newPage });
    } catch (err) {
      console.error(`FAIL ${suiteName} [${engine}]: ${err.message}`);
      await browser.close();
      process.exit(1);
    }
    console.log(`ok ${suiteName} [${engine}]`);
    await browser.close();
  }
};
