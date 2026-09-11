---
id: rk-hoist-the-tokenizer-s-two-regexes-3455a62d
short-id: '34'
title: Hoist the tokenizer's two regexes
priority: 4
labels:
- chore-search-review
deps: []
closed: false
---
`_tokenize` builds a fresh `regex("^[0-9]+$")` for every token of every note's
body. The corpus pass is the most expensive thing this package does at build
time, and this is a regex compile per word.

Touches: /home/lox/code/_fcl/rookery/search/0.1.0/src/compress.typ

## What is wrong

`/home/lox/code/_fcl/rookery/search/0.1.0/src/compress.typ` lines 86-105:

```typ
#let _tokenize(body) = {
  let out = ()
  for m in lower(body).matches(regex("\\.?[\\p{L}\\p{N}][\\p{L}\\p{N}.\\-]*")) {
    let t = m.text
    while t.len() > 0 and (t.ends-with(".") or t.ends-with("-")) {
      t = t.slice(0, t.len() - 1)
    }
    if t.clusters().len() < 3 { continue }
    if t.contains(regex("^[0-9]+$")) { continue }
    if t in _stopwords { continue }
    out.push(t)
  }
  out
}
```

Two `regex(..)` constructions, both inside a function that runs once per note
per corpus pass:

- the tokenizer pattern, built once per BODY, and
- `regex("^[0-9]+$")`, built once per TOKEN — which on a 320-note rookery is
  tens of thousands of constructions of one constant pattern.

`_compress-corpus` calls `_tokenize` over every body (line 124), and on the
inline index path that whole pass can run per output page. The file's own header
records what this pass costs: about 118 ms a page on a 200-note rookery with 40
emitting vertebrae.

Two smaller things in the same function:

- `t.contains(regex("^[0-9]+$"))` uses a SUBSTRING test with an anchored
  pattern to ask a whole-string question. It works, but `t.match(..) != none` is
  what that question is spelled as.
- the `while` loop's `t.len()`/`t.slice` are byte offsets, which the comment at
  lines 92-95 correctly justifies (the two stripped characters are ASCII). Leave
  that exactly as it is.

Line numbers are as of filing. If they have shifted, match the quoted text.

## Decisions already made — do not re-derive

- **Hoist both patterns to module constants**, beside `_stopwords`. A Typst
  `regex(..)` value is an ordinary value and can be bound with `#let` at module
  scope; `_stopwords` at lines 37-58 is already built once that way, for the
  same reason.
- **Do not change what the patterns match.** The tokenizer's rule — split on
  every non-alphanumeric cluster except `.` and `-`, keep a leading `.`, strip a
  trailing `.`/`-` — is a contract with the reader typing in the search box, and
  the comment at lines 60-85 records the closed set. A change there silently
  changes what a build kept and what a query can find.
- **Keep the doubled backslashes.** The comment at lines 88-89 records why:
  Typst rejects `\.` and `\p` as string escapes, so the source must double them
  and the engine sees `\.?[\p{L}\p{N}][\p{L}\p{N}.\-]*`.

## Steps

1. In `/home/lox/code/_fcl/rookery/search/0.1.0/src/compress.typ`, directly
   above `_tokenize`, add the two constants:

   ```typ
   // The token pattern and the bare-digit test, built ONCE rather than per body
   // and per token: this pass runs over every note's body, and on the inline
   // index path over every note's body per output page.
   //
   // Doubled backslashes: Typst rejects `\.` / `\p` as unknown STRING escapes, so
   // the regex the engine sees is `\.?[\p{L}\p{N}][\p{L}\p{N}.\-]*`.
   #let _TOKEN-RE = regex("\\.?[\\p{L}\\p{N}][\\p{L}\\p{N}.\\-]*")
   #let _DIGITS-RE = regex("^[0-9]+$")
   ```

   Move the doubled-backslash sentence out of `_tokenize`'s own comment block
   (lines 88-89) so it sits with the pattern it describes and is not stated
   twice.

2. In `_tokenize`, use them:
   - `for m in lower(body).matches(_TOKEN-RE) {`
   - `if t.match(_DIGITS-RE) != none { continue }`

3. Leave every other line of `_tokenize` untouched, including the byte-offset
   `while` loop and the cluster-counting length floor.

## Do NOT

- Do not change the pattern strings, the length floor, the stopword test, or
  their order. The order is load-bearing for cost: the cheap cluster count runs
  before the regex and the dictionary test runs last.
- Do not touch `_stopwords`, `_compress-corpus`, or the df/tf arithmetic.
- Do not add a second exception character to the token pattern.
- Do not reword comments beyond the one sentence moved in step 1 — a separate
  bird covers this package's comment prose.
- Do not edit anything under `test/`.

## VERIFY

All three are green today and must stay green:

```sh
cd /home/lox/code/_fcl/rookery/search/0.1.0 && just test
cd /home/lox/code/_fcl/rookery/search/0.1.0 && just parity
cd /home/lox/code/_fcl/rookery/search/0.1.0/demo/rheo && just check
```

Expected: `pass 123` / `fail 0`; six `OK` lines from parity; `demo/rheo OK`.

The decisive check is the demo, which builds a real index and asserts on it —
its `check.sh` prints a `label: titleless note ships as "Marginalia accumulate
faster than ..."` line and a `label: 'marginalia' ranks [...]` line, both of
which read the compressed field this function feeds. If the tokenizer's behaviour
changed at all, the island's terms change and those assertions move.