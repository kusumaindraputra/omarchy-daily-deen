#!/usr/bin/env bash
#
# The plugin must actually see the settings the user saved.
#
# A third-party plugin is handed a scoped PluginShellApi, which has barConfig
# and idleConfig but no shellConfig. Service.settings and Panel.liveSettings
# both read shell.shellConfig, got undefined, and so saw {} — every setting read
# as its default. A language change never reached deen-fetch, the dropdowns
# showed defaults, and persist() built its entry from {} and so erased every
# key but the one just changed.
#
# This runs the real Service.adoptSettings / Service.settings and the real
# Panel.persist, lifted out of the QML, under qml6.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

command -v qml6 >/dev/null || { echo "skip  qml6 not installed"; exit 0; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cp Model.js "$TMP/"

# A block from a start line up to and including the end of the first function
# whose brace depth returns to zero, or (no function) up to a blank line.
extract() {  # file start-regex
  awk -v re="$2" '
    $0 ~ re { on = 1 }
    on { print; n = gsub(/{/, "{"); m = gsub(/}/, "}"); depth += n - m
         if (depth == 0 && $0 ~ /}[[:space:]]*$/ && seen) exit; if (n) seen = 1 }
  ' "$1"
}

ADOPT="$(extract Service.qml '^  function adoptSettings')"
PERSIST="$(extract Panel.qml '^  function persist')"
PROPS="$(sed -n '/^  property var pushedSettings/,/^    : Model.entrySettings/p' Service.qml)"
[[ -n "$ADOPT" && -n "$PERSIST" && -n "$PROPS" ]] || { echo "FAIL  could not find the code under test"; exit 1; }

cat > "$TMP/service.qml" <<QML
import QtQuick
import "Model.js" as Model
Item {
  id: root
  readonly property string pluginId: "p.id"
  property var shell: null
$PROPS
$ADOPT
  property int changes: 0
  onSettingsChanged: changes++

  Component.onCompleted: {
    var out = []
    // a shell with barConfig and no shellConfig, like PluginShellApi
    shell = { barConfig: { layout: { right: [ { id: "p.id", a: 1 } ] } } }
    out.push("snap:" + settings.a)
    adoptSettings({ id: "p.id", a: 2, b: "x" })
    out.push("pushed:" + settings.a + settings.b + ":" + ("id" in settings))
    var n = changes
    adoptSettings({ id: "p.id", a: 2, b: "x" })
    out.push("same:" + (changes === n))
    adoptSettings({ id: "p.id", a: 3, b: "x" })
    out.push("diff:" + settings.a)
    console.log("RESULT " + out.join(" "))
    Qt.quit()
  }
}
QML

cat > "$TMP/panel.qml" <<QML
import QtQuick
Item {
  id: root
  property var written: null
  property var liveSettings: ({ contentLanguage: "Indonesian", quranTranslationEdition: "ind-x" })
  property string moduleName: "p.id"
  property var settings: ({})
  property var hostWidget: ({ settings: ({}) })
  property var bar: ({ shell: { updateEntryInline: function(id, e) { root.written = e } } })
$PERSIST

  Component.onCompleted: {
    var out = []
    persist({ hadithLanguage: "English" })
    out.push("keeps:" + written.contentLanguage + ":" + written.quranTranslationEdition + ":" + written.hadithLanguage + ":" + written.id)
    persist({ contentLanguage: "" })
    out.push("clears:" + ("contentLanguage" in written))
    console.log("RESULT " + out.join(" "))
    Qt.quit()
  }
}
QML

run() { QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen timeout 20 qml6 "$TMP/$1.qml" 2>&1; }
out1="$(run service)"; out2="$(run panel)"
got="$(cat <<<"$out1"$'\n'"$out2" | sed -n 's/.*RESULT //p' | paste -sd' ')"
want="snap:1 pushed:2x:false same:true diff:3 keeps:Indonesian:ind-x:English:p.id clears:false"
if [[ "$got" == "$want" ]]; then
  echo "ok    service sees pushed settings; persist keeps the keys it was not asked to change"
  echo; echo "settings: all checks passed"
else
  echo "FAIL  got  '$got'"; echo "      want '$want'"; echo "$out1" | head -6; echo "$out2" | head -6; exit 1
fi
