---
id: rk-drop-tracker-ids-from-shipped-comments-b0162a03
short-id: b01
title: Drop tracker ids from shipped comments
priority: 2
labels:
- drop-tracker-ids
deps: []
closed: false
---
This project's `CLAUDE.md` gives two rules this bird enforces: "**No issue ids.**
Never name a bird, a bookmark or a branch. The argument for a line has to stand
on its own, because most readers of it have no access to the tracker and no
interest in one." And: "**Keep the measurement, drop the lab notebook.**"

Three files carry tracker identifiers or narrated incident history in comments
that a stranger reads. Two of them ship in the repository a reader clones.

Touches: core/0.1.0/demo/rheo/check.sh, core/0.1.0/demo/pure/Justfile, core/0.1.0/demo/pure/naming.typ, Justfile

## Site one: tracker ids in the rheo demo's check script

Anchor — two hits, in `core/0.1.0/demo/rheo/check.sh` (lines 285-286 as of
filing), inside a comment block:

```
rg -n 'rheo-cli-input-flag-q12|rheo-toml-inputs-table-rih' /home/lox/code/_fcl/rookery
```

The comment explains why a case cannot be covered from this demo and names two
rheo tracker ids as "what will make it reachable". Keep the explanation — the
constraint is real and a reader needs it. Remove the two ids and rewrite the
clause so it stands on its own: the case needs rheo to forward `--input` to the
compile, which it does not do today.

## Site two: a decision id in the pure demo's Justfile

Anchor — one hit, in `core/0.1.0/demo/pure/Justfile` (line 4 as of filing),
inside the comment block above the `watch` recipe:

```
rg -n 'epic decision 8' /home/lox/code/_fcl/rookery
```

The line reads "`--features html` is required always (epic decision 8) — see
`root.typ`." The parenthetical is a tracker reference. Delete it. The pointer to
`root.typ` stays, and so does the claim, which is true and load-bearing.

## Site three: a narrated CI incident in the repository root Justfile

Anchor — one hit, in the repository root `Justfile` (line 36 as of filing),
inside the comment block above the `check-versions` recipe:

```
rg -n '32126839338' /home/lox/code/_fcl/rookery
```

The `check-versions` comment block runs to roughly 40 lines and includes: two
CI run identifiers; a paragraph headed "GREP AND SED, NOT RIPGREP, and that is
the whole reason this recipe reads the way it does"; and a list headed "THE
THREE rg FEATURES THAT HAD TO BE REPLACED, so nobody reintroduces them", with
three before-and-after translations.

The durable fact is small and worth keeping: **this recipe uses `grep` and `sed`
rather than `rg` because `rg` is not on the CI runner image, and a lint that
only runs on the author's machine is not a lint.** One or two sentences.

Everything else in that span is narration of a debugging session — the run ids,
the "had to be replaced" framing, the three translations. Cut it.

The same block's three numbered rules about what `check-versions` checks
(a spec naming its own package, a spec naming another package that is here,
the `<name>/<version>/` layout) are a present-tense description of what the
recipe does and they stay — though the clause "all of them things that have
gone wrong at least once" is lab notebook and goes.

While in this file, the `bump` recipe below carries two `MEASURED:` annotations
naming a specific version cut ("cutting rookery and rookery-search 0.3.0 ->
0.4.0 is 84 literal specs" and "MEASURED on the 0.3.0 -> 0.4.0 cut: 9 such
references"). These are measurements that justify the recipe existing, so under
this project's rules the NUMBER stays. Drop the version pair — `0.3.0` and
`0.4.0` are versions that do not exist in this repository — and keep the counts:
a version cut rewrites on the order of 84 literal specs by hand, and 9
path-form references that `check-versions` cannot see.

## Site four: a comment in the pure demo describing a naming scheme that is gone

Anchor — one hit, in `core/0.1.0/demo/pure/naming.typ` (line 33 as of filing),
in the comment above the `#idea("nn-parent", ..)` fixture:

```
rg -n 'Under the ordinal-' /home/lox/code/_fcl/rookery/core/0.1.0/demo
```

The comment reads: "Under the ordinal-based scheme this took its parent's own
id with a counter appended (`nn-parent-1`); it now derives an id from its own
body like any other titleless note, and carries none of its parent's name."

The first clause describes a scheme the package does not use. Keep the
present-tense half — a nested titleless idea derives its name from its own body
and carries none of its parent's — and drop the comparison.

Note that `demo/pure/Justfile`'s check for this fixture asserts the ABSENCE of
the old shape (`if grep -qE 'idea:nn-parent-[0-9]'`), which is a legitimate
assertion about current behaviour. Leave that check alone; only the comment
changes.

## Non-goals

- Do NOT change any recipe body, shell logic, assertion, or command in any of
  the three files. This bird edits comments only. The `check-versions` and
  `bump` recipes in particular are intricate and are not being touched.
- Do NOT delete the `check-versions` comment block wholesale. It explains a
  non-obvious `grep`/`sed` construction that a reader would otherwise "fix" back
  into `rg`.
- Do NOT go hunting for tracker ids elsewhere. These three sites are the scope;
  a repository-wide sweep is a different change.
- Do NOT touch anything under `.birds/`.

## VERIFY

1. `rg -n 'rheo-cli-input-flag-q12|rheo-toml-inputs-table-rih|epic decision|32126839338|32127008271' /home/lox/code/_fcl/rookery --glob '!.birds/**'`
   prints nothing.
2. `rg -n '0\.3\.0|0\.4\.0' /home/lox/code/_fcl/rookery/Justfile` prints
   nothing.
3. From the repository root, `just check-versions` passes (prints
   `check-versions OK across N manifests`).
4. From `core/0.1.0/demo/pure`, `just build` passes (prints `demo/pure OK`).
5. `rg -n 'grep' /home/lox/code/_fcl/rookery/Justfile` still prints several hits
   — the recipe itself is untouched.