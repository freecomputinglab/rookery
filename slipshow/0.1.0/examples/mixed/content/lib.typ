// Shared `@rookery/core` configuration for this example, imported alongside
// `@rookery/slipshow` even though `slipshow` itself is never called from this
// file: rheo's package asset detection scans a project's own files for
// `@rookery/*` imports, not the packages those files import in turn, so an
// import HERE — in the one file every page of this project applies — is what
// guarantees both core's idea-box stylesheet and slipshow's deck stylesheet
// reach every page, not only whichever one that page's own file happens to
// name for its own functions.
#import "@rookery/core:0.1.0": rookery
#import "@rookery/slipshow:0.1.0"

#let template(doc) = {
  show: rookery
  doc
}
