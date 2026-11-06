#!/usr/bin/env bash
#
# Favorites and pick history: reference-only lists kept in the state dir.
#
# Hermetic: XDG_CACHE_HOME and XDG_STATE_HOME are redirected at a temp tree and
# the editions are made up here, so this never touches real state or the network.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export XDG_CACHE_HOME="$TMP/cache" XDG_STATE_HOME="$TMP/state"
DATA="$XDG_CACHE_HOME/omarchy-daily-deen"
STATE="$XDG_STATE_HOME/omarchy-daily-deen"
FAV="$STATE/favorites.json"; HIST="$STATE/history.json"
mkdir -p "$DATA/quran" "$STATE"

jq -n '{
  version: 1, fetchedAt: 0, generatedBy: "test",
  quran: [{ slug: "test-edition", language: "English", author: "Test",
            direction: "ltr", latin: false, comments: "", source: "" }],
  hadith: [], books: {},
  surahs: [{ n: 2, name: "Al-Baqarah", english: "The Cow", arabic: "x", ayahs: 200 }]
}' > "$DATA/catalog.json"
jq -n '{ quran: [range(1; 201) | { chapter: 2, verse: ., text: "verse \(.)" }] }' \
  > "$DATA/quran/test-edition.json"

fd() { ./bin/deen-fetch "$@"; }
reset() { rm -f "$FAV" "$HIST"; }

fail=0
check() {
  local name="$1" expected="$2" actual="$3"
  if [[ $actual == "$expected" ]]; then
    printf 'ok    %s\n' "$name"
  else
    printf 'FAIL  %s: expected %s, got %s\n' "$name" "$expected" "$actual"
    fail=$(( fail + 1 ))
  fi
}
fails() { # name, command...
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf 'FAIL  %s: expected a non-zero exit\n' "$name"; fail=$(( fail + 1 ))
  else printf 'ok    %s\n' "$name"; fi
}
refs() { jq -c "$1 | map(\"\(.surah):\(.ayah)\") | join(\",\")" -r; }

EMPTY='{"favorites":[],"history":[]}'

# ---- lists: tolerant reads
reset
check "lists with no files" "$EMPTY" "$(fd lists)"
check "lists prints a single line" "1" "$(fd lists | wc -l)"
: > "$FAV"; : > "$HIST"
check "lists with empty files" "$EMPTY" "$(fd lists)"
echo 'not json {{' > "$FAV"; echo '\x00garbage' > "$HIST"
check "lists with corrupt files" "$EMPTY" "$(fd lists)"
echo '{"surah":1,"ayah":1}' > "$FAV"; echo '"str"' > "$HIST"
check "lists with non-array files" "$EMPTY" "$(fd lists)"
echo '[1,"a",null,{"surah":0,"ayah":1},{"surah":1,"ayah":0},{"surah":"2","ayah":1},{"surah":1.5,"ayah":1},{"surah":-3,"ayah":2},{"ayah":4},{"surah":3,"ayah":4,"name":"ok","at":7}]' > "$FAV"
check "garbage entries are dropped" '[{"surah":3,"ayah":4,"name":"ok","at":7}]' "$(fd lists | jq -c .favorites)"
echo '[{"surah":5,"ayah":6,"name":{"a":1}}]' > "$HIST"
check "a non-string name is coerced to a string" "string" "$(fd lists | jq -r '.history[0].name|type')"
printf '[{"surah":5,"ayah":6,"name":"a\\nb\\u0001c\\u007fd"}]' > "$HIST"
check "lists strips control characters" "abcd" "$(fd lists | jq -r '.history[0].name')"
jq -n --arg n "$(printf 'x%.0s' {1..200})" '[{surah:1,ayah:1,name:$n,at:1}]' > "$HIST"
check "lists cuts names to 60 chars" "60" "$(fd lists | jq -r '.history[0].name|length')"

