---
id: rk-adds-tag-and-base-tags-to-idea-9960f68e
short-id: '996'
title: 'Adds tag and base-tags to #idea'
priority: 3
labels:
- feat-idea-base-tags
deps: []
closed: false
---
Touches: core/0.1.0/src/pure.typ, core/0.1.0/src/idea.typ, core/0.1.0/test/units.typ, core/0.1.0/readme.md

Give `#idea` in `@rookery/core` two new tag arguments, `tag:` and `base-tags:`,
so that `idea.with(..)` is a safe way to build a note constructor.

## Why

Today the only safe way to build a tagged constructor is the `tagged-idea`
factory. The obvious `.with()` spelling is a documented trap:

    #let note = idea.with(tags: ("note",))
    #note("c", tags: ("draft",))[body]

`.with()` binds a DEFAULT, and a caller's explicit `tags:` REPLACES it
wholesale, so note "c" comes out tagged `("draft",)` — the "note" tag is
silently gone. This was measured on the current tree, not inferred:
`tagged-idea("note")` gives `("note", "draft")` for the same call.

`tag:` and `base-tags:` are merging slots next to the replacing one. A caller's
`tags:` is merged ON TOP OF them rather than replacing them, so `.with()`
becomes safe:

    #let note = idea.with(tag: "note")
    #note("c", tags: ("draft",))[body]      // -> ("note", "draft")

After this bird there are exactly three ways to put tags on a note, and they
differ in who writes them and what they accept:

    #idea(
      tag: "onlystring",                    // a string, or none
      base-tags: ("string", "or", "array"), // none, string, array or dictionary
      tags: "string-or-array",              // none, string, array or dictionary
    )

- `tags:` is the CALL SITE's. It replaces whatever a constructor bound, which
  is why it alone is safe to name at a call site and unsafe to bind with
  `.with()`.
- `base-tags:` is a CONSTRUCTOR's, and takes every shape `tags:` does. The
  dictionary form binds a VALUE per tag —
  `idea.with(base-tags: (todo: (state: "open")))`.
- `tag:` is the same thing narrowed to the single-tag case, which is the
  common one: `idea.with(tag: "note")`. It accepts a STRING ONLY.

PRECEDENCE, lowest to highest: `tag:`, then `base-tags:`, then `tags:`. Where
two of them name the same tag, the higher one's value wins outright — there is
no deep merge, which is the rule `_dedup-tag` already implements.

## Where

All sites are in `core/0.1.0/`. Run the anchor commands from the FLIGHT ROOT
(the directory containing `core/`, `search/`, `todos/` …). Each was run before
filing and printed exactly ONE hit.

**Site 1 — `_assert-tags`,** the shared validator, in `core/0.1.0/src/pure.typ`
(around line 760 as of filing).

    rg -Fn '#let _assert-tags(v, where)' core/

**Site 2 — `_dedup-tag`,** the per-key merge, also in `core/0.1.0/src/pure.typ`
(around line 226 as of filing). The new helper goes directly BELOW it.

    rg -Fn '#let _dedup-tag(tag, tags, value: none)' core/

**Site 3 — `#idea`'s signature,** in `core/0.1.0/src/idea.typ` (around line 45).

    rg -Fn '#let idea(level: 1, title: none, tags: ()' core/

**Site 4 — `#idea`'s tag normalization,** three lines into that function's body
(around line 55).

    rg -Fn '_assert-tags(tags, "#idea'"'"'s")' core/

**Site 5 — `tagged-idea`'s fold,** in `core/0.1.0/src/idea.typ` (around line
524).

    rg -Fn 'own-tags.rev().fold(tags,' core/

**Site 6 — `tagged-idea`'s banner comment,** in `core/0.1.0/src/idea.typ`
(around line 436).

    rg -Fn 'is a FACTORY: it returns an' core/

**Site 7 — the units fixture's `_dedup-tag` block,** in
`core/0.1.0/test/units.typ` (around line 48).

    rg -Fn '_dedup-tag — `#todo("x", tags: ("todo",))` must not double the tag' core/

