#!/usr/bin/env bash
#
# What deen-fetch refuses to do with what it downloads.
#
# Edition slugs are not ours. They arrive inside the catalogs fetched from the
# CDN, are stored in the plugin's settings, and are then pasted into both a URL
# and a cache path. A slug carrying a slash or a .. would write a CDN response
# somewhere else under the user account; a response with no size limit would
# fill the disk on the way there. Both were raised in the marketplace security
# review of commit 84b8547.
#
# Hermetic: XDG_CACHE_HOME and XDG_STATE_HOME point at a temp tree, the catalog
# and edition are made up here, and nothing reaches the network.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export XDG_CACHE_HOME="$TMP/cache" XDG_STATE_HOME="$TMP/state"
DATA="$XDG_CACHE_HOME/omarchy-daily-deen"
mkdir -p "$DATA/quran" "$TMP/canary"

jq -n '{ version: 1, fetchedAt: 0, generatedBy: "test",
         quran: [{ slug: "test-edition", language: "English", author: "Test",
                   direction: "ltr", latin: false, comments: "", source: "" }],
         hadith: [], books: {}, surahs: [] }' > "$DATA/catalog.json"
jq -n '{ quran: [range(1; 21) | { chapter: 2, verse: ., text: "verse \(.)" }] }' \
  > "$DATA/quran/test-edition.json"

fail=0
ok()   { printf 'ok    %s\n' "$1"; }
bad()  { printf 'FAIL  %s\n' "$1"; fail=$(( fail + 1 )); }

# --- a traversing slug is refused, and writes nothing outside the cache ------
for evil in "../../canary/pwned" "..%2F..%2Fpwned" "a/b" ".hidden" "-leading" "x..y"; do
  out="$(./bin/deen-fetch pick --no-sync --no-hadith --quran "$evil" 2>&1)"
  code=$?
  if (( code == 0 )); then
    bad "slug '$evil' was accepted (exit 0)"
  elif ! grep -q "refusing" <<<"$out"; then
    bad "slug '$evil' failed for the wrong reason: $out"
  else
    ok "slug '$evil' refused"
  fi
done

if [[ -n "$(ls -A "$TMP/canary" 2>/dev/null)" ]]; then
  bad "a refused slug still wrote into $TMP/canary"
else
  ok "nothing escaped the cache directory"
fi

# --- the legitimate slug still works ----------------------------------------
if ./bin/deen-fetch pick --no-sync --no-hadith --quran test-edition >/dev/null 2>&1; then
  ok "an ordinary slug is still accepted"
else
  bad "the ordinary slug was rejected too"
fi

# --- an empty slug means 'not configured', not 'invalid' --------------------
if ./bin/deen-fetch pick --no-sync --no-ayah --hadith "" >/dev/null 2>&1; then
  ok "an empty slug is treated as unset"
else
  # No hadith cached, so a non-zero exit is expected; what matters is that it
  # did not die complaining about the slug.
  out="$(./bin/deen-fetch pick --no-sync --no-ayah --hadith "" 2>&1)"
  if grep -q "refusing" <<<"$out"; then
    bad "an empty slug was refused as invalid"
  else
    ok "an empty slug is treated as unset"
  fi
fi

# --- the size cap actually refuses bytes ------------------------------------
# accept_within is what stands between a response and the cache, so drive it
# directly rather than asserting that the source mentions it.
( eval "$(sed -n '/^accept_within()/,/^}/p' bin/deen-fetch)"
  note() { :; }
  big="$TMP/big"; dst="$TMP/dest-big"
  head -c 5000 /dev/zero > "$big"
  if accept_within "$big" "$dst" 1000 2>/dev/null; then exit 1; fi
  [[ -e $dst ]] && exit 2
  [[ -e $big ]] && exit 3
  small="$TMP/small"; dst2="$TMP/dest-small"
  head -c 500 /dev/zero > "$small"
  accept_within "$small" "$dst2" 1000 || exit 4
  [[ -s $dst2 ]] || exit 5
  exit 0 )
case $? in
  0) ok "an oversized response is discarded and an in-cap one accepted" ;;
  1) bad "an oversized response was accepted" ;;
  2) bad "an oversized response was written to its destination" ;;
  3) bad "the oversized temp file was left behind" ;;
  *) bad "an in-cap response was rejected or not written" ;;
esac

# Every curl call has to declare the cap, not just one of them.
calls="$(grep -c 'curl -fsS' bin/deen-fetch)"
caps="$(grep -c -- '--max-filesize "\$max"' bin/deen-fetch)"
if (( caps == calls )); then
  ok "all $calls curl calls declare --max-filesize"
else
  bad "$calls curl calls but $caps declare --max-filesize"
fi

# --- a hostile slug never reaches the cached catalog ------------------------
# Built offline from local raw files, so this needs no network: --offline makes
# fetch serve what is already on disk.
CAT="$TMP/cat"; CD="$CAT/c/omarchy-daily-deen"; mkdir -p "$CD/raw"
jq -n '{"eng_good":{name:"eng-good",language:"English",author:"Good",direction:"ltr"},
        "evil":{name:"../../../pwned",language:"English",author:"Evil",direction:"ltr"},
        "dots":{name:"a..b",language:"English",author:"Dots",direction:"ltr"}}' \
  > "$CD/raw/quran-editions.json"
jq -n '{"tirmidhi":{name:"Jami",collection:[{name:"eng-tirmidhi",language:"English",has_sections:true},
                                            {name:"../escape",language:"English",has_sections:true}]}}' \
  > "$CD/raw/hadith-editions.json"
jq -n '{chapters:[range(1;115)|{chapter:.,name:"S\(.)",englishname:"S\(.)",arabicname:"x",revelation:"Meccan",verses:[1,2,3]}]}' \
  > "$CD/raw/quran-info.json"
XDG_CACHE_HOME="$CAT/c" XDG_STATE_HOME="$CAT/s" \
  ./bin/deen-fetch pick --offline --no-hadith --quran eng-good >/dev/null 2>&1
if [[ -s $CD/catalog.json ]]; then
  kept="$(jq -c '[.quran[].slug]+[.hadith[].slug]|sort' "$CD/catalog.json")"
  if [[ $kept == '["eng-good","eng-tirmidhi"]' ]]; then
    ok "the catalog keeps only well-formed slugs ($kept)"
  else
    bad "the catalog kept something it should not: $kept"
  fi
else
  bad "no catalog was built from the local raw files"
fi

# --- a catalog that parses but carries nothing is refused -------------------
EMP="$TMP/empty"; ED="$EMP/c/omarchy-daily-deen"; mkdir -p "$ED/raw"
jq -n '{}' > "$ED/raw/quran-editions.json"
jq -n '{}' > "$ED/raw/hadith-editions.json"
jq -n '{chapters:[]}' > "$ED/raw/quran-info.json"
# --offline again: without it fetch would go and get the real editions, quietly
# replacing the bait and testing nothing.
XDG_CACHE_HOME="$EMP/c" XDG_STATE_HOME="$EMP/s" \
  ./bin/deen-fetch pick --offline --no-hadith --quran eng-good >/dev/null 2>&1
# The message itself is not asserted: cmd_pick swallows a failing sync on
# purpose, so that a pick still serves what is cached. What matters is that
# nothing was written.
if [[ -e $ED/catalog.json ]]; then
  bad "an empty catalog was cached anyway"
else
  ok "an empty catalog is refused rather than cached"
fi
unset out

if (( fail )); then printf '\ninputs: %s failed\n' "$fail"; exit 1; fi
printf '\ninputs: all checks passed\n'
