import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:minaret/core/theme.dart';
import 'package:minaret/core/locale_text.dart';
import 'package:minaret/core/secure_http_client.dart';
import 'package:minaret/widgets/atelier_layout.dart';
import 'package:minaret/widgets/offline_banner.dart';
import 'package:minaret/widgets/app_loading_indicator.dart';
import 'package:minaret/services/offline_cache_service.dart';

/// Total pages in the standard 604-page Madani Mushaf.
const int kMushafPageCount = 604;

/// Start page of each surah (index 0 == surah 1). Derived from the
/// alquran.cloud `/meta` page references — verified against the printed Mushaf.
const List<int> kSurahStartPages = [
  1, 2, 50, 77, 106, 128, 151, 177, 187, 208, 221, 235, 249, 255, 262, 267,
  282, 293, 305, 312, 322, 332, 342, 350, 359, 367, 377, 385, 396, 404, 411,
  415, 418, 428, 434, 440, 446, 453, 458, 467, 477, 483, 489, 496, 499, 502,
  507, 511, 515, 518, 520, 523, 526, 528, 531, 534, 537, 542, 545, 549, 551,
  553, 554, 556, 558, 560, 562, 564, 566, 568, 570, 572, 574, 575, 577, 578,
  580, 582, 583, 585, 586, 587, 587, 589, 590, 591, 591, 592, 593, 594, 595,
  595, 596, 596, 597, 597, 598, 598, 599, 599, 600, 600, 601, 601, 601, 602,
  602, 602, 603, 603, 603, 604, 604, 604,
];

/// Start page of each juz / para (index 0 == juz 1).
const List<int> kJuzStartPages = [
  1, 22, 42, 62, 82, 102, 121, 142, 162, 182, 201, 222, 242, 262, 282, 302,
  322, 342, 362, 382, 402, 422, 442, 462, 482, 502, 522, 542, 562, 582,
];

class Reciter {
  final String id;
  final String name;
  final String arabicName;
  const Reciter(this.id, this.name, this.arabicName);
}

/// Curated set of verse-by-verse reciters available at 128 kbps on
/// cdn.islamic.network. Audio URLs are deterministic, so no API call is needed.
const List<Reciter> kReciters = [
  Reciter('ar.alafasy', 'Mishary Alafasy', 'مشاري العفاسي'),
  Reciter('ar.husary', 'Mahmoud Al-Husary', 'محمود الحصري'),
  Reciter('ar.abdulsamad', 'Abdul Basit', 'عبد الباسط'),
  Reciter('ar.abdurrahmaansudais', 'Abdurrahman As-Sudais', 'عبد الرحمن السديس'),
  Reciter('ar.mahermuaiqly', 'Maher Al-Muaiqly', 'ماهر المعيقلي'),
  Reciter('ar.shaatree', 'Abu Bakr Ash-Shaatree', 'أبو بكر الشاطري'),
  Reciter('ar.hudhaify', 'Ali Al-Hudhaify', 'علي الحذيفي'),
];

const String _kReciterPrefKey = 'mushaf_reciter';
const String _kBismillah = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

String _audioUrl(String reciterId, int globalAyahNumber) =>
    'https://cdn.islamic.network/quran/audio/128/$reciterId/$globalAyahNumber.mp3';

String _toArabicDigits(int n) {
  const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  var s = n.toString();
  for (var i = 0; i < western.length; i++) {
    s = s.replaceAll(western[i], arabic[i]);
  }
  return s;
}

class _Ayah {
  final int number; // global ayah number 1..6236
  final int surah;
  final int numberInSurah;
  final String text;
  const _Ayah({
    required this.number,
    required this.surah,
    required this.numberInSurah,
    required this.text,
  });
}

class _SurahInfo {
  final int number;
  final String name; // arabic
  final String englishName;
  const _SurahInfo(this.number, this.name, this.englishName);
}

class _PageData {
  final List<_Ayah> ayahs;
  final Map<int, _SurahInfo> surahs;
  const _PageData(this.ayahs, this.surahs);
}

class MushafViewPage extends StatefulWidget {
  /// 1-based page to open on.
  final int initialPage;

  /// Translation edition id (e.g. `en.sahih`) used for the tap-to-translate
  /// sheet — preserved from the existing reader.
  final String editionId;

  /// Optional label shown briefly in the header (surah/juz name).
  final String? title;

