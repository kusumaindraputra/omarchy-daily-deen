#!/usr/bin/env bash
#
# Favourites/history bookkeeping in Service.qml. Process does not exist in plain
# qml6, so listsProc/stepProc are stubs; refreshLists, toggleFavorite, runLists,
# listsPart, listsFinished, jumpTo, stepAyah and runShow are the real ones,
# extracted from Service.qml. Model is a minimal stand-in for the contract.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
command -v qml6 >/dev/null || { echo "skip  qml6 not installed"; exit 0; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
SRC="${LISTS_TEST_SERVICE:-Service.qml}"

grab() {
  awk -v re="^  function $1\\\\(" '$0 ~ re { on = 1 }
    on { print; d += gsub(/{/, "{") - gsub(/}/, "}"); if (d == 0) exit }' "$SRC"
}
FNS=""
for f in refreshLists toggleFavorite runLists listsPart listsFinished jumpTo stepAyah runShow; do
  body="$(grab $f)"
  [[ -n "$body" ]] || { echo "FAIL  $f not found in $SRC"; exit 1; }
  FNS+="$body"$'\n'
done

cat > "$TMP/Model.js" <<'JS'
.pragma library
function listsArgs(helper) { return [helper, "lists"] }
function favoriteArgs(helper, a) { return a ? [helper, "fav-toggle", "--surah", String(a.surah), "--ayah", String(a.ayah), "--name", "N"] : null }
function jumpArgs(helper, s, surah, ayah) { return surah > 0 && ayah > 0 ? [helper, "show", "--surah", String(surah), "--ayah", String(ayah)] : null }
function stepArgs(helper, s, a, d) { return [helper, "show", "--step", String(d)] }
function parseLists(raw) {
  var o; try { o = JSON.parse(raw) } catch (e) { return { favorites: [], history: [] } }
  return { favorites: Array.isArray(o.favorites) ? o.favorites : [], history: Array.isArray(o.history) ? o.history : [] }
}
JS

WD="$(awk '/^  Timer \{/ { buf = $0; grab = 1; next }
  grab { buf = buf "\n" $0; if ($0 ~ /id: listsWatchdog/) hit = 1
         if ($0 ~ /^  }$/) { if (hit) { print buf; exit } grab = 0; buf = "" } }' "$SRC" | sed 's/interval: 8000/interval: 50/')"
[[ -n "$WD" ]] || { echo "FAIL  listsWatchdog not found in $SRC"; exit 1; }

cat > "$TMP/h.qml" <<QML
import QtQuick
import "Model.js" as Model
Item {
  id: root
  property bool ready: true
  property string helperPath: "/h"
  property var settings: ({})
  property var shownState: ({ ayah: { surah: 2, ayah: 255 } })
  property bool navBusy: false
  property var viewedAyah: null
  property string navError: ""
  property string stepOut: ""
  property string stepErr: ""
  property int stepWaiting: 0
  property int stepCode: 0
  property var current: ({ ayah: { surah: 2, ayah: 255 } })
  property var favorites: []
  property var history: []
  property bool listsBusy: false
  property string listsError: ""
  property string listsOut: ""
  property string listsErr: ""
  property int listsWaiting: 0
  property int listsCode: 0
  property var o: []
  QtObject { id: stepProc; property bool running: false; property var command: [] }
  QtObject { id: listsProc; property bool running: false; property var command: [] }
  Timer { id: stepWatchdog; interval: 8000 }
$WD
$FNS
  function cmd() { return listsProc.command.slice(1).join(",") }
  function snap() { return (listsBusy ? "B" : "-") + ":" + favorites.length + "/" + history.length + ":" + listsError }
  function finish(code, out, err) { listsCode = code; listsOut = out; listsErr = err; listsPart(); listsPart(); listsPart() }
  function reset() { listsProc.running = false; listsProc.command = []; listsBusy = false; listsWatchdog.stop() }
  Timer {
    id: check
    interval: 200
    onTriggered: {
      o.push("watchdog:" + snap() + ":run=" + listsProc.running)
      console.log("RESULT " + o.join(" "))
      Qt.quit()
    }
  }
  Component.onCompleted: {
    ready = false; refreshLists(); o.push("notReady:" + listsProc.running); ready = true
    toggleFavorite(); o.push("favStart:" + listsProc.running + ":" + cmd()); finish(0, '{"favorites":[],"history":[]}', ""); reset()
    shownState = { ayah: null }; toggleFavorite(); o.push("nullArgs:" + listsProc.running + ":" + listsBusy)
    shownState = { ayah: { surah: 2, ayah: 255 } }
    refreshLists(); o.push("start:" + listsProc.running + ":" + listsBusy + ":" + cmd() + ":wd=" + listsWatchdog.running)
    listsProc.command = ["keep"]; refreshLists(); toggleFavorite(); o.push("reentrant:" + listsProc.command.join(","))
    listsWaiting = 3; listsPart(); o.push("partial:" + snap())
    listsCode = 0; listsOut = '{"favorites":[{"surah":1,"ayah":1}],"history":[{"surah":2,"ayah":2},{"surah":3,"ayah":3}]}'; listsErr = ""
    listsPart(); listsPart(); o.push("ok:" + snap() + ":wd=" + listsWatchdog.running)
    refreshLists(); finish(1, "", "deen-fetch: boom\n"); o.push("fail:" + snap())
    refreshLists(); finish(0, "{not json", ""); o.push("junk:" + snap())
    refreshLists(); finish(0, '{"favorites":[],"history":[]}', ""); o.push("recover:" + snap())
    // a jump takes the same busy flag as a step, and runs show without --step
    jumpTo(0, 1); o.push("badJump:" + stepProc.running + ":" + navBusy)
    jumpTo(3, 4); o.push("jump:" + stepProc.running + ":" + navBusy + ":" + stepProc.command.slice(1).join(","))
    stepProc.command = ["keep"]; stepAyah(1); jumpTo(5, 6); o.push("jumpBusy:" + stepProc.command.join(","))
    navBusy = false; stepProc.running = false; stepWatchdog.stop()
    stepAyah(1); stepProc.command = ["keep"]; jumpTo(5, 6); o.push("stepBusy:" + stepProc.command.join(","))
    navBusy = false; stepProc.running = false; stepWatchdog.stop()
    // the watchdog frees a stuck lists run (stdout/stderr never drained)
    listsProc.running = false; refreshLists(); listsWatchdog.restart()
    check.start()
  }
}
QML

out="$(cd "$TMP" && QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen timeout 20 qml6 h.qml 2>&1)"
got="$(sed -n 's/.*RESULT //p' <<<"$out")"
want="notReady:false favStart:true:/h,fav-toggle,--surah,2,--ayah,255,--name,N nullArgs:false:false start:true:true:/h,lists:wd=true reentrant:keep partial:B:0/0: ok:-:1/2::wd=false fail:-:1/2:deen-fetch: boom junk:-:1/2:bad data recover:-:0/0: badJump:false:false jump:true:true:/h,show,--surah,3,--ayah,4 jumpBusy:keep stepBusy:keep watchdog:-:0/0:timed out:run=false"
if [[ "$got" == "$want" ]]; then
  echo "ok    lists: guards, success/failure/junk, reentrancy, watchdog, favourite on the shown ayah, jump shares navBusy"
  echo; echo "lists: all checks passed"
else
  echo "FAIL  got '$got'"; echo "      want '$want'"; echo "$out" | head -6; exit 1
fi
