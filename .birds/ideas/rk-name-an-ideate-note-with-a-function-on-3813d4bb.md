---
id: rk-name-an-ideate-note-with-a-function-on-3813d4bb
short-id: '381'
title: 'Name an #ideate note with a function on its heading'
priority: 3
labels:
- feat-ideate-name-fn
deps: []
closed: true
---
`#ideate`'s `name:` accepts `auto` (the package counter) or the sentinel `heading`
(a slug of the heading that starts each note) and nothing else — a fixed string is
refused, because one `name:` would mint every note in the body under one id
(`core/0.1.0/src/ideate.typ:307-313`).

That leaves no way to give the minted ids a per-document namespace. The motivating
consumer is `weeknotes.ohrg.org`, whose weeks are one `#weeknote` idea with a
nested idea per section. Weeks up to 26w36 hand-write each nested note as
`#idea(<26w35-rookery>)[..]`; 26w37 moved to a document-level
`#show: ideate.with(separator: heading.where(level: 2), title: heading, name: heading)`
and now mints `idea:rookery` — a flat, global id, so the same heading next week is
a build error. Rookery ids are flat by design (readme, "Flat ids, and why"), so the
prefix has to come from the call site.

Add a THIRD accepted form: a FUNCTION, called once per section, returning that
section's id as a string.

    #import "@rookery/core:0.1.0": ideate, slug

    #show: ideate.with(
      separator: heading.where(level: 2),
      title: heading,
      name: (content, labels) => "26w37-" + slug(content),
    )

    == Waterline <tag:waterline>   ->  idea:26w37-waterline

**Arguments, both positional:**

1. `content` — the separating heading's own body, the SAME value `title: heading`
   already passes to `#idea`. Raw content, not a string: the caller decides how to
   project it.
2. `labels` — the Typst labels on that heading, as an ARRAY. `()` for a bare
   heading, `(<tag:waterline>,)` for a labelled one. A Typst element carries at
   most one label today, so the array is never longer than 1; it is an array so
   the signature does not change if that ever stops being true, and so a lambda
   never has to handle two types.

Because `content` is raw content, the package must also export the slugger it
already has, or every caller re-implements it. That is step 1.

## Steps

1. **Export a public `slug`.** File: `core/0.1.0/src/pure.typ`. `_slug(s)` is at
   line 750 and takes a STRING; `_plain(c)` (content -> plain string, and a
   passthrough for a string already) is at line 348 in the same file, above it.
   Immediately after `_slug`, add:

   ```typ
   #let slug(content) = _slug(_plain(content))
   ```

   No change to `src/lib.typ`: it star-imports `base.typ`, which star-imports
   `pure.typ` (`src/base.typ:45`), and the name has no leading underscore, so it is
   re-exported to `@rookery/core:0.1.0` automatically.

   While there, generalise `_slug`'s own panic message (lines 753-758). It names
   "`#ideate`'s `name: heading`" as the only caller; a public `slug()` can now fire
   it too. Say that the text slugged to nothing once punctuation was stripped,
   name the input, and drop the sentinel-specific advice.

2. **Classify the new form.** File: `core/0.1.0/src/ideate.typ`, ~line 306, beside
   the existing `title-from-heading`/`name-from-heading` lines. Add:

   ```typ
   let name-fn = type(name) == function and not name-from-heading
   ```

   ORDER MATTERS and this is the one real trap in the bird: `heading` is itself an
   element function, so `type(name) == function` is TRUE for the sentinel. `name-fn`
   must exclude `name-from-heading`, which is computed on the line above it.

3. **Widen the two panics.** Same file.
   - Line 307, `if name != auto and not name-from-heading {` -> also `and not
     name-fn`. Extend its message to name the third accepted form: a function of
     `(content, labels)` returning the note's id as a string.
   - Line 315, `if (title-from-heading or name-from-heading) and not heading-mode {`
     -> include `name-fn`. A function needs a separating heading to read exactly as
     the sentinel does, so it is heading-mode-only for the same reason and gets the
     same panic.

4. **Take the naming branch.** Same file, the emit loop (~line 441):
   - `if not (title-from-heading or name-from-heading) or lead-heading == none {`
     -> add `or name-fn` to the first group. The `lead-heading == none` arm is
     UNCHANGED and load-bearing: the preamble group (content before the first
     matching heading) has no heading to hand the lambda, so it keeps minting under
     the package counter, exactly as it does under `name: heading` today.
   - Line 449, `if not name-from-heading {` -> `if not (name-from-heading or
     name-fn) {`.

