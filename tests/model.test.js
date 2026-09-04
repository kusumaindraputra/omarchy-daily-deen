const test = require("node:test")
const assert = require("node:assert/strict")
const Model = require("../Model.js")
const Grades = require("../Grades.js")

const ID = "io.github.kusumaindraputra.daily-deen"

const CATALOG = {
  quran: [
    { slug: "ara-quranuthmanihaf", language: "Arabic", author: "Quran Uthmani Hafs", direction: "rtl", latin: false, comments: "" },
    { slug: "ara-quran-la", language: "Arabic", author: "Quran Transliteration", direction: "ltr", latin: true, comments: "" },
    { slug: "ind-indonesianislam", language: "Indonesian", author: "Indonesian Islamic Affairs Ministry", direction: "ltr", latin: false, comments: "" },
    { slug: "ind-kingfahdcomplex", language: "Indonesian", author: "King Fahd Complex", direction: "ltr", latin: false, comments: "OCRed" },
    { slug: "eng-abdelhaleem", language: "English", author: "Abdel Haleem", direction: "ltr", latin: false, comments: "" }
  ],
  hadith: [
    { slug: "ara-abudawud", book: "abudawud", language: "Arabic", direction: "rtl", comments: "" },
    { slug: "ara-abudawud1", book: "abudawud", language: "Arabic", direction: "rtl", comments: "Diacritics removed" },
    { slug: "ind-abudawud", book: "abudawud", language: "Indonesian", direction: "ltr", comments: "" },
    { slug: "eng-abudawud", book: "abudawud", language: "English", direction: "ltr", comments: "" },
    { slug: "eng-bukhari", book: "bukhari", language: "English", direction: "ltr", comments: "" }
  ],
  books: { abudawud: { name: "Sunan Abu Dawud" }, bukhari: { name: "Sahih al Bukhari" } },
  surahs: [{ n: 2, name: "Al-Baqara", english: "The Cow", arabic: "سورة البقرة", ayahs: 286 }]
}

// --- settings -------------------------------------------------------------

test("entrySettings finds the widget's inline settings in any bar section", () => {
  const config = {
    bar: { layout: {
      left: [{ id: "omarchy.workspaces" }],
      right: [{ id: "omarchy.clock", format: "HH:mm" }, { id: ID, rotationHours: 12, notify: false }]
    } }
  }
  assert.deepEqual(Model.entrySettings(config, ID), { rotationHours: 12, notify: false })
})

test("entrySettings falls back to plugins[] for a non-bar placement", () => {
  const config = { plugins: [{ id: ID, rotationHours: 3 }] }
  assert.deepEqual(Model.entrySettings(config, ID), { rotationHours: 3 })
})

test("entrySettings survives a missing or malformed config", () => {
  assert.deepEqual(Model.entrySettings(null, ID), {})
  assert.deepEqual(Model.entrySettings({ bar: { layout: { right: "nonsense" } } }, ID), {})
})

test("entryWith keeps the rest of the entry and drops a cleared key", () => {
  const settings = { rotationHours: 6, gradeFilter: "sahih", notify: true }
  assert.deepEqual(Model.entryWith(settings, ID, "gradeFilter", "daif"),
    { id: ID, rotationHours: 6, gradeFilter: "daif", notify: true })
  assert.deepEqual(Model.entryWith(settings, ID, "gradeFilter", ""),
    { id: ID, rotationHours: 6, notify: true })
})

// --- rotation -------------------------------------------------------------

test("rotation compares against the stored timestamp, so a restart does not reset it", () => {
  const chosen = 1_000_000_000_000
  const hour = 3600000
  assert.equal(Model.rotationDue(chosen, 6, chosen + 5 * hour), false)
  assert.equal(Model.rotationDue(chosen, 6, chosen + 6 * hour), true)
  // A laptop that slept through twenty hours is due exactly once, not four times.
  assert.equal(Model.rotationDue(chosen, 6, chosen + 20 * hour), true)
  assert.equal(Model.nextRotationAt(chosen, 6), chosen + 6 * hour)
})

test("rotation treats a never-picked state as due and a bad interval as six hours", () => {
  assert.equal(Model.rotationDue(0, 6, 123), true)
  assert.equal(Model.rotationDue(1000, 0, 1000 + 6 * 3600000), true)
  assert.equal(Model.rotationDue(1000, 0, 1000 + 5 * 3600000), false)
})

test("formatDuration reads as a countdown, never as 0m while time remains", () => {
  assert.equal(Model.formatDuration(3 * 3600000 + 25 * 60000), "3h 25m")
  assert.equal(Model.formatDuration(90000), "1m")
  assert.equal(Model.formatDuration(30000), "1m")
  assert.equal(Model.formatDuration(50 * 3600000), "2d 2h")
  assert.equal(Model.formatDuration(-5), "0m")
})

// --- state ----------------------------------------------------------------

test("parseState never throws and always yields a usable shape", () => {
  assert.deepEqual(Model.parseState(""), Model.defaultState())
  assert.deepEqual(Model.parseState("{ truncated"), Model.defaultState())
  assert.deepEqual(Model.parseState("42"), Model.defaultState())
  const ok = Model.parseState(JSON.stringify({ chosenAt: 5, ayah: { surah: 1 } }))
  assert.equal(ok.chosenAt, 5)
  assert.deepEqual(ok.unavailable, [])
})

// --- catalog pickers ------------------------------------------------------

