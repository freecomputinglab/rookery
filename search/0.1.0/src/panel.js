// Browser half of `#panel` in `src/panel.typ`: filter and reorder the rows
// already on the page — reorder onto the pills' and query's own combined
// verdict, never by score, which is what "rank" would imply.
//
// NOTHING IS FETCHED AND NOTHING IS BUILT HERE. The Typst side emitted every row
// up front with its haystack and its faceted values as `data-` attributes, so
// this only shows, hides and reorders them. If it never runs, the page is a
// complete readable list and the stylesheet keeps the chrome that would do
// nothing out of sight.
//
// GENERIC OVER WHATEVER FIELDS A ROW CARRIES. A panel declares its facets in
// Typst; this reads the pill groups off the DOM and takes each group's
// `data-panel-group` as the attribute name to test. So no facet vocabulary lives
// here, which is what lets one implementation serve submissions, todos and
// anything else.
//
// TWO PANEL KINDS, TOLD APART BY `data-panel-mode`. `#panel` (no mode) filters on
// projected fields, ORing within a group and ANDing across groups — bar the groups
// `data-panel-union` names, which OR with each other too. `#filter-panel`
// (`mode="tags"`) filters on bare tag names off `data-panel-tags`, composing them the
// way `data-panel-pill-match` says — "any" by default, "all" to intersect. One
// `wirePanel` serves both and only the predicate branches.
//
// THE INPUT TAKES THE SAME CLAUSE-TREE LANGUAGE the search bar takes —
// `tags:todo&!todo-closed` in a panel's filter box lists the open todos, and
// `tags:todo window` ANDs that gate with a text clause the same way. The
// query is parsed ONCE per keystroke (`splitQuery`) into one tree, and every
// row is resolved against it in one `evalClauses` call: a `tags:` clause
// reads `row.allTags` (every tag its note carries — not the pill set), a
// text clause reads `row.text` via `score`. The panel only FILTERS on the
// result — see `apply` for why it does not also rank by it.
//
// THE EXPRESSION AND THE PILLS BOTH NARROW. See `apply` for why that is the only
// composition that is not surprising.
//
// THE SCORER IS `score` FROM `score.js` and the language is `tagquery.js`, both
// imported rather than re-ported: one ranking rule and one parser per language is
// the whole reason those modules exist.

import { score, bodyScore } from "./score.js";
import { splitQuery, evalClauses } from "./tagquery.js";
// `fold` IS REQUIRED, not decorative: a `tags:` clause's contract is that `tags`
// arrive ALREADY FOLDED, which is how `search()` satisfies it (`score.js`:
// `(row.tags ?? []).map(fold)`). Skip it and a panel's tag query is case- and
// hyphen-sensitive in a way the search bar is not, which reads as the language being
// broken in one of the two places it runs.
import { fold } from "./text.js";
import { readSync, writeSync, commit, claimKey, debounce } from "./urlstate.js";

