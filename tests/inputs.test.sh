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

# --- the cap stops bytes as they arrive, not after they have landed ---------
# The blocker in the second security review: --max-filesize only refuses a
# response that declares a length, and measuring the file after curl finishes is
# too late, because by then the whole thing is already on disk. So point the real
# downloader at a server that streams a chunked body forever and check that it
# stops on its own.
PORT_F="$TMP/port"; COUNT_F="$TMP/sent"
python3 tests/streamserver.py "$PORT_F" "$COUNT_F" &
SRV=$!
for _ in $(seq 1 100); do [[ -s $PORT_F ]] && break; sleep 0.1; done

if [[ -s $PORT_F ]]; then
  CAP=100000
  started=$SECONDS
  ( eval "$(sed -n '/^bounded_get()/,/^}/p' bin/deen-fetch)"
    note() { :; }
    bounded_get "http://127.0.0.1:$(cat "$PORT_F")/edition.json" \
                "$TMP/stream-out" "$CAP" "$TMP/stream-etag"
    exit $? )
  rc=$?
  elapsed=$(( SECONDS - started ))

  wait "$SRV" 2>/dev/null
  sent="$(cat "$COUNT_F" 2>/dev/null || echo 0)"
  landed="$(wc -c < "$TMP/stream-out" 2>/dev/null || echo 0)"

  (( rc == 2 )) \
    && ok "an endless chunked response is refused (exit 2)" \
    || bad "an endless chunked response returned $rc, expected 2"
  (( landed == 0 )) \
    && ok "nothing of it was left on disk" \
    || bad "$landed bytes of the refused response were left on disk"
  # Whichever ceiling fired, the refusal must not depend on which one it was.
  (( sent <= 5000000 )) \
    && ok "the transfer was cut at the cap, not after the body finished" \
    || bad "the transfer ran on to $sent bytes"
  (( elapsed < 30 )) \
    && ok "it gave up in ${elapsed}s rather than reading forever" \
    || bad "it took ${elapsed}s to give up"
  # The socket buffers hold some slack past the cap, but it has to be slack, not
  # the 512 MB the server was willing to send.
  if (( sent > 0 && sent < 5000000 )); then
    ok "the server got cut off after $sent bytes, well short of what it offered"
  else
    bad "the server sent $sent bytes before being cut off"
  fi
  # The etag must not survive a refused body, or the next run is told nothing
  # changed and never retries.
  [[ -e $TMP/stream-etag ]] \
    && bad "an etag was kept for a response that was thrown away" \
    || ok "no etag was kept for the refused response"
else
  kill "$SRV" 2>/dev/null
  bad "the streaming test server never came up"
fi

# A body inside the cap still has to arrive intact.
PORT2="$TMP/port2"; COUNT2="$TMP/sent2"
python3 - "$PORT2" <<'SRV' &
import socket, sys
srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(("127.0.0.1", 0)); srv.listen(1)
open(sys.argv[1], "w").write(str(srv.getsockname()[1]))
conn, _ = srv.accept()
while b"\r\n\r\n" not in conn.recv(65536):
    pass
body = b'{"ok":true}'
conn.sendall(b"HTTP/1.1 200 OK\r\nContent-Length: %d\r\n\r\n" % len(body) + body)
conn.close(); srv.close()
SRV
SRV2=$!
for _ in $(seq 1 100); do [[ -s $PORT2 ]] && break; sleep 0.1; done
( eval "$(sed -n '/^bounded_get()/,/^}/p' bin/deen-fetch)"
  note() { :; }
  bounded_get "http://127.0.0.1:$(cat "$PORT2")/small.json" \
              "$TMP/small-out" 100000 "$TMP/small-etag"
  exit $? )
rc2=$?
wait "$SRV2" 2>/dev/null
if (( rc2 == 0 )) && [[ "$(cat "$TMP/small-out" 2>/dev/null)" == '{"ok":true}' ]]; then
  ok "a body inside the cap arrives intact"
else
  bad "an in-cap body was mangled or rejected (exit $rc2)"
fi

# Every curl call has to declare the cap, not just one of them.
calls="$(grep -c 'curl -fsS' bin/deen-fetch)"
caps="$(grep -c -- '--max-filesize "$max"' bin/deen-fetch)"
if (( caps == calls )); then
  ok "all $calls curl calls declare --max-filesize"
else
  bad "$calls curl calls but $caps declare --max-filesize"
fi
# ...and the cap has to be applied to the stream, not to the finished file.
if grep -q 'head -c \$(( max + 1 ))' bin/deen-fetch; then
  ok "the body is truncated as it arrives"
else
  bad "nothing bounds the body while it is arriving"
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
