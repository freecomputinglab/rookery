---
id: rk-say-the-index-is-loading-not-that-3f215825
short-id: 3f2
title: Say the index is loading, not that nothing matched
priority: 3
labels:
- fix-search-modal-pending-state
deps: []
closed: false
---
Touches: search/0.1.0/src/modal.js, search/0.1.0/src/search.js, search/0.1.0/src/search.css, search/0.1.0/test/browser/modal.mjs

`#search-modal` opened while the search index is still being fetched tells the
reader their archive is empty. The preview pane reads **"No match found"** — the
same words a query that genuinely matches nothing gets — until the index lands,
at which point the rows appear and the message vanishes.

MEASURED against the deployed build of a real 112-idea site (Playwright WebKit,
`index.json` delayed 6s): 0.5s after the trigger was clicked the dialog was
99px tall with 0 rows and the text "No match found"; 7.5s later, the same dialog
was 514px tall with 30 rows. Reproduced identically in WebKit, Chromium and
Gecko, so this is not engine-specific.

On a fast connection the window is invisible. On a slow one it is a search box
that says the site has nothing in it, which reads as broken search — close
enough to the inert-button symptom that bird `79` fixed
(`fix-safari-search-modal`) that it can generate fresh reports of the same
shape. This bird makes the pending state say "loading" instead.

## Why it says the wrong thing

`search/0.1.0/src/search.js:102` wires each dialog before the index is fetched
— deliberately, and that ordering must not change; it is what bird `79`
established so a trigger is live on first paint. It passes an empty array:

```js
    const modal = wireModal(dialog, []);
```

`search/0.1.0/src/modal.js:27-28` derives two variables from that argument:

```js
  let corpus = Array.isArray(rows) ? rows : [];
  let loaded = Array.isArray(rows);
```

`[]` IS an array, so `loaded` is `true` from the moment of wiring. The empty
message at `src/modal.js:165` then picks the wrong branch:

```js
      empty.textContent = loaded
        ? "No match found"
        : "Search index unavailable — reload the page, or check the browser console.";
```

`loaded` is carrying two meanings at once — "rows have arrived" and "rows are
never coming" — when there are really three states: **pending** (no answer
yet), **loaded** (rows arrived, possibly zero), and **failed** (`setRows(null)`,
the index will never arrive). Pending is currently indistinguishable from
loaded, so it borrows loaded's message.

## Approach, already decided

Make the state tri-valued and give pending its own affordance.

**Pending is signalled by the ABSENCE of the second argument**, not by a new
sentinel value: `wireModal(dialog)` means "rows are coming", `setRows(array)`
means they arrived, `setRows(null)` means they never will. This keeps the
existing public contract intact — `wireModal(dialog, [])` still means "loaded
and empty", which is what an external caller holding rows in hand expects, and
`wireModal` is exported from `search.js` as part of the published
`RookerySearch` surface. A new magic value like `"pending"` would be a second
vocabulary for the same idea.

**The indicator reuses the spinner that already exists** rather than adding a
second one. `search/0.1.0/src/search.css:511-546` already defines a themed,
reduced-motion-aware spinner driven by a data attribute
(`.rookery-search-preview[data-rookery-search-loading]::after`, the
`rookery-search-spin` keyframes at line 532, and the
`prefers-reduced-motion` override at line 540). Setting that SAME attribute on
the preview pane during the pending state gets the spinner for free, in the
project's own theme colours, with no new CSS animation.

A spinner alone in an empty pane was rejected as insufficient: the pane is the
wide half of the dialog and a lone 0.9em circle in its corner does not explain
itself. Pending gets the spinner AND a worded line, in the existing
`.rookery-search-preview-empty` register, so the three states read as one
family:

- pending — "Loading search index…" + spinner
- loaded, no hits — "No match found"
- failed — "Search index unavailable — reload the page, or check the browser console."

## Steps

1. In `search/0.1.0/src/modal.js`, replace the two lines at 27-28 with a
   tri-state. Keep `corpus` as it is and replace the boolean `loaded` with a
   single status string, so there is one variable holding one meaning:

   ```js
   let corpus = Array.isArray(rows) ? rows : [];
   // Three states, not two: rows have not arrived YET (the modal was wired
   // before the fetch, so its trigger is live on first paint), rows arrived, or
   // rows are never coming. Pending and loaded-but-empty need different words.
   let status = Array.isArray(rows) ? "loaded" : rows === undefined ? "pending" : "failed";
   ```

   Write the comment in the register `CLAUDE.md` requires — present tense, no
   history, no bird id.

2. In the same file, in the `hits.length === 0` branch beginning at line 157,
   replace the `empty.textContent = loaded ? … : …` ternary at line 165 with a
   three-way choice on `status`, and set the loading attribute for the pending
   case only. The surrounding lines already `delete
   preview.dataset.rookerySearchLoading` before this point (line 162), so the
   pending case is the one place that puts it back:

   ```js
   empty.textContent =
     status === "pending"
       ? "Loading search index…"
       : status === "loaded"
         ? "No match found"
         : "Search index unavailable — reload the page, or check the browser console.";
   if (status === "pending") preview.dataset.rookerySearchLoading = "true";
   ```

   Keep `empty.className = "rookery-search-preview-empty"` at line 164 exactly
   as it is — all three messages share that one muted-italic register on
   purpose, as the comment above `.rookery-search-preview-empty` in the
   stylesheet says.