// `CSS.escape` IS ABSENT UNDER LINKEDOM, which is what the node suite here runs
// on, so rehydration builds its own attribute-selector strings with this rather
// than `CSS.escape` directly. Escapes only what a double-quoted attribute value
// needs escaped — a quote or a backslash — which is narrower than the full CSS
// spec but exactly what a `[attr="value"]` selector requires.
const cssEscape = (s) =>
  globalThis.CSS?.escape ? CSS.escape(s) : s.replace(/["\\]/g, "\\$&");

// DOES ONE GROUP ACCEPT THE ROW? Within a facet the values OR — two state pills mean
// "either".
//
// A MULTI-VALUED FACET (`data-panel-multi`) holds a SET per row rather than a value, so
// the OR becomes an INTERSECTION test: the row carries any pressed value. The same rule
// stated over a set instead of a scalar, which is why it branches here and nowhere else.
//
// SEPARATE FROM `passesFacets` because the answer is now read two ways — a group that
// must accept, and a group that only has to be one of the accepting ones — and the two
// readings must not each carry their own copy of the scalar/multi split.
const accepts = (row, field, wanted, multi) => {
  if (!multi.has(field)) return wanted.has(row.values[field] ?? "");
  for (const v of wanted) if (row.values[field].has(v)) return true;
  return false;
};

// Does a row survive the pills? Groups AND by default — a tag and a state narrow
// together — and an EMPTY set means that facet is unconstrained, which is what makes "no
// pills pressed" show everything rather than nothing.
//
// THE `union` GROUPS ARE THE EXCEPTION, because ANDing is wrong for groups asking
// ONE question in two projections. @rookery/todos splits what a todo is ABOUT
// across `epic` and `tag`: a todo under `epic-rheo` never also gets a `rheo` tag
// pill, the epic group already saying it, so ANDing `rheo` with `birds` — two
// subjects, two pills — can only ever return nothing. The groups stay separate
// because they are derived differently and chip differently; what they compose as
// is declared.
//
// SO: a row must satisfy EVERY pressed ordinary group, and — if any union group has a
// pill pressed at all — at least ONE of the union groups. A single pressed union group
// is therefore exactly what it was before, which is what keeps this from changing the
// one-pill case.
//
// EXPORTED for the node suite, on the same terms as `passesTags` below:
// `src/search.js` does not re-export it. `union` DEFAULTS TO EMPTY, so a panel
// whose markup carries no `data-panel-union` gets the plain AND.
export const passesFacets = (row, facets, multi, union = new Set()) => {
  // `asked` rather than testing `union.size`: a union group with NO pill pressed asks
  // nothing, and requiring a hit from it would hide every row the moment a site declared
  // the composition.
  let asked = false;
  let met = false;
  for (const [field, wanted] of facets) {
    if (wanted.size === 0) continue;
    if (union.has(field)) {
      asked = true;
      if (accepts(row, field, wanted, multi)) met = true;
    } else if (!accepts(row, field, wanted, multi)) return false;
  }
  return !asked || met;
};

// THE TAG PANEL'S PREDICATE (`#filter-panel`, `data-panel-mode="tags"`), and it reads
// the panel's declared composition rather than picking one:
//
//   "any" (THE DEFAULT) — a row survives if it carries ANY pressed tag, so a second
//   pill WIDENS the result. Default because the tags a pill row is built from are
//   usually MUTUALLY EXCLUSIVE in practice — one epic per todo, one sort per
//   submission — and ANDing two of those can only ever return nothing. A filter whose
//   commonest two-press outcome is an empty list is the wrong default whatever the set
//   theory says.
//
//   "all" — a row survives only if it carries EVERY pressed tag, so a second pill
//   narrows. Right where tags genuinely stack (a todo that is `urgent` AND
//   `epic-jobs`), and declared per panel.
//
// AN EMPTY SET PASSES EVERYTHING in both modes, which is what makes "no pills pressed"
// show the whole list rather than none of it — the same rule the facet path relies on.
//
// EXPORTED for the node suite, not for consumers: `src/search.js` — the package's
// public surface — does not re-export it, the same line `test/internal.mjs` draws
// for the helpers it bridges. A predicate this small is better pinned directly than
// through a DOM.
export const passesTags = (row, pressed, mode) => {
  if (pressed.size === 0) return true;
  if (mode === "all") {
    for (const t of pressed) if (!row.tags.has(t)) return false;
    return true;
  }
  for (const t of pressed) if (row.tags.has(t)) return true;
  return false;
};

export const wirePanel = (container, n) => {
  const input = container.querySelector(".panel-input");
  const list = container.querySelector(".panel-results");
  if (input === null || list === null) return null;

  // TWO PANELS, ONE WIRING. `#panel` facets on projected FIELDS; `#filter-panel`
  // filters on bare TAGS. Everything else — the input, the count, the scroll reset,
  // the score-and-reorder loop, the `hidden` handling — is identical, and a second
  // copy of that is precisely what `#panel` was written to stop. So the mode picks a
  // predicate and nothing else.
  const tagMode = container.dataset.panelMode === "tags";
  // "any" unless the panel says otherwise, the absent attribute included.
  const pillMatch = container.dataset.panelPillMatch === "all" ? "all" : "any";

  // `data-panel-sync` NAMES THE WIDGET'S URL NAMESPACE, absent on a panel that
  // never opted in. `claimKey` is what emits the duplicate-key warning; a
  // duplicate simply does not sync, and the panel otherwise works exactly as
  // it does with no `sync:` at all.
  const syncKey = container.dataset.panelSync;
  const syncing = syncKey !== undefined && syncKey !== "" && claimKey(syncKey);

  // The facet fields, read off the groups the Typst side emitted. A panel with no
  // pills is legal and gets an empty map; a tag panel emits no groups at all.
  const facets = new Map();
  for (const group of container.querySelectorAll(".panel-pill-group")) {
    const field = group.dataset.panelGroup;
    if (field) facets.set(field, new Set());
  }
  const fields = [...facets.keys()];

  // WHICH FIELDS HOLD A SET, declared by the Typst side because the markup cannot
  // say it: a padded `" a b "` and a scalar value are the same string once written.
  // Absent on a panel with no such facet.
  const multi = new Set(
    (container.dataset.panelMulti || "").split(" ").filter(Boolean),
  );

  // WHICH GROUPS OR WITH EACH OTHER instead of ANDing — see `passesFacets`. Read
  // the same way `multi` is, and absent on a panel that never declared it.
  const union = new Set(
    (container.dataset.panelUnion || "").split(" ").filter(Boolean),
  );

  // The tag panel's own state: which pills are pressed, as tag names.
  const pressed = new Set();

  // ONE PILL, POSSIBLY SEVERAL BUTTONS. A facet value may be drawn more than
  // once on a panel — @rookery/todos draws a row's own tags as pills inside the
  // row — and `aria-pressed` is the state, so every copy has to carry the same
  // answer or the page shows one filter as both on and off.
  const mirror = (facet, value, on) => {
    const sel = tagMode
      ? `.panel-pill[data-panel-tag="${cssEscape(value)}"]`
      : `.panel-pill[data-panel-facet="${cssEscape(facet)}"][data-panel-value="${cssEscape(value)}"]`;
    for (const el of container.querySelectorAll(sel)) {
      el.setAttribute("aria-pressed", on ? "true" : "false");
    }
  };

  // Read ONCE. The rows never change after this — filtering only toggles `hidden`
  // and re-appends — so the original index survives as the tiebreak that
  // preserves the order Typst sorted them into.
  const rows = [...list.querySelectorAll(".panel-row")].map((el, index) => {
    const values = {};
    for (const f of fields) {
      const raw = el.getAttribute(`data-${f}`) ?? "";
      // A MULTI-VALUED FIELD IS TOKENIZED HERE, once, the same way the tag set below
      // is and for the same reason: an exact membership test beats any string test,
      // and the Typst side padded the attribute so a half-match was never possible
      // either way.
      values[f] = multi.has(f) ? new Set(raw.split(" ").filter(Boolean)) : raw;
    }
    // The attribute is space-padded at both ends by the Typst side, so that a
    // substring test cannot half-match a tag that is another's prefix. Split here
    // anyway and keep a Set: an exact membership test is better than any string
    // test, and the padding then costs nothing but the two empties this filters.
    const tags = new Set(
      (el.getAttribute("data-panel-tags") || " ").split(" ").filter(Boolean),
    );
    // EVERY TAG THE NOTE CARRIES, for the input's `tags:` expression — a DIFFERENT set
    // from `tags` above, which is the PILL set. Under `tag-filter:` or `pills: auto`
    // most of a note's tags have no pill, and on a todo panel the whole `todo-*`
    // namespace has none, so a query reading the pill set could not name them.
    //
    // AN ARRAY, not a Set, because `evalTagQuery` takes one and tests by PREFIX
    // (`tg === v || tg.startsWith(v)`) — a membership test would not do, and folding
    // it into a Set would only be thrown away.
    //
    // FOLDED HERE, once per row, per `evalTagQuery`'s contract. The Typst side
    // deliberately does not fold, so the rule lives in one language.
    const allTags = (el.getAttribute("data-panel-all-tags") || " ")
      .split(" ")
      .filter(Boolean)
      .map(fold);
    return {
      el,
      index,
      text: el.getAttribute("data-panel-text") || "",
      name: el.getAttribute("data-panel-name") || "",
      values,
      tags,
      allTags,
    };
  });
  const total = rows.length;

  // `aria-controls` wired at RUNTIME, because the markup carries no id: a
  // hardcoded one cannot appear twice on a page and nothing stops a site putting
  // two panels on one.
  if (!list.id) list.id = `panel-results-${n}`;
  input.setAttribute("aria-controls", list.id);

  const count = container.querySelector(".panel-count");
  const noun = count ? (count.textContent.split(" ").slice(1).join(" ") || "rows") : "rows";

  const apply = () => {
    // SPLIT ONCE PER KEYSTROKE, ahead of the loop, exactly where `search()`
    // splits it — not per row.
    const { rpn } = splitQuery(input.value);
    const kept = [];
    for (const row of rows) {
      // ONE `evalClauses` CALL, not a predicate-then-score sequence: a
      // `tags:` clause and a bare word are resolved by the SAME walk over
      // `row.allTags`/`row.text`, so `tags:todo window` gates on `todo` and
      // requires `window` in one pass. An unknown field (or a bare word,
      // the same fallback with an empty prefix) falls back to scoring the
      // whole `field:value` string as text, mirroring `_resolve` in
      // `src/rank.typ` and `src/score.js`.
      //
      // THE PANEL DOES NOT RANK — it filters. `evalClauses`' score is
      // computed and thrown away; only `matched` decides whether a row
      // stays, and a match keeps the row in the build-time order the Typst
      // side sorted it into rather than reordering it by that score.
      const resolve = (field, value) => {
        if (field === "tags") {
          return {
            matched: value === "" || row.allTags.some((tg) => tg === value || tg.startsWith(value)),
            score: 0,
          };
        }
        const text = field === "" ? value : `${field}:${value}`;
        // TWO TIERS, `_resolve`'s rule in `score.js` — subsequence over the row's
        // NAME, substring-AND over its body. A subsequence of a 24,000-character
        // body matches every row and filters nothing.
        if (score(row.name, text) != null) return { matched: true, score: 0 };
        return { matched: bodyScore(row.text, text) != null, score: 0 };
      };
      // IT ANDs WITH THE PILLS, which is the only composition that is not
      // surprising: a pressed pill and a typed query are both visible commitments,
      // so a row must satisfy both. A query that silently released the pills would
      // leave buttons on screen reading as pressed while filtering nothing, which
      // is worse than an empty list a reader can explain by looking at it.
      const ok =
        evalClauses(rpn, resolve).matched &&
        (tagMode
          ? passesTags(row, pressed, pillMatch)
          : passesFacets(row, facets, multi, union));
      if (ok) {
        kept.push({ row });
      } else {
        row.el.hidden = true;
      }
    }

    // EVERY MATCH IS SHOWN. The list is a scroll box `--panel-rows` tall — a
    // stylesheet's business, not this script's — so there is nothing to cap here
    // and no row a reader cannot reach.
    //
    // `hidden` is the ATTRIBUTE rather than a class: it is what tells assistive
    // technology the row is absent, where a class would hide it visually and leave
    // it in the accessibility tree. It needs `.panel-row[hidden]` in the stylesheet
    // to bite, the row setting its own `display` and the UA's `[hidden]` rule
    // losing to any author rule that does.
    // ONE WRITE TO THE LIVE LIST, not one per row. Appending an element that is
    // already in the document MOVES it, in a fragment exactly as in the list, so
    // the resulting order is the same — a panel over a few hundred rows just stops
    // doing a few hundred separate mutations per keystroke.
    const order = document.createDocumentFragment();
    for (const { row } of kept) {
      row.el.hidden = false;
      order.append(row.el);
    }
    list.append(order);

    // Scrolled halfway down and then narrowing the query would otherwise leave
    // the box parked past the end of the new, shorter list.
    list.scrollTop = 0;

    if (count) {
      if (kept.length === 0) count.textContent = "nothing matches";
      else if (kept.length === total) count.textContent = `${total} ${noun}`;
      else count.textContent = `${kept.length} of ${total}`;
    }
  };

  // WRITES THE CURRENT STATE INTO THE URL, a no-op unless this panel claimed
  // its key. `location.search` is read fresh on every call rather than
  // captured once: a second synced widget on the page writes between two
  // calls to this one, and a captured string would drop its params.
  const persist = () => {
    if (!syncing) return;
    const values = new Map();
    if (tagMode) values.set("t", pressed);
    else for (const [field, set] of facets) values.set(field, set);
    commit(writeSync(syncKey, { q: input.value, values }, location.search));
  };
  const persistSoon = debounce(persist);

  input.addEventListener("input", apply);
  input.addEventListener("input", persistSoon);
  input.addEventListener("keydown", (ev) => {
    // Escape clears the query and restores the original order.
    if (ev.key === "Escape") {
      input.value = "";
      apply();
      // Immediate, not debounced: a deliberate clear should drop its param at
      // once rather than wait out a quiet period nothing else is filling.
      persist();
    }
  });

  // `aria-pressed` IS THE STATE, in both modes: the sets above mirror it, and
  // nothing carries a pressed CLASS — a class would be a second source of truth and
  // the stylesheets already key off the attribute.
  for (const pill of container.querySelectorAll(".panel-pill")) {
    pill.addEventListener("click", () => {
      const set = tagMode ? pressed : facets.get(pill.dataset.panelFacet);
      if (!set) return;
      const value = tagMode ? pill.dataset.panelTag : pill.dataset.panelValue;
      if (!value) return;
      if (set.has(value)) set.delete(value);
      else set.add(value);
      mirror(pill.dataset.panelFacet, value, set.has(value));
      apply();
      // A pill press is one deliberate act, unlike a keystroke, so it lands
      // in the URL immediately rather than behind the input's debounce.
      persist();
    });
  }

  // REHYDRATE BEFORE THE FIRST `apply()`, so the restored state renders as
  // the first paint rather than an unfiltered flash followed by a second
  // render. A URL value naming a pill this markup does not carry is IGNORED,
  // not applied: a stale link naming a value no longer offered would
  // otherwise filter every row away with nothing on screen to explain it or
  // press to undo it.
  if (syncing) {
    const st = readSync(syncKey, location.search);
    if (st.q) input.value = st.q;
    if (tagMode) {
      for (const v of st.values.get("t") ?? []) {
        const sel = `.panel-pill[data-panel-tag="${cssEscape(v)}"]`;
        if (container.querySelectorAll(sel).length === 0) continue;
        pressed.add(v);
        mirror(null, v, true);
      }
    } else {
      for (const [field, wanted] of st.values) {
        const set = facets.get(field);
        if (!set) continue;
        for (const v of wanted) {
          const sel = `.panel-pill[data-panel-facet="${cssEscape(field)}"][data-panel-value="${cssEscape(v)}"]`;
          if (container.querySelectorAll(sel).length === 0) continue;
          set.add(v);
          mirror(field, v, true);
        }
      }
    }
  }

  container.setAttribute("data-panel-ready", "true");
  apply();
  return { container, apply };
};

// ONE PANEL'S FAILURE IS ONE PANEL'S. `wirePanel` reads shapes the Typst side
// is trusted to have emitted, and a page mixing an older build's markup with
// this script is enough to throw — which, uncaught, would also take the
// search modal wired after it.
export const initPanels = () => {
  let n = 0;
  for (const c of document.querySelectorAll(".panel")) {
    try {
      wirePanel(c, n++);
    } catch (err) {
      console.error("@rookery/search: a #panel could not be wired and is left as a plain list.", c, err);
    }
  }
};
