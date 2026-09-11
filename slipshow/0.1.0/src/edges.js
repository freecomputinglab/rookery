// The connector layer: an SVG under the deck in which each edge declared by
// `data-slip-edges` (`src/slipshow.typ`'s file header) leaves the BOTTOM of
// one slide's left rule and curves into the TOP of another's, stroked with a
// gradient running from the source rail's colour to the target's. Reading
// down the deck then reads the graph — the rails are the nodes, the curves
// are the edges.
//
// DATA FLOWS ONE WAY. `src/slipshow.js` calls `redraw()`; nothing here reads
// anything out of that module, its zoom scale included. The geometry exports
// below (`edgePath`, `railX`) run on plain numbers with no browser at all,
// the same discipline `src/camera.js` follows and for the same reason —
// `test/edges.test.mjs` exercises them in node.
//
// THE CURVE SHAPE IS SHARED WITH `@rookery/todos`' graph view
// (`todos/0.1.0/src/todos.js`, `drawEdge`): a cubic bezier whose control
// points sit at the vertical midpoint, directly below the start and above the
// end, so the curve leaves and arrives VERTICAL and reads as continuous with
// a rail rather than kinked into it. No arrowhead here, unlike there: a
// curve's direction is carried by its gradient, and a marker where a curve
// meets a rail would sit on top of the rail.
//
// KNOWN LIMITATION: a `.slip-row` is its own horizontal scroll container and
// this layer spans all of them, so a curve crossing a scrolled row is drawn
// in full rather than clipped to it. One SVG per row would clip correctly and
// could not draw an edge between rows at all, which is the case this exists
// for.

const SVG_NS = "http://www.w3.org/2000/svg";

const LAYER_CLASS = "slip-edges";

// The cubic bezier above: `{x, y}` in, an SVG `d` string out.
export const edgePath = (from, to) => {
  const mid = (from.y + to.y) / 2;
  return `M ${from.x} ${from.y} C ${from.x} ${mid}, ${to.x} ${mid}, ${to.x} ${to.y}`;
};

// The x of a slide's rule CENTRE. The rule is `border-inline-start`
// (`src/slipshow.css`'s `.slip`), so it occupies the first `ruleWidth` pixels
// of the box, and a stroke of that same width centred here lands ON the rule
// rather than beside it. Left-to-right: an RTL deck would want the box's
// other edge, and nothing here asks for the writing direction yet.
export const railX = (box, ruleWidth) => box.x + ruleWidth / 2;

// A slide's `{x, y, width, height}` in the deck's OWN UNTRANSFORMED
// coordinate space — the space this layer's user units are in, since the SVG
// is `inset: 0` inside the deck and carries no `viewBox`.
//
// AN OFFSET WALK, NEVER `getBoundingClientRect`, for two reasons that are
// both load-bearing. The camera scales the deck with a CSS `transform`
// (`applyScale`, `src/slipshow.js`), so every rect is post-transform and
// would have to be divided back out by a scale this module has no business
// knowing. And a `.slip-row` scrolls itself sideways on overflow
// (`overflow-x: auto`), which an offset walk reports as a constant offset
// plus a scroll position — a rect reports it as a moving box.
//
// A `.slip-row` is unpositioned, so it is NOT in the `offsetParent` chain and
// its scroll has to be subtracted separately.
export function deckBox(el, deck) {
  let x = 0;
  let y = 0;
  for (let node = el; node && node !== deck; node = node.offsetParent) {
    x += node.offsetLeft;
    y += node.offsetTop;
  }
  for (
    let row = el.closest(".slip-row");
    row && deck.contains(row);
    row = row.parentElement?.closest(".slip-row")
  ) {
    x -= row.scrollLeft;
    y -= row.scrollTop;
  }
  return { x, y, width: el.offsetWidth, height: el.offsetHeight };
}

function svgEl(name, attrs) {
  const node = document.createElementNS(SVG_NS, name);
  for (const [k, v] of Object.entries(attrs)) node.setAttribute(k, String(v));
  return node;
}

// A slide's rail as the connector sees it: its width in pixels and its
// RESOLVED colour.
//
// `borderInlineStartColor` rather than `--slip-rule-color`, deliberately: a
// custom property's computed value is a token stream, and a consumer is free
// to set it to another `var()` chain (`@rookery/todos`' `todos.css` sets it to
// `var(--todo-ready-color, seagreen)`), so what comes back is not necessarily
// a colour an SVG `stop-color` can use. The longhand is always a resolved
// `rgb(..)`. Reading it is also what keeps this module ignorant of every
// consumer's palette: the curve's colours are whatever the rails already are.
function rail(el) {
  const style = getComputedStyle(el);
  return {
    width: parseFloat(style.borderInlineStartWidth) || 0,
    color: style.borderInlineStartColor,
  };
}

