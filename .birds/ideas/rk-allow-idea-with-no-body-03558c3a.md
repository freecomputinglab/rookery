---
id: rk-allow-idea-with-no-body-03558c3a
short-id: '03'
title: 'Allow #idea with no body'
priority: 3
labels:
- fix-idea-bodiless
deps: []
closed: false
---
Touches: core/0.1.0/src/idea.typ, core/0.1.0/test/units.typ, core/0.1.0/readme.md

`#idea` in `@rookery/core` currently REQUIRES at least one positional
argument. A call that carries only named arguments and no trailing content
block — `#idea(title: [hello])` — panics with the package's own arity message
("#idea takes a body, optionally preceded by a name ... got 0 positional
arguments").

That is wrong. A note with a title and no body is a legitimate note: it
registers, it carries an id and an anchor, it can be linked to and
transcluded, and an empty body is already a fully supported shape everywhere
downstream — `#idea("x")[]` works today, and `test/units.typ` already pins
two of its consequences (`_join(())` returning `""` rather than `none`, and
`_derived-title([])` staying `none`). The only thing rejecting the call is
the arity guard at the top of `#idea`. Nothing below it needs to change.

So: make zero positional arguments legal, meaning an unnamed note with an
empty body.

## Where

All three sites are in `core/0.1.0/`. Run the anchor commands from the
REPOSITORY ROOT (the directory containing `core/`, `search/`, `todos/` …).
Each command below was run before filing and printed exactly ONE hit.

**Site 1 — the arity guard.** Inside the `#let idea(...)` function in
`core/0.1.0/src/idea.typ`, around line 62 as of filing.

```
rg -n 'pos.len\(\) >= 1 and pos.len\(\) <= 2' core/
```

**Site 2 — the destructuring just below it.** Same function, around line 69.

```
rg -n 'let \(name, body\) = if pos.len\(\) == 1' core/
```

**Site 3 — the arity fixture.** Under the heading `// ---- #idea — the two
legal positional shapes still compile` in `core/0.1.0/test/units.typ`, around
lines 76-87 as of filing.

```
rg -n 'let _bare = idea\[body text\]' core/
```

**Site 4 — the signature paragraph in the readme.** `core/0.1.0/readme.md`,
around line 23 as of filing.

```
rg -n 'the sink accepts the body alone' core/
```

If an anchor does not resolve, widen the `rg` to the repository root. If it
is still gone, STOP and report the miss naming the landmark (the `#let idea`
function, the units heading, the readme signature paragraph) rather than
guessing at the site or recreating the text.

## Steps

1. At site 1, change the assertion's condition from
   `pos.len() >= 1 and pos.len() <= 2` to `pos.len() <= 2`.

2. Rewrite that assertion's `message:` so it no longer claims a body is
   required. The message exists to catch ONE remaining mistake — a third
   positional, which is silently dropped — so it should say that and nothing
   else. Replace the existing message text with:

   ```
     message: "@rookery/core: #idea takes an optional name and an optional "
       + "body — #idea(<x>, title: [T])[body], not #idea(<x>, [T])[body]. "
       + "A title is a named argument; a third positional is silently the "
       + "one that gets dropped — got "
       + str(pos.len()) + " positional arguments.",
   ```

3. At site 2, extend the destructuring to handle the empty case. It currently
   reads:

   ```typ
   let (name, body) = if pos.len() == 1 {
     (none, pos.at(0))
   } else {
     (pos.at(0), pos.at(1))
   }
   ```

   Make it:

   ```typ
   let (name, body) = if pos.len() == 0 {
     (none, [])
   } else if pos.len() == 1 {
     (none, pos.at(0))
   } else {
     (pos.at(0), pos.at(1))
   }
   ```

   `[]` — empty content, NOT `none`. Everything downstream (`_derived-title`,
   `_outbound`, `_flatten`, `_own-cited-keys`, `_std-footnotes`) is written
   against content and already handles an empty body; `none` would reach
   `.children` and fail.

4. Update the comment block directly above the assertion at site 1. It
   currently explains the variadic sink with "a positional parameter cannot
   carry a default in Typst, and `#idea[body]` has to be callable with no name
   at all." Keep that reason and add the second one — the sink is also what
   lets the body itself be absent. Follow the project's comment style in
   `CLAUDE.md`: describe the present, do not narrate the change, no issue ids,
   no "used to".

5. At site 3, widen the units fixture. The heading and its explanatory comment
   say "the two legal positional shapes"; there are now three. Rewrite the
   heading to `// ---- #idea — the three legal positional shapes still compile
   -----------` (pad or trim the trailing dashes so the line stays within the
   file's existing width) and add a third binding beside `_named` and `_bare`
   inside the same `#context` block:

   ```typ
     let _bodiless = idea(title: [Some Title])
   ```

   Adjust the prose in that comment block so it describes three shapes — a
   name plus a body, a bare body, and named arguments alone — and keep its
   existing final point that a third positional is a manual VERIFY because
   Typst cannot catch a panic from inside a document.

6. At site 4, update the readme's signature paragraph so the sink's accepted
   shapes include the empty one. The sentence currently reads "the sink accepts
   the body alone, `(name, body)`, or `(<name>, body)`". Make it also state
   that all positionals may be omitted, giving an unnamed note with an empty
   body, and that this is how a title-only note is written:
   `#idea(title: [hello])`.

## Non-goals

- **Do NOT make a NAMED bodiless note possible.** `#idea("x", title: [T])` has
  one positional and therefore still means "unnamed note whose body is the
  string `x`". Changing what a lone positional means would break every
  existing `#idea[..]` and `#idea("literal text")` call. That gap is real and
  deliberately left alone here.
- Do not add a `name:` named argument, or any other new parameter.
- Do not touch the exclusion gate, the registry write, the rendering branches,
  or anything else in `idea.typ` below the destructuring.
- Do not touch `#window`, `#hyperlink`, `#ideate` or `.marrow.typ`. Their own
  argument sinks are out of scope even though they share the pattern.
- Do not add a demo file under `core/0.1.0/demo/`.

## VERIFY

Run all of these from `core/0.1.0/`.

1. The unit fixtures compile, which is the whole test harness — `assert.eq`
   failing the compile with a line number is the runner:

   ```
   just test
   ```

   Expect it to end with `units OK`.

2. The new shape actually renders rather than merely type-checking. Write a
   scratch file OUTSIDE the repository, at `/tmp/rookery-bodiless.typ`:

   ```typ
   #import "/src/lib.typ": idea, rookery
   #show: rookery
   #idea(title: [hello])
   #idea("after")[A note following a bodiless one.]
   ```

   and compile it:

   ```
   typst compile --features html --root . --format pdf /tmp/rookery-bodiless.typ /dev/null
   ```

   Expect a clean compile with no panic and no warning.

3. The arity guard still rejects three positionals. Add a third positional to
   the scratch file above (`#idea(<a>, [b], [c])`), re-run the same `typst
   compile` command, and confirm it FAILS with the package's message naming
   "a third positional is silently the one that gets dropped". Then remove
   that line again.

4. The readme states the new shape:

   ```
   rg -n 'idea\(title: \[hello\]\)' readme.md
   ```

   Expect at least one hit.