test("language options are unique and counted", () => {
  const langs = Model.languageOptions(CATALOG, "quran")
  assert.deepEqual(langs.map(l => l.value), ["Arabic", "English", "Indonesian"])
  assert.equal(langs.find(l => l.value === "Indonesian").description, "2 editions")
})

test("Latin transliterations stay out of the translation picker unless asked for", () => {
  const arabic = Model.quranEditionOptions(CATALOG, "Arabic")
  assert.deepEqual(arabic.map(e => e.value), ["ara-quranuthmanihaf"])

  const withLatin = Model.quranEditionOptions(CATALOG, "Arabic", { includeLatin: true })
  assert.equal(withLatin.length, 2)

  const onlyLatin = Model.quranEditionOptions(CATALOG, "Arabic", { onlyLatin: true })
  assert.deepEqual(onlyLatin.map(e => e.value), ["ara-quran-la"])
})

test("edition options carry the slug in the description so search finds it", () => {
  const ind = Model.quranEditionOptions(CATALOG, "Indonesian")
  const kf = ind.find(e => e.value === "ind-kingfahdcomplex")
  assert.equal(kf.label, "King Fahd Complex")
  assert.match(kf.description, /ind-kingfahdcomplex/)
  assert.match(kf.description, /OCRed/)
})

test("hadith books are filtered by language, since not every book exists in every one", () => {
  assert.deepEqual(Model.hadithBookOptions(CATALOG, "Indonesian").map(b => b.value), ["abudawud"])
  assert.deepEqual(Model.hadithBookOptions(CATALOG, "English").map(b => b.value).sort(),
    ["abudawud", "bukhari"])
  assert.equal(Model.hadithBookOptions(CATALOG, "English")[0].label, "Sahih al Bukhari")
})

test("the Arabic counterpart of a hadith edition skips the de-diacriticised variant", () => {
  assert.equal(Model.arabicCounterpart(CATALOG, "ind-abudawud"), "ara-abudawud")
  assert.equal(Model.arabicCounterpart(CATALOG, "nope"), "")
})

// --- rendering ------------------------------------------------------------

test("safeDisplayText strips control characters and angle brackets", () => {
  const raw = "lineone <b>bold</b>\nline two​"
  assert.equal(Model.safeDisplayText(raw), "line one bbold/b line two")
  assert.equal(Model.safeDisplayText(null), "")
})

test("snippet cuts on a word boundary and marks the cut", () => {
  const text = "the quick brown fox jumps over the lazy dog and keeps going"
  const cut = Model.snippet(text, 20)
  assert.ok(cut.length <= 21, cut)
  assert.ok(cut.endsWith("…"))
  assert.equal(Model.snippet("short", 20), "short")
})

test("references read the way a person would cite them", () => {
  const state = {
    ayah: { surah: 2, ayah: 255, surahName: "Al-Baqara" },
    hadith: { number: 1035, collectionName: "Sunan Abu Dawud", book: "abudawud" }
  }
  assert.equal(Model.ayahReference(state), "Al-Baqara 2:255")
  assert.equal(Model.hadithReference(state), "Sunan Abu Dawud 1035")
  assert.equal(Model.ayahReference({}), "")
})

test("the bar never carries a paragraph", () => {
  const state = {
    ayah: { surah: 2, ayah: 255, surahName: "Al-Baqara",
            translation: "God: there is no god but Him, the Ever Living, the Ever Watchful" }
  }
  assert.equal(Model.barLabel(state, "glyph"), "")
  assert.equal(Model.barLabel(state, "glyph-reference"), "Al-Baqara 2:255")
  assert.ok(Model.barLabel(state, "glyph-snippet").length <= 45)
})

// --- helper argv ----------------------------------------------------------

test("pickArgs is an argv array, so remote text can never reach a shell string", () => {
  const args = Model.pickArgs("/p/deen-fetch", { rotationHours: 12, gradeFilter: "daif" }, true, false)
  assert.equal(args[0], "/p/deen-fetch")
  assert.equal(args[1], "pick")
  assert.equal(args[args.indexOf("--interval-hours") + 1], "12")
  assert.equal(args[args.indexOf("--grade-filter") + 1], "daif")
  assert.ok(args.includes("--force"))
  assert.ok(!args.includes("--offline"))
  assert.ok(args.every(a => typeof a === "string"))
})

test("pickArgs suppresses a section the user turned off", () => {
  const args = Model.pickArgs("/p/deen-fetch", { showAyah: false }, false, true)
  assert.ok(args.includes("--no-ayah"))
  assert.ok(!args.includes("--no-hadith"))
  assert.ok(args.includes("--offline"))
})

// --- grade presentation ---------------------------------------------------

test("badges dedupe identical verdicts and list every grader behind them", () => {
  const hadith = { grades: [
    { name: "Al-Albani", grade: "Sahih" },
    { name: "Zubair Ali Zai", grade: "Sahih" },
    { name: "Shuaib Al Arnaut", grade: "Hasan" }
  ] }
  const badges = Grades.badges(hadith)
  assert.deepEqual(badges.map(b => b.grade), ["Sahih", "Hasan"])
  assert.equal(Grades.graderLine(badges[0]), "Al-Albani, Zubair Ali Zai")
})

test("an ungraded collection produces no badges rather than an empty one", () => {
  assert.deepEqual(Grades.badges({ grades: [] }), [])
  assert.deepEqual(Grades.badges(null), [])
  assert.equal(Grades.isImplicitlySahih("bukhari"), true)
  assert.equal(Grades.isImplicitlySahih("abudawud"), false)
})
