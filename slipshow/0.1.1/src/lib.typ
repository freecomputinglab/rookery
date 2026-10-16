// @rookery/slipshow — an endlessly scrolling presentation over @rookery/core
// ideas, in the spirit of https://github.com/panglesd/slipshow.

// THE ENTRYPOINT IS A MANIFEST, not a place for code. Every name this package
// exports lives in one of the modules below, imported here in dependency
// order.
// Depended on for its JavaScript, not for any Typst API it exports: this
// import is what puts `@rheo/rehydrate`'s script on the page, which this
// package's own script then reads as the `RheoRehydrate` global to re-wire
// its widgets after a `rheo watch` morph.
#import "@rheo/rehydrate:0.1.0"

#import "tags.typ": *
#import "marker.typ": *
#import "select.typ": *
#import "slip.typ": *
#import "slipshow.typ": *
