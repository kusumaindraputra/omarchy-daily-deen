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

  // Looked up rather than bound. serviceFor() is a plain function, so nothing
  // re-evaluates it when a service finishes loading, and reading
  // bar.shell._services — which this once did to create that dependency —
  // reads nothing at all: a plugin's bar.shell is a scoped PluginShellApi, and
  // _services lives only on the host's own ShellRoot. A widget built before
  // its service would have kept a null here for good. So ask again until the
  // answer is non-null; the host never hands a service back and then takes it
  // away without rebuilding the widget.
  property var service: null

  function resolveService() {
    if (!bar || !bar.shell || typeof bar.shell.serviceFor !== "function") return
    var found = bar.shell.serviceFor(root.moduleName)
    if (found && found !== root.service) root.service = found
  }

  // Which of the host bar/shell members this plugin calls are absent. Pure:
  // names only, never throws, and a null bar reports the bar itself.
  function missingHostApi(b) {
    if (!b) return ["bar"]
    var out = []
    var fns = ["setCenterHoverRevealSuppressed", "switchPanelFrom"]
    for (var i = 0; i < fns.length; i++)
      if (typeof b[fns[i]] !== "function") out.push(fns[i])
    if (!b.shell) { out.push("shell"); return out }
    var sfns = ["serviceFor", "updateEntryInline"]
    for (var j = 0; j < sfns.length; j++)
      if (typeof b.shell[sfns[j]] !== "function") out.push("shell." + sfns[j])
    return out
  }

  property bool _hostChecked: false
  function checkHost() {
    if (_hostChecked || !bar) return
    _hostChecked = true
    var missing = missingHostApi(bar)
    if (missing.length > 0) console.warn("daily-deen: host API missing: " + missing.join(", "))
  }

  Timer {
    interval: 500
    repeat: true
    running: root.service === null
    triggeredOnStart: true
    onTriggered: root.resolveService()
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

  // The service cannot see shell.json itself (see Service.settings), so the
  // widget — whose `settings` the bar keeps current — passes it along.
  function feedService() {
    if (root.service && typeof root.service.adoptSettings === "function" && root.settings)
      root.service.adoptSettings(root.settings)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: { checkHost(); injectPanel(); resolveService() }
  onSettingsChanged: { injectPanel(); feedService() }
  onServiceChanged: { injectPanel(); feedService() }

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
