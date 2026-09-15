---
id: rk-carry-show-tags-through-a-replayed-card-d577e4fe
short-id: d57
title: Carry show-tags through a replayed card
priority: 3
labels:
- fix-show-tags-transclusion
deps: []
closed: false
---
Touches: core/0.1.0/src/idea.typ, core/0.1.0/src/transclusion.typ, core/0.1.0/demo/rheo/content/tags.typ, core/0.1.0/demo/rheo/check.sh

`show-tags: true` on `#idea` renders a note's flat tags as pills in its hat. That
holds where the card is hatched in place, and is lost the moment the same card is
REPLAYED from its metadata beacon — nested inside a transcluded parent, or on the
minted `ideas/<parent>.html` page of an idea that contains it. The replayed card
comes back with a permalink and no pills, whatever its call site asked for.

Observed on a real site: a week page's section cards each wear their thread pill,
and the week's own minted page reproduces all eight cards with the correct
`idea-tag-<tag>` CLASS on every heading and not one pill in any hat.

## Why — two defects, both required

1. `/home/lox/code/_fcl/rookery/core/0.1.0/src/idea.typ:164` — the `#metadata`
   payload carries `show-frame` and `show-id` but NOT `show-tags`, so the switch
   is not even available to the replay path. The comment directly above it
   (lines 160-163) states the rule being broken: a presentation switch missing
   from the payload "is silently lost the moment the note is shown nested inside
   a transcluded or minted parent".

2. `/home/lox/code/_fcl/rookery/core/0.1.0/src/transclusion.typ:336` —
   `_flatten`'s idea (IK) arm builds the hat as
   `_permalink-tab(id, show-id: v.at("show-id", default: true))` and passes no
   `tags:` argument at all, so that hat can only ever be a permalink.

The window (WK) arm of the same file ALREADY does this correctly at
`transclusion.typ:429-437`, reading `v.at("show-tags", default: false)` off the
payload with an `.at` default because an older payload may carry no such key.
Copy that shape.

## Steps

1. `/home/lox/code/_fcl/rookery/core/0.1.0/src/idea.typ:164`. The line is one
   long `#metadata((..))` call ending `show-frame: show-frame, show-id: show-id))`.
   Add `show-tags` as the last key, so it ends:

   `show-frame: show-frame, show-id: show-id, show-tags: show-tags))`

   `show-tags` is already a parameter of `#idea` (idea.typ:45), so there is
   nothing to thread in — it is in scope at this line.

2. `/home/lox/code/_fcl/rookery/core/0.1.0/src/transclusion.typ:336`. Replace
   that single line:

   ```typst
        if id == none { [] } else { _permalink-tab(id, show-id: v.at("show-id", default: true)) },
   ```

   with:

   ```typst
        if id == none { [] } else {
          _permalink-tab(
            id,
            tags: if v.at("show-tags", default: false) {
              v.tags.pairs().filter(((_, val)) => val == none).map(((k, _)) => k)
            } else { () },
            show-id: v.at("show-id", default: true),
          )
        },
   ```

   FLAT TAGS ONLY — those whose value is `none`. That mirrors `idea.typ:327`,
   which is what `#idea`'s own hat renders, and the same filter the marrow uses
   at `.marrow.typ:183-185`. A valued tag's name alone says nothing in a pill.

   Name the filter's binding `val`, NOT `v`: the record being read is also called
   `v` in this scope, and shadowing it inside the closure is how this line gets
   quietly wrong.

3. Add the missing fixture. Nothing in the demo covers this path today:
   `tag-hat` (`demo/rheo/content/tags.typ:34-41`) and `tag-valued`
   (`tags.typ:50-60`) are both TOP-LEVEL ideas, so no demo note nests a tagged
   `show-tags: true` card inside another idea — which is exactly why `just check`
   passes with the bug present. Append to
   `/home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo/content/tags.typ`, after the
   `#context [..]` block that ends on line 66:

   ```typst
   // A tagged note with `show-tags: true` NESTED inside another idea. The outer
   // note's minted page rebuilds this card from its beacon, which is the only
   // path on which the pill can go missing.
   #idea("tag-nest-outer", title: [A note containing a tagged note])[
     #idea(
       "tag-nest-inner",
       title: [The nested tagged note],
       tags: ("draft",),
       show-tags: true,
     )[Its pill must survive being replayed on the outer note's minted page.]
   ]
   ```

4. Add the assertions. In
   `/home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo/check.sh`, insert a new
   numbered block immediately BEFORE the final `if [ "$fail" -ne 0 ]; then` line
   (currently line 624). `$H` is already bound by the script to the build's HTML
   root; reuse it as every other block does.

   ```bash
   # 26. `show-tags: true` SURVIVES A REPLAY. `tag-nest-inner` is hatched with a
   #     pill on its own card in tags.html; the outer note's minted page rebuilds
   #     that card from its beacon, and the pill has to come back with it.
   grep -q 'class="idea-tag' "$H/tags.html" ||
     note "tags.html does not show the nested card's pill where it is hatched in place"
   grep -q 'class="idea-tag' "$H/ideas/tag-nest-outer.html" ||
     note "ideas/tag-nest-outer.html replays the nested card without its tag pill"
   ```

   `class="idea-tag` is the pill's own class and the right test here, for the
   reason `check.sh:594-598` already gives: a bare `idea-tag-` substring matches
   the project-wide generated `.idea-tag-note { .. }` rule that every page in
   this build carries regardless of its own tags. `tag-nest-outer` has no tags of
   its own, so the only pill that can appear on its page is the replayed one.

## VERIFY

Requires the `rheo` binary, because `demo/rheo/rheo.toml` resolves the
`@rookery` namespace with a `path` source and `path` landed in rheo 0.6.3. Check
first — if this prints anything below 0.6.3, stop and report rather than
working around it:

```bash
rheo --version
```

Then, all four expected to pass:

```bash
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check-typst
cd /home/lox/code/_fcl/rookery/core/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/pure && just build
```

`just check` must print `demo/rheo OK`. It deletes and rebuilds `build/` every
run, so there is no snapshot to regenerate — the regeneration command IS the test
command.

Two absence-based assertions elsewhere in the suite are the ones a wrong fix
breaks, and both must stay green: the invisible-tag block at `check.sh:261-273`
(`idea-tag-secret` must appear nowhere in the build) and the tagless control at
`check.sh:599-601` (`ideas/literate-programming.html` must wear no pill). A
tagless note has no flat tags either way, so a correct fix leaves both alone.

## Non-goals

- **Do not filter invisible tags at the new call site.** `_permalink-tab` already
  does it, at `permalink.typ:128` (`let shown = _visible-tags(tags)`). A second
  filter is how the two drift apart.
- **Do not touch `.marrow.typ`.** A minted page already renders its OWN idea's
  tags unconditionally — `check.sh:252-253` documents that deliberately. The gap
  is only in replayed CHILD cards.
- **Do not add `show-date` to the payload**, or otherwise "complete the set" of
  presentation switches. `show-tags` only.
- **Do not edit `core/0.1.0/readme.md`.** It already documents `show-tags` as
  rendering pills (readme.md:961, 1678-1688); this restores documented behaviour
  rather than changing it, so there is nothing to describe.
- **Do not bump `version` in `core/0.1.0/typst.toml`.**
- **Do not edit `check.sh` blocks 1-25, or `check-native.sh`.** The native build
  mints no pages, so it has no replay path to cover.

## Uncertainty

`class="idea-tag` assumes the default `idea` CSS prefix. `demo/rheo` sets no
`css-prefix`, so this holds there; do not copy the assertion into a build that
configures one.