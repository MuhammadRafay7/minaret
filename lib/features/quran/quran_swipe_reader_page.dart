import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:minaret/core/theme.dart';
import 'package:minaret/core/locale_text.dart';
import 'package:minaret/core/secure_http_client.dart';
import 'package:minaret/widgets/atelier_layout.dart';
import 'package:minaret/widgets/offline_banner.dart';
import 'package:minaret/widgets/app_loading_indicator.dart';
import 'package:minaret/services/offline_cache_service.dart';

const String _kBismillah = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';
const String _kArabicSentinel = 'ARABIC'; // deck entry that shows Arabic only
const String _kDeckPrefKey = 'quran_deck_editions';
const String _kReciterPrefKey = 'mushaf_reciter';

/// RTL translation language codes (so the translation text aligns correctly).
const Set<String> _kRtlCodes = {'ar', 'ur', 'fa', 'ps', 'sd', 'ug'};

/// Default languages in the swipe deck (identifiers verified on alquran.cloud).
const List<String> _kDefaultDeck = [
  'en.sahih',
  'ur.jalandhry',
  'ru.kuliev',
  _kArabicSentinel,
  'fr.hamidullah',
  'id.indonesian',
  'tr.diyanet',
  'bn.bengali',
];

class Reciter {
  final String id;
  final String name;
  // cdn.islamic.network serves each reciter at a specific bitrate; mismatched
  // bitrates 403. Abdul Basit and Sudais are only available at 64 kbps.
  final int bitrate;
  // Most reciters' first-ayah audio for surahs 2..114 already begins with
  // the Basmala. Prepending another Bismillah produces a double recital.
  // Maher Al-Muaiqly is the one exception in our list.
  final bool includesBismillah;
  const Reciter(
    this.id,
    this.name, {
    this.bitrate = 128,
    this.includesBismillah = true,
  });
}

const List<Reciter> kReciters = [
  Reciter('ar.alafasy', 'Mishary Alafasy'),
  Reciter('ar.husary', 'Mahmoud Al-Husary'),
  Reciter('ar.abdulsamad', 'Abdul Basit', bitrate: 64),
  Reciter('ar.abdurrahmaansudais', 'Abdurrahman As-Sudais', bitrate: 64),
  Reciter('ar.mahermuaiqly', 'Maher Al-Muaiqly', includesBismillah: false),
  Reciter('ar.shaatree', 'Abu Bakr Ash-Shaatree'),
  Reciter('ar.hudhaify', 'Ali Al-Hudhaify'),
];

String _audioUrl(Reciter r, int globalAyah) =>
    'https://cdn.islamic.network/quran/audio/${r.bitrate}/${r.id}/$globalAyah.mp3';

String _stripControl(String s) =>
    s.replaceAll('﻿', '').replaceAll('‏', '').trim();

class _Lang {
  final String editionId; // _kArabicSentinel for Arabic-only
  final String label; // human language name (e.g. "English")
  final String native; // edition / translator name
  final String code; // iso language code

  const _Lang({
    required this.editionId,
    required this.label,
    required this.native,
    required this.code,
  });

  bool get isArabicOnly => editionId == _kArabicSentinel;
  bool get isRtl => _kRtlCodes.contains(code);
}

class _Ayah {
  final int number; // global ayah number
  final int numberInSurah;
  final String arabic;
  final String? translation;
  const _Ayah(this.number, this.numberInSurah, this.arabic, this.translation);
}

class _ReadingData {
  final String surahArabicName;
  final String surahEnglishName;
  final List<_Ayah> ayahs;
  const _ReadingData(this.surahArabicName, this.surahEnglishName, this.ayahs);
}

class QuranSwipeReaderPage extends StatefulWidget {
  const QuranSwipeReaderPage({super.key});

  @override
  State<QuranSwipeReaderPage> createState() => _QuranSwipeReaderPageState();
}

