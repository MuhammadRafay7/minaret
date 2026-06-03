import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:minaret/core/theme.dart';
import 'package:minaret/core/locale_text.dart';
import 'package:minaret/core/secure_http_client.dart';
import 'package:minaret/widgets/atelier_layout.dart';
import 'package:minaret/widgets/offline_banner.dart';
import 'package:minaret/widgets/app_loading_indicator.dart';
import 'package:minaret/services/offline_cache_service.dart';

const String _editionsUrl =
    'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions.min.json';

const List<Map<String, String>> _canonicalBooks = [
  {'id': 'bukhari', 'author': 'Imam Bukhari'},
  {'id': 'muslim', 'author': 'Imam Muslim'},
  {'id': 'tirmidhi', 'author': 'Imam Tirmidhi'},
  {'id': 'abudawud', 'author': 'Abu Dawood'},
  {'id': 'nasai', 'author': "Imam An-Nasa'i"},
  {'id': 'ibnmajah', 'author': 'Ibn Majah'},
];

const Map<String, Map<String, String>> _bookArabicNames = {
  'bukhari': {'ar': 'صحيح البخاري', 'en': 'Sahih al-Bukhari'},
  'muslim': {'ar': 'صحيح مسلم', 'en': 'Sahih Muslim'},
  'tirmidhi': {'ar': 'جامع الترمذي', 'en': 'Jami at-Tirmidhi'},
  'abudawud': {'ar': 'سنن أبي داود', 'en': 'Sunan Abi Dawud'},
  'nasai': {'ar': 'سنن النسائي', 'en': "Sunan an-Nasa'i"},
  'ibnmajah': {'ar': 'سنن ابن ماجه', 'en': 'Sunan Ibn Majah'},
};

class _HEdition {
  final String editionId;
  final String language; // e.g. "English"
  final bool rtl;
  const _HEdition(this.editionId, this.language, this.rtl);
  bool get isArabic => language.toLowerCase() == 'arabic';
}

class _HBook {
  final String id;
  final String arabicName;
  final String englishName;
  final String author;
  final _HEdition? arabicEdition;
  final List<_HEdition> editions;
  const _HBook({
    required this.id,
    required this.arabicName,
    required this.englishName,
    required this.author,
    required this.arabicEdition,
    required this.editions,
  });
}

/// Robustly parse a hadith number (the API sometimes types it as a string).
int? _hnum(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');

Future<String> _httpGet(String url) async {
  final cacheKey = url.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
  final cached = await OfflineCacheService.getJson(cacheKey);
  if (cached != null) return cached;
  final dio = SecureHttpClient.createTrustedClient('cdn.jsdelivr.net');
  final res = await dio.get(url);
  if (res.statusCode == 200) {
    final data = res.data is String ? res.data as String : json.encode(res.data);
    await OfflineCacheService.setJson(cacheKey, data);
    return data;
  }
  throw Exception('HTTP ${res.statusCode}');
}

/// Builds a [_HBook] for a canonical book from the editions catalog json.
_HBook? _buildBook(String id, Map<String, dynamic>? bookJson, String author) {
  if (bookJson == null) return null;
  final collection = (bookJson['collection'] as List).cast<Map<String, dynamic>>();
  final seen = <String>{};
  final editions = <_HEdition>[];
  for (final e in collection) {
    final lang = (e['language'] ?? 'Unknown').toString();
    if (seen.contains(lang)) continue;
    seen.add(lang);
    editions.add(_HEdition(
      e['name'] as String,
      lang,
      (e['direction'] ?? 'ltr').toString() == 'rtl',
    ));
  }
  if (editions.isEmpty) return null;
  // English first, Arabic last so the reader opens on a translation.
  editions.sort((a, b) {
    int rank(_HEdition e) => e.language == 'English'
        ? 0
        : e.isArabic
            ? 2
            : 1;
    return rank(a).compareTo(rank(b));
  });
  return _HBook(
    id: id,
    arabicName: _bookArabicNames[id]?['ar'] ?? bookJson['name'] as String,
    englishName: _bookArabicNames[id]?['en'] ?? bookJson['name'] as String,
    author: author,
    arabicEdition: editions.where((e) => e.isArabic).isNotEmpty
        ? editions.firstWhere((e) => e.isArabic)
        : null,
    editions: editions,
  );
}

/// Public deep-link: open a collection's reader at a specific hadith number
/// (used by the home daily-hadith card).
Future<void> openHadithByNumber(
  BuildContext context, {
  required String bookId,
  required int hadithNumber,
}) async {
  try {
    final raw = await _httpGet(_editionsUrl);
    final all = json.decode(raw) as Map<String, dynamic>;
    final author = _canonicalBooks.firstWhere(
      (b) => b['id'] == bookId,
      orElse: () => {'author': ''},
    )['author']!;
    final book = _buildBook(bookId, all[bookId] as Map<String, dynamic>?, author);
    if (book == null || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _HadithReaderPage(book: book, initialHadithNumber: hadithNumber),
      ),
    );
  } catch (_) {/* ignore — card stays on home */}
}

