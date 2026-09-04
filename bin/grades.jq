# The one and only grade normaliser.
#
# Hadith graders write free text, not an enum. The corpus across the ten books
# contains things like "Sahih", "Hasan Sahih", "Sahih Isnaad", "Sahih
# Lighairihi", "Da'if", "Mauquf Sahih" and "Sahih Bukhari (1224) Sahih Muslim
# (570)" — that last one is a cross-reference, not a verdict, which is why the
# parenthesised citations are deleted before any keyword is looked for.
#
# Run at index-build time only. current.json carries the resulting class, so
# nothing downstream needs a second implementation that could drift from this one.

def _translit:
  gsub("[āáàâĀÁÀÂ]"; "a") | gsub("[īíìîĪÍÌÎ]"; "i") | gsub("[ūúùûŪÚÙÛ]"; "u")
  | gsub("[ḥḫḩḤḪḨ]"; "h") | gsub("[ḍḑḌḐ]"; "d") | gsub("[ṣşṢŞ]"; "s")
  | gsub("[ṭţṬŢ]"; "t") | gsub("[ẓẒ]"; "z")
  | gsub("[ʿʾ’‘'`´]"; "")
  | ascii_downcase;

def _norm:
  (. // "") | tostring | _translit
  | gsub("\\([^)]*\\)"; " ")      # drop "(1224)" style citations
  | gsub("\\[[^\\]]*\\]"; " ")
  | gsub("[^a-z]+"; " ")
  | sub("^ +"; "") | sub(" +$"; "");

# One grade string -> one class. First match wins; the order is the whole point.
def grade_class_of:
  _norm as $g
  | if   $g == ""                                        then "unknown"
    elif $g | test("mawdu|maudu|maud|fabricat|batil")     then "maudu"
    # munkar, shadh, malool, matruk are all defects, not forgeries. Grouping
    # them with mawdu would overstate the verdict; they belong with daif.
    elif $g | test("\\bdaif\\b|\\bdhaif\\b|\\bdaeef\\b|\\bweak\\b|munkar|shadh|shaadh|malool|muallal|matruk") then "daif"
    elif $g | test("hasan sahih|sahih hasan")            then "hasan"
    elif $g | test("sahih|sahi\\b|authentic")            then "sahih"
    elif $g | test("hasan")                              then "hasan"
    else "unknown"
    end;

def _rank: {"maudu":0, "daif":1, "unknown":2, "hasan":3, "sahih":4}[.] // 2;

# A hadith's grades[] plus the book it came from -> one class.
#
# $authority, when it matches a grader's name, decides on its own. Otherwise the
# strictest verdict present wins, which is the conservative reading and is at
# least deterministic — "first entry" would depend on upstream ordering.
#
# Sahih al-Bukhari and Sahih Muslim ship grades: [] because every hadith in them
# is sahih by construction. Left alone they would classify as "unknown" and a
# sahih filter over Bukhari would return nothing at all.
def hadith_grade_class($book; $authority):
  (.grades // []) as $gs
  | if ($gs | length) == 0 then
      (if ($book == "bukhari" or $book == "muslim") then "sahih" else "unknown" end)
    else
      ( if ($authority // "") == "" then null
        else ($gs | map(select((.name // "") | ascii_downcase | contains($authority | ascii_downcase))) | first)
        end ) as $picked
      | if $picked != null then ($picked.grade | grade_class_of)
        else ($gs | map(.grade | grade_class_of) | sort_by(_rank) | first)
        end
    end;
