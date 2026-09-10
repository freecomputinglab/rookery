---
id: rk-document-url-state-in-search-s-readme-ccdf3b37
short-id: cc
title: Document URL state in search's readme
priority: 2
labels:
- type:task
- docs-url-state
deps:
- blocked-by:rk-sync-panel-query-and-pills-to-the-url-386ad1b3
- blocked-by:rk-take-sync-on-filter-panel-6b93790a
- blocked-by:rk-sync-a-radio-group-named-by-data-cb8c8c12
closed: true
---
Document URL state in `@rookery/search`'s readme: the `sync:` key on `#panel` and
`#filter-panel`, the `data-rookery-url-radio` hook, the parameter shape, and the
rules a consuming site has to know. Documentation only — no code changes at all.

## Why this is a bird of its own

`/home/lox/code/_fcl/rookery/search/0.1.0/readme.md` is 1571 lines and is this
package's ONLY API documentation — there is no docs site
(`/home/lox/code/_fcl/rookery/CLAUDE.md` describes the layout; every package
documents itself in its own readme). Three separate birds added the feature it now
has to describe, and if each had written its own readme section they would have
conflicted on landing in one file. So the code birds deliberately left the readme
alone and this one writes it in a single pass.

## What is already in the tree, and must be described exactly as it is

Read the implementation before writing a word of this — the readme has to match it,
not the plan:

- `/home/lox/code/_fcl/rookery/search/0.1.0/src/urlstate.js` — `readSync`,
  `writeSync`, `readParam`, `writeParam`, `commit`, `claimKey`, `debounce`, all
  published on `globalThis.RookerySearch` by `src/search.js`.
- `/home/lox/code/_fcl/rookery/search/0.1.0/src/urlsync.js` — `initUrlSync`,
  `wireRadioGroup`, auto-run from `init()` in `src/search.js`.
- `/home/lox/code/_fcl/rookery/search/0.1.0/src/panel.typ` — `sync:` on `#panel`
  and on the private `_panel-shell`, plus the `_sync-key` validator.
- `/home/lox/code/_fcl/rookery/search/0.1.0/src/filter-panel.typ` — `sync:` on
  `#filter-panel`.
- `/home/lox/code/_fcl/rookery/search/0.1.0/src/panel.js` — the rehydrate and
  persist paths inside `wirePanel`.

## Steps

1. Add a top-level section to
   `/home/lox/code/_fcl/rookery/search/0.1.0/readme.md`, titled along the lines of
   `## Keeping filter state in the URL: `sync:``. Place it after
   `### The row is not this package's` (line 1509, the last subsection of the
   `#filter-panel` chapter) and before `## Working on it locally` (line 1517): it
   describes both widgets, so it belongs after both chapters and before the
   contributor-facing tail.