**Site 8 — the readme's `tagged-idea` section heading,** in
`core/0.1.0/readme.md` (around line 1756).

    rg -Fn '### `tagged-idea` — build your own constructors' core/

**Site 9 — the readme's signature paragraph,** in `core/0.1.0/readme.md`
(around line 23).

    rg -Fn 'the sink accepts the body alone' core/

If an anchor does not resolve, widen the `rg` to the flight root. If it is
still gone, STOP and report the miss naming the landmark (the function, the
comment banner, the readme heading) rather than guessing or recreating text.

## Steps

1. **Site 1 — let `_assert-tags` name the argument it is checking.** It
   currently hardcodes the word `tags` in its message. Give it a `what:`
   parameter defaulting to `"tags"` and use that in the message instead of the
   literal:

       #let _assert-tags(v, where, what: "tags") = assert(
         v == none
           or type(v) == str
           or type(v) == dictionary
           or (type(v) == array and v.all(t => type(t) == str)),
         message: "@rookery/core: " + where + " `" + what + "` must be none, a "
           + "string, an array of strings, or a dictionary — got " + repr(v),
       )

   Every existing call site passes two arguments and keeps working unchanged.
   Do NOT touch the four existing callers (`data.typ`, `window.typ`,
   `outline.typ`, `template.typ`).

2. **Site 2 — add `_merge-base-tags` directly below `_dedup-tag`.** It folds a
   constructor's base tags UNDER a caller's, reusing `_dedup-tag` so the
   caller-wins rule is defined in exactly one place:

       #let _merge-base-tags(base, tags) = {
         let base = _norm-tags(base)
         base.keys().rev().fold(
           _norm-tags(tags),
           (acc, t) => _dedup-tag(t, acc, value: base.at(t)),
         )
       }

   Give it a comment block in the project's style (see `CLAUDE.md`) saying what
   it is: the merge behind `#idea`'s `tag:` and `base-tags:`, where the
   higher-precedence side wins outright on a key collision because
   `_dedup-tag`'s "already a key" guard says so, and where the `.rev()` is
   there so keys come out in the order the constructor named them
   (`_dedup-tag` prepends, so the last one folded ends up first). It NESTS to
   give the three-way precedence — that is worth one sentence, since it is why
   no three-argument version of this helper exists. Do not narrate the change.

3. **Site 3 — add the two parameters to `#idea`.** Insert
   `tag: none, base-tags: none,` immediately after `tags: (),` in the
   signature. Leave every other parameter and its order alone.

4. **Site 4 — validate and merge them.** The function body currently opens
   with:

       _assert-tags(tags, "#idea's")
       let tags = _norm-tags(tags)

   Make it:

       _assert-tags(tags, "#idea's")
       _assert-tags(base-tags, "#idea's", what: "base-tags")
       assert(
         tag == none or type(tag) == str,
         message: "@rookery/core: #idea's `tag` must be a single tag name as a "
           + "string — pass several as `base-tags: (\"a\", \"b\")` — got "
           + repr(tag),
       )
       let tags = _merge-base-tags(tag, _merge-base-tags(base-tags, tags))

   Read the nesting from the inside out: `base-tags` merges under the caller's
   `tags`, and `tag` merges under the result of that. `_merge-base-tags`
   normalizes both its sides, so the separate `_norm-tags(tags)` call is no
   longer needed here.

   `tag:` gets its OWN assert rather than `_assert-tags`, because it is the one
   tag argument that does NOT take all four shapes — a string only. The message
   must point at `base-tags:` as the way to pass several, or a caller who
   writes `tag: ("a", "b")` has nowhere to go.

   **Do NOT name a local `base` anywhere in this function.** `#idea` already
   binds `let base = if named { _norm(name) } else { none }` further down and
   uses it for the note's id; shadowing it breaks every named note.

   Add a short comment above the asserts giving the three-way split and its
   precedence: `tags:` is the call site's and replaces; `base-tags:` and `tag:`
   are a constructor's and are merged under it, `tag:` lowest; which is what
   makes `idea.with(tag: ..)` safe where `idea.with(tags: ..)` silently drops
   the constructor's tag.

