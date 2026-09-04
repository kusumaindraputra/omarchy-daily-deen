const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const I18n = require("../I18n.js")

// The key-parity test in i18n.test.js compares the locales against each other,
// so a key that no locale has — including English — sails straight past it. That
// is exactly what happened to `showArabic`: the panel asked for it, t() fell all
// the way through to returning the key, and the toggle in the settings section
// was labelled "showArabic" in every language.
//
// This reads the QML instead, which is the only place that knows what is
// actually asked for.

const ROOT = path.join(__dirname, "..")
const QML = fs.readdirSync(ROOT).filter(f => f.endsWith(".qml"))

function keysUsedIn(file) {
  const source = fs.readFileSync(path.join(ROOT, file), "utf8")
  const keys = new Set()
  // t("key") and I18n.t(locale, "key")
  for (const m of source.matchAll(/\bt\(\s*"([A-Za-z][A-Za-z0-9_]*)"\s*\)/g)) keys.add(m[1])
  for (const m of source.matchAll(/I18n\.t\(\s*[^,]+,\s*"([A-Za-z][A-Za-z0-9_]*)"\s*\)/g)) keys.add(m[1])
  return keys
}

test("every string the QML asks for exists in English", () => {
  assert.ok(QML.length > 0, "no QML files found to scan")
  const missing = []
  for (const file of QML) {
    for (const key of keysUsedIn(file)) {
      if (I18n.STRINGS.en[key] === undefined) missing.push(`${file}: ${key}`)
    }
  }
  assert.deepEqual(missing, [], `keys with no English string:\n  ${missing.join("\n  ")}`)
})

test("t never hands back the key it was given for a key the QML uses", () => {
  for (const file of QML) {
    for (const key of keysUsedIn(file)) {
      for (const locale of I18n.locales()) {
        assert.notEqual(I18n.t(locale, key), key,
          `${locale}.${key} would render as the raw key in the UI (asked for by ${file})`)
      }
    }
  }
})
