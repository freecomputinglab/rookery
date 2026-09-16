---
id: rk-reject-extra-positional-args-in-idea-751d4989
short-id: '75'
title: 'Reject extra positional args in #idea'
priority: 2
labels:
- fix-idea-positional-args
deps: []
closed: false
---
`#idea` accepts any number of positional arguments and silently uses only the
first two. Everything from the third onwards is discarded with no error and no
warning, so a note's entire body can vanish from the built site while the build
reports success.

Touches: core/0.1.0/src/idea.typ, core/0.1.0/test/units.typ

## The failure this fixes

`#idea` is variadic. At `core/0.1.0/src/idea.typ:57-62` it reads:

```typst
  let pos = args.pos()
  let (name, body) = if pos.len() == 1 {
    (none, pos.at(0))
  } else {
    (pos.at(0), pos.at(1))
  }
```

The sink exists because three call shapes must all work: `#idea[body]`,
`#idea("name")[body]` and `#idea(<name>)[body]`. With one positional the
argument is the body; with two, they are the name and the body.

With **three** the `else` branch still takes only `pos.at(0)` and `pos.at(1)`,
and `pos.at(2)` is never read. The shape that produces three is an author who
forgot that the title is a named argument:

```typst
#idea(<bh-wifi>, [Wi-Fi])[
  #table(columns: (auto, auto), [Network], [`bh-member`])
]
```

Typst appends a trailing content block as a positional argument, so `pos` here
is `(<bh-wifi>, [Wi-Fi], [#table(...)])`. `#idea` takes `[Wi-Fi]` as the *body*
and throws the table away. The build succeeds. The minted page renders an empty
heading, the intended title as body prose, and no table at all. This happened on
a real site and took a diagnosis session to find, because nothing anywhere
reported a problem.

With **zero** positionals — `#idea(title: [x])`, a note with a title and no body
at all — the `else` branch calls `pos.at(0)` on an empty array. That does fail,
but as a bare Typst index-out-of-bounds error inside package internals, which
tells the author nothing about what they wrote.

The fix is an assert at the top of the function, before either value is used.

## The precedent to copy

`#window` in `core/0.1.0/src/window.typ:143-149` already guards its own sink in
exactly the way wanted here, and is the model to follow for both placement and
message shape:

```typst
  let pos = args.pos()
  assert(
    pos.len() <= 1,
    message: "@rookery/core: #window wants one name or one array of names — "
      + "#window((\"a\", \"b\")), not #window(\"a\", \"b\") — got "
      + str(pos.len()) + " positional arguments.",
  )
```

Note what that message does: it states the rule, shows the correct call beside
the wrong one, and ends with what was actually received. `@rookery/core`'s
convention, documented in the repo's `CLAUDE.md`, is that a guard assert sits at
the top of a function before any use of the guarded value, and that its message
reads `"@rookery/<pkg>: " + <what is wrong> + <how to fix it>`.

## Steps

1. Open `core/0.1.0/src/idea.typ`. Line 57 is `let pos = args.pos()`; lines
   58-62 are the `let (name, body) = ...` destructuring quoted above.

2. Insert an assert **between** line 57 and line 58 — after `pos` is bound, before
   it is destructured — reading:

   ```typst
   assert(
     pos.len() >= 1 and pos.len() <= 2,
     message: "@rookery/core: #idea takes a body, optionally preceded by a "
       + "name — #idea(<x>, title: [T])[body], not #idea(<x>, [T])[body]. "
       + "A title is a named argument; a third positional is silently the "
       + "one that gets dropped — got "
       + str(pos.len()) + " positional arguments.",
   )
   ```

   Do not change the destructuring below it. With the assert in place,
   `pos.len()` is guaranteed to be 1 or 2, which is exactly what the existing
   two branches already handle correctly.

3. Add a comment above the assert saying why the sink cannot just be three named
   parameters — a positional parameter cannot carry a default in Typst, and
   `#idea[body]` has to be callable with no name at all. `#window` carries this
   same explanation at `window.typ:140-142`; write it in your own words rather
   than copying it verbatim. Keep it to two or three lines. The repo's
   `CLAUDE.md` forbids comments that narrate history, name a bird, or record
   that something was once a bug — describe only what is true now.

4. Open `core/0.1.0/test/units.typ` and add a test block confirming the two
   legal shapes still compile and still produce what they did before: one
   `#idea(<some-name>, title: [Some Title])[body text]` and one bare
   `#idea[body text]`. Follow whatever assertion style the surrounding blocks in
   that file already use — it is a compile-time test file where `assert.eq`
   failures fail the compile with a line number, and existing blocks carry a
   short comment above them saying what case they pin. `units.typ:70` and
   `units.typ:429` are existing blocks covering the `#idea("x")[]` empty-body
   case; put the new block near them.

   You **cannot** write a test that asserts the panic fires. Typst has no way to
   catch a panic from inside a document, so a negative case would simply fail the
   build. The negative check is manual and is in VERIFY below.

## Non-goals

- **Do not touch `#hyperlink`** (`core/0.1.0/src/hyperlink.typ:68`), even though
  it uses the same `args.pos()` sink. It is genuinely variadic in a different
  way — it branches on both the count and the *type* of its positionals — so it
  has no fixed maximum to assert against. It is a separate question and not this
  bird's.
- **Do not touch `#window`.** It already has the guard.
- **Do not add a generic shared `_assert-positionals` helper** to
  `core/0.1.0/src/pure.typ`. There is no such helper today and only two call
  sites would use it; a local assert matching `#window`'s is the smaller change.
- **Do not change how `#idea` destructures `pos`,** and do not add support for a
  third positional meaning anything. The title stays a named argument.
- **Do not edit anything under `core/0.1.0/demo/`** or any site that consumes
  the package.

## VERIFY

1. Core's tests still pass. From the repo root:

   ```bash
   cd core/0.1.0 && just test
   ```

   A clean exit is green — there is no separate runner, a passing compile is the
   pass. No existing test or demo in `core/0.1.0/` calls `#idea` with three
   positionals, so nothing should newly fail; if something does, the assert's
   bounds are wrong, not the call site.

2. The bad shape now fails loudly. Write this file to
   `/tmp/idea-positional-check.typ`:

   ```typst
   #import "src/lib.typ": *
   #idea(<x>, [A Title])[body]
   ```

   Then, from `core/0.1.0`:

   ```bash
   typst compile --features html --root . --format pdf /tmp/idea-positional-check.typ /dev/null
   ```

   This **must fail**, and the error text must contain
   `@rookery/core: #idea takes a body`. If it compiles successfully, the assert
   is not being reached.

   The exact `#import` line may need adjusting to match how `core/0.1.0/test/units.typ`
   imports the package — check its first few lines and mirror them.

3. The good shape still works. Change that same file to
   `#idea(<x>, title: [A Title])[body]` and re-run the same command. It must now
   compile with no error.