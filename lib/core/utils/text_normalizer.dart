// lib/core/utils/text_normalizer.dart
// ─────────────────────────────────────────────────────────────────────────────
// Normalizes Arabic and Greek text for diacritic-insensitive search.
//
// Arabic:
//   • Removes harakat / tashkeel (ً ٌ ٍ َ ُ ِ ّ ْ ـ and extended marks)
//   • Normalizes alef variants (أ إ آ ٱ) → ا
//   • Normalizes ya  (ى) → ي
//   • Normalizes waw-hamza (ؤ) → و
//
// Greek:
//   • Strips monotonic and polytonic accent marks (ά→α, ῶ→ω, etc.)
//   • Lowercases
//
// General:
//   • Lowercases the whole string
//   • Collapses runs of whitespace
// ─────────────────────────────────────────────────────────────────────────────

class TextNormalizer {
  TextNormalizer._();

  // ── Arabic patterns ────────────────────────────────────────────────────────

  /// Harakat, tashkeel, Quranic marks, tatweel (U+0640).
  static final _arDiacritics = RegExp('[ؐ-ًؚ-ٰٟۖ-ۜ۟-۪ۤۧۨ-ۭـ]');

  /// أ إ آ ٱ  →  ا
  static final _arAlef = RegExp('[أإآٱ]');

  /// ى  →  ي
  static final _arYa = RegExp('ى');

  /// ؤ  →  و
  static final _arWaw = RegExp('ؤ');

  /// ئ  →  ي
  static final _arYaHamza = RegExp('ئ');

  // ── Greek accent map ───────────────────────────────────────────────────────
  // Covers both monotonic (common) and the most frequent polytonic characters.

