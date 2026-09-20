---
id: rk-document-content-derived-note-names-5d5d62f8
short-id: 5d
title: Document content-derived note names
priority: 2
labels:
- fix-content-derived-names
deps:
- blocked-by:rk-name-a-titleless-note-from-its-content-8ef775a9
closed: true
---
Touches: core/0.1.0/readme.md, core/0.1.0/src/ideate.typ, naming.md, generating-idea-names.md

`@rookery/core` now names a titleless note from its own content rather than
from a container ordinal. Two prose files still describe the old scheme and
will teach a reader something false.

## 1. `core/0.1.0/readme.md`

Two sections document how an automatic id is produced. Anchors, run from
`/home/lox/code/_fcl/rookery/core/0.1.0`:

```
rg -n '^## Flat ids, and why' readme.md
rg -n '^## Unnamed notes' readme.md
```

One hit each — `readme.md:1038` and `readme.md:1047` at filing.

Rewrite the second so it describes the ladder as it now stands:

1. a pinned name, `#idea(<etal>, ..)`, wins outright
2. otherwise a slug of the title, capped at 60 characters, with a numeric
   suffix when two titles slug the same
3. otherwise a slug of the BODY, capped at 16 characters, plus `-` and three
   base36 characters of a digest of the note's own content — for example
   `idea:lean-io-uring-4m3`
4. otherwise the build fails, asking for a name or a title

Say what rung 3's slug does, because an author will see the results and wonder:
a body beginning with a bare URL is slugged from the URL's TAIL rather than its
head (so `https://anil.recoil.org/projects/unikernels` reads `unikernels`, not
`https-anil-recoil`); leading stopwords are dropped; a leading `https-`,
`http-` or `www-` is stripped; and words are never cut in half.

Say the consequence plainly, because it is the thing that bites: **a titleless
note's id changes when its body is edited.** Pinning a name is how an author
opts out, and that is what rung 1 is for.

Check the surrounding prose for anything else describing a counter, an ordinal,
a container, or an id shaped `<page>-<n>`:

```
rg -n 'ordinal|container|counter' readme.md
```

and correct each hit that is about naming. Some hits will be about other
machinery — read before editing.

## 2. `naming.md` at the repository root

`/home/lox/code/_fcl/rookery/naming.md` documents the container-ordinal
algorithm step by step, including a section marked as the open bug. Its
replacement, `generating-idea-names.md`, sits beside it and describes the
current design.

Do NOT delete `naming.md` — it is the record of why the ordinal scheme failed,
and `convergence-bug.md` refers to it. Add a short note at the very top, before
the first heading's prose, saying that it describes the superseded
container-ordinal scheme and pointing at `generating-idea-names.md` for the
algorithm in use. Two or three sentences; do not annotate every section.

## 3. One stale code comment in `src/ideate.typ`

A comment still describes the deleted container-ordinal mechanism. Anchor, run
from `/home/lox/code/_fcl/rookery/core/0.1.0`:

```
rg -n 'over both a container ordinal' src/
```

One hit at filing, `src/ideate.typ:611`, reading in part "...it wins the id
outright, over both a container ordinal and a derived `doc-title` slug".

There is no container ordinal any more. Rewrite the clause so it describes what
outranks what NOW: a beacon-set id beats a derived slug. Change the comment
only — no code, no logic, nothing else in that file.

## 4. `generating-idea-names.md`

Read it before writing anything above — it is the source of truth for this
change, and the readme should agree with it rather than restate it at length.
If you find a claim in it that the code contradicts, say so in your report
rather than quietly writing something different.

## NON-GOALS

- Do NOT edit any `.typ` file, any `Justfile`, or anything under `demo/`.
- Do NOT delete `naming.md` or `convergence-bug.md`.
- Do NOT rewrite `generating-idea-names.md` wholesale; at most correct a claim
  the code contradicts, and report it.
- Do NOT add issue ids, bird names, branch names or dates to `readme.md`. The
  repo's `CLAUDE.md` forbids them in prose that describes the code.

## VERIFY

1. The readme teaches the current scheme:

   ```
   rg -n 'base36|digest|tail' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   returns hits inside the unnamed-notes section.

2. Nothing in the readme still teaches the ordinal as current behaviour. Read
   every hit of

   ```
   rg -n 'ordinal|container ordinal' /home/lox/code/_fcl/rookery/core/0.1.0/readme.md
   ```

   and confirm each is either absent or describing something other than naming.

3. `naming.md` announces its own supersession:

   ```
   rg -n 'generating-idea-names' /home/lox/code/_fcl/rookery/naming.md
   ```

   returns at least one hit.

4. The package still builds — prose birds break code more often than expected:

   ```
   cd /home/lox/code/_fcl/rookery/core/0.1.0 && just test
   ```

   prints `units OK`.