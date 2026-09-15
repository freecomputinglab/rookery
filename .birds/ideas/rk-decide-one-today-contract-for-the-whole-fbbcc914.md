---
id: rk-decide-one-today-contract-for-the-whole-fbbcc914
short-id: fbb
title: 'Decide one today: contract for the whole package'
priority: 1
labels:
- chore-timeline-api
- parked
deps: []
closed: false
---
PARKED: this needs a decision before it is work. It changes a policy the package
documents at length and defends on purpose, and the two options below are both
defensible.

The package has two contracts for `today:` behind identical signatures.

Everything in `when.typ` and `ladder.typ` — `is-overdue`, `is-upcoming`,
`is-scheduled-now`, `stage-of`, `stage-on`, `next-of`, `days-at-stage`,
`days-in-flight`, `is-settled`, `rung`, `next-stage` — resolves a missing `today:`
through `_today` (`/home/lox/code/_fcl/rookery/timeline/0.1.0/src/when.typ:32`):
the explicit argument, then the document's own `#set document(date:)`, then a
panic.

`#upcoming` and `#upcoming-rows` refuse the document date and assert on the
argument instead (`timeline/0.1.0/src/upcoming.typ:118-133`, `_require-today`).
The stated reason: a predicate answers a question the caller asked, while a queue
asserts an ordering, a window and a set of badges, all of which read as facts
about the reader's today — and a document date set once and forgotten would make
every one of them silently wrong.

The cost is that a caller cannot see which contract they are in. Both spell
`today: none`. And the argument cuts both ways: `is-overdue` asserts a fact about
the reader's today as hard as a queue does, which is the case for making the
package uniform instead.

## The two options

**A — uniform `_today` everywhere.** `#upcoming`/`#upcoming-rows` drop
`_require-today` and resolve like everything else. One contract, one fallback
chain, one panic message. Costs: a project with a stale `#set document(date:)`
gets a wrong queue rather than a loud failure, which is exactly what
`upcoming.typ`'s comment was written to prevent.

**B — keep the split, but put it in the signature.** The two views take `today`
POSITIONALLY: `timeline-upcoming(today, ..)`. A required argument that is required
in the signature rather than in an assert, and `days-until(d, today)`
(`when.typ:166`) already uses exactly this device in this package for exactly this
reason. Costs: a keyword-heavy view gains one positional argument, and every call
site changes.

A third option — leave it, and document the split in the readme's own API section
rather than only in a source comment — is the null result and is a legitimate
outcome of the decision.

Touches (option A): /home/lox/code/_fcl/rookery/timeline/0.1.0/src/upcoming.typ
Touches (option B): /home/lox/code/_fcl/rookery/timeline/0.1.0/src/upcoming.typ,
timeline/0.1.0/test/upcoming.typ, timeline/0.1.0/readme.md, plus every call site
of either view

## What to do when this is unparked

1. Record the chosen option and the reason in the bird before touching code.
2. Implement only that option. Do not implement both and pick one after.
3. Either way, the readme gains a sentence in its API section stating the
   package's ONE rule about reference dates, so the contract is documented where a
   caller reads rather than only in a source comment.

## Non-goals

- **No wall clock, ever.** `datetime.today()` returns 1980-01-01 under this
  repo's own `SOURCE_DATE_EPOCH` and fails silently. Nothing here may call it,
  whichever option wins.
- **Do not change the panic messages' content** — they explain the missing clock,
  which is the one thing a caller who hits them needs.
- **Do not fold `days-until`'s positional `today` into the keyword style.** It
  takes two dates and has no tag dictionary and no context to resolve a fallback
  from.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery/timeline/0.1.0 && just test` — `units OK`,
   `views OK`.
2. `cd /home/lox/code/_fcl/rookery/todos/0.1.0 && just check` and
   `cd /home/lox/code/_fcl/rookery/cfps/0.1.0 && just test` pass.
3. Under option A, a fixture with `#set document(date: ..)` and no `today:`
   renders a queue; under option B, every call site names its reference date
   positionally and a call omitting it fails to compile.