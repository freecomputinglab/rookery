---
id: rookery-priority-scale-48n
title: 'Reverse the priority scale: higher is more important, unbounded, default 0'
priority: 4
labels:
- priority-reversal
- type:task
deps: []
closed: false
---
Reverse the meaning of `priority:` in `@rookery/todos` so that a HIGHER number is a HIGHER priority, remove the 0-4 cap, and make 0 the default. This is the foundation bead: it changes only the encode/decode pair, and every other bead in this set depends on it.

Context you need (do not go looking for it):
- Priority is stored ONLY as a tag key on the note — `todo-p3` — and read back out by decoding that key. There is no separate stored field. Both halves live in `/home/lox/code/_fcl/rookery/todos/0.1.0/src/tags.typ`.
- The encoder is `todo-tags(..)` at line 148; its priority branch is lines 161-169.
- The decoder is `priority-of(tags)` at lines 249-252.
- The OLD scale was br's: integer 0-4, 0 = critical, 4 = backlog, and an absent key decoded to `none`.
- The NEW scale is: a non-negative integer with NO upper bound, where a bigger number means more important, and an absent key decodes to `0`. There is no `none` priority any more — an unprioritised todo simply has priority 0.
- Backwards compatibility is NOT wanted. The only consuming site is `/home/lox/code/waterline`, which is migrated by its own beads. Do not add a compatibility shim, a deprecation warning, or an old-scale reader.

Steps:
1. In `todo-tags` (tags.typ:161-169), replace the assertion with:
   `type(priority) == int and priority >= 0`
   and the message with:
   `"@rookery/todos: `priority` must be a non-negative integer (higher is more important, 0 = unprioritised) — got " + repr(priority)`
   Note that `float.inf` and any other float must still FAIL this assertion — integers only, and the cap is simply gone.
2. Still in that branch, emit the key ONLY when `priority > 0`. Priority 0 is the default, so it needs no key: one representation of one fact, and `todo-p0` would otherwise be an every-todo tag that means nothing. So the branch becomes, in effect: `if priority != none and priority > 0 { out.insert("todo-p" + str(priority), none) }`. Keep the assertion running for `priority: 0` so a bad value is still caught.
3. Rewrite `priority-of(tags)` (tags.typ:249-252). It can no longer scan `range(5)`, because the scale is unbounded. Iterate `tags.keys()`, keep every key that starts with `"todo-p"` and whose remainder after that prefix is one or more ASCII digits (test the remainder with `regex("^[0-9]+$")` via `.match(..) != none`), map each survivor to `int(<remainder>)`, and return the MAXIMUM. Return `0` when there is no such key. Taking the max rather than the first hit makes the result deterministic if someone hand-writes two priority keys in `tags:`.
4. Update the comment above `priority-of` so it describes the new contract: decoded rather than stored, unbounded, absent means 0.
5. Update the tag-vocabulary comment at tags.typ:6, which currently reads `todo`, `todo-p0`..`todo-p4`, ... — it should say `todo-p<n>` for any `n > 0`.

Do NOT touch sorting, the colour ramp, `todos-stats`, the readme, or the tests in this bead — each has its own. Do NOT rename `priority-of` or `todo-tags`. Do NOT introduce a `priority-of` variant that still returns `none`.

Careful: the prefix test must not catch other `todo-*` keys. The ones in use are `todo`, `todo-closed`, `todo-deps`, `todo-metadata`, and `todo-<type>`/`todo-<status>` words; none of them is `todo-p` followed by digits, so the digit test is what keeps them out. There is no `todo-parent` key in this package.

VERIFY, from `/home/lox/code/_fcl/rookery/todos/0.1.0`:
1. `todo-tags(priority: 7).keys()` is `("todo", "todo-p7")`.
2. `todo-tags(priority: 0).keys()` is `("todo",)` — no priority key at all.
3. `priority-of(todo-tags(priority: 7))` is `7`; `priority-of(todo-tags())` is `0`; `priority-of(todo-tags(priority: 0))` is `0`.
4. `priority-of(("todo-p2": none, "todo-p9": none))` is `9`.
5. `priority-of(("todo": none, "todo-bug": none, "todo-closed": none))` is `0`.
6. `todo-tags(priority: 5.0)` and `todo-tags(priority: -1)` both panic with the new message.