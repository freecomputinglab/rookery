// The rows of a multi-line equation, split at its `\`s.
#let equation-rows(eq) = {
  let kids = if eq.body.func() == [].func() { eq.body.children } else { (eq.body,) }
  let rows = ((),)
  for k in kids { if k.func() == linebreak { rows.push(()) } else { rows.last().push(k) } }
  rows.filter(r => r.len() > 0).map(r => r.join())
}

#let _band(eq, k) = context {
  let rows = equation-rows(eq)
  let n = rows.len()
  let size(m) = measure(box(math.equation(block: true, rows.slice(0, m).intersperse(linebreak()).join())))
  let gap = if n < 2 { 0pt } else {
    size(2).height - size(1).height - measure(box(math.equation(block: true, rows.at(1)))).height
  }
  let top = if k == 0 { 0pt } else { size(k).height + gap / 2 }
  let bottom = if k == n - 1 { size(n).height } else { size(k + 1).height + gap / 2 }
  block(width: size(n).width, height: bottom - top, clip: true, move(dy: -top, box(eq)))
}

// Row `k` of `eq`, drawn as its band of the whole equation, so it keeps the
// columns its `&`s have among the other rows. In HTML it is a frame, since
// only paged layout can clip.
#let equation-band(eq, k) = context if target() == "html" { html.frame(_band(eq, k)) } else { _band(eq, k) }

#let _space = [ ].func()
#let _blank(c) = c.func() in (_space, parbreak)

#let _block-equation(c) = c.func() == math.equation and c.block

// The one block equation `body` is, ignoring space around it, or `none`.
#let _lone-equation(body) = {
  if _block-equation(body) { return body }
  if body.func() != [].func() { return none }
  let kids = body.children.filter(c => not _blank(c))
  if kids.len() == 1 and _block-equation(kids.first()) { kids.first() } else { none }
}

// The rows `#slip(lines: true)` reveals one at a time. A lone block equation
// splits at its `\`s into bands that keep its `&` columns; anything else
// splits at paragraph breaks, with each list or enum item a row of its own.
#let slip-rows(body) = {
  let eq = _lone-equation(body)
  if eq != none { return range(equation-rows(eq).len()).map(k => equation-band(eq, k)) }

  let kids = if body.func() == [].func() { body.children } else { (body,) }
  kids = kids.map(c => if c.func() in (list, enum) { c.children } else { (c,) }).flatten()
  let rows = ()
  let cur = ()
  // The number the next enum item in an unbroken run takes.
  let next = none
  for c in kids {
    if c.func() in (parbreak, list.item, enum.item) {
      if cur.any(k => not _blank(k)) { rows.push(cur.join()) }
      cur = ()
    }
    if c.func() == list.item {
      rows.push(c)
      next = none
    } else if c.func() == enum.item {
      let given = c.at("number", default: none)
      let n = if type(given) == int { given } else if next == none { 1 } else { next }
      rows.push(enum.item(n, c.body))
      next = n + 1
    } else if c.func() != parbreak {
      if not _blank(c) { next = none }
      cur.push(c)
    }
  }
  if cur.any(k => not _blank(k)) { rows.push(cur.join()) }
  rows
}
