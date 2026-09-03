// Fourteen todos, each with a PINNED name, telling one story — organizing a
// retreat — so the graph below is shaped like a real project's rather than a
// synthetic chain. `layers(todo-graph())` groups them into four layers, and
// this file's shape decides what those layers look like:
//
//   layer 0 (5)  `kickoff` and four unrelated standalone todos beside it —
//                one CLOSED (`retire-legacy`), one with a DANGLING dep
//                (`note-onboarding`, which names a note that does not
//                exist — see `@rookery/todos`' `graph.typ` line 62 for why
//                that is not an error), and two ordinary open todos.
//   layer 1 (4)  `audit-logs`, `collect-data`, `review-budget`, and
//                `draft-notes` all depend on `kickoff` and on nothing from
//                each other — the WIDE layer this whole example exists to
//                prove, so several unrelated todos releasing off one root
//                sit BESIDE each other rather than in a list. Priorities
//                1, 1, 3 and none (unprioritised) so within-layer ordering
//                — priority then name, unprioritised last — is visible
//                rather than accidental.
//   layer 2 (3)  each depends on two layer-1 todos.
//   layer 3 (2)  each depends on two layer-2 todos.
//
// EVERY TODO CARRIES `slip-row`/`slip-max-width` TAGS BY HAND, matching its
// layer above — see `content/index.typ` for why (route (a) of the two ways
// to get a computed row onto a slip) and for the assertion that catches this
// file drifting out of step with the graph it describes.
#import "lib.typ": template, todo
#show: template

= The corpus

Fourteen todos for one retreat, authored once here. `content/index.typ`,
`content/open-only.typ` and `content/wide.typ` all read this same graph —
nothing below is rendered specially.

#todo(
  "kickoff", title: [Kick off the retreat], priority: 0,
  tags: (slip-row: 0, slip-max-width: 18em),
)[
  Pick a date, book the venue, and tell everyone it is happening.
]

#todo(
  "retire-legacy", title: [Retire the legacy signup form], priority: 4,
  done: datetime(year: 2026, month: 1, day: 10),
  tags: (slip-row: 0, slip-max-width: 18em),
)[
  The old paper signup sheet is finally gone — everyone signs up online now.
]

#todo(
  "note-onboarding", title: [Draft onboarding notes], priority: 2,
  deps: ("legacy-import",),
  tags: (slip-row: 0, slip-max-width: 18em),
)[
  Meant to carry over the attendee list the old signup form kept, but that
  form (`legacy-import`) was never itself a todo in this rookery — a typo or
  a note pinned on a page outside the spine, either way this dep resolves to
  nothing and stays a todo the graph cannot place.
]

#todo(
  "renew-lease", title: [Renew the venue lease], priority: 2,
  tags: (slip-row: 0, slip-max-width: 18em),
)[
  The venue's lease on the retreat hall expires the week before the retreat
  does, so this has to close before travel is booked.
]

#todo(
  "sync-calendar", title: [Sync the shared calendar], priority: 3,
  tags: (slip-row: 0, slip-max-width: 18em),
)[
  Everyone's calendar invite should show the same dates, room, and dial-in.
]

#todo(
  "audit-logs", title: [Audit the registration logs], priority: 1,
  deps: ("kickoff",),
  tags: (slip-row: 1, slip-max-width: 24em),
)[
  Check the registration system for duplicate or bounced signups before
  anyone downstream builds a headcount on top of it.
]

#todo(
  "collect-data", title: [Collect attendee dietary data], priority: 1,
  deps: ("kickoff",),
  tags: (slip-row: 1, slip-max-width: 24em),
)[
  A short form asking every attendee about allergies and preferences, closed
  a week before catering needs numbers.
]

#todo(
  "review-budget", title: [Review the catering budget], priority: 3,
  deps: ("kickoff",),
  tags: (slip-row: 1, slip-max-width: 24em),
)[
  Last year's per-head catering cost, checked against this year's quote
  before anyone commits to a headcount.
]

#todo(
  "draft-notes", title: [Draft the welcome notes],
  deps: ("kickoff",),
  tags: (slip-row: 1, slip-max-width: 24em),
)[
  A page handed out at check-in: schedule, wifi password, where the bathrooms
  are. Nobody has claimed it yet, so it carries no priority at all — and it
  is exactly the todo that has to sort LAST among its four siblings, not
  first, for that reason.
]

#todo(
  "compile-summary", title: [Compile the attendee summary], priority: 1,
  deps: ("collect-data", "draft-notes"),
  tags: (slip-row: 2, slip-max-width: 24em),
)[
  One page combining the dietary form's results with whatever the welcome
  notes already promise attendees, so catering and the door desk read the
  same numbers.
]

#todo(
  "merge-results", title: [Merge the audit and dietary results], priority: 2,
  deps: ("audit-logs", "collect-data"),
  tags: (slip-row: 2, slip-max-width: 24em),
)[
  One clean roster: the audited registration list joined against who
  actually answered the dietary form.
]

#todo(
  "publish-report", title: [Publish the budget report], priority: 2,
  deps: ("review-budget", "draft-notes"),
  tags: (slip-row: 2, slip-max-width: 24em),
)[
  The reviewed catering budget, written up alongside the welcome notes'
  headcount assumptions, for whoever signs the final cheque.
]

#todo(
  "ship-final", title: [Ship the retreat pack], priority: 0,
  deps: ("merge-results", "publish-report"),
  tags: (slip-row: 3, slip-max-width: 45%),
)[
  The roster and the budget report, bundled into one pack and sent to the
  venue and the caterer.
]

#todo(
  "sign-off", title: [Sign off the retreat plan], priority: 2,
  deps: ("compile-summary", "publish-report"),
  tags: (slip-row: 3, slip-max-width: 45%),
)[
  A last read of the attendee summary against the budget report before
  travel gets booked against either one.
]
