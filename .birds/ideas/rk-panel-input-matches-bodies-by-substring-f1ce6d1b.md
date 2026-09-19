---
id: rk-panel-input-matches-bodies-by-substring-f1ce6d1b
short-id: f1c
title: Panel input matches bodies by substring
priority: 3
labels:
- fix-panel-body-substring
deps: []
closed: true
---
A panel's text input filters almost nothing on a real corpus, because it
subsequence-matches the note's whole BODY. On waterline's `index.typ` — two
`.panel`s over 132 todos and 378 ideas — typing `lyotard` into the ideas box
leaves **198 of 375 rows** on screen, and the nonsense query `zzzz` leaves
**12**. A reader types and the list does not visibly change, which reads as the
box being dead.

Touches: search/0.1.0/src/base.typ, search/0.1.0/src/panel.typ, search/0.1.0/src/filter-panel.typ, search/0.1.0/src/panel.js, search/0.1.0/test/panelinput.test.mjs

## Why it happens

`score` (`search/0.1.0/src/score.js:10`) is a SUBSEQUENCE matcher: it returns
non-`null` when the query's characters all appear in the haystack **in order**,
anywhere. That is the right rule for a short string — a title, an id — where a
subsequence hit is a real fuzzy match and a typo still lands.

The panel hands it a long one. `_row-haystack`
(`search/0.1.0/src/base.typ:82`) joins the row's `label`, `name` AND `body`;
`#panel` writes that into `data-panel-text` at
`search/0.1.0/src/panel.typ:553` and `#filter-panel` at
`search/0.1.0/src/filter-panel.typ:329`. On the waterline corpus that attribute
is a **median of 245 characters and a maximum of 24,705**. Over a paragraph that
long, essentially every short query is a subsequence of essentially every row —
`z`, `z`, `z`, `z` in order is not a rare event in 24,000 characters.

`wirePanel` then uses that as the whole text predicate. It reads the attribute
at `search/0.1.0/src/panel.js:238` (`text: el.getAttribute("data-panel-text")
|| ""`) and its `resolve` scores it at `search/0.1.0/src/panel.js:280`:

```js
const s = score(row.text, field === "" ? value : `${field}:${value}`);
return s == null ? { matched: false, score: 0 } : { matched: true, score: s };
```

**The package already knows the right rule and applies it everywhere else.**
`_resolve` in `search/0.1.0/src/score.js:141` — the search modal's own
resolver — is two-tiered: `score` (subsequence) over the SHORT `name`/`id`,
falling back to `bodyScore` (`search/0.1.0/src/score.js:60`) over the body,
which is an AND of substring hits and returns `null` unless every
whitespace-split query term is a substring of some word in the haystack. The
modal is not affected by this defect. Only the two panels are, because they were
given one flat haystack and one flat matcher.

## Why no test caught it

`test/panelinput.test.mjs:21-23` — the DOM test that exists precisely to pin
"the input actually hides rows" — uses fixtures whose whole haystack is
`"alpha abstract"`, `"beta reference"`, `"gamma chore"`. At two words per row a
subsequence match and a substring match agree on almost every query, so the
looseness is invisible at that scale. The fixture is the blind spot, not the
assertion.

## The fix, decided

Mirror `_resolve`: subsequence over a short name, substring-AND over the body.
Reuse `bodyScore` rather than writing a second body rule — one matching rule per
language is the reason that function is exported.

Rejected alternative: making the panel substring-match the whole existing
haystack in one tier. It works, but it drops typo tolerance on the TITLE, which
is the one place a subsequence match earns its keep (`filterpanel` finding
`filter panel`). Two tiers costs one attribute and keeps both.

1. In `search/0.1.0/src/base.typ`, beside `_row-haystack` at line 82, add a
   companion that is the SHORT fields only:

   ```typst
   // The short half of the haystack — the row's own name, with no body. The panel
   // subsequence-matches THIS (see `panel.js`), because a subsequence of a
   // paragraph is not a match; the body is matched by substring instead.
   #let _row-name(r) = (
     r.at("label", default: ""),
     r.at("name", default: ""),
   ).filter(s => s != "" and s != none).join(" ")
   ```

