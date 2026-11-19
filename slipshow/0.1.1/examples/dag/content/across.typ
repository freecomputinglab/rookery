// The same corpus as `content/index.typ`, with the one option that changes
// the layout: `direction: "across"` puts every dependency-free todo — the
// five with nothing blocking them — into a single row spanning the screen,
// where the default stacks them one under the next. Everything they release
// is laid out identically on both pages, because the sibling group is what
// decides a row and `direction:` does not touch it: the four todos `kickoff`
// releases share a row here exactly as they do there.
#import "lib.typ": template, todo-slipshow
#show: template

= Organizing the retreat, across

#todo-slipshow(tags: "todo", direction: "across")
