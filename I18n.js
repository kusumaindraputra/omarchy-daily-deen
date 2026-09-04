// UI strings for the plugin's own chrome.
//
// The content language (98 for the Qur'an, 9 for hadith) is a different axis
// from this one: the translations come from the API, these strings have to be
// written by hand, so only the nine locales below are shipped. "auto" follows
// the content language when a locale for it exists and falls back to English
// otherwise, which is also what t() does for any single key a locale is missing.
//
// A plain .js table rather than JSON on disk: it is parsed once with the
// component, needs no async load and no second file watcher on a directory the
// PluginRegistry is already watching, and node --test can require it.
//
// Note that manifest.json's own name/displayName/description cannot be
// localised — they are static JSON read by the plugin scanner — so those stay
// English and everything in-plugin goes through t().

var STRINGS = {
  en: {
    title: "Daily Ayah & Hadith",
    ayah: "Ayah", hadith: "Hadith",
    arabic: "Arabic", translation: "Translation",
    reference: "Reference", grading: "Grading", gradedBy: "graded by",
    nextIn: "Next in", rotateNow: "Show another",
    settings: "Settings", close: "Close", copy: "Copy", copied: "Copied",
    contentLanguage: "Translation language",
    quranEdition: "Qur'an script", quranTranslation: "Qur'an translation",
    hadithLanguage: "Hadith language", hadithBook: "Hadith collection",
    hadithEdition: "Hadith edition", hadithArabic: "Hadith in Arabic",
    gradeFilter: "Only show hadith graded",
    gradeAny: "Any grading", gradeSahihOnly: "Sahih", gradeSahihHasan: "Sahih or hasan", gradeDaifOnly: "Da'if",
    gradeAuthority: "Preferred grader", strictest: "Strictest verdict",
    rotationHours: "Rotate every (hours)", rotationMode: "Choice",
    deterministic: "Same everywhere", random: "Random",
    notify: "Notify when it rotates", barDisplay: "Show in the bar",
    barGlyph: "Icon only", barReference: "Icon and reference", barSnippet: "Icon and a few words",
    uiLanguage: "Plugin language", auto: "Follow the translation",
    showAyah: "Show an ayah", showHadith: "Show a hadith",
    search: "Search",
    loading: "Loading…", noContent: "Nothing loaded yet",
    offline: "Offline — showing what was cached",
    unavailableAyah: "The ayah could not be loaded. Connect to the internet once to cache it.",
    unavailableHadith: "The hadith could not be loaded. Connect to the internet once to cache it.",
    gradeFallbackNote: "This collection carries no gradings, so the filter was ignored.",
    ungradedNote: "Every hadith in this collection is sahih by construction, so it carries no grade strings.",
    classSahih: "Sahih", classHasan: "Hasan", classDaif: "Da'if",
    classMaudu: "Fabricated", classUnknown: "Ungraded"
  },

  id: {
    title: "Ayat & Hadis Harian",
    ayah: "Ayat", hadith: "Hadis",
    arabic: "Arab", translation: "Terjemahan",
    reference: "Rujukan", grading: "Derajat", gradedBy: "dinilai oleh",
    nextIn: "Berganti dalam", rotateNow: "Tampilkan yang lain",
    settings: "Pengaturan", close: "Tutup", copy: "Salin", copied: "Tersalin",
    contentLanguage: "Bahasa terjemahan",
    quranEdition: "Mushaf Al-Qur'an", quranTranslation: "Terjemahan Al-Qur'an",
    hadithLanguage: "Bahasa hadis", hadithBook: "Kitab hadis",
    hadithEdition: "Edisi hadis", hadithArabic: "Hadis dalam bahasa Arab",
    gradeFilter: "Hanya tampilkan hadis berderajat",
    gradeAny: "Semua derajat", gradeSahihOnly: "Sahih", gradeSahihHasan: "Sahih atau hasan", gradeDaifOnly: "Da'if",
    gradeAuthority: "Penilai yang diutamakan", strictest: "Penilaian terketat",
    rotationHours: "Berganti tiap (jam)", rotationMode: "Cara memilih",
    deterministic: "Sama di semua perangkat", random: "Acak",
    notify: "Beri notifikasi saat berganti", barDisplay: "Tampilan di bar",
    barGlyph: "Ikon saja", barReference: "Ikon dan rujukan", barSnippet: "Ikon dan sepenggal teks",
    uiLanguage: "Bahasa plugin", auto: "Ikut bahasa terjemahan",
    showAyah: "Tampilkan ayat", showHadith: "Tampilkan hadis",
    search: "Cari",
    loading: "Memuat…", noContent: "Belum ada yang dimuat",
    offline: "Luring — menampilkan data yang tersimpan",
    unavailableAyah: "Ayat belum bisa dimuat. Sambungkan ke internet sekali agar tersimpan.",
    unavailableHadith: "Hadis belum bisa dimuat. Sambungkan ke internet sekali agar tersimpan.",
    gradeFallbackNote: "Kitab ini tidak menyertakan penilaian derajat, jadi filternya diabaikan.",
    ungradedNote: "Seluruh hadis dalam kitab ini sahih, sehingga tidak mencantumkan keterangan derajat.",
    classSahih: "Sahih", classHasan: "Hasan", classDaif: "Da'if",
    classMaudu: "Maudu'", classUnknown: "Tanpa penilaian"
  },

  ms: {
    title: "Ayat & Hadis Harian",
    ayah: "Ayat", hadith: "Hadis",
    arabic: "Arab", translation: "Terjemahan",
    reference: "Rujukan", grading: "Darjat", gradedBy: "dinilai oleh",
    nextIn: "Bertukar dalam", rotateNow: "Papar yang lain",
    settings: "Tetapan", close: "Tutup", copy: "Salin", copied: "Disalin",
    contentLanguage: "Bahasa terjemahan",
    quranEdition: "Mushaf Al-Quran", quranTranslation: "Terjemahan Al-Quran",
    hadithLanguage: "Bahasa hadis", hadithBook: "Kitab hadis",
    hadithEdition: "Edisi hadis", hadithArabic: "Hadis dalam bahasa Arab",
    gradeFilter: "Hanya papar hadis berdarjat",
    gradeAny: "Semua darjat", gradeSahihOnly: "Sahih", gradeSahihHasan: "Sahih atau hasan", gradeDaifOnly: "Da'if",
    gradeAuthority: "Penilai pilihan", strictest: "Penilaian paling ketat",
    rotationHours: "Bertukar setiap (jam)", rotationMode: "Cara pilihan",
    deterministic: "Sama di semua peranti", random: "Rawak",
    notify: "Beritahu apabila bertukar", barDisplay: "Paparan pada bar",
    barGlyph: "Ikon sahaja", barReference: "Ikon dan rujukan", barSnippet: "Ikon dan cebisan teks",
    uiLanguage: "Bahasa pemalam", auto: "Ikut bahasa terjemahan",
    showAyah: "Papar ayat", showHadith: "Papar hadis",
    search: "Cari",
    loading: "Memuatkan…", noContent: "Belum ada yang dimuatkan",
    offline: "Luar talian — memaparkan data tersimpan",
    unavailableAyah: "Ayat belum dapat dimuatkan. Sambung ke internet sekali untuk menyimpannya.",
    unavailableHadith: "Hadis belum dapat dimuatkan. Sambung ke internet sekali untuk menyimpannya.",
    gradeFallbackNote: "Kitab ini tidak menyertakan penilaian darjat, jadi penapis diabaikan.",
    ungradedNote: "Setiap hadis dalam kitab ini sahih, jadi ia tidak mencatatkan darjat.",
    classSahih: "Sahih", classHasan: "Hasan", classDaif: "Da'if",
    classMaudu: "Maudhu'", classUnknown: "Tanpa penilaian"
  },

  ar: {
    title: "آية وحديث اليوم",
    ayah: "آية", hadith: "حديث",
    arabic: "العربية", translation: "الترجمة",
    reference: "المرجع", grading: "الدرجة", gradedBy: "حكم عليه",
    nextIn: "التالي بعد", rotateNow: "اعرض غيره",
    settings: "الإعدادات", close: "إغلاق", copy: "نسخ", copied: "تم النسخ",
    contentLanguage: "لغة الترجمة",
    quranEdition: "رسم المصحف", quranTranslation: "ترجمة القرآن",
    hadithLanguage: "لغة الحديث", hadithBook: "كتاب الحديث",
    hadithEdition: "نسخة الحديث", hadithArabic: "الحديث بالعربية",
    gradeFilter: "اعرض الأحاديث بدرجة",
    gradeAny: "كل الدرجات", gradeSahihOnly: "صحيح", gradeSahihHasan: "صحيح أو حسن", gradeDaifOnly: "ضعيف",
    gradeAuthority: "المحدّث المفضل", strictest: "أشد الأحكام",
    rotationHours: "التبديل كل (ساعة)", rotationMode: "طريقة الاختيار",
    deterministic: "نفسه على كل جهاز", random: "عشوائي",
    notify: "إشعار عند التبديل", barDisplay: "العرض في الشريط",
    barGlyph: "الأيقونة فقط", barReference: "الأيقونة والمرجع", barSnippet: "الأيقونة ومقتطف",
    uiLanguage: "لغة الإضافة", auto: "تبع لغة الترجمة",
    showAyah: "اعرض آية", showHadith: "اعرض حديثًا",
    search: "بحث",
    loading: "جارٍ التحميل…", noContent: "لا يوجد محتوى بعد",
    offline: "دون اتصال — يُعرض المحفوظ",
    unavailableAyah: "تعذّر تحميل الآية. اتصل بالإنترنت مرة واحدة لحفظها.",
    unavailableHadith: "تعذّر تحميل الحديث. اتصل بالإنترنت مرة واحدة لحفظه.",
    gradeFallbackNote: "هذا الكتاب لا يذكر درجات، فتم تجاهل عامل التصفية.",
    ungradedNote: "كل أحاديث هذا الكتاب صحيحة، ولذلك لا تُذكر درجاتها.",
    classSahih: "صحيح", classHasan: "حسن", classDaif: "ضعيف",
    classMaudu: "موضوع", classUnknown: "بلا درجة"
  },

  tr: {
    title: "Günün Ayeti ve Hadisi",
    ayah: "Ayet", hadith: "Hadis",
    arabic: "Arapça", translation: "Meal",
    reference: "Kaynak", grading: "Derece", gradedBy: "değerlendiren",
    nextIn: "Sonraki", rotateNow: "Başka bir tane göster",
    settings: "Ayarlar", close: "Kapat", copy: "Kopyala", copied: "Kopyalandı",
    contentLanguage: "Meal dili",
    quranEdition: "Kur'an hattı", quranTranslation: "Kur'an meali",
    hadithLanguage: "Hadis dili", hadithBook: "Hadis kitabı",
    hadithEdition: "Hadis baskısı", hadithArabic: "Arapça hadis metni",
    gradeFilter: "Yalnızca şu dereceli hadisler",
    gradeAny: "Tüm dereceler", gradeSahihOnly: "Sahih", gradeSahihHasan: "Sahih veya hasen", gradeDaifOnly: "Zayıf",
    gradeAuthority: "Tercih edilen muhaddis", strictest: "En sıkı hüküm",
    rotationHours: "Değişim aralığı (saat)", rotationMode: "Seçim",
    deterministic: "Her cihazda aynı", random: "Rastgele",
    notify: "Değiştiğinde bildir", barDisplay: "Çubukta görünüm",
    barGlyph: "Yalnızca simge", barReference: "Simge ve kaynak", barSnippet: "Simge ve kısa metin",
    uiLanguage: "Eklenti dili", auto: "Meal dilini izle",
    showAyah: "Ayet göster", showHadith: "Hadis göster",
    search: "Ara",
    loading: "Yükleniyor…", noContent: "Henüz içerik yok",
    offline: "Çevrimdışı — önbellekteki gösteriliyor",
    unavailableAyah: "Ayet yüklenemedi. Önbelleğe almak için bir kez internete bağlanın.",
    unavailableHadith: "Hadis yüklenemedi. Önbelleğe almak için bir kez internete bağlanın.",
    gradeFallbackNote: "Bu kitapta derece bilgisi yok, bu yüzden filtre yok sayıldı.",
    ungradedNote: "Bu kitaptaki her hadis sahihtir, bu yüzden derece bilgisi taşımaz.",
    classSahih: "Sahih", classHasan: "Hasen", classDaif: "Zayıf",
    classMaudu: "Mevzu", classUnknown: "Derecesiz"
  },

  ur: {
    title: "روزانہ آیت و حدیث",
    ayah: "آیت", hadith: "حدیث",
    arabic: "عربی", translation: "ترجمہ",
    reference: "حوالہ", grading: "درجہ", gradedBy: "حکم لگایا",
    nextIn: "اگلی تبدیلی", rotateNow: "کوئی اور دکھائیں",
    settings: "ترتیبات", close: "بند کریں", copy: "نقل کریں", copied: "نقل ہو گیا",
    contentLanguage: "ترجمے کی زبان",
    quranEdition: "قرآن کا رسم", quranTranslation: "قرآن کا ترجمہ",
    hadithLanguage: "حدیث کی زبان", hadithBook: "کتابِ حدیث",
    hadithEdition: "حدیث کا نسخہ", hadithArabic: "عربی متنِ حدیث",
    gradeFilter: "صرف اس درجے کی احادیث",
    gradeAny: "تمام درجات", gradeSahihOnly: "صحیح", gradeSahihHasan: "صحیح یا حسن", gradeDaifOnly: "ضعیف",
    gradeAuthority: "پسندیدہ محدث", strictest: "سخت ترین حکم",
    rotationHours: "ہر کتنے گھنٹے بعد", rotationMode: "انتخاب",
    deterministic: "ہر آلے پر یکساں", random: "بے ترتیب",
    notify: "تبدیلی پر اطلاع", barDisplay: "بار میں دکھائیں",
    barGlyph: "صرف علامت", barReference: "علامت اور حوالہ", barSnippet: "علامت اور مختصر متن",
    uiLanguage: "پلگ ان کی زبان", auto: "ترجمے کی زبان کے مطابق",
    showAyah: "آیت دکھائیں", showHadith: "حدیث دکھائیں",
    search: "تلاش",
    loading: "لوڈ ہو رہا ہے…", noContent: "ابھی کچھ نہیں",
    offline: "آف لائن — محفوظ شدہ دکھایا جا رہا ہے",
    unavailableAyah: "آیت لوڈ نہ ہو سکی۔ محفوظ کرنے کے لیے ایک بار انٹرنیٹ سے جڑیں۔",
    unavailableHadith: "حدیث لوڈ نہ ہو سکی۔ محفوظ کرنے کے لیے ایک بار انٹرنیٹ سے جڑیں۔",
    gradeFallbackNote: "اس کتاب میں درجات درج نہیں، اس لیے فلٹر نظر انداز کر دیا گیا۔",
    ungradedNote: "اس کتاب کی ہر حدیث صحیح ہے، اسی لیے درجہ درج نہیں کیا جاتا۔",
    classSahih: "صحیح", classHasan: "حسن", classDaif: "ضعیف",
    classMaudu: "موضوع", classUnknown: "بلا درجہ"
  },

  bn: {
    title: "দৈনিক আয়াত ও হাদিস",
    ayah: "আয়াত", hadith: "হাদিস",
    arabic: "আরবি", translation: "অনুবাদ",
    reference: "সূত্র", grading: "মান", gradedBy: "মান দিয়েছেন",
    nextIn: "পরেরটি", rotateNow: "অন্য একটি দেখান",
    settings: "সেটিংস", close: "বন্ধ", copy: "কপি", copied: "কপি হয়েছে",
    contentLanguage: "অনুবাদের ভাষা",
    quranEdition: "কুরআনের লিপি", quranTranslation: "কুরআনের অনুবাদ",
    hadithLanguage: "হাদিসের ভাষা", hadithBook: "হাদিস গ্রন্থ",
    hadithEdition: "হাদিস সংস্করণ", hadithArabic: "আরবি হাদিস",
    gradeFilter: "কেবল এই মানের হাদিস",
    gradeAny: "সব মান", gradeSahihOnly: "সহিহ", gradeSahihHasan: "সহিহ বা হাসান", gradeDaifOnly: "দুর্বল",
    gradeAuthority: "পছন্দের মুহাদ্দিস", strictest: "কঠোরতম রায়",
    rotationHours: "প্রতি কত ঘণ্টায়", rotationMode: "নির্বাচন",
    deterministic: "সব ডিভাইসে একই", random: "এলোমেলো",
    notify: "পরিবর্তনে জানান", barDisplay: "বারে দেখান",
    barGlyph: "শুধু আইকন", barReference: "আইকন ও সূত্র", barSnippet: "আইকন ও কিছু শব্দ",
    uiLanguage: "প্লাগিনের ভাষা", auto: "অনুবাদের ভাষা অনুসরণ",
    showAyah: "আয়াত দেখান", showHadith: "হাদিস দেখান",
    search: "খুঁজুন",
    loading: "লোড হচ্ছে…", noContent: "এখনো কিছু নেই",
    offline: "অফলাইন — সংরক্ষিত দেখানো হচ্ছে",
    unavailableAyah: "আয়াত লোড করা যায়নি। সংরক্ষণের জন্য একবার ইন্টারনেটে যুক্ত হন।",
    unavailableHadith: "হাদিস লোড করা যায়নি। সংরক্ষণের জন্য একবার ইন্টারনেটে যুক্ত হন।",
    gradeFallbackNote: "এই গ্রন্থে মান উল্লেখ নেই, তাই ফিল্টার উপেক্ষা করা হয়েছে।",
    ungradedNote: "এই গ্রন্থের প্রতিটি হাদিসই সহিহ, তাই আলাদা মান লেখা থাকে না।",
    classSahih: "সহিহ", classHasan: "হাসান", classDaif: "দুর্বল",
    classMaudu: "জাল", classUnknown: "মানহীন"
  },

  fr: {
    title: "Verset et hadith du jour",
    ayah: "Verset", hadith: "Hadith",
    arabic: "Arabe", translation: "Traduction",
    reference: "Référence", grading: "Authenticité", gradedBy: "jugé par",
    nextIn: "Prochain dans", rotateNow: "En afficher un autre",
    settings: "Paramètres", close: "Fermer", copy: "Copier", copied: "Copié",
    contentLanguage: "Langue de la traduction",
    quranEdition: "Graphie du Coran", quranTranslation: "Traduction du Coran",
    hadithLanguage: "Langue des hadiths", hadithBook: "Recueil de hadiths",
    hadithEdition: "Édition du hadith", hadithArabic: "Hadith en arabe",
    gradeFilter: "N'afficher que les hadiths jugés",
    gradeAny: "Tous", gradeSahihOnly: "Sahih", gradeSahihHasan: "Sahih ou hasan", gradeDaifOnly: "Da'if",
    gradeAuthority: "Savant de référence", strictest: "Jugement le plus strict",
    rotationHours: "Changer toutes les (heures)", rotationMode: "Choix",
    deterministic: "Identique partout", random: "Aléatoire",
    notify: "Notifier au changement", barDisplay: "Affichage dans la barre",
    barGlyph: "Icône seule", barReference: "Icône et référence", barSnippet: "Icône et extrait",
    uiLanguage: "Langue du greffon", auto: "Suivre la traduction",
    showAyah: "Afficher un verset", showHadith: "Afficher un hadith",
    search: "Rechercher",
    loading: "Chargement…", noContent: "Rien de chargé",
    offline: "Hors ligne — contenu en cache",
    unavailableAyah: "Le verset n'a pas pu être chargé. Connectez-vous une fois pour le mettre en cache.",
    unavailableHadith: "Le hadith n'a pas pu être chargé. Connectez-vous une fois pour le mettre en cache.",
    gradeFallbackNote: "Ce recueil ne porte aucun jugement, le filtre a donc été ignoré.",
    ungradedNote: "Tous les hadiths de ce recueil sont sahih, aucun jugement n'y figure donc.",
    classSahih: "Sahih", classHasan: "Hasan", classDaif: "Da'if",
    classMaudu: "Forgé", classUnknown: "Non jugé"
  },

  ru: {
    title: "Аят и хадис дня",
    ayah: "Аят", hadith: "Хадис",
    arabic: "Арабский", translation: "Перевод",
    reference: "Источник", grading: "Степень", gradedBy: "оценил",
    nextIn: "Смена через", rotateNow: "Показать другой",
    settings: "Настройки", close: "Закрыть", copy: "Копировать", copied: "Скопировано",
    contentLanguage: "Язык перевода",
    quranEdition: "Начертание Корана", quranTranslation: "Перевод Корана",
    hadithLanguage: "Язык хадисов", hadithBook: "Сборник хадисов",
    hadithEdition: "Издание хадисов", hadithArabic: "Хадис по-арабски",
    gradeFilter: "Показывать хадисы со степенью",
    gradeAny: "Любая", gradeSahihOnly: "Сахих", gradeSahihHasan: "Сахих или хасан", gradeDaifOnly: "Даиф",
    gradeAuthority: "Предпочитаемый мухаддис", strictest: "Самая строгая оценка",
    rotationHours: "Менять каждые (часов)", rotationMode: "Выбор",
    deterministic: "Одинаково везде", random: "Случайно",
    notify: "Уведомлять о смене", barDisplay: "Вид в панели",
    barGlyph: "Только значок", barReference: "Значок и источник", barSnippet: "Значок и отрывок",
    uiLanguage: "Язык плагина", auto: "По языку перевода",
    showAyah: "Показывать аят", showHadith: "Показывать хадис",
    search: "Поиск",
    loading: "Загрузка…", noContent: "Пока ничего нет",
    offline: "Офлайн — показано из кэша",
    unavailableAyah: "Аят не загрузился. Подключитесь к интернету один раз, чтобы сохранить его.",
    unavailableHadith: "Хадис не загрузился. Подключитесь к интернету один раз, чтобы сохранить его.",
    gradeFallbackNote: "В этом сборнике нет оценок, поэтому фильтр не применялся.",
    ungradedNote: "Все хадисы этого сборника достоверны, поэтому степень в них не указывается.",
    classSahih: "Сахих", classHasan: "Хасан", classDaif: "Даиф",
    classMaudu: "Вымышленный", classUnknown: "Без оценки"
  }
}

