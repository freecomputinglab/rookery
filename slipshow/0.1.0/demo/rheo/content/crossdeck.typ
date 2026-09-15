// THE CROSS-PAGE CASE, and the only one in this fixture that can see
// `backlink:` at all. Every other deck here queries notes authored on its own
// page, and a page that MINTS a note is already its Context — rookery does not
// also list it as a backlink — so those pages produce the same footer whatever
// `backlink:` says. This one decks a note authored on `index.typ`, by NAME, so
// the name route goes through `#window` and the deck's setting reaches it.
//
// `check.sh` asserts that `ideas/opener.html` gains no Backlinks section from
// this page. Flip the `#slipshow` below to `backlink: true` and it does — that
// is the assertion's control, and it is worth running by hand if this check
// ever starts looking tautological.
#import "lib.typ": demo
#import "@rookery/slipshow:0.1.0": slipshow
#show: demo

= A deck of someone else's notes

#slipshow(slips: ("opener",))
