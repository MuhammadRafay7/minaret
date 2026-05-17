import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:minaret/services/offline_cache_service.dart';
import 'package:minaret/services/quran_download_service.dart';
import 'package:minaret/l10n/generated/app_localizations.dart';

import 'package:minaret/core/theme.dart';
import 'package:minaret/core/secure_http_client.dart';
import 'package:minaret/core/locale_text.dart';
import 'package:minaret/widgets/atelier_layout.dart';
import 'package:minaret/features/quran/surah_view_page.dart';
import 'package:minaret/features/quran/juz_view_page.dart';
import 'package:minaret/widgets/offline_banner.dart';
import 'package:minaret/widgets/app_loading_indicator.dart';

class QuranReaderPage extends StatefulWidget {
  final String editionId;
  final String title;

  const QuranReaderPage({
    super.key,
    required this.editionId,
    required this.title,
  });

  @override
  State<QuranReaderPage> createState() => _QuranReaderPageState();
}

class _QuranReaderPageState extends State<QuranReaderPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<dynamic> _allSurahs = [];
  List<dynamic> _filteredSurahs = [];
  bool _isLoading = true;
  String? _loadError;

  final TextEditingController _searchController = TextEditingController();

  Color get _textPrimary => Theme.of(context).colorScheme.onSurface;
  Color get _textSecondary => Theme.of(context).brightness == Brightness.dark
      ? Colors.white70
      : MinaretTheme.slate;
  Color get _surface => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF151B24)
      : MinaretTheme.surface;
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearch);
    _loadSurahs();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearch);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _t({required String en, required String ar, required String ur, required String ru}) =>
      context.localText(en: en, ar: ar, ur: ur, ru: ru);

  Future<void> _loadSurahs() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      List<dynamic>? data;
      const cacheKey = 'quran_surahs_list';

      // 1. Try offline cache first
      try {
        final cachedData = await OfflineCacheService.getMap(cacheKey);
        if (cachedData != null && cachedData['data'] is List) {
          data = cachedData['data'] as List<dynamic>;
          if (mounted) {
            setState(() {
              _allSurahs = data!;
              _filteredSurahs = List.from(data);
              _isLoading = false;
            });
          }
          return; // Successfully loaded from cache
        }
      } catch (e) {
        debugPrint("Offline cache check failed: $e");
      }

      // 2. Fetch from network if no cached data
      final response = await SecureHttpClient.instance
          .get('https://api.alquran.cloud/v1/surah');

      if (response.statusCode == 200) {
        final decoded = response.data as Map<String, dynamic>;
        if (decoded['data'] is List) {
          data = decoded['data'] as List<dynamic>;
        } else {
          throw Exception('Server returned ${response.statusCode}');
        }
      }

      if (!mounted) return;

      if (data != null && data.isNotEmpty) {
        // Cache the response for offline use
        try {
          await OfflineCacheService.setJson(cacheKey, json.encode(response.data));
        } catch (e) {
          debugPrint("Failed to cache surahs list: $e");
        }

        setState(() {
          _allSurahs = data!;
          _filteredSurahs = List.from(data);
          _isLoading = false;
        });
      } else {
        setState(() {
          _loadError = 'No data returned from server';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onSearch() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredSurahs = List.from(_allSurahs);
      } else {
        _filteredSurahs = _allSurahs.where((s) {
          final english = (s['englishName'] ?? '').toString().toLowerCase();
          final arabic = (s['name'] ?? '').toString();
          final translation = (s['englishNameTranslation'] ?? '')
              .toString()
              .toLowerCase();
          final number = s['number'].toString();
          return english.contains(q) ||
              arabic.contains(q) ||
              translation.contains(q) ||
              number == q;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AtelierLayout(
      child: SafeArea(
        child: Column(
          children: [
            const OfflineBanner(),
            _buildHeader(),
            const SizedBox(height: 10),
            TabBar(
              controller: _tabController,
              labelColor: MinaretTheme.gold,
              unselectedLabelColor: _textSecondary,
              indicatorColor: MinaretTheme.gold,
              labelStyle: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
              tabs: [
                Tab(
                  text: _t(en: 'SURAH', ar: 'السور', ur: 'سورہ', ru: 'СУРЫ'),
                ),
                Tab(
                  text: _t(
                    en: 'PARA / JUZ',
                    ar: 'الأجزاء',
                    ur: 'پارہ',
                    ru: 'ДЖУЗЫ',
                  ),
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildSurahTab(), _buildJuzGrid()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 10, 25, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title.toUpperCase(),
              style: MinaretTheme.heading.copyWith(
                fontSize: 20,
                letterSpacing: 2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurahTab() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppLoadingIndicator(size: 18, strokeWidth: 1.5),
            const SizedBox(height: 16),
            Text(
              _t(
                en: 'LOADING SURAHS...',
                ar: 'جارٍ التحميل...',
                ur: 'لوڈ ہو رہا ہے...',
                ru: 'ЗАГРУЗКА...',
              ),
              style: GoogleFonts.montserrat(
                fontSize: 8,
                letterSpacing: 2,
                color: _textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                color: MinaretTheme.gold.withOpacity(0.35),
                size: 32,
              ),
              const SizedBox(height: 16),
              Text(
                _t(
                  en: 'COULD NOT LOAD SURAHS',
                  ar: 'تعذّر التحميل',
                  ur: 'سورتیں لوڈ نہیں ہوئیں',
                  ru: 'ОШИБКА ЗАГРУЗКИ',
                ),
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  letterSpacing: 2,
                  color: _textSecondary,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _loadError!,
                style: GoogleFonts.lato(
                  fontSize: 11,
                  color: _textSecondary.withOpacity(0.5),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _loadSurahs,
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: Text(
                  _t(en: 'RETRY', ar: 'إعادة', ur: 'دوبارہ', ru: 'ПОВТОР'),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MinaretTheme.gold,
                  side: const BorderSide(color: MinaretTheme.gold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(25, 12, 25, 4),
          child: Container(
            decoration: BoxDecoration(
              color: _surface,
              border: Border.all(color: MinaretTheme.dividerColor),
            ),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.lato(fontSize: 14, color: _textPrimary),
              cursorColor: MinaretTheme.gold,
              cursorWidth: 1,
              decoration: InputDecoration(
                hintText: _t(
                  en: 'Search surah by name or number...',
                  ar: 'ابحث عن سورة...',
                  ur: 'سورة تلاش کریں...',
                  ru: 'Поиск суры...',
                ),
                hintStyle: GoogleFonts.lato(
                  color: _textSecondary.withOpacity(0.6),
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: MinaretTheme.gold.withOpacity(0.5),
                  size: 18,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          size: 16,
                          color: _textSecondary.withOpacity(0.5),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _onSearch();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
                border: InputBorder.none,
              ),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(25, 6, 25, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${_filteredSurahs.length} ${_t(en: 'SURAHS', ar: 'سور', ur: 'سورتیں', ru: 'СУР')}',
              style: GoogleFonts.montserrat(
                fontSize: 8,
                letterSpacing: 2,
                color: _textSecondary.withOpacity(0.55),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        Expanded(
          child: _filteredSurahs.isEmpty
              ? Center(
                  child: Text(
                    _t(
                      en: 'No surahs found',
                      ar: 'لا توجد نتائج',
                      ur: 'کوئی نتیجہ نہیں',
                      ru: 'Ничего не найдено',
                    ),
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: _textSecondary.withOpacity(0.6),
                    ),
                  ),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(25, 6, 25, 120),
                  itemCount: _filteredSurahs.length,
                  itemBuilder: (context, i) {
                    final s = _filteredSurahs[i];
                    final int number = s['number'];
                    return _SurahListTile(
                      surah: s,
                      editionId: widget.editionId,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SurahViewPage(
                            surahNumber: number,
                            surahName: s['englishName'],
                            editionId: widget.editionId,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildJuzGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(25, 20, 25, 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: 30,
      itemBuilder: (context, i) {
        final juzNo = i + 1;
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  JuzViewPage(juzNumber: juzNo, editionId: widget.editionId),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: _isDark ? Colors.white.withOpacity(0.05) : Colors.white,
              border: Border.all(color: MinaretTheme.dividerColor),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'PARA',
                  style: GoogleFonts.montserrat(
                    fontSize: 7,
                    letterSpacing: 1.5,
                    color: MinaretTheme.gold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  juzNo.toString(),
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SurahListTile extends StatelessWidget {
  final dynamic surah;
  final String editionId;
  final VoidCallback onTap;

  const _SurahListTile({
    required this.surah,
    required this.editionId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final downloadService = context.watch<QuranDownloadService>();
    final int number = surah['number'];
    final isDownloading = downloadService.isDownloading(number);
    final progress = downloadService.getProgress(number);

    return FutureBuilder<bool>(
      future: downloadService.isSurahDownloaded(number, editionId),
      builder: (context, snap) {
        final isDownloaded = snap.data ?? false;
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final secondaryColor = isDark ? Colors.white70 : MinaretTheme.slate;

        return Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: MinaretTheme.dividerColor,
                width: 0.5,
              ),
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            leading: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: MinaretTheme.gold.withOpacity(0.07),
                border: Border.all(
                  color: MinaretTheme.gold.withOpacity(0.2),
                  width: 0.7,
                ),
              ),
              child: Text(
                number.toString(),
                style: GoogleFonts.ibmPlexMono(
                  color: MinaretTheme.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              (surah['englishName'] ?? '').toString().toUpperCase(),
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Row(
              children: [
                Expanded(
                  child: Text(
                    '${surah['revelationType']} · ${surah['numberOfAyahs']} ayahs',
                    style: TextStyle(fontSize: 10, color: secondaryColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isDownloaded) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle, size: 10, color: MinaretTheme.emerald),
                ]
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isDownloading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 2,
                      color: MinaretTheme.gold,
                    ),
                  )
                else if (!isDownloaded)
                  IconButton(
                    icon: const Icon(Icons.download_for_offline_outlined, size: 20, color: MinaretTheme.gold),
                    onPressed: () => downloadService.downloadSurah(number, editionId),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                    onPressed: () => downloadService.deleteDownloadedSurah(number, editionId),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                const SizedBox(width: 12),
                Text(
                  surah['name'].toString(),
                  style: GoogleFonts.amiri(
                    fontSize: 18,
                    color: MinaretTheme.gold,
                  ),
                ),
              ],
            ),
            onTap: onTap,
          ),
        );
      },
    );
  }
}
