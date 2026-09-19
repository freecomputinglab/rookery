---
id: rk-documents-title-derived-ids-and-the-url-579ccbdc
short-id: '57'
title: Documents title-derived ids and the URL break
priority: 2
labels:
- feat-title-derived-ids
deps:
- blocked-by:rk-derives-an-unnamed-idea-s-id-from-its-ac04e549
closed: false
---
Touches: core/0.1.0/readme.md

Document title-derived note ids in `@rookery/core`'s readme, and record the URL break
they cause.

## What changed in the code

An unnamed `#idea` used to always take a sequence number as its id (`idea:1`,
`idea:2`). Now:

- A note with a `title:` and no explicit name takes a slug of that title —
  `#idea(title: [My Title])[..]` mints `idea:my-title` and its page at
  `ideas/my-title.html`.
- The slug is lowercased with every run of non-alphanumeric characters collapsed to a
  single `-`, trimmed, and capped at 60 characters.
- Colliding slugs get a `-<n>` suffix counting from 1: a second note titled "My Title"
  mints `idea:my-title-1`.
- A title that slugs to nothing (pure punctuation) or to digits only falls back to the
  counter. Digits are refused because they would collide with the counter's own
  namespace.
- A note with NO title still takes a counter id, exactly as before. Titled notes still
  step that counter and discard the value, so untitled ids can have gaps (1, 4, 7) —
  this keeps an untitled note's id stable when a title is added to some earlier note.
- A PINNED name always wins: `#idea(<x>, title: [My Title])` mints `idea:x`.

## Steps

1. Find the existing description of auto ids:

   ```
   rg -n -F 'it takes a' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   The passage near the top of the readme (line 9 as of filing) currently says an
   unnamed `#idea[body]` "takes a sequential id, names itself by its own opening words
   wherever it is referred to (see \"Derived labels\"), and wears that id as a
   `[idea:1]`-style permalink". Rewrite it for the new rule: a titled note is named
   after its title, an untitled one still gets a number.

2. Find the other place this is documented:

   ```
   rg -n -i 'auto-generated id' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   Around line 393 as of filing, the readme argues that a permalink is the ONLY way to
   discover an auto-generated id, so a note that wants to be linkable wants a name.
   That argument is now much weaker for a TITLED note, whose id is predictable from its
   title. Update it: the warning still holds for an untitled note, and `show-id: false`
   is correspondingly cheaper on a titled one.

   The same claim appears in a comment in `core/0.1.0/src/idea.typ`, above the `#idea`
   signature — find it with `rg -n -F 'the ONLY way to discover an' /home/lox/code/_fcl/rookery`.
   Update that comment too if it is still overstated. This is the one source file this
   bird may touch.

3. Add a short section documenting the derivation rules listed above, placed with the
   readme's other material on ids and names. Match the readme's existing register (see
   `CLAUDE.md`, "Comment style", which applies to prose here too: present tense,
   describe what is, no changelog voice).

4. Add a migration note stating plainly that this CHANGES EXISTING URLS: a titled,
   unnamed note that was `ideas/3.html` is now `ideas/my-title.html`. In-repo `@idea:3`
   references fail at compile, which is loud; external links and bookmarks break
   silently. Say that pinning a name (`#idea(<3>)`) is how to keep an old id if one
   matters.

5. Check whether the two other readmes that describe core's auto-numbered ids need the
   same correction:

   ```
   rg -n -i 'sequential id|auto-numbered|counter' /home/lox/code/_fcl/rookery/slipshow/0.1.0/readme.md /home/lox/code/_fcl/rookery/search/0.1.0/readme.md
   ```

   If either states the old rule as fact, fix that sentence and nothing else, and add
   the file to your report. If neither does, say so. Do NOT rewrite either readme
   beyond a stale sentence.

## Non-goals

- Do NOT change any behaviour. This bird edits prose (plus at most the one overstated
  comment named in step 2).
- Do NOT document `_id-slug` or `_taken-ids`. Both are internal (leading underscore).
- Do NOT touch `core/0.1.0/src/` other than the single comment in step 2.
- Do NOT add a versioned changelog or "what's new" section — this project's convention
  is that documentation describes the present.

## VERIFY

From `core/0.1.0`:

1. `just test` exits 0 and prints `units OK`.
2. `rg -i -F 'my-title' readme.md` returns at least one hit — the worked example of a
   derived id is present.
3. `rg -i 'sequential id' readme.md` returns no hit, or only hits that correctly
   describe the UNTITLED case.
4. `rg -i -F 'ideas/my-title.html' readme.md` returns at least one hit, showing the
   minted-page filename is documented.
5. Report which of `slipshow/0.1.0/readme.md` and `search/0.1.0/readme.md` you changed,
   if either.