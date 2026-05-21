import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:minaret/l10n/generated/app_localizations.dart';
import 'package:minaret/services/offline_cache_service.dart';
import '../../core/theme.dart';
import '../../core/secure_http_client.dart';
import '../../widgets/atelier_layout.dart';
import 'hadith_chapters_page.dart';

class HadithPage extends StatefulWidget {
  const HadithPage({super.key});

  @override
  State<HadithPage> createState() => _HadithPageState();
}

class _HadithPageState extends State<HadithPage> {
  static const List<Map<String, String>> _canonicalBooks = [
    {'id': 'bukhari', 'author': 'Imam Bukhari'},
    {'id': 'muslim', 'author': 'Imam Muslim'},
    {'id': 'tirmidhi', 'author': 'Imam Tirmidhi'},
    {'id': 'abudawud', 'author': 'Abu Dawood'},
    {'id': 'nasai', 'author': "Imam An-Nasa'i"},
    {'id': 'ibnmajah', 'author': 'Ibn Majah'},
  ];

  static const String _editionsUrl =
      'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions.min.json';
  static const String _editionsUrlFallback =
      'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions.json';

  bool _loading = true;
  String? _error;

  Map<String, Map<String, dynamic>> _bookData = {};
  List<String> _filteredBookIds = [];
  final Map<String, String> _selectedEdition = {};
  final TextEditingController _searchController = TextEditingController();

  static const Set<String> _completeLanguages = {'English', 'Arabic'};
  static const Map<String, Map<String, String>> _bookNamesByLocale = {
    'bukhari': {
      'en': 'Sahih al-Bukhari',
      'ar': 'صحيح البخاري',
      'ur': 'صحیح البخاری',
      'ru': 'Сахих аль-Бухари',
    },
    'muslim': {
      'en': 'Sahih Muslim',
      'ar': 'صحيح مسلم',
      'ur': 'صحیح مسلم',
      'ru': 'Сахих Муслим',
    },
    'tirmidhi': {
      'en': 'Jami at-Tirmidhi',
      'ar': 'جامع الترمذي',
      'ur': 'جامع ترمذی',
      'ru': 'Джами ат-Тирмизи',
    },
    'abudawud': {
      'en': 'Sunan Abi Dawud',
      'ar': 'سنن أبي داود',
      'ur': 'سنن ابی داؤد',
      'ru': 'Сунан Абу Дауд',
    },
    'nasai': {
      'en': "Sunan an-Nasa'i",
      'ar': 'سنن النسائي',
      'ur': 'سنن نسائی',
      'ru': 'Сунан ан-Насаи',
    },
    'ibnmajah': {
      'en': 'Sunan Ibn Majah',
      'ar': 'سنن ابن ماجه',
      'ur': 'سنن ابن ماجہ',
      'ru': 'Сунан Ибн Маджа',
    },
  };

