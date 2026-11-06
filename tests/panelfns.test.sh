#!/usr/bin/env bash
#
# The panel's own setting functions, run as written in Panel.qml.
#
# cfg() must let false and 0 through (only undefined/null take the fallback);
# changing a language must choose the first edition of the new one, and leave
# "" (not a stranded edition) when it has none; the Arabic edition follows
# showArabic. persist() is stubbed to capture what it is asked to write; the
# rest is lifted out of Panel.qml. PANEL_QML points at another copy to test.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

command -v qml6 >/dev/null || { echo "skip  qml6 not installed"; exit 0; }
PANEL="${PANEL_QML:-Panel.qml}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cp Model.js "$TMP/"

extract() {
  awk -v name="$1" '
    $0 ~ "^  function " name "\\(" { on = 1 }
    on { print; n = gsub(/{/, "{"); m = gsub(/}/, "}"); depth += n - m; if (depth == 0) exit }
  ' "$PANEL"
}

CODE=""
for f in cfg setContentLanguage setHadithLanguage setHadithBook setShowArabic; do
  body="$(extract "$f")"
  [[ -n "$body" ]] || { echo "FAIL  could not find $f() in $PANEL"; exit 1; }
  CODE+="$body"$'\n'
done
SHOWARABIC="$(grep -m1 'property bool showArabic:' "$PANEL")"
[[ -n "$SHOWARABIC" ]] || { echo "FAIL  could not find showArabic in $PANEL"; exit 1; }

cat > "$TMP/h.qml" <<QML
import QtQuick
import "Model.js" as Model
Item {
  id: root
  property var liveSettings: ({})
  property var written: null
  property var catalog: ({
    books: { abudawud: { name: "Sunan Abu Dawud" }, bukhari: { name: "Sahih al-Bukhari" } },
    quran: [
      { slug: "ind-zeta",  language: "Indonesian", author: "Zeta" },
      { slug: "ind-alpha", language: "Indonesian", author: "Alpha" },
      { slug: "ind-latin", language: "Indonesian", author: "AAA", latin: true },
      { slug: "eng-sahih", language: "English",    author: "Sahih" }
    ],
    hadith: [
      { slug: "eng-abudawud", language: "English",    book: "abudawud" },
      { slug: "ara-abudawud", language: "Arabic",     book: "abudawud" },
      { slug: "eng-bukhari",  language: "English",    book: "bukhari" },
      { slug: "ara-bukhari",  language: "Arabic",     book: "bukhari" },
      { slug: "ara-bukhari1", language: "Arabic",     book: "bukhari" },
      { slug: "ind-bukhari",  language: "Indonesian", book: "bukhari" }
    ]
  })
  function persist(values) { written = values }
$SHOWARABIC
$CODE

  function show(v) { return JSON.stringify(v) }
  function run(fn, settings) { liveSettings = settings; written = null; fn(); return show(written) }

  Component.onCompleted: {
    var out = []
    liveSettings = ({ f: false, z: 0, e: "", u: undefined, n: null, s: "x" })
    out.push("cfg:" + [cfg("f", true), cfg("z", 9), cfg("e", "d"), cfg("u", "fb"), cfg("n", "fb"), cfg("missing", "fb"), cfg("s", "fb")].join(","))
    liveSettings = null
    out.push("cfgnull:" + cfg("a", "fb"))

    out.push("cl1:" + run(function() { setContentLanguage("Indonesian") }, {}))
    out.push("cl2:" + run(function() { setContentLanguage("Klingon") }, { quranTranslationEdition: "ind-alpha" }))

    out.push("hl1:" + run(function() { setHadithLanguage("English") }, {}))
    out.push("hl2:" + run(function() { setHadithLanguage("English") }, { showArabic: false }))
    out.push("hl3:" + run(function() { setHadithLanguage("Indonesian") }, { showArabic: true }))
    out.push("hl4:" + run(function() { setHadithLanguage("Klingon") }, { showArabic: true }))

    out.push("hb1:" + run(function() { setHadithBook("bukhari") }, { hadithLanguage: "English" }))
    out.push("hb2:" + run(function() { setHadithBook("bukhari") }, { hadithLanguage: "Indonesian", showArabic: false }))
    out.push("hb3:" + run(function() { setHadithBook("abudawud") }, { hadithLanguage: "Indonesian" }))
    out.push("hb4:" + run(function() { setHadithBook("bukhari") }, {}))

    out.push("sa1:" + run(function() { setShowArabic(true) }, { hadithEdition: "eng-bukhari" }))
    out.push("sa2:" + run(function() { setShowArabic(true) }, {}))
    out.push("sa3:" + run(function() { setShowArabic(false) }, { hadithEdition: "eng-bukhari" }))
    console.log("RESULT " + out.join("\n"))
    Qt.quit()
  }
}
QML