2. Cover, in this readme's register — prose-first, worked examples, an honest
   statement of the limits, which is how every other chapter there reads:

   - **What problem it solves.** A page reload — a `rheo watch` rebuild, a browser
     refresh, a link shared with someone else — starts every panel from a clean
     slate: empty box, no pill pressed. `sync:` puts that state in the query string
     so it survives, and makes a filtered view a copyable link.
   - **The opt-in.** `sync:` defaults to `none` and a widget without it emits no
     attribute and reads no parameter. Nothing changes for a site that does not ask.
   - **The parameter shape**, with a real example URL:
     `?todos.q=rheo&todos.state=ready&todos.state=blocked&ideas.t=cfp`. `<key>.q` is
     the text box; `<key>.<field>` is one facet group, repeated once per pressed
     value; `<key>.t` is `#filter-panel`'s tag-pill set.
   - **Why repeated parameters and not a comma-joined list.** `_attr` permits any
     scalar as a facet value and only `_multi-attr` forbids whitespace, so a value
     containing a comma is legal and a joined parameter would corrupt it with no
     escaping rule to fall back on. This is the kind of "and here is the honest
     consequence" note the rest of this readme is full of — write it that way.
   - **`q` and `t` are reserved** inside a key's namespace, and `#panel` panics at
     build time if a synced panel's `facets:` names either. Quote the assert's
     wording so a reader can search for it.
   - **The key's charset**, `^[a-z0-9-]+$`, and why: a key carrying `.`, `&` or `=`
     would break out of its own namespace.
   - **One key per page.** A second widget claiming a key does not sync and emits a
     `console.warn`. Typst cannot see across two calls to assert it, which is why
     the check is in the browser — say so.
   - **`history.replaceState`, not `pushState`.** Back leaves the page as it always
     did; a filter change is not a navigation. Typing is debounced, a pill press
     writes at once.
   - **Parameters merge.** Only this key's parameters are rewritten; a second
     panel's, a tab's, and anything a site put there survive.
   - **A stale value is ignored.** A parameter naming a pill that no longer exists
     presses nothing rather than filtering the list to nothing.
   - **Without JavaScript**, `sync:` does nothing at all and the panel is the
     complete readable list it always was. There is an existing
     `### Without JavaScript` subsection at line 1317 to be consistent with — match
     its claim, do not contradict it.
   - **`data-rookery-url-radio`**, in a subsection of its own. What it is: put the
     attribute on any element containing a radio group, give each radio a `value`,
     and the group's selection lives in the bare `?<key>=` parameter. Why it
     exists: a CSS-only tab strip in a consuming site can then keep its active pane
     across a reload with no script of that site's own. The trap worth documenting:
     a radio with NO `value` attribute reports `.value === "on"`, so a group whose
     radios carry no values syncs nothing rather than writing `?tab=on` three times.
     Include the markup example.
   - **The public JS surface**, briefly: `readSync`, `writeSync`, `readParam`,
     `writeParam`, `commit`, `claimKey`, `debounce` on `globalThis.RookerySearch`,
     for a site building its own widget on the same rule. There is a precedent
     subsection for exactly this framing at line 440,
     `### Building your own UI on the same rule` — point at it or mirror it.

3. Update the one existing place that would now be wrong or incomplete: the
   `## `#panel` — a faceted filter over a projection` chapter (line 1139) and the
   `## `#filter-panel` — the same chrome, over tags` chapter (line 1337) each list
   their arguments. Add `sync:` to those lists with a one-line gloss and a pointer
   to the new section — do not duplicate the whole explanation twice.

## Do NOT

- Do NOT change any `.js`, `.typ`, `.css` or `.toml` file. If the readme cannot be
  written truthfully without a code change, stop and say so rather than making one.
- Do NOT touch `todos/0.1.0/readme.md` — that package documents its own half in a
  separate bird.
- Do NOT document `#window` fold state, scroll-position syncing or a
  `sessionStorage` fallback. None of those exist; the first two were considered and
  ruled out.
- Do NOT write a changelog entry, a migration note, or a "what changed" passage.
  `CLAUDE.md`'s comment-style section states the rule and it holds for prose here
  too: describe the present, not how it got that way. The existing
  `### What it replaced` at line 1324 is about a superseded widget, not a diff log —
  do not take it as licence for one.
- Do NOT invent a version number or a release note.

## VERIFY

```sh
cd /home/lox/code/_fcl/rookery/search/0.1.0
grep -n '^#\{1,3\} ' readme.md
```

The new section must appear between `### The row is not this package's` and
`## Working on it locally`, at the right heading depth for its position.

Then check every claim against the code rather than against this bird's summary of
it. Concretely, each of these must be true of the files as they stand:

```sh
grep -n 'sync' src/panel.typ src/filter-panel.typ | head -40
grep -n 'export const' src/urlstate.js src/urlsync.js
grep -n 'panelSync\|claimKey\|writeSync\|readSync' src/panel.js
```

Every parameter name, attribute name and function name in the readme must be
spelled the way those outputs spell it. Finally:

```sh
just test
```

must still pass — nothing here should touch it, and a failure means a code file was
edited by accident.