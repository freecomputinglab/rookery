---
id: rk-hoist-meetings-css-safe-regex-to-module-c2b9e625
short-id: c2
title: Hoist meetings' _css-safe regex to module scope
priority: 4
labels:
- chore-meetings-review
deps: []
closed: true
---
`_css-safe` in /home/lox/code/_fcl/rookery/meetings/0.1.0/src/lib.typ (lines 59-64)
compiles a fresh `regex(...)` object on every call:

    #let _css-safe(name) = assert(
      type(name) == str and name.match(regex("^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$")) != none,
      message: "@rookery/meetings: the page tag "
        + repr(name)
        + " is not usable as a CSS class fragment. Use alphanumerics and interior hyphens only.",
    )

It is called once per page tag from the `#meetings(..)` factory (line 130):

    for (k, _) in own.pairs() { _css-safe(k) }

Every `meetings(...)` factory call (one per subject page in a project — see the
package's own doc comment at lines 104-113 for that pattern) rebuilds the same
pattern for every tag it carries, instead of compiling it once when the module
loads. This is the same defect shape flagged elsewhere in this repo: a
`regex(..)` built inside a loop rather than bound once at module scope.

Touches: /home/lox/code/_fcl/rookery/meetings/0.1.0/src/lib.typ

## Steps

1. Above `_css-safe` (currently line 59), add a module-level binding for the
   compiled pattern, e.g.:

       #let _CSS-SAFE-RE = regex("^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$")

2. In `_css-safe`'s assert condition, replace the inline `regex("...")` call
   with `_CSS-SAFE-RE`.
3. Leave the assert's `message:` argument and every other line of the function
   unchanged.
4. Leave the call site at line 130 (`_css-safe(k)`) unchanged — only the regex
   construction moves.

## Do NOT

- Do not rename `_css-safe` or change its signature.
- Do not touch any other function in this file.
- Do not touch `test/units.typ`, `test/view.typ`, or `src/meetings.css`.

## VERIFY

    cd /home/lox/code/_fcl/rookery/meetings/0.1.0 && just test

Expect the same output as before the change: `units OK` then `view OK`, with
no assertion failures.