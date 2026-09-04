// Pure helpers for the Daily Ayah & Hadith plugin.
//
// No QML types in here, so `node --test tests/model.test.js` exercises the
// rules directly. Same shape as the first-party weather Model.js and
// crmne.lyrics' Model.js: plain functions, module.exports tail at the bottom,
// and deliberately no `.pragma library` — that would be a syntax error to node
// and would also opt the file out of plugin hot reload.

var PLUGIN_ID = "io.github.keyaypi.daily-deen"

// ------------------------------------------------------------------ settings

// A service is handed `shell`, `manifest` and friends but never `settings`, so
// it has to find its own entry in shell.json. Bar widgets get settings injected
// and never need this.
function entrySettings(shellConfig, id) {
  if (!shellConfig || typeof shellConfig !== "object") return {}
  var sections = ["left", "center", "right"]
  var layout = shellConfig.bar && shellConfig.bar.layout ? shellConfig.bar.layout : {}
  for (var s = 0; s < sections.length; s++) {
    var entries = layout[sections[s]]
    if (!Array.isArray(entries)) continue
    for (var i = 0; i < entries.length; i++) {
      var e = entries[i]
      if (e && typeof e === "object" && e.id === id) return stripId(e)
    }
  }
  if (Array.isArray(shellConfig.plugins)) {
    for (var p = 0; p < shellConfig.plugins.length; p++) {
      var pe = shellConfig.plugins[p]
      if (pe && typeof pe === "object" && pe.id === id) return stripId(pe)
    }
  }
  return {}
}

function stripId(entry) {
  var out = {}
  for (var k in entry) if (k !== "id") out[k] = entry[k]
  return out
}

// updateEntryInline rebuilds the entry from what it is given, so a caller has
// to hand over the whole thing rather than a delta. An empty value removes the
// key, which is how "use the default" is expressed.
function entryWith(settings, id, key, value) {
  var entry = { id: id }
  for (var k in settings) if (k !== "id") entry[k] = settings[k]
  if (value === undefined || value === null || value === "") delete entry[key]
  else entry[key] = value
  return entry
}

// ------------------------------------------------------------------- state

function defaultState() {
  return { version: 1, chosenAt: 0, intervalHours: 6, source: "empty",
           gradeFallback: false, unavailable: [], ayah: null, hadith: null }
}

function parseState(raw) {
  if (!raw) return defaultState()
  try {
    var parsed = typeof raw === "string" ? JSON.parse(raw) : raw
    if (!parsed || typeof parsed !== "object") return defaultState()
    if (!Array.isArray(parsed.unavailable)) parsed.unavailable = []
    return parsed
  } catch (e) {
    return defaultState()
  }
}

function hasContent(state) {
  return !!(state && (state.ayah || state.hadith))
}

// Rotation is a comparison against a stored timestamp, never a Timer whose
// interval is the rotation period. A Timer restarts from zero when the shell
// restarts, which would break "the same ayah until the interval elapses", and a
// laptop waking from eight hours of sleep would fire it eight times over.
function rotationDue(chosenAt, intervalHours, now) {
  var hours = intervalHours > 0 ? intervalHours : 6
  if (!chosenAt) return true
  return (now - chosenAt) >= hours * 3600000
}

function nextRotationAt(chosenAt, intervalHours) {
  var hours = intervalHours > 0 ? intervalHours : 6
  return (chosenAt || 0) + hours * 3600000
}

function formatDuration(ms) {
  if (ms <= 0) return "0m"
  var mins = Math.floor(ms / 60000)
  var h = Math.floor(mins / 60)
  var m = mins % 60
  if (h >= 24) {
    var d = Math.floor(h / 24)
    return d + "d " + (h % 24) + "h"
  }
  if (h > 0) return h + "h " + m + "m"
  return Math.max(1, m) + "m"
}

// ----------------------------------------------------------------- catalog

function catalogList(catalog, api) {
  if (!catalog) return []
  var list = api === "hadith" ? catalog.hadith : catalog.quran
  return Array.isArray(list) ? list : []
}

function languageOptions(catalog, api) {
  var seen = {}
  var list = catalogList(catalog, api)
  for (var i = 0; i < list.length; i++) {
    var lang = list[i].language
    if (!lang) continue
    if (!seen[lang]) seen[lang] = 0
    seen[lang] += 1
  }
  var out = []
  for (var name in seen) out.push({ value: name, label: name, description: seen[name] + " editions" })
  out.sort(function(a, b) { return a.label < b.label ? -1 : a.label > b.label ? 1 : 0 })
  return out
}

