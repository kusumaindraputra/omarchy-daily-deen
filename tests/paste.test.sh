#!/usr/bin/env bash
#
# The panel's text fields never read the clipboard.
#
# A paste on Qt 6.12/Wayland reads the clipboard synchronously and without a
# limit inside the shell, so a clipboard owner that never stops sending can
# stall it (marketplace review of a7b3e42). Panel.qml therefore swaps qs.Ui's
# SearchableDropdown and NumberField for copies whose text input is a
# PasteProofInput. This lifts those three inline components out of Panel.qml,
# loads them against small stand-ins for qs.Commons and qs.Ui, and drives them
# with real key and mouse events under qmltestrunner:
#
#   - a bare TextInput does paste here (so the check below is not vacuous),
#   - Ctrl+V, Ctrl+Shift+V and Shift+Insert do nothing in a PasteProofInput,
#     nor a middle or right click (the Paste key is covered by the predicate
#     alone: QtTest cannot synthesise it), while typing, Backspace, Escape, Down and
#     Enter keep working in the dropdown's filter,
#   - the spin box still takes typed digits and refuses a pasted number,
#   - Panel.qml has no qs.Ui SearchableDropdown or NumberField left.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

RUNNER="$(command -v qmltestrunner6 || command -v qmltestrunner || true)"
[[ -z "$RUNNER" && -x /usr/lib/qt6/bin/qmltestrunner ]] && RUNNER=/usr/lib/qt6/bin/qmltestrunner
[[ -n "$RUNNER" ]] || { echo "skip  qmltestrunner not installed"; exit 0; }

fail=0
# --- no unguarded field is left in the panel ---------------------------------
if grep -nE '^\s*(SearchableDropdown|NumberField|TextField|TextInput|TextEdit|TextArea)\s*\{' Panel.qml; then
  echo "FAIL  Panel.qml still declares a text field that can paste (above)"; fail=1
else
  echo "ok    Panel.qml declares no unguarded text field"
fi

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

extract() {
  awk -v name="$1" '
    $0 ~ "^  component " name ":" { on = 1 }
    on { print; n = gsub(/{/, "{"); m = gsub(/}/, "}"); depth += n - m; if (depth == 0) exit }
  ' Panel.qml
}
COMPS=""
for c in PasteProofInput SafeSearchableDropdown SafeNumberField; do
  body="$(extract "$c")"
  [[ -n "$body" ]] || { echo "FAIL  component $c not found in Panel.qml"; exit 1; }
  COMPS+="$body"$'\n'
done

cp PasteGuard.js "$TMP/"
mkdir -p "$TMP/imports/qs/Commons" "$TMP/imports/qs/Ui"
cat > "$TMP/imports/qs/Commons/qmldir" <<'EOF'
module qs.Commons
singleton Style 1.0 Style.qml
singleton Border 1.0 Border.qml
singleton Color 1.0 Color.qml
singleton I18n 1.0 I18n.qml
EOF
cat > "$TMP/imports/qs/Commons/Style.qml" <<'EOF'
pragma Singleton
import QtQuick
QtObject {
  property QtObject font: QtObject { property string family: "sans"; property int body: 14; property int caption: 11; property int bodySmall: 12 }
  property QtObject spacing: QtObject {
    property int controlHeight: 30; property int popupRowHeight: 28; property int searchablePopupMinHeight: 220
    property int searchableDropdownWidth: 240; property int huge: 20; property int labelGap: 4; property int md: 6
    property int controlPaddingX: 10; property int controlPaddingY: 4; property int controlGap: 8; property int xxs: 2
    property int hairline: 1; property int rowPaddingX: 8; property int numberFieldWidth: 120
  }
  property int cornerRadius: 0
  property int normalBorderWidth: 1
  function space(v) { return v }
  function controlFill(f, h, fg, a) { return "transparent" }
  function selectionFillFor(fg, a) { return a }
  function hoverFillFor(fg, a) { return a }
  function hoverStateColor(fg, a) { return fg }
}
EOF
cat > "$TMP/imports/qs/Commons/Border.qml" <<'EOF'
pragma Singleton
import QtQuick
QtObject {
  function controlSpec(s, fg, a) { return { widths: { left: 1, right: 1, top: 1, bottom: 1 } } }
  function localOrSurfaceSpec() { return { widths: { left: 1, right: 1, top: 1, bottom: 1 } } }
  function left(s) { return 1 } function right(s) { return 1 } function top(s) { return 1 } function bottom(s) { return 1 }
}
EOF
cat > "$TMP/imports/qs/Commons/Color.qml" <<'EOF'
pragma Singleton
import QtQuick
QtObject {
  property color foreground: "white"; property color accent: "orange"
  property QtObject popups: QtObject { property color text: "white"; property color background: "black"; property color border: "gray" }
}
EOF
cat > "$TMP/imports/qs/Commons/I18n.qml" <<'EOF'
pragma Singleton
import QtQuick
QtObject { function t(k) { return k } }
EOF
cat > "$TMP/imports/qs/Ui/qmldir" <<'EOF'
module qs.Ui
BorderSurface 1.0 BorderSurface.qml
EOF
cat > "$TMP/imports/qs/Ui/BorderSurface.qml" <<'EOF'
import QtQuick
Rectangle { property var borderSpec: null; property int borderLeft: 1; property int borderRight: 1 }
EOF

