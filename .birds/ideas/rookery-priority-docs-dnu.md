---
id: rookery-priority-docs-dnu
title: Update the readmes and example corpora for the new priority scale
priority: 2
labels:
- priority-reversal
- type:task
deps:
- blocked-by:rookery-priority-css-7v3
- blocked-by:rookery-priority-stats-iqm
closed: true
---
The `@rookery` documentation and the two example corpora still describe and use the old priority scale (integer 0-4, 0 = critical, br's scale, absent = unprioritised). Bring them onto the new one: a non-negative integer with no upper bound, bigger is more important, absent means 0, and the colour ramp's three rungs are the three highest priorities in use on the site rather than fixed numbers p0/p1/p2. See beads `rookery-priority-scale-48n`, `rookery-priority-rung-47g` and `rookery-priority-css-7v3` for the mechanics.

All paths under `/home/lox/code/_fcl/rookery/`.

Steps:
1. `todos/0.1.0/readme.md`. Fix, at minimum, these lines: 12-13 and 59 (example `priority:` numbers, which read as critical-first today); 171 (the tag table row, which literally says `todo-p0` … `todo-p4` | `priority:` (0 = critical, br's scale)); 303 and 415 (the `tags:todo-p1` search examples); 436-445 (the whole undated-row paragraph, which names `P0` red / `P1` orange / `P2` yellow and says the rows sort "p0 first"); 486 and 532 (sibling ordering, "unprioritised last" — still true, but "by priority" now means descending); 610 (a `priority: 1` example); 675 (`.idea-tag-todo-p0` styles a critical todo); 694-726 (the ramp section, including the `--todo-band-p0/p1/p2` table row at 709 and the worked override at 726, which must be renamed to `--todo-band-rung-0/1/2` and `--todo-pri-fg-rung-<n>`). Renumber every example so the new reading is obvious — a document whose examples all use 0 and 1 teaches the reader nothing about a scale with no ceiling, so use a spread like 0, 2, 5, 9 somewhere.
2. `todos/0.1.0/demo/rheo/content/index.typ`, lines 29, 40, 65, 78, 87, 97, 138, 150. Remap each `priority: n` under the reversal `0->4, 1->3, 2->2, 3->1, 4->0`, then adjust a couple upward so the demo exercises a priority above 4 — the demo is the thing a reader looks at to learn the scale, and a demo that stops at 4 hides the change. Fix the prose at lines 203-216, which names `P1` and `undated-priority` in the old terms.
3. `slipshow/0.1.0/examples/dag/content/corpus.typ`, lines 39, 46, 54, 65, 73, 80, 89, 98, 118, 128, 137, 146, 155. Same `0->4, 1->3, 2->2, 3->1, 4->0` remap. The prose at line 112 says a node "carries no priority at all"; that is still true of a node with no `priority:` argument, so check it reads correctly against whatever that node now is. Also fix the ordering comment at line 19 and at `examples/dag/content/index.typ:14`, both of which say "priority then name, unprioritised last" in the ascending sense.
4. `search/0.1.0/readme.md:1235` and `search/0.1.0/src/panel.typ:238` both use "a reader pressing `ready` and `p0`" as the worked example of AND-ing two facet groups. The point being made is about AND, not about which priority is urgent, so either leave them or pick a number that reads as high on the new scale — do not restructure the surrounding paragraphs.
5. `timeline/0.1.0/readme.md:694` and `:832` mention the shared heat ramp and the "due and priority chips `@rookery/todos` draws". Check each sentence is still true and fix only what is not.

Do NOT touch `core/0.1.0/readme.md:951` or `core/0.1.0/src/pure.typ:134`. Both use `t.at("priority", default: 9)` as a generic illustration of reading a value out of a tag dictionary; they are about core's tag API and are not claims about `@rookery/todos`' scale.

Do NOT change any code in `src/` in this bead — the other beads own that. If a doc sentence cannot be made true without a code change, leave the sentence and say which one in the commit message.

Follow this repo's comment and prose rule from `/home/lox/code/_fcl/rookery/CLAUDE.md`: describe the present. Never write that the scale "used to be" 0-4, never mention the reversal, never name a bead.

VERIFY:
1. `rg -n '0 = critical|br.s own scale|br.s scale|integer 0-4' /home/lox/code/_fcl/rookery` returns nothing.
2. `rg -n 'todo-band-p[0-9]|todo-pri-fg-p[0-9]' /home/lox/code/_fcl/rookery` returns nothing.
3. `cd /home/lox/code/_fcl/rookery/todos/0.1.0/demo/rheo && rheo compile` succeeds, and the rendered todo list shows the highest-numbered priority at the top.
4. The slipshow dag example still compiles.