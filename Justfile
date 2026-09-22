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

# A STABILIZED PACKAGE IS AUTHORED ON MAIN, and reaches every other line by
# inheritance rather than by an edit made there. `main` carries the packages that
# have stabilized — `core` alone for now, the rest being alpha — and is the line
# publish-packages.yml cuts releases from; `dev` carries all nine and descends
# from main, so the stable ones it holds are main's, unmodified.
#
# That is what keeps a rebase cheap. While it holds, moving dev onto a new main is
# a fast-forward; the moment a commit on dev edits a package that main also has,
# the same rebase must merge two divergent copies of it, and every commit in
# between inherits the conflict. This recipe states that invariant as a check, so
# the failure lands on the commit that breaks it rather than on whoever rebases
# next.
#
# THE PACKAGE LIST COMES FROM MAIN, not from a literal here, so a package
# graduating out of alpha is covered the moment it lands there and this recipe
# needs no edit. A package that is alpha — here but not on main — is untouched by
# this, which is the point: dev is where it is still being written.
#
# `git`, NOT `jj`, because the CI runner has only the former — the same reason
# `check-versions` above is written with grep and sed rather than rg.
#
# BASE is a revision, not a branch name, so CI can hand it the `FETCH_HEAD` of a
# shallow fetch: `git diff` compares trees and needs no common history, which a
# depth-1 checkout does not have.
check-release-parity BASE="main":
    #!/usr/bin/env bash
    set -euo pipefail
    base='{{BASE}}'
    if ! git rev-parse --verify --quiet "$base^{commit}" >/dev/null; then
        echo "check-release-parity: no such revision '$base'"
        exit 1
    fi
    # `<pkg>/<version>/typst.toml` is the layout (CLAUDE.md), so the first path
    # component of every manifest on BASE is a released package's name.
    pkgs=$(git ls-tree -r --name-only "$base" \
        | sed -n 's|^\([^/]*\)/[^/]*/typst\.toml$|\1|p' | sort -u)
    if [ -z "$pkgs" ]; then
        echo "check-release-parity: $base holds no packages — nothing to compare"
        exit 1
    fi
    fail=0
    for pkg in $pkgs; do
        if ! git diff --quiet "$base" -- "$pkg/"; then
            echo "$pkg/ differs from $base:"
            git diff --stat "$base" -- "$pkg/"
            fail=1
        fi
    done
    if [ "$fail" -ne 0 ]; then
        echo
        echo "Author changes to a stabilized package on main, then rebase this line onto it."
        echo "check-release-parity: FAILED"
        exit 1
    fi
    echo "check-release-parity OK — $(echo "$pkgs" | tr '\n' ' ')matches $base"

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