out="$(QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen timeout 20 qml6 "$TMP/h.qml" 2>&1)"
got="$(sed -n '/RESULT/,$p' <<<"$out" | sed 's/^.*RESULT //' | grep -E '^[a-z0-9]+:')"

declare -A want=(
  [cfg]='cfg:false,0,,fb,fb,fb,x'
  [cfgnull]='cfgnull:fb'
  [cl1]='cl1:{"contentLanguage":"Indonesian","quranTranslationEdition":"ind-alpha"}'
  [cl2]='cl2:{"contentLanguage":"Klingon","quranTranslationEdition":""}'
  [hl1]='hl1:{"hadithLanguage":"English","hadithEdition":"eng-bukhari","hadithArabicEdition":"ara-bukhari"}'
  [hl2]='hl2:{"hadithLanguage":"English","hadithEdition":"eng-bukhari","hadithArabicEdition":""}'
  [hl3]='hl3:{"hadithLanguage":"Indonesian","hadithEdition":"ind-bukhari","hadithArabicEdition":"ara-bukhari"}'
  [hl4]='hl4:{"hadithLanguage":"Klingon","hadithEdition":"","hadithArabicEdition":""}'
  [hb1]='hb1:{"hadithEdition":"eng-bukhari","hadithArabicEdition":"ara-bukhari"}'
  [hb2]='hb2:{"hadithEdition":"ind-bukhari","hadithArabicEdition":""}'
  [hb3]='hb3:{"hadithEdition":"","hadithArabicEdition":""}'
  [hb4]='hb4:{"hadithEdition":"eng-bukhari","hadithArabicEdition":"ara-bukhari"}'
  [sa1]='sa1:{"showArabic":true,"hadithArabicEdition":"ara-bukhari"}'
  [sa2]='sa2:{"showArabic":true,"hadithArabicEdition":"ara-abudawud"}'
  [sa3]='sa3:{"showArabic":false,"hadithArabicEdition":""}'
)
desc=(
  "cfg: false and 0 and \"\" kept; undefined/null/missing fall back"
  "cfg: no settings object falls back"
  "setContentLanguage picks the first edition of the new language (Latin skipped)"
  "setContentLanguage to a language with no edition clears it"
  "setHadithLanguage fills the Arabic edition when showArabic defaults on"
  "setHadithLanguage leaves it empty when showArabic is off"
  "setHadithLanguage picks the first book (by label) and its edition"
  "setHadithLanguage with no books leaves no orphan edition"
  "setHadithBook picks the first edition in the current language"
  "setHadithBook respects showArabic=false"
  "setHadithBook with no edition in that language clears it"
  "setHadithBook defaults to English"
  "setShowArabic(true) derives the Arabic edition from hadithEdition"
  "setShowArabic(true) falls back to the default edition"
  "setShowArabic(false) empties hadithArabicEdition"
)
keys=(cfg cfgnull cl1 cl2 hl1 hl2 hl3 hl4 hb1 hb2 hb3 hb4 sa1 sa2 sa3)
fail=0
for i in "${!keys[@]}"; do
  k="${keys[$i]}"; line="$(grep -m1 "^$k:" <<<"$got")"
  if [[ "$line" == "${want[$k]}" ]]; then echo "ok    ${desc[$i]}"
  else echo "FAIL  ${desc[$i]}"; echo "      got  '$line'"; echo "      want '${want[$k]}'"; fail=1; fi
done
if (( fail )); then echo; echo "--- qml output"; head -20 <<<"$out"; exit 1; fi
echo; echo "panelfns: all checks passed"
