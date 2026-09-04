#!/usr/bin/env bash
#
# The grade classifier against the real corpus.
#
# tests/fixtures/grades.tsv holds every distinct grade string found across the
# cached editions of all ten books, with the class it must map to. The expected
# column was reviewed by hand once — regenerating it from the classifier would
# turn this into a tautology.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

FIXTURE="tests/fixtures/grades.tsv"
PROGRAM="$(mktemp)"; trap 'rm -f "$PROGRAM"' EXIT
{ cat bin/grades.jq; echo 'grade_class_of'; } > "$PROGRAM"

fail=0 total=0
# Read the columns by hand: `read` with a tab IFS strips a leading tab, which
# would silently shift the empty-grade row's columns by one.
while IFS= read -r line; do
  [[ -n $line ]] || continue
  grade="${line%%$'\t'*}"
  expected="${line#*$'\t'}"
  total=$(( total + 1 ))
  actual="$(printf '%s\n' "$grade" | jq -R -r -f "$PROGRAM")"
  if [[ $actual != "$expected" ]]; then
    printf 'FAIL  %-45s expected %-8s got %s\n' "${grade:-(empty)}" "$expected" "$actual"
    fail=$(( fail + 1 ))
  fi
done < "$FIXTURE"

# The rules that carry an actual judgement, spelled out so a future edit that
# breaks one of them fails loudly rather than quietly reshuffling a filter.
assert() {
  total=$(( total + 1 ))
  local input="$1" expected="$2" actual
  actual="$(printf '%s\n' "$input" | jq -R -r -f "$PROGRAM")"
  [[ $actual == "$expected" ]] && return 0
  printf 'FAIL  %-45s expected %-8s got %s\n' "$input" "$expected" "$actual"
  fail=$(( fail + 1 ))
}

# Tirmidhi's "Hasan Sahih" is the conservative reading: hasan, not sahih.
assert "Hasan Sahih"                              hasan
# A cross-reference is not a verdict on this chain, but it does mean sahih.
assert "Sahih Bukhari (1224) Sahih Muslim (570)"  sahih
# Parenthesised asides are dropped before any keyword is looked for. Only a
# paren whose keyword outranks the verdict outside it can demonstrate that,
# since first-match-wins puts daif above sahih, so this is a shape built to
# prove the rule rather than a string lifted from the corpus.
assert "Sahih (Da'if al-Jami 1234)"               sahih
# Defects, not forgeries.
assert "Munkar"                                   daif
assert "Shadh"                                    daif
# Chain descriptors with no verdict attached decide nothing.
assert "Mursal"                                   unknown
assert "Mauquf"                                   unknown
# Diacritics and apostrophe styles must not change the answer.
assert "Ḍaʿīf"                                    daif
assert "Da'if"                                    daif
assert "DAIF"                                     daif

if (( fail )); then
  echo "grades: $fail of $total failed"; exit 1
fi
echo "grades: $total cases passed"