cat > "$TMP/tst_paste.qml" <<QML
import QtQuick
import QtQuick.Controls as QQC
import QtTest
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "PasteGuard.js" as PasteGuard

Item {
  id: root
  width: 600; height: 600

$COMPS

  TextInput { id: source; text: "PASTED"; width: 100; height: 20 }
  TextInput { id: bare; y: 30; width: 200; height: 20 }
  PasteProofInput { id: guarded; y: 60; width: 200; height: 20 }
  SafeSearchableDropdown {
    id: dd; y: 100; width: 300
    options: [{ value: "a", label: "Alpha" }, { value: "b", label: "Beta" }, { value: "c", label: "Gamma" }]
    property string picked: ""
    onChanged: function(v) { picked = v }
  }
  SafeNumberField { id: nf; x: 350; y: 100; from: 1; to: 168; value: 6
    property int last: -1
    onModified: function(v) { last = v } }

  // QtTest cannot hand a QML string the TextInput that holds the focus inside
  // a Popup, so the filter field is found by walking the popup's content.
  function findInput(item) {
    if (!item) return null
    if (item.hasOwnProperty("keyPressed") && item.hasOwnProperty("cursorPosition")) return item
    for (var i = 0; i < item.children.length; i++) { var f = findInput(item.children[i]); if (f) return f }
    return null
  }
  function findSpinInput(item) {
    if (!item) return null
    if (item.hasOwnProperty("cursorPosition")) return item
    for (var i = 0; i < item.children.length; i++) { var f = findSpinInput(item.children[i]); if (f) return f }
    return null
  }

  TestCase {
    name: "paste"
    when: windowShown

    function copySource() { source.selectAll(); source.copy(); source.deselect() }

    function test_1_guard_predicate() {
      compare(PasteGuard.isPasteKey({ key: Qt.Key_V, modifiers: Qt.ControlModifier }), true)
      compare(PasteGuard.isPasteKey({ key: Qt.Key_Insert, modifiers: Qt.ShiftModifier }), true)
      compare(PasteGuard.isPasteKey({ key: Qt.Key_Paste, modifiers: 0 }), true)
      compare(PasteGuard.isPasteKey({ key: Qt.Key_V, modifiers: Qt.ControlModifier | Qt.ShiftModifier }), true)
      compare(PasteGuard.isPasteKey({ key: Qt.Key_V, modifiers: 0, text: "v" }), false)
      compare(PasteGuard.isPasteKey({ key: Qt.Key_C, modifiers: Qt.ControlModifier }), false)
      compare(PasteGuard.isPasteKey({ key: Qt.Key_Insert, modifiers: 0 }), false)
      compare(PasteGuard.isPasteKey(null), false)
    }

    function test_2_bare_input_pastes_here() {
      copySource()
      bare.text = ""; bare.forceActiveFocus()
      keyClick(Qt.Key_V, Qt.ControlModifier)
      compare(bare.text, "PASTED", "control: a plain TextInput pastes in this environment")
    }

    function test_3_guarded_input_refuses_paste() {
      copySource()
      guarded.text = ""; guarded.forceActiveFocus()
      keyClick(Qt.Key_V, Qt.ControlModifier)
      keyClick(Qt.Key_Insert, Qt.ShiftModifier)
      keyClick(Qt.Key_V, Qt.ControlModifier | Qt.ShiftModifier)
      mouseClick(guarded, 5, 5, Qt.MiddleButton)
      mouseClick(guarded, 5, 5, Qt.RightButton)
      compare(guarded.text, "", "nothing reached the field")
      verify(guarded.activeFocus, "a swallowed click still leaves the field focused")
      keyClick(Qt.Key_X); keyClick(Qt.Key_Y)
      compare(guarded.text, "xy", "typing still works")
      keyClick(Qt.Key_Backspace)
      compare(guarded.text, "x")
    }

    function test_4_dropdown_filter() {
      copySource()
      dd.open()
      tryVerify(function() { return dd.popupOpen })
      var field = null
      // The popup's content is not a child of dd, so look in the overlay.
      var overlay = root.QQC.Overlay.overlay
      tryVerify(function() { field = root.findInput(overlay); return field !== null && field.activeFocus }, 2000, "filter field focused")
      keyClick(Qt.Key_V, Qt.ControlModifier)
      keyClick(Qt.Key_Insert, Qt.ShiftModifier)
      mouseClick(field, 5, 5, Qt.MiddleButton)
      compare(field.text, "", "no paste into the filter")
      verify(dd.popupOpen, "a refused paste does not close the picker")
      keyClick(Qt.Key_A)
      compare(dd.filtered.length, 3, "typing filters: 'a' is in all three")
      keyClick(Qt.Key_Backspace); keyClick(Qt.Key_M)
      compare(field.text, "m", "Backspace and typing edit the filter")
      compare(dd.filtered.length, 1, "'m' leaves Gamma")
      keyClick(Qt.Key_Down); keyClick(Qt.Key_Return)
      compare(dd.picked, "c", "Down, Enter picks Gamma")
      compare(dd.value, "c")
      tryVerify(function() { return !dd.popupOpen })
      dd.open(); tryVerify(function() { return dd.popupOpen })
      tryVerify(function() { field = root.findInput(overlay); return field !== null && field.activeFocus })
      compare(field.text, "", "the filter clears on reopen")
      keyClick(Qt.Key_Escape)
      tryVerify(function() { return !dd.popupOpen }, 2000, "Esc closes")
    }

    function test_5_number_field() {
      source.text = "99"; copySource(); source.text = "PASTED"
      var input = root.findSpinInput(nf)
      verify(input !== null)
      input.forceActiveFocus()
      input.selectAll()
      keyClick(Qt.Key_V, Qt.ControlModifier)
      mouseClick(input, 5, 5, Qt.MiddleButton)
      compare(input.text, "6", "no paste into the hours field")
      input.selectAll()
      keyClick(Qt.Key_1); keyClick(Qt.Key_2); keyClick(Qt.Key_Return)
      compare(nf.last, 12, "typed digits still set the hours")
      keyClick(Qt.Key_Up)
      compare(nf.last, 13, "Up still steps")
    }
  }
}
QML

out="$(cd "$TMP" && QT_QPA_PLATFORM=offscreen "$RUNNER" -import "$TMP/imports" -input "$TMP/tst_paste.qml" 2>&1)"; code=$?
grep -E "^(PASS|FAIL|Totals|QWARN|QDEBUG)|Error|error" <<<"$out" | grep -v "^QDEBUG" 
if (( code != 0 )); then echo "$out" | tail -30; echo "FAIL  paste-proof inputs"; fail=1
else echo "ok    paste-proof inputs refuse every paste route and keep their keys"; fi
exit "$fail"
