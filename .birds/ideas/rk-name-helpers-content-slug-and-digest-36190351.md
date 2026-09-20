---
id: rk-name-helpers-content-slug-and-digest-36190351
short-id: '361'
title: 'Name helpers: content slug and digest'
priority: 5
labels:
- fix-content-derived-names
deps: []
closed: true
---
Touches: core/0.1.0/src/pure.typ, core/0.1.0/test/units.typ

Add two pure helpers that name a note from its own content. This bird adds
them and tests them. It does NOT wire them into `#idea` — a separate bird does
that, and this one must leave `#idea`'s behaviour exactly as it is.

`src/pure.typ` is the ordering-free half of the package: pure functions of
their arguments, no `state`, no `context`, no `query`. It imports nothing
(`rg -n '^#import' src/pure.typ` printed no hits), so both helpers go there.

## Where

Anchor for the neighbourhood, run from `/home/lox/code/_fcl/rookery/core/0.1.0`:

```
rg -n 'let _id-slug' src/
```

One hit, `src/pure.typ:974`, `#let _id-slug(s, limit: 60) = {`. Put the new
helpers immediately after `_id-slug` ends. If the anchor has moved, search the
package root; if it is gone entirely, stop and report rather than guessing a
location.

`_plain` is the projection the caller will feed these: anchor
`rg -n 'let _plain\(c\)' src/` — one hit, `src/pure.typ:369`.

## 1. `_b36(n, width)`

Renders a non-negative integer as lowercase base36, left-padded with `0` to
exactly `width` characters, keeping the LOW-order digits if it is longer.
Digits are `0123456789abcdefghijklmnopqrstuvwxyz`.

## 2. `_h3(s)`

A three-character base36 digest of a string. djb2 modulo 2147483647:

```typ
#let _h3(s) = {
  let acc = 5381
  for b in array(bytes(s)) { acc = calc.rem(acc * 33 + b, 2147483647) }
  _b36(acc, 3)
}
```

`acc * 33` stays below 2^36 and so never overflows Typst's i64. Typst ships no
hash of its own — neither `std` nor `calc` has one — which is why this is
hand-rolled.

Callers pass a capped string; `_h3` itself does no capping.

## 3. `_name-slug(s, limit: 16)`

Takes already-projected plain text and returns a slug, or `none`.

1. If `s`, after trimming, STARTS WITH `http://` or `https://`, replace `s`
   with that URL's last meaningful path segment before doing anything else.
   Take the leading run of non-whitespace as the URL; strip the scheme; strip
   a trailing `/`; split on `/`, `?` and `#`; drop empty segments; drop a
   trailing `.html`, `.htm`, `.pdf`, `.php`, `.asp` or `.aspx` from each; drop
   segments matching `^[0-9.]+$`; take the last surviving segment, or the
   empty string if none survive.
2. Lowercase. Replace each run of `[^a-z0-9]+` with a single `-`. Trim `-` from
   both ends.
3. Split on `-`. While the first word is in the stopword list below AND more
   than one word remains, drop it.
4. If the first word is `https`, `http` or `www`, drop it. Repeat until the
   first word is none of those.
5. Rejoin with `-`, then take WHOLE WORDS from the start while the result
   stays within `limit` characters. Never truncate mid-word. The first word is
   the exception: if it alone exceeds `limit`, hard-truncate that one word to
   `limit`.
6. Return `none` for an empty result, and `none` if the result matches
   `^[0-9]+$` — the same two rejections `_id-slug` already makes.

Stopword list, leading position only:

```
the a an and or of to in on at is are was were be been it its this that for with as by from
```

Step 1 is load-bearing, not cosmetic. A reading list of bare links is a common
shape, and a URL's distinguishing part is its tail: three notes reading
`https://anil.recoil.org/papers/2024-hope-bastion`,
`https://anil.recoil.org/projects/unikernels` and
`https://anil.recoil.org/ideas/lean-io-uring-backend` all slug to
`https-anil-recoil` left-to-right, and to three distinct names from the tail.

Step 4 is a separate rule from step 1 on purpose: step 1 only fires when the
body BEGINS with a URL, and step 4 catches everything else that still arrives
with a scheme attached.

Write a file header comment for the pair in the style of the file's
neighbours, and follow `CLAUDE.md`'s comment rules — describe the present, no
issue ids, keep a measurement only where it justifies a constant.

## 4. Unit assertions

`test/units.typ` asserts with bare top-level `#assert.eq(..)`; a failing
compile with a line number is the whole harness. Anchor for the idiom:
`rg -n '_norm\("etal"\)' test/` — one hit, `test/units.typ:32`.

Add `_name-slug`, `_h3` and `_b36` to the import list. Anchor:
`rg -n 'import "/src/lib.typ"' test/` — one hit, `test/units.typ:19`,
`#import "/src/lib.typ": (`. The list is alphabetical-ish; keep its shape.

Add at least these assertions:

```typ
#assert.eq(_name-slug("https://anil.recoil.org/papers/2024-hope-bastion"), "2024-hope-bastion")
#assert.eq(_name-slug("https://anil.recoil.org/projects/unikernels"), "unikernels")
#assert.eq(_name-slug("https://terrytao.wordpress.com/2026/09/11/a-severe-misalignment/"), "a-severe")
#assert.eq(_name-slug("The scorer lives in score.typ"), "scorer-lives-in")
#assert.eq(_name-slug("https www example"), "example")
#assert.eq(_name-slug(""), none)
#assert.eq(_name-slug("12345"), none)
#assert.eq(_h3("abc").len(), 3)
#assert.eq(_h3("abc"), _h3("abc"))
#assert.eq(_b36(0, 3), "000")
```

Work out the expected strings by running the rules above by hand and make the
assertions match your implementation; if one of the literals here disagrees
with a faithful reading of steps 1-6, TRUST THE STEPS and change the literal,
noting which one you changed in your report.

## NON-GOALS

- Do NOT touch `src/idea.typ`, `src/state.typ` or `src/transclusion.typ`. No
  wiring, no call sites, no deletions. Another bird does that and will
  conflict with you.
- Do NOT change `_id-slug`. Rung 2 of the naming ladder keeps using it with its
  existing 60-character cap.
- Do NOT add a stopword list to `_id-slug` or otherwise alter title slugging.
- Do NOT add a `dist/` build step. `core` is a pure-Typst package.

## VERIFY

```
cd /home/lox/code/_fcl/rookery/core/0.1.0 && just test
```

prints `units OK`. That recipe runs two `typst compile` fixtures, and a failed
`assert.eq` fails the compile with a line number.

Then confirm the helpers are reachable from the package entrypoint:

```
rg -n '_name-slug|_h3|_b36' /home/lox/code/_fcl/rookery/core/0.1.0/src/pure.typ
```

prints hits for all three definitions.