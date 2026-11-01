// The corpus every other page in this example queries: fifteen notes, each
// with a PINNED name — never an auto id, which steps a package-wide counter
// that shifts the moment a note is inserted earlier in the file, and would
// silently repoint `ranked.typ`'s names (carried out of a ranking, not
// written by hand) as well as `index.typ`'s tag query.
//
// Tags overlap on purpose: `method`, `result`, `draft`, and `archive` sit on
// several notes each, so `index.typ`'s `method&!draft` selects a real subset
// rather than everything or nothing. Thirteen notes carry a `created:` date;
// `calib-gamma` and `method-theta` carry none, so `narrowed.typ`'s
// `where: r => r.created != none` has something to exclude besides old
// dates.
//
// Most titles open with the word "calibration" — what `ranked.typ`'s
// `search-ideas("calibration")` ranks on — so that page's top hits differ
// from a plain id sort instead of coinciding with it by accident.
#import "lib.typ": template, slip
#show: template

= The corpus

Fifteen notes, authored once here. Every other page in this example queries
them by tag, by field, or by search rank — nothing below is rendered
specially.

#slip(
  "calib-alpha", title: [Calibration protocol overview],
  tags: ("method", "result"), created: datetime(year: 2026, month: 1, day: 10),
)[
  The calibration protocol synchronizes every sensor against the reference
  standard before a run begins.
]

#slip(
  "calib-beta", title: [Detector calibration walkthrough],
  tags: ("method", "result"), created: datetime(year: 2026, month: 2, day: 15),
)[
  This walkthrough covers detector calibration end to end, from warm-up to
  the final drift check.
]

#slip(
  "calib-gamma", title: [Calibration draft checklist],
  tags: ("method", "draft"),
)[
  A checklist draft for calibration, incomplete until the reference source
  arrives.
]

#slip(
  "calib-delta", title: [Early calibration notes],
  tags: ("method", "draft"), created: datetime(year: 2025, month: 11, day: 20),
)[
  An early pass at calibration notes, written before the procedure had a
  name.
]

#slip(
  "calib-epsilon", title: [Sensor calibration results],
  tags: ("result",), created: datetime(year: 2026, month: 3, day: 5),
)[
  Sensor calibration results from the second batch show the drift within
  tolerance.
]

#slip(
  "calib-zeta", title: [Archived calibration report],
  tags: ("result", "archive"), created: datetime(year: 2022, month: 4, day: 1),
)[
  An archived calibration report from a run that predates the current
  procedure.
]

#slip(
  "calib-xi", title: [Calibration plan], fullscreen: true,
  tags: ("method", "result"), created: datetime(year: 2026, month: 7, day: 1),
)[
  The calibration plan for the coming quarter, presented full screen for the
  review meeting.
]

#slip(
  "calib-omicron", title: [Calibration report draft],
  tags: ("method", "draft"), created: datetime(year: 2024, month: 9, day: 1),
)[
  A draft report on calibration, held back pending a second reviewer.
]

#slip(
  "method-eta", title: [Method writeup: sampling procedure],
  tags: ("method",), created: datetime(year: 2026, month: 4, day: 12),
)[
  The sampling procedure draws three replicates per site and logs the time
  of each draw.
]

#slip(
  "method-theta", title: [Method scratchpad],
  tags: ("method", "draft"),
)[
  Loose notes on method, not yet organized into a procedure.
]

#slip(
  "result-iota", title: [Result summary for trial two],
  tags: ("result",), created: datetime(year: 2026, month: 5, day: 1),
)[
  The second trial's results confirm the pattern seen in the first.
]

#slip(
  "result-kappa", title: [Result appendix tables],
  tags: ("result", "archive"), created: datetime(year: 2021, month: 8, day: 9),
)[
  Appendix tables summarizing every result from the quarter's trials.
]

#slip(
  "archive-lambda", title: [Archive of legacy method notes],
  tags: ("method", "archive"), created: datetime(year: 2020, month: 1, day: 1),
)[
  Legacy method notes kept for reference, including an early calibration
  attempt that was later abandoned.
]

#slip(
  "archive-mu", title: [Archive index],
  tags: ("archive",), created: datetime(year: 2019, month: 6, day: 1),
)[
  An index of everything moved to the archive so far.
]

#slip(
  "draft-nu", title: [Draft thoughts on calibration],
  tags: ("draft",), created: datetime(year: 2026, month: 6, day: 18),
)[
  Loose thoughts on calibration, written before the plan was finalized.
]