// The edges worth drawing, source-resolved and measured. An edge is DROPPED
// rather than reported for any of four reasons, because each of them is an
// ordinary state of a live deck rather than a mistake:
//
//   - the source id names no element in this deck (the Typst side already
//     restricts `data-slip-edges` to slides the deck shows, so this is the
//     defensive half of that rule);
//   - either endpoint is hidden — `offsetParent` is `null`, which is exactly
//     what a progressive deck's unrevealed slide is (`display: none` via
//     `.slipshow-revealing .slip:not(.slip-revealed)`), so a deck draws its
//     curves in as the reader advances rather than out to empty space;
//   - either endpoint has no rail to connect (a zero-width
//     `border-inline-start`);
//   - both endpoints sit in the SAME row. A row is a set of slides that
//     depend on nothing from each other, so a same-row edge means the deck's
//     `row:` and its `edges:` disagree; a curve doubling back into its own
//     row would assert a shape the layout is already denying. Silently, not
//     as an error: a caller's `row:` is free to group however it likes.
function collect(deck) {
  const edges = [];
  for (const target of deck.querySelectorAll("section.slip[data-slip-edges]")) {
    if (target.offsetParent === null) continue;
    const targetRail = rail(target);
    if (targetRail.width === 0) continue;
    const targetRow = target.closest(".slip-row");

    for (const id of target.dataset.slipEdges.split(/\s+/).filter(Boolean)) {
      // `getElementById`, not a `#id` selector: a slide's id carries the
      // note's registry prefix (`slip-idea:intro`) and a bare `:` in a
      // selector is a pseudo-class.
      const source = document.getElementById(id);
      if (!source || !deck.contains(source) || source.offsetParent === null) continue;
      const sourceRail = rail(source);
      if (sourceRail.width === 0) continue;
      const sourceRow = source.closest(".slip-row");
      if (sourceRow !== null && sourceRow === targetRow) continue;

      const sourceBox = deckBox(source, deck);
      const targetBox = deckBox(target, deck);
      edges.push({
        from: { x: railX(sourceBox, sourceRail.width), y: sourceBox.y + sourceBox.height },
        to: { x: railX(targetBox, targetRail.width), y: targetBox.y },
        fromColor: sourceRail.color,
        toColor: targetRail.color,
      });
    }
  }
  return edges;
}

// The layer itself, as the deck's FIRST child so the curves paint BENEATH
// every `section.slip` by DOM order: an edge between two rails far apart
// horizontally crosses the slides between them, and it must pass under their
// text rather than over it.
function ensureLayer(deck) {
  const first = deck.firstElementChild;
  if (first && first.classList.contains(LAYER_CLASS)) return first;
  const layer = svgEl("svg", { class: LAYER_CLASS, "aria-hidden": "true" });
  deck.insertBefore(layer, deck.firstChild);
  return layer;
}

// Rebuilds the layer WHOLE — every path and every gradient replaced, never
// diffed — which is the discipline `syncReveal` (`src/slipshow.js`) already
// applies and for the same reason: an idempotent whole-deck rebuild cannot
// drift out of step with the DOM, and the boundary can move by any number of
// slides at once.
//
// A deck declaring no edges anywhere does no work and gets no `<svg>` at all.
export function redraw(deck) {
  if (!deck) return;
  if (deck.querySelector("section.slip[data-slip-edges]") === null) return;

  const edges = collect(deck);
  const layer = ensureLayer(deck);

  const defs = document.createElementNS(SVG_NS, "defs");
  const paths = edges.map((e, i) => {
    // One gradient per edge, in user space, anchored to that edge's own
    // endpoints so the colour turns over along the curve rather than across
    // the whole layer.
    const id = `slip-edge-gradient-${i}`;
    const gradient = svgEl("linearGradient", {
      id,
      gradientUnits: "userSpaceOnUse",
      x1: e.from.x,
      y1: e.from.y,
      x2: e.to.x,
      y2: e.to.y,
    });
    gradient.appendChild(svgEl("stop", { offset: "0", "stop-color": e.fromColor }));
    gradient.appendChild(svgEl("stop", { offset: "1", "stop-color": e.toColor }));
    defs.appendChild(gradient);
    return svgEl("path", { class: "slip-edge", d: edgePath(e.from, e.to), fill: "none", stroke: `url(#${id})` });
  });

  layer.replaceChildren(defs, ...paths);
}
