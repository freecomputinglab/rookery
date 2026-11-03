// @rookery/pinboard: a board of draggable cards for arranging @rookery/core
// notes by hand — John McPhee's structural method, in the browser. Write
// each component of a piece on its own note, see every one as a card on one
// board, and move the cards around until a sequence appears.
// Depended on for its JavaScript, not for any Typst API it exports: this
// import is what puts `@rheo/rehydrate`'s script on the page, which this
// package's own script then reads as the `RheoRehydrate` global to re-wire
// its widgets after a `rheo watch` morph.
#import "@rheo/rehydrate:0.1.0"

#import "board.typ": *
