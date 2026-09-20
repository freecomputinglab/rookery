---
id: rk-correct-six-wrong-comments-in-src-6e39825c
short-id: '6e3'
title: Correct six wrong comments in src
priority: 2
labels:
- fix-wrong-comments
deps:
- blocked-by:rk-strip-the-interior-section-banners-7392205a
closed: true
---
Six comments in `core/0.1.0/src/` state things that are not true of the code
as it stands. Two of them are in the first six lines of the package's
entrypoint, which is the first thing anyone reads.

This project's `CLAUDE.md` requires comments to describe the present: not what
the code used to be, not what it might have been. Each of these fails that in a
way a reader can actually be misled by.

Touches: core/0.1.0/src/lib.typ, core/0.1.0/src/outline.typ, core/0.1.0/src/idea.typ, core/0.1.0/src/pure.typ, core/0.1.0/src/state.typ, core/0.1.0/src/window.typ, core/0.1.0/src/template.typ

## Problem one: `#note` and `#todo` do not exist

`src/lib.typ`'s header comment tells a reader that the package ships two
functions it does not ship. Anchor — one hit, in `core/0.1.0/src/lib.typ`
(line 6 as of filing), inside the file's opening header block:

```
rg -n 'pure sugar over that same' /home/lox/code/_fcl/rookery/core/0.1.0/src
```

The sentence reads: "`#note`/`#todo` are pure sugar over that same tags array
(see below), not a taxonomy of their own." Neither function is defined anywhere
in `src/`, and the "(see below)" points at nothing. Confirm for yourself:

```
rg -n '^#let (note|todo)\b' /home/lox/code/_fcl/rookery/core/0.1.0/src
```

Prints nothing.

What `note` and `todo` actually are: names a CONSUMING PROJECT binds for itself
with `#let note = idea.with(tag: "note")`. The package's own demos do exactly
that — see `core/0.1.0/demo/rheo/content/lib.typ` and
`core/0.1.0/demo/pure/excluded.typ`.

Fix the header so it makes the real point — that ideas are flat and carry only
free-form tags, and that a project builds its own constructors over `idea.with(tag: ..)`
rather than the package offering a taxonomy — without naming `#note` or `#todo`
as if they were exports.

Three other comments repeat the same false impression. Find them:

```
rg -n '#note|#todo' /home/lox/code/_fcl/rookery/core/0.1.0/src
```

Hits as of filing, beyond `lib.typ:6`:

- `outline.typ:587` — "the package ships NO default rule for any of them —
  `#note`/`#todo` are sugar, not a recognised set". The claim the sentence is
  making is correct; only the example is wrong. Rewrite it to make the point
  without naming two functions that do not exist.
- `idea.typ:93` and `pure.typ:210`, `pure.typ:225` — three comments illustrating
  tag precedence with a `#todo("x", tags: (todo: (state: "open")))` call.
  Replace the illustration with one built on a call that really exists, for
  instance a constructor a project made with `idea.with(tag: "todo")`, and make
  clear in the wording that the constructor is the caller's, not the package's.
- `pure.typ:432` and `pure.typ:540` — two comments using `#todo[Write ...]` as a
  throwaway example of a body. Same treatment.

While in `lib.typ`'s header: line 7 as of filing says "Note ids are flat Typst
labels". The package's vocabulary is **idea** and **name**. Reword to "An idea's
name is a flat Typst label" or similar.

## Problem two: a state comment that contradicts the only entry point

Anchor — one hit, in `core/0.1.0/src/state.typ` (line 188 as of filing), inside
the comment block above the `_index-page` binding:

```
rg -n 'DEFAULT OFF\. A project with its own index' /home/lox/code/_fcl/rookery/core/0.1.0/src
```

The comment says minting `ideas/index.html` is off by default, and gives a
paragraph on why a project with its own index must not get a second one.
But the only real entry point, `#let rookery(` in `src/template.typ`, declares
`index-page: true` and always publishes that resolved value to this state.
Confirm:

```
rg -n 'index-page: true' /home/lox/code/_fcl/rookery/core/0.1.0/src/template.typ
```

One hit. So the effective default every project gets is **on**. The state's
`false` initial value is only what is read before `#show: rookery` runs.

**The code is right and the comment is stale.** The package's own documentation
site and readme both state the default is on, and turning it off now would be a
behaviour change this bird must not make. Rewrite the comment to say what is
true: the default is on, `#rookery(index-page: false)` turns it off, and a
project that already publishes an index of its own should do that.

## Problem three: four comments written in the past tense

```
rg -n 'exactly as it always has|exactly as they already did|still applies everywhere it already did|any more\. .context' /home/lox/code/_fcl/rookery/core/0.1.0/src
```

Four hits as of filing:

- `window.typ:39` — "behaves exactly as it always has"
- `window.typ:74` — "exactly as they already did inside the `display:` dictionary"
- `idea.typ:53` — "none of them gets a built-in default substituted in this
  function any more"
- `template.typ:595` — "still applies everywhere it already did"

Each is comparing the code to a previous version of itself, which no reader of
the published package has seen. In each case, state the present fact and drop
the comparison: "a window that names its ideas and asks for no sort keeps them
in call-site order", "all nine keys are accepted; these three are unused here",
"every flag stays `auto` when unset", and so on. Read the surrounding block
before rewriting so the replacement says what the block needs it to say.

## Non-goals

- Do NOT change `index-page`'s default, or any other default value. This bird
  corrects comments only.
- Do NOT define `#note` or `#todo`. The package deliberately ships no taxonomy;
  the fix is to stop claiming it does.
- Do NOT remove section-divider comments. A separate bird owns those and may
  already have landed.
- Do NOT shorten the comment blocks generally. A separate bird owns comment
  volume.
- Do NOT change any code under `src/`.

## VERIFY

1. `rg -n '#note|#todo' /home/lox/code/_fcl/rookery/core/0.1.0/src` prints
   nothing.
2. `rg -n 'DEFAULT OFF' /home/lox/code/_fcl/rookery/core/0.1.0/src` prints
   nothing.
3. `rg -n 'exactly as it always has|exactly as they already did|still applies everywhere it already did|any more\. .context' /home/lox/code/_fcl/rookery/core/0.1.0/src`
   prints nothing. (Use exactly this pattern. Two other lines in `src/` contain
   the bare words "always has" and "any more" in ordinary present-tense prose —
   `state.typ`'s "arrival always has" and `pure.typ`'s "any more than two
   naming" — and both are correct and must be left alone.)
4. `rg -n 'index-page: true' /home/lox/code/_fcl/rookery/core/0.1.0/src/template.typ`
   still prints one hit — the default is unchanged.
5. From `core/0.1.0`, `just test` passes (prints `units OK`).
6. From `core/0.1.0/demo/pure`, `just build` passes (prints `demo/pure OK`).