  // ── Theme helpers ────────────────────────────────────────────────────────
  Color get textPrimary => Theme.of(context).colorScheme.onSurface;
  Color get textSecondary => Theme.of(context).brightness == Brightness.dark
      ? Colors.white70
      : MinaretTheme.slate;
  Color get surface => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF151B24)
      : MinaretTheme.surface;

  @override
  void initState() {
    super.initState();
    _fetchEditions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchEditions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      const cacheKey = 'hadith_editions_catalog';
      String? raw;

      // 1. Try offline cache first
      try {
        final cachedRaw = await OfflineCacheService.getJson(cacheKey);
        if (cachedRaw != null && cachedRaw.isNotEmpty) {
          raw = cachedRaw;
        }
      } catch (e) {
        debugPrint("Offline cache check failed: $e");
      }

      // 2. Fetch from network if no cached data
      if (raw == null) {
        raw = await _get(_editionsUrl, fallback: _editionsUrlFallback);
        // Cache the response for offline use
        try {
          await OfflineCacheService.setJson(cacheKey, raw);
        } catch (e) {
          debugPrint("Failed to cache hadith editions: $e");
        }
      }

      final Map<String, dynamic> all = json.decode(raw);
      final result = <String, Map<String, dynamic>>{};

      for (final canon in _canonicalBooks) {
        final id = canon['id']!;
        final bookJson = all[id] as Map<String, dynamic>?;
        if (bookJson == null) continue;

        final collection = (bookJson['collection'] as List<dynamic>)
            .cast<Map<String, dynamic>>();

        final seen = <String>{};
        final editions = <Map<String, String>>[];

        for (final e in collection) {
          final lang = e['language'] as String? ?? 'Unknown';
          if (seen.contains(lang)) continue;
          seen.add(lang);
          editions.add({
            'editionId': e['name'] as String,
            'language': lang,
            'direction': e['direction'] as String? ?? 'ltr',
            'has_sections': (e['has_sections'] ?? false).toString(),
          });
        }

        result[id] = {
          'displayName': bookJson['name'] as String,
          'author': canon['author']!,
          'editions': editions,
        };

        final engEdition = editions.firstWhere(
          (e) => e['language'] == 'English',
          orElse: () => editions.first,
        );
        _selectedEdition[id] = engEdition['editionId']!;
      }

      if (mounted) {
        setState(() {
          _bookData = result;
          _filteredBookIds = _canonicalBooks
              .map((b) => b['id']!)
              .where((id) => result.containsKey(id))
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<String> _get(String url, {String? fallback}) async {
    // Try to get from cache first
    final cacheKey = url.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final cachedData = await OfflineCacheService.getJson(cacheKey);
    if (cachedData != null) {
      debugPrint('📚 Using cached hadith data for $cacheKey');
      return cachedData;
    }

    final dio = SecureHttpClient.createTrustedClient('cdn.jsdelivr.net');
    try {
      final res = await dio.get(url);
      if (res.statusCode == 200) {
        final data = json.encode(res.data);
        // Cache the successful response
        await OfflineCacheService.setJson(cacheKey, data);
        return data;
      }
      throw Exception('HTTP ${res.statusCode}');
    } catch (e) {
      debugPrint('❌ Hadith API error: $e');
      
      // Try fallback URL
      if (fallback != null) {
        try {
          final res = await dio.get(fallback);
          if (res.statusCode == 200) {
            final data = json.encode(res.data);
            // Cache the fallback response
            await OfflineCacheService.setJson(cacheKey, data);
            return data;
          }
        } catch (fallbackError) {
          debugPrint('❌ Fallback also failed: $fallbackError');
        }
      }
      
      // Try to use any cached data as last resort
      final cachedData = await OfflineCacheService.getJson(cacheKey);
      if (cachedData != null) {
        debugPrint('📚 Using cached hadith data as fallback');
        return cachedData;
      }
      
      rethrow;
    }
  }

  void _filterBooks(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) {
      setState(() {
        _filteredBookIds = _canonicalBooks
            .map((b) => b['id']!)
            .where((id) => _bookData.containsKey(id))
            .toList();
      });
      return;
    }
    setState(() {
      _filteredBookIds = _canonicalBooks.map((b) => b['id']!).where((id) {
        if (!_bookData.containsKey(id)) return false;
        final book = _bookData[id]!;
        return (book['displayName'] as String).toLowerCase().contains(q) ||
            (book['author'] as String).toLowerCase().contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: AtelierLayout(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(l10n),
              _buildSearchField(l10n),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  String _tr({
    required String en,
    required String ar,
    required String ur,
    required String ru,
    String? fa,
    String? nl,
    String? zh,
  }) {
    final code = Localizations.localeOf(context).languageCode;
    switch (code) {
      case 'ar':
        return ar;
      case 'fa':
        return fa ?? en;
      case 'nl':
        return nl ?? en;
      case 'ur':
        return ur;
      case 'ru':
        return ru;
      case 'zh':
        return zh ?? en;
      default:
        return en;
    }
  }

  String _localizedBookName(String bookId, String fallback) {
    final code = Localizations.localeOf(context).languageCode;
    return _bookNamesByLocale[bookId]?[code] ?? fallback;
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 24, 25, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tr(en: 'HADITH', ar: 'الحديث', ur: 'حدیث', ru: 'ХАДИС'),
            style: GoogleFonts.montserrat(
              fontSize: 9,
              letterSpacing: 3,
              color: MinaretTheme.gold,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.hadithTitle.toUpperCase(),
            style: MinaretTheme.heading.copyWith(
              fontSize: 38,
              letterSpacing: 6,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _tr(
              en: 'Select a collection to read hadith',
              ar: 'اختر مجموعة لقراءة الحديث',
              ur: 'حدیث پڑھنے کے لیے مجموعہ منتخب کریں',
              ru: 'Выберите сборник для чтения хадисов',
            ),
            style: GoogleFonts.lato(
              fontSize: 13,
              color: textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _tr(
              en: 'Source: Hadith API canonical collections (Bukhari, Muslim, Tirmidhi, Abu Dawud, Nasai, Ibn Majah)',
              ar: 'المصدر: مجموعات API الحديث المعتمدة (البخاري، مسلم، الترمذي، أبو داود، النسائي، ابن ماجه)',
              ur: 'ماخذ: Hadith API کی مستند کتب (بخاری، مسلم، ترمذی، ابو داؤد، نسائی، ابن ماجہ)',
              ru: 'Источник: канонические сборники Hadith API (Бухари, Муслим, Тирмизи, Абу Дауд, Насаи, Ибн Маджа)',
            ),
            style: GoogleFonts.cairo(
              fontSize: 11,
              color: textSecondary.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 1,
            width: 30,
            color: MinaretTheme.gold.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 10, 25, 14),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: MinaretTheme.dividerColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _filterBooks,
                style: GoogleFonts.lato(fontSize: 15, color: textPrimary),
                cursorColor: MinaretTheme.gold,
                cursorWidth: 1,
                decoration: InputDecoration(
                  hintText: _tr(
                    en: 'Search collection or author...',
                    ar: 'ابحث في المجموعات أو المؤلف...',
                    ur: 'مجموعہ یا مصنف تلاش کریں...',
                    ru: 'Поиск по сборнику или автору...',
                  ),
                  hintStyle: GoogleFonts.lato(
                    color: textSecondary.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: MinaretTheme.gold.withValues(alpha: 0.5),
                    size: 18,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 20),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _searchController.text.isNotEmpty
                  ? GestureDetector(
                      key: const ValueKey('clear'),
                      onTap: () {
                        _searchController.clear();
                        _filterBooks('');
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: textSecondary.withValues(alpha: 0.6),
                        ),
                      ),
                    )
                  : const SizedBox(key: ValueKey('empty')),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: MinaretTheme.gold,
                strokeWidth: 1,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _tr(
                en: 'LOADING COLLECTIONS...',
                ar: 'جارٍ تحميل المجموعات...',
                ur: 'مجموعے لوڈ ہو رہے ہیں...',
                ru: 'ЗАГРУЗКА СБОРНИКОВ...',
              ),
              style: GoogleFonts.montserrat(
                fontSize: 8,
                letterSpacing: 2,
                color: textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _tr(
                en: 'FAILED TO LOAD COLLECTIONS',
                ar: 'فشل تحميل المجموعات',
                ur: 'مجموعے لوڈ نہیں ہو سکے',
                ru: 'НЕ УДАЛОСЬ ЗАГРУЗИТЬ СБОРНИКИ',
              ),
              style: GoogleFonts.montserrat(
                fontSize: 8,
                letterSpacing: 2,
                color: textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _fetchEditions,
              child: Text(
                _tr(
                  en: 'TAP TO RETRY',
                  ar: 'اضغط للمحاولة مرة أخرى',
                  ur: 'دوبارہ کوشش کے لیے ٹیپ کریں',
                  ru: 'НАЖМИТЕ ДЛЯ ПОВТОРА',
                ),
                style: GoogleFonts.montserrat(
                  fontSize: 8,
                  letterSpacing: 2,
                  color: MinaretTheme.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _buildBookList();
  }

  Widget _buildBookList() {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(25, 16, 25, 140),
      itemCount: _filteredBookIds.length,
      itemBuilder: (context, index) {
        final bookId = _filteredBookIds[index];
        final book = _bookData[bookId]!;
        final localizedBookName = _localizedBookName(
          bookId,
          book['displayName'] as String,
        );
        final editions = book['editions'] as List<Map<String, String>>;
        final selectedEditionId = _selectedEdition[bookId]!;
        final selectedEditionData = editions.firstWhere(
          (e) => e['editionId'] == selectedEditionId,
          orElse: () => editions.first,
        );

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HadithChaptersPage(
                bookId: selectedEditionId,
                bookName: localizedBookName,
                textDirection: selectedEditionData['direction'] ?? 'ltr',
                hasSections: selectedEditionData['has_sections'] == 'true',
              ),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            decoration: BoxDecoration(
              color: surface,
              border: Border.all(color: MinaretTheme.dividerColor, width: 0.8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: MinaretTheme.emerald.withValues(alpha: 0.07),
                    border: Border.all(
                      color: MinaretTheme.emerald.withValues(alpha: 0.15),
                      width: 0.7,
                    ),
                  ),
                  child: Text(
                    (index + 1).toString().padLeft(2, '0'),
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 11,
                      color: MinaretTheme.emerald,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizedBookName.toUpperCase(),
                        style: GoogleFonts.lato(
                          color: textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        (book['author'] as String).toUpperCase(),
                        style: GoogleFonts.montserrat(
                          color: MinaretTheme.gold,
                          fontSize: 8,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildLanguagePills(
                        bookId,
                        editions,
                        selectedEditionData,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.chevron_right_rounded,
                  color: textSecondary.withValues(alpha: 0.5),
                  size: 18,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguagePills(
    String bookId,
    List<Map<String, String>> editions,
    Map<String, String> selected,
  ) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: editions.map((e) {
        final isSelected = e['editionId'] == selected['editionId'];
        final mightBeIncomplete = !_completeLanguages.contains(e['language']);

        return GestureDetector(
          onTap: () =>
              setState(() => _selectedEdition[bookId] = e['editionId']!),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected ? MinaretTheme.emerald : Colors.transparent,
              border: Border.all(
                color: isSelected
                    ? MinaretTheme.emerald
                    : MinaretTheme.dividerColor,
                width: 0.7,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  e['language']!.toUpperCase(),
                  style: GoogleFonts.montserrat(
                    fontSize: 8,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : textSecondary,
                  ),
                ),
                if (mightBeIncomplete) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.6)
                          : textSecondary.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
