---
id: rk-comment-diet-core-css-46664205
short-id: '46'
title: 'Comment diet: core.css'
priority: 2
labels:
- chore-core-review
deps: []
closed: false
---
`core.css` is 1738 lines and 1213 of them — seventy per cent — are inside
comments. Most of that prose is a measurement log: the browser, the viewport,
the site it was measured on, the value before the fix and the value after. Keep
the numbers that justify a constant; drop the log around them.

Touches: /home/lox/code/_fcl/rookery/core/0.1.0/src/core.css

## The rubric

`/home/lox/code/_fcl/rookery/CLAUDE.md`, the section headed "Comment style", is
the standard, and it applies to the stylesheet as much as to the Typst. Read it
before editing. Restated so this bird stands alone:

- **Describe the present.** What the rule is and why it is that way. Never what
  it used to be, what it replaced, or that something "is gone".
- **No issue ids**, bookmark names or branch names.
- **Keep the measurement, drop the lab notebook.** A number that justifies a
  constant stays, and says what it buys. The machine it was measured on, the
  viewport, the date, the site, the baseline it beat and the alternatives that
  lost do not — unless a future reader would otherwise retune the number, and
  then one sentence, not a paragraph.
- **Comment the non-obvious.** What earns a line here: a constraint the
  stylesheet cannot express (a class the Typst side must emit, a CSS cascade
  rule the arithmetic depends on), an invariant between two rules that must move
  together, or a contract with the markup. Not a restatement of the declaration
  under it.
- **Declarative and concise, present tense.** Emphasis capitals for the one
  claim in a block that carries it, not every second clause.

The parity exception applies and is important in this file: a comment may name
its counterpart on the Typst side — which function emits the element, which
custom property publishes the value — because that is a present-tense fact about
how the two halves are arranged, and they cannot be changed apart.

## What this looks like in practice

The block at lines 245-252 reads today:

> THE RULE TO THE BOTTOM OF THE LINE, not through the id's middle, and only in
> these two contexts — the ones with a top border for it to be. A zero-height
> flex item centred lands on the label's own centre line, which is what used to
> leave half the id hanging BELOW the border: MEASURED, 4.55px above the box top
> and 4.58px below it. At `flex-end` the rule sits under the label, so the lift
> below puts the id ON the border rather than through it.

Everything in it that a future editor needs survives in:

> The rule sits at the bottom of the line, not through the id's middle, and only
> in the two contexts that have a top border for it to be: a zero-height flex
> item centred would land on the label's own centre line. At `flex-end` the rule
> sits under the label, so the lift below puts the id ON the border.

The measured pair (4.55px / 4.58px) goes because it describes a state the code
is not in. Contrast the block at lines 276-285, whose measurement must STAY in
some form: it explains why every lift in the file carries an extra `- 1px`, and
without that sentence a reader would remove the `- 1px` as noise. One sentence
of it is enough — "the label is the tallest item, so its margin box sets the
line height, and the 1px of air under the id therefore has to be paid for with
1px more lift" — and the headless-browser readings around it do not need to be
there.

## The specific work

Line numbers are as of filing; match the quoted text if they have shifted.

1. Go through the file block by block. For each comment, keep the constraint,
   the invariant, the markup contract and the number that a declaration would be
   retuned without. Delete the before-and-after readings, the viewport and
   browser notes ("MEASURED (chromium headless, 900px viewport)", lines 1139 and
   1186), and the site names ("MEASURED on rookery.ohrg.org", at lines 117, 320,
   496, 552, 610, 637, 736 and elsewhere) unless the site is the only thing that
   makes a number meaningful — and it generally is not.
2. Rewrite every passage that describes a previous state of the file. The ones
   found by grep are at lines 247-248, 262, 317, 387, 496, 618, 650-651, 736,
   911 and 1203 ("It used to be one rule for the hat, hand-copied into..."), and
   there are likely more that the grep's wording missed.
3. The two `REJECTED` passages, at lines 513 and 1192, each reduce to a
   one-clause constraint: what must not be done and the property that makes it
   wrong. Delete the rest.
4. Keep in full, because each is a rule the stylesheet cannot express and a
   reader cannot recover:
   - the `@layer` interaction — an unlayered rule beats a layered one regardless
     of specificity, which is what the generated per-tag rules depend on (around
     line 859);
   - every note about a class or attribute the Typst side must emit for a rule
     to match, including the `:empty` rules that collapse a titleless heading
     and an empty tab, and the `data-rookery-*` boolean flags that are emitted
     only when off;
   - the arithmetic that ties the tab, the stub, the corner and the left rule to
     `--idea-pad` and `--idea-rule-width`, including the statement that these
     read from the custom properties rather than a pixel count so a retheme
     keeps the alignment;
   - the `rem`-not-`em` decision for the label size.

## Do NOT

- **Do not change one declaration, selector, or property value.** Comments only.
  Not a reorder, not a reformat, not a merge of two rules that look alike.
- Do not delete a comment that names the Typst function or custom property a
  rule depends on.
- Do not delete a number without checking whether a future editor would retune
  the declaration without it. When in doubt, keep the number and cut the prose
  around it.
- Do not touch any other file.

## VERIFY

The stylesheet is not compiled, so a mistake here is invisible to a build. Two
checks instead, and both matter:

1. **Nothing outside a comment changed.** Confirm it by reading your own diff
   before landing the flight: every changed line must be inside a `/* ... */`.
   As a second pass, the declaration count must be identical before and after:

   ```sh
   cd /home/lox/code/_fcl/rookery/core/0.1.0/src && grep -vE "^\s*(/\*|\*)" core.css | grep -c ";"
   ```

   Run it before you start, note the number, and run it again at the end. The
   two must match exactly.

2. **The demos still render.** They read this stylesheet, and `demo/rheo`'s
   `check.sh` asserts on classes and generated rules:

   ```sh
   cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/pure && just build
   cd /home/lox/code/_fcl/rookery/core/0.1.0/demo/rheo && just check
   ```

   Expected last lines: `demo/pure OK` and `demo/rheo OK`. Both are green today.

Size, as guidance rather than a gate:

```sh
cd /home/lox/code/_fcl/rookery/core/0.1.0/src && awk 'BEGIN{inc=0;c=0} {if ($0 ~ /\/\*/) inc=1; if (inc) c++; if ($0 ~ /\*\//) inc=0} END{print c, "of", NR}' core.css
```

Today it prints `1213 of 1738`. Landing near 700 of 1200 would be a good pass.
Losing a constraint or an unrecoverable number to hit a count is the one failure
this bird cannot accept.