var RTL_LOCALES = { ar: true, ur: true }

// The content language names as the APIs spell them, mapped to the locales that
// exist here. Anything not in this table falls through to English.
var LANGUAGE_TO_LOCALE = {
  English: "en", Indonesian: "id", Malay: "ms", Arabic: "ar", Turkish: "tr",
  Urdu: "ur", Bengali: "bn", French: "fr", Russian: "ru"
}

function locales() {
  var out = []
  for (var k in STRINGS) out.push(k)
  out.sort()
  return out
}

function resolve(uiLanguageSetting, contentLanguage, systemLocaleName) {
  var want = String(uiLanguageSetting || "auto")
  if (want !== "auto" && STRINGS[want]) return want
  if (want === "auto") {
    var byContent = LANGUAGE_TO_LOCALE[String(contentLanguage || "")]
    if (byContent && STRINGS[byContent]) return byContent
    var bySystem = String(systemLocaleName || "").split("_")[0].split("-")[0]
    if (STRINGS[bySystem]) return bySystem
  }
  return "en"
}

function t(locale, key) {
  var table = STRINGS[locale] || STRINGS.en
  if (table[key] !== undefined) return table[key]
  if (STRINGS.en[key] !== undefined) return STRINGS.en[key]
  return key
}

function isRtlLocale(locale) { return RTL_LOCALES[locale] === true }

// Native name for each locale, so the picker is readable to the person who
// needs it rather than to an English speaker.
var LOCALE_NAMES = {
  en: "English", id: "Bahasa Indonesia", ms: "Bahasa Melayu", ar: "العربية",
  tr: "Türkçe", ur: "اردو", bn: "বাংলা", fr: "Français", ru: "Русский"
}

function localeOptions(locale) {
  var out = [{ value: "auto", label: t(locale, "auto"), description: "" }]
  var names = locales()
  for (var i = 0; i < names.length; i++) {
    out.push({ value: names[i], label: LOCALE_NAMES[names[i]] || names[i], description: names[i] })
  }
  return out
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    STRINGS: STRINGS, LANGUAGE_TO_LOCALE: LANGUAGE_TO_LOCALE, LOCALE_NAMES: LOCALE_NAMES,
    locales: locales, resolve: resolve, t: t, isRtlLocale: isRtlLocale,
    localeOptions: localeOptions
  }
}