// The 492 Qur'an editions are filtered by language before they reach a picker,
// which turns the list into something on the order of a dozen entries. The
// author goes in the label and everything else in the description because
// SearchableDropdown filters across both.
function quranEditionOptions(catalog, language, opts) {
  var includeLatin = opts && opts.includeLatin === true
  var onlyLatin = opts && opts.onlyLatin === true
  var list = catalogList(catalog, "quran")
  var out = []
  for (var i = 0; i < list.length; i++) {
    var e = list[i]
    if (language && e.language !== language) continue
    if (e.latin && !includeLatin && !onlyLatin) continue
    if (!e.latin && onlyLatin) continue
    out.push({
      value: e.slug,
      label: e.author || e.slug,
      description: e.slug + (e.comments ? " — " + e.comments : "")
    })
  }
  out.sort(function(a, b) { return a.label < b.label ? -1 : a.label > b.label ? 1 : 0 })
  return out
}

function hadithLanguageOptions(catalog) {
  return languageOptions(catalog, "hadith")
}

function hadithBookOptions(catalog, language) {
  var list = catalogList(catalog, "hadith")
  var books = catalog && catalog.books ? catalog.books : {}
  var seen = {}
  for (var i = 0; i < list.length; i++) {
    var e = list[i]
    if (language && e.language !== language) continue
    seen[e.book] = true
  }
  var out = []
  for (var b in seen) {
    out.push({ value: b, label: (books[b] && books[b].name) || b, description: b })
  }
  out.sort(function(a, b) { return a.label < b.label ? -1 : a.label > b.label ? 1 : 0 })
  return out
}

function hadithEditionOptions(catalog, book, language) {
  var list = catalogList(catalog, "hadith")
  var out = []
  for (var i = 0; i < list.length; i++) {
    var e = list[i]
    if (book && e.book !== book) continue
    if (language && e.language !== language) continue
    out.push({ value: e.slug, label: e.slug, description: e.language + (e.comments ? " — " + e.comments : "") })
  }
  return out
}

function editionInfo(catalog, api, slug) {
  var list = catalogList(catalog, api)
  for (var i = 0; i < list.length; i++) if (list[i].slug === slug) return list[i]
  return null
}

// The Arabic edition of the same book, so the panel can offer it without the
// user hunting for the slug.
function arabicCounterpart(catalog, slug) {
  var info = editionInfo(catalog, "hadith", slug)
  if (!info) return ""
  var list = catalogList(catalog, "hadith")
  for (var i = 0; i < list.length; i++) {
    if (list[i].book === info.book && list[i].language === "Arabic" && !/[0-9]$/.test(list[i].slug))
      return list[i].slug
  }
  return ""
}

// ---------------------------------------------------------------- rendering

function isRtl(direction) { return String(direction || "").toLowerCase() === "rtl" }

// Remote text reaches tooltips and notifications, so control characters and
// angle brackets come out before it lands on a shared surface. Text items also
// render it with textFormat: Text.PlainText.
var CONTROL_CHARS = /[\u0000-\u001f\u007f-\u009f\u200b-\u200f\u2028\u2029]/g

function safeDisplayText(value) {
  if (value === undefined || value === null) return ""
  return String(value)
    .replace(CONTROL_CHARS, " ")
    .replace(/[<>]/g, "")
    .replace(/\s+/g, " ")
    .trim()
}

// The bar's monospace family (JetBrainsMono Nerd Font here) carries no Arabic
// at all, so a right-to-left run needs a face chosen for it. Text.font.families
// is not available in this QML environment, so the chain is resolved here
// against what is actually installed and a single family is handed over.
function fontsFor(language, direction) {
  if (!isRtl(direction)) return []
  if (language === "Urdu") return ["Noto Nastaliq Urdu", "Noto Naskh Arabic", "Amiri", "Noto Sans Arabic"]
  return ["Noto Naskh Arabic", "Amiri", "Scheherazade New", "Noto Sans Arabic", "Noto Kufi Arabic"]
}

// First candidate the system actually has. Falling back to the UI family is
// not great for a long Arabic passage — fontconfig will substitute per glyph —
// but it beats rendering nothing while we pretend a font is there.
function pickFamily(candidates, available, fallback) {
  if (!Array.isArray(candidates) || candidates.length === 0) return fallback
  var have = Array.isArray(available) ? available : []
  for (var i = 0; i < candidates.length; i++) {
    if (have.indexOf(candidates[i]) !== -1) return candidates[i]
  }
  return fallback
}

function familyFor(language, direction, available, uiFamily) {
  return pickFamily(fontsFor(language, direction), available, uiFamily || "monospace")
}