5. **Call the lambda.** Same file, the `else` arm at lines 452-478 that currently
   computes `_plain` -> `_slug` -> collision check -> `mint(slug, ..)`. Restructure
   so both paths produce one `name-value` string and share the collision check:

   ```typ
   let name-value = if name-fn {
     let labels = (lead-heading.at("label", default: none),).filter(l => l != none)
     let out = (name)(lead-heading.body, labels)
     if type(out) != str or out == "" {
       panic(
         "ideate: `name:`'s function must return this note's id as a "
           + "non-empty string. Got: " + repr(out),
       )
     }
     out
   } else {
     _slug(_plain(lead-heading.body))
   }
   ```

   Then the EXISTING `seen-slugs` check runs against `name-value` for both paths —
   two sections landing on one id panic rather than silently sharing it — and
   `mint(name-value, rest, ..title-arg, tags: group-tags)` closes the branch.

   Do NOT reach for `_plain-with(.., _ref-text(reg))` on the lambda path. The
   comment at lines 460-470 records a MEASURED failure: reading the registry here,
   in the call that is about to add to it, made a rheo build fail with `document did
   not converge within five attempts`. The lambda gets the heading's raw body and
   what it does with a `#ref` inside it is the caller's business — note in the
   readme that a caller who resolves one themselves can reintroduce exactly that
   non-convergence.

6. **Unit-assert `slug`.** File: `core/0.1.0/test/units.typ`. Add `slug` to the
   `#import "/src/lib.typ": (..)` list at line 19, and assertions beside the
   existing `_slug` block (~line 580):

   ```typ
   #assert.eq(slug([Waterline]), "waterline")
   #assert.eq(slug([Week 37: Intro]), "week-37-intro")
   #assert.eq(slug("already a string"), "already-a-string")
   ```

   `#ideate` itself CANNOT be asserted in this file — see its header and the note at
   line 522: the fixture compiles to a PAGED target, where `#ideate` is a
   passthrough that mints nothing. The behaviour in steps 2-5 is proved by the demo
   in step 7, which is the established split for everything `#ideate` does.

7. **Demo fixture and check.** `core/0.1.0/demo/rheo/content/ideated.typ` already
   installs a document-level `#show: ideate.with(..)`, so a second `#ideate` call
   inside it would NEST one note in another. Add a NEW sibling file,
   `core/0.1.0/demo/rheo/content/ideated-named.typ`, shaped like `ideated.typ`
   (same `#import "lib.typ": demo` / `#show: demo` preamble), whose show rule is:

   ```typ
   #show: ideate.with(
     separator: heading.where(level: 2),
     title: heading,
     name: (content, labels) => "wk-" + str(labels.len()) + "-" + slug(content),
   )
   ```

   with two sections: `== Waterline <tag:waterline>` and `== Rheo` (no label).
   Encoding `labels.len()` in the id is deliberate — it makes the array argument
   observable from a minted PATH, which is all `check.sh` can see.

   Then add a numbered check to `core/0.1.0/demo/rheo/check.sh` (the last one today
   is 24, at line 586) asserting `$H/ideas/wk-1-waterline.html` and
   `$H/ideas/wk-0-rheo.html` both exist, and that `wk-1-waterline.html`'s `<title>`
   is `Waterline` — the lambda names the note without touching its title. Follow
   check 23's shape (line 560) for the `note "..."` failure-message style.

   UNVERIFIED, so check it rather than assuming: that the rheo demo picks up a new
   content file with no registration step. If `demo/rheo/rheo.toml` or a spine file
   lists content explicitly, add the new file there too.

8. **Readme.** File: `core/0.1.0/readme.md`. Four edits:
   - Line 684, the `title:`/`name:` table — a fourth column, or a row for the
     function form.
   - Lines 693-694, "so `name:` accepts only `auto` or `heading`" — no longer true.
   - Line 740, the signature line — unchanged in shape, but the prose around it
     should name the third form.
   - A new subsection under "Titling and naming notes from their own heading"
     documenting the two arguments, the return contract, that the preamble group
     still gets the counter, the `#ref` non-convergence warning from step 5, and
     `slug()` as the exported projection. Use the `26w37-` weeknotes example above
     — it is the real motivating case.

## Do NOT

- Do NOT add a `prefix:` argument. A function subsumes it and the caller asked for
  the general form.
- Do NOT touch `title:`. It keeps accepting `none`, a fixed value, or the `heading`
  sentinel, and is independent of `name:`.
- Do NOT make the function work with `separator: par` or `separator: none`. There is
  no separating heading in either mode; both must panic via step 3.
- Do NOT change what the preamble group mints under. It is the package counter today
  and stays the package counter.
- Do NOT re-slug or otherwise rewrite what the lambda returns. Validate it is a
  non-empty string and pass it through — a caller that wants slugging calls `slug()`.

## VERIFY

1. `cd core/0.1.0 && just test` passes (both fixtures), including the three new
   `slug` assertions.
2. `cd core/0.1.0/demo/rheo && ./check.sh` (or the Justfile recipe it is wired to)
   passes, with the new check finding `ideas/wk-1-waterline.html` and
   `ideas/wk-0-rheo.html`.
3. `ideas/wk-1-waterline.html`'s `<title>` is `Waterline` — naming a note through
   the lambda leaves its title alone.
4. In the new demo file, content written BEFORE the first `==` still mints under a
   numeric id (`ideas/1.html` or whatever the counter is at), not through the lambda.
5. `#show: ideate.with(separator: par, name: (c, l) => "x")` panics with the
   heading-mode message from step 3, and `name: (c, l) => 42` panics naming `42`.