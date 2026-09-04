import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "I18n.js" as I18n

// The bar entry: a mosque glyph, optionally a short reference beside it, and
// the host for the panel that carries the actual text.
//
// One of these exists per monitor. It holds no state of its own — the rotation
// clock, the fetches and the notification all live in the service, which is a
// single instance for the whole shell. Three monitors must not mean three
// notifications.
BarWidget {
  id: root
  moduleName: "io.github.kusumaindraputra.daily-deen"

  readonly property string glyph: "\u{F405}"

  // serviceFor is a plain function, so a binding on bar.shell alone would not
  // re-evaluate when the service finishes loading — services are created
  // asynchronously and a widget can be built first. Reading _services is what
  // creates the dependency.
  readonly property var service: {
    if (!bar || !bar.shell) return null
    var _revision = bar.shell._services
    return bar.shell.serviceFor(root.moduleName)
  }

  readonly property string locale: service ? service.locale : "en"

  // A vertical bar is one glyph wide, so the reference is dropped there rather
  // than rotated or truncated into nothing.
  readonly property string label: (vertical || !service) ? "" : service.barText
  readonly property bool glyphOnly: label === ""

  function refresh() { if (service) service.rotate(true) }
  function renotify() { if (service) service.notify() }

  function press(b) {
    if (b === Qt.MiddleButton) root.refresh()
    else if (b === Qt.RightButton) root.renotify()
    else root.togglePanel()
  }

  // ---- Shape contract for shell.summon/hide/toggle routing: Bar.findPanelWidget
  //      requires open/close/opened on the bar-widget root, and Bar.requestPopout
  //      prefers closeForPopoutSwitch over close.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("service" in target) target.service = root.service
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  onServiceChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      // The bar injects twice on purpose; do the same, since `service` can
      // still be null on the first pass.
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyph
    tooltipText: root.service ? root.service.barTooltip : I18n.t(root.locale, "title")
    onPressed: function(b) { root.press(b) }
  }
}
