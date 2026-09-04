#!/usr/bin/env bash
#
# What --force actually has to do.
#
# A deterministic pick is a pure function of the settings and the clock slot, so
# that two machines configured alike show the same passage. --force was written
# to skip the due check only, which meant that inside one slot it re-derived the
# very same seed: the refresh button ran, rewrote current.json with a new
# chosenAt, and showed the same ayah it already had. From the panel that is
# indistinguishable from a dead button.
#
# Hermetic: XDG_CACHE_HOME and XDG_STATE_HOME are redirected at a temp tree and
# the editions are made up here, so this never touches the real cache or the
# network.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export XDG_CACHE_HOME="$TMP/cache" XDG_STATE_HOME="$TMP/state"
DATA="$XDG_CACHE_HOME/omarchy-daily-deen"
mkdir -p "$DATA/quran"

jq -n '{
  version: 1, fetchedAt: 0, generatedBy: "test",
  quran: [{ slug: "test-edition", language: "English", author: "Test",
            direction: "ltr", latin: false, comments: "", source: "" }],
  hadith: [], books: {}, surahs: []
}' > "$DATA/catalog.json"

# 200 verses is well past SEEN_MAX, so the recent-picks list can never corner
# the forced path into having nothing left to choose.
jq -n '{ quran: [range(1; 201) | { chapter: 2, verse: ., text: "verse \(.)" }] }' \
  > "$DATA/quran/test-edition.json"

ARGS=(--no-sync --no-hadith --quran test-edition --mode deterministic --interval-hours 6)
pick() { ./bin/deen-fetch pick "$@" "${ARGS[@]}" 2>/dev/null | jq -r '.ayah.ayah'; }

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

# An unforced pick inside one slot must not move; that is the whole promise of
# deterministic mode.
first="$(pick)"
check "an unforced pick is stable within its slot" "$first" "$(pick)"
check "and stays stable on a third call"           "$first" "$(pick)"

# A forced pick must move, every time. Five presses of the refresh button that
# all land on the same verse is the bug this file exists for.
declare -A seen=()
for _ in 1 2 3 4 5; do seen["$(pick --force)"]=1; done
distinct="${#seen[@]}"
if (( distinct >= 4 )); then
  printf 'ok    five forced picks give %s distinct verses\n' "$distinct"
else
  printf 'FAIL  five forced picks gave only %s distinct verses\n' "$distinct"
  fail=$(( fail + 1 ))
fi

# The recent-picks list must not be the only thing making a force move. It
# rerolls whenever the seed lands on something already seen, which is enough to
# hide a seed that never varies — so clear the list between presses and let the
# seed answer on its own.
declare -A unseeded=()
for _ in 1 2 3 4 5; do
  rm -f "$XDG_STATE_HOME/omarchy-daily-deen/seen.json"
  unseeded["$(pick --force)"]=1
done
distinct="${#unseeded[@]}"
if (( distinct >= 4 )); then
  printf 'ok    a forced pick varies on its seed alone (%s distinct)\n' "$distinct"
else
  printf 'FAIL  with no recent-picks list to reroll against, five forced picks gave %s distinct verses\n' "$distinct"
  fail=$(( fail + 1 ))
fi

# A force is not a mode switch: what it chose has to stick until the interval is
# up, or the bar would drift every time the shell asked for the current pick.
settled="$(pick --force)"
check "an unforced pick after a forced one keeps it" "$settled" "$(pick)"

if (( fail )); then
  printf '\npick: %s failed\n' "$fail"; exit 1
fi
printf '\npick: all checks passed\n'
