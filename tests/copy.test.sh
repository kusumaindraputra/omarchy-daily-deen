#!/usr/bin/env bash
#
# Copy-to-clipboard bookkeeping in Service.qml. Process does not exist in plain
# qml6, so copyProc is a stub; copyPassage and copyFinished are the real ones,
# extracted from Service.qml. Model.formatCopy is a small stand-in so this does
# not depend on Model.js while it changes.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
command -v qml6 >/dev/null || { echo "skip  qml6 not installed"; exit 0; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
SRC="${COPY_TEST_SERVICE:-Service.qml}"

grab() {
  awk -v re="^  function $1\\\\(" '$0 ~ re { on = 1 }
    on { print; d += gsub(/{/, "{") - gsub(/}/, "}"); if (d == 0) exit }' "$SRC"
}
CP="$(grab copyPassage)"; CF="$(grab copyFinished)"
[[ -n "$CP" && -n "$CF" ]] || { echo "FAIL  copyPassage/copyFinished not found in $SRC"; exit 1; }

cat > "$TMP/Model.js" <<'JS'
.pragma library
function formatCopy(state, which) { return state && state.text ? which + ":" + state.text : "" }
JS

cat > "$TMP/h.qml" <<QML
import QtQuick
import "Model.js" as Model
Item {
  id: root
  property var current: ({ text: "" })
  property bool copied: false
  property bool copyFailed: false
  property bool copyPending: false
  property string copyText: ""
  QtObject { id: copyProc; property bool running: false; property var command: []; property bool stdinEnabled: false }
  Timer { id: copiedTimer; interval: 2000 }
  Timer { id: copyWatchdog; interval: 5000 }
$CP
$CF

  function snap() { return (copied ? "C" : "-") + (copyFailed ? "F" : "-") + (copyPending ? "P" : "-") }
  Component.onCompleted: {
    var o = []
    copyPassage("all"); o.push("empty:" + snap() + ":" + copyProc.running)
    current = { text: "x" }
    copyPassage(); o.push("start:" + snap() + ":" + copyProc.running + ":" + copyProc.command.join(",") + ":" + copyText)
    o.push("stdin1:" + copyProc.stdinEnabled + ":" + copyWatchdog.running)
    copyProc.stdinEnabled = false   // what Process.onStarted does to send EOF
    copyText = "keep"; copyPassage("ayah"); o.push("reentrant:" + copyText)
    copyFinished(0); o.push("ok:" + snap() + ":" + copiedTimer.running + ":[" + copyText + "]:" + copyWatchdog.running)
    copyFinished(1); o.push("idem:" + snap())
    copyProc.running = false
    copyPassage("hadith"); o.push("again:" + snap() + ":" + copyText + ":stdin2=" + copyProc.stdinEnabled)
    copyFinished(1); o.push("fail:" + snap())
    copyProc.running = false
    copyPassage("all"); o.push("reset:" + snap())
    console.log("RESULT " + o.join(" "))
    Qt.quit()
  }
}
QML

out="$(cd "$TMP" && QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen timeout 20 qml6 h.qml 2>&1)"
got="$(sed -n 's/.*RESULT //p' <<<"$out")"
# stdin1/stdin2: stdin must be re-enabled on EVERY run. Process.onStarted turns it
# off to close the pipe, and turning off what is already off closes nothing, so the
# second copy used to leave wl-copy waiting for EOF forever. The watchdog runs while
# a copy is pending and stops once it has finished.
want="empty:---:false start:--P:true:wl-copy:all:x stdin1:true:true reentrant:keep ok:C--:true:[]:false idem:C-- again:--P:hadith:x:stdin2=true fail:-F- reset:--P"
if [[ "$got" == "$want" ]]; then
  echo "ok    copy: empty is a no-op, running is not re-entered, copied/copyFailed transition and reset"
  echo; echo "copy: all checks passed"
else
  echo "FAIL  got '$got'"; echo "      want '$want'"; echo "$out" | head -6; exit 1
fi
