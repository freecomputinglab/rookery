// Browser half of `#todos-search`: filter the rows already on the page.
//
// Nothing is fetched and nothing is built here. The Typst side emitted every
// row up front with its haystack, status and type as `data-` attributes; this
// only shows, hides and reorders them. If it never runs, the page is a complete
// readable list and the stylesheet keeps the chrome that would do nothing out
// of sight.
//
// The pure half is exported so it can be tested without a DOM — the same split
// `layout.js` and `todos.js` already use.
//
// THE INPUT TAKES A `tags:` EXPRESSION WHEN `@rookery/search` IS ON THE PAGE,
// and that capability is reached for through the `RookerySearch` GLOBAL rather
// than an import. The reason is the property `search.typ`'s header states: a
// project wanting only `#todos-search` must need nothing but this package and
// `@rookery/core`, and an import — relative or by coordinate — would make the
// dependency unconditional. A relative ES import could not even serve both asset
// modes: in source mode `rookery/search/tagquery.js` sits beside this file, in
// dist mode each package is one bundled `lib.js` and that path does not exist.
//
// So the language is FEATURE-DETECTED at wire time and degrades to nothing:
// without the global, `tags:todo` is scored as literal text exactly as it was
// before, and nothing is raised. The alternative — a second copy of the parser
// here — would be a third implementation of it with no parity harness over the
// new one.

// A case-insensitive SUBSEQUENCE score: every character of `query` must appear
// in `haystack` in order, though not necessarily adjacently. Returns a number,
// or -1 for no match.
//
// AN EMPTY QUERY SCORES 0 FOR EVERYTHING, which is what leaves the build-time
// priority order untouched until someone types: equal scores keep their
// original index at the call site below.
//
// The score rewards contiguous runs and an earlier first match, so "manifest"
// beats a scattered m-a-n-i-f-e-s-t spread across a sentence.
//
// DELIBERATELY SIMPLER THAN `@rookery/search`'s ranking, which is mirrored
// in Typst and pinned by a parity test. This filter runs over tens of rows
// already on the page rather than a whole corpus, and copying that ranking here
// would create a second copy of it with no parity test to keep the two honest.

// ONE WIRING PER CONTAINER, the same reason `@rookery/search`'s `panel.js`
// keeps one: rheo's dev server morphs a rebuilt page into the live DOM instead
// of reloading it (`docs/contract.md`'s rehydrate protocol), and a morph writes
// the PRE-HYDRATION markup back over a live widget — `data-todo-search-ready`
// reverts to absent, the input empties, pressed pills release, hidden rows
// unhide — while leaving listeners bound to surviving nodes intact. Re-running
// `wire` on a survivor without dropping its old listeners first would double-fire
// every keystroke and every pill press.
//
// `@rheo/rehydrate` keeps the per-key controller bookkeeping, so the
// WeakMap-not-an-expando reasoning lives there once instead of in every package
// that needs it. READ AT CALL TIME: script execution order between two packages
// is whatever order a consuming project imported them in, which neither package
// can see.
//
// The fallback returns a signal without aborting a previous one, which is only
// reached on a rheo too old to have injected the helper — and that is a rheo too
// old to morph, so it reloads the page and there is no previous pass to drop.
const wiring = (key) =>
  globalThis.RheoRehydrate?.wiring?.(key) ?? new AbortController().signal;

export function score(haystack, query) {
  if (!query) return 0;
  const h = haystack.toLowerCase();
  const q = query.toLowerCase();
  let hi = 0;
  let first = -1;
  let run = 0;
  let best = 0;
  for (let qi = 0; qi < q.length; qi++) {
    const found = h.indexOf(q[qi], hi);
    if (found === -1) return -1;
    if (first === -1) first = found;
    run = found === hi && qi > 0 ? run + 1 : 0;
    if (run > best) best = run;
    hi = found + 1;
  }
  // Contiguity dominates; an earlier first match breaks the tie. Both are
  // bounded so a long haystack cannot outscore a better match in a short one.
  return best * 100 + Math.max(0, 100 - first);
}

