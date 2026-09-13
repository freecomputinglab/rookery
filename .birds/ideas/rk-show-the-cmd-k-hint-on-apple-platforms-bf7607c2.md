---
id: rk-show-the-cmd-k-hint-on-apple-platforms-bf7607c2
short-id: bf7
title: Show the Cmd K hint on Apple platforms
priority: 3
labels:
- fix-safari-search-modal
deps:
- blocked-by:rk-isolate-each-widget-s-wiring-in-search-e10dfb64
closed: true
---
`#search-modal` draws a keyboard hint beside its magnifier icon, and it always
reads `Ctrl K`. On macOS and iPadOS that is the wrong key to advertise, and it is
wrong in a way that costs a reader the feature: `Ctrl-K` is a long-standing
text-field binding on Apple platforms (kill-to-end-of-line), so a Mac reader who
takes the hint literally in a focused field gets that instead of the search
modal. The reader who filed the Safari report this bird came out of was on macOS
and an iPad.

The BINDING is already correct and needs no change. In
`/home/lox/code/_fcl/rookery/search/0.1.0/src/search.js` the keydown listener
opens on either modifier:

```js
    if (!(ev.ctrlKey || ev.metaKey) || ev.key.toLowerCase() !== "k") return;
```

So Cmd-K already works on a Mac today. Only the printed hint disagrees with it.

The hint is emitted from Typst, in
`/home/lox/code/_fcl/rookery/search/0.1.0/src/ui.typ` at line 270:

```typ
        + html.elem("kbd", attrs: (class: "rookery-search-key", "aria-hidden": "true"), [Ctrl K]),
```

Typst cannot know which platform will read the page — one build serves every
visitor — so the correction has to happen in the browser. The element is already
`aria-hidden="true"`, so rewriting its text changes nothing a screen reader
hears; the button's own `aria-label` is what it announces.

Touches: /home/lox/code/_fcl/rookery/search/0.1.0/src/search.js

## Steps

1. In `/home/lox/code/_fcl/rookery/search/0.1.0/src/search.js`, inside `init()`,
   in the block that wires the triggers (the loop over
   `document.querySelectorAll(".rookery-search-trigger")`), relabel the hint on
   Apple platforms. Add this immediately after the `trigger.addEventListener`
   line inside that loop:

   ```js
   // THE HINT FOLLOWS THE PLATFORM, because the binding already does: the
   // keydown listener below opens on `ctrlKey || metaKey`, and on a Mac or an
   // iPad the discoverable modifier is Command — Control-K there is a
   // text-field binding that eats the keystroke before the page sees it. The
   // markup says `Ctrl K` because Typst builds one page for every visitor and
   // cannot know which is reading it.
   const key = trigger.querySelector(".rookery-search-key");
   if (key !== null && APPLE) key.textContent = "⌘ K";
   ```

2. Define `APPLE` once, at module scope in the same file, just above
   `export const init = async () => {` (line 63):

   ```js
   // `navigator.platform` is deprecated but is the only field that separates
   // macOS and iPadOS from everything else in every shipping browser today;
   // `userAgentData.platform` is not implemented in Safari, which is precisely
   // the browser this has to be right for. Guarded for node, where the parity
   // fixture imports this module and there is no navigator.
   const APPLE =
     typeof navigator !== "undefined" &&
     /Mac|iPhone|iPad|iPod/.test(navigator.platform ?? "");
   ```

3. Leave `/home/lox/code/_fcl/rookery/search/0.1.0/src/ui.typ` line 270 exactly
   as it is. `Ctrl K` stays the markup's default, which is correct for every
   non-Apple reader and is what a page with no JavaScript shows.

## Non-goals

- Do NOT change the keydown listener's condition. `ctrlKey || metaKey` is
  already right on every platform and narrowing it would break one of them.
- Do NOT change `ui.typ`, the `rookery-search-key` class, or `src/search.css`.
- Do NOT add a package parameter or a Typst option for the hint text. One
  platform check is the whole feature.
- Do NOT try to detect the platform from the user-agent string.

## VERIFY

1. `cd /home/lox/code/_fcl/rookery/search/0.1.0 && just test` — the node suite
   stays green, which also proves the `typeof navigator` guard holds under node.
2. `cd /home/lox/code/_fcl/rookery/search/0.1.0 && just build` — vite still
   bundles `dist/lib.js`.
3. `cd /home/lox/code/_fcl/rookery/search/0.1.0 && just parity` — still prints
   `parity OK across ...`.
4. Read `src/search.js` and confirm `APPLE` is evaluated once at module scope,
   not per trigger and not inside the keydown listener.