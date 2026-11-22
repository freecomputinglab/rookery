build:
    #!/usr/bin/env bash
    set -euo pipefail
    find . -mindepth 2 -name Justfile -printf '%h\n' | while read -r dir; do
        echo "==> $dir"
        (cd "$dir" && just)
    done

# A Typst import spec has to be a literal, so `@rookery/<pkg>:<x.y.z>` is written
# out by hand in every readme, every doc comment, every `.marrow.typ` and every
# cross-package import — and nothing but this recipe checks any of them against
# the manifest that defines the version. CI derives the release tag from
# `typst.toml`, so a version directory cut by copying and bumping only the
# manifest publishes a package whose own marrow imports its PREDECESSOR: it
# resolves to the old code where that is installed and fails outright where it
# is not.
#
# Three rules:
#   - a spec naming its OWN package must name the version its manifest declares;
#   - a spec naming ANOTHER package THAT IS HERE must name a version that exists;
#   - `<name>/<version>/` is the layout (CLAUDE.md), so the directory must match.
#
# The second rule is deliberately scoped to packages present in the tree. A
# branch can hold one package without the siblings its readme points readers
# to, and a spec naming a package that is not here at all is unverifiable
# rather than wrong — so it prints and does not fail. A package that IS here at
# a DIFFERENT version is the drift this rule exists to catch, and still fails.
#
# Hidden files are searched on purpose: `.marrow.typ` carries the import that
# mints every page, and it is the one place a stale spec silently produces no
# output at all. `grep -r` reads dotfiles by default, so this needs no flag for
# them — unlike the `rg` this recipe used to be written with.
#
# This recipe uses `grep` and `sed` rather than `rg` because `rg` is not on
# the CI runner image, and a lint that only runs on the author's machine is
# not a lint.
check-versions:
    #!/usr/bin/env bash
    set -euo pipefail
    fail=0
    for manifest in */*/typst.toml; do
        dir="${manifest%/typst.toml}"
        name=$(sed -n 's/^name = "\([^"]*\)".*/\1/p' "$manifest")
        version=$(sed -n 's/^version = "\([^"]*\)".*/\1/p' "$manifest")
        if [ "$dir" != "$name/$version" ]; then
            echo "$manifest: declares $name $version but lives at $dir/"
            fail=1
        fi
        while IFS=: read -r file line rest; do
            read -r pkg ver <<<"$rest"
            if [ "$pkg" = "$name" ]; then
                if [ "$ver" != "$version" ]; then
                    echo "$file:$line: @rookery/$pkg:$ver, but $manifest declares $version"
                    fail=1
                fi
            elif [ ! -d "$pkg" ]; then
                echo "$file:$line: @rookery/$pkg:$ver — $pkg/ is not in this repo, spec not checked"
            elif [ ! -d "$pkg/$ver" ]; then
                echo "$file:$line: @rookery/$pkg:$ver, but $pkg/$ver/ is not in this repo"
                fail=1
            fi
        # `grep -o` prints ONE match per output line, so each line is exactly
        # `path:line:@rookery/pkg:x.y.z` and the `sed` turns the `:@rookery/pkg:` in the
        # middle into `:pkg ` — giving `path:line:pkg x.y.z`, which is what the
        # `IFS=:` read above splits. Not `/g`: there is only ever one.
        #
        # `{ grep || true; }` INSIDE the braces, not after the pipeline: grep exits
        # 1 when a package contains no spec at all (which is legal — a pure-CSS
        # package could), and `set -o pipefail` above would take that as failure.
        done < <({ grep -rEon --binary-files=without-match \
            --exclude-dir=dist --exclude-dir=node_modules \
            --exclude-dir=.direnv --exclude-dir=build \
            '@rookery/[a-z-]+:[0-9]+\.[0-9]+\.[0-9]+' "$dir" || true; } \
            | sed 's|:@rookery/\([a-z-]*\):|:\1 |')
    done
    if [ "$fail" -ne 0 ]; then
        echo "check-versions: FAILED"
        exit 1
    fi
    echo "check-versions OK across $(ls -d */*/typst.toml | wc -l) manifests"

# A STABILIZED PACKAGE VERSION IS AUTHORED ON MAIN, and reaches every other line
# by inheritance rather than by an edit made there. `main` carries the versions
# that have stabilized — `core/0.1.0` alone for now — and is the line
# publish-packages.yml cuts releases from; `dev` descends from main and carries
# every package, including the next version of a stable one (`core/0.1.1`), so
# the stable versions it holds are main's, unmodified.
#
# That is what keeps a rebase cheap. While it holds, moving dev onto a new main is
# a fast-forward; the moment a commit on dev edits a version directory that main
# also has, the same rebase must merge two divergent copies of it, and every
# commit in between inherits the conflict. Run this before pushing dev; CI does
# not, since it checks only pull requests into main, where changing a released
# version belongs.
#
# THE VERSION LIST COMES FROM MAIN, not from a literal here, so a version released
# there is covered the moment it lands and this recipe needs no edit. A version
# directory only here — an alpha package, or the next version of a stable one — is
# untouched by this, which is the point: dev is where it is still being written.
check-release-parity BASE="main" REV="@":
    #!/usr/bin/env bash
    set -euo pipefail
    base='{{BASE}}'
    rev='{{REV}}'
    # `<pkg>/<version>/typst.toml` is the layout (CLAUDE.md), so the directory of
    # every manifest on BASE is a released package version.
    dirs=$(jj file list -r "$base" --ignore-working-copy 'glob:*/*/typst.toml' \
        | sed -n 's|^\([^/]*/[^/]*\)/typst\.toml$|\1|p' | sort -u)
    if [ -z "$dirs" ]; then
        echo "check-release-parity: $base holds no packages — nothing to compare"
        exit 1
    fi
    fail=0
    for dir in $dirs; do
        if [ -n "$(jj diff --from "$base" --to "$rev" --name-only "$dir")" ]; then
            echo "$dir/ differs from $base:"
            jj diff --from "$base" --to "$rev" --stat "$dir"
            fail=1
        fi
    done
    if [ "$fail" -ne 0 ]; then
        echo
        echo "Author changes to a stabilized version on main, then rebase this line onto it."
        echo "check-release-parity: FAILED"
        exit 1
    fi
    echo "check-release-parity OK — $(echo "$dirs" | tr '\n' ' ')matches $base"

