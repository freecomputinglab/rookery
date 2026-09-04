// The rest of the bibliography, swept in one call: `all()` mints a note for
// every entry `entry.typ`'s hand-written `#citation` has not already
// claimed — see `@rookery/bibtex`'s readme, "all() — minting the rest of the
// bibliography".
#import "lib.typ": demo, refs

#show: demo

= References

#(refs.all)()