// ───────────────────────────────────────────────────────────────────────────
// Book carousel — swipe through collections, tap to open the reader.
// ───────────────────────────────────────────────────────────────────────────
class HadithBookCarouselPage extends StatefulWidget {
  const HadithBookCarouselPage({super.key});

  @override
  State<HadithBookCarouselPage> createState() => _HadithBookCarouselPageState();
}

class _HadithBookCarouselPageState extends State<HadithBookCarouselPage> {
  final PageController _controller = PageController(viewportFraction: 0.84);
  List<_HBook> _books = [];
  bool _loading = true;
  String? _error;
  int _index = 0;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _t({required String en, required String ar, required String ur, required String ru}) =>
      context.localText(en: en, ar: ar, ur: ur, ru: ru);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await _httpGet(_editionsUrl);
      final all = json.decode(raw) as Map<String, dynamic>;
      final books = <_HBook>[];
      for (final canon in _canonicalBooks) {
        final book = _buildBook(
            canon['id']!, all[canon['id']] as Map<String, dynamic>?, canon['author']!);
        if (book != null) books.add(book);
      }
      if (!mounted) return;
      setState(() {
        _books = books;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _open(_HBook book) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _HadithReaderPage(book: book)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AtelierLayout(
      child: SafeArea(
        child: Column(
          children: [
            const OfflineBanner(),
            _header(),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 16, 25, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t(en: 'HADITH', ar: 'الحديث', ur: 'حدیث', ru: 'ХАДИС'),
            style: GoogleFonts.cairo(
              fontSize: 10,
              letterSpacing: 3,
              color: MinaretTheme.gold,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _t(
              en: 'Choose a collection',
              ar: 'اختر مجموعة',
              ur: 'مجموعہ منتخب کریں',
              ru: 'Выберите сборник',
            ),
            style: MinaretTheme.heading.copyWith(fontSize: 22, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: AppLoadingIndicator(size: 20, strokeWidth: 1.5));
    }
    if (_error != null || _books.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 30, color: MinaretTheme.gold.withValues(alpha: 0.35)),
            const SizedBox(height: 14),
            Text(
              _t(
                en: 'Could not load collections',
                ar: 'تعذّر تحميل المجموعات',
                ur: 'مجموعے لوڈ نہیں ہوئے',
                ru: 'Не удалось загрузить',
              ),
              style: GoogleFonts.montserrat(fontSize: 11, color: MinaretTheme.slate),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _load,
              style: OutlinedButton.styleFrom(
                foregroundColor: MinaretTheme.gold,
                side: const BorderSide(color: MinaretTheme.gold),
              ),
              child: Text(_t(en: 'RETRY', ar: 'إعادة', ur: 'دوبارہ', ru: 'ПОВТОР')),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: _books.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => _bookCard(_books[i], i == _index, i),
          ),
        ),
        _dots(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _dots() => Wrap(
        spacing: 6,
        alignment: WrapAlignment.center,
        children: List.generate(_books.length, (i) {
          final active = i == _index;
          return Container(
            width: active ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: active
                  ? MinaretTheme.gold
                  : MinaretTheme.gold.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      );

  Widget _bookCard(_HBook book, bool active, int i) {
    return AnimatedScale(
      scale: active ? 1.0 : 0.92,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: active ? 1.0 : 0.5,
        duration: const Duration(milliseconds: 260),
        child: GestureDetector(
          onTap: () => _open(book),
          child: Container(
            margin: const EdgeInsets.fromLTRB(8, 12, 8, 16),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _isDark
                    ? [
                        MinaretTheme.gold.withValues(alpha: active ? 0.06 : 0.02),
                        Colors.white.withValues(alpha: 0.02),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.9),
                        Colors.white.withValues(alpha: 0.6),
                      ],
              ),
              borderRadius: BorderRadius.circular(MinaretTheme.cardRadius),
              border: Border.all(
                color: active
                    ? MinaretTheme.gold.withValues(alpha: _isDark ? 0.35 : 0.3)
                    : (_isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : MinaretTheme.gold.withValues(alpha: 0.1)),
                width: active ? 1.2 : 0.8,
              ),
              boxShadow: active
                  ? (_isDark ? MinaretTheme.goldShadow : MinaretTheme.cardShadow)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  (i + 1).toString().padLeft(2, '0'),
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 12,
                    color: MinaretTheme.gold.withValues(alpha: 0.7),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 24),
                _flourish(),
                const SizedBox(height: 20),
                Text(
                  book.arabicName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.amiriQuran(
                    fontSize: 34,
                    color: _isDark ? MinaretTheme.goldSoft : MinaretTheme.gold,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  book.englishName.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  book.author.toUpperCase(),
                  style: GoogleFonts.cairo(
                    fontSize: 9,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                    color: MinaretTheme.slate,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '${book.editions.length} ${_t(en: 'LANGUAGES', ar: 'لغات', ur: 'زبانیں', ru: 'ЯЗЫКОВ')}',
                  style: GoogleFonts.cairo(
                    fontSize: 8.5,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                    color: MinaretTheme.slate.withValues(alpha: 0.8),
                  ),
                ),
                const Spacer(),
                _openButton(book),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _flourish() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
              width: 30,
              height: 1,
              color: MinaretTheme.gold.withValues(alpha: 0.3)),
          const SizedBox(width: 10),
          Transform.rotate(
            angle: 0.785398,
            child: Container(
                width: 6, height: 6, color: MinaretTheme.gold.withValues(alpha: 0.6)),
          ),
          const SizedBox(width: 10),
          Container(
              width: 30,
              height: 1,
              color: MinaretTheme.gold.withValues(alpha: 0.3)),
        ],
      );

  Widget _openButton(_HBook book) {
    return Material(
      color: MinaretTheme.emerald,
      borderRadius: BorderRadius.circular(MinaretTheme.buttonRadius),
      child: InkWell(
        onTap: () => _open(book),
        borderRadius: BorderRadius.circular(MinaretTheme.buttonRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _t(en: 'READ', ar: 'اقرأ', ur: 'پڑھیں', ru: 'ЧИТАТЬ'),
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, size: 15, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Reader — swipe = language; shows the current section's hadiths
// (Arabic + that language's translation). Section picker at top.
// ───────────────────────────────────────────────────────────────────────────
class _HadithItem {
  final int number;
  final String arabic;
  final String? translation;
  final int refBook;
  final int refHadith;
  final String? grade;
  const _HadithItem(this.number, this.arabic, this.translation, this.refBook,
      this.refHadith, this.grade);
}

class _SectionData {
  final String name;
  final List<_HadithItem> items;
  const _SectionData(this.name, this.items);
}

class _HadithReaderPage extends StatefulWidget {
  final _HBook book;
  final int? initialHadithNumber;
  const _HadithReaderPage({required this.book, this.initialHadithNumber});

  @override
  State<_HadithReaderPage> createState() => __HadithReaderPageState();
}

class __HadithReaderPageState extends State<_HadithReaderPage> {
  PageController? _controller;
  final TextEditingController _searchController = TextEditingController();

  // Arabic source (whole book) → sections + grouped hadiths.
  final Map<int, List<dynamic>> _arabicBySection = {};
  final Map<int, String> _sectionNames = {};
  List<int> _sectionIds = [];

  // Translation section cache: 'editionId|section' -> {hadithNumber: text}.
  final Map<String, Map<int, String>> _trCache = {};
  // Built reading data: 'editionId|section' -> _SectionData.
  final Map<String, _SectionData> _mem = {};

  int _section = 0;
  int _langIndex = 0;
  bool _loading = true;
  String? _error;
  int? _highlight; // hadith number to highlight + scroll to

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  List<_HEdition> get _deck => widget.book.editions;

  /// The section that contains the given hadith number, or null.
  int? _sectionOf(int hadithNumber) {
    for (final s in _sectionIds) {
      final list = _arabicBySection[s] ?? [];
      if (list.any((h) => _hnum(h['hadithnumber']) == hadithNumber)) {
        return s;
      }
    }
    return null;
  }

  void _jumpToHadith(int number) {
    final sec = _sectionOf(number);
    if (sec == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t(
          en: 'Hadith $number not found in this collection',
          ar: 'لم يتم العثور على الحديث $number',
          ur: 'حدیث $number نہیں ملی',
          ru: 'Хадис $number не найден',
        )),
      ));
      return;
    }
    setState(() {
      _section = sec;
      _highlight = number;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadBook();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _t({required String en, required String ar, required String ur, required String ru}) =>
      context.localText(en: en, ar: ar, ur: ur, ru: ru);

  Future<void> _loadBook() async {
    final ara = widget.book.arabicEdition;
    if (ara == null) {
      setState(() {
        _error = 'No Arabic source';
        _loading = false;
      });
      return;
    }
    try {
      final raw = await _httpGet(
          'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/${ara.editionId}.min.json');
      final data = json.decode(raw) as Map<String, dynamic>;
      final sections = (data['metadata']?['sections'] ?? {}) as Map;
      sections.forEach((k, v) {
        final id = int.tryParse(k.toString());
        if (id != null) _sectionNames[id] = v.toString();
      });
      for (final h in (data['hadiths'] as List)) {
        final sec = (h['reference']?['book'] as num?)?.toInt() ?? 0;
        _arabicBySection.putIfAbsent(sec, () => []).add(h);
      }
      // Sections that actually have hadiths, in order.
      _sectionIds = _arabicBySection.keys.toList()..sort();
      _sectionIds.removeWhere((s) => (_arabicBySection[s] ?? []).isEmpty);
      _section = _sectionIds.isNotEmpty ? _sectionIds.first : 0;
      // Deep-link: open straight to the requested hadith's chapter.
      if (widget.initialHadithNumber != null) {
        final sec = _sectionOf(widget.initialHadithNumber!);
        if (sec != null) {
          _section = sec;
          _highlight = widget.initialHadithNumber;
        }
      }
      if (!mounted) return;
      setState(() {
        _controller = PageController(initialPage: _langIndex);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<Map<int, String>> _translationFor(_HEdition ed, int section) async {
    final key = '${ed.editionId}|$section';
    if (_trCache.containsKey(key)) return _trCache[key]!;
    final raw = await _httpGet(
        'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/${ed.editionId}/sections/$section.min.json');
    final data = json.decode(raw) as Map<String, dynamic>;
    final map = <int, String>{};
    for (final h in (data['hadiths'] as List)) {
      final n = _hnum(h['hadithnumber']);
      if (n != null) map[n] = (h['text'] ?? '').toString();
    }
    _trCache[key] = map;
    return map;
  }

  Future<_SectionData> _load(_HEdition ed, int section) async {
    final key = '${ed.editionId}|$section';
    if (_mem.containsKey(key)) return _mem[key]!;
    final arabic = _arabicBySection[section] ?? [];
    Map<int, String>? tr;
    if (!ed.isArabic) tr = await _translationFor(ed, section);
    final items = <_HadithItem>[];
    for (final h in arabic) {
      final n = _hnum(h['hadithnumber']) ?? 0;
      final grades = h['grades'] as List?;
      items.add(_HadithItem(
        n,
        (h['text'] ?? '').toString().trim(),
        tr?[n],
        (h['reference']?['book'] as num?)?.toInt() ?? section,
        (h['reference']?['hadith'] as num?)?.toInt() ?? 0,
        (grades != null && grades.isNotEmpty)
            ? (grades.first['grade'] ?? '').toString()
            : null,
      ));
    }
    final result = _SectionData(_sectionNames[section] ?? '', items);
    _mem[key] = result;
    return result;
  }

  void _onSectionChanged(int section) {
    // Clear any deep-link/search highlight — it belongs to the old chapter.
    setState(() {
      _section = section;
      _highlight = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AtelierLayout(
      child: SafeArea(
        child: Column(
          children: [
            const OfflineBanner(),
            _topBar(),
            Expanded(child: _body()),
            if (!_loading && _error == null) _dots(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldFill = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.03);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, size: 16),
          ),
          Expanded(
            child: InkWell(
              onTap: _sectionIds.isEmpty ? null : _openSectionPicker,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.book.englishName.toUpperCase(),
                      style: GoogleFonts.cairo(
                        fontSize: 8.5,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w700,
                        color: MinaretTheme.slate,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _sectionNames[_section] ??
                                '${_t(en: 'Section', ar: 'باب', ur: 'باب', ru: 'Раздел')} $_section',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.expand_more_rounded,
                            size: 18, color: MinaretTheme.slate),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: 120,
            height: 40,
            child: TextField(
              controller: _searchController,
              keyboardType: TextInputType.number,
              cursorColor: MinaretTheme.gold,
              style: GoogleFonts.ibmPlexMono(fontSize: 13),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: _t(en: 'Find', ar: 'ابحث', ur: 'تلاش', ru: 'Найти'),
                hintStyle: GoogleFonts.lato(
                    fontSize: 12,
                    color: MinaretTheme.slate.withValues(alpha: 0.6)),
                prefixIcon: Icon(Icons.search_rounded,
                    size: 16, color: MinaretTheme.gold.withValues(alpha: 0.6)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? InkWell(
                        onTap: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        child: Icon(Icons.close_rounded,
                            size: 16,
                            color: MinaretTheme.gold.withValues(alpha: 0.6)),
                      )
                    : null,
                filled: true,
                fillColor: fieldFill,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: MinaretTheme.dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: MinaretTheme.gold.withValues(alpha: 0.5)),
                ),
              ),
              onChanged: (value) => setState(() {}),
              onSubmitted: (value) {
                final n = int.tryParse(value.trim());
                if (n != null) {
                  _jumpToHadith(n);
                  _searchController.clear();
                  setState(() {});
                }
              },
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }


  Widget _body() {
    if (_loading) {
      return const Center(child: AppLoadingIndicator(size: 20, strokeWidth: 1.5));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 30, color: MinaretTheme.gold.withValues(alpha: 0.35)),
              const SizedBox(height: 14),
              Text(
                _t(
                  en: 'Could not load this collection',
                  ar: 'تعذّر تحميل المجموعة',
                  ur: 'مجموعہ لوڈ نہیں ہوا',
                  ru: 'Не удалось загрузить',
                ),
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(fontSize: 11, color: MinaretTheme.slate),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  setState(() => _loading = true);
                  _loadBook();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: MinaretTheme.gold,
                  side: const BorderSide(color: MinaretTheme.gold),
                ),
                child: Text(_t(en: 'RETRY', ar: 'إعادة', ur: 'دوبارہ', ru: 'ПОВТОР')),
              ),
            ],
          ),
        ),
      );
    }
    return PageView.builder(
      controller: _controller,
      itemCount: _deck.length,
      onPageChanged: (i) => setState(() => _langIndex = i),
      itemBuilder: (context, i) => _LangCard(
        key: ValueKey('${_section}_${_deck[i].editionId}'),
        edition: _deck[i],
        section: _section,
        loader: _load,
        active: i == _langIndex,
        isDark: _isDark,
        highlightNumber: _highlight,
      ),
    );
  }

  Widget _dots() => Wrap(
        spacing: 6,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: List.generate(_deck.length, (i) {
          final active = i == _langIndex;
          return Container(
            width: active ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: active
                  ? MinaretTheme.gold
                  : MinaretTheme.gold.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      );

  void _openSectionPicker() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _isDark ? MinaretTheme.darkSurface : Colors.white,
      builder: (ctx) => _SectionPickerSheet(
        sectionIds: _sectionIds,
        names: _sectionNames,
        counts: {for (final s in _sectionIds) s: (_arabicBySection[s] ?? []).length},
        current: _section,
      ),
    );
    if (picked != null && picked != _section) _onSectionChanged(picked);
  }
}

class _LangCard extends StatefulWidget {
  final _HEdition edition;
  final int section;
  final Future<_SectionData> Function(_HEdition ed, int section) loader;
  final bool active;
  final bool isDark;
  final int? highlightNumber;

  const _LangCard({
    super.key,
    required this.edition,
    required this.section,
    required this.loader,
    required this.active,
    required this.isDark,
    required this.highlightNumber,
  });

  @override
  State<_LangCard> createState() => _LangCardState();
}

class _LangCardState extends State<_LangCard> {
  final GlobalKey _highlightKey = GlobalKey();
  final ScrollController _scroll = ScrollController();
  int? _scrolledFor;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls to the highlighted hadith. Because the list is lazy and tiles vary
  /// wildly in height, a single index-fraction jump rarely lands the target in
  /// the build window — so [_settleScroll] sweeps outward from the estimate,
  /// rebuilding more tiles each pass, until the highlighted tile is laid out and
  /// can be animated precisely into view.
  void _maybeScrollToHighlight(int hlIndex, int total) {
    if (!widget.active || widget.highlightNumber == null || hlIndex < 0) return;
    if (_scrolledFor == widget.highlightNumber) return;
    _scrolledFor = widget.highlightNumber;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _settleScroll(hlIndex, total, 0));
  }

  void _settleScroll(int hlIndex, int total, int attempt) {
    if (!mounted || !_scroll.hasClients) return;
    // Target tile is built → centre it and stop.
    final ctx = _highlightKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.15,
      );
      return;
    }
    if (attempt >= 14) return; // give up gracefully rather than spin forever
    // Estimate the offset from the index fraction (+1 for the header row), then
    // sweep alternately below/above it by growing steps so an off estimate
    // still drags the target tile into the lazy build window within a few tries.
    final max = _scroll.position.maxScrollExtent;
    final base = ((hlIndex + 1) / (total + 1)) * max;
    final viewport = _scroll.position.viewportDimension;
    final step = ((attempt + 1) ~/ 2) * viewport * 0.8;
    final dir = attempt.isEven ? 1 : -1;
    _scroll.jumpTo((base + dir * step).clamp(0.0, max));
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _settleScroll(hlIndex, total, attempt + 1));
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final isDark = widget.isDark;
    return AnimatedScale(
      scale: active ? 1.0 : 0.93,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: active ? 1.0 : 0.45,
        duration: const Duration(milliseconds: 260),
        child: Container(
          margin: const EdgeInsets.fromLTRB(7, 6, 7, 8),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      MinaretTheme.gold.withValues(alpha: active ? 0.06 : 0.02),
                      Colors.white.withValues(alpha: 0.02),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.9),
                      Colors.white.withValues(alpha: 0.6),
                    ],
            ),
            borderRadius: BorderRadius.circular(MinaretTheme.cardRadius),
            border: Border.all(
              color: active
                  ? MinaretTheme.gold.withValues(alpha: isDark ? 0.35 : 0.3)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : MinaretTheme.gold.withValues(alpha: 0.1)),
              width: active ? 1.2 : 0.8,
            ),
            boxShadow: active
                ? (isDark ? MinaretTheme.goldShadow : MinaretTheme.cardShadow)
                : null,
          ),
          child: Column(
            children: [
              Expanded(
                child: FutureBuilder<_SectionData>(
                  future: widget.loader(widget.edition, widget.section),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: AppLoadingIndicator(size: 18, strokeWidth: 1.5));
                    }
                    if (snap.hasError || !snap.hasData) {
                      return Center(
                        child: Text(
                          context.localText(
                            en: 'Translation unavailable',
                            ar: 'الترجمة غير متاحة',
                            ur: 'ترجمہ دستیاب نہیں',
                            ru: 'Перевод недоступен',
                          ),
                          style: GoogleFonts.montserrat(
                              fontSize: 11, color: MinaretTheme.slate),
                        ),
                      );
                    }
                    final data = snap.data!;
                    final hlIndex = widget.highlightNumber == null
                        ? -1
                        : data.items
                            .indexWhere((it) => it.number == widget.highlightNumber);
                    _maybeScrollToHighlight(hlIndex, data.items.length);
                    return ListView.builder(
                      controller: _scroll,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      itemCount: data.items.length + 1,
                      itemBuilder: (context, i) {
                        if (i == 0) return _sectionHeader(data, context);
                        final item = data.items[i - 1];
                        final hl = item.number == widget.highlightNumber;
                        return _HadithTile(
                          key: hl ? _highlightKey : null,
                          item: item,
                          edition: widget.edition,
                          highlighted: hl,
                        );
                      },
                    );
                  },
                ),
              ),
              _footer(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(_SectionData data, BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                    height: 1, color: MinaretTheme.gold.withValues(alpha: 0.25)),
              ),
              const SizedBox(width: 10),
              Transform.rotate(
                angle: 0.785398,
                child: Container(
                    width: 6,
                    height: 6,
                    color: MinaretTheme.gold.withValues(alpha: 0.6)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                    height: 1, color: MinaretTheme.gold.withValues(alpha: 0.25)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            data.name,
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${data.items.length} ${context.localText(en: 'HADITH', ar: 'حديث', ur: 'احادیث', ru: 'ХАДИСОВ')}',
            style: GoogleFonts.cairo(
              fontSize: 8.5,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
              color: MinaretTheme.slate,
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: MinaretTheme.dividerColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
              widget.edition.isArabic
                  ? Icons.menu_book_rounded
                  : Icons.translate_rounded,
              size: 15,
              color: MinaretTheme.gold),
          const SizedBox(width: 10),
          Text(
            widget.edition.language,
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HadithTile extends StatelessWidget {
  final _HadithItem item;
  final _HEdition edition;
  final bool highlighted;
  const _HadithTile(
      {super.key, required this.item, required this.edition, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark ? Colors.white70 : MinaretTheme.slate;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
      decoration: BoxDecoration(
        color: highlighted ? MinaretTheme.gold.withValues(alpha: 0.07) : null,
        border: Border(
          bottom: BorderSide(color: MinaretTheme.dividerColor, width: 0.5),
          left: highlighted
              ? const BorderSide(color: MinaretTheme.gold, width: 2.5)
              : BorderSide.none,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Reference pill.
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: MinaretTheme.gold.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: MinaretTheme.gold.withValues(alpha: 0.25),
                      width: 0.7),
                ),
                child: Text(
                  '${context.localText(en: 'Hadith', ar: 'حديث', ur: 'حدیث', ru: 'Хадис')} ${item.number}',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 9.5,
                    color: MinaretTheme.gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (item.grade != null && item.grade!.isNotEmpty)
                Text(
                  item.grade!.toUpperCase(),
                  style: GoogleFonts.cairo(
                    fontSize: 8,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                    color: MinaretTheme.emerald,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          // Arabic.
          Text(
            item.arabic,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: GoogleFonts.amiriQuran(
              fontSize: 21,
              height: 2.1,
              color: ink.withValues(alpha: 0.92),
            ),
          ),
          if (item.translation != null && item.translation!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              item.translation!,
              textAlign: edition.rtl ? TextAlign.right : TextAlign.left,
              textDirection: edition.rtl ? TextDirection.rtl : TextDirection.ltr,
              style: edition.rtl
                  ? GoogleFonts.notoNaskhArabic(
                      fontSize: 14.5, height: 2.0, color: secondary)
                  : GoogleFonts.lato(fontSize: 14.5, height: 1.8, color: secondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionPickerSheet extends StatefulWidget {
  final List<int> sectionIds;
  final Map<int, String> names;
  final Map<int, int> counts;
  final int current;
  const _SectionPickerSheet({
    required this.sectionIds,
    required this.names,
    required this.counts,
    required this.current,
  });

  @override
  State<_SectionPickerSheet> createState() => _SectionPickerSheetState();
}

class _SectionPickerSheetState extends State<_SectionPickerSheet> {
  final _search = TextEditingController();
  late List<int> _filtered = widget.sectionIds;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    q = q.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.sectionIds
          : widget.sectionIds
              .where((s) =>
                  (widget.names[s] ?? '').toLowerCase().contains(q) ||
                  s.toString().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldFill = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.03);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: MinaretTheme.slate.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
              child: Row(
                children: [
                  Text(
                    context.localText(
                        en: 'CHAPTERS',
                        ar: 'الأبواب',
                        ur: 'ابواب',
                        ru: 'ГЛАВЫ'),
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w800,
                      color: MinaretTheme.gold,
                    ),
                  ),
                  const Spacer(),
                  Text('${_filtered.length}',
                      style: GoogleFonts.ibmPlexMono(
                          fontSize: 10, color: MinaretTheme.slate)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
              child: TextField(
                controller: _search,
                onChanged: _onSearch,
                cursorColor: MinaretTheme.gold,
                style: GoogleFonts.lato(fontSize: 14),
                decoration: InputDecoration(
                  hintText: context.localText(
                      en: 'Search chapter…',
                      ar: 'ابحث عن باب…',
                      ur: 'باب تلاش کریں…',
                      ru: 'Поиск главы…'),
                  hintStyle: GoogleFonts.lato(
                      fontSize: 13,
                      color: MinaretTheme.slate.withValues(alpha: 0.7)),
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 18, color: MinaretTheme.gold.withValues(alpha: 0.6)),
                  filled: true,
                  fillColor: fieldFill,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: MinaretTheme.dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: MinaretTheme.gold.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: _filtered.length,
                itemBuilder: (context, i) {
                  final s = _filtered[i];
                  final sel = s == widget.current;
                  return InkWell(
                    onTap: () => Navigator.pop(context, s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 13),
                      decoration: BoxDecoration(
                        color:
                            sel ? MinaretTheme.gold.withValues(alpha: 0.07) : null,
                        border: Border(
                          bottom: BorderSide(
                              color: MinaretTheme.dividerColor, width: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 34,
                            child: Text(
                              s.toString(),
                              style: GoogleFonts.ibmPlexMono(
                                fontSize: 11,
                                color: MinaretTheme.gold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              widget.names[s] ?? 'Chapter $s',
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                fontWeight:
                                    sel ? FontWeight.w800 : FontWeight.w600,
                                color: sel ? MinaretTheme.gold : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${widget.counts[s] ?? 0}',
                            style: GoogleFonts.cairo(
                              fontSize: 9,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w600,
                              color: MinaretTheme.slate,
                            ),
                          ),
                          if (sel) ...[
                            const SizedBox(width: 10),
                            const Icon(Icons.check_rounded,
                                size: 16, color: MinaretTheme.gold),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
