---
id: rk-repin-ci-to-rheo-0-6-3-73cf041d
short-id: '73'
title: Repin CI to rheo 0.6.3
priority: 3
labels:
- fix-rheo-path-floor
deps: []
closed: false
---
Every CI run on this repository's `0.1.0` branch has failed since the repo was
split out, at the same step and for the same reason. This bird repins CI to the
rheo release that fixes it.

Touches: .github/workflows/check.yml

## Why

Every demo and example project here resolves the `@rookery` namespace out of
this checkout with a `path` source:

```toml
[packages.rookery]
path = "../../../.."
```

`path` is a rheo config key that landed AFTER the `v0.6.2` release — rheo PR
#171, "Allow local custom namespaces". `.github/workflows/check.yml` installs
the pinned `v0.6.2` release tarball, which has no `path` arm in its namespace
parser, so the first step that runs `rheo compile` dies before compiling
anything:

```
Error: ProjectConfig { message: "invalid rheo.toml: [packages.rookery]: set one of `repo` (a repository at a ref) or `releases` (a releases host)\n" }
```

A developer machine hides this: a locally built rheo from `main` HAS `path` and
still reports `rheo 0.6.2`, because rheo's own version was never bumped after
the release. So the demos build here and can never build in CI.

The fix is a rheo release carrying #171, cut by a companion bird in the `rheo`
repository under the same label, `fix-rheo-path-floor`. THIS BIRD CANNOT START
UNTIL `v0.6.3` HAS ACTUALLY PUBLISHED, because it pins that release's asset
digest, which does not exist before then. It is parked for that reason; unpark
it with `bd idea unpark <this bird's id>` once `gh release view v0.6.3 --repo
freecomputinglab/rheo` succeeds.

## Steps

All edits are in `/home/lox/code/_fcl/rookery/.github/workflows/check.yml`.

1. Fetch the new asset's digest. The exact asset name matters — matching on
   `linux-gnu.zip` alone also catches the aarch64 build — and `digest` comes
   back `sha256:`-prefixed, which `sha256sum -c` will not accept:

   ```bash
   gh release view v0.6.3 --repo freecomputinglab/rheo --json assets \
     --jq '.assets[] | select(.name == "rheo-x86_64-unknown-linux-gnu.zip") | .digest' \
     | cut -d: -f2
   ```

2. Line 82: replace the `sha256="…"` value with what step 1 printed. The
   current value is
   `ab71c5e4fea2ff05381f19e9ff11003e311e03974dcfd663a52b05569eceaa71`.

3. Line 84: change the download URL's tag from `v0.6.2` to `v0.6.3`.

4. Line 69: the step is named `Install rheo 0.6.2 (the declared min_version
   floor)`. Rename it `Install rheo 0.6.3 (the floor the demo projects need)`.
   The parenthetical has to change with the number: the packages' declared
   `min_version` is staying at `0.6.2`, so calling 0.6.3 "the declared
   min_version floor" would be false.

5. Lines 72-73 and 76: the comment above the digest says "Digest of the v0.6.2
   … asset, published 2026-08-30" and the read-it-back command names
   `v0.6.3`'s predecessor. Update both to `v0.6.3` and to that release's own
   publication date.

6. Line 89: the trailing comment reads `# must print: rheo 0.6.2`. Change it to
   `rheo 0.6.3`.

7. Lines 38-68 are the comment block arguing that CI pins the OLDEST rheo the
   manifests declare, "so that the DECLARED floor is the floor actually
   tested". That argument no longer holds on its own and must be extended, not
   deleted. After the `0.6.2:` paragraph that ends at line 64, add one more
   paragraph in the same shape, saying: 0.6.3 is where a namespace could first
   resolve from a directory on disk, which is what every `[packages.rookery]
   path = "../../../.."` in this repo's demos and examples asks for — so the
   version CI installs is now set by the DEMO PROJECTS' floor rather than the
   packages' `min_version`, which stays at 0.6.2 because no package here
   reaches for a 0.6.3 surface. Keep the existing 0.6.0 / 0.6.1 / 0.6.2
   paragraphs as they are; they still explain the packages' own floor. Follow
   this repo's comment style (`CLAUDE.md`, "Comment style"): describe the
   present, name no bird, no branch and no PR number.

## Non-goals

- **Do not change any `min_version` in any `typst.toml`.** All eight packages
  declare `min_version = "0.6.2"` and that is still true — `path` is a project
  config key, not a package surface, so no package here needs 0.6.3.
- **Do not touch the `version = "…"` key in any `rheo.toml`.** That key is the
  manifest version, not a floor checked against the running binary: the demos
  here currently declare everything from `0.1.0` (`pinboard/0.1.0/demo/rheo`)
  to `0.6.2` (`core/0.1.0/demo/rheo`) and all of them compile under one rheo.
  Bumping them changes nothing and is churn in eight files.
- **Do not remove or rewrite the `[packages.rookery]` tables.** Dropping them
  would let the namespace resolve from the Typst package cache and would make
  CI pass at 0.6.2 — and it would silently flip the built packages
  (`search`, `todos`, `slipshow`) from their `[tool.rheo.source.html]` asset
  list to their `[tool.rheo.html]` bundle, which is the other shipping shape,
  and give up the multi-checkout safety the tables exist for.
- **Do not change the pinned Typst version** (0.15.1, lines 30-36). It is
  unrelated to this failure.
- **Do not push.** The operator pushes.

## VERIFY

```bash
cd /home/lox/code/_fcl/rookery
rg -n '0\.6\.2' .github/workflows/check.yml
```

Every remaining hit must be inside the packages' `min_version` prose in the
comment block — no hit may be in the install step's name, URL, digest comment
or version echo.

Then prove the pin itself is good, exactly as CI will:

```bash
cd /tmp
sha256="<the value now on line 82>"
curl -fsSL -o rheo.zip \
  https://github.com/freecomputinglab/rheo/releases/download/v0.6.3/rheo-x86_64-unknown-linux-gnu.zip
echo "$sha256  rheo.zip" | sha256sum -c -
```

`sha256sum -c -` must print `rheo.zip: OK`. That is the whole contract this
step has with the release: right tag, right asset, right bytes.

Note for a NixOS machine: the downloaded binary will not RUN locally without
patching, because it is a generic-linux dynamically linked executable. Do not
try to work around that — verifying the digest is what this bird needs, and the
binary only has to run on the CI runner.