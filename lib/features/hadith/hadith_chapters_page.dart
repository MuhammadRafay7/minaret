import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:minaret/l10n/generated/app_localizations.dart';

import '../../core/theme.dart';
import '../../widgets/atelier_layout.dart';
import '../../widgets/glass_container.dart';
import '../../services/offline_cache_service.dart';

class HadithChaptersPage extends StatefulWidget {
  final String bookId;
  final String bookName;
  final String textDirection;
  final bool hasSections;
  final String? initialHadithNumber;

  const HadithChaptersPage({
    super.key,
    required this.bookId,
    required this.bookName,
    this.textDirection = 'ltr',
    this.hasSections = false,
    this.initialHadithNumber,
  });

  @override
  State<HadithChaptersPage> createState() => _HadithChaptersPageState();
}

class _HadithChaptersPageState extends State<HadithChaptersPage> {
  // ── Data state ────────────────────────────────────────────────────────────
  List<dynamic> allHadiths = [];
  List<dynamic> filteredHadiths = [];
  Map<String, String> sectionsMap = {};
  bool isLoading = true;
  String? _error;
  int _displayLimit = 20;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _hadithKeys = {};
  String _sourceLabel = 'Hadith API (verified canonical collections)';

  // ── Theme helpers ─────────────────────────────────────────────────────────
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
    _loadHadiths();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── i18n ──────────────────────────────────────────────────────────────────
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

  // ── Text extraction ───────────────────────────────────────────────────────
  String? _extractText(Map h) {
    for (final key in ['text', 'body', 'hadith', 'matn']) {
      final val = h[key];
      if (val is String && val.trim().isNotEmpty) return val;
    }
    return null;
  }

