---
id: rk-ideate-tags-via-metadata-beacon-8c4920a3
short-id: 8c
title: Ideate tags via metadata beacon
priority: 3
labels:
- feat-ideate-tag-beacon
deps: []
closed: false
---
# Replace `#ideate`'s `<tag:x>` label with a metadata beacon

## Why

`#ideate` (`core/0.1.0/src/ideate.typ`) currently lets one separating heading
add exactly ONE extra tag to its own section, via a `<tag:x>` Typst label on
that heading (`_label-tag`, `core/0.1.0/src/pure.typ:766-780`; used at
`ideate.typ:441-442`). This is a hard ceiling, not a design choice worth
keeping: a Typst content element carries at most one label (documented at
`core/0.1.0/readme.md:727`), so the mechanism can never grow past one tag,
can never carry a VALUED tag (a label has no value slot, only a name), and
only works when `separator: heading.where(level: n)` — a `separator: par` or
`separator: none` section has no separating heading to label at all.

Replace it with an inline `#metadata(..)` beacon, the same idiom `#footnote`
already uses in this package (`idea.typ:580`,
`[#metadata((rookery-fn: body))<rkfn>]`, detected in `pure.typ:541-542`,
`links.typ:81`, and `bib.typ:74` by checking
`c.func() == metadata and type(c.value) == dictionary and "rookery-fn" in c.value`
— NOT by reading a label). A metadata payload is an arbitrary
dictionary/array, so it has no cardinality ceiling and no value restriction,
and it is an ordinary content node that can sit inside a paragraph's own run
of children just as easily as beside a heading — so it works in EVERY
`separator:` mode, not only heading mode.

## Design (resolved — implement exactly this, do not re-derive)

