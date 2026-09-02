// The `data-rookery-search-limit` attribute, read by both surfaces: a NUMBER,
// the string "none", or absent.
//
// `null` is what `search()` reads as uncapped (`score.js`: `limit == null ? out :
// out.slice(0, limit)`), so "none" resolves to that rather than to Infinity.
//
// ABSENT IS NOT UNCAPPED. It means markup carrying no such attribute, which wants
// the calling widget's own default — 8 for the bar, 30 for the modal — so the
// fallback is a parameter here rather than a constant.
export const readLimit = (raw, fallback) => {
  if (raw === "none") return null;
  const n = Number(raw);
  return Number.isFinite(n) && n > 0 ? n : fallback;
};
