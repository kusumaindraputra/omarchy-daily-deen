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

# --- the download cap is wired to every fetch -------------------------------
if grep -q 'curl' bin/deen-fetch && ! grep -q -- '--max-filesize' bin/deen-fetch; then
  bad "curl is called without --max-filesize"
else
  ok "curl declares a producer-side size cap"
fi
missing="$(grep -n 'curl -fsS' bin/deen-fetch | wc -l)"
capped="$(grep -c 'max-filesize' bin/deen-fetch)"
if (( capped < missing )); then
  bad "$missing curl calls but only $capped size caps"
else
  ok "every curl call carries a size cap ($capped for $missing calls)"
fi
# A declared length is not the only way bytes arrive, so the delivered file is
# measured too.
if grep -q 'accept_within' bin/deen-fetch; then
  ok "delivered bytes are measured before a file is accepted"
else
  bad "nothing re-checks the size of what actually arrived"
fi

if (( fail )); then printf '\ninputs: %s failed\n' "$fail"; exit 1; fi
printf '\ninputs: all checks passed\n'