5. **Site 5 — reimplement `tagged-idea` over the new parameters,** so the two
   cannot drift. Its returned closure currently reads:

       (
         tags: none,
         exclude-tags: exclude-tags,
         ..args,
       ) => idea(
         tags: own-tags.rev().fold(tags, (acc, t) => _dedup-tag(t, acc, value: value)),
         exclude-tags: exclude-tags,
         ..args,
       )

   Replace the whole returned-closure expression with:

       idea.with(
         base-tags: if value == none {
           own-tags
         } else {
           ((own-tags.at(0)): value)
         },
         exclude-tags: exclude-tags,
       )

   This is an exact translation: the asserts above it already guarantee
   `own-tags` is non-empty, and that `value` is only ever set when there is
   exactly ONE tag — so `own-tags.at(0)` is safe in that branch. `.with()`
   binds `exclude-tags` as a default a caller can still override, which is the
   behaviour the closure's explicit `exclude-tags:` parameter provided.

   Use `base-tags:`, NOT `tag:` — the factory takes several tags and `tag:`
   takes one.

   Keep every assert above it exactly as it is, including the `own.named()`
   sink check and the `value == none or own-tags.len() == 1` check.

6. **Site 6 — update `tagged-idea`'s banner comment.** Two claims in it are now
   false and must be rewritten to describe what is actually there:

   - "THE TRAP, do not reintroduce: `#let note = idea.with(tags: (note: none))`"
     — still a trap, but the reason to reach for `tagged-idea` is no longer
     that `.with()` cannot merge. Rewrite this paragraph to say that `tags:`
     replaces while `tag:`/`base-tags:` merge, and that `idea.with(tag: ..)` is
     the supported `.with()` spelling.
   - The paragraph beginning "`value:` is the default this factory binds" and
     its "IT TAKES ONE TAG" reasoning — keep the description of what `value:`
     does, and note that `base-tags:` in its dictionary form expresses the same
     thing without the one-tag restriction, since there the dictionary IS the
     tag record.

   Also say plainly that the factory is now a thin wrapper over
   `idea.with(base-tags: ..)`. Follow `CLAUDE.md`'s comment style: present
   tense, describe what is there, no "used to", no issue ids.

7. **Site 7 — add unit cases.** In `core/0.1.0/test/units.typ`, add
   `_merge-base-tags` to the big `#import "/src/lib.typ": (..)` list at the top
   (keep the list's existing grouping), and add a new block directly BELOW the
   existing `_dedup-tag` block:

       // ---- _merge-base-tags — a constructor's tags, under the caller's ------
       // The trap this pins: `idea.with(tags: ("note",))` lets a caller's own
       // `tags:` REPLACE the constructor's tag outright, so `#note("c", tags:
       // ("draft",))` loses "note". `tag:`/`base-tags:` merge instead.
       #assert.eq(_merge-base-tags("note", none), (note: none))
       #assert.eq(_merge-base-tags("note", ("draft",)), (note: none, draft: none))
       // Several tags keep the order the constructor named them in.
       #assert.eq(
         _merge-base-tags(("person", "participant"), none),
         (person: none, participant: none),
       )
       // A dictionary base binds a VALUE per tag, which is what makes a
       // one-tag `value:` restriction unnecessary.
       #assert.eq(
         _merge-base-tags((todo: (state: "open"), draft: none), none),
         (todo: (state: "open"), draft: none),
       )
       // THE CALLER'S OWN VALUE FOR THE SAME TAG WINS OUTRIGHT — no deep merge.
       #assert.eq(
         _merge-base-tags((todo: (state: "open")), (todo: (state: "done"))),
         (todo: (state: "done")),
       )
       // An absent base is the caller's tags, normalized and nothing else.
       #assert.eq(_merge-base-tags(none, ("draft",)), (draft: none))
       // NESTED, which is how `#idea` gets its three-way precedence:
       // `tag:` under `base-tags:` under the caller's `tags:`.
       #assert.eq(
         _merge-base-tags("low", _merge-base-tags(("mid",), ("high",))),
         (low: none, mid: none, high: none),
       )
       #assert.eq(
         _merge-base-tags((k: "low"), _merge-base-tags((k: "mid"), (k: "high"))),
         (k: "high"),
       )