  static const _greekMap = <String, String>{
    // Lowercase accented → plain
    'ά': 'α',
    'έ': 'ε',
    'ή': 'η',
    'ί': 'ι', 'ΐ': 'ι', 'ϊ': 'ι',
    'ό': 'ο',
    'ύ': 'υ', 'ΰ': 'υ', 'ϋ': 'υ',
    'ώ': 'ω',
    // Polytonic lowercase
    'ὰ': 'α', 'ᾰ': 'α', 'ᾱ': 'α', 'ἀ': 'α', 'ἁ': 'α', 'ἂ': 'α',
    'ἃ': 'α', 'ἄ': 'α', 'ἅ': 'α', 'ἆ': 'α', 'ἇ': 'α',
    'ᾀ': 'α', 'ᾁ': 'α', 'ᾂ': 'α', 'ᾃ': 'α', 'ᾄ': 'α', 'ᾅ': 'α',
    'ᾆ': 'α', 'ᾇ': 'α', 'ᾲ': 'α', 'ᾳ': 'α', 'ᾴ': 'α', 'ᾶ': 'α', 'ᾷ': 'α',
    'ὲ': 'ε', 'ἐ': 'ε', 'ἑ': 'ε', 'ἒ': 'ε', 'ἓ': 'ε', 'ἔ': 'ε', 'ἕ': 'ε',
    'ὴ': 'η', 'ἠ': 'η', 'ἡ': 'η', 'ἢ': 'η', 'ἣ': 'η', 'ἤ': 'η',
    'ἥ': 'η', 'ἦ': 'η', 'ἧ': 'η', 'ᾐ': 'η', 'ᾑ': 'η', 'ᾒ': 'η',
    'ᾓ': 'η', 'ᾔ': 'η', 'ᾕ': 'η', 'ᾖ': 'η', 'ᾗ': 'η',
    'ῂ': 'η', 'ῃ': 'η', 'ῄ': 'η', 'ῆ': 'η', 'ῇ': 'η',
    'ὶ': 'ι', 'ἰ': 'ι', 'ἱ': 'ι', 'ἲ': 'ι', 'ἳ': 'ι', 'ἴ': 'ι',
    'ἵ': 'ι',
    'ἶ': 'ι',
    'ἷ': 'ι',
    'ῐ': 'ι',
    'ῑ': 'ι',
    'ῒ': 'ι',
    'ῖ': 'ι',
    'ῗ': 'ι',
    'ὸ': 'ο', 'ὀ': 'ο', 'ὁ': 'ο', 'ὂ': 'ο', 'ὃ': 'ο', 'ὄ': 'ο', 'ὅ': 'ο',
    'ὺ': 'υ', 'ὐ': 'υ', 'ὑ': 'υ', 'ὒ': 'υ', 'ὓ': 'υ', 'ὔ': 'υ',
    'ὕ': 'υ',
    'ὖ': 'υ',
    'ὗ': 'υ',
    'ῠ': 'υ',
    'ῡ': 'υ',
    'ῢ': 'υ',
    'ῦ': 'υ',
    'ῧ': 'υ',
    'ὼ': 'ω', 'ὠ': 'ω', 'ὡ': 'ω', 'ὢ': 'ω', 'ὣ': 'ω', 'ὤ': 'ω',
    'ὥ': 'ω', 'ὦ': 'ω', 'ὧ': 'ω', 'ᾠ': 'ω', 'ᾡ': 'ω', 'ᾢ': 'ω',
    'ᾣ': 'ω', 'ᾤ': 'ω', 'ᾥ': 'ω', 'ᾦ': 'ω', 'ᾧ': 'ω',
    'ῲ': 'ω', 'ῳ': 'ω', 'ῴ': 'ω', 'ῶ': 'ω', 'ῷ': 'ω',
    'ῤ': 'ρ', 'ῥ': 'ρ',
    // Uppercase → lowercase plain
    'Ά': 'α', 'Έ': 'ε', 'Ή': 'η', 'Ί': 'ι', 'Ό': 'ο', 'Ύ': 'υ', 'Ώ': 'ω',
    'Ϊ': 'ι', 'Ϋ': 'υ',
    'Ἀ': 'α',
    'Ἁ': 'α',
    'Ἂ': 'α',
    'Ἃ': 'α',
    'Ἄ': 'α',
    'Ἅ': 'α',
    'Ἆ': 'α',
    'Ἇ': 'α',
    'Ἐ': 'ε', 'Ἑ': 'ε', 'Ἒ': 'ε', 'Ἓ': 'ε', 'Ἔ': 'ε', 'Ἕ': 'ε',
    'Ἠ': 'η',
    'Ἡ': 'η',
    'Ἢ': 'η',
    'Ἣ': 'η',
    'Ἤ': 'η',
    'Ἥ': 'η',
    'Ἦ': 'η',
    'Ἧ': 'η',
    'Ἰ': 'ι',
    'Ἱ': 'ι',
    'Ἲ': 'ι',
    'Ἳ': 'ι',
    'Ἴ': 'ι',
    'Ἵ': 'ι',
    'Ἶ': 'ι',
    'Ἷ': 'ι',
    'Ὀ': 'ο', 'Ὁ': 'ο', 'Ὂ': 'ο', 'Ὃ': 'ο', 'Ὄ': 'ο', 'Ὅ': 'ο',
    'Ὑ': 'υ', 'Ὓ': 'υ', 'Ὕ': 'υ', 'Ὗ': 'υ',
    'Ὠ': 'ω',
    'Ὡ': 'ω',
    'Ὢ': 'ω',
    'Ὣ': 'ω',
    'Ὤ': 'ω',
    'Ὥ': 'ω',
    'Ὦ': 'ω',
    'Ὧ': 'ω',
    'Ῥ': 'ρ',
  };

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns a canonical, diacritic-free, lowercase version of [text].
  ///
  /// Safe to call on any string — returns the input unchanged if it contains
  /// neither Arabic nor Greek characters.
  static String normalize(String text) {
    if (text.isEmpty) return '';

    // 1. Lowercase (handles Latin + most Greek uppercase)
    var s = text.toLowerCase();

    // 2. Strip Arabic diacritics / tashkeel
    s = s.replaceAll(_arDiacritics, '');

    // 3. Normalize Arabic letter variants
    s = s.replaceAll(_arAlef, 'ا');
    s = s.replaceAll(_arYa, 'ي');
    s = s.replaceAll(_arWaw, 'و');
    s = s.replaceAll(_arYaHamza, 'ي');

    // 4. Normalize Greek accented characters
    s = s.splitMapJoin('', onNonMatch: (ch) => _greekMap[ch] ?? ch);

    // 5. Collapse extra whitespace
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    return s;
  }

  /// Returns true if [haystack] contains [query] after normalization.
  ///
  /// Always returns true when [query] is empty.
  static bool contains(String haystack, String query) {
    if (query.isEmpty) return true;
    return normalize(haystack).contains(normalize(query));
  }

  /// Convenience: normalizes [query] once and tests multiple [haystacks].
  ///
  /// Returns true if any haystack matches.
  static bool anyContains(Iterable<String> haystacks, String query) {
    if (query.isEmpty) return true;
    final q = normalize(query);
    return haystacks.any((h) => normalize(h).contains(q));
  }
}