  // ── Load hadiths with Offline Cache Service ─────────────────────────────
  Future<void> _loadHadiths() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      _error = null;
    });

    try {
      Map<String, dynamic>? data;

      // 1. Try OfflineCacheService first
      try {
        final cached = await OfflineCacheService.getMap('hadith_book_${widget.bookId}');
        if (cached != null) {
          data = cached;
        }
      } catch (e) {
        debugPrint("Offline cache read error: $e");
      }

      // 2. Network fallback
      if (data == null) {
        // Prioritizing minified for speed/space
        final minUrl =
            'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/${widget.bookId}.min.json';
        final regUrl =
            'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/${widget.bookId}.json';

        http.Response response = await http
            .get(Uri.parse(minUrl))
            .timeout(const Duration(seconds: 25));

        if (response.statusCode != 200) {
          response = await http
              .get(Uri.parse(regUrl))
              .timeout(const Duration(seconds: 25));
        }

        if (response.statusCode == 200) {
          data = json.decode(response.body) as Map<String, dynamic>;

          // Save to OfflineCacheService (Handles large books like Tirmidhi easily)
          try {
            await OfflineCacheService.setJson('hadith_book_${widget.bookId}', response.body);
          } catch (e) {
            debugPrint(
              "Offline cache write error (Quota exceeded even on IndexedDB): $e",
            );
          }
        } else {
          throw Exception('Connection error (${response.statusCode})');
        }
      }

      if (!mounted) return;
      _parseAndApplyPayload(data);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().contains('QuotaExceededError')
            ? "Storage full. Please clear browser cache."
            : e.toString();
        isLoading = false;
      });
    }
  }

  void _parseAndApplyPayload(Map<String, dynamic> data) {
    final Map<String, String> parsedSections = {};
    final rawSections = data['metadata']?['sections'];
    if (rawSections is Map) {
      rawSections.forEach(
        (k, v) => parsedSections[k.toString()] = v.toString(),
      );
    }

    String sourceLabel = 'Hadith API (verified canonical collections)';
    final source = data['metadata']?['metadata']?['source'];
    if (source is String && source.trim().isNotEmpty)
      sourceLabel = source.trim();

    final List<dynamic> extracted = [];
    final rawHadiths = data['hadiths'];

    if (rawHadiths is List) {
      for (final h in rawHadiths) {
        if (h is Map && _extractText(h) != null) extracted.add(h);
      }
    } else if (rawHadiths is Map) {
      rawHadiths.forEach((sectionKey, sectionValue) {
        final sectionName = parsedSections[sectionKey.toString()] ?? '';
        if (sectionValue is List) {
          for (final h in sectionValue) {
            if (h is Map) {
              final enriched = Map<String, dynamic>.from(h)
                ..['_sectionKey'] = sectionKey.toString()
                ..['_sectionName'] = sectionName;
              if (_extractText(enriched) != null) extracted.add(enriched);
            }
          }
        }
      });
    }

    setState(() {
      sectionsMap = parsedSections;
      _sourceLabel = sourceLabel;
      allHadiths = extracted;
      filteredHadiths = List.from(extracted);
      isLoading = false;
    });

    if (widget.initialHadithNumber != null && extracted.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _jumpToHadith(widget.initialHadithNumber!),
      );
    }
  }

  // ── Logic Helpers ──────────────────────────────────────────────────────────
  void _jumpToHadith(String number) {
    final targetInt = int.tryParse(number);
    final index = filteredHadiths.indexWhere((h) {
      final raw = h['hadithnumber']?.toString() ?? '';
      if (raw == number) return true;
      final parsed = int.tryParse(raw);
      return parsed != null && parsed == targetInt;
    });

    if (index == -1) return;
    if (index >= _displayLimit) setState(() => _displayLimit = index + 10);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _hadithKeys[index];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      }
    });
  }

  void _filterHadiths(String query) {
    setState(() {
      _displayLimit = 20;
      final q = query.toLowerCase().trim();
      if (q.isEmpty) {
        filteredHadiths = List.from(allHadiths);
        return;
      }
      filteredHadiths = allHadiths.where((h) {
        final text = (_extractText(h) ?? '').toLowerCase();
        final number = (h['hadithnumber'] ?? '').toString().toLowerCase();
        final section = (h['_sectionName'] ?? '').toString().toLowerCase();
        return text.contains(q) || number.contains(q) || section.contains(q);
      }).toList();
    });
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _tr(
            en: 'COPIED',
            ar: 'تم النسخ',
            ur: 'کاپی ہو گیا',
            ru: 'СКОПИРОВАНО',
          ),
          style: GoogleFonts.montserrat(
            fontSize: 12.sp,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
        duration: const Duration(seconds: 1),
        margin: EdgeInsets.fromLTRB(24.w, 0, 24.w, 40.h),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build UI ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AtelierLayout(
        child: isLoading
            ? _buildLoading()
            : _error != null
            ? _buildError()
            : _buildContent(l10n),
      ),
    );
  }

  Widget _buildContent(AppLocalizations l10n) {
    final isRtl = widget.textDirection == 'rtl';
    return NestedScrollView(
      controller: _scrollController,
      headerSliverBuilder: (context, _) => [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(28.w, 70.h, 28.w, 20.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBackButton(l10n),
                SizedBox(height: 28.h),
                if (widget.initialHadithNumber != null) _buildJumpButton(),
                Text(
                  widget.bookName.toUpperCase(),
                  style: MinaretTheme.heading.copyWith(
                    fontSize: 28.sp,
                    letterSpacing: 4,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 12.h),
                _buildEditionBadge(),
                SizedBox(height: 12.h),
                _buildStatsText(),
                SizedBox(height: 14.h),
                Container(
                  width: 40.w,
                  height: 1,
                  color: MinaretTheme.gold.withValues(alpha: 0.4),
                ),
                SizedBox(height: 20.h),
                _buildDisclaimerBanner(),
                SizedBox(height: 18.h),
                _buildSearchBar(l10n),
              ],
            ),
          ),
        ),
      ],
      body: Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(28.w, 0, 28.w, 140.h),
          physics: const BouncingScrollPhysics(),
          itemCount: filteredHadiths.length > _displayLimit
              ? _displayLimit + 1
              : filteredHadiths.length,
          itemBuilder: (context, index) {
            if (index == _displayLimit) return _buildLoadMore();

            final hadith = filteredHadiths[index];
            final sectionName = (hadith['_sectionName'] as String?) ?? '';
            final prevSection = index > 0
                ? ((filteredHadiths[index - 1]['_sectionName'] as String?) ??
                      '')
                : '';
            final showSection =
                sectionName.isNotEmpty && sectionName != prevSection;

            _hadithKeys[index] ??= GlobalKey();
            final isTarget =
                widget.initialHadithNumber != null &&
                hadith['hadithnumber']?.toString() ==
                    widget.initialHadithNumber;

            return Column(
              key: _hadithKeys[index],
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showSection) _buildSectionHeader(sectionName),
                _buildHadithCard(hadith, isRtl, highlight: isTarget),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Sub-Widgets ────────────────────────────────────────────────────────────
  Widget _buildBackButton(AppLocalizations l10n) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Row(
        children: [
          Icon(
            Icons.arrow_back_ios_rounded,
            size: 14.sp,
            color: textSecondary.withValues(alpha: 0.75),
          ),
          SizedBox(width: 8.w),
          Text(
            l10n.cancelAction.toUpperCase(),
            style: GoogleFonts.montserrat(
              fontSize: 11.sp,
              letterSpacing: 2,
              color: textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJumpButton() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: GestureDetector(
        onTap: () => _jumpToHadith(widget.initialHadithNumber!),
        child: Row(
          children: [
            const Icon(
              Icons.my_location_rounded,
              size: 12,
              color: MinaretTheme.gold,
            ),
            const SizedBox(width: 8),
            Text(
              '${_tr(en: 'JUMP TO HADITH', ar: 'انتقل إلى الحديث', ur: 'حدیث پر جائیں', ru: 'ПЕРЕЙТИ К ХАДИСУ')} ${widget.initialHadithNumber}',
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
    );
  }

  Widget _buildStatsText() {
    return Text(
      '${allHadiths.length} ${_tr(en: 'HADITHS', ar: 'أحاديث', ur: 'احادیث', ru: 'ХАДИСОВ')} · ${filteredHadiths.length} ${_tr(en: 'SHOWN', ar: 'مُعروض', ur: 'نمایاں', ru: 'ПОКАЗАНО')}',
      style: GoogleFonts.ibmPlexMono(
        fontSize: 10.sp,
        color: textSecondary.withValues(alpha: 0.75),
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(top: 28.h, bottom: 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.montserrat(
              fontSize: 11.sp,
              letterSpacing: 3,
              color: MinaretTheme.gold,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6.h),
          Container(height: 0.5, color: MinaretTheme.gold.withValues(alpha: 0.3)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(AppLocalizations l10n) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 15.w),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: MinaretTheme.dividerColor),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _filterHadiths,
        cursorColor: MinaretTheme.gold,
        style: GoogleFonts.lato(fontSize: 15.sp, color: textPrimary),
        decoration: InputDecoration(
          hintText:
              '${l10n.searchRegistry.toUpperCase()} ${widget.bookName.toUpperCase()}',
          hintStyle: GoogleFonts.montserrat(
            fontSize: 11.sp,
            letterSpacing: 1,
            color: textSecondary.withValues(alpha: 0.65),
          ),
          border: InputBorder.none,
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    size: 16.sp,
                    color: textSecondary.withValues(alpha: 0.5),
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _filterHadiths('');
                  },
                )
              : null,
          icon: Icon(
            Icons.search_rounded,
            size: 18.sp,
            color: MinaretTheme.gold.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildHadithCard(
    dynamic hadith,
    bool isRtl, {
    bool highlight = false,
  }) {
    final String text = _extractText(hadith) ?? '';
    final grades = hadith['grades'] as List<dynamic>?;
    final String? grade = (grades != null && grades.isNotEmpty)
        ? grades.first['grade']?.toString()
        : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: EdgeInsets.only(bottom: 48.h),
      padding: highlight ? const EdgeInsets.all(16) : EdgeInsets.zero,
      decoration: highlight
          ? BoxDecoration(
              color: MinaretTheme.gold.withValues(alpha: 0.05),
              border: Border.all(
                color: MinaretTheme.gold.withValues(alpha: 0.3),
                width: 0.8,
              ),
            )
          : const BoxDecoration(),
      child: Column(
        crossAxisAlignment: isRtl
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nº ${hadith['hadithnumber']}',
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: MinaretTheme.gold,
                ),
              ),
              Row(
                children: [
                  if (grade != null) _buildGradeBadge(grade),
                  IconButton(
                    onPressed: () => _copyToClipboard(context, text),
                    icon: Icon(
                      Icons.copy_rounded,
                      size: 16.sp,
                      color: textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Share.share(
                      '*${widget.bookName}*\nHadith ${hadith['hadithnumber']}\n\n$text',
                    ),
                    icon: Icon(
                      Icons.ios_share_rounded,
                      size: 16.sp,
                      color: textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            text,
            textAlign: isRtl ? TextAlign.right : TextAlign.left,
            style: isRtl
                ? GoogleFonts.amiri(
                    fontSize: 22.sp,
                    height: 2.2,
                    color: textPrimary,
                  )
                : GoogleFonts.lato(
                    fontSize: 15.sp,
                    height: 1.9,
                    color: textPrimary,
                    fontWeight: FontWeight.w300,
                  ),
          ),
          SizedBox(height: 28.h),
          Divider(thickness: 0.5, color: MinaretTheme.dividerColor),
        ],
      ),
    );
  }

  Widget _buildGradeBadge(String grade) {
    final color = _gradeColor(grade);
    return Container(
      margin: EdgeInsets.only(right: 6.w),
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.7),
      ),
      child: Text(
        grade.toUpperCase(),
        style: GoogleFonts.montserrat(
          fontSize: 10.sp,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEditionBadge() {
    final langCode = widget.bookId.split('-').first.toUpperCase();
    return Row(
      children: [
        Container(height: 1, width: 20.w, color: MinaretTheme.gold),
        SizedBox(width: 10.w),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
          decoration: BoxDecoration(
            border: Border.all(
              color: MinaretTheme.gold.withValues(alpha: 0.5),
              width: 0.7,
            ),
          ),
          child: Text(
            langCode,
            style: GoogleFonts.montserrat(
              fontSize: 11.sp,
              letterSpacing: 2,
              color: MinaretTheme.gold,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimerBanner() {
    return GlassContainer(
      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 14.sp,
            color: MinaretTheme.gold.withValues(alpha: 0.7),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              '${_tr(en: 'TRANSLATIONS FOR REFERENCE ONLY.', ar: 'الترجمات للاطلاع فقط.', ur: 'تراجم صرف حوالہ کے لیے ہیں۔', ru: 'Переводы для справки.')}\nSource: $_sourceLabel',
              style: GoogleFonts.montserrat(
                fontSize: 10.sp,
                letterSpacing: 1.1,
                color: textSecondary,
                height: 1.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 22.w,
            height: 22.w,
            child: const CircularProgressIndicator(
              color: MinaretTheme.gold,
              strokeWidth: 1.2,
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            _tr(
              en: 'LOADING...',
              ar: 'تحميل...',
              ur: 'لوڈنگ...',
              ru: 'ЗАГРУЗКА...',
            ),
            style: GoogleFonts.montserrat(
              fontSize: 11.sp,
              letterSpacing: 2,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              color: MinaretTheme.gold.withValues(alpha: 0.35),
              size: 32,
            ),
            SizedBox(height: 16.h),
            Text(
              _tr(
                en: 'FAILED TO LOAD',
                ar: 'فشل التحميل',
                ur: 'لوڈ نہیں ہوا',
                ru: 'ОШИБКА ЗАГРУЗКИ',
              ),
              style: GoogleFonts.montserrat(
                fontSize: 13.sp,
                letterSpacing: 2,
                color: textSecondary,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              _error!,
              style: GoogleFonts.lato(
                fontSize: 11.sp,
                color: textSecondary.withValues(alpha: 0.5),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            OutlinedButton.icon(
              onPressed: _loadHadiths,
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: Text(
                _tr(en: 'RETRY', ar: 'إعادة', ur: 'دوبارہ', ru: 'ПОВТОР'),
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

  Widget _buildLoadMore() {
    return Padding(
      padding: EdgeInsets.only(top: 20.h),
      child: TextButton(
        onPressed: () => setState(() => _displayLimit += 20),
        child: Text(
          _tr(
            en: 'LOAD MORE',
            ar: 'تحميل المزيد',
            ur: 'مزید لوڈ کریں',
            ru: 'ЕЩЁ',
          ),
          style: GoogleFonts.montserrat(
            fontSize: 12.sp,
            letterSpacing: 3,
            color: MinaretTheme.gold,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Color _gradeColor(String grade) {
    final g = grade.toLowerCase();
    if (g.contains('sahih')) return const Color(0xFF2E7D5E);
    if (g.contains('hasan')) return const Color(0xFF8B6914);
    if (g.contains("da'if") || g.contains('weak'))
      return const Color(0xFF9E3A2F);
    return MinaretTheme.slate;
  }
}
