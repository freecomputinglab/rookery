---
id: rookery-priority-stats-iqm
title: Count todos-stats over the priorities actually in use
priority: 3
labels:
- priority-reversal
- type:task
deps:
- blocked-by:rookery-priority-scale-48n
closed: true
---
`#todos-stats` counts todos per priority by walking `range(5)`, which is the old capped 0-4 scale. Bead `rookery-priority-scale-48n` removes the cap, so the loop must instead walk the priorities actually in use.

File: `/home/lox/code/_fcl/rookery/todos/0.1.0/src/views.typ`, function `todos-stats`, the loop at lines 339-342:

```
  for n in range(5) {
    let c = count(r => r.priority == n)
    if c > 0 { pairs.push(("p" + str(n), c)) }
  }
```

Steps:
1. Replace `range(5)` with the distinct non-zero priorities present in `rows`, largest first: `rows.map(r => r.priority).filter(p => p > 0).dedup().sorted().rev()`. `rows` is already in scope (line 327).
2. Drop the `if c > 0` guard — deriving the list from `rows` means every entry is non-zero by construction — unless you keep the derivation as a separate `let`, in which case leaving the guard is harmless. Prefer the shorter version.
3. Priority 0 is deliberately NOT counted as its own line. On the new scale 0 means unprioritised, and `total` minus the priority lines already says how many there are.
4. Update the comment at line 323 ("Totals by status, priority and type") only if it makes a claim about the 0-4 range; as quoted it does not, so most likely leave it.

Do NOT change the `status` or `type` pairs, the two rendering branches below, or the order in which `pairs` is built — the "built once, rendered twice" property at lines 333-334 is the point of the function.

Note that `priority-scale()` from bead `rookery-priority-rung-47g` computes almost this same list, but over the WHOLE rookery via `todos()`. Do not reuse it here: `todos-stats` counts over its own `rows`, and the two must not silently diverge if that ever stops being everything.

VERIFY, from `/home/lox/code/_fcl/rookery/todos/0.1.0`:
1. `rg -n 'range\(5\)' src/views.typ` returns nothing.
2. `just build` succeeds and `cd demo/rheo && rheo compile` succeeds.
3. On the built demo page, `#todos-stats` shows a `p<n>` count for each distinct priority the demo content uses, in descending order of `n`, and shows no `p0` line.