// Nastaliq stacks its glyphs diagonally and collides with itself at ordinary
// leading; naskh needs more room than Latin too.
function lineHeightFor(language, direction) {
  if (!isRtl(direction)) return 1.35
  return language === "Urdu" ? 2.0 : 1.6
}

function snippet(text, max) {
  var clean = safeDisplayText(text)
  var limit = max || 80
  if (clean.length <= limit) return clean
  var cut = clean.slice(0, limit)
  var space = cut.lastIndexOf(" ")
  if (space > limit * 0.6) cut = cut.slice(0, space)
  return cut + "…"
}

function ayahReference(state) {
  var a = state && state.ayah
  if (!a) return ""
  var name = a.surahName || a.surahEnglish || ("Surah " + a.surah)
  return name + " " + a.surah + ":" + a.ayah
}

function hadithReference(state) {
  var h = state && state.hadith
  if (!h) return ""
  var name = h.collectionName || h.book || h.edition
  return name + " " + h.number
}

// The bar is 26px tall. Arabic never goes in it, and neither does a paragraph:
// a glyph, optionally a short reference, is all that fits honestly.
function barLabel(state, mode) {
  if (mode === "glyph" || !state) return ""
  var ref = ayahReference(state) || hadithReference(state)
  if (mode === "glyph-reference") return ref
  if (mode === "glyph-snippet") {
    var a = state.ayah
    var h = state.hadith
    var text = (a && (a.translation || a.text)) || (h && h.text) || ""
    return snippet(text, 44)
  }
  return ""
}

function tooltipText(state) {
  if (!state || !hasContent(state)) return "Daily Ayah & Hadith"
  var parts = []
  if (state.ayah) parts.push(ayahReference(state) + " — " + snippet(state.ayah.translation || state.ayah.text, 90))
  if (state.hadith) parts.push(hadithReference(state) + " — " + snippet(state.hadith.text, 90))
  return parts.join("\n")
}

// ------------------------------------------------------------------ helpers

function cacheDir(home, xdgCache) {
  return (xdgCache && xdgCache.length ? xdgCache : home + "/.cache") + "/omarchy-daily-deen"
}

function stateDir(home, xdgState) {
  return (xdgState && xdgState.length ? xdgState : home + "/.local/state") + "/omarchy-daily-deen"
}

// The argv the service hands to Process. Built here so it is testable, and
// always as an array: remote text must never be interpolated into a shell
// string.
function pickArgs(helper, settings, force, offline) {
  function get(k, fallback) {
    var v = settings ? settings[k] : undefined
    return v === undefined || v === null ? fallback : v
  }
  var args = [helper, "pick",
    "--interval-hours", String(get("rotationHours", 6)),
    "--mode", String(get("rotationMode", "deterministic")),
    "--quran", String(get("quranEdition", "ara-quranuthmanihaf")),
    "--quran-translation", String(get("quranTranslationEdition", "eng-abdelhaleem")),
    "--hadith", String(get("hadithEdition", "eng-abudawud")),
    "--hadith-arabic", String(get("hadithArabicEdition", "")),
    "--grade-filter", String(get("gradeFilter", "sahih-hasan")),
    "--authority", String(get("gradeAuthority", "Al-Albani"))]
  if (get("showAyah", true) !== true) args.push("--no-ayah")
  if (get("showHadith", true) !== true) args.push("--no-hadith")
  if (force) args.push("--force")
  if (offline) args.push("--offline")
  return args
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    PLUGIN_ID: PLUGIN_ID,
    entrySettings: entrySettings, entryWith: entryWith,
    defaultState: defaultState, parseState: parseState, hasContent: hasContent,
    rotationDue: rotationDue, nextRotationAt: nextRotationAt, formatDuration: formatDuration,
    languageOptions: languageOptions, quranEditionOptions: quranEditionOptions,
    hadithLanguageOptions: hadithLanguageOptions, hadithBookOptions: hadithBookOptions,
    hadithEditionOptions: hadithEditionOptions, editionInfo: editionInfo,
    arabicCounterpart: arabicCounterpart,
    isRtl: isRtl, safeDisplayText: safeDisplayText, snippet: snippet,
    fontsFor: fontsFor, pickFamily: pickFamily, familyFor: familyFor,
    lineHeightFor: lineHeightFor,
    ayahReference: ayahReference, hadithReference: hadithReference,
    barLabel: barLabel, tooltipText: tooltipText,
    cacheDir: cacheDir, stateDir: stateDir, pickArgs: pickArgs
  }
}
