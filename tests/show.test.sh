#!/usr/bin/env bash
#
# deen-fetch show: step to the neighbouring ayah without touching the rotation.
#
# show is read-only and cache-only. It must cross surah borders using the
# catalog's ayah counts, refuse the two ends, refuse bad numbers and slugs, give
# an ayah object shaped exactly like pick's, and leave cache and state alone.
#
# Hermetic: XDG_CACHE_HOME and XDG_STATE_HOME point at a temp tree and the
# catalog and editions are made up here.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export XDG_CACHE_HOME="$TMP/cache" XDG_STATE_HOME="$TMP/state"
DATA="$XDG_CACHE_HOME/omarchy-daily-deen"
STATE="$XDG_STATE_HOME/omarchy-daily-deen"
mkdir -p "$DATA/quran" "$STATE"

jq -n '{ version: 1, fetchedAt: 0, generatedBy: "test",
  quran: [
    { slug: "ar-test", language: "Arabic", author: "A", direction: "rtl" },
    { slug: "en-test", language: "English", author: "E", direction: "ltr" }],
  hadith: [], books: {},
  surahs: [
    { n: 1, name: "One",   english: "First",  arabic: "ا", ayahs: 3 },
    { n: 2, name: "Two",   english: "Second", arabic: "ب", ayahs: 2 },
    { n: 3, name: "Three", english: "Third",  arabic: "ت", ayahs: 4 }] }' > "$DATA/catalog.json"
for ed in ar en; do
  jq -n --arg p "$ed" '{ quran: [ ([1,3], [2,2], [3,4]) as [$c, $n]
    | range(1; $n + 1) as $v
    | { chapter: $c, verse: $v, text: "\($p) \($c):\($v)" } ] }' \
    > "$DATA/quran/$ed-test.json"
done
echo '["ayah:9:9"]' > "$STATE/seen.json"
echo '{"marker":1}' > "$STATE/current.json"

fail=0
ok()  { printf 'ok    %s\n' "$1"; }
bad() { printf 'FAIL  %s\n' "$1"; fail=$(( fail + 1 )); }

show() { ./bin/deen-fetch show --quran ar-test --quran-translation en-test "$@"; }
at()   { # expected "S:A" for the given args
  local want="$1" out; shift
  out="$(show "$@" 2>&1)"
  local got; got="$(jq -r '"\(.surah):\(.ayah)"' <<<"$out" 2>/dev/null)"
  if [[ $got == "$want" ]]; then ok "$* -> $want"; else bad "$* -> $got (wanted $want): $out"; fi
}
refuse() { # message-substring, args...
  local msg="$1" out err code; shift
  out="$(show "$@" 2>"$TMP/err")"; code=$?; err="$(<"$TMP/err")"
  if (( code == 1 )) && [[ -z $out ]] && grep -q -- "$msg" <<<"$err"; then
    ok "refused ($msg): $*"
  else bad "not refused properly ($msg): $* code=$code out='$out' err='$err'"; fi
}

snapshot() { find "$XDG_CACHE_HOME" "$XDG_STATE_HOME" -print0 | sort -z \
  | xargs -0 sh -c 'for f; do if [ -f "$f" ]; then sha256sum "$f"; else echo "dir $f"; fi; done' _; }
before="$(snapshot)"

# --- a specific ayah, in full -------------------------------------------------
out="$(show --surah 2 --ayah 1)"
want='{"edition":"ar-test","editionAuthor":"A","language":"Arabic","direction":"rtl","surah":2,"ayah":1,"text":"ar 2:1","surahName":"Two","surahEnglish":"Second","surahArabic":"ب","ayahCount":2,"translationEdition":"en-test","translationAuthor":"E","translationLanguage":"English","translationDirection":"ltr","translation":"en 2:1"}'
if [[ "$(jq -cS . <<<"$out")" == "$(jq -cS . <<<"$want")" ]]; then ok "plain ayah is complete"
else bad "plain ayah differs: $out"; fi

# --- stepping -----------------------------------------------------------------
at 1:2 --surah 1 --ayah 1 --step 1
at 1:1 --surah 1 --ayah 2 --step -1
at 2:1 --surah 1 --ayah 3 --step 1
at 3:1 --surah 2 --ayah 2 --step 1
at 1:3 --surah 2 --ayah 1 --step -1
at 2:2 --surah 3 --ayah 1 --step -1
at 3:4 --surah 3 --ayah 3 --step 1

