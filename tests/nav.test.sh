#!/usr/bin/env bash
#
# Ayah navigation bookkeeping in Service.qml. Process does not exist in plain
# qml6, so stepProc is a stub; stepAyah, stepPart, stepFinished and resetView are
# the real ones, extracted from Service.qml. Model is a small stand-in so this
# does not depend on Model.js while it changes.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
command -v qml6 >/dev/null || { echo "skip  qml6 not installed"; exit 0; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
SRC="${NAV_TEST_SERVICE:-Service.qml}"

grab() {
  awk -v re="^  function $1\\\\(" '$0 ~ re { on = 1 }
    on { print; d += gsub(/{/, "{") - gsub(/}/, "}"); if (d == 0) exit }' "$SRC"
}
FNS=""
for f in stepAyah runShow stepPart stepFinished resetView adopt; do
  body="$(grab $f)"
  [[ -n "$body" ]] || { echo "FAIL  $f not found in $SRC"; exit 1; }
  FNS+="$body"$'\n'
done

cat > "$TMP/Model.js" <<'JS'
.pragma library
function stepArgs(helper, settings, ayah, delta) {
  if (delta !== 1 && delta !== -1) return null
  return [helper, "show", "--surah", String(ayah.surah), "--ayah", String(ayah.ayah), "--step", String(delta)]
}
function parseState(raw) { try { return JSON.parse(raw) } catch (e) { return {} } }
function hasContent(s) { return !!(s && s.ayah) }
JS

cat > "$TMP/h.qml" <<QML
import QtQuick
import "Model.js" as Model
Item {
  id: root
  property bool ready: true
  property bool navBusy: false
  property var viewedAyah: null
  property string navError: ""
  property string stepOut: ""
  property string stepErr: ""
  property int stepWaiting: 0
  property int stepCode: 0
  property var current: ({ chosenAt: 1, ayah: { surah: 2, ayah: 255 } })
  property bool primed: true
  property int rotations: 0
  signal rotated()
  onRotated: rotations++
  function notify() {}
  function refreshLists() {}
  property string helperPath: "/h"
  property var settings: ({})
  QtObject { id: stepProc; property bool running: false; property var command: [] }
  Timer { id: stepWatchdog; interval: 8000 }
$FNS
  function v() { return viewedAyah ? viewedAyah.surah + ":" + viewedAyah.ayah : "null" }
  function snap() { return v() + "/" + (navBusy ? "B" : "-") + "/" + navError }
  function ran() { var r = stepProc.running; stepProc.running = false; return r ? "run" : "no" }
  function finish(code, out, err) { stepCode = code; stepOut = out; stepErr = err; stepPart(); stepPart(); stepPart() }
  Component.onCompleted: {
    var o = []
    stepAyah(2); o.push("badDelta:" + ran() + ":" + navBusy)
    ready = false; stepAyah(1); o.push("notReady:" + ran()); ready = true
    current = { ayah: null }; stepAyah(1); o.push("noAyah:" + ran()); current = { ayah: { surah: 2, ayah: 255 } }
    stepAyah(1); o.push("start:" + ran() + ":" + navBusy + ":" + stepProc.command.join(",") + ":wd=" + stepWatchdog.running)
    stepWaiting = 3
    stepProc.running = true; stepAyah(-1); o.push("busy:" + (stepProc.command.length) + ":" + stepProc.command[stepProc.command.length - 1])
    stepWaiting = 2; stepPart(); o.push("partial:" + snap()); stepPart(); stepPart()   // 3 parts total from here
    finish(0, '{"surah":2,"ayah":256,"text":"t"}', ""); o.push("ok:" + snap() + ":wd=" + stepWatchdog.running)
    navError = "old"; stepAyah(1); o.push("fromView:" + stepProc.command[stepProc.command.length - 3])
    finish(1, "", "deen-fetch: no next ayah\n"); o.push("fail:" + snap())
    stepAyah(1); finish(0, "{not json", ""); o.push("junk:" + snap())
    stepAyah(1); finish(0, '{"surah":2,"ayah":257,"text":"t"}', ""); o.push("again:" + snap())
    resetView(); o.push("reset:" + snap())
    // adopt: a new pick (new chosenAt) drops the viewed ayah; the same pick keeps it
    current = { chosenAt: 1, ayah: { surah: 2, ayah: 255 } }; primed = true; rotations = 0
    viewedAyah = { surah: 3, ayah: 1 }
    adopt('{"chosenAt":1,"ayah":{"surah":2,"ayah":255}}'); o.push("adoptSame:" + v())
    adopt('{"chosenAt":2,"ayah":{"surah":9,"ayah":9}}');   o.push("adoptNew:" + v() + ":" + rotations)
    console.log("RESULT " + o.join(" "))
    Qt.quit()
  }
}
QML

out="$(cd "$TMP" && QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen timeout 20 qml6 h.qml 2>&1)"
got="$(sed -n 's/.*RESULT //p' <<<"$out")"
want="badDelta:no:false notReady:no noAyah:no start:run:true:/bin/bash,/h,show,--surah,2,--ayah,255,--step,1:wd=true busy:9:1 partial:null/B/ ok:2:256/-/:wd=false fromView:256 fail:2:256/-/deen-fetch: no next ayah junk:2:256/-/bad data again:2:257/-/ reset:null/-/ adoptSame:3:1 adoptNew:null:1"
if [[ "$got" == "$want" ]]; then
  echo "ok    nav: guards, success/failure/junk results, reentrancy and reset"
  echo; echo "nav: all checks passed"
else
  echo "FAIL  got '$got'"; echo "      want '$want'"; echo "$out" | head -6; exit 1
fi