1. **New exported function**, in `core/0.1.0/src/pure.typ`, right after
   `slug` (currently defined at the file's end, ~line 762-764):

   ```typst
   #let ideate-tag(tags) = [#metadata((rookery-ideate-tags: tags))]
   ```

   `tags` takes exactly what `#idea`'s own `tags:` argument already accepts —
   `none`, a string, an array of strings, or a dictionary (see
   `_assert-tags`/`_norm-tags`, already in this file, used by `#idea` itself
   at `idea.typ:55-56`). Do NOT write a new normalization function — call
   `_norm-tags(tags)` on the payload wherever it is read back, exactly as
   `ideate.typ:297` already does for the call's own `tags:` argument. No
   Typst label on this element at all — unlike `#footnote`'s `<rkfn>`,
   nothing here needs to intercept it via a `show` rule (it only needs to be
   found by walking content), so a label would be dead weight.

   Export it from `core/0.1.0/src/lib.typ` the same way `slug` is exported —
   grep that file for `slug` to find the existing export line/list and add
   `ideate-tag` beside it.

2. **Detection, in `core/0.1.0/src/ideate.typ`**: add a small helper near
   where `_label-tag` is currently used (which this bird deletes — see step
   4):

   ```typst
   #let _ideate-tag-value(c) = {
     if c.func() != metadata { return none }
     if type(c.value) != dictionary { return none }
     if "rookery-ideate-tags" not in c.value { return none }
     c.value.rookery-ideate-tags
   }
   ```

   In the per-group emit loop (`ideate.typ:420-494`, the `for group in
   groups` block), for the ELSE branch only (the branch that actually mints
   a note — never the `_no-content`/`_heading-only` branches above it), scan
   `group` for every child where `_ideate-tag-value(child) != none`. Union
   their values in document order with `_norm-tags`, right-biased on key
   conflict (a later beacon's key wins over an earlier one — the same
   direction `base-tags + ((tag): none)` already uses today):

   ```typst
   let beacon-tags = group.fold((:), (acc, c) => {
     let v = _ideate-tag-value(c)
     if v == none { acc } else { acc + _norm-tags(v) }
   })
   let group-tags = base-tags + beacon-tags
   ```

   This REPLACES the existing `tag`/`group-tags` computation at
   `ideate.typ:441-442` (the `_label-tag(lead-heading.at("label", ...))`
   line and its surrounding comment) — delete that logic; this is its full
   replacement, and it is no longer conditional on `heading-mode`/
   `lead-heading` at all: it runs for every group regardless of `separator:`.

3. **Strip the beacon from the minted body.** Wherever `rest`/`group.join()`
   is built for the mint call (`ideate.typ:448` and `:450`), filter out every
   child for which `_ideate-tag-value(child) != none` before joining —
   mirroring how the lead heading is already excluded via
   `group.slice(0, lead-i) + group.slice(lead-i + 1)`. A beacon renders
   nothing either way (metadata is invisible), but leaving it in the stored
   raw body is not "written as the author wrote it" — the heading-strip
   precedent is to remove apparatus, not content, and this beacon is
   apparatus.

4. **Delete the old mechanism entirely** (this is a replacement, not an
   addition):
   - `core/0.1.0/src/pure.typ` — delete `_label-tag` (~14 lines, immediately
     after `slug`, at the file's end).
   - `core/0.1.0/src/ideate.typ:437-442` — delete the `tag`/
     `lead-heading.at("label", ...)` block and its comment.
   - `core/0.1.0/test/units.typ:23` — remove `_label-tag` from the
     `#import "/src/lib.typ": (...)` list.
   - `core/0.1.0/test/units.typ:609-623` — delete the whole `_label-tag`
     test block (the `---- _label-tag ----` header through the last
     `#assert.eq(_label-tag(<tag:a:b>), "a:b")`).
   - Add an equivalent unit-test block for `_ideate-tag-value` in its place
     (same file), covering: a `#ideate-tag("rookery")`'s metadata detected
     and its value returned; a plain unrelated `#metadata((other: 1))`
     returns `none`; non-metadata content (e.g. `[text]`) returns `none`.
     This predicate takes content, not a label — do not call it with `none`
     (unlike `_label-tag`, which took a label-or-none).

## Placement constraint the beacon has (state this in the readme too)

A beacon only counts if it is a DIRECT child of the section's content — the
same flat-sequence model this file's own header comment already documents
(facts 1-5, `ideate.typ:81-114`). Concretely:
- Under `separator: heading.where(level: n)`, place `#ideate-tag(..)`
  anywhere inside the section's own body (after the heading, before the next
  one) — NOT nested inside `#strong[..]`, `#emph[..]`, a table cell, or a
  list item's own content, all of which put it inside THAT element's body
  rather than the flat sequence `#ideate` walks.
- Under `separator: par` (or the default), place it INLINE within the
  paragraph it should tag — i.e. with no blank line (no `parbreak()`)
  between it and that paragraph's own text. A `#ideate-tag(..)` written on
  its own line, surrounded by blank lines, becomes its OWN group (bounded by
  parbreaks on both sides) and is silently classified as a no-content group
  (all-blank/inert) — passed through unminted, not attached to any note.
- Under `separator: none` there is only one group, so placement anywhere in
  the body reaches it.

## Non-goals

- Do NOT change how `tags:` (the call-level argument) works — only the
  per-section extra-tag mechanism.
- Do NOT add a `show` rule or a label for the beacon — detection is by
  walking content and checking the metadata dictionary key, never by label,
  matching `_footnotes`'s own mechanism exactly.
- Do NOT touch `_norm-tags`, `_assert-tags`, or any other tag-normalization
  helper — reuse them as-is.
- Do NOT change `core/0.1.0/demo/rheo/content/ideated-named.typ` — its
  `<tag:waterline>` label is unrelated (it feeds the `name:` function's
  `labels` array parameter, not tag application), and is out of scope here.

## Update the readme, `core/0.1.0/readme.md`

`readme.md:704-736` ("### Tagging one section from its own heading")
describes the old `<tag:x>` mechanism, including the exact prose "one Typst
element carries at most one label — a heading cannot carry two" (line 727).
Rewrite this section for the beacon: rename it to "### Tagging a section
with `#ideate-tag`", document `#ideate-tag(tags)` (the same four accepted
shapes `#idea`'s own `tags:` takes), show it working under `separator: par`
(a plain-paragraph example, not just heading mode — this is the actual
improvement over the old mechanism), state the placement constraint above,
and drop the "only one tag" limitation entirely since a dictionary/array
payload has no such ceiling.

## Update the demo fixture

`core/0.1.0/demo/rheo/content/ideated.typ:34-40` (the fourth section,
`== Rookery <tag:rookery>`) currently tags itself via the label. Change it to
use the beacon instead: import `ideate-tag` alongside `ideate` at line 2, and
replace the `<tag:rookery>` label with an inline `#ideate-tag("rookery")`
call placed in the section's own body (NOT on the heading — headings no
longer carry the tag under this mechanism). Keep the section immediately
above it (`== Testing edge cases <sec:one>`, lines 27-32) UNCHANGED as a
Typst section — it exists partly to prove the ids don't collide, which is
unrelated to tagging; only its comment (lines 29-32), which currently frames
`<sec:one>` as "a label without the `tag:` prefix is left alone," may need a
one-line rewording if it no longer reads accurately once labels stop being
read for tags at all — do not delete the section.

`core/0.1.0/demo/rheo/check.sh:586-605` (check 24, "TAG FROM A HEADING
LABEL") checks `idea-tag-rookery` on `ideas/rookery.html` and that
`literate-programming.html`/`testing-edge-cases.html` carry no stray tag
pill. Update the check's comment to describe the beacon instead of the
heading label — the HTML assertions themselves (the `idea-tag-rookery`
class, the `class="idea-tag` pill presence/absence) do NOT need to change,
since the rendered output is identical either way; only how the tag got
there changed.

## Touches

`core/0.1.0/src/pure.typ`, `core/0.1.0/src/ideate.typ`,
`core/0.1.0/src/lib.typ`, `core/0.1.0/test/units.typ`,
`core/0.1.0/readme.md`, `core/0.1.0/demo/rheo/content/ideated.typ`,
`core/0.1.0/demo/rheo/check.sh`

## VERIFY

1. `cd core/0.1.0 && just test` — must print `units OK` (the new
   `_ideate-tag-value` assertions run here).
2. `cd core/0.1.0/demo/rheo && just check` — must print `demo/rheo OK`, with
   check 24's assertions passing against the rewritten fixture. This recipe
   needs a `rheo` binary on `PATH` (see that directory's own `Justfile`
   header comment for how to point it at a locally built one) — if none is
   available, say so explicitly rather than skipping this step silently.
3. `bd status <this-bird-id>` reports `retired` after landing — if it still
   reports `ready`, the flight landed but the bird did not close; re-slip
   and alight the empty flight.