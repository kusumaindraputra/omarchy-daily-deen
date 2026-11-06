#!/usr/bin/env bash
#
# The bar widget must find its service without relying on a dependency that
# does not exist.
#
# BarWidget used to bind `service` to bar.shell.serviceFor() and read
# bar.shell._services to make that re-evaluate. A plugin's bar.shell is a
# scoped PluginShellApi with no _services, so the dependency was never formed.
# resolveService() is asked again on a timer instead; this runs the real one
# against a shell that has no service yet, then has one, and against shells
# that are missing pieces.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
command -v qml6 >/dev/null || { echo "skip  qml6 not installed"; exit 0; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

FN="$(awk '/^  function resolveService/ { on = 1 }
  on { print; d += gsub(/{/, "{") - gsub(/}/, "}"); if (d == 0) exit }' BarWidget.qml)"
[[ -n "$FN" ]] || { echo "FAIL  resolveService not found in BarWidget.qml"; exit 1; }

cat > "$TMP/h.qml" <<QML
import QtQuick
Item {
  id: root
  property var bar: null
  property var service: null
  readonly property string moduleName: "p.id"
$FN

  property var registry: ({})
  Component.onCompleted: {
    var out = []
    resolveService(); out.push("nobar:" + (service === null))
    bar = { shell: {} }; resolveService(); out.push("nolookup:" + (service === null))
    bar = { shell: { serviceFor: function(id) { return registry[id] || null } } }
    resolveService(); out.push("notyet:" + (service === null))
    var svc = { tag: "svc" }
    registry = { "p.id": svc }
    resolveService(); out.push("found:" + (service === svc))
    registry = {}
    resolveService(); out.push("kept:" + (service === svc))
    console.log("RESULT " + out.join(" "))
    Qt.quit()
  }
}
QML

out="$(QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen timeout 20 qml6 "$TMP/h.qml" 2>&1)"
got="$(sed -n 's/.*RESULT //p' <<<"$out")"
want="nobar:true nolookup:true notyet:true found:true kept:true"
if [[ "$got" == "$want" ]]; then
  echo "ok    resolveService waits for the service, finds it, and never drops it"
  echo; echo "widget: all checks passed"
else
  echo "FAIL  got '$got'"; echo "      want '$want'"; echo "$out" | head -6; exit 1
fi
