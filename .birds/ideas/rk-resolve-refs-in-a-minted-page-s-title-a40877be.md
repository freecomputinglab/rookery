---
id: rk-resolve-refs-in-a-minted-page-s-title-a40877be
short-id: a4
title: Resolve refs in a minted page's title
priority: 3
labels:
- type:bug
- fix-title-refs
deps: []
closed: true
---
A note whose TITLE contains a reference is named wrongly on its own minted page:
the reference renders as a bare number instead of the target's name, and the
page's `<title>` loses it entirely. Both halves are in
`core/0.1.0/.marrow.typ`, the file that mints those
pages.

## The symptom, measured in a consuming site

`@rookery/meetings` synthesizes a title for an untitled meeting —
`meetings/0.1.0/src/lib.typ:212-214` builds `[Meeting with #_refs(who) on
#stamp]`, where `_refs` (line 80) is `who.map(n => ref(label("idea:" + n)))`.
On the minted page of such a meeting in a real rheo site, the `<h1>` comes out
as:

```html
<span class="idea-title" data-rookery="title">Meeting with <a href="../nest/people.html#loc-17">386</a></span>
```

and the browser tab reads `Meeting with ` with the name missing. The record
block a few lines lower down the SAME page resolves correctly, which is what
makes this a rendering-scope bug rather than a broken registry:

```html
<dl class="meeting-fields"><dt>With</dt><dd><span class="idea-ref" data-rookery="ref"><a href="../ideas/doshi-velez-finale.html">Finale Doshi-Velez</a></span></dd></dl>
```

`386` is Typst's own numbering for the note's anchor `figure` (kind
`rheo-idea-anchor`), and `#loc-17` is that figure's location — i.e. what a
`ref` renders as when NO `show ref:` rule is in scope to intercept it.

## Why the package fixtures do not catch it — do not go looking for a fixture bug

This does not reproduce in `meetings/0.1.0/test/view.typ`. That fixture renders
its notes INLINE on one vertebra, under `#show: rookery`, and there the same
title is correct — verified by running `cd
meetings/0.1.0 && just test` and reading
`test/build/view.html`:

```html
<span class="idea-title" data-rookery="title">Meeting with <span class="idea-ref" data-rookery="ref"><a href="#loc-1">Finale Doshi-Velez</a></span> on 10.9.26</span>
```

`meetings/0.1.0/test/units.typ:31-35` likewise asserts the plain-text label is
`"Meeting with Finale Doshi-Velez on 10.9.26"` and passes. The package is
fine. Only a MINTED page is wrong, and no fixture in this repo currently mints
a page whose title holds a reference — step 3 below is what adds one.

The reason is stated in this repo's own comment, at
`core/0.1.0/src/template.typ:267-269`:

> A minted note page never calls `rookery()` again — it applies the project's
> `idea-page-template` — so it publishes no beacon

`show ref: hyperlink` is installed by `rookery()` and nowhere else
(`core/0.1.0/src/template.typ:284-289`, inside `if refs {`). So on a minted page
that rule is simply absent. A note's BODY still resolves its references because
`_flatten` installs a rule of its own (`core/0.1.0/src/transclusion.typ:331`).
A note's TITLE is rendered outside any such scope, and falls through to Typst.

## The two defects, exactly located

Both in `core/0.1.0/.marrow.typ`:

1. **Lines 296-297 — the `<h1>`.**

   ```typ
   (if rec.title == none { [] } else {
     html.elem("span", attrs: (class: _c("title"), data-rookery: "title"), rec.title)
   }),
   ```

   `rec.title` is the authored (or factory-derived) title CONTENT, refs and all,
   rendered with no `show ref:` rule around it.

2. **Lines 538-541 — the browser tab**, inside the `rheo-document(..)` call that
   begins at line 528:

   ```typ
   title: {
     let l = rec.at("label", default: none)
     if l == none { slug } else { l }
   },
   ```

   `rec.label` is the note's REGISTRATION-TIME label, and that string is computed
   with the pure projection `_plain` — `core/0.1.0/src/pure.typ:350`, whose
   resolver is `_ => ""`. A reference therefore contributes the empty string,
   which is the `Meeting with ` above.

   The resolving form already exists and is used in four other places:
   `_rec-label(rec, _ref-text(reg))`, defined at `core/0.1.0/src/pure.typ:414`
   and `:376`, called from `core/0.1.0/src/data.typ:304-305` (`ideas()`),
   `core/0.1.0/src/hyperlink.typ:103`, `core/0.1.0/src/transclusion.typ:154` and
   `core/0.1.0/src/permalink.typ:203`. `_ref-text`'s own banner
   (`pure.typ:352-358`) documents this exact case: "what a `ref` inside a title
   is worth in plain text is the NAME OF THE NOTE it points at".

