#import "slip.typ": slip

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

#let slip-lines(name, eq, ..args) = {
  assert(type(name) == str, message: "@rookery/slipshow: `slip-lines` takes a string name first — got " + repr(name))
  assert(type(eq) == content and eq.func() == math.equation,
    message: "@rookery/slipshow: `slip-lines` takes one equation — got " + repr(eq))
  assert("order" not in args.named(),
    message: "@rookery/slipshow: `slip-lines` takes no `order:` — its rows would share it")
  let named = args.named()
  let rest = named.pairs().filter(p => p.at(0) != "title").to-dict()
  range(equation-rows(eq).len()).map(k => slip(
    if k == 0 { name } else { name + "-line-" + str(k + 1) },
    join: k > 0,
    ..(if k == 0 { named } else { rest }),
    ..args.pos(),
    equation-band(eq, k),
  ))
}
