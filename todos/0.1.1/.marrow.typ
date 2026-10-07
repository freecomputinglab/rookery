// Writes the whole todo corpus as JSON, once per build, at the bundle root.
//
// rheo inlines this file verbatim at the bundle root when a project imports
// `@rookery/todos`, so it runs with the finished note registry in scope —
// the same place `@rookery/search`'s own `.marrow.typ` builds its index
// from. `todos()` already resolves every note and its tag values in two bulk
// reads; this file only projects each row to a JSON-safe shape and writes it
// to `rookery/todos/index.json`.
//
// `title` IS OMITTED IN FAVOUR OF `label`: `e.title` is authored Typst
// content, and `json.encode` of content does not error — it silently emits a
// structural blob (`@rookery/core`'s `src/data.typ` warns of exactly this).
// `label` is core's own flattened plain-text derivation of the same field.
// `body` is dropped entirely for the same reason and because a todo's prose
// is not what a reader of this corpus needs.
//
// `metadata` keeps only scalar entries (`str`, `int`, `float`, `bool`):
// an author can put anything in that bag, including content, and there is no
// general way to flatten an arbitrary value into JSON. A dropped key is
// silent by design — better than a corrupt file — so a project relying on a
// non-scalar metadata value will not find it here.
//
// Every field but `closed` is omitted rather than written as `none`/empty,
// matching `@rookery/search`'s marrow: it keeps the file small and makes a
// missing key unambiguous rather than a explicit null.
#import "@rookery/todos:0.1.1": _todos-asset-path, todos

// A `datetime` as an ISO `YYYY-MM-DD` string, or `none` when absent.
#let _iso(d) = if d == none { none } else { d.display("[year]-[month padding:zero]-[day padding:zero]") }

#let _scalar-metadata(m) = {
  let out = (:)
  for (k, v) in m {
    if type(v) in (str, int, float, bool) { out.insert(k, v) }
  }
  out
}

#let _export-row(e) = {
  let row = (id: e.id, name: e.name, title: e.label, closed: e.closed)
  if e.priority != 0 { row.insert("priority", e.priority) }
  if e.kind != none { row.insert("type", e.kind) }
  if e.status != none { row.insert("status", e.status) }
  let closed-on = _iso(e.closed-on)
  if closed-on != none { row.insert("closed-on", closed-on) }
  if e.deps.len() > 0 { row.insert("deps", e.deps) }
  let tags = e.tags-dict.keys()
  if tags.len() > 0 { row.insert("tags", tags) }
  let metadata = _scalar-metadata(e.metadata)
  if metadata.len() > 0 { row.insert("metadata", metadata) }
  let created = _iso(e.at("created", default: none))
  if created != none { row.insert("created", created) }
  if e.page != none { row.insert("href", e.page) }
  row
}

#context {
  let rows = todos()
  if rows.len() > 0 {
    asset(_todos-asset-path, json.encode(rows.map(_export-row), pretty: false))
  }
}
