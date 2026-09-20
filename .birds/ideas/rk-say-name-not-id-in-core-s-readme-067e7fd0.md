---
id: rk-say-name-not-id-in-core-s-readme-067e7fd0
short-id: '06'
title: Say name not id in core's readme
priority: 1
labels:
- fix-idea-name-terminology
deps:
- blocked-by:rk-rename-ideate-id-to-ideate-name-7aed87f3
- blocked-by:rk-rename-display-id-to-display-name-0e403847
- blocked-by:rk-rename-id-color-to-name-color-81555eef
closed: false
---
Touches: core/0.1.0/readme.md

## Why

`@rookery/core` is settling on one word for the thing that names a note:
**name**. The author-facing API already says it — `#idea("etal")` takes a name
(its own panic reads `#idea takes an optional name and an optional body`),
`#ideate(name: ..)` is spelled `name:`, `#idea-href(name)`,
`#idea-path(name)` and `#idea-body(name)` all take a name, and `ideas()` rows
carry a `name` field.

Three sibling birds rename the last identifiers that said *id* instead:
`#ideate-id` becomes `#ideate-name`, `display-id:` / `display: (id: ..)`
become `display-name:` / `display: (name: ..)`, and the theme key `id-color`
with its custom property `--idea-id-color` become `name-color` and
`--idea-name-color`. Those birds rename the identifiers and touch only the
readme lines that cite them.

This bird finishes the job in prose. `core/0.1.0/readme.md` is the package's
whole documentation, and it explains the concept as an *id* throughout — two
section headings among them. A reader who meets `#idea("etal")`, described as
taking an id, in a readme whose parameter is called `name:`, is being taught
that there are two things.

**This bird flies last, after the three rename birds have landed.** It is
declared `blocked-by` all three, so `bd` will not hand it out early. The reason
is not just tidiness: each of those birds edits the same readme, and a prose
sweep racing them conflicts on landing.

## Scope, measured before filing

```
rg -c '\bids?\b' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
```

118 matching lines at the time of filing, before the three rename birds land.
Expect fewer by the time this flies — those birds will have converted the
lines that cite a renamed identifier. A materially different count is the
earlier birds having done more or less than expected, not a broken bird.

## Steps

1. Rename the two section headings that name the concept. Anchors:

   ```
   rg -n '^## Flat ids' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   rg -n '^## Unnamed notes' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   One hit each — line 1038, `## Flat ids, and why`, and line 1047,
   `## Unnamed notes: where their ids come from`. They become
   `## Flat names, and why` and `## Unnamed notes: where their names come
   from`.

   **Check for an in-document link to either heading before renaming**, since
   a Markdown anchor is derived from the heading text:

   ```
   rg -n '#flat-ids|#unnamed-notes' /home/lox/code/_fcl/rookery/core/0.1.0
   ```

   If that prints hits, update them to the new anchors in the same step. If it
   prints nothing, there are no internal links to fix.

2. Sweep the body prose. Work through every hit of:

   ```
   rg -n '\bids?\b' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   Read each line and decide by what the word refers to:

   - **The thing that names a note** — rewrite as *name*. "an id is a Typst
     label" becomes "a name is a Typst label"; "those ids are generated rather
     than authored" becomes "those names are generated rather than authored";
     "the full id, prefix included" becomes "the full name, prefix included".
   - **A code identifier that still contains `id`** — leave it exactly as it
     is, inside its backticks. After the three sibling birds land, the
     survivors are: the `.id` field on `ideas()` rows, the `id:` parameter of
     `idea-page-template`, and the `id` attribute of any HTML element the
     package emits. See NON-GOALS.
   - **Something else entirely** — leave it. Words like "idea", "provide",
     "consider" are not hits of `\bids?\b`, but a line about, say, an HTML
     `id` attribute is, and it is not about a note's name.

3. Reconcile the two places that would now read oddly. Anchors:

   ```
   rg -n 'the full id, prefix included' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   rg -n 'the id with the prefix stripped' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   These sit in the `ideas()` row shape, around line 194, where the dictionary
   is spelled out as `(id: "idea:etal", name: "etal", ..)`. The **field names**
   `id` and `name` do not change in this bird — only the prose describing them.
   Write the pair so the distinction is legible without the word *id* doing
   conceptual work:

   - `id:` — the note's full name, prefix included (`"idea:etal"`)
   - `name:` — the same name with the prefix stripped (`"etal"`)

   Say plainly in that passage that the two fields are the same name in two
   forms, and that the field is still called `id` for the prefixed form. This
   is the one place the readme has to acknowledge the remaining mismatch, so
   do it once, here, rather than apologising for it at every mention.

4. Read the two renamed sections end to end afterwards
   (`## Flat names, and why` and `## Unnamed notes: where their names come
   from`) and check the prose still parses as English. A mechanical
   substitution produces phrases like "a name namespace" or "the name is a
   pure function of its call site, and names are flat" that are correct but
   clumsy; rewrite those sentences rather than leaving the substitution
   showing.

## NON-GOALS

- **Do not rename any code identifier.** Not `.id` on `ideas()` rows, not
  `idea-page-template(id: ..)`, not an HTML `id` attribute. Those are separate
  decisions with their own birds, and this bird must produce a readme-only
  change.
- **Do not touch anything under `src/`.** The package's source comments and its
  local `id` bindings — `_permalink(id, ..)`, `let id = ..` and friends — are
  deliberately out of scope. Those bindings mostly hold the *prefixed* form,
  which is still the `.id` field, so renaming them is churn that would have to
  be redone once the field decision lands. A follow-up bird covers them.
- **Do not touch any package other than `core`.**
- **Do not restructure the readme** — no new sections, no reordering, no
  moving material between sections. This is a wording pass over prose that
  exists.
- Do not touch `/home/lox/code/_fcl/rookery.ohrg.org`; that site has its own
  tracker and its own bird for this.

## VERIFY

1. Both headings are renamed. This must print two hits:

   ```
   rg -n '^## Flat names, and why|^## Unnamed notes: where their names come from' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

2. The old headings are gone. This must print nothing:

   ```
   rg -n '^## Flat ids|where their ids come from' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

3. Every surviving `\bids?\b` in the readme is a code identifier, not prose
   about a note's name. List them and read each one:

   ```
   rg -n '\bids?\b' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   State the surviving count in the flight report and confirm each is one of:
   the `.id` field, `idea-page-template(id: ..)`, or an HTML `id` attribute. A
   hit that is none of those is a line the sweep missed.

4. The `ideas()` row passage explains the two forms. This must print at least
   one hit:

   ```
   rg -n 'prefix included' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   Read the surrounding paragraph and confirm it says the field is called `id`
   while the thing it holds is the note's full name.

5. Nothing outside the readme changed. The package's tests must still pass
   unchanged — from `/home/lox/code/_fcl/rookery/core/0.1.0`:

   ```
   just test
   ```

   If that recipe does not exist, run what the package's `Justfile` does
   define for tests — read it with `rg -n '^[a-z-]+:' Justfile` — and report
   which recipe you ran.