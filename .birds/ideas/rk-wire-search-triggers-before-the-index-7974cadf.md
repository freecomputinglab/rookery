---
id: rk-wire-search-triggers-before-the-index-7974cadf
short-id: '79'
title: Wire search triggers before the index loads
priority: 6
labels:
- fix-safari-search-modal
deps: []
closed: true
---
A reader on Safari (macOS and iPad) reported that clicking the search button in
a rookery site's header does nothing at all, while the same click on Firefox and
Brave opens the modal. Investigation reproduced that exact symptom — button
inert, dialog never opens, nothing printed to the console — and found its cause
in this package rather than in the browser.

WHAT WAS RULED OUT, so nobody repeats the work. The modal itself is engine-clean:
driven under Playwright's WebKit 26.5 (the Safari 26 engine), Chromium and
Firefox, against the built HTML of two real rookery sites, the dialog opens at an
identical position and size in all three, on a 1280x900 desktop viewport and on
an emulated iPad with a touch tap. A top-layer `<dialog>` was also checked
against every ancestor style that could plausibly clip or contain it —
`overflow: hidden`, `transform`, `filter`, `backdrop-filter`, `contain: paint`,
`will-change`, `isolation`, `opacity` — and WebKit escapes all of them exactly as
Blink and Gecko do. Serving the JSON index under a wrong MIME type does not
diverge by engine either. So this bird does not chase a WebKit rendering bug;
there is none to chase in a current engine.

WHAT DOES REPRODUCE THE SYMPTOM, exactly, in every engine including WebKit:
make the fetch of the search index fail. Abort the request, or answer it with a
500, and the search button becomes inert and the package says nothing. That is
the whole reported behaviour, and it is a defect in this file regardless of which
Safari-side condition (a content blocker, a cached failure, a captive network, a
host that answers one client differently) caused the fetch to fail for that
reader and not for their other browsers.

THE CAUSE is the order of work in `init()`. Read
`/home/lox/code/_fcl/rookery/search/0.1.0/src/search.js` lines 116-143:

```js
  const modals = new Map();
  for (const dialog of dialogs) {
    const elemId = dialog.dataset.rookerySearch || "rookery-search-index";
    const rows = await rowsFor(elemId);
    if (rows === null) continue;
    const modal = wireModal(dialog, rows);
    if (modal !== null) modals.set(elemId, modal);
  }
  if (modals.size === 0) return;

  for (const trigger of document.querySelectorAll(".rookery-search-trigger")) {
```

The click listener on `.rookery-search-trigger` (line 129) and the Ctrl/Cmd-K
binding (line 136) are both registered AFTER the index has been awaited, and
both are skipped entirely when `loadIndex` hands back `null` — line 120
`continue`s, line 124 returns. A trigger that is never wired is a button that
does nothing, with no error and no warning anywhere.

THE FIX is to wire the chrome first and feed it the corpus second. A modal with
no rows is a perfectly good modal: it opens, it focuses its input, and it says it
has nothing to search. That is a far better failure than an inert button, and it
is the state the reader can screenshot.

Touches: /home/lox/code/_fcl/rookery/search/0.1.0/src/search.js, /home/lox/code/_fcl/rookery/search/0.1.0/src/modal.js, /home/lox/code/_fcl/rookery/search/0.1.0/src/island.js

## Steps

1. In `/home/lox/code/_fcl/rookery/search/0.1.0/src/modal.js`, let a wired modal
   be re-fed its rows after wiring.

   `wireModal(dialog, rows)` is declared at line 14 and `rows` is read in exactly
   one place, inside `render`, as `hits = searchSplit(rows, split, limit);`.
   Introduce a mutable local right after the `limit` line (line 20) and read that
   instead:

   ```js
   // The corpus, re-fed after wiring. `search.js` wires this modal before the
   // index has loaded so its trigger is live on first paint, then hands the
   // rows over when they land — or hands over `null` when they never will.
   let corpus = Array.isArray(rows) ? rows : [];
   let loaded = Array.isArray(rows);
   ```

   Change the one `searchSplit(rows, ...)` call to `searchSplit(corpus, ...)`.

2. Still in `modal.js`, distinguish "nothing matched" from "there is nothing to
   match against". Line 160 currently reads:

   ```js
       empty.textContent = "No match found";
   ```

   Replace it with:

   ```js
       empty.textContent = loaded
         ? "No match found"
         : "Search index unavailable — reload the page, or check the browser console.";
   ```

