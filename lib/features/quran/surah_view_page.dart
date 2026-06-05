import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:minaret/core/secure_http_client.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:minaret/core/app_spacing.dart';
import 'package:minaret/core/theme.dart';
import 'package:minaret/widgets/atelier_layout.dart';
import 'package:minaret/core/locale_format.dart';
import 'package:minaret/services/quran_download_service.dart';
import 'package:minaret/services/offline_cache_service.dart';
import 'package:minaret/features/quran/mushaf_view_page.dart' show Reciter, kReciters;

const String _kReciterPrefKey = 'mushaf_reciter';

String _audioUrl(Reciter r, int globalAyahNumber) =>
    'https://cdn.islamic.network/quran/audio/${r.bitrate}/${r.id}/$globalAyahNumber.mp3';

class SurahViewPage extends StatefulWidget {
  final int surahNumber;
  final String surahName;
  final String editionId;
  final int? initialAyahNumber;

  const SurahViewPage({
    super.key,
    required this.surahNumber,
    required this.surahName,
    required this.editionId,
    this.initialAyahNumber,
  });

  @override
  State<SurahViewPage> createState() => _SurahViewPageState();
}

class _SurahViewPageState extends State<SurahViewPage> {
  late Future<Map<String, dynamic>> _surahFuture;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _arabicAyahs = [];
  List<dynamic> _translationAyahs = [];
  List<dynamic> _audioAyahs = [];
  List<int> _filteredIndices = [];
  String _searchQuery = '';

  int _currentPlayingIndex = -1;
  bool _isPlayingFullSurah = false;
  bool _isPlayingBismillah = false;
  final Map<int, GlobalKey> _ayahKeys = {};
  int _lastVisibleAyahIndex = 0;

  Map<String, dynamic>? _lastListen;

  final String bismillahText = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

  Reciter _reciter = kReciters.first;

