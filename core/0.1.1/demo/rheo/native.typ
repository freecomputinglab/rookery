// The same rookery `content/` compiles under rheo, compiled as ONE document
// instead of a bundle: no minted note pages, no CSS injection (a real
// deployment links `src/core.css` itself), and every href within it an
// in-page fragment rather than a path to another file. `#show: rookery` runs
// once per file, so including several vertebrae here applies it that many
// times — MEASURED, this does not duplicate or error: the `@layer
// rookery-tags` block and the bibliography each appear once, because the
// configuration and the registry both live on document-wide state that a
// later `show: rookery` re-reads rather than re-emits. Every vertebra under
// `content/` belongs here, EXCEPT `content/ideated-doctitle.typ`: its own
// `#set document(title: ..)` would apply to this whole single compiled
// document rather than to just that page, fighting the other vertebrae's
// titles (or the lack of one) instead of naming only its own note.
//
// A VERTEBRA WINDOWED BY ONE ALREADY LISTED HERE HAS TO BE LISTED TOO. Under
// rheo the spine finds every file in `content/` whether this root names it or
// not, so a `#window` resolves against the whole rookery; here the document is
// only what these lines include, and a window onto a note nobody included
// panics with `#window unknown note`. `content/sub/page.typ` windows
// `same-title`, which is why `same-title-pair.typ` is below.
#include "content/index.typ"
#include "content/sub/page.typ"
#include "content/relations.typ"
#include "content/sub/deeper/page.typ"
#include "content/refs.typ"
#include "content/tags.typ"
#include "content/same-title-pair.typ"
