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

  List<dynamic> _arabicAyahs = [];
  List<dynamic> _translationAyahs = [];
  List<dynamic> _audioAyahs = [];

  int _currentPlayingIndex = -1;
  bool _isPlayingFullSurah = false;
  bool _isPlayingBismillah = false;
  final Map<int, GlobalKey> _ayahKeys = {};

  final String bismillahText = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';
  final String bismillahAudioUrl =
      'https://cdn.islamic.network/quran/audio/128/ar.alafasy/1.mp3';

  @override
  void initState() {
    super.initState();
    _surahFuture = _fetchFullSurah();

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
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
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

    await _audioPlayer.setUrl(_audioAyahs[index]['audio']);
    _audioPlayer.play();
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

      if (widget.surahNumber != 1 && widget.surahNumber != 9) {
        setState(() => _isPlayingBismillah = true);
        await _audioPlayer.setUrl(bismillahAudioUrl);
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

            final data = snapshot.data?['data'] as List;
            _arabicAyahs = data[0]['ayahs'];
            _translationAyahs = data[1]['ayahs'];
            _audioAyahs = data[2]['ayahs'];

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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 10,
                    ),
                    child: OutlinedButton.icon(
                      onPressed: _toggleFullSurah,
                      icon: Icon(
                        _isPlayingFullSurah
                            ? Icons.stop_circle
                            : Icons.play_circle_fill,
                        color: MinaretTheme.gold,
                      ),
                      label: Text(
                        _isPlayingFullSurah ? "STOP SURAH" : "PLAY FULL SURAH",
                        style: const TextStyle(
                          color: MinaretTheme.gold,
                          letterSpacing: 2,
                          fontSize: 12,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: MinaretTheme.gold.withValues(alpha: 0.4),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      ),
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

                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
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
                  }, childCount: _arabicAyahs.length),
                ),
              ],
            );
          },
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
