// Presentation for a grade class. The classification itself lives in
// bin/grades.jq and runs once at index-build time — current.json already
// carries gradeClass, so there is deliberately no second classifier here that
// could drift from the one that built the index.

var ORDER = ["sahih", "hasan", "daif", "maudu", "unknown"]

var LABEL_KEY = {
  sahih: "classSahih",
  hasan: "classHasan",
  daif: "classDaif",
  maudu: "classMaudu",
  unknown: "classUnknown"
}

// Named against the theme roles the shell exposes rather than literal colours,
// so a badge follows whatever theme is active.
var ROLE = {
  sahih: "positive",
  hasan: "positive",
  daif: "muted",
  maudu: "urgent",
  unknown: "muted"
}

function labelKey(cls) { return LABEL_KEY[cls] || LABEL_KEY.unknown }
function role(cls) { return ROLE[cls] || "muted" }
function rank(cls) { var i = ORDER.indexOf(cls); return i < 0 ? ORDER.length : i }

// Collections whose every hadith is authentic by construction ship an empty
// grades[] rather than repeating "Sahih" seven thousand times. The index maps
// them to sahih; the panel says why instead of showing a bare badge with no
// grader behind it.
function isImplicitlySahih(book) { return book === "bukhari" || book === "muslim" }

// One badge per grader, deduplicated, so a hadith graded Sahih by four people
// does not render four identical chips.
function badges(hadith) {
  if (!hadith) return []
  var grades = Array.isArray(hadith.grades) ? hadith.grades : []
  if (grades.length === 0) return []
  var seen = {}
  var out = []
  for (var i = 0; i < grades.length; i++) {
    var g = grades[i]
    if (!g || !g.grade) continue
    var key = String(g.grade).trim()
    if (seen[key]) { seen[key].graders.push(g.name || ""); continue }
    var entry = { grade: key, graders: [g.name || ""] }
    seen[key] = entry
    out.push(entry)
  }
  return out
}

// "Al-Albani, Zubair Ali Zai" — the list the badge's secondary line shows.
function graderLine(entry) {
  if (!entry || !Array.isArray(entry.graders)) return ""
  var names = []
  for (var i = 0; i < entry.graders.length; i++) {
    var n = String(entry.graders[i] || "").trim()
    if (n && names.indexOf(n) === -1) names.push(n)
  }
  return names.join(", ")
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    ORDER: ORDER, labelKey: labelKey, role: role, rank: rank,
    isImplicitlySahih: isImplicitlySahih, badges: badges, graderLine: graderLine
  }
}