class _QuranSwipeReaderPageState extends State<QuranSwipeReaderPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  PageController? _pageController;

  // Language deck.
  final Map<String, _Lang> _langMeta = {}; // identifier -> meta (from API)
  List<_Lang> _deck = [];
  int _langIndex = 0;

  // Reading position.
  int _surahNumber = 1;

  // Caches.
  final Map<String, _ReadingData> _mem = {};
  List<dynamic> _surahList = []; // for the picker

  // Audio.
  Reciter _reciter = kReciters.first;
  List<int> _globals = []; // ordered global ayah numbers of current surah
  int? _playingGlobal;
  bool _isPlaying = false;
  bool _isPlayingBismillah = false;

  // Offline downloads — full editions cached in one request via /quran/{edition}.
  final Set<String> _downloadedEditions = {};
  final Set<String> _downloadingEditions = {};

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _audioPlayer.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed && _isPlaying) {
        if (_isPlayingBismillah) {
          _isPlayingBismillah = false;
          _playGlobal(_globals.first);
        } else {
          _advance();
        }
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _pageController?.dispose();
    _savePosition();
    super.dispose();
  }

  String _t({required String en, required String ar, required String ur, required String ru}) =>
      context.localText(en: en, ar: ar, ur: ur, ru: ru);

  Future<void> _bootstrap() async {
    await _loadEditionMeta();
    await _loadDeck();
    final reciter = await OfflineCacheService.getJson(_kReciterPrefKey);
    final pos = await OfflineCacheService.getMap('quran_last_position');
    final dl = await OfflineCacheService.getMap('quran_downloaded_editions');
    if (!mounted) return;
    setState(() {
      if (reciter != null) {
        final m = kReciters.where((r) => r.id == reciter);
        if (m.isNotEmpty) _reciter = m.first;
      }
      if (pos != null && pos['surahNumber'] is int) {
        _surahNumber = (pos['surahNumber'] as int).clamp(1, 114);
      }
      if (dl != null && dl['ids'] is List) {
        _downloadedEditions.addAll((dl['ids'] as List).cast<String>());
      }
      _pageController = PageController(initialPage: _langIndex, viewportFraction: 0.88);
    });
  }

  Map<String, dynamic> _resumeRecord() {
    // Pick a real translation edition (the resume handler opens SurahViewPage
    // which needs one) — skip the Arabic-only sentinel if it's the active card.
    String editionId = 'en.sahih';
    if (_deck.isNotEmpty) {
      final cur = _deck[_langIndex];
      if (!cur.isArabicOnly) {
        editionId = cur.editionId;
      } else {
        final fallback = _deck.firstWhere(
          (l) => !l.isArabicOnly,
          orElse: () => cur,
        );
        if (!fallback.isArabicOnly) editionId = fallback.editionId;
      }
    }
    String surahName = '';
    for (final entry in _mem.entries) {
      if (entry.key.startsWith('qsr_${_surahNumber}_')) {
        surahName = entry.value.surahEnglishName;
        break;
      }
    }
    int ayahIndex = 0;
    if (_playingGlobal != null && _globals.isNotEmpty) {
      final i = _globals.indexOf(_playingGlobal!);
      if (i >= 0) ayahIndex = i;
    }
    return {
      'mode': 'surah',
      'editionId': editionId,
      'surahNumber': _surahNumber,
      'surahName': surahName,
      'ayahIndex': ayahIndex,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  void _savePosition() {
    OfflineCacheService.setJson(
      'quran_last_position',
      json.encode(_resumeRecord()),
    );
  }

  void _saveListen() {
    OfflineCacheService.setJson(
      'quran_last_listen',
      json.encode(_resumeRecord()),
    );
  }

  // ── Edition metadata + deck ──────────────────────────────────────────────
  Future<void> _loadEditionMeta() async {
    List<dynamic>? data;
    final cached = await OfflineCacheService.getMap('quran_translation_editions');
    if (cached != null && cached['data'] is List) {
      data = cached['data'] as List;
    } else {
      try {
        final res = await SecureHttpClient.instance
            .get('https://api.alquran.cloud/v1/edition/type/translation');
        if (res.statusCode == 200 && res.data is Map) {
          data = (res.data as Map)['data'] as List;
          OfflineCacheService.setJson(
              'quran_translation_editions', json.encode(res.data));
        }
      } catch (_) {/* offline — defaults still render via fallback labels */}
    }
    if (data == null) return;
    for (final e in data) {
      final m = e as Map;
      _langMeta[m['identifier'] as String] = _Lang(
        editionId: m['identifier'] as String,
        label: _langName(m['language'] as String? ?? ''),
        native: (m['name'] ?? '').toString(),
        code: (m['language'] ?? '').toString(),
      );
    }
  }

  Future<void> _loadDeck() async {
    final saved = await OfflineCacheService.getMap(_kDeckPrefKey);
    final ids = (saved != null && saved['ids'] is List)
        ? (saved['ids'] as List).cast<String>()
        : _kDefaultDeck;
    _deck = ids.map(_resolveLang).toList();
    if (_deck.isEmpty) _deck = _kDefaultDeck.map(_resolveLang).toList();
    _langIndex = _langIndex.clamp(0, _deck.length - 1);
  }

  _Lang _resolveLang(String id) {
    if (id == _kArabicSentinel) {
      return const _Lang(
          editionId: _kArabicSentinel, label: 'Arabic', native: 'العربية', code: 'ar');
    }
    return _langMeta[id] ??
        _Lang(editionId: id, label: id.split('.').first.toUpperCase(), native: id, code: id.split('.').first);
  }


  // ── Data loading ─────────────────────────────────────────────────────────
  Future<_ReadingData> _load(int surah, _Lang lang) async {
    final key = 'qsr_${surah}_${lang.editionId}';
    if (_mem.containsKey(key)) return _mem[key]!;

    // 1. Prefer a downloaded full edition (offline).
    final offline = await _fromFullCache(surah, lang);
    if (offline != null) {
      _mem[key] = offline;
      return offline;
    }

    // 2. Per-surah cache, then network.
    Map<String, dynamic>? raw;
    final cached = await OfflineCacheService.getMap(key);
    if (cached != null && cached['data'] != null) {
      raw = cached;
    } else {
      final url = lang.isArabicOnly
          ? 'https://api.alquran.cloud/v1/surah/$surah/quran-uthmani'
          : 'https://api.alquran.cloud/v1/surah/$surah/editions/quran-uthmani,${lang.editionId}';
      final res = await SecureHttpClient.instance.get(url);
      if (res.statusCode == 200 && res.data is Map) {
        raw = res.data as Map<String, dynamic>;
        OfflineCacheService.setJson(key, json.encode(raw));
      } else {
        throw Exception('Failed to load surah $surah');
      }
    }

    final data = raw['data'];
    final Map arabicEd;
    Map? transEd;
    if (data is List) {
      arabicEd = data[0] as Map;
      if (data.length > 1) transEd = data[1] as Map;
    } else {
      arabicEd = data as Map; // arabic-only single edition
    }
    final result = _buildReadingData(surah, arabicEd, transEd);
    _mem[key] = result;
    return result;
  }

  /// Builds a [_ReadingData] from an Arabic edition surah object and an optional
  /// translation surah object (both share the alquran.cloud surah shape).
  _ReadingData _buildReadingData(int surah, Map arabicEd, Map? transEd) {
    final arAyahs = arabicEd['ayahs'] as List;
    final trAyahs = transEd?['ayahs'] as List?;
    final ayahs = <_Ayah>[];
    for (var i = 0; i < arAyahs.length; i++) {
      final a = arAyahs[i] as Map;
      final numInSurah = a['numberInSurah'] as int;
      var text = _stripControl(a['text'] as String);
      // Bismillah is rendered in the header, so strip it from ayah 1 of every
      // surah except Al-Fatiha (1, where it is ayah 1) and At-Tawbah (9, none).
      if (numInSurah == 1 && surah != 1 && surah != 9) {
        text = _stripControl(text.replaceFirst(_kBismillah, ''));
      }
      final tr = (trAyahs != null && i < trAyahs.length)
          ? (trAyahs[i] as Map)['text']?.toString()
          : null;
      ayahs.add(_Ayah(a['number'] as int, numInSurah, text, tr));
    }
    return _ReadingData(
      _stripControl((arabicEd['name'] ?? '').toString()),
      (arabicEd['englishName'] ?? '').toString(),
      ayahs,
    );
  }

  /// Reads a surah from downloaded full-edition caches, or null if not downloaded.
  Future<_ReadingData?> _fromFullCache(int surah, _Lang lang) async {
    final ar = await OfflineCacheService.getMap('qfull_quran-uthmani');
    if (ar == null || ar['data'] is! Map) return null;
    final arSurahs = (ar['data'] as Map)['surahs'] as List;
    if (surah - 1 >= arSurahs.length) return null;
    final arSurah = arSurahs[surah - 1] as Map;

    Map? trSurah;
    if (!lang.isArabicOnly) {
      final tr = await OfflineCacheService.getMap('qfull_${lang.editionId}');
      if (tr == null || tr['data'] is! Map) return null;
      final trSurahs = (tr['data'] as Map)['surahs'] as List;
      trSurah = trSurahs[surah - 1] as Map;
    }
    return _buildReadingData(surah, arSurah, trSurah);
  }

  // ── Downloads ──────────────────────────────────────────────────────────────
  bool _isDownloaded(_Lang lang) => _downloadedEditions.contains(lang.editionId);
  bool _isDownloading(_Lang lang) => _downloadingEditions.contains(lang.editionId);

  Future<void> _downloadEdition(_Lang lang) async {
    final id = lang.editionId;
    if (_downloadingEditions.contains(id) || _downloadedEditions.contains(id)) {
      return;
    }
    setState(() => _downloadingEditions.add(id));
    try {
      await _fetchFullEdition('quran-uthmani');
      if (!lang.isArabicOnly) await _fetchFullEdition(id);
      _downloadedEditions.add(id);
      OfflineCacheService.setJson('quran_downloaded_editions',
          json.encode({'ids': _downloadedEditions.toList()}));
    } catch (_) {/* leave un-downloaded; user can retry */} finally {
      if (mounted) setState(() => _downloadingEditions.remove(id));
    }
  }

  Future<void> _fetchFullEdition(String editionId) async {
    final key = 'qfull_$editionId';
    final cached = await OfflineCacheService.getMap(key);
    if (cached != null && cached['data'] != null) return;
    final res = await SecureHttpClient.instance
        .get('https://api.alquran.cloud/v1/quran/$editionId');
    if (res.statusCode == 200 && res.data is Map) {
      OfflineCacheService.setJson(key, json.encode(res.data));
    } else {
      throw Exception('Download failed for $editionId');
    }
  }

  // ── Audio ─────────────────────────────────────────────────────────────────
  /// Tap on a verse: toggle pause/resume if it's the current verse, else play it.
  void _onAyahTap(int global) {
    if (_playingGlobal == global) {
      if (_isPlaying) {
        _audioPlayer.pause();
        setState(() => _isPlaying = false);
      } else {
        _audioPlayer.play();
        setState(() => _isPlaying = true);
      }
    } else {
      _playGlobal(global);
    }
  }

  Future<void> _playGlobal(int global) async {
    if (_globals.isEmpty) return;
    setState(() {
      _playingGlobal = global;
      _isPlaying = true;
      _isPlayingBismillah = false;
    });
    _savePosition();
    _saveListen();
    try {
      await _audioPlayer.setUrl(_audioUrl(_reciter, global));
      _audioPlayer.play();
    } catch (_) {
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  /// Start full-surah playback. Prepends Bismillah (global ayah 1) for every
  /// surah except At-Tawbah (9) and Al-Fatiha (1, whose first ayah already is
  /// the Bismillah).
  Future<void> _playSurah() async {
    if (_globals.isEmpty) return;
    if (_surahNumber == 1 ||
        _surahNumber == 9 ||
        _reciter.includesBismillah) {
      _playGlobal(_globals.first);
      return;
    }
    setState(() {
      _playingGlobal = _globals.first;
      _isPlaying = true;
      _isPlayingBismillah = true;
    });
    try {
      await _audioPlayer.setUrl(_audioUrl(_reciter, 1));
      _audioPlayer.play();
    } catch (_) {
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  void _advance() {
    if (_playingGlobal == null) return;
    final i = _globals.indexOf(_playingGlobal!);
    if (i >= 0 && i < _globals.length - 1) {
      _playGlobal(_globals[i + 1]);
    } else {
      _stop();
    }
  }

  void _stop() {
    _audioPlayer.stop();
    setState(() {
      _isPlaying = false;
      _playingGlobal = null;
      _isPlayingBismillah = false;
    });
  }

  void _togglePlayAll() {
    if (_isPlaying) {
      _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else if (_playingGlobal != null) {
      _audioPlayer.play();
      setState(() => _isPlaying = true);
    } else if (_globals.isNotEmpty) {
      _playSurah();
    }
  }

  void _onSurahChanged(int surah) {
    _stop();
    setState(() {
      _surahNumber = surah;
      _globals = [];
    });
  }

  void _openFullReader(_Lang l) {
    // Pause carousel audio so the two players don't overlap.
    if (_isPlaying) _stop();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullSurahReaderPage(
          surah: _surahNumber,
          lang: l,
          loader: _load,
          reciter: _reciter,
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_pageController == null || _deck.isEmpty) {
      return const AtelierLayout(
        child: Center(child: AppLoadingIndicator(size: 20, strokeWidth: 1.5)),
      );
    }
    return AtelierLayout(
      child: SafeArea(
        child: Column(
          children: [
            const OfflineBanner(),
            _buildTopBar(),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _deck.length,
                onPageChanged: (i) => setState(() => _langIndex = i),
                itemBuilder: (context, i) => _buildCard(i),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        children: [
          // Surah selector
          Expanded(
            child: InkWell(
              onTap: _openSurahPicker,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book_rounded,
                        size: 18, color: MinaretTheme.gold),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        '${_t(en: 'Surah', ar: 'سورة', ur: 'سورہ', ru: 'Сура')} $_surahNumber',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.expand_more_rounded,
                        size: 18, color: MinaretTheme.slate),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: _reciter.name,
            onPressed: _pickReciter,
            icon: const Icon(
              Icons.record_voice_over_rounded,
              size: 18,
              color: MinaretTheme.gold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickReciter() async {
    final picked = await showModalBottomSheet<Reciter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _isDark ? MinaretTheme.darkSurface : Colors.white,
      builder: (ctx) => _ReciterSheet(current: _reciter),
    );
    if (picked == null || picked.id == _reciter.id) return;
    _stop();
    setState(() => _reciter = picked);
    OfflineCacheService.setJson(_kReciterPrefKey, picked.id);
  }

  /// A single swipeable language "card" — the surah read in one language, with a
  /// footer showing the language/translator and a Download button (Mawaqit-style).
  Widget _buildCard(int i) {
    final l = _deck[i];
    final active = i == _langIndex;
    return AnimatedScale(
      scale: active ? 1.0 : 0.93,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: active ? 1.0 : 0.45,
        duration: const Duration(milliseconds: 260),
        child: Container(
          margin: const EdgeInsets.fromLTRB(7, 10, 7, 12),
          clipBehavior: Clip.antiAlias,
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
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openFullReader(l),
                child: _LanguageReadingView(
                  key: ValueKey('${_surahNumber}_${l.editionId}'),
                  surah: _surahNumber,
                  lang: l,
                  loader: _load,
                  playingGlobal: _playingGlobal,
                  isPlaying: _isPlaying,
                  reciter: _reciter,
                  onPlay: _onAyahTap,
                  onLoaded: (surah, globals) {
                    if (surah == _surahNumber && _globals.isEmpty) {
                      _globals = globals;
                    }
                  },
                ),
              ),
            ),
              _cardFooter(l),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardFooter(_Lang l) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 14, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: MinaretTheme.dividerColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.isArabicOnly ? 'Arabic' : l.label,
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  (l.isArabicOnly ? 'Uthmani Script' : l.native).toUpperCase(),
                  style: GoogleFonts.cairo(
                    fontSize: 8.5,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600,
                    color: MinaretTheme.slate,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _downloadButton(l),
        ],
      ),
    );
  }

  Widget _downloadButton(_Lang l) {
    if (_isDownloading(l)) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: AppLoadingIndicator(size: 16, strokeWidth: 1.6),
      );
    }
    if (_isDownloaded(l)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(MinaretTheme.buttonRadius),
          border: Border.all(color: MinaretTheme.emerald.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_rounded, size: 14, color: MinaretTheme.emerald),
            const SizedBox(width: 6),
            Text(
              _t(en: 'SAVED', ar: 'محفوظ', ur: 'محفوظ', ru: 'СОХР'),
              style: GoogleFonts.montserrat(
                fontSize: 9,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
                color: MinaretTheme.emerald,
              ),
            ),
          ],
        ),
      );
    }
    return Material(
      color: MinaretTheme.emerald,
      borderRadius: BorderRadius.circular(MinaretTheme.buttonRadius),
      child: InkWell(
        onTap: () => _downloadEdition(l),
        borderRadius: BorderRadius.circular(MinaretTheme.buttonRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.download_rounded, size: 15, color: Colors.white),
              const SizedBox(width: 7),
              Text(
                _t(en: 'DOWNLOAD', ar: 'تنزيل', ur: 'ڈاؤن لوڈ', ru: 'СКАЧАТЬ'),
                style: GoogleFonts.montserrat(
                  fontSize: 9,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: MinaretTheme.dividerColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
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
            ),
          ),
          TextButton.icon(
            onPressed: _togglePlayAll,
            icon: Icon(
              _isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded,
              color: MinaretTheme.gold,
              size: 26,
            ),
            label: Text(
              _isPlaying
                  ? _t(en: 'PAUSE', ar: 'إيقاف', ur: 'روکیں', ru: 'ПАУЗА')
                  : _t(en: 'PLAY SURAH', ar: 'تشغيل', ur: 'سنیں', ru: 'СЛУШАТЬ'),
              style: GoogleFonts.montserrat(
                fontSize: 10,
                letterSpacing: 1,
                fontWeight: FontWeight.w800,
                color: MinaretTheme.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sheets ────────────────────────────────────────────────────────────────
  Future<void> _ensureSurahList() async {
    if (_surahList.isNotEmpty) return;
    final cached = await OfflineCacheService.getMap('quran_surahs_list');
    if (cached != null && cached['data'] is List) {
      _surahList = cached['data'] as List;
      return;
    }
    final res =
        await SecureHttpClient.instance.get('https://api.alquran.cloud/v1/surah');
    if (res.statusCode == 200 && res.data is Map) {
      _surahList = (res.data as Map)['data'] as List;
      OfflineCacheService.setJson('quran_surahs_list', json.encode(res.data));
    }
  }

  void _openSurahPicker() async {
    await _ensureSurahList();
    if (!mounted) return;
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _isDark ? MinaretTheme.darkSurface : Colors.white,
      builder: (ctx) => _SurahPickerSheet(
        surahs: _surahList,
        current: _surahNumber,
      ),
    );
    if (picked != null && picked != _surahNumber) _onSurahChanged(picked);
  }

  static String _langName(String code) {
    const names = {
      'en': 'English', 'ur': 'Urdu', 'ar': 'Arabic', 'ru': 'Russian',
      'fr': 'French', 'id': 'Indonesian', 'tr': 'Turkish', 'bn': 'Bengali',
      'es': 'Spanish', 'fa': 'Persian', 'zh': 'Chinese', 'de': 'German',
      'ml': 'Malayalam', 'hi': 'Hindi', 'ta': 'Tamil', 'nl': 'Dutch',
      'it': 'Italian', 'pt': 'Portuguese', 'sv': 'Swedish', 'sw': 'Swahili',
      'az': 'Azerbaijani', 'bs': 'Bosnian', 'sq': 'Albanian', 'cs': 'Czech',
      'ja': 'Japanese', 'ko': 'Korean', 'th': 'Thai', 'uz': 'Uzbek',
      'ha': 'Hausa', 'so': 'Somali', 'pl': 'Polish', 'ro': 'Romanian',
    };
    return names[code] ?? (code.isEmpty ? '—' : code.toUpperCase());
  }
}

/// One swipe page: the current surah rendered in one language
/// (Arabic line + that language's translation beneath each ayah).
class _LanguageReadingView extends StatefulWidget {
  final int surah;
  final _Lang lang;
  final Future<_ReadingData> Function(int surah, _Lang lang) loader;
  final int? playingGlobal;
  final bool isPlaying;
  final Reciter reciter;
  final void Function(int global) onPlay;
  final void Function(int surah, List<int> globals) onLoaded;

  const _LanguageReadingView({
    super.key,
    required this.surah,
    required this.lang,
    required this.loader,
    required this.playingGlobal,
    required this.isPlaying,
    required this.reciter,
    required this.onPlay,
    required this.onLoaded,
  });

  @override
  State<_LanguageReadingView> createState() => _LanguageReadingViewState();
}

class _LanguageReadingViewState extends State<_LanguageReadingView>
    with AutomaticKeepAliveClientMixin {
  late Future<_ReadingData> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = widget.loader(widget.surah, widget.lang).then((d) {
      widget.onLoaded(widget.surah, d.ayahs.map((a) => a.number).toList());
      return d;
    });
  }

  Color get _ink => Theme.of(context).colorScheme.onSurface;
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _secondary =>
      Theme.of(context).brightness == Brightness.dark ? Colors.white70 : MinaretTheme.slate;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<_ReadingData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: AppLoadingIndicator(size: 18, strokeWidth: 1.5));
        }
        if (snap.hasError || !snap.hasData) {
          return _error();
        }
        return _content(snap.data!);
      },
    );
  }

  Widget _error() => Center(
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
                  en: 'Could not load this surah',
                  ar: 'تعذّر تحميل السورة',
                  ur: 'سورہ لوڈ نہیں ہوا',
                  ru: 'Не удалось загрузить суру',
                ),
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(fontSize: 11, color: _secondary),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => setState(() {
                  _future = widget.loader(widget.surah, widget.lang);
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

  Widget _content(_ReadingData data) {
    final showBismillah = widget.surah != 1 && widget.surah != 9;
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
      itemCount: data.ayahs.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) return _header(data, data.ayahs.length, showBismillah);
        return _ayahTile(data.ayahs[i - 1]);
      },
    );
  }

  Widget _header(_ReadingData data, int ayahCount, bool showBismillah) {
    return Column(
      children: [
        const SizedBox(height: 18),
        // Elegant flourish: fading rules + diamonds flanking the surah name.
        Row(
          children: [
            Expanded(child: _hRule(fadeLeft: true)),
            const SizedBox(width: 12),
            _diamond(),
            const SizedBox(width: 12),
            Text(
              data.surahArabicName,
              textAlign: TextAlign.center,
              style: GoogleFonts.amiriQuran(
                fontSize: 27,
                color: _isDark ? MinaretTheme.goldSoft : MinaretTheme.gold,
                height: 1.2,
              ),
            ),
            const SizedBox(width: 12),
            _diamond(),
            const SizedBox(width: 12),
            Expanded(child: _hRule(fadeLeft: false)),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '${data.surahEnglishName.toUpperCase()}   ·   $ayahCount '
          '${context.localText(en: 'AYAT', ar: 'آية', ur: 'آیات', ru: 'АЯТОВ')}',
          style: GoogleFonts.cairo(
            fontSize: 9,
            letterSpacing: 2.2,
            fontWeight: FontWeight.w700,
            color: MinaretTheme.slate,
          ),
        ),
        if (showBismillah)
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 2),
            child: Text(
              _kBismillah,
              textAlign: TextAlign.center,
              style: GoogleFonts.amiriQuran(
                  fontSize: 22, color: _ink.withValues(alpha: 0.8)),
            ),
          ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _hRule({required bool fadeLeft}) => Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              MinaretTheme.gold.withValues(alpha: fadeLeft ? 0.0 : 0.4),
              MinaretTheme.gold.withValues(alpha: fadeLeft ? 0.4 : 0.0),
            ],
          ),
        ),
      );

  Widget _diamond() => Transform.rotate(
        angle: 0.785398, // 45°
        child: Container(
          width: 6,
          height: 6,
          color: MinaretTheme.gold.withValues(alpha: 0.6),
        ),
      );

  Widget _ayahTile(_Ayah ayah) => _VerseTile(
        ayah: ayah,
        lang: widget.lang,
        surah: widget.surah,
        highlighted: widget.playingGlobal == ayah.number,
        playing: widget.playingGlobal == ayah.number && widget.isPlaying,
        onTap: () => widget.onPlay(ayah.number),
      );
}

class _SurahPickerSheet extends StatefulWidget {
  final List<dynamic> surahs;
  final int current;
  const _SurahPickerSheet({required this.surahs, required this.current});

  @override
  State<_SurahPickerSheet> createState() => _SurahPickerSheetState();
}

class _SurahPickerSheetState extends State<_SurahPickerSheet> {
  final _search = TextEditingController();
  late List<dynamic> _filtered = widget.surahs;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    q = q.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.surahs
          : widget.surahs.where((s) {
              return (s['englishName'] ?? '').toString().toLowerCase().contains(q) ||
                  (s['name'] ?? '').toString().contains(q) ||
                  s['number'].toString() == q;
            }).toList();
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
                        en: 'SELECT SURAH',
                        ar: 'اختر سورة',
                        ur: 'سورہ منتخب کریں',
                        ru: 'ВЫБЕРИТЕ СУРУ'),
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w800,
                      color: MinaretTheme.gold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_filtered.length} / 114',
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 10,
                      color: MinaretTheme.slate,
                    ),
                  ),
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
                      en: 'Search name or number…',
                      ar: 'ابحث بالاسم أو الرقم…',
                      ur: 'نام یا نمبر تلاش کریں…',
                      ru: 'Поиск по имени или номеру…'),
                  hintStyle: GoogleFonts.lato(
                      fontSize: 13,
                      color: MinaretTheme.slate.withValues(alpha: 0.7)),
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 18,
                      color: MinaretTheme.gold.withValues(alpha: 0.6)),
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
                  final number = s['number'] as int;
                  final sel = number == widget.current;
                  final meccan =
                      (s['revelationType'] ?? '').toString().toLowerCase() ==
                          'meccan';
                  return InkWell(
                    onTap: () => Navigator.pop(context, number),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                      decoration: BoxDecoration(
                        color: sel
                            ? MinaretTheme.gold.withValues(alpha: 0.07)
                            : null,
                        border: Border(
                          bottom: BorderSide(
                              color: MinaretTheme.dividerColor, width: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Diamond number badge
                          SizedBox(
                            width: 38,
                            height: 38,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Transform.rotate(
                                  angle: 0.785398,
                                  child: Container(
                                    width: 27,
                                    height: 27,
                                    decoration: BoxDecoration(
                                      color: MinaretTheme.gold.withValues(
                                          alpha: sel ? 0.16 : 0.07),
                                      border: Border.all(
                                          color: MinaretTheme.gold
                                              .withValues(alpha: 0.3),
                                          width: 0.8),
                                    ),
                                  ),
                                ),
                                Text('$number',
                                    style: GoogleFonts.ibmPlexMono(
                                        fontSize: 11,
                                        color: MinaretTheme.gold,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (s['englishName'] ?? '').toString(),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 13.5,
                                    fontWeight:
                                        sel ? FontWeight.w800 : FontWeight.w700,
                                    color: sel ? MinaretTheme.gold : null,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Icon(
                                      meccan
                                          ? Icons.brightness_2_outlined
                                          : Icons.location_city_rounded,
                                      size: 10,
                                      color: MinaretTheme.slate
                                          .withValues(alpha: 0.7),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${(s['revelationType'] ?? '').toString().toUpperCase()}   ·   ${s['numberOfAyahs']} ${context.localText(en: 'AYAT', ar: 'آية', ur: 'آیات', ru: 'АЯТ')}',
                                      style: GoogleFonts.cairo(
                                        fontSize: 8.5,
                                        letterSpacing: 1.2,
                                        fontWeight: FontWeight.w600,
                                        color: MinaretTheme.slate,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            (s['name'] ?? '').toString(),
                            style: GoogleFonts.amiriQuran(
                                fontSize: 18, color: MinaretTheme.gold),
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

TextStyle _translationStyleFor(_Lang lang, Color color) {
  // Arabic-script languages render well with Noto Naskh; Latin/Cyrillic with
  // Lato; everything else falls back to the platform font for full coverage.
  if (lang.isRtl) {
    return GoogleFonts.notoNaskhArabic(fontSize: 15.5, height: 2.0, color: color);
  }
  const latin = {'en', 'fr', 'id', 'tr', 'es', 'de', 'nl', 'it', 'pt', 'ru'};
  if (latin.contains(lang.code)) {
    return GoogleFonts.lato(fontSize: 15, height: 1.85, color: color);
  }
  return TextStyle(fontSize: 15, height: 1.85, color: color);
}

/// Shared verse row — used by both the carousel card and the full-screen reader
/// so they never drift visually.
class _VerseTile extends StatelessWidget {
  final _Ayah ayah;
  final _Lang lang;
  final int surah;
  final bool highlighted; // this ayah is the current one (tint + gold)
  final bool playing; // audio is actively playing this ayah (pause icon)
  final VoidCallback onTap; // toggles play/pause for this ayah

  const _VerseTile({
    required this.ayah,
    required this.lang,
    required this.surah,
    required this.highlighted,
    required this.playing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark ? Colors.white70 : MinaretTheme.slate;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 22, 6, 20),
      decoration: BoxDecoration(
        color: highlighted ? MinaretTheme.gold.withValues(alpha: 0.05) : null,
        border: Border(
          bottom: BorderSide(color: MinaretTheme.dividerColor, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ayah.arabic,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: GoogleFonts.amiriQuran(
              fontSize: 26,
              height: 2.3,
              color:
                  highlighted ? MinaretTheme.gold : ink.withValues(alpha: 0.92),
            ),
          ),
          if (ayah.translation != null) ...[
            const SizedBox(height: 16),
            Text(
              ayah.translation!,
              textAlign: lang.isRtl ? TextAlign.right : TextAlign.left,
              textDirection: lang.isRtl ? TextDirection.rtl : TextDirection.ltr,
              style: _translationStyleFor(lang, secondary),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: MinaretTheme.gold
                      .withValues(alpha: highlighted ? 0.16 : 0.07),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: MinaretTheme.gold.withValues(alpha: 0.25),
                      width: 0.7),
                ),
                child: Text(
                  '$surah:${ayah.numberInSurah}',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 9.5,
                    color: MinaretTheme.gold,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 20,
                    color: highlighted
                        ? MinaretTheme.gold
                        : secondary.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Full-screen reading of one surah in one language — opened by tapping a card.
/// Self-contained audio (its own player) so it doesn't fight the carousel.
class _FullSurahReaderPage extends StatefulWidget {
  final int surah;
  final _Lang lang;
  final Future<_ReadingData> Function(int surah, _Lang lang) loader;
  final Reciter reciter;

  const _FullSurahReaderPage({
    required this.surah,
    required this.lang,
    required this.loader,
    required this.reciter,
  });

  @override
  State<_FullSurahReaderPage> createState() => _FullSurahReaderPageState();
}

class _FullSurahReaderPageState extends State<_FullSurahReaderPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  late Future<_ReadingData> _future;
  List<int> _globals = [];
  int? _playingGlobal;
  bool _isPlaying = false;
  bool _isPlayingBismillah = false;

  @override
  void initState() {
    super.initState();
    _future = widget.loader(widget.surah, widget.lang).then((d) {
      _globals = d.ayahs.map((a) => a.number).toList();
      return d;
    });
    _audioPlayer.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed && _isPlaying) {
        if (_isPlayingBismillah) {
          _isPlayingBismillah = false;
          _playGlobal(_globals.first);
        } else {
          _advance();
        }
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _onAyahTap(int global) {
    if (_playingGlobal == global) {
      // Toggle pause/resume on the verse already loaded.
      if (_isPlaying) {
        _audioPlayer.pause();
        setState(() => _isPlaying = false);
      } else {
        _audioPlayer.play();
        setState(() => _isPlaying = true);
      }
    } else {
      _playGlobal(global);
    }
  }

  Future<void> _playGlobal(int global) async {
    if (_globals.isEmpty) return;
    setState(() {
      _playingGlobal = global;
      _isPlaying = true;
      _isPlayingBismillah = false;
    });
    try {
      await _audioPlayer.setUrl(_audioUrl(widget.reciter, global));
      _audioPlayer.play();
    } catch (_) {
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  /// Start full-surah playback. Prepends Bismillah (global ayah 1) for every
  /// surah except At-Tawbah (9) and Al-Fatiha (1, whose first ayah already is
  /// the Bismillah).
  Future<void> _playSurah() async {
    if (_globals.isEmpty) return;
    if (widget.surah == 1 ||
        widget.surah == 9 ||
        widget.reciter.includesBismillah) {
      _playGlobal(_globals.first);
      return;
    }
    setState(() {
      _playingGlobal = _globals.first;
      _isPlaying = true;
      _isPlayingBismillah = true;
    });
    try {
      await _audioPlayer.setUrl(_audioUrl(widget.reciter, 1));
      _audioPlayer.play();
    } catch (_) {
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  void _advance() {
    final i = _globals.indexOf(_playingGlobal ?? -1);
    if (i >= 0 && i < _globals.length - 1) {
      _playGlobal(_globals[i + 1]);
    } else {
      _audioPlayer.stop();
      setState(() {
        _isPlaying = false;
        _playingGlobal = null;
        _isPlayingBismillah = false;
      });
    }
  }

  void _togglePlayAll() {
    if (_isPlaying) {
      _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else if (_playingGlobal != null) {
      _audioPlayer.play();
      setState(() => _isPlaying = true);
    } else if (_globals.isNotEmpty) {
      _playSurah();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AtelierLayout(
      child: SafeArea(
        child: FutureBuilder<_ReadingData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: AppLoadingIndicator(size: 20, strokeWidth: 1.5));
            }
            if (snap.hasError || !snap.hasData) {
              return Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go back'),
                ),
              );
            }
            final data = snap.data!;
            final showBismillah = widget.surah != 1 && widget.surah != 9;
            return Column(
              children: [
                _header(data, isDark),
                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                    itemCount: data.ayahs.length + (showBismillah ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (showBismillah && i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 14),
                          child: Text(
                            _kBismillah,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.amiriQuran(
                              fontSize: 24,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.8),
                            ),
                          ),
                        );
                      }
                      final ayah = data.ayahs[i - (showBismillah ? 1 : 0)];
                      return _VerseTile(
                        ayah: ayah,
                        lang: widget.lang,
                        surah: widget.surah,
                        highlighted: _playingGlobal == ayah.number,
                        playing: _playingGlobal == ayah.number && _isPlaying,
                        onTap: () => _onAyahTap(ayah.number),
                      );
                    },
                  ),
                ),
                _bottomBar(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(_ReadingData data, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: MinaretTheme.dividerColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, size: 16),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.surahArabicName,
                  style: GoogleFonts.amiriQuran(
                    fontSize: 19,
                    color: isDark ? MinaretTheme.goldSoft : MinaretTheme.gold,
                  ),
                ),
                Text(
                  '${data.surahEnglishName.toUpperCase()}  ·  '
                  '${widget.lang.isArabicOnly ? 'ARABIC' : widget.lang.label.toUpperCase()}',
                  style: GoogleFonts.cairo(
                    fontSize: 8.5,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w700,
                    color: MinaretTheme.slate,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: MinaretTheme.dividerColor, width: 0.5),
        ),
      ),
      child: Center(
        child: TextButton.icon(
          onPressed: _togglePlayAll,
          icon: Icon(
            _isPlaying
                ? Icons.pause_circle_filled_rounded
                : Icons.play_circle_fill_rounded,
            color: MinaretTheme.gold,
            size: 28,
          ),
          label: Text(
            _isPlaying
                ? context.localText(
                    en: 'PAUSE', ar: 'إيقاف', ur: 'روکیں', ru: 'ПАУЗА')
                : context.localText(
                    en: 'PLAY SURAH', ar: 'تشغيل', ur: 'سنیں', ru: 'СЛУШАТЬ'),
            style: GoogleFonts.montserrat(
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
              color: MinaretTheme.gold,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReciterSheet extends StatelessWidget {
  final Reciter current;
  const _ReciterSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 14),
            decoration: BoxDecoration(
              color: MinaretTheme.slate.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
            child: Row(
              children: [
                Text(
                  context.localText(
                    en: 'SELECT RECITER',
                    ar: 'اختر القارئ',
                    ur: 'قاری منتخب کریں',
                    ru: 'ВЫБЕРИТЕ ЧТЕЦА',
                  ),
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w800,
                    color: MinaretTheme.gold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...kReciters.map((r) {
            final sel = r.id == current.id;
            return InkWell(
              onTap: () => Navigator.pop(context, r),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                decoration: BoxDecoration(
                  color: sel
                      ? MinaretTheme.gold.withValues(alpha: 0.07)
                      : null,
                  border: Border(
                    bottom: BorderSide(
                      color: MinaretTheme.dividerColor,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      sel
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 16,
                      color: sel
                          ? MinaretTheme.gold
                          : MinaretTheme.slate.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        r.name,
                        style: GoogleFonts.montserrat(
                          fontSize: 13.5,
                          fontWeight:
                              sel ? FontWeight.w800 : FontWeight.w700,
                          color: sel ? MinaretTheme.gold : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
        ],
        ),
      ),
    );
  }
}

