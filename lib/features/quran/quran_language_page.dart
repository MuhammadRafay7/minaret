import 'package:flutter/material.dart';
import 'package:minaret/core/secure_http_client.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:minaret/l10n/generated/app_localizations.dart';

import 'package:minaret/core/theme.dart';
import 'package:minaret/widgets/atelier_layout.dart';
import 'package:minaret/features/quran/quran_reader_page.dart';

class QuranLanguagePage extends StatefulWidget {
  const QuranLanguagePage({super.key});

  @override
  State<QuranLanguagePage> createState() => _QuranLanguagePageState();
}

class _QuranLanguagePageState extends State<QuranLanguagePage> {
  List<dynamic> allLanguages = [];
  List<dynamic> filteredLanguages = [];
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // Color Getters to make them accessible to all methods in the class
  Color get textPrimary => Theme.of(context).colorScheme.onSurface;
  Color get textSecondary => Theme.of(context).brightness == Brightness.dark
      ? Colors.white70
      : MinaretTheme.slate;
  Color get surface => Theme.of(context).brightness == Brightness.dark
      ? MinaretTheme.darkSurface
      : MinaretTheme.surface;

  static const _isoNames = {
    'ur': 'urdu',
    'ar': 'arabic',
    'en': 'english',
    'fr': 'french',
    'de': 'german',
    'tr': 'turkish',
    'id': 'indonesian',
    'ms': 'malay',
    'bn': 'bengali',
    'hi': 'hindi',
    'fa': 'persian farsi',
    'ru': 'russian',
    'es': 'spanish',
    'it': 'italian',
    'nl': 'dutch',
    'pt': 'portuguese',
    'zh': 'chinese',
    'ja': 'japanese',
    'ko': 'korean',
    'sw': 'swahili',
    'ha': 'hausa',
    'so': 'somali',
    'az': 'azerbaijani',
    'bs': 'bosnian',
    'sq': 'albanian',
    'cs': 'czech',
    'fi': 'finnish',
    'hu': 'hungarian',
    'pl': 'polish',
    'ro': 'romanian',
    'sk': 'slovak',
    'sv': 'swedish',
    'uk': 'ukrainian',
    'uz': 'uzbek',
    'tg': 'tajik',
    'kk': 'kazakh',
    'ky': 'kyrgyz',
    'ml': 'malayalam',
    'ta': 'tamil',
    'te': 'telugu',
    'gu': 'gujarati',
    'pa': 'punjabi',
    'si': 'sinhala',
    'th': 'thai',
    'vi': 'vietnamese',
    'am': 'amharic',
    'yo': 'yoruba',
    'dv': 'divehi',
    'ku': 'kurdish',
  };

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

  @override
  void initState() {
    super.initState();
    fetchLanguages();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchLanguages() async {
    try {
      final response = await SecureHttpClient.instance.get(
        'https://api.alquran.cloud/v1/edition/type/translation',
      );
      if (response.statusCode == 200) {
        final body = response.data as Map<String, dynamic>;
        final data = body['data'];
        if (mounted) {
          setState(() {
            allLanguages = data;
            filteredLanguages = data;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('API Error: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _filterLanguages(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) {
      setState(() => filteredLanguages = allLanguages);
      return;
    }
    setState(() {
      filteredLanguages = allLanguages.where((lang) {
        final name = (lang['name'] ?? '').toString().toLowerCase();
        final isoCode = (lang['language'] ?? '').toString().toLowerCase();
        final fullName = _isoNames[isoCode] ?? '';
        return name.contains(q) || isoCode.contains(q) || fullName.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AtelierLayout(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 55),
            _buildHeader(l10n),
            _buildSearchField(l10n),
            Expanded(
              child: isLoading
                  ? _buildLoadingState()
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(25, 16, 25, 140),
                      itemCount: filteredLanguages.length,
                      itemBuilder: (context, index) =>
                          _buildEditionCard(filteredLanguages[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
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
              en: 'LOADING TRANSLATIONS...',
              ar: 'جارٍ تحميل الترجمات...',
              ur: 'تراجم لوڈ ہو رہے ہیں...',
              ru: 'ЗАГРУЗКА ПЕРЕВОДОВ...',
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


  Widget _buildHeader(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 20, 25, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tr(en: 'TRANSLATION', ar: 'الترجمة', ur: 'ترجمہ', ru: 'ПЕРЕВОД'),
            style: GoogleFonts.montserrat(
              fontSize: 9,
              letterSpacing: 3,
              color: MinaretTheme.gold,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.quranTitle.toUpperCase(),
            style: MinaretTheme.heading.copyWith(
              fontSize: 38,
              letterSpacing: 6,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _tr(
              en: 'Select a language to read the Quran',
              ar: 'اختر لغة لقراءة القرآن',
              ur: 'قرآن پڑھنے کے لیے زبان منتخب کریں',
              ru: 'Выберите язык для чтения Корана',
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
              en: 'Source: AlQuran Cloud API (verified Quran editions)',
              ar: 'المصدر: واجهة AlQuran Cloud (نسخ قرآن موثوقة)',
              ur: 'ماخذ: AlQuran Cloud API (مصدقہ قرآن ایڈیشنز)',
              ru: 'Источник: AlQuran Cloud API (проверенные издания Корана)',
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
        child: TextField(
          controller: _searchController,
          onChanged: _filterLanguages,
          style: GoogleFonts.lato(fontSize: 15, color: textPrimary),
          cursorColor: MinaretTheme.gold,
          cursorWidth: 1,
          decoration: InputDecoration(
            hintText: _tr(
              en: 'Search language or translator...',
              ar: 'ابحث عن لغة أو مترجم...',
              ur: 'زبان یا مترجم تلاش کریں...',
              ru: 'Поиск языка или переводчика...',
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
          ),
        ),
      ),
    );
  }

  Widget _buildEditionCard(dynamic lang) {
    final name = lang['name'].toString();
    final language = lang['language'].toString();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              QuranReaderPage(editionId: lang['identifier'], title: name),
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
                language
                    .substring(0, language.length.clamp(0, 2))
                    .toUpperCase(),
                style: GoogleFonts.montserrat(
                  color: MinaretTheme.emerald,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.lato(
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    (_isoNames[language.toLowerCase()] ?? language)
                        .toUpperCase(),
                    style: GoogleFonts.montserrat(
                      color: MinaretTheme.gold,
                      fontSize: 8,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: textSecondary.withValues(alpha: 0.5),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
