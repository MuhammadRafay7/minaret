import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:minaret/core/secure_http_client.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:minaret/core/app_spacing.dart';
import 'package:minaret/core/theme.dart';
import 'package:minaret/widgets/atelier_layout.dart';
import 'package:minaret/core/locale_format.dart';
import 'package:minaret/features/quran/surah_view_page.dart';
import 'package:minaret/services/offline_cache_service.dart';

// ─── Data model ───────────────────────────────────────────────────────────────
class _SurahEntry {
  final int number;
  final String arabicName;
  final String englishName;
  final String revelationType;
  final int startAyah;
  final int ayahCount;
  final int totalAyahs;

  const _SurahEntry({
    required this.number,
    required this.arabicName,
    required this.englishName,
    required this.revelationType,
    required this.startAyah,
    required this.ayahCount,
    required this.totalAyahs,
  });
}

class JuzViewPage extends StatefulWidget {
  final int juzNumber;
  final String editionId;

  const JuzViewPage({
    super.key,
    required this.juzNumber,
    required this.editionId,
  });

  @override
  State<JuzViewPage> createState() => _JuzViewPageState();
}

class _JuzViewPageState extends State<JuzViewPage>
    with SingleTickerProviderStateMixin {
  late Future<List<_SurahEntry>> _juzFuture;

  List<_SurahEntry> _allSurahs = [];
  List<_SurahEntry> _filteredSurahs = [];
  final TextEditingController _searchController = TextEditingController();
  bool _dataLoaded = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ── i18n ──────────────────────────────────────────────────────────────────
  String _tr({
    required String en,
    required String ar,
    required String ur,
    required String ru,
  }) {
    final code = Localizations.localeOf(context).languageCode;
    switch (code) {
      case 'ar':
        return ar;
      case 'ur':
        return ur;
      case 'ru':
        return ru;
      default:
        return en;
    }
  }

  @override
  void initState() {
    super.initState();
    _juzFuture = _fetchJuzSurahs();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredSurahs = q.isEmpty
          ? List.from(_allSurahs)
          : _allSurahs
              .where(
                (s) =>
                    s.englishName.toLowerCase().contains(q) ||
                    s.arabicName.contains(q) ||
                    s.number.toString() == q,
              )
              .toList();
    });
  }

  // ── API LOGIC ──────────────────────────────────────────────────────────────
  Future<List<_SurahEntry>> _fetchJuzSurahs() async {
    List<dynamic>? ayahs;

    // 1. Try OfflineCacheService first
    try {
      final cachedData = await OfflineCacheService.getMap('quran_juz_${widget.juzNumber}');
      if (cachedData != null) {
        if (cachedData['ayahs'] is List) {
          ayahs = cachedData['ayahs'] as List;
        } else {
          final data = cachedData['data'];
          if (data is List && data.isNotEmpty && data[0] is Map) {
            ayahs = (data[0] as Map)['ayahs'] as List?;
          } else if (data is Map) {
            ayahs = data['ayahs'] as List?;
          }
        }
      }
    } catch (e) {
      debugPrint("Offline cache check failed: $e");
    }

    // 2. Fetch from network if no cached data
    if (ayahs == null) {
      final url =
          'https://api.alquran.cloud/v1/juz/${widget.juzNumber}/quran-uthmani';

      final response = await SecureHttpClient.instance.get(url);

      if (response.statusCode == 200) {
        final raw = response.data as Map<String, dynamic>;
        final rawData = raw['data'];
        if (rawData is List && rawData.isNotEmpty && rawData[0] is Map) {
          ayahs = (rawData[0] as Map)['ayahs'] as List?;
        } else if (rawData is Map) {
          ayahs = rawData['ayahs'] as List?;
        }
        // Cache the response for offline use
        try {
          await OfflineCacheService.setJson('quran_juz_${widget.juzNumber}', json.encode(raw));
        } catch (e) {
          debugPrint("Failed to cache juz data: $e");
        }
      } else {
        throw Exception('Server Error: ${response.statusCode}');
      }
    }

    if (ayahs == null) throw Exception('No data available');

    // Parse ayahs into Surah list
    final Map<int, _SurahEntry> surahMap = {};
    for (final ayah in ayahs) {
      final surah = ayah['surah'];
      final surahNum = (surah['number'] as num).toInt();

      if (!surahMap.containsKey(surahNum)) {
        surahMap[surahNum] = _SurahEntry(
          number: surahNum,
          arabicName: surah['name'],
          englishName: surah['englishName'],
          revelationType: surah['revelationType'],
          startAyah: (ayah['numberInSurah'] as num).toInt(),
          ayahCount: 1,
          totalAyahs: (surah['numberOfAyahs'] as num).toInt(),
        );
      } else {
        final e = surahMap[surahNum]!;
        surahMap[surahNum] = _SurahEntry(
          number: e.number,
          arabicName: e.arabicName,
          englishName: e.englishName,
          revelationType: e.revelationType,
          startAyah: e.startAyah,
          ayahCount: e.ayahCount + 1,
          totalAyahs: e.totalAyahs,
        );
      }
    }

    return surahMap.values.toList()
      ..sort((a, b) => a.number.compareTo(b.number));
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? Colors.white70 : MinaretTheme.slate;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AtelierLayout(
        child: FutureBuilder<List<_SurahEntry>>(
          future: _juzFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState(textSecondary);
            }
            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString(), textSecondary);
            }

            final surahs = snapshot.data ?? [];
            if (!_dataLoaded && surahs.isNotEmpty) {
              _allSurahs = surahs;
              _filteredSurahs = List.from(surahs);
              _dataLoaded = true;
              _animController.forward();
            }

            return FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    const SliverToBoxAdapter(child: SizedBox(height: 75)),
                    _buildHeader(textSecondary),
                    _buildSearchBar(isDark, textSecondary),
                    _buildCountLabel(textSecondary),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 140),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildSurahCard(
                            _filteredSurahs[index],
                            isDark: isDark,
                            textSecondary: textSecondary,
                          ),
                          childCount: _filteredSurahs.length,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── UI COMPONENTS ──────────────────────────────────────────────────────────

  Widget _buildHeader(Color textSecondary) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GlassPill(
              onTap: () => Navigator.pop(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.arrow_back_ios_new,
                    size: 11,
                    color: MinaretTheme.gold,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _tr(en: 'BACK', ar: 'رجوع', ur: 'واپس', ru: 'НАЗАД'),
                    style: GoogleFonts.montserrat(
                      fontSize: 9,
                      letterSpacing: 2,
                      color: MinaretTheme.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _tr(en: 'PARA / JUZ', ar: 'الجزء', ur: 'پارہ', ru: 'ДЖУЗ'),
              style: GoogleFonts.montserrat(
                fontSize: 9,
                letterSpacing: 3,
                color: MinaretTheme.gold,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              LocaleFormat.localizedDigits(
                  context, widget.juzNumber.toString()),
              style: MinaretTheme.heading.copyWith(
                fontSize: 56,
                letterSpacing: 4,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            Container(width: 40, height: 1.5, color: MinaretTheme.gold),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, Color textSecondary) {
    final surface = isDark ? const Color(0xFF151B24) : MinaretTheme.surface;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Container(
          decoration: BoxDecoration(
            color: surface,
            border: Border.all(color: MinaretTheme.dividerColor),
          ),
          child: TextField(
            controller: _searchController,
            style: GoogleFonts.lato(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            cursorColor: MinaretTheme.gold,
            decoration: InputDecoration(
              hintText: _tr(
                en: 'Search surah...',
                ar: 'ابحث عن سورة...',
                ur: 'سورت تلاش کریں...',
                ru: 'Поиск суры...',
              ),
              hintStyle: GoogleFonts.lato(
                color: textSecondary.withOpacity(0.6),
                fontSize: 13,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: MinaretTheme.gold.withOpacity(0.5),
                size: 18,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountLabel(Color textSecondary) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 14, AppSpacing.lg, 0),
        child: Text(
          '${LocaleFormat.localizedDigits(context, _filteredSurahs.length.toString())} ${_tr(en: 'SURAHS IN THIS PARA', ar: 'سور في هذا الجزء', ur: 'سورتیں اس پارے میں', ru: 'СУР В ДЖУЗЕ')}',
          style: GoogleFonts.montserrat(
            fontSize: 8,
            letterSpacing: 2,
            color: textSecondary.withOpacity(0.55),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSurahCard(
    _SurahEntry surah, {
    required bool isDark,
    required Color textSecondary,
  }) {
    final surface = isDark ? const Color(0xFF151B24) : MinaretTheme.surface;
    final isPartial = surah.ayahCount < surah.totalAyahs;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SurahViewPage(
              surahNumber: surah.number,
              surahName: surah.englishName,
              editionId: widget.editionId,
              initialAyahNumber: surah.startAyah,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: MinaretTheme.dividerColor, width: 0.7),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: MinaretTheme.gold.withOpacity(0.07),
                border: Border.all(color: MinaretTheme.gold.withOpacity(0.2)),
              ),
              child: Text(
                LocaleFormat.localizedDigits(context, surah.number.toString()),
                style: GoogleFonts.ibmPlexMono(
                  color: MinaretTheme.gold,
                  fontSize: 12,
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
                    surah.englishName.toUpperCase(),
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${surah.revelationType.toUpperCase()} · ${LocaleFormat.localizedDigits(context, (isPartial ? surah.ayahCount : surah.totalAyahs).toString())} ${_tr(en: 'VERSES', ar: 'آيات', ur: 'آیات', ru: 'АЯТ')}',
                    style: GoogleFonts.montserrat(
                      fontSize: 7,
                      letterSpacing: 1.5,
                      color: textSecondary.withOpacity(0.55),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              surah.arabicName,
              style: GoogleFonts.amiri(fontSize: 20, color: MinaretTheme.gold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(Color textSecondary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: MinaretTheme.gold,
              strokeWidth: 1,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _tr(
              en: 'LOADING PARA...',
              ar: 'جارٍ التحميل...',
              ur: 'لوڈ ہو رہا ہے...',
              ru: 'ЗАГРУЗКА...',
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

  Widget _buildErrorState(String error, Color textSecondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              color: MinaretTheme.gold.withOpacity(0.35),
              size: 32,
            ),
            const SizedBox(height: 20),
            Text(
              _tr(
                en: 'COULD NOT LOAD PARA',
                ar: 'تعذّر التحميل',
                ur: 'لوڈ نہیں ہوا',
                ru: 'ОШИБКА ЗАГРУЗКИ',
              ),
              style: GoogleFonts.montserrat(
                fontSize: 10,
                letterSpacing: 2.5,
                color: textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 28),
            OutlinedButton(
              onPressed: () => setState(() {
                _dataLoaded = false;
                _juzFuture = _fetchJuzSurahs();
              }),
              child: Text(
                _tr(en: 'RETRY', ar: 'إعادة', ur: 'دوبارہ', ru: 'ПОВТОР'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _GlassPill({required this.child, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: Colors.white.withOpacity(0.09)),
        ),
        child: child,
      ),
    );
  }
}