## Decisions already made — do not re-derive these

- **Use the plain `hyperlink`, NOT `hyperlink.with(link-to: "anchor")`.** Anchor
  mode exists for a reference rendered on the vertebra that authored the target,
  where the anchor is on the same page. A minted page is a page of its own, so
  the target's own minted page is the right destination — which is what
  `link-to: "page"`, `hyperlink`'s default, gives.

- **Install it unconditionally, and accept one known limitation.** `rookery()`
  gates the rule on its `refs:` parameter and picks anchor-vs-page from
  `ref-target:`, but NEITHER is stored in state: `core/0.1.0/src/state.typ` holds
  `_show-title` (line 245), `_show-context` (227) and `_page-titles` (266) and
  has no entry for refs at all, so `.marrow.typ` cannot read them. A project
  building with `refs: false` will therefore still get a resolved link in a
  minted page's `<h1>`. That is deliberate and better than the status quo — a
  raw figure counter is wrong under every setting — and plumbing `refs:` through
  state is a separate change nobody has asked for. Say so in a comment rather
  than adding the state.

- **The `<title>` keeps using the LABEL, not the authored title.** The reasoning
  at `.marrow.typ:532-537` ("a LABEL rather than the authored title: this is
  never rendered beside the note's body") stands and is not in question. Only
  how that label is RESOLVED changes.

- **Do not touch `core/0.1.0/src/idea.typ:401`.** That is the inline heading, a
  separate copy of the same span, and it is already correct because it renders
  inside `rookery()`'s scope. Verified against the meetings fixture above.

## Steps

Every path below is relative to the repository root. The only source file that changes is
`core/0.1.0/.marrow.typ`.

1. **Add the three names to the import list.** `.marrow.typ:92` is one long
   `#import "@rookery/core:0.1.0": ...` line, currently ending `..., _plain,
   _visible-tags, _tags-attr, window`. Add `hyperlink`, `_ref-text` and
   `_rec-label` to it.

   These are reachable: `_plain` is already imported there and is defined in
   `src/pure.typ` alongside `_ref-text` and `_rec-label`, and `hyperlink` is
   re-exported by `src/lib.typ:47`. If an import nonetheless fails to resolve,
   the compile says `unknown variable` with the name — report that rather than
   reaching into `src/` to re-export something.

2. **Fix the `<h1>` at lines 296-297.** Wrap the title content so the reference
   rule is in scope while it renders. A `show` rule applies to the rest of its
   own scope, so it has to go inside a block that then yields the content, e.g.:

   ```typ
   (if rec.title == none { [] } else {
     html.elem("span", attrs: (class: _c("title"), data-rookery: "title"), {
       show ref: hyperlink
       rec.title
     })
   }),
   ```

   Add two or three comment lines above it, in this file's register — present
   tense, declarative, saying WHY: a minted page never calls `rookery()`
   (`src/template.typ:267-269`), so the document-wide `show ref: hyperlink` that
   a vertebra installs is absent here, and without this the reference renders as
   its anchor figure's counter. Mention the `refs: false` limitation from the
   decisions above in that same comment.

3. **Fix the `<title>` at lines 538-541.** Resolve the label with the registry
   rather than reading the stored one:

   ```typ
   title: {
     let reg = _registry.final()
     let l = _rec-label(rec, _ref-text(reg))
     if l == none or l == "" { slug } else { l }
   },
   ```

   `_registry` is already imported at line 92. Keep `slug` as the fallback, and
   keep the existing comment at lines 532-537 intact — extend it with one
   sentence saying the label is resolved through `_ref-text` so a title holding a
   reference names the note it points at, rather than dropping it.

   Note the fallback condition gained `or l == ""`: `_rec-label` returns its
   `fallback:` (defaulting to `none`) only when the title AND the label are both
   empty, so an empty string is reachable and `slug` is the honest answer for it.

4. **Add the fixture case that would have caught this.** In
   `core/0.1.0/demo/rheo/content/refs.typ` — the
   vertebra headed `= Citation positions and derived labels`, which already owns
   the derived-label cases under its `== Derived labels` section — add, after the
   `#idea("dt-empty")[]` line:

   ```typ
   // A TITLE HOLDING A REFERENCE, which only a MINTED page renders wrongly: this
   // vertebra is inside `#show: rookery` and so has the ref rule, where
   // `.marrow.typ` mints `ideas/ref-titled.html` without it. Named `cited-note`,
   // defined above on this same page, so the target's title is a fixed string.
   #idea("ref-titled", title: [About #ref(label("idea:cited-note"))])[
     A note whose title names another note.
   ]
   ```

   `cited-note` is defined at line 13 of that same file with `title: [Cited
   note]`, so the resolved name is exactly `Cited note`.

5. **Assert it in the demo's check script.** In
   `core/0.1.0/demo/rheo/check.sh`, add a block in
   the style of the ones already there (they use `$H` for the built HTML root and
   a `note "..."` helper for a failure):

   ```sh
   # A TITLE HOLDING A REFERENCE, on the minted page that renders it. A minted
   # page never calls `rookery()`, so the `show ref:` rule has to be installed
   # where the title span is built — without it the reference renders as its
   # anchor figure's counter, a bare number, and the page's <title> loses the
   # name altogether.
   R="$H/ideas/ref-titled.html"
   grep -q 'class="idea-title"[^>]*>About <span class="idea-ref"' "$R" ||
     note "ref-titled.html's <h1> does not render its title's reference through the ref rule"
   grep -q '>Cited note<' "$R" ||
     note "ref-titled.html's <h1> does not name the note its title references"
   grep -q '<title>About Cited note</title>' "$R" ||
     note "ref-titled.html's <title> does not resolve its title's reference"
   ```

   If the exact attribute order in the built markup differs from the first
   pattern, loosen that grep to the two facts that matter — the `idea-ref` span
   is present inside the title span, and `Cited note` appears — rather than
   deleting the assertion.

## Do NOT

- Do NOT edit `core/0.1.0/src/idea.typ`, `src/pure.typ`, `src/hyperlink.typ`,
  `src/transclusion.typ` or `src/template.typ`. The fix is in `.marrow.typ` and
  the demo fixture only.
- Do NOT add `refs` or `ref-target` to `core/0.1.0/src/state.typ`, and do not add
  a parameter to `rookery()`. See the decisions above.
- Do NOT change what the `<title>` is derived FROM (the label, not the authored
  title) — only how it is resolved.
- Do NOT edit anything under `meetings/0.1.0`. The package that revealed this is
  correct; its title synthesis is not the bug.
- Do NOT touch any other package in this repo, and do not touch any consuming
  site outside it.
- Do NOT run `just clean` at the repo root, and do not commit anything under a
  `build/` or `dist/` directory — both are build output and gitignored.

## VERIFY

1. The demo's own check, which cleans, rebuilds and asserts — this is the one
   that proves the fix:

   ```sh
   cd core/0.1.0/demo/rheo && just check
   ```

   It must exit 0. `just check` runs `clean`, then `rheo compile .`, then
   `./check.sh`. If `rheo` is not on PATH, say so and stop — that recipe's own
   header explains rheo is not in this repo's devShell.

2. Read the built page directly and confirm both halves by eye:

   ```sh
   cd core/0.1.0/demo/rheo
   grep -o '<title>[^<]*</title>' build/html/ideas/ref-titled.html
   grep -o '<span class="idea-title"[^>]*>.\{0,160\}' build/html/ideas/ref-titled.html
   ```

   The first must print `<title>About Cited note</title>`. The second must
   contain `Cited note` inside an `idea-ref` span, and must NOT contain a bare
   number where the name belongs.

3. Core's own unit fixtures still pass:

   ```sh
   cd core/0.1.0 && just test
   ```

4. The package that revealed the bug is unaffected:

   ```sh
   cd meetings/0.1.0 && just test
   ```

   Both must exit 0 and print their `OK` lines.