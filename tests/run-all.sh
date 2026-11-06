#!/usr/bin/env bash
#
# The whole suite: node tests, then the shell tests.
#
# `node --test tests/` does not work — node treats the argument as a module,
# not a directory — so the files are globbed. Each shell test is run through
# bash, so none of them needs its executable bit.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

fail=0

if command -v node >/dev/null; then
  node --test tests/*.test.js || fail=1
else
  echo "skip  node is not installed; the .test.js files were not run"
fi

for t in tests/*.test.sh; do
  echo "== $t"
  bash "$t" || { echo "FAIL  $t"; fail=1; }
done

(( fail == 0 )) && echo && echo "all suites passed"
exit "$fail"
