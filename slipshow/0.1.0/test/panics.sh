#!/usr/bin/env sh
# Proves a panic where Typst has no `try`/`catch`: a case can only be shown
# to panic by a compile that fails. One case per file — a panic aborts the
# whole compile, so a second case in the same file would never run.
set -e

expect_panic() {   # $1 = file, $2 = substring the message must contain
  if out=$(typst compile --features html --root . --format pdf "$1" /dev/null 2>&1); then
    echo "FAIL: $1 compiled, expected a panic"; exit 1
  fi
  case "$out" in *"$2"*) ;; *) echo "FAIL: $1 panicked without '$2':"; echo "$out"; exit 1;; esac
}

expect_panic test/panic-enter.typ "scroll"
expect_panic test/panic-neither.typ "exactly one of \`slips\` or \`tags\`"
expect_panic test/panic-both.typ "exactly one of \`slips\` or \`tags\`"
expect_panic test/panic-order.typ "conflict"