3. Still in `modal.js`, extend the returned object (line 209-217) with a setter,
   keeping `open` exactly as it is:

   ```js
   return {
     open: () => { /* unchanged */ },
     // Called once by `search.js` when the index settles. `null` means it never
     // will, which is what the empty-state message above reads.
     setRows: (next) => {
       loaded = Array.isArray(next);
       corpus = loaded ? next : [];
       if (dialog.open) render();
     },
   };
   ```

4. In `/home/lox/code/_fcl/rookery/search/0.1.0/src/search.js`, move the modal,
   trigger and keyboard wiring ahead of every `await`. Cut the block at lines
   116-143 and place it BEFORE the `const cache = new Map();` line (line 81),
   rewritten so nothing in it awaits:

   ```js
   // WIRED BEFORE THE INDEX IS FETCHED, and that ordering is the whole point:
   // a trigger registered after an `await` is a dead button whenever the fetch
   // fails, with nothing on screen and nothing in the console to say so. A modal
   // with no rows opens and says it has none; `setRows` below fills it in.
   const modals = new Map();
   for (const dialog of dialogs) {
     const elemId = dialog.dataset.rookerySearch || "rookery-search-index";
     const modal = wireModal(dialog, []);
     if (modal !== null) modals.set(elemId, modal);
   }
   if (modals.size > 0) {
     for (const trigger of document.querySelectorAll(".rookery-search-trigger")) {
       const modal = modals.get(trigger.dataset.rookerySearchModal);
       if (modal === undefined) continue;
       trigger.addEventListener("click", () => modal.open());
     }
     document.addEventListener("keydown", (ev) => { /* body unchanged */ });
   }
   ```

   Keep the existing explanatory comment above the keydown listener and the
   listener's body byte-for-byte; only its guard changes from the `if
   (modals.size === 0) return;` early return to being nested inside `if
   (modals.size > 0)`.

5. At the very end of `init()`, after the bars loop and the `pointerdown`
   listener, feed each modal its rows:

   ```js
   for (const [elemId, modal] of modals) modal.setRows(await rowsFor(elemId));
   ```

   `rowsFor` memoises by `elemId`, so a page whose bar and modal name the same
   island still performs one fetch.

6. In `/home/lox/code/_fcl/rookery/search/0.1.0/src/island.js`, make a failed
   index audible. `loadIndex` (line 32) currently turns every failure into a
   silent `null`. Add a `console.warn` naming the package, the element id and the
   URL at the three points where an index that WAS asked for could not be
   produced — the non-OK response (line 42), the non-array payload (line 45) and
   the `catch` (line 46):

   ```js
     if (!res.ok) {
       console.warn(`@rookery/search: the search index at "${src}" answered ${res.status} — search will be empty.`);
       return null;
     }
   ```

   ```js
     if (!Array.isArray(rows)) {
       console.warn(`@rookery/search: the search index at "${src}" is not a JSON array — search will be empty.`);
       return null;
     }
   ```

   ```js
     } catch (err) {
       console.warn(`@rookery/search: could not fetch the search index at "${src}" — search will be empty.`, err);
       return null;
     }
   ```

   Leave line 34 (`if (el === null) return null;`) SILENT. A page carrying a bar
   and no island is a legitimate configuration, not a failure, and warning there
   would fire on every such page.

## Non-goals

- Do NOT change `#search-bar`'s dropdown (`src/bar.js`) or how bars are wired. A
  bar with no index is an inert text field, which is already what its comment
  promises and is not the reported bug.
- Do NOT change the Typst side. `src/ui.typ` emits the trigger and the dialog
  correctly; nothing in the markup is at fault.
- Do NOT add a retry, a timeout, or a second fetch attempt. One fetch, one
  warning, one legible empty state.
- Do NOT move the `<dialog>` element in the DOM or add a fallback overlay. Top
  layer was measured clean in WebKit, Blink and Gecko.
- Do NOT touch `src/panel.js` — isolating widget wiring from each other is a
  separate bird.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery/search/0.1.0 && just test` — the node suite
   (`test/*.test.mjs`) stays green. `test/island.test.mjs` has four cases that
   exercise the null paths you just added warnings to; they assert the return
   value only, so they must still pass. The new `console.warn` output on stderr
   during those cases is expected and is not a failure.
2. `cd /home/lox/code/_fcl/rookery/search/0.1.0 && just parity` — still prints
   `parity OK across ...`, proving no ranking function was disturbed.
3. `cd /home/lox/code/_fcl/rookery/search/0.1.0 && just build` — vite still
   bundles `dist/lib.js`.
4. Read `src/search.js` and confirm that no `await` appears anywhere above the
   line registering the `.rookery-search-trigger` click listener.
5. `bd status <this bird's id>` reports it as no longer ready once its flight
   lands.