8. **Site 8 — update the readme's `tagged-idea` section.** Add `tag:` and
   `base-tags:` as the primary way to build a constructor, with the three
   argument forms shown and the precedence rule stated, plus the `.with()`
   composition example. The sentence "`tagged-idea` exists because `.with()`
   cannot express \"merge, don't replace\"" is now false — find it with
   `rg -Fn 'cannot express' core/0.1.0/readme.md` and rewrite it to say that
   `tag:`/`base-tags:` are what express it, and that `tagged-idea` remains as a
   factory spelling of the same thing. Keep the existing `exclude-tags`
   discussion in that section; it still holds for the factory.

9. **Site 9 — update the readme's full-signature paragraph** so the listed
   signature includes `tag: none, base-tags: none` after `tags: ()`.

## Non-goals

- **Do NOT remove or deprecate `tagged-idea` in this bird.** It stays
  exported, with its current signature and behaviour, reimplemented over
  `base-tags:` per step 5. `todos`, `slipshow`, `meetings`, `cfps`, `bibtex`
  and `timeline` all still import it, and they are migrated off it by their
  own birds before a separate later bird deletes it from core. Removing it
  here breaks six packages at once.
- **Do NOT touch any package outside `core/0.1.0/`.**
- Do not add `tag:` or `base-tags:` to `#window`, `#ideas`, `#ideas-outline`
  or `#ideate`. Their `tags:` is a FILTER, not a constructor's tags, and
  merging makes no sense there.
- Do not change what `tags:` does. It still replaces.
- Do not make `tag:` accept an array, a dictionary or a label. A string or
  `none`, and nothing else — that restriction is the point of having it
  alongside `base-tags:`.
- Do not touch `.marrow.typ`, the exclusion gate, the registry write, or any
  rendering branch.
- Do not add a demo file under `core/0.1.0/demo/`.

## VERIFY

Run 1, 2 and 3 from `<flight>/core/0.1.0/`.

1. The unit fixtures compile, which is the whole harness:

       just test

   Expect it to end with `units OK`.

2. The trap is actually fixed end to end, and all three arguments compose.
   Create `_basetags_check.typ` INSIDE `core/0.1.0/` (it must live under the
   compile root — a file in `/tmp` fails with "source file must be contained
   in project root"):

       #import "/src/lib.typ": idea, rookery, tagged-idea, tags-of, tag-value
       #show: rookery
       #let note = idea.with(tag: "note")
       #let participant = idea.with(base-tags: ("person", "participant"))
       #let todo = idea.with(base-tags: (todo: (state: "open")))
       #let factory = tagged-idea("note")
       #note("a", tags: ("draft",))[body]
       #factory("b", tags: ("draft",))[body]
       #participant("c")[body]
       #todo("d")[body]
       #idea("e", tag: "low", base-tags: ("mid",), tags: ("high",))[body]
       #context {
         assert.eq(tags-of("a"), ("note", "draft"))
         assert.eq(tags-of("b"), ("note", "draft"))
         assert.eq(tags-of("c"), ("person", "participant"))
         assert.eq(tags-of("d"), ("todo",))
         assert.eq(tag-value("d", "todo"), (state: "open"))
         assert.eq(tags-of("e"), ("low", "mid", "high"))
       }

   Compile it:

       typst compile --features html --root . --format html _basetags_check.typ /dev/null

   Expect exit 0 (an `html export is under active development` warning is
   normal and expected). The asserts are the test: note "a" proves
   `.with(tag:)` survives a caller's own `tags:`, note "b" proves the
   reimplemented factory still behaves identically, and note "e" proves the
   three-way precedence.

   DELETE `_basetags_check.typ` afterwards — it must not be left in the tree.

3. The demo suite still builds:

       cd demo/pure && just build

   Expect it to end with `demo/pure OK`.

4. The readme documents both new arguments. From `<flight>/core/0.1.0/`:

       rg -Fn 'base-tags' readme.md

   Expect at least three hits (the signature paragraph and the `tagged-idea`
   section).