3. In the same file, update `setRows` at lines 226-228 to write the same
   tri-state. `null` is the explicit "never coming" answer `search.js` sends, so
   it must land on `"failed"`, never back on `"pending"`:

   ```js
   setRows: (next) => {
     status = Array.isArray(next) ? "loaded" : "failed";
     corpus = status === "loaded" ? next : [];
     if (dialog.open) render();
   },
   ```

   The existing `if (dialog.open) render()` is what repaints a modal the reader
   already has open when the index lands — leave it in place; it is what
   replaces the spinner with rows.

4. In `search/0.1.0/src/search.js`, change line 102 from
   `const modal = wireModal(dialog, []);` to `const modal = wireModal(dialog);`
   so the pending state is what a pre-fetch wiring actually produces. Update the
   comment immediately above it (lines 95-98), which currently ends "A modal
   with no rows opens and says it has none; `setRows` below fills it in" — that
   sentence describes the behaviour this bird is removing. It should now say the
   modal opens and reports that the index is still loading.

   Do NOT move the wiring loop relative to the `await` on line 176. That
   ordering is the fix bird `79` landed and it is why the trigger works at all.

5. In `search/0.1.0/src/search.css`, widen the two selectors that currently name
   only the fetch-driven case so the same spinner serves the pending state. At
   line 511 the selector is
   `.rookery-search-preview[data-rookery-search-loading]::after`, and at line
   541 the same selector repeats inside the
   `@media (prefers-reduced-motion: reduce)` block at line 540.

   NO SELECTOR CHANGE IS NEEDED if step 2 sets `data-rookery-search-loading` on
   the same `.rookery-search-preview` element — verify this first by reading the
   selector, and if it already matches, make no CSS edit at all and say so in
   the report. The attribute is set on `preview` in both cases, so the existing
   rule should apply as written. Only if the pending indicator ends up on a
   different element (it should not) does the selector need widening.

   If no CSS change is needed, still add one sentence to the comment block at
   lines 496-510 noting that the attribute now also marks the index-loading
   state, not only a note fetch — that comment currently says it is set "for as
   long as the selected note's minted page is being fetched", which would become
   incomplete.

6. Add a case to `search/0.1.0/test/browser/modal.mjs`. Model it on case 5 (the
   aborted-index case, which begins around line 101 and routes
   `` `${origin}/${indexSrc}` ``) — that case already demonstrates the exact
   mechanics: its own page, a `route` on the index asset, and assertions that
   the dialog still opens. Where case 5 calls `route.abort()`, this case should
   DELAY the response instead, then click the trigger and assert the pending
   state, then let the index land and assert it resolves:

   ```js
   await slowPage.route(`${origin}/${indexSrc}`, async (route) => {
     await new Promise((r) => setTimeout(r, 3000));
     await route.continue();
   });
   ```

   Assert three things: the dialog opens; while stalled the preview's text is
   the loading message and NOT "No match found", and the pane carries
   `data-rookery-search-loading`; and after the index lands rows are present and
   the loading attribute is gone. Reuse the file's existing `DIALOG` constant
   (line 23) and its `page.errors` convention, and use
   `node:assert/strict` as every other case does — do not add a test library.

## Non-goals

- Do not change WHEN the index is fetched or when triggers are wired.
  `search.js`'s wire-before-await ordering is bird `79`'s fix; this bird only
  changes what the modal SAYS while that fetch is outstanding.
- Do not touch `#search-bar`'s dropdown (`search/0.1.0/src/bar.js`). A bar is
  wired only after its rows land and stays inert until then, which is its
  documented behaviour; giving it a loading state is a separate decision.
- Do not add a new spinner, a new keyframes block, or a new CSS animation. The
  one at `search.css:511-546` is the only one this package should have.
- Do not add a timeout that gives up on the fetch and switches to the failed
  message. `loadIndex` in `search/0.1.0/src/island.js` already resolves to
  `null` on a genuine failure, and that path already produces the failed
  message; a second timeout would be a second policy.
- Do not change the wording of the other two messages.
- Do not create a new version directory — this is a fix to the shipped
  `search/0.1.0`.

## VERIFY

1. The package builds: `cd search/0.1.0 && just build`
2. Build the demo the browser suite asserts against:
   `cd search/0.1.0/demo/rheo && just check`
3. The modal suite passes on all three engines, new case included:
   `node search/0.1.0/test/browser/modal.mjs`
4. The package's own node tests still pass: `cd search/0.1.0 && just test`
5. `rg -n 'No match found' search/0.1.0/src/modal.js` shows it on the
   `status === "loaded"` branch only, and `rg -n 'wireModal\(dialog' search/0.1.0/src/search.js`
   shows the call passing one argument.