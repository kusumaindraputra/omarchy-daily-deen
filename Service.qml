import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model
import "I18n.js" as I18n

// Everything that must happen once rather than once per monitor: the rotation
// clock, the calls into bin/deen-fetch, the notification, and the IPC target a
// keybind can drive. A bar surface exists per screen, so a widget that owned
// any of this would fire three notifications on a three-monitor desk.
Item {
  id: root

  // Injected by shell.ensureService after construction — so Component.onCompleted
  // cannot see them, and everything that depends on them hangs off onShellChanged.
  property var shell: null
  property var manifest: null

  readonly property string pluginId: "io.github.kusumaindraputra.daily-deen"

  // A service is not handed `settings`, and the shell object it is given is a
  // scoped PluginShellApi with no shellConfig on it — reading shell.shellConfig
  // here yields undefined, so every setting silently read as its default and a
  // changed language never reached the helper. shell.barConfig exists but is
  // only refreshed when the plugin registry changes, not when shell.json does.
  //
  // The bar widgets are the one source that is live: the bar patches each
  // widget's `settings` in place on every change. They hand it over through
  // adoptSettings(); until the first one has, the barConfig snapshot stands in.
  property var pushedSettings: null
  readonly property var settings: pushedSettings !== null
    ? pushedSettings
    : Model.entrySettings(shell ? { bar: shell.barConfig } : null, pluginId)

  // One widget per monitor all push the same thing, and the bar injects twice
  // on purpose; comparing keeps that from restarting the repick timer.
  function adoptSettings(entry) {
    var next = ({})
    for (var key in entry) if (key !== "id") next[key] = entry[key]
    if (JSON.stringify(next) === JSON.stringify(pushedSettings)) return
    pushedSettings = next
  }
  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  // Called through /bin/bash rather than the shebang: a checkout can arrive
  // without the executable bit, and the shell inherits a PATH where a version
  // manager may have shimmed things.
  readonly property string helperPath: {
    var url = String(Qt.resolvedUrl("bin/deen-fetch"))
    return url.indexOf("file://") === 0 ? url.substring(7) : url
  }

  readonly property string cacheDir: Model.cacheDir(Quickshell.env("HOME"), Quickshell.env("XDG_CACHE_HOME"))
  readonly property string stateDir: Model.stateDir(Quickshell.env("HOME"), Quickshell.env("XDG_STATE_HOME"))

  // --- state ---------------------------------------------------------------

  // Named `current` rather than `state`: Item.state already exists as the
  // string QML state-machine property, and shadowing it with an object is a
  // trap even where it happens to work.
  property var current: Model.defaultState()
  property var catalog: null
  property string lastError: ""

  // The last pick exited non-zero. With no cache that leaves nothing to show,
  // and the state file missing is what normally triggers a first pick — so
  // without this flag a failed pick re-reads the file, finds it missing, picks
  // again, and spins for as long as the network is down. While it is set,
  // only the minute tick or a person pressing retry starts another attempt.
  property bool pickFailed: false

  // What the panel shows instead of "nothing loaded yet": the helper ran, came
  // back with nothing, and said why.
  readonly property bool failed: !busy && !hasContent && lastError !== ""
  property bool busy: false
  property bool syncing: false

  readonly property bool hasContent: Model.hasContent(current)

  // Nothing may run until the shell has been injected: until then `settings`
  // reads as {} and a rotation would be taken with the defaults rather than
  // with what the user configured.
  readonly property bool ready: shell !== null

  // A passage this instance merely read off disk is not a rotation. Without
  // this the service announces whatever was already on screen every time it
  // starts — and during a shell restart, where the outgoing and incoming
  // processes overlap, that arrives as two toasts a few seconds apart.
  property bool primed: false
  readonly property string locale: I18n.resolve(
    setting("uiLanguage", "auto"),
    setting("contentLanguage", "English"),
    Qt.locale().name)
  function t(key) { return I18n.t(locale, key) }

  readonly property string barText: Model.barLabel(current, setting("barDisplay", "glyph"))
  readonly property string barTooltip: Model.tooltipText(current)

  signal rotated()

  // --- rotation ------------------------------------------------------------

  // One minute, always, comparing a persisted timestamp — not a Timer whose
  // interval is the rotation period. A period-length Timer restarts from zero
  // when the shell restarts, which would break "the same ayah until the
  // interval is up", and a laptop waking after eight hours would fire it eight
  // times over. deen-fetch does the due check itself, so this just asks.
  Timer {
    interval: 60000
    running: true
    repeat: true
    triggeredOnStart: false
    onTriggered: root.tick()
  }

  // A settings change has to take effect now, not at the next rotation — a
  // person who just picked a different translation is looking at the panel.
  // pick() decides for itself whether anything actually changed: it hashes the
  // settings into a fingerprint and returns the current state untouched when
  // that fingerprint still matches, so a cosmetic change like the bar display
  // mode costs nothing. Debounced because shell.json is rewritten once per
  // control and a language change writes two keys at once.
  onSettingsChanged: if (ready) settingsSettle.restart()

  Timer {
    id: settingsSettle
    interval: 700
    onTriggered: root.rotate(false)
  }

  function tick() {
    if (!ready) return
    if (!Model.rotationDue(current.chosenAt, current.intervalHours || setting("rotationHours", 6), Date.now())) return
    rotate(false)
  }

  // A forced rotation that lands while the helper is still running is queued
  // rather than dropped: a person who pressed "show another" gets another,
  // even if the settings-change repick happened to be in flight.
  property bool pendingForce: false

  function rotate(force) {
    if (!ready) return
    if (force === true) pickFailed = false
    if (busy) {
      if (force === true) pendingForce = true
      return
    }
    busy = true
    pickProc.command = ["/bin/bash"].concat(Model.pickArgs(helperPath, settings, force === true, false))
    pickProc.running = true
  }

  function sync() {
    if (syncing) return
    syncing = true
    syncProc.command = ["/bin/bash", helperPath, "sync",
      "--quran", String(setting("quranEdition", "ara-quranuthmanihaf")),
      "--quran-translation", String(setting("quranTranslationEdition", "eng-abdelhaleem")),
      "--hadith", String(setting("hadithEdition", "eng-abudawud")),
      "--hadith-arabic", String(setting("hadithArabicEdition", "")),
      "--authority", String(setting("gradeAuthority", "Al-Albani"))]
    syncProc.running = true
  }

  function refreshCatalog() {
    catalogProc.command = ["/bin/bash", helperPath, "catalog"]
    catalogProc.running = true
  }

  Process {
    id: pickProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.adopt(text)
    }
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: root.lastError = String(text || "").trim() }
    onExited: function(code) {
      root.busy = false
      root.pickFailed = code !== 0
      if (code !== 0 && !root.hasContent) stateFile.reload()
      if (root.pendingForce) {
        root.pendingForce = false
        Qt.callLater(function() { root.rotate(true) })
      }
    }
  }

  Process {
    id: syncProc
    onExited: function(code) { root.syncing = false; if (code === 0) root.rotate(true) }
  }

  Process {
    id: catalogProc
    onExited: function(code) { if (code === 0) catalogFile.reload() }
  }

  // Adopting from the helper's stdout keeps the panel from waiting on the file
  // watcher; the FileView below is for changes this process did not make, such
  // as a keybind running deen-fetch directly.
  function adopt(raw) {
    var next = Model.parseState(raw)
    if (!Model.hasContent(next)) return
    var changed = next.chosenAt !== root.current.chosenAt
    var first = !root.primed
    root.current = next
    root.primed = true
    if (!changed || first) return
    root.rotated()
    // Backstop for the case primed cannot see: a second instance of this
    // service, alive for a moment during a reload, adopting a file the first
    // one just wrote. A rotation that already happened minutes ago is not news.
    if (Date.now() - (next.chosenAt || 0) < 120000) root.notify()
  }

  FileView {
    id: stateFile
    path: root.stateDir + "/current.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.adopt(text())
    onLoadFailed: {
      // No state file yet: pick the first passage, but stay unprimed so the
      // very first one arrives quietly.
      root.primed = false
      if (!root.pickFailed) root.rotate(false)
    }
  }

  FileView {
    id: catalogFile
    path: root.cacheDir + "/catalog.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try { root.catalog = JSON.parse(text()) } catch (e) { root.catalog = null }
    }
    onLoadFailed: root.refreshCatalog()
  }

  // Counts and grader names for the selected hadith edition, so the panel can
  // offer the scholars who actually graded this book rather than a hardcoded
  // list, and can say how many hadith a filter leaves to draw from. Sidecar to
  // the index: a couple of hundred bytes, where the index itself is tens of
  // kilobytes of number arrays that QML has no use for.
  property var hadithMeta: null

  FileView {
    id: metaFile
    path: root.cacheDir + "/index/" + String(root.setting("hadithEdition", "eng-abudawud")) + ".meta.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try { root.hadithMeta = JSON.parse(text()) } catch (e) { root.hadithMeta = null }
    }
    onLoadFailed: root.hadithMeta = null
  }

  // The very first read can race shell startup, which would leave the widget
  // empty until something else happened to touch the file. One delayed reload
  // is a no-op when the first read was fine.
  Timer {
    interval: 1500
    running: true
    onTriggered: { stateFile.reload(); catalogFile.reload(); metaFile.reload() }
  }

  // --- notification --------------------------------------------------------

  property int lastNotificationId: 0

  function notify() {
    if (setting("notify", true) !== true) return
    if (!hasContent) return

    var headline = ""
    var body = ""
    if (current.ayah) {
      headline = Model.ayahReference(current)
      body = Model.safeDisplayText(current.ayah.translation || current.ayah.text)
    } else if (current.hadith) {
      headline = Model.hadithReference(current)
      body = Model.safeDisplayText(current.hadith.text)
    }
    if (current.ayah && current.hadith) {
      headline = Model.ayahReference(current) + "  ·  " + Model.hadithReference(current)
    }
    if (!headline) return

    // An argv array, never a bash -c string: the body is scripture text fetched
    // from a CDN, and it must not be able to become an argument. omarchy's own
    // notification sender exists for the same reason — notify-send would
    // reinterpret a body that opens with a dash as options.
    var argv = ["omarchy-notification-send",
      "--app-name", "Daily Ayah & Hadith",
      "-u", "low",
      "-g", "\u{F405}",
      "-p"]
    if (lastNotificationId > 0) argv = argv.concat(["-r", String(lastNotificationId)])
    argv = argv.concat([headline, Model.snippet(body, 240)])
    // --exec has to come last and takes its command as separate words.
    argv = argv.concat(["--exec", "omarchy-shell", "shell", "toggle", pluginId])

    notifyProc.command = argv
    notifyProc.running = true
  }

  Process {
    id: notifyProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var id = parseInt(String(text || "").trim(), 10)
        // Reusing the id replaces the previous toast in place instead of
        // stacking a new one every rotation.
        if (!isNaN(id) && id > 0) root.lastNotificationId = id
      }
    }
  }

  // --- clipboard -----------------------------------------------------------

  property bool copied: false
  property bool copyFailed: false
  // True from the moment a copy starts until copyFinished has run once.
  property bool copyPending: false
  property string copyText: ""

  Timer { id: copiedTimer; interval: 2000; onTriggered: root.copied = false }

  function copyPassage(which) {
    if (copyProc.running || copyPending) return
    var text = Model.formatCopy(root.current, which || "all")
    if (!text) return
    copied = false
    copyFailed = false
    copiedTimer.stop()
    copyPending = true
    copyText = text
    // No shell: the text comes from a third-party CDN and goes over stdin only.
    copyProc.command = ["wl-copy"]
    // Re-armed on every run. onStarted turns it off to send EOF, and turning
    // off a property that is already off changes nothing — so on the second
    // copy the pipe was never closed and wl-copy waited on it forever, with
    // copyPending held true and every later copy silently refused.
    copyProc.stdinEnabled = true
    copyWatchdog.restart()
    copyProc.running = true
  }

  // Whatever goes wrong with wl-copy, "pending" must not outlive a few seconds:
  // it is what refuses the next copy.
  Timer {
    id: copyWatchdog
    interval: 5000
    onTriggered: {
      if (!root.copyPending) return
      copyProc.running = false
      root.copyFinished(-1)
    }
  }

  // Idempotent: exited and the not-running fallback may both report one run.
  function copyFinished(code) {
    if (!copyPending) return
    copyPending = false
    copyWatchdog.stop()
    copyText = ""
    if (code === 0) { copied = true; copiedTimer.restart() }
    else copyFailed = true
  }

  Process {
    id: copyProc
    stdinEnabled: true
    // wl-copy reads until EOF, then forks into the background to serve the
    // selection. Switching stdinEnabled off closes the write channel (Qt
    // flushes the buffered write first), which is the EOF it waits for.
    onStarted: {
      write(root.copyText)
      stdinEnabled = false
      root.copyText = ""
    }
    onExited: function(code) { root.copyFinished(code) }
    // A binary that cannot be started (wl-clipboard missing) may never emit a
    // sensible exit code. Deferred so a real exited signal always wins.
    onRunningChanged: if (!running) Qt.callLater(function() { root.copyFinished(-1) })
  }

  // --- IPC -----------------------------------------------------------------

  // `omarchy-shell shell call` only reaches panel/overlay/menu plugins, so a
  // service that wants a CLI surface has to register its own target. It lives
  // here and nowhere else: a target registered on the bar widget would be
  // registered once per monitor, and only one of them would win.
  //
  // Opening the panel is deliberately not here — that goes through
  // `omarchy-shell shell toggle <id>`, which picks the focused monitor's
  // instance. A signal from a service would open the panel on every screen.
  IpcHandler {
    target: "io.github.kusumaindraputra.daily-deen"

    // The pick, plus the few flags worth seeing when something looks wrong.
    function status(): string {
      var out = JSON.parse(JSON.stringify(root.current))
      out.serviceReady = root.ready
      out.servicePrimed = root.primed
      out.serviceBusy = root.busy
      out.serviceFailed = root.failed
      out.lastError = root.lastError
      out.copied = root.copied
      out.copyFailed = root.copyFailed
      return JSON.stringify(out)
    }
    function next(): string { root.rotate(true); return "ok" }
    function refresh(): string { root.rotate(false); return "ok" }
    function sync(): string { root.sync(); return "ok" }
    function catalog(): string { root.refreshCatalog(); return "ok" }
    function copy(which: string): string { root.copyPassage(which); return "ok" }
  }

  onShellChanged: if (shell) Qt.callLater(function() { stateFile.reload(); catalogFile.reload() })
}