# --- the ends -----------------------------------------------------------------
refuse "deen-fetch: no previous ayah" --surah 1 --ayah 1 --step -1
refuse "deen-fetch: no next ayah"     --surah 3 --ayah 4 --step 1
at 1:1 --surah 1 --ayah 1
at 3:4 --surah 3 --ayah 4

# --- bad numbers --------------------------------------------------------------
for v in 0 -1 abc "" 1.5 "1 2"; do
  refuse "invalid surah" --surah "$v" --ayah 1
  refuse "invalid ayah"  --surah 1 --ayah "$v"
done
for v in 0 2 -2 x ""; do refuse "invalid step" --surah 1 --ayah 1 --step "$v"; done
refuse "unknown flag" --surah 1 --ayah 1 --bogus
refuse "not found in edition" --surah 1 --ayah 4
refuse "not in the catalog" --surah 1 --ayah 4 --step 1
refuse "not found in edition" --surah 9 --ayah 1
refuse "not in the catalog" --surah 9 --ayah 1 --step -1

# --- bad slugs and uncached editions -----------------------------------------
for evil in "../../x" "a/b" ".hidden" "-lead" "x..y"; do
  out="$(./bin/deen-fetch show --quran "$evil" --surah 1 --ayah 1 2>&1)"; code=$?
  if (( code == 1 )) && grep -q "refusing quran slug" <<<"$out"; then ok "slug '$evil' refused"
  else bad "slug '$evil': code=$code $out"; fi
  out="$(./bin/deen-fetch show --quran ar-test --quran-translation "$evil" --surah 1 --ayah 1 2>&1)"; code=$?
  if (( code == 1 )) && grep -q "refusing quran translation slug" <<<"$out"; then ok "translation slug '$evil' refused"
  else bad "translation slug '$evil': code=$code $out"; fi
done
out="$(./bin/deen-fetch show --quran nope --surah 1 --ayah 1 2>&1)"; code=$?
if (( code == 1 )) && [[ $out == "deen-fetch: edition nope is not cached" ]]; then ok "uncached edition refused"
else bad "uncached edition: code=$code $out"; fi
out="$(show --surah 1 --ayah 1 --quran-translation nope 2>&1)"; code=$?
if (( code == 1 )) && [[ $out == *"edition nope is not cached" ]]; then ok "uncached translation refused"
else bad "uncached translation: code=$code $out"; fi

# --- same shape as pick -------------------------------------------------------
pk="$(./bin/deen-fetch pick --no-sync --no-hadith --quran ar-test --quran-translation en-test --force 2>/dev/null | jq -c '.ayah')"
sh="$(jq -c --argjson a "$pk" 'select(.)' <<<"$(show --surah "$(jq .surah <<<"$pk")" --ayah "$(jq .ayah <<<"$pk")")")"
if [[ -n $pk && "$(jq -c 'keys' <<<"$pk")" == "$(jq -c 'keys' <<<"$sh")" && "$pk" == "$sh" ]]; then
  ok "show and pick agree on the ayah object"
else bad "shape differs: pick=$pk show=$sh"; fi
before="$(snapshot)"   # pick above legitimately wrote state; re-baseline

# --- nothing written ----------------------------------------------------------
show --surah 1 --ayah 3 --step 1 >/dev/null
show --surah 2 --ayah 1 >/dev/null
show --surah 1 --ayah 1 --step -1 >/dev/null 2>&1
show --surah 9 --ayah 9 >/dev/null 2>&1
after="$(snapshot)"
if [[ "$before" == "$after" ]]; then ok "cache and state are untouched by show"
else bad "show changed files:"; diff <(echo "$before") <(echo "$after"); fi

# --- show never creates the directories either -------------------------------
rm -rf "$TMP/c2" "$TMP/s2"
XDG_CACHE_HOME="$TMP/c2" XDG_STATE_HOME="$TMP/s2" ./bin/deen-fetch show --quran ar-test --surah 1 --ayah 1 >/dev/null 2>&1
if [[ ! -e $TMP/c2 && ! -e $TMP/s2 ]]; then ok "show creates no directories"
else bad "show created directories"; fi

if (( fail )); then printf '\nshow: %s failed\n' "$fail"; exit 1; fi
printf '\nshow: all checks passed\n'