  const MushafViewPage({
    super.key,
    required this.initialPage,
    required this.editionId,
    this.title,
  });

  @override
  State<MushafViewPage> createState() => _MushafViewPageState();
}

class _MushafViewPageState extends State<MushafViewPage> {
  late final PageController _pageController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Map<int, _PageData> _mem = {};

  late int _currentPage;
  Reciter _reciter = kReciters.first;

  // Continuous-playback cursor.
  bool _isPlaying = false;
  int? _playingPage;
  int _playingIndex = 0; // index within the playing page's ayah list
  bool _isPlayingBismillah = false;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(1, kMushafPageCount);
    _pageController = PageController(initialPage: _currentPage - 1);
    _loadReciter();

    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && _isPlaying) {
        if (_isPlayingBismillah) {
          _isPlayingBismillah = false;
          _playFrom(_playingPage!, _playingIndex, skipBismillah: true);
        } else {
          _advance();
        }
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _pageController.dispose();
    _savePosition();
    super.dispose();
  }

  String _t({required String en, required String ar, required String ur, required String ru}) =>
      context.localText(en: en, ar: ar, ur: ur, ru: ru);

  Future<void> _loadReciter() async {
    final saved = await OfflineCacheService.getJson(_kReciterPrefKey);
    if (saved == null || !mounted) return;
    final match = kReciters.where((r) => r.id == saved);
    if (match.isNotEmpty) setState(() => _reciter = match.first);
  }

  void _savePosition() {
    final data = _mem[_currentPage];
    final surahName = data?.ayahs.isNotEmpty == true
        ? data!.surahs[data.ayahs.first.surah]?.englishName ?? ''
        : '';
    final surahNumber = data?.ayahs.isNotEmpty == true
        ? data!.ayahs.first.surah
        : null;
    OfflineCacheService.setJson(
      'quran_last_position',
      json.encode({
        'mode': 'mushaf',
        'editionId': widget.editionId,
        'page': _currentPage,
        'surahName': surahName,
        if (surahNumber != null) 'surahNumber': surahNumber,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  /// Loads (and caches) the text for a Mushaf page.
  Future<_PageData> _getPage(int page) async {
    if (_mem.containsKey(page)) return _mem[page]!;

    Map<String, dynamic>? raw;
    final cacheKey = 'mushaf_page_$page';
    final cached = await OfflineCacheService.getMap(cacheKey);
    if (cached != null && cached['data'] is Map) {
      raw = cached;
    } else {
      final res = await SecureHttpClient.instance
          .get('https://api.alquran.cloud/v1/page/$page/quran-uthmani');
      if (res.statusCode == 200 && res.data is Map) {
        raw = res.data as Map<String, dynamic>;
        OfflineCacheService.setJson(cacheKey, json.encode(raw));
      } else {
        throw Exception('Failed to load page $page');
      }
    }

    final data = raw['data'] as Map<String, dynamic>;
    final ayahList = (data['ayahs'] as List).map((a) {
      final m = a as Map<String, dynamic>;
      return _Ayah(
        number: m['number'] as int,
        surah: (m['surah'] as Map)['number'] as int,
        numberInSurah: m['numberInSurah'] as int,
        text: (m['text'] as String).trim(),
      );
    }).toList();

    final surahs = <int, _SurahInfo>{};
    final surahsRaw = data['surahs'];
    if (surahsRaw is Map) {
      surahsRaw.forEach((key, value) {
        final v = value as Map;
        final num = v['number'] as int;
        surahs[num] = _SurahInfo(
          num,
          (v['name'] ?? '').toString(),
          (v['englishName'] ?? '').toString(),
        );
      });
    }

    final pageData = _PageData(ayahList, surahs);
    _mem[page] = pageData;
    return pageData;
  }

  // ── Audio ──────────────────────────────────────────────────────────────
  Future<void> _playFrom(int page, int index, {bool skipBismillah = false}) async {
    final data = _mem[page] ?? await _getPage(page);
    if (index < 0 || index >= data.ayahs.length) return;

    final surahNo = data.ayahs[index].surah;
    final isFirstAyah = data.ayahs[index].numberInSurah == 1;
    final shouldPlayBismillah = !skipBismillah && isFirstAyah && surahNo != 9;

    setState(() {
      _isPlaying = true;
      _playingPage = page;
      _playingIndex = index;
      _isPlayingBismillah = shouldPlayBismillah;
    });
    try {
      if (shouldPlayBismillah) {
        await _audioPlayer.setUrl(_audioUrl(_reciter.id, 1));
      } else {
        await _audioPlayer.setUrl(_audioUrl(_reciter.id, data.ayahs[index].number));
      }
      _audioPlayer.play();
    } catch (_) {
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  Future<void> _advance() async {
    final page = _playingPage;
    if (page == null) return;
    final data = _mem[page];
    if (data == null) return;

    if (_playingIndex < data.ayahs.length - 1) {
      _playFrom(page, _playingIndex + 1);
    } else if (page < kMushafPageCount) {
      // Flow into the next page and keep reciting.
      await _pageController.animateToPage(
        page, // zero-based index of (page+1)
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      _playFrom(page + 1, 0);
    } else {
      _stop();
    }
  }

  void _stop() {
    _audioPlayer.stop();
    setState(() {
      _isPlaying = false;
      _playingPage = null;
      _isPlayingBismillah = false;
    });
  }

  void _togglePlay() {
    if (_isPlaying) {
      _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else if (_playingPage != null) {
      _audioPlayer.play();
      setState(() => _isPlaying = true);
    } else {
      _playFrom(_currentPage, 0);
    }
  }

  // ── Sheets ─────────────────────────────────────────────────────────────
  void _openAyahSheet(_Ayah ayah, _SurahInfo? surah) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _isDark ? MinaretTheme.darkSurface : Colors.white,
      builder: (ctx) => _AyahSheet(
        ayah: ayah,
        surah: surah,
        editionId: widget.editionId,
        onPlay: () {
          Navigator.pop(ctx);
          final page = _playingPageForAyah(ayah);
          if (page != null) _playFrom(page, _indexOf(page, ayah));
        },
      ),
    );
  }

  int? _playingPageForAyah(_Ayah ayah) {
    for (final e in _mem.entries) {
      if (e.value.ayahs.any((a) => a.number == ayah.number)) return e.key;
    }
    return _currentPage;
  }

  int _indexOf(int page, _Ayah ayah) {
    final data = _mem[page];
    if (data == null) return 0;
    final i = data.ayahs.indexWhere((a) => a.number == ayah.number);
    return i < 0 ? 0 : i;
  }

  /// Global ayah number currently being recited on [page], or null.
  int? _playingAyahNumberOn(int page) {
    if (_playingPage != page) return null;
    final ayahs = _mem[page]?.ayahs;
    if (ayahs == null || _playingIndex >= ayahs.length) return null;
    return ayahs[_playingIndex].number;
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AtelierLayout(
      child: SafeArea(
        child: Column(
          children: [
            const OfflineBanner(),
            _buildHeader(),
            Expanded(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: kMushafPageCount,
                  onPageChanged: (i) {
                    setState(() => _currentPage = i + 1);
                  },
                  itemBuilder: (context, i) {
                    final page = i + 1;
                    return _MushafPageContent(
                      page: page,
                      loader: _getPage,
                      reciter: _reciter,
                      playingAyahNumber: _playingAyahNumberOn(page),
                      onAyahTap: _openAyahSheet,
                      onLoaded: (p, d) {
                        if (p == _currentPage && mounted) setState(() {});
                      },
                    );
                  },
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final data = _mem[_currentPage];
    final surahName = data != null && data.ayahs.isNotEmpty
        ? data.surahs[data.ayahs.first.surah]?.name ?? widget.title ?? ''
        : widget.title ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 20, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, size: 16),
          ),
          Expanded(
            child: Text(
              surahName,
              textAlign: TextAlign.center,
              style: GoogleFonts.amiriQuran(
                fontSize: 18,
                color: MinaretTheme.gold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: MinaretTheme.dividerColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Play / pause
          IconButton(
            onPressed: _togglePlay,
            iconSize: 44,
            padding: EdgeInsets.zero,
            icon: Icon(
              _isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded,
              color: MinaretTheme.gold,
            ),
          ),
          // Page indicator
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_t(en: 'PAGE', ar: 'صفحة', ur: 'صفحہ', ru: 'СТР')} '
                '${_toArabicDigits(_currentPage)} / ${_toArabicDigits(kMushafPageCount)}',
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  letterSpacing: 1,
                  color: MinaretTheme.slate,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One swipeable Mushaf page. Lazy-loads its own text and renders surah-grouped
/// justified Uthmani text with ornate ayah markers.
class _MushafPageContent extends StatefulWidget {
  final int page;
  final Future<_PageData> Function(int page) loader;
  final Reciter reciter;
  final int? playingAyahNumber;
  final void Function(_Ayah ayah, _SurahInfo? surah) onAyahTap;
  final void Function(int page, _PageData data) onLoaded;

  const _MushafPageContent({
    required this.page,
    required this.loader,
    required this.reciter,
    required this.playingAyahNumber,
    required this.onAyahTap,
    required this.onLoaded,
  });

  @override
  State<_MushafPageContent> createState() => _MushafPageContentState();
}

class _MushafPageContentState extends State<_MushafPageContent>
    with AutomaticKeepAliveClientMixin {
  late Future<_PageData> _future;
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = widget.loader(widget.page).then((d) {
      widget.onLoaded(widget.page, d);
      return d;
    });
  }

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  Color get _ink => Theme.of(context).colorScheme.onSurface;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<_PageData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: AppLoadingIndicator(size: 18, strokeWidth: 1.5));
        }
        if (snap.hasError || !snap.hasData) {
          return _error();
        }
        return _buildPage(snap.data!);
      },
    );
  }

  Widget _error() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded,
                color: MinaretTheme.gold.withValues(alpha: 0.35), size: 30),
            const SizedBox(height: 14),
            Text(
              context.localText(
                en: 'Could not load this page',
                ar: 'تعذّر تحميل الصفحة',
                ur: 'صفحہ لوڈ نہیں ہوا',
                ru: 'Не удалось загрузить страницу',
              ),
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(fontSize: 11, color: MinaretTheme.slate),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => setState(() {
                _future = widget.loader(widget.page);
              }),
              style: OutlinedButton.styleFrom(
                foregroundColor: MinaretTheme.gold,
                side: const BorderSide(color: MinaretTheme.gold),
              ),
              child: Text(context.localText(
                  en: 'RETRY', ar: 'إعادة', ur: 'دوبارہ', ru: 'ПОВТОР')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_PageData data) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    // Group consecutive ayahs by surah so we can drop a header + bismillah
    // wherever a surah begins on this page.
    final segments = <Widget>[];
    var i = 0;
    while (i < data.ayahs.length) {
      final surahNo = data.ayahs[i].surah;
      final start = i;
      while (i < data.ayahs.length && data.ayahs[i].surah == surahNo) {
        i++;
      }
      final run = data.ayahs.sublist(start, i);
      final beginsHere = run.first.numberInSurah == 1;
      if (beginsHere) {
        segments.add(_surahHeader(data.surahs[surahNo], surahNo));
      }
      segments.add(_ayahBlock(run, beginsHere));
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...segments,
          const SizedBox(height: 18),
          Center(
            child: Text(
              _toArabicDigits(widget.page),
              style: GoogleFonts.amiriQuran(
                fontSize: 14,
                color: MinaretTheme.gold.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _surahHeader(_SurahInfo? info, int surahNo) {
    final showBismillah = surahNo != 9;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: MinaretTheme.gold.withValues(alpha: 0.4)),
              color: MinaretTheme.gold.withValues(alpha: 0.05),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_outline_rounded,
                    size: 12, color: MinaretTheme.gold.withValues(alpha: 0.7)),
                const SizedBox(width: 12),
                Text(
                  info?.name ?? '',
                  style: GoogleFonts.amiriQuran(
                    fontSize: 22,
                    color: MinaretTheme.gold,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.star_outline_rounded,
                    size: 12, color: MinaretTheme.gold.withValues(alpha: 0.7)),
              ],
            ),
          ),
          if (showBismillah)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Text(
                _kBismillah,
                textAlign: TextAlign.center,
                style: GoogleFonts.amiriQuran(
                  fontSize: 22,
                  color: _ink.withValues(alpha: 0.85),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ayahBlock(List<_Ayah> run, bool stripBismillah) {
    final spans = <InlineSpan>[];
    for (var j = 0; j < run.length; j++) {
      final ayah = run[j];
      var text = ayah.text;
      // The first ayah of most surahs carries Bismillah in the Uthmani text;
      // it is already shown in the header, so strip it here.
      if (j == 0 && stripBismillah && ayah.surah != 9) {
        text = text.replaceFirst(_kBismillah, '').trim();
      }
      final isPlaying = widget.playingAyahNumber == ayah.number;

      final recognizer = TapGestureRecognizer()
        ..onTap = () => widget.onAyahTap(ayah, null);
      _recognizers.add(recognizer);

      spans.add(TextSpan(
        text: '$text ',
        recognizer: recognizer,
        style: GoogleFonts.amiriQuran(
          fontSize: 24,
          height: 2.1,
          color: isPlaying ? MinaretTheme.gold : _ink,
          backgroundColor:
              isPlaying ? MinaretTheme.gold.withValues(alpha: 0.12) : null,
        ),
      ));
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _AyahMarker(number: ayah.numberInSurah, active: isPlaying),
      ));
      spans.add(const TextSpan(text: ' '));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text.rich(
        TextSpan(children: spans),
        textAlign: TextAlign.justify,
        textDirection: TextDirection.rtl,
      ),
    );
  }
}

class _AyahMarker extends StatelessWidget {
  final int number;
  final bool active;
  const _AyahMarker({required this.number, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active
            ? MinaretTheme.gold.withValues(alpha: 0.18)
            : MinaretTheme.gold.withValues(alpha: 0.06),
        border: Border.all(
          color: MinaretTheme.gold.withValues(alpha: active ? 0.7 : 0.35),
          width: 0.8,
        ),
      ),
      child: Text(
        _toArabicDigits(number),
        style: GoogleFonts.amiriQuran(
          fontSize: 11,
          color: MinaretTheme.gold,
          height: 1.0,
        ),
      ),
    );
  }
}

class _AyahSheet extends StatefulWidget {
  final _Ayah ayah;
  final _SurahInfo? surah;
  final String editionId;
  final VoidCallback onPlay;

  const _AyahSheet({
    required this.ayah,
    required this.surah,
    required this.editionId,
    required this.onPlay,
  });

  @override
  State<_AyahSheet> createState() => _AyahSheetState();
}

class _AyahSheetState extends State<_AyahSheet> {
  String? _translation;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadTranslation();
  }

  Future<void> _loadTranslation() async {
    final key = 'quran_trans_${widget.ayah.number}_${widget.editionId}';
    try {
      final cached = await OfflineCacheService.getMap(key);
      if (cached != null && cached['data'] is Map) {
        _apply((cached['data'] as Map)['text']?.toString());
        return;
      }
      final res = await SecureHttpClient.instance.get(
        'https://api.alquran.cloud/v1/ayah/${widget.ayah.number}/${widget.editionId}',
      );
      if (res.statusCode == 200 && res.data is Map) {
        OfflineCacheService.setJson(key, json.encode(res.data));
        _apply(((res.data as Map)['data'] as Map)['text']?.toString());
      } else {
        _apply(null);
      }
    } catch (_) {
      _apply(null);
    }
  }

  void _apply(String? text) {
    if (!mounted) return;
    setState(() {
      _translation = text;
      _failed = text == null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ref = widget.surah != null
        ? '${widget.surah!.englishName} · ${widget.ayah.numberInSurah}'
        : '${context.localText(en: 'Ayah', ar: 'آية', ur: 'آیت', ru: 'Аят')} '
            '${widget.ayah.numberInSurah}';

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 22,
        bottom: 22 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                ref.toUpperCase(),
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w800,
                  color: MinaretTheme.gold,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: widget.onPlay,
                icon: const Icon(Icons.play_arrow_rounded,
                    size: 18, color: MinaretTheme.gold),
                label: Text(
                  context.localText(
                      en: 'Play', ar: 'تشغيل', ur: 'چلائیں', ru: 'Играть'),
                  style: const TextStyle(color: MinaretTheme.gold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            widget.ayah.text,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: GoogleFonts.amiriQuran(
              fontSize: 24,
              height: 2.0,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 18),
          if (_loading)
            const Center(child: AppLoadingIndicator(size: 16, strokeWidth: 1.5))
          else if (_failed)
            Text(
              context.localText(
                en: 'Translation unavailable offline',
                ar: 'الترجمة غير متاحة دون اتصال',
                ur: 'ترجمہ آف لائن دستیاب نہیں',
                ru: 'Перевод недоступен офлайн',
              ),
              style: GoogleFonts.lato(
                fontSize: 13,
                color: MinaretTheme.slate,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Text(
              _translation ?? '',
              style: GoogleFonts.notoNaskhArabic(
                fontSize: 15,
                height: 1.7,
                color: isDark ? Colors.white70 : MinaretTheme.slate,
              ),
            ),
        ],
      ),
    );
  }
}