# ---- fav-toggle
reset
out="$(fd fav-toggle --surah 2 --ayah 255 --name "Ayat al-Kursi")"
check "toggle on adds the favorite" "2:255" "$(refs .favorites <<<"$out")"
check "toggle on stores the name" "Ayat al-Kursi" "$(jq -r '.favorites[0].name' <<<"$out")"
check "toggle on stores a current timestamp" "true" "$(jq '.favorites[0].at > 1700000000' <<<"$out")"
check "toggle output matches lists" "$out" "$(fd lists)"
check "the favorites file holds only references" '["at","ayah","name","surah"]' "$(jq -c '.[0]|keys' "$FAV")"
fd fav-toggle --surah 1 --ayah 1 >/dev/null
out="$(fd fav-toggle --surah 3 --ayah 5)"
check "newest favorite comes first" "3:5,1:1,2:255" "$(refs .favorites <<<"$out")"
check "name defaults to empty" "" "$(jq -r '.favorites[0].name' <<<"$out")"
out="$(fd fav-toggle --surah 1 --ayah 1)"
check "toggle off removes only that favorite" "3:5,2:255" "$(refs .favorites <<<"$out")"
out="$(fd fav-toggle --surah 3 --ayah 5)"; out="$(fd fav-toggle --surah 2 --ayah 255)"
check "toggling everything off leaves none" "$EMPTY" "$out"
check "toggle leaves history alone" "[]" "$(jq -c .history <<<"$out")"

# leading zeros
reset
out="$(fd fav-toggle --surah 002 --ayah 0255)"
check "leading zeros are accepted" "2:255" "$(refs .favorites <<<"$out")"
out="$(fd fav-toggle --surah 2 --ayah 255)"
check "and 002:0255 is the same ayah as 2:255" "$EMPTY" "$out"
check "08 is decimal, not a bad octal" "8:9" "$(fd fav-toggle --surah 08 --ayah 09 | refs .favorites)"

# name sanitising
reset
out="$(fd fav-toggle --surah 1 --ayah 1 --name "$(printf 'a\nb\tc\001d\177e')")"
check "toggle strips control characters from the name" "abcde" "$(jq -r '.favorites[0].name' <<<"$out")"
reset
out="$(fd fav-toggle --surah 1 --ayah 1 --name "$(printf 'y%.0s' {1..200})")"
check "toggle cuts a 200-char name to 60" "60" "$(jq -r '.favorites[0].name|length' <<<"$out")"

# bad input
reset
fails "surah 0 is refused"        fd fav-toggle --surah 0 --ayah 1
fails "surah abc is refused"      fd fav-toggle --surah abc --ayah 1
fails "negative surah is refused" fd fav-toggle --surah -1 --ayah 1
fails "missing surah is refused"  fd fav-toggle --ayah 1
fails "ayah 0 is refused"         fd fav-toggle --surah 1 --ayah 0
fails "ayah 1.5 is refused"       fd fav-toggle --surah 1 --ayah 1.5
fails "missing ayah is refused"   fd fav-toggle --surah 1
fails "unknown flag is refused"   fd fav-toggle --surah 1 --ayah 1 --bogus x
fails "lists takes no flags"      fd lists --x
check "invalid surah message" "deen-fetch: invalid surah: abc" "$(fd fav-toggle --surah abc --ayah 1 2>&1)"
check "invalid ayah message"  "deen-fetch: invalid ayah: 0"    "$(fd fav-toggle --surah 1 --ayah 0 2>&1)"
check "unknown flag message"  "deen-fetch: unknown flag --bogus" "$(fd fav-toggle --bogus 2>&1)"
check "refused input writes nothing" "no" "$([[ -e $FAV ]] && echo yes || echo no)"

# an unreadable favorites file is treated as empty and then replaced
echo 'corrupt' > "$FAV"
check "toggle over a corrupt file starts fresh" "1:1" "$(fd fav-toggle --surah 1 --ayah 1 | refs .favorites)"

