// Paged regression fixture for an idea's Footnotes block. Checked by
// `just test`'s `pdftotext` step, which fails if the block's label shares a
// line with the body's last paragraph instead of standing on its own.

#import "/src/lib.typ": footnote, idea, rookery

#show: rookery

#idea(<fn-paged>)[
  The last paragraph of a note with a footnote#footnote[The footnote's own text.] ends here.
]
