const test = require("node:test")
const assert = require("node:assert/strict")
const I18n = require("../I18n.js")

// The one i18n bug worth catching mechanically: a locale that quietly lost a
// key and now falls back to English in the middle of an otherwise translated
// panel.
test("every locale carries exactly the English key set", () => {
  const expected = Object.keys(I18n.STRINGS.en).sort()
  for (const locale of I18n.locales()) {
    const actual = Object.keys(I18n.STRINGS[locale]).sort()
    const missing = expected.filter(k => !actual.includes(k))
    const extra = actual.filter(k => !expected.includes(k))
    assert.deepEqual(missing, [], `${locale} is missing: ${missing.join(", ")}`)
    assert.deepEqual(extra, [], `${locale} has keys English does not: ${extra.join(", ")}`)
  }
})

test("no locale ships an empty string in place of a translation", () => {
  for (const locale of I18n.locales()) {
    for (const [key, value] of Object.entries(I18n.STRINGS[locale])) {
      assert.equal(typeof value, "string", `${locale}.${key} is not a string`)
      assert.ok(value.trim().length > 0, `${locale}.${key} is blank`)
    }
  }
})

test("every shipped locale has a native name for the picker", () => {
  for (const locale of I18n.locales()) {
    assert.ok(I18n.LOCALE_NAMES[locale], `${locale} has no native name`)
  }
})

test("auto follows the content language when that locale exists", () => {
  assert.equal(I18n.resolve("auto", "Indonesian", "en_US"), "id")
  assert.equal(I18n.resolve("auto", "Arabic", "en_US"), "ar")
  assert.equal(I18n.resolve("auto", "Turkish", "en_US"), "tr")
})

test("auto falls back to the system locale, then to English", () => {
  // Javanese has 2 Qur'an translations but no UI locale here.
  assert.equal(I18n.resolve("auto", "Javanese", "id_ID"), "id")
  assert.equal(I18n.resolve("auto", "Javanese", "xx_XX"), "en")
  assert.equal(I18n.resolve("auto", "", ""), "en")
})

test("an explicit choice wins over the content language", () => {
  assert.equal(I18n.resolve("fr", "Indonesian", "id_ID"), "fr")
  // ...but an unknown one does not strand the user in a blank UI.
  assert.equal(I18n.resolve("eo", "Indonesian", "id_ID"), "en")
})

test("t falls back per key rather than per locale", () => {
  assert.equal(I18n.t("id", "settings"), "Pengaturan")
  assert.equal(I18n.t("id", "somethingNobodyTranslated"), "somethingNobodyTranslated")
  assert.equal(I18n.t("zz", "settings"), "Settings")
})

test("the RTL locales are exactly the ones written right to left", () => {
  assert.equal(I18n.isRtlLocale("ar"), true)
  assert.equal(I18n.isRtlLocale("ur"), true)
  assert.equal(I18n.isRtlLocale("en"), false)
  assert.equal(I18n.isRtlLocale("bn"), false)
})

test("the locale picker leads with auto and then lists native names", () => {
  const opts = I18n.localeOptions("id")
  assert.equal(opts[0].value, "auto")
  assert.equal(opts[0].label, "Ikut bahasa terjemahan")
  assert.ok(opts.some(o => o.value === "ar" && o.label === "العربية"))
  assert.equal(opts.length, I18n.locales().length + 1)
})