// Does a row survive the pills?
//
// `facets` is `{ status: Set, type: Set }`. Within a facet the values OR — two
// status pills mean "either" — and across facets they AND. An EMPTY set means
// that facet is unconstrained, which is what makes "no pills pressed" show
// everything rather than nothing.
export function passes(row, facets) {
  for (const [key, wanted] of Object.entries(facets)) {
    if (!wanted || wanted.size === 0) continue;
    if (!wanted.has(row[key])) return false;
  }
  return true;
}

// EXPORTED for the node suite, not for consumers: nothing re-exports it and
// `todos.js` imports this module for its side effect alone. The join between the
// two halves — reading the right attribute, folding it, splitting once, ANDing
// the result with the pills — is what a DOM case can pin and a pure one cannot.
export function wire(container) {
  const input = container.querySelector(".todo-search-input");
  const list = container.querySelector(".todo-search-results");
  const count = container.querySelector(".todo-search-count");
  if (!input || !list) return;

  // Abandons the previous pass BEFORE anything below runs, so a re-wire cannot
  // briefly have two live wirings racing on one input. `signal` then scopes
  // every listener this pass adds, and the next pass drops all of them at once.
  const signal = wiring(container);

  // THE `tags:` LANGUAGE, IF `@rookery/search` PUT IT THERE. Read ONCE at wire
  // time rather than per keystroke, so a page either has the capability or does
  // not and the filter loop below has no third case to consider.
  //
  // ALL THREE FUNCTIONS OR NONE: `splitQuery` parses the query, `fold`
  // normalises the row's tags to what the parser already did to the atoms, and
  // `evalClauses` decides. A partial surface is a version skew, and must degrade
  // exactly as an absent one does rather than half-work.
  const tq = globalThis.RookerySearch;
  const hasTagQuery = Boolean(tq && tq.splitQuery && tq.evalClauses && tq.fold);

  // THE URL-SYNC SURFACE, same all-five-or-none rule as `hasTagQuery` above,
  // over `@rookery/search`'s `urlstate.js`. `data-todo-search-sync` names the
  // query-parameter namespace; `claimKey` refuses a second widget on the page
  // trying to sync the same one.
  const syncKey = container.getAttribute("data-todo-search-sync");
  const hasUrlState = Boolean(
    tq && tq.readSync && tq.writeSync && tq.commit && tq.claimKey && tq.debounce,
  );
  //
  // `container` IS PASSED AS THE CLAIM'S OWNER, which is what lets this widget
  // re-wire itself after a rheo morph without colliding with the claim it made
  // last pass: `claimKey` refuses only a holder still in the document, so the
  // same container re-claims and a container the morph replaced hands its key
  // over. An older `@rookery/search` ignores the extra argument and keeps its
  // write-once behaviour, which is why this needs no feature test of its own.
  const syncing = Boolean(syncKey) && hasUrlState && tq.claimKey(syncKey, container);

  // Read once. The rows never change after this — filtering only toggles
  // `hidden` and re-appends, so the original index survives as the tiebreak
  // that preserves the build-time priority order.
  const rows = [...list.querySelectorAll(".todo-search-row")].map((el, index) => {
    // Padded at both ends by the Typst side, so the two empties are filtered.
    // AN ARRAY, not a Set, because `evalTagQuery` takes one and tests by PREFIX
    // (`tg === v || tg.startsWith(v)`) — a membership test would not do.
    //
    // FOLDED HERE when the language is available, per `evalTagQuery`'s contract;
    // left alone when it is not, since nothing then reads it.
    const tags = (el.getAttribute("data-todo-tags") || " ").split(" ").filter(Boolean);
    return {
      el,
      index,
      text: el.getAttribute("data-todo-text") || "",
      status: el.getAttribute("data-todo-status") || "",
      type: el.getAttribute("data-todo-type") || "",
      tags: hasTagQuery ? tags.map((t) => tq.fold(t)) : tags,
    };
  });
  const total = rows.length;

  // `aria-controls` wired at RUNTIME, because the markup carries no id: a
  // hardcoded one cannot appear twice on a page and nothing stops a project
  // putting two of these widgets on one.
  if (!list.id) {
    list.id = `todo-search-results-${Math.round(performance.now() * 1000)}-${total}`;
  }
  input.setAttribute("aria-controls", list.id);

  const facets = { status: new Set(), type: new Set() };
  const pills = [...container.querySelectorAll(".todo-search-pill")];

  const apply = () => {
    // PARSED ONCE PER KEYSTROKE, ahead of the loop, exactly where `#panel`
    // parses it — not per row. Every clause, gating or scoring, lives in the
    // one `rpn`: `tags:todo` gates and a bare word ranks, and no text sits
    // outside the tree. With no language on the page there is no tree at all
    // and the input value goes to `score` whole, which is what it always did.
    const rpn = hasTagQuery ? tq.splitQuery(input.value).rpn : [];
    const q = input.value.trim();
    const scored = [];
    for (const row of rows) {
      // ONE `evalClauses` CALL, not a predicate-then-score sequence: a `tags:`
      // clause and a bare word are resolved by the SAME walk, so `tags:todo
      // window` gates on the tag and ranks on the word in one pass. An unknown
      // field falls back to scoring the whole `field:value` string as text,
      // mirroring `_resolve` in `@rookery/search`'s `panel.js`.
      //
      // `score` HERE STAYS THIS FILE'S OWN subsequence matcher, deliberately
      // simpler than `@rookery/search`'s (see its comment above). The language
      // and the ranking are separate questions, and only the language is
      // borrowed.
      //
      // AN EMPTY VALUE IS NO CONSTRAINT, per `evalTagQuery`'s own rule: a
      // half-typed `tags:` filters nothing, tagged row or not.
      const resolve = (field, value) => {
        if (field === "tags") {
          return {
            matched: value === "" || row.tags.some((tg) => tg === value || tg.startsWith(value)),
            score: 0,
          };
        }
        const s = score(row.text, field === "" ? value : `${field}:${value}`);
        return s < 0 ? { matched: false, score: 0 } : { matched: true, score: s };
      };
      // It ANDs with the pills for the reason `#panel` does — a pressed pill
      // and a typed query are both visible commitments, and a query that
      // silently released the pills would leave buttons on screen reading as
      // pressed while no longer filtering.
      //
      // An empty tree matches with score `0`, which is what leaves the
      // build-time priority order untouched until someone types.
      const verdict = hasTagQuery
        ? tq.evalClauses(rpn, resolve)
        : { matched: true, score: score(row.text, q) };
      const ok = passes(row, facets) && verdict.matched && verdict.score >= 0;
      const s = ok ? verdict.score : -1;
      if (s < 0) {
        // THE `hidden` ATTRIBUTE NEEDS `.todo-search-row[hidden]` IN THE
        // STYLESHEET to do anything here, and the two must move together. A
        // search row carries `todo-row`, which is `display: flex`, and the UA's
        // `[hidden] { display: none }` loses to any author rule setting
        // `display` — so on its own this hid nothing and the filter merely
        // reordered the list. MEASURED on a live site before the rule existed.
        //
        // Still the attribute rather than a class: `hidden` is what tells
        // assistive technology the row is gone, where a class would hide it
        // visually and leave it in the accessibility tree.
        row.el.hidden = true;
      } else {
        row.el.hidden = false;
        scored.push({ row, s });
      }
    }
    // Higher score first; equal scores keep their original order, which is the
    // priority order Typst sorted them into.
    scored.sort((a, b) => (b.s - a.s) || (a.row.index - b.row.index));
    for (const { row } of scored) list.appendChild(row.el);
    if (count) {
      count.textContent =
        scored.length === total ? `${total} todos` : `${scored.length} of ${total}`;
    }
  };

  // Mirrors the box and the pills into the URL. Reads `location.search` fresh
  // on every call rather than a captured copy — another synced widget on the
  // page may have written between two of these — and writes through `commit`,
  // which is `history.replaceState` under the hood so Back keeps leaving the
  // page.
  const persist = () => {
    if (!syncing) return;
    const values = new Map([
      ["status", facets.status],
      ["type", facets.type],
    ]);
    tq.commit(tq.writeSync(syncKey, { q: input.value, values }, location.search));
  };
  const persistSoon = syncing ? tq.debounce(persist) : () => {};

  input.addEventListener("input", apply, { signal });
  input.addEventListener("input", persistSoon, { signal });
  input.addEventListener("keydown", (ev) => {
    // Escape clears the query and restores the original order.
    if (ev.key === "Escape") {
      input.value = "";
      apply();
      persist();
    }
  }, { signal });

  for (const pill of pills) {
    pill.addEventListener("click", () => {
      const facet = pill.getAttribute("data-todo-facet");
      const value = pill.getAttribute("data-todo-value");
      const set = facets[facet];
      if (!set) return;
      if (set.has(value)) {
        set.delete(value);
        pill.setAttribute("aria-pressed", "false");
      } else {
        set.add(value);
        pill.setAttribute("aria-pressed", "true");
      }
      apply();
      persist();
    }, { signal });
  }

  // Rehydrates from the URL before the ready flag flips, so the first paint a
  // reader sees already reflects the link they followed. A value naming no
  // pill on THIS page (a stale link to a type that no longer appears) is
  // silently dropped rather than filtering every row away with nothing left
  // to press.
  if (syncing) {
    const st = tq.readSync(syncKey, location.search);
    let restored = false;
    if (st.q) {
      input.value = st.q;
      restored = true;
    }
    for (const facet of ["status", "type"]) {
      for (const v of st.values.get(facet) ?? []) {
        const pill = pills.find(
          (p) =>
            p.getAttribute("data-todo-facet") === facet &&
            p.getAttribute("data-todo-value") === v,
        );
        if (!pill) continue;
        facets[facet].add(v);
        pill.setAttribute("aria-pressed", "true");
        restored = true;
      }
    }
    // `apply()` runs only when something was restored: `wire` otherwise never
    // calls it, and the rows stay in the build-time priority order Typst
    // sorted them into until someone types or presses a pill.
    if (restored) apply();
  }

  container.setAttribute("data-todo-search-ready", "true");
}

