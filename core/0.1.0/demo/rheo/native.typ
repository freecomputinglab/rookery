// The same rookery `content/` compiles under rheo, compiled as ONE document
// instead of a bundle: no minted note pages, no CSS injection (a real
// deployment links `src/core.css` itself), and every href within it an
// in-page fragment rather than a path to another file. `#show: rookery` runs
// once per file, so including several vertebrae here applies it that many
// times — MEASURED, this does not duplicate or error: the `@layer
// rookery-tags` block and the bibliography each appear once, because the
// configuration and the registry both live on document-wide state that a
// later `show: rookery` re-reads rather than re-emits. Every vertebra under
// `content/` belongs here.
#include "content/index.typ"
#include "content/sub/page.typ"
#include "content/relations.typ"
#include "content/sub/deeper/page.typ"
#include "content/refs.typ"
#include "content/tags.typ"
