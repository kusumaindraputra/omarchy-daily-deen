#!/usr/bin/env bash
#
# The panel must close even when the bar will not take the reveal flag.
#
# Omarchy 4.0.6 hands a plugin a PluginBarApi, whose centerHoverRevealSuppressed
# is read-only. Panel.close() assigned to it first, the assignment threw, and
# controller.hide() never ran: the panel could not be closed while its keyboard
# grab was still held. This runs the real close() and
# setCenterHoverRevealSuppressed() lifted out of Panel.qml against a bar that
# behaves like PluginBarApi (setter, read-only property) and like a bar that
# throws on anything.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

command -v qml6 >/dev/null || { echo "skip  qml6 not installed"; exit 0; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# Pull a whole top-level function out of Panel.qml by brace matching.
extract() {
  awk -v name="$1" '
    $0 ~ "^  function " name "\\(" { on = 1 }
    on { print; n = gsub(/{/, "{"); m = gsub(/}/, "}"); depth += n - m; if (depth == 0) exit }
  ' Panel.qml
}

CLOSE="$(extract close)"; SETTER="$(extract setCenterHoverRevealSuppressed)"
[[ -n "$CLOSE" && -n "$SETTER" ]] || { echo "FAIL  could not find close()/setter in Panel.qml"; exit 1; }

cat > "$TMP/h.qml" <<QML
import QtQuick
Item {
  id: root
  property var bar: null
  property bool hidden: false
  property var controller: ({ hide: function() { root.hidden = true } })
$SETTER
$CLOSE

  QtObject { id: apiBar            // like PluginBarApi
    property bool _s: true
    readonly property bool centerHoverRevealSuppressed: _s
    function setCenterHoverRevealSuppressed(v) { _s = !!v }
  }
  QtObject { id: roBar             // read-only and no setter
    readonly property bool centerHoverRevealSuppressed: true
  }

  Component.onCompleted: {
    var out = []
    bar = apiBar; hidden = false; close()
    out.push("api:" + hidden + ":" + apiBar._s)
    bar = roBar; hidden = false
    try { close() } catch (e) { out.push("threw") }
    out.push("ro:" + hidden)
    bar = null; hidden = false; close()
    out.push("nobar:" + hidden)
    console.log("RESULT " + out.join(" "))
    Qt.quit()
  }
}
QML

out="$(QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen timeout 20 qml6 "$TMP/h.qml" 2>&1)"
got="$(grep -o 'RESULT.*' <<<"$out")"
want="RESULT api:true:false ro:true nobar:true"
if [[ "$got" == "$want" ]]; then
  echo "ok    close() hides the panel and clears the flag through the setter, whatever the bar"
  echo; echo "panelclose: all checks passed"
else
  echo "FAIL  got '$got', want '$want'"; echo "$out" | head -10; exit 1
fi
