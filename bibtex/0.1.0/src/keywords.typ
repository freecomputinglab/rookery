// A BibTeX `keywords` field, split into rookery tag slugs.
//
// BibTeX has no repeated fields, so `keywords = {ethics, ontology, badiou}`
// parses to one string (`parse-bib`, `parse.typ`); Better BibTeX exports use
// either `,` or `;` as the separator depending on export settings, so both
// are accepted.

// Trimmed, lowercased, every run of non-alphanumeric characters collapsed to
// one hyphen, leading/trailing hyphens stripped. A tag with a space silently
// breaks its CSS class downstream — `idea-tag-<tag>`'s class attribute is
// built by joining tag names with a space, so an untrimmed `digital
// humanities` becomes TWO classes, `idea-tag-digital` and a stray global
// `humanities` — so every keyword goes through this before it becomes a tag.
#let _slugify(s) = {
  let s = lower(s.trim())
  let s = s.replace(regex("[^a-z0-9]+"), "-")
  s.replace(regex("^-+|-+$"), "")
}

// The raw `keywords` field value (a string, or `none` for an entry that
// carries no such field) as an array of slugs, empty parts dropped — a
// keyword that slugifies to the empty string (punctuation only) contributes
// nothing.
#let keyword-tags(raw) = {
  if raw == none { return () }
  raw.split(regex("[,;]")).map(_slugify).filter(s => s != "")
}