2. In `search/0.1.0/src/panel.typ`, in the `attrs:` dictionary that currently
   sets `"data-panel-text": lower(hay(r))` at line 553, add a sibling entry
   directly after it:

   ```typst
   "data-panel-name": lower(_row-name(r)),
   ```

   Leave `data-panel-text` exactly as it is. A caller's own `haystack:` override
   keeps feeding it, unchanged.

3. Do the same in `search/0.1.0/src/filter-panel.typ`, after line 329.

4. In `search/0.1.0/src/panel.js`, extend the import at line 41 to
   `import { score, bodyScore } from "./score.js";`.

5. In `search/0.1.0/src/panel.js`, in the row-reading `.map` that builds each
   row object, add a `name` field beside `text` at line 238:

   ```js
   name: el.getAttribute("data-panel-name") || "",
   ```

6. In `search/0.1.0/src/panel.js`, replace the two lines of `resolve` at 280-281
   with the two-tier rule. The panel FILTERS and does not rank — the surrounding
   comment at 264-272 says so, and `evalClauses`' score is already thrown away —
   so both tiers return `score: 0`:

   ```js
   const text = field === "" ? value : `${field}:${value}`;
   // TWO TIERS, `_resolve`'s rule in `score.js` — subsequence over the row's
   // NAME, substring-AND over its body. A subsequence of a 24,000-character
   // body matches every row and filters nothing.
   if (score(row.name, text) != null) return { matched: true, score: 0 };
   return { matched: bodyScore(row.text, text) != null, score: 0 };
   ```

7. Add one test to `search/0.1.0/test/panelinput.test.mjs` with a fixture whose
   haystack is long enough to show the difference — a row of prose, plus a query
   that is a subsequence of it and not a substring of any of its words:

   ```js
   test("a long body is matched by substring, not subsequence", () => {
     const { document } = parseHTML(`<!doctype html><body><div class="panel" data-panel-ready="false">
   <input class="panel-input" type="search"><p class="panel-count">2 rows</p><ul class="panel-results">
   <li class="panel-row" data-panel-name="alpha" data-panel-text="a long paragraph of ordinary prose about typesetting and rivers">a</li>
   <li class="panel-row" data-panel-name="beta" data-panel-text="another note entirely, on birds and their flights">b</li>
   </ul></div></body>`);
     globalThis.document = document;
     wirePanel(document.querySelector(".panel"), 0);
     const input = document.querySelector(".panel-input");
     const shown = () => [...document.querySelectorAll(".panel-row")]
       .filter((r) => !r.hidden).map((r) => r.textContent);
     // `lprs` is a subsequence of row a's body and a substring of no word in it.
     input.value = "lprs";
     input.dispatchEvent(new document.defaultView.Event("input"));
     assert.deepEqual(shown(), []);
     input.value = "rivers";
     input.dispatchEvent(new document.defaultView.Event("input"));
     assert.deepEqual(shown(), ["a"]);
   });
   ```

   Extend that file's header comment to say what the new test pins, in the
   register the rest of it already uses.

## Non-goals

- **Do not touch `score` or `bodyScore` themselves.** Both are correct and both
  are pinned by the Typst/JavaScript parity harness (`just parity`). This bird
  changes only which of them the PANEL reaches for.
- **Do not touch the search modal** (`src/search.js`, `src/modal.js`,
  `src/bar.js`). `_resolve` there is already two-tiered and is the model being
  copied.
- **Do not change the `tags:` branch** of `resolve` at
  `search/0.1.0/src/panel.js:274-279`. Tag matching is a folded prefix test and
  is not affected.
- **Do not add ranking to the panel.** It filters and keeps the build-time order
  the Typst side sorted rows into; that is deliberate.
- **Do not change `_row-haystack` or the `haystack:` argument.** A caller that
  overrides the haystack must keep working exactly as it does now.
- **Do not edit the demo or any downstream site.**

## VERIFY

Run from `search/0.1.0` inside the flight:

```bash
cd search/0.1.0
just test
just parity
just build
```

All three must pass, `just test` including the new test from step 7 and the four
existing tests in `test/panelinput.test.mjs`, which must still pass unchanged.

Then confirm the emitted attribute, which is the half `just test` cannot see —
the Typst side is what writes `data-panel-name`:

```bash
rg -n 'data-panel-name' src/panel.typ src/filter-panel.typ src/panel.js
```

That must report one hit in each of the three files.

Finally, `bd status <this bird's id>` should report the bird retired once the
flight has alighted.