# Real-engine tests, across WebKit (the Safari engine), Chromium and Gecko.
# One runner per file under a package's `test/browser/`, so a package adds a
# suite by adding a file and nothing here changes. Needs the root devShell for
# the browser builds; every `just test` in this repo stays runnable without it.
#
# The suites assert against a package's BUILT demo, so run that package's
# `just check` first — each suite says so by name if the build is missing.
browser:
    #!/usr/bin/env bash
    set -euo pipefail
    shopt -s nullglob
    found=0
    for f in */*/test/browser/*.mjs; do
        echo "==> $f"
        node "$f"
        found=1
    done
    if [ "$found" -eq 0 ]; then
        echo "browser: no suites yet — nothing to run"
    fi

# Cuts `<pkg>/<new>/` from `<pkg>/<old>/` and rewrites every version this repo
# writes out by hand, so a release is one command rather than dozens of edits
# that `check-versions` can only catch AFTERWARDS. A version cut rewrites on
# the order of 84 literal specs by hand, 42 of them doc comments in one file.
#
# `.github/workflows/check.yml` is rewritten too, and that is the whole reason
# this recipe cannot be a one-line `sed`. `check-versions` walks `*/*/` only, so
# the CI file is invisible to it while hardcoding the version PATHS it tests
# (`cd <pkg>/<version> && just test`, the package-cache assertion, `demo/pure`).
# A cut that misses it leaves CI exercising the PREVIOUS version and reporting
# green for code nobody ran.
#
# The OLD directory is never touched: every published version stays in the tree,
# because a release tag is cut per manifest and an edit to an already-released
# directory can never be published again.
#
# Sibling pins are PRINTED, not rewritten. `@rookery/a:1.0.0` inside package `b` is
# legal as long as `a/1.0.0/` exists, so whether a sibling should follow the bump
# is a judgement per package — the demo of an unrelated package may well want to
# stay where it is.
bump PKG OLD NEW:
    #!/usr/bin/env bash
    set -euo pipefail
    pkg='{{PKG}}'; old='{{OLD}}'; new='{{NEW}}'

    [ -f "$pkg/$old/typst.toml" ] || { echo "bump: no manifest at $pkg/$old/typst.toml"; exit 1; }
    [ -e "$pkg/$new" ] && { echo "bump: $pkg/$new already exists — refusing to overwrite"; exit 1; }

    cp -r "$pkg/$old" "$pkg/$new"
    # Build artifacts are per-package gitignored and must not be carried into a
    # new version: `dist/` is what the manifest publishes, and shipping the OLD
    # build under the NEW version is the one mistake this copy could bake in.
    find "$pkg/$new" -type d \
        \( -name dist -o -name node_modules -o -name .direnv -o -name build \) \
        -prune -exec rm -rf {} +

    # Only specs naming THIS package. A spec naming another package is that
    # package's business (printed at the end).
    grep -rl --binary-files=without-match "@rookery/$pkg:$old" "$pkg/$new" \
        | xargs -r sed -i "s|@rookery/$pkg:$old|@rookery/$pkg:$new|g"

    # Path-form self-references: `rookery/<old>/src/pure.typ` in a comment, `cd
    # rookery-search/<old>` in a readme, "run it from rookery/<old>" in a test
    # fixture's header. `check-versions` reads the `@rookery/pkg:ver` spec form only,
    # so these go stale silently and are found by a reader following one into the
    # PREVIOUS version's file. A version cut leaves on the order of 9 such
    # references across both rookery packages, none of them caught.
    #
    # Directory form ONLY. Prose about what a version DID — "since <old>",
    # "<old>'s breaking change", a `## <old>` release-notes heading — says the old
    # number on purpose and has to survive the bump.
    grep -rl --binary-files=without-match "$pkg/$old" "$pkg/$new" \
        | xargs -r sed -i "s|$pkg/$old|$pkg/$new|g"

    sed -i "s|^version = \"$old\"|version = \"$new\"|" "$pkg/$new/typst.toml"
    sed -i "s|$pkg/$old|$pkg/$new|g" .github/workflows/check.yml

    just check-versions

    # `{ grep || true; }` for the same reason `check-versions` needs it: no
    # sibling pin at all is the common case, and grep's exit 1 would trip `set -e`.
    stale=$({ grep -rn --binary-files=without-match \
        --exclude-dir=dist --exclude-dir=node_modules \
        --exclude-dir=.direnv --exclude-dir=build \
        -e "@rookery/$pkg:$old" -e "$pkg/$old/" . || true; } | grep -v "^\./$pkg/" || true)
    if [ -n "$stale" ]; then
        echo
        echo "Siblings still naming $pkg $old (legal — $pkg/$old/ is still here):"
        echo "$stale"
        echo "Decide per package whether each should follow the bump; this recipe will not."
    fi