# favorites cap: 500 pre-seeded, one more pushes the oldest out
jq -n '[range(1; 501) | {surah: 1, ayah: ., name: "", at: 1}]' > "$FAV"
out="$(fd fav-toggle --surah 2 --ayah 1)"
check "adding to a full list keeps 500" "500" "$(jq '.favorites|length' <<<"$out")"
check "the newest is first after the cap" "2:1" "$(jq -r '.favorites[0]|"\(.surah):\(.ayah)"' <<<"$out")"
check "the oldest fell off" "false" "$(jq 'any(.favorites[]; .surah==1 and .ayah==500)' <<<"$out")"
# and by plain repeated toggling
reset
for i in $(seq 1 501); do fd fav-toggle --surah 1 --ayah "$i" >/dev/null; done
out="$(fd lists)"
check "501 toggles leave 500" "500" "$(jq '.favorites|length' <<<"$out")"
check "the first one toggled is gone" "false" "$(jq 'any(.favorites[]; .ayah==1)' <<<"$out")"
check "the last one toggled is first" "501" "$(jq '.favorites[0].ayah' <<<"$out")"

# ---- history, written by a real pick
reset
ARGS=(--no-sync --no-hadith --quran test-edition --mode deterministic --interval-hours 6)
pick() { fd pick "$@" "${ARGS[@]}" 2>/dev/null | jq -r '"\(.ayah.surah):\(.ayah.ayah)"'; }

shown="$(pick)"
check "a pick records one history entry" "$shown" "$(fd lists | refs .history)"
check "the history name is the surah's English name" "The Cow" "$(fd lists | jq -r '.history[0].name')"
check "history entries hold only references" '["at","ayah","name","surah"]' "$(jq -c '.[0]|keys' "$HIST")"
check "pick does not touch favorites" "[]" "$(fd lists | jq -c .favorites)"
before="$(cat "$HIST")"
pick >/dev/null
check "an unchanged slot does not add history" "$before" "$(cat "$HIST")"
second="$(pick --force)"
check "a forced pick prepends to history" "$second" "$(fd lists | jq -r '.history[0]|"\(.surah):\(.ayah)"')"

# show never writes history
before="$(cat "$HIST")"
fd show --quran test-edition --surah 2 --ayah 10 >/dev/null
fd show --quran test-edition --surah 2 --ayah 10 --step 1 >/dev/null
check "show leaves history unchanged" "$before" "$(cat "$HIST")"

# history cap and dedupe, against a pre-seeded file
jq -n '[range(1; 51) | {surah: 1, ayah: ., name: "", at: 1}]' > "$HIST"
rm -f "$STATE/current.json" "$STATE/seen.json"
shown="$(pick --force)"
check "a pick on a full history keeps 50" "50" "$(fd lists | jq '.history|length')"
check "the new pick is first" "$shown" "$(fd lists | jq -r '.history[0]|"\(.surah):\(.ayah)"')"
check "the oldest entry fell off" "false" "$(fd lists | jq 'any(.history[]; .ayah==50 and .surah==1)' )"

# dedupe: seed history with the very ayah the next deterministic pick lands on
reset
rm -f "$STATE/current.json" "$STATE/seen.json"
target="$(pick)"; rm -f "$STATE/current.json" "$STATE/seen.json"
t_ayah="${target#*:}"
jq -n --argjson a "$t_ayah" '[{surah:1,ayah:1,name:"",at:1}, {surah:2,ayah:$a,name:"old",at:1}, {surah:1,ayah:2,name:"",at:1}]' > "$HIST"
pick >/dev/null
out="$(fd lists)"
check "a repeated ayah is moved to the front, not duplicated" "$target,1:1,1:2" "$(refs .history <<<"$out")"
check "and takes the fresh name" "The Cow" "$(jq -r '.history[0].name' <<<"$out")"

# best effort: an unwritable history must not fail the pick
reset
mkdir -p "$HIST"   # a directory where the file should be
check "pick succeeds when history cannot be written" "ok" "$(fd pick --force "${ARGS[@]}" >/dev/null 2>&1 && echo ok || echo failed)"
rm -rf "$HIST"

if (( fail )); then
  printf '\nstore: %s failed\n' "$fail"; exit 1
fi
printf '\nstore: all checks passed\n'