function init() {
  for (const c of document.querySelectorAll(".todo-search")) wire(c);
}

if (typeof document !== "undefined") {
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }

  // REHYDRATE AFTER A rheo MORPH. The dev server patches a content edit into
  // the live DOM instead of reloading (`docs/contract.md`), which re-runs no
  // script — and the markup it patches in is the PRE-HYDRATION build output, so
  // `.todo-search` comes back with no `data-todo-search-ready`, an empty input,
  // released pills and every row unhidden while the URL still names the filter
  // that is no longer applied. `js_rehydrate = true` in `typst.toml` is the
  // other half of the declaration: without it rheo reloads the page and never
  // calls this.
  //
  // RE-RUNNING `init()` IS SAFE because `wire` aborts its own previous pass
  // before adding a single listener — `@rheo/rehydrate`'s `wiring`, keyed on
  // the container, the same helper `@rookery/search`'s `panel.js` uses.
  //
  // AND IT HAS NO ORDERING DEPENDENCY ON `@rookery/search`'s OWN HOOK, which is
  // the whole reason `wire` passes its container to `tq.claimKey` rather than
  // this hook clearing the shared registry first. Hooks run in registration
  // order, fixed at page load by which package's `<script>` executed first,
  // which follows a consuming project's import order — nothing either package
  // can see, let alone force. A claim refused on its holder's LIVENESS needs no
  // such agreement: whichever hook runs first, each widget re-claims its own
  // key on the way past.
  //
  // `globalThis`, not `window`, matching how this file already reaches
  // `RookerySearch`: the node suite supplies a document and no `window`, and
  // reading one at module-evaluation time would throw there.
  (globalThis.__rheoRehydrate ??= []).push(init);
}
