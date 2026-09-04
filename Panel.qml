import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "Grades.js" as Grades
import "I18n.js" as I18n

// The popup: the ayah and the hadith in full, and the settings that decide
// which ones. BarWidget.qml owns the bar pill and hands this panel the button
// to anchor against.
//
// It is a view over the service's state — it never fetches and never picks. Its
// one job beyond rendering is writing a chosen edition back to shell.json.
Panel {
  id: root
  moduleName: "io.github.keyaypi.daily-deen"
  ipcTarget: "io.github.keyaypi.daily-deen"
  manageIpc: false

  property var anchorItem: null
  property var service: null

  // The bar tracks the widget mounted in its slot — BarWidget.qml — not this
  // nested panel. Everything the bar identifies a panel by has to be that
  // widget: the popout coordinator (and with it the open-panel dot under the
  // pill) compares against slot.activeItem.
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  property bool settingsOpen: false
  property int nowTick: Date.now()

  // `current` rather than `state`: Item.state is taken.
  readonly property var current: service ? service.current : Model.defaultState()
  readonly property var catalog: service ? service.catalog : null
  readonly property var hadithMeta: service ? service.hadithMeta : null
  readonly property string locale: service ? service.locale : "en"
  function t(key) { return I18n.t(locale, key) }

  readonly property var ayah: current ? current.ayah : null
  readonly property var hadith: current ? current.hadith : null
  readonly property bool showArabic: setting("showArabic", true) === true

  // Resolved once rather than per Text: Qt.fontFamilies() walks the whole
  // system font list, and there is one of these Texts per passage.
  readonly property var installedFonts: Qt.fontFamilies()

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(contentForeground, 1.5)
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property int remainingMs: Math.max(0,
    Model.nextRotationAt(current ? current.chosenAt : 0,
                         current ? (current.intervalHours || setting("rotationHours", 6)) : 6) - nowTick)

  // ---- lifecycle

  function open() {
    root.controller.show()
    root.nowTick = Date.now()
    // Set after showing, not before: showing hands the popout coordinator over,
    // which closes whichever panel was open, and that close clears the shared
    // flag.
    Qt.callLater(function() { if (root.opened) setCenterHoverRevealSuppressed(true) })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    root.controller.hide()
  }

  function toggle() { root.opened ? root.close() : root.open() }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  // Summoning by hotkey moves no pointer, so a hover the bar was still holding
  // must not keep the centre indicators revealed behind the panel.
  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  Timer {
    interval: 30000
    running: root.opened
    repeat: true
    onTriggered: root.nowTick = Date.now()
  }

  // ---- settings

  // Applied locally first so the panel redraws on the click itself; the
  // shell.json write comes back through the bar as the same value, and
  // updateEntryInline writes nothing at all when the entry is unchanged — which
  // is what keeps this from looping.
  function persist(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) {
      if (values[key] === undefined || values[key] === null || values[key] === "") delete entry[key]
      else entry[key] = values[key]
    }

    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  // Changing the translation language strands the edition that went with the
  // old one, so the first edition of the new language is chosen alongside it.
  // Leaving a dangling slug would show an empty panel with no explanation.
  function setContentLanguage(language) {
    var options = Model.quranEditionOptions(root.catalog, language)
    persist({
      contentLanguage: language,
      quranTranslationEdition: options.length > 0 ? options[0].value : ""
    })
  }

  function setHadithLanguage(language) {
    var books = Model.hadithBookOptions(root.catalog, language)
    var book = books.length > 0 ? books[0].value : ""
    var editions = Model.hadithEditionOptions(root.catalog, book, language)
    var edition = editions.length > 0 ? editions[0].value : ""
    persist({
      hadithLanguage: language,
      hadithEdition: edition,
      hadithArabicEdition: root.showArabic ? Model.arabicCounterpart(root.catalog, edition) : ""
    })
  }

  function setHadithBook(book) {
    var editions = Model.hadithEditionOptions(root.catalog, book, setting("hadithLanguage", "English"))
    var edition = editions.length > 0 ? editions[0].value : ""
    persist({
      hadithEdition: edition,
      hadithArabicEdition: root.showArabic ? Model.arabicCounterpart(root.catalog, edition) : ""
    })
  }

  function setShowArabic(value) {
    persist({
      showArabic: value,
      hadithArabicEdition: value
        ? Model.arabicCounterpart(root.catalog, setting("hadithEdition", "eng-abudawud"))
        : ""
    })
  }

  // The number field fires on every keystroke and every step of the spinner, so
  // it is the one control that has to settle before anything is written.
  property int pendingHours: 0
  Timer {
    id: hoursDebounce
    interval: 400
    onTriggered: if (root.pendingHours > 0) root.persist({ rotationHours: root.pendingHours })
  }

  // ---- option lists

  readonly property var quranLanguages: Model.languageOptions(catalog, "quran")
  readonly property var hadithLanguages: Model.languageOptions(catalog, "hadith")
  readonly property var arabicScripts: Model.quranEditionOptions(catalog, "Arabic")
  readonly property var translations: Model.quranEditionOptions(catalog, setting("contentLanguage", "English"))
  readonly property var hadithBooks: Model.hadithBookOptions(catalog, setting("hadithLanguage", "English"))
  readonly property string currentBook: {
    var info = Model.editionInfo(catalog, "hadith", setting("hadithEdition", "eng-abudawud"))
    return info ? info.book : ""
  }
  readonly property var hadithEditions: Model.hadithEditionOptions(catalog, currentBook, setting("hadithLanguage", "English"))

  readonly property var graderOptions: {
    var out = [{ value: "", label: t("strictest"), description: "" }]
    var names = hadithMeta && Array.isArray(hadithMeta.graders) ? hadithMeta.graders : []
    for (var i = 0; i < names.length; i++) out.push({ value: names[i], label: names[i], description: "" })
    return out
  }

  readonly property var gradeFilterOptions: [
    { value: "any", label: t("gradeAny") },
    { value: "sahih", label: t("gradeSahihOnly") },
    { value: "sahih-hasan", label: t("gradeSahihHasan") },
    { value: "daif", label: t("gradeDaifOnly") }
  ]

  // "3,512 sahih to draw from" — the count the current filter actually leaves.
  readonly property string poolNote: {
    if (!hadithMeta || !hadithMeta.counts) return ""
    var filter = setting("gradeFilter", "sahih-hasan")
    var wanted = filter === "any" ? Grades.ORDER
      : filter === "sahih" ? ["sahih"]
      : filter === "daif" ? ["daif"] : ["sahih", "hasan"]
    var total = 0
    for (var i = 0; i < wanted.length; i++) total += Number(hadithMeta.counts[wanted[i]] || 0)
    if (total <= 0) return ""
    return total + " / " + hadithMeta.total
  }

  readonly property bool dropdownOpen: {
    var kids = settingsColumn.children
    for (var i = 0; i < kids.length; i++) if (kids[i] && kids[i].popupOpen === true) return true
    return false
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(520))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      // A picker's search field owns the keyboard while it is up; without this
      // typing a filter would also drive the panel behind it.
      blocked: root.dropdownOpen
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(key) {
        if (key === "n" || key === "N") { if (root.service) root.service.rotate(true) }
        else if (key === "s" || key === "S") root.settingsOpen = !root.settingsOpen
      }

      Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: column
          width: scroll.width
          spacing: Style.spacing.panelGap

          // ---- hero

          PanelHero {
            width: parent.width
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            title: root.t("title")
            meta: root.remainingMs > 0
              ? root.t("nextIn") + " " + Model.formatDuration(root.remainingMs)
              : root.t("rotateNow")
            detail: root.current && root.current.source === "offline" ? root.t("offline") : ""

            trailingControl: Component {
              Row {
                spacing: Style.spacing.sm
                PanelActionButton {
                  iconText: "\u{F0450}"
                  tooltipText: root.t("rotateNow")
                  foreground: root.contentForeground
                  onClicked: if (root.service) root.service.rotate(true)
                }
                PanelActionButton {
                  iconText: "\u{F0493}"
                  tooltipText: root.t("settings")
                  foreground: root.settingsOpen ? Color.accent : root.contentForeground
                  onClicked: root.settingsOpen = !root.settingsOpen
                }
              }
            }
          }

          // ---- ayah

          Column {
            width: parent.width
            spacing: Style.spacing.md
            visible: root.ayah !== null && root.ayah !== undefined

            PanelSectionHeader {
              width: parent.width
              text: root.t("ayah")
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }

            ScriptureText {
              width: parent.width
              visible: root.showArabic && text !== ""
              text: root.ayah ? String(root.ayah.text || "") : ""
              language: root.ayah ? String(root.ayah.language || "") : ""
              direction: root.ayah ? String(root.ayah.direction || "ltr") : "ltr"
              foreground: root.contentForeground
              uiFamily: root.contentFontFamily
              scale_: 1.35
            }

            ScriptureText {
              width: parent.width
              visible: text !== ""
              text: root.ayah ? String(root.ayah.translation || "") : ""
              language: root.ayah ? String(root.ayah.translationLanguage || "") : ""
              direction: root.ayah ? String(root.ayah.translationDirection || "ltr") : "ltr"
              foreground: root.contentForeground
              uiFamily: root.contentFontFamily
            }

            Text {
              width: parent.width
              text: Model.ayahReference(root.current)
                + (root.ayah && root.ayah.translationAuthor ? "  ·  " + root.ayah.translationAuthor : "")
              color: root.dim
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              textFormat: Text.PlainText
              elide: Text.ElideRight
            }
          }

          Note {
            width: parent.width
            visible: root.current && root.current.unavailable && root.current.unavailable.indexOf("ayah") !== -1
            text: root.t("unavailableAyah")
            foreground: root.contentForeground
            uiFamily: root.contentFontFamily
          }

          PanelSeparator {
            width: parent.width
            foreground: root.contentForeground
            visible: root.ayah && root.hadith
          }

          // ---- hadith

          Column {
            width: parent.width
            spacing: Style.spacing.md
            visible: root.hadith !== null && root.hadith !== undefined

            PanelSectionHeader {
              width: parent.width
              text: root.t("hadith")
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }

            ScriptureText {
              width: parent.width
              visible: root.showArabic && text !== ""
              text: root.hadith ? String(root.hadith.arabicText || "") : ""
              language: "Arabic"
              direction: "rtl"
              foreground: root.contentForeground
              uiFamily: root.contentFontFamily
              scale_: 1.2
            }

            ScriptureText {
              width: parent.width
              visible: text !== ""
              text: root.hadith ? String(root.hadith.text || "") : ""
              language: root.hadith ? String(root.hadith.language || "") : ""
              direction: root.hadith ? String(root.hadith.direction || "ltr") : "ltr"
              foreground: root.contentForeground
              uiFamily: root.contentFontFamily
            }

            Text {
              width: parent.width
              text: {
                var ref = Model.hadithReference(root.current)
                var h = root.hadith
                if (h && h.reference && h.reference.book)
                  ref += "  ·  " + root.t("reference") + " " + h.reference.book + ":" + h.reference.hadith
                return ref
              }
              color: root.dim
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              textFormat: Text.PlainText
              elide: Text.ElideRight
            }

            // One badge per distinct verdict, with the scholars behind it —
            // four graders agreeing must not render as four identical chips.
            Flow {
              width: parent.width
              spacing: Style.spacing.sm
              visible: repeater.count > 0

              Repeater {
                id: repeater
                model: Grades.badges(root.hadith)

                Rectangle {
                  required property var modelData
                  radius: Style.cornerRadius > 0 ? Style.space(4) : 0
                  color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.06)
                  border.width: 1
                  border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.18)
                  implicitWidth: badgeRow.implicitWidth + Style.space(16)
                  implicitHeight: badgeRow.implicitHeight + Style.space(8)

                  Row {
                    id: badgeRow
                    anchors.centerIn: parent
                    spacing: Style.spacing.sm

                    Text {
                      text: modelData.grade
                      color: root.contentForeground
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      textFormat: Text.PlainText
                    }
                    Text {
                      visible: text !== ""
                      text: Grades.graderLine(modelData)
                      color: root.dim
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      textFormat: Text.PlainText
                    }
                  }
                }
              }
            }

            Note {
              width: parent.width
              visible: root.hadith && Grades.isImplicitlySahih(String(root.hadith.book || ""))
              text: root.t("ungradedNote")
              foreground: root.contentForeground
              uiFamily: root.contentFontFamily
            }

            Note {
              width: parent.width
              visible: root.current && root.current.gradeFallback === true
              text: root.t("gradeFallbackNote")
              foreground: root.contentForeground
              uiFamily: root.contentFontFamily
            }
          }

          Note {
            width: parent.width
            visible: root.current && root.current.unavailable && root.current.unavailable.indexOf("hadith") !== -1
            text: root.t("unavailableHadith")
            foreground: root.contentForeground
            uiFamily: root.contentFontFamily
          }

          Text {
            width: parent.width
            visible: !Model.hasContent(root.current)
            text: root.service && root.service.busy ? root.t("loading") : root.t("noContent")
            color: root.dim
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
          }

          // ---- settings

          PanelSeparator {
            width: parent.width
            foreground: root.contentForeground
            visible: root.settingsOpen
          }

          Column {
            id: settingsColumn
            width: parent.width
            spacing: Style.spacing.controlGap
            visible: root.settingsOpen

            PanelSectionHeader {
              width: parent.width
              text: root.t("settings")
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
            }

            // 492 editions never reach a picker as one list: the language comes
            // first, and the edition list is whatever that language has —
            // usually somewhere between one and twenty.
            SearchableDropdown {
              width: parent.width
              label: root.t("contentLanguage")
              placeholderText: root.t("search")
              options: root.quranLanguages
              value: root.setting("contentLanguage", "English")
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onChanged: function(v) { root.setContentLanguage(v) }
            }

            SearchableDropdown {
              width: parent.width
              label: root.t("quranTranslation")
              placeholderText: root.t("search")
              options: root.translations
              value: root.setting("quranTranslationEdition", "")
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onChanged: function(v) { root.persist({ quranTranslationEdition: v }) }
            }

            SearchableDropdown {
              width: parent.width
              visible: root.showArabic
              label: root.t("quranEdition")
              placeholderText: root.t("search")
              options: root.arabicScripts
              value: root.setting("quranEdition", "ara-quranuthmanihaf")
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onChanged: function(v) { root.persist({ quranEdition: v }) }
            }

            SearchableDropdown {
              width: parent.width
              label: root.t("hadithLanguage")
              placeholderText: root.t("search")
              options: root.hadithLanguages
              value: root.setting("hadithLanguage", "English")
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onChanged: function(v) { root.setHadithLanguage(v) }
            }

            SearchableDropdown {
              width: parent.width
              label: root.t("hadithBook")
              placeholderText: root.t("search")
              options: root.hadithBooks
              value: root.currentBook
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onChanged: function(v) { root.setHadithBook(v) }
            }

            // Most book-and-language pairs have exactly one edition, so the
            // picker only earns its space when there is a choice to make.
            SearchableDropdown {
              width: parent.width
              visible: root.hadithEditions.length > 1
              label: root.t("hadithEdition")
              placeholderText: root.t("search")
              options: root.hadithEditions
              value: root.setting("hadithEdition", "eng-abudawud")
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onChanged: function(v) { root.persist({ hadithEdition: v }) }
            }

            Dropdown {
              width: parent.width
              label: root.t("gradeFilter") + (root.poolNote ? "   " + root.poolNote : "")
              options: root.gradeFilterOptions
              value: root.setting("gradeFilter", "sahih-hasan")
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onChanged: function(v) { root.persist({ gradeFilter: v }) }
            }

            // The scholars who actually graded this book, read off the index,
            // rather than a fixed list that would be wrong for Muwatta Malik.
            SearchableDropdown {
              width: parent.width
              visible: root.graderOptions.length > 1
              label: root.t("gradeAuthority")
              placeholderText: root.t("search")
              options: root.graderOptions
              value: root.setting("gradeAuthority", "Al-Albani")
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onChanged: function(v) { root.persist({ gradeAuthority: v }) }
            }

            NumberField {
              label: root.t("rotationHours")
              from: 1
              to: 168
              stepSize: 1
              value: Number(root.setting("rotationHours", 6))
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onModified: function(v) { root.pendingHours = v; hoursDebounce.restart() }
            }

            Dropdown {
              width: parent.width
              label: root.t("rotationMode")
              options: [
                { value: "deterministic", label: root.t("deterministic") },
                { value: "random", label: root.t("random") }
              ]
              value: root.setting("rotationMode", "deterministic")
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onChanged: function(v) { root.persist({ rotationMode: v }) }
            }

            Dropdown {
              width: parent.width
              label: root.t("barDisplay")
              options: [
                { value: "glyph", label: root.t("barGlyph") },
                { value: "glyph-reference", label: root.t("barReference") },
                { value: "glyph-snippet", label: root.t("barSnippet") }
              ]
              value: root.setting("barDisplay", "glyph")
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onChanged: function(v) { root.persist({ barDisplay: v }) }
            }

            SearchableDropdown {
              width: parent.width
              label: root.t("uiLanguage")
              placeholderText: root.t("search")
              options: I18n.localeOptions(root.locale)
              value: root.setting("uiLanguage", "auto")
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onChanged: function(v) { root.persist({ uiLanguage: v }) }
            }

            Toggle {
              width: parent.width
              label: root.t("showArabic")
              checked: root.showArabic
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.setShowArabic(!root.showArabic)
            }

            Toggle {
              width: parent.width
              label: root.t("showAyah")
              checked: root.setting("showAyah", true) === true
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.persist({ showAyah: !(root.setting("showAyah", true) === true) })
            }

            Toggle {
              width: parent.width
              label: root.t("showHadith")
              checked: root.setting("showHadith", true) === true
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.persist({ showHadith: !(root.setting("showHadith", true) === true) })
            }

            Toggle {
              width: parent.width
              label: root.t("notify")
              checked: root.setting("notify", true) === true
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.persist({ notify: !(root.setting("notify", true) === true) })
            }
          }
        }
      }
    }
  }

  // ---- local components

  // Every remote string renders through this: PlainText so nothing in a
  // translation can be read as markup, a direction-aware alignment, and a font
  // chain that puts an Arabic face first for a right-to-left run because the
  // bar's monospace family has no Arabic coverage at all.
  component ScriptureText: Text {
    property string language: ""
    property string direction: "ltr"
    property color foreground: Color.foreground
    property string uiFamily: Style.font.family
    property real scale_: 1.0

    readonly property bool rtl: Model.isRtl(direction)

    color: foreground
    textFormat: Text.PlainText
    wrapMode: Text.WordWrap
    horizontalAlignment: rtl ? Text.AlignRight : Text.AlignLeft
    font.family: Model.familyFor(language, direction, root.installedFonts, uiFamily)
    font.pixelSize: Math.round(Style.font.body * scale_)
    lineHeight: Model.lineHeightFor(language, direction)
    lineHeightMode: Text.ProportionalHeight
  }

  component Note: Text {
    property color foreground: Color.foreground
    property string uiFamily: Style.font.family

    color: Qt.darker(foreground, 1.5)
    font.family: uiFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
    textFormat: Text.PlainText
    horizontalAlignment: I18n.isRtlLocale(root.locale) ? Text.AlignRight : Text.AlignLeft
  }
}
