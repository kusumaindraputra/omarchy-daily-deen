.pragma library

// The panel's text fields never read the clipboard.
//
// On Qt 6.12 under Wayland a paste reads the offered data synchronously,
// inside the shell process, with no size limit, before the field sees any of
// it. A clipboard owner that never stops sending can therefore stall or
// exhaust the whole shell (raised in the marketplace review of a7b3e42). Every
// field here holds a search filter or a number of hours, so nothing is lost by
// refusing to paste: the routes Qt uses are a paste key and, where the
// compositor offers a primary selection, a middle click.

// True for any key press a Qt text input would treat as paste. `pasteKey` is
// StandardKey.Paste from the caller, because a .pragma library cannot see the
// QtQuick enums; the explicit chords cover a platform whose key map lacks one.
function isPasteKey(event, pasteKey) {
  if (!event) return false
  if (pasteKey !== undefined && typeof event.matches === "function" && event.matches(pasteKey)) return true
  var mods = event.modifiers || 0
  if (event.key === Qt.Key_Paste) return true
  if (event.key === Qt.Key_V && (mods & Qt.ControlModifier)) return true
  if (event.key === Qt.Key_Insert && (mods & Qt.ShiftModifier)) return true
  return false
}

// The mouse buttons a text input reads the clipboard on: middle pastes the
// primary selection, right opens a menu with Paste in it on Qt Quick Controls.
var PASTE_BUTTONS = Qt.MiddleButton | Qt.RightButton
