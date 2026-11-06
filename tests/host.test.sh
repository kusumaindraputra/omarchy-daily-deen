#!/usr/bin/env bash
#
# The widget names the host API members it needs and warns once if any are
# missing. This runs the real missingHostApi() against complete and broken
# bars, then proves the harness can fail by running a damaged copy.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
command -v qml6 >/dev/null || { echo "skip  qml6 not installed"; exit 0; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

FN="$(awk '/^  function missingHostApi/ { on = 1 }
  on { print; d += gsub(/{/, "{") - gsub(/}/, "}"); if (d == 0) exit }' BarWidget.qml)"
[[ -n "$FN" ]] || { echo "FAIL  missingHostApi not found in BarWidget.qml"; exit 1; }

run() { # $1 = function text
cat > "$TMP/h.qml" <<QML
import QtQuick
Item {
$1
  function full() {
    var f = function() {}
    return { setCenterHoverRevealSuppressed: f, switchPanelFrom: f,
             shell: { serviceFor: f, updateEntryInline: f } }
  }
  Component.onCompleted: {
    var out = []
    out.push("full:" + JSON.stringify(missingHostApi(full())))
    var b = full(); delete b.switchPanelFrom
    out.push("nosw:" + JSON.stringify(missingHostApi(b)))
    b = full(); b.shell = null
    out.push("noshell:" + JSON.stringify(missingHostApi(b)))
    b = full(); b.setCenterHoverRevealSuppressed = true
    out.push("notfn:" + JSON.stringify(missingHostApi(b)))
    try { missingHostApi(null); out.push("null:ok") } catch (e) { out.push("null:threw") }
    console.log("RESULT " + out.join(" "))
    Qt.quit()
  }
}
QML
QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen timeout 20 qml6 "$TMP/h.qml" 2>&1 | sed -n 's/.*RESULT //p'
}

want='full:[] nosw:["switchPanelFrom"] noshell:["shell"] notfn:["setCenterHoverRevealSuppressed"] null:ok'
got="$(run "$FN")"
if [[ "$got" == "$want" ]]; then
  echo "ok    missingHostApi reports exactly the missing members"
else
  echo "FAIL  got '$got'"; echo "      want '$want'"; exit 1
fi

# The harness must be able to fail: break the copy and expect a mismatch.
broken="${FN//\"switchPanelFrom\"/\"switchPanelFromX\"}"
bad="$(run "$broken")"
if [[ "$bad" != "$want" ]]; then
  echo "ok    a damaged copy is detected"
  echo; echo "host: all checks passed"
else
  echo "FAIL  damaged copy still passed; test cannot fail"; exit 1
fi
