---
id: rookery-priority-sort-3ta
title: Sort todos by priority descending everywhere
priority: 4
labels:
- priority-reversal
- type:task
deps:
- blocked-by:rookery-priority-scale-48n
closed: true
---
Every place `@rookery/todos` orders todos by priority sorts ASCENDING today, because the old scale had 0 as critical, and treats an unset priority as a large sentinel (9 or 99) so it lands last. The scale is now reversed by bead `rookery-priority-scale-48n`: a bigger number is more important, `priority-of` never returns `none`, and an unprioritised todo is simply priority 0. So every one of these sorts must become DESCENDING by priority, then ascending by name — and the sentinels must go, because 0 already sorts last on its own.

There are exactly four sites. All paths are under `/home/lox/code/_fcl/rookery/todos/0.1.0/`.

1. `src/views.typ:181-184`, `_by-priority`. It is currently
   `#let _by-priority(rows) = rows.sorted(key: r => (if r.priority == none { 9 } else { r.priority }, r.name))`.
   Make the key `(-r.priority, r.name)`. Rewrite the comment above it (lines 178-180) so it says: by priority, most important first, then by name for a build-stable order; an unprioritised todo is priority 0 and so sorts last. `_by-priority` is called from views.typ lines 217, 229, 248, 309, 313 and from `src/search.typ:140`; none of those call sites change.

2. `src/graph.typ:317-323`, `_rank`. Same change: the key becomes `(-r.at("priority", default: 0), r.name)`. Update the comment above it, which currently says "priority ascending, then name, with an unprioritised node last".

3. `src/panel.typ:308-312`. `let rank = r => if r.priority == none { 99 } else { r.priority }` becomes `let rank = r => -r.priority`. Leave the `if order == "newest" { s.rev() }` line exactly as it is — reversing the whole list is still correct. Fix the comment at panel.typ:305-307, which says the tie-break "would come out p4-first"; on the new scale the wrong end is the LOWEST priority, so word it as "would come out least-important-first".

4. `src/layout.js:57-62`, inside `rows()`. `const pa = a.priority ?? 9;` / `const pb = b.priority ?? 9;` become `?? 0`, and the comparison `pa !== pb ? pa - pb : ...` becomes `pa !== pb ? pb - pa : ...`. Update the comment at layout.js:46-48 the same way as the Typst twin. This file has a Typst counterpart (`_rank` in graph.typ, step 2) and the two must agree — that parity is the whole reason both exist.

Do NOT change `undated-priority`'s semantics, the colour ramp, the pill projection at panel.typ:327, or `todos-stats` — each has its own bead. Do NOT touch `src/todo-search.js`, whose "priority order" comments mean the build-time row order it must preserve, not a todo's priority field.

VERIFY:
1. `rg -n '\?\? 9|\?\? 99|== none \{ 9 \}|== none \{ 99 \}' src/` returns nothing.
2. In `/home/lox/code/_fcl/rookery/todos/0.1.0`, `just build` succeeds and `cd demo/rheo && rheo compile` succeeds.
3. On the built demo page, in a `#todos-list`, the todo with the highest `priority:` number appears above every todo with a lower one, and the todos carrying no `priority:` at all appear at the bottom of the list.