  @override
  void initState() {
    super.initState();
    _surahFuture = _fetchFullSurah();
    _scrollController.addListener(_onScroll);
    _loadReciter();
    _loadLastListen();

    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed &&
          _isPlayingFullSurah) {
        if (_isPlayingBismillah) {
          _isPlayingBismillah = false;
          _playAyah(0, isSequence: true);
        } else {
          _playNextAyah();
        }
      }
    });
  }

  void _scrollToInitialAyah() {
    if (widget.initialAyahNumber == null) return;
    final index = widget.initialAyahNumber! - 1;
    final key = _ayahKeys[index];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onScroll() {
    if (_arabicAyahs.isEmpty) return;
    int? first;
    _ayahKeys.forEach((i, key) {
      final ctx = key.currentContext;
      if (ctx == null) return;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final y = box.localToGlobal(Offset.zero).dy;
      if (y >= -50 && (first == null || i < first!)) first = i;
    });
    if (first != null) _lastVisibleAyahIndex = first!;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    if (_arabicAyahs.isNotEmpty) {
      OfflineCacheService.setJson(
        'quran_last_position',
        json.encode({
          'mode': 'surah',
          'surahNumber': widget.surahNumber,
          'surahName': widget.surahName,
          'editionId': widget.editionId,
          'ayahIndex': _lastVisibleAyahIndex,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        }),
      ); // fire-and-forget; Hive writes to memory immediately
    }
    _audioPlayer.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    final q = value.trim().toLowerCase();
    setState(() {
      _searchQuery = q;
      if (q.isEmpty) {
        _filteredIndices = List.generate(_arabicAyahs.length, (i) => i);
      } else {
        _filteredIndices = [];
        for (var i = 0; i < _arabicAyahs.length; i++) {
          final arabic = (_arabicAyahs[i]['text'] ?? '').toString().toLowerCase();
          final translation = i < _translationAyahs.length
              ? (_translationAyahs[i]['text'] ?? '').toString().toLowerCase()
              : '';
          final number = (i + 1).toString();
          if (arabic.contains(q) || translation.contains(q) || number == q) {
            _filteredIndices.add(i);
          }
        }
      }
    });
  }

  Future<Map<String, dynamic>> _fetchFullSurah() async {
    // 1. Check permanent offline downloads first
    final downloadService = Provider.of<QuranDownloadService>(context, listen: false);
    final offlineData = await downloadService.getOfflineSurah(widget.surahNumber, widget.editionId);
    if (offlineData != null) return offlineData;

    // 2. Check OfflineCacheService for cached data
    try {
      final cachedData = await OfflineCacheService.getMap('quran_surah_${widget.surahNumber}_${widget.editionId}');
      if (cachedData != null) return cachedData;
    } catch (e) {
      debugPrint("Offline cache check failed: $e");
    }

    // 3. Fetch from network
    final response = await SecureHttpClient.instance.get(
      'https://api.alquran.cloud/v1/surah/${widget.surahNumber}/editions/quran-uthmani,${widget.editionId},ar.alafasy',
    );

    if (response.statusCode == 200) {
      // Cache the response for offline use
      try {
        await OfflineCacheService.setJson(
          'quran_surah_${widget.surahNumber}_${widget.editionId}',
          json.encode(response.data),
        );
      } catch (e) {
        debugPrint("Failed to cache surah data: $e");
      }
      return response.data;
    }
    throw Exception('Failed to load Surah');
  }

  void _playAyah(int index, {bool isSequence = false}) async {
    if (index < 0 || index >= _audioAyahs.length) {
      setState(() {
        _isPlayingFullSurah = false;
        _currentPlayingIndex = -1;
      });
      return;
    }

    setState(() {
      _currentPlayingIndex = index;
      if (!isSequence) _isPlayingFullSurah = false;
    });

    _saveListen(index);

    final globalNumber = (_audioAyahs[index] is Map
            ? _audioAyahs[index]['number']
            : null) ??
        _arabicAyahs[index]['number'];
    await _audioPlayer.setUrl(_audioUrl(_reciter, globalNumber as int));
    _audioPlayer.play();
  }

  void _saveListen(int index) {
    final record = {
      'surahNumber': widget.surahNumber,
      'surahName': widget.surahName,
      'editionId': widget.editionId,
      'ayahIndex': index,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    OfflineCacheService.setJson('quran_last_listen', json.encode(record));
    if (mounted) setState(() => _lastListen = record);
  }

  Future<void> _loadLastListen() async {
    final l = await OfflineCacheService.getMap('quran_last_listen');
    if (mounted) setState(() => _lastListen = l);
  }

  void _resumeFromLastListen() {
    final l = _lastListen;
    if (l == null) return;
    final savedSurah = (l['surahNumber'] as int?) ?? 1;
    final savedAyahIdx = (l['ayahIndex'] as int?) ?? 0;
    if (savedSurah == widget.surahNumber &&
        savedAyahIdx < _audioAyahs.length) {
      _playAyah(savedAyahIdx);
      final key = _ayahKeys[savedAyahIdx];
      final ctx = key?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SurahViewPage(
            surahNumber: savedSurah,
            surahName: (l['surahName'] as String?) ?? '',
            editionId: widget.editionId,
            initialAyahNumber: savedAyahIdx + 1,
          ),
        ),
      );
    }
  }

  Future<void> _loadReciter() async {
    final saved = await OfflineCacheService.getJson(_kReciterPrefKey);
    if (saved == null || !mounted) return;
    final match = kReciters.where((r) => r.id == saved);
    if (match.isNotEmpty) setState(() => _reciter = match.first);
  }

  Future<void> _pickReciter() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showModalBottomSheet<Reciter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? MinaretTheme.darkSurface : Colors.white,
      builder: (ctx) => _ReciterSheet(current: _reciter),
    );
    if (picked == null || picked.id == _reciter.id) return;
    await _audioPlayer.stop();
    setState(() {
      _reciter = picked;
      _isPlayingFullSurah = false;
      _isPlayingBismillah = false;
      _currentPlayingIndex = -1;
    });
    OfflineCacheService.setJson(_kReciterPrefKey, picked.id);
  }

  void _playNextAyah() {
    if (_currentPlayingIndex < _audioAyahs.length - 1) {
      _playAyah(_currentPlayingIndex + 1, isSequence: true);
    } else {
      setState(() {
        _isPlayingFullSurah = false;
        _currentPlayingIndex = -1;
      });
    }
  }

  void _toggleFullSurah() async {
    if (_isPlayingFullSurah) {
      _audioPlayer.stop();
      setState(() {
        _isPlayingFullSurah = false;
        _currentPlayingIndex = -1;
        _isPlayingBismillah = false;
      });
    } else {
      setState(() => _isPlayingFullSurah = true);

      if (widget.surahNumber != 1 &&
          widget.surahNumber != 9 &&
          !_reciter.includesBismillah) {
        setState(() => _isPlayingBismillah = true);
        await _audioPlayer.setUrl(_audioUrl(_reciter, 1));
        _audioPlayer.play();
      } else {
        _playAyah(0, isSequence: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AtelierLayout(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _surahFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: MinaretTheme.gold,
                  strokeWidth: 1,
                ),
              );
            }

            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }

            final rawData = snapshot.data?['data'];
            if (rawData is! List || rawData.length < 3) {
              return _buildErrorState('Unexpected response format. Please retry.');
            }
            _arabicAyahs = (rawData[0] as Map?)?['ayahs'] as List? ?? [];
            _translationAyahs = (rawData[1] as Map?)?['ayahs'] as List? ?? [];
            _audioAyahs = (rawData[2] as Map?)?['ayahs'] as List? ?? [];
            if (_filteredIndices.length != _arabicAyahs.length && _searchQuery.isEmpty) {
              _filteredIndices = List.generate(_arabicAyahs.length, (i) => i);
            }

            if (widget.initialAyahNumber != null) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _scrollToInitialAyah(),
              );
            }

            final bool showHeaderBismillah =
                widget.surahNumber != 1 && widget.surahNumber != 9;

            return CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverAppBar(
                  expandedHeight: 120,
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      widget.surahName.toUpperCase(),
                      style: MinaretTheme.heading.copyWith(
                        fontSize: 14,
                        letterSpacing: 3,
                      ),
                    ),
                    centerTitle: true,
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 8, 28, 4),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF151B24)
                            : MinaretTheme.surface,
                        border: Border.all(color: MinaretTheme.dividerColor),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        cursorColor: MinaretTheme.gold,
                        cursorWidth: 1,
                        decoration: InputDecoration(
                          hintText: 'Search ayah by number or text...',
                          hintStyle: GoogleFonts.lato(
                            color: (isDark ? Colors.white70 : MinaretTheme.slate)
                                .withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: MinaretTheme.gold.withValues(alpha: 0.5),
                            size: 18,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear_rounded,
                                    size: 16,
                                    color: (isDark
                                            ? Colors.white70
                                            : MinaretTheme.slate)
                                        .withValues(alpha: 0.5),
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                )
                              : null,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 16),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ),

                SliverToBoxAdapter(child: _buildLastPausedBanner()),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _toggleFullSurah,
                            icon: Icon(
                              _isPlayingFullSurah
                                  ? Icons.stop_circle
                                  : Icons.play_circle_fill,
                              color: MinaretTheme.gold,
                            ),
                            label: Text(
                              _isPlayingFullSurah
                                  ? "STOP SURAH"
                                  : "PLAY FULL SURAH",
                              style: const TextStyle(
                                color: MinaretTheme.gold,
                                letterSpacing: 2,
                                fontSize: 12,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color:
                                    MinaretTheme.gold.withValues(alpha: 0.4),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.md),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Tooltip(
                          message: _reciter.name,
                          child: OutlinedButton(
                            onPressed: _pickReciter,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color:
                                    MinaretTheme.gold.withValues(alpha: 0.4),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: AppSpacing.md,
                              ),
                            ),
                            child: const Icon(
                              Icons.record_voice_over_rounded,
                              size: 18,
                              color: MinaretTheme.gold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (showHeaderBismillah)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                      child: Text(
                        bismillahText,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.amiri(
                          fontSize: 32,
                          color: _isPlayingBismillah
                              ? MinaretTheme.gold
                              : MinaretTheme.gold.withValues(alpha: 0.7),
                          shadows: _isPlayingBismillah
                              ? [
                                  Shadow(
                                    color: MinaretTheme.gold.withValues(alpha: 0.3),
                                    blurRadius: 20,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),

                if (_searchQuery.isNotEmpty && _filteredIndices.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'No ayah found',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            color: (isDark ? Colors.white70 : MinaretTheme.slate)
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  ),

                SliverList(
                  delegate: SliverChildBuilderDelegate((context, i) {
                    final index = _filteredIndices[i];
                    _ayahKeys[index] ??= GlobalKey();
                    String cleanText = _arabicAyahs[index]['text'];

                    if (index == 0 && showHeaderBismillah) {
                      cleanText = cleanText
                          .replaceFirst(bismillahText, '')
                          .trim();
                    }

                    return Container(
                      key: _ayahKeys[index],
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: MinaretTheme.dividerColor,
                            width: 0.5,
                          ),
                        ),
                        color: _currentPlayingIndex == index
                            ? MinaretTheme.gold.withValues(alpha: 0.05)
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Text(
                                LocaleFormat.localizedDigits(
                                  context,
                                  "${index + 1}",
                                ),
                                style: GoogleFonts.ibmPlexMono(
                                  fontSize: 11,
                                  color: MinaretTheme.gold,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: Icon(
                                  _currentPlayingIndex == index
                                      ? Icons.pause_circle
                                      : Icons.play_arrow_rounded,
                                  color: MinaretTheme.gold,
                                ),
                                onPressed: () => _playAyah(index),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            cleanText,
                            textAlign: TextAlign.right,
                            style: GoogleFonts.amiri(
                              fontSize: 26,
                              height: 2.0,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _translationAyahs[index]['text'],
                            style: GoogleFonts.notoNaskhArabic(
                              fontSize: 15,
                              color: isDark
                                  ? Colors.white70
                                  : MinaretTheme.slate,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    );
                  }, childCount: _filteredIndices.length),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLastPausedBanner() {
    final l = _lastListen;
    if (l == null) return const SizedBox.shrink();
    final savedSurah = (l['surahNumber'] as int?) ?? 0;
    final savedAyahIdx = (l['ayahIndex'] as int?) ?? 0;
    final surahName = (l['surahName'] as String? ?? '').trim();
    if (surahName.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 4),
      child: Material(
        color: MinaretTheme.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: _resumeFromLastListen,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(
              children: [
                const Icon(Icons.headphones_rounded,
                    size: 16, color: MinaretTheme.gold),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LAST PAUSED',
                        style: GoogleFonts.montserrat(
                          fontSize: 9,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w800,
                          color: MinaretTheme.gold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$surahName · Ayah ${savedAyahIdx + 1}',
                        style: GoogleFonts.lato(
                          fontSize: 12.5,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  savedSurah == widget.surahNumber
                      ? Icons.play_arrow_rounded
                      : Icons.chevron_right_rounded,
                  color: MinaretTheme.gold,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 40, color: Colors.white24),
          const SizedBox(height: 24),
          const Text(
            "FAILED TO LOAD",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: Colors.white,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Text(
              "Something went wrong while loading the Surah. Please check your connection and retry.",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          InkWell(
            onTap: () => setState(() {
              _surahFuture = _fetchFullSurah();
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: MinaretTheme.gold),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, size: 16, color: MinaretTheme.gold),
                  SizedBox(width: 8),
                  Text(
                    "RETRY",
                    style: TextStyle(
                      color: MinaretTheme.gold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
                  'SELECT RECITER',
                  style: GoogleFonts.montserrat(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.name,
                            style: GoogleFonts.montserrat(
                              fontSize: 13.5,
                              fontWeight:
                                  sel ? FontWeight.w800 : FontWeight.w700,
                              color: sel ? MinaretTheme.gold : null,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            r.arabicName,
                            style: GoogleFonts.amiri(
                              fontSize: 16,
                              color:
                                  MinaretTheme.gold.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
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
