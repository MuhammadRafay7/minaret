import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:minaret/l10n/generated/app_localizations.dart';

import '../../core/app_spacing.dart';
import '../../core/theme.dart';
import '../../widgets/premium_loading.dart';
import '../../widgets/atelier_layout.dart';
import 'details_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Hexagonal tiling background painter
// ─────────────────────────────────────────────────────────────────────────────
class _HexPainter extends CustomPainter {
  const _HexPainter();

  static const double _r = 20.0;
  static const double _sqrt3 = 1.7320508;

  void _hexPath(Path path, Offset c) {
    for (int i = 0; i < 6; i++) {
      final a = math.pi / 180 * (60 * i - 30);
      final p = Offset(c.dx + _r * math.cos(a), c.dy + _r * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    final double colW = _r * 1.5;
    final double rowH = _r * _sqrt3;

    for (double x = -_r; x < size.width + _r; x += colW) {
      for (double y = -_r; y < size.height + _r; y += rowH) {
        final bool shifted = ((x / colW).round() % 2) == 1;
        final path = Path();
        _hexPath(path, Offset(x, y + (shifted ? rowH / 2 : 0)));
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────
class GlobalRegistryPage extends StatefulWidget {
  const GlobalRegistryPage({super.key});

  @override
  State<GlobalRegistryPage> createState() => _GlobalRegistryPageState();
}

class _GlobalRegistryPageState extends State<GlobalRegistryPage> {
  // search
  String _searchQuery = '';
  Timer? _debounce;
  static const _debounceDelay = Duration(milliseconds: 300);
  static const _maxSearches = 30;
  final _searchTs = <DateTime>[];

  // location
  Position? _position;

  // pagination — 20 most popular mosques per page
  static const _pageSize = 20;
  final _docs = <QueryDocumentSnapshot>[];
  bool _hasMore = true;
  bool _loading = false;
  DocumentSnapshot? _lastDoc;

  // stats
  int _totalMosques   = 0;
  int _totalCountries = 0;
  int _totalVerified  = 0;
  bool _statsLoading  = true;

  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _filteredDocs = [];
  List<String> _filteredDocIds = [];

  @override
  void initState() {
    super.initState();
    _initLocation();
    _fetchPage();
    _fetchStats();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  static const _statsCacheKey = 'registry_stats_v1';
  static const _statsCacheTsKey = 'registry_stats_ts_v1';
  static const _cacheTtlHours = 12;

  Future<void> _fetchStats() async {
    try {
      // Serve from device cache if fresh enough (saves 1000 Firestore reads).
      final prefs = await SharedPreferences.getInstance();
      final tsMs = prefs.getInt(_statsCacheTsKey) ?? 0;
      final ageHours = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(tsMs))
          .inHours;

      if (ageHours < _cacheTtlHours) {
        final cached = prefs.getString(_statsCacheKey);
        if (cached != null) {
          final d = jsonDecode(cached) as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              _totalMosques   = (d['m'] as num?)?.toInt() ?? 0;
              _totalCountries = (d['c'] as num?)?.toInt() ?? 0;
              _totalVerified  = (d['v'] as num?)?.toInt() ?? 0;
              _statsLoading   = false;
            });
          }
          return;
        }
      }

      // Cache miss — fetch from Firestore (at most once per 12 hours per device).
      final snap = await FirebaseFirestore.instance
          .collection('mosques')
          .limit(1000)
          .get();

      int totalMosques = 0;
      int totalVerified = 0;
      final countries = <String>{};

      for (final doc in snap.docs) {
        final d = doc.data();
        if (d['restricted'] == true) continue;
        totalMosques++;
        if (d['isVerified'] == true) totalVerified++;
        final country = d['country']?.toString();
        if (country != null && country.isNotEmpty) countries.add(country);
      }

      await prefs.setString(_statsCacheKey, jsonEncode({
        'm': totalMosques,
        'c': countries.length,
        'v': totalVerified,
      }));
      await prefs.setInt(
          _statsCacheTsKey, DateTime.now().millisecondsSinceEpoch);

      if (mounted) {
        setState(() {
          _totalMosques   = totalMosques;
          _totalCountries = countries.length;
          _totalVerified  = totalVerified;
          _statsLoading   = false;
        });
      }
    } catch (e) {
      debugPrint('Stats fetch: $e');
      if (mounted) {
        setState(() {
          _totalMosques   = 0;
          _totalCountries = 0;
          _totalVerified  = 0;
          _statsLoading   = false;
        });
      }
    }
  }

  bool _rateLimited() {
    final now = DateTime.now();
    _searchTs
      ..add(now)
      ..removeWhere((t) => now.difference(t).inMinutes > 0);
    return _searchTs.length > _maxSearches;
  }

  void _onSearch(String v) {
    if (_rateLimited()) return;
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      if (mounted) {
        setState(() {
          _searchQuery = v.toLowerCase().trim();
          _updateFilteredDocs();
        });
      }
    });
  }

  void _updateFilteredDocs() {
    _filteredDocs = [];
    _filteredDocIds = [];

    for (final doc in _docs) {
      final m = doc.data() as Map<String, dynamic>;
      if (m['restricted'] == true) continue;
      final n  = (m['name']    ?? '').toString().toLowerCase();
      final c  = (m['city']    ?? '').toString().toLowerCase();
      final co = (m['country'] ?? '').toString().toLowerCase();
      if (_searchQuery.isEmpty ||
          n.contains(_searchQuery) ||
          c.contains(_searchQuery) ||
          co.contains(_searchQuery)) {
        _filteredDocs.add(m);
        _filteredDocIds.add(doc.id);
      }
    }
  }

  Future<void> _initLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return;
      }
      if (perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 10),
      );
      if (mounted) setState(() => _position = pos);
    } catch (e) {
      debugPrint('Location: $e');
    }
  }

  double _km(double? lat, double? lng) {
    if (_position == null || lat == null || lng == null) return 0;
    return Geolocator.distanceBetween(
          _position!.latitude, _position!.longitude, lat, lng) /
        1000;
  }

  // Ordered by followerCount descending — most popular mosques first
  Future<void> _fetchPage() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      Query q = FirebaseFirestore.instance
          .collection('mosques')
          .orderBy('followerCount', descending: true)
          .limit(_pageSize);
      if (_lastDoc != null) q = q.startAfterDocument(_lastDoc!);
      final snap = await q.get();
      if (snap.docs.length < _pageSize) _hasMore = false;
      if (snap.docs.isNotEmpty) {
        _lastDoc = snap.docs.last;
        _docs.addAll(snap.docs);
        _updateFilteredDocs();
      }
    } catch (e) {
      debugPrint('Fetch: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          dark ? const Color(0xFF0D1117) : const Color(0xFFF0EDE4),
      body: SafeArea(
        child: AtelierLayout(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, dark),
              _buildSearch(dark),
              _buildStats(dark),
              _buildSectionLabel(dark),
              Expanded(child: _buildList(dark)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, bool dark) {
    final l10n      = AppLocalizations.of(context)!;
    final textColor = dark ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 24, 25, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.globalHeader.toUpperCase(),
            style: GoogleFonts.montserrat(
              fontSize: 9,
              letterSpacing: 3,
              fontWeight: FontWeight.w900,
              color: MinaretTheme.gold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.registryHeader,
            style: MinaretTheme.heading.copyWith(
              fontSize: 38,
              letterSpacing: 6,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 1,
            width: 30,
            color: MinaretTheme.gold.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────
  Widget _buildSearch(bool dark) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 20, AppSpacing.lg, 12),
      child: Container(
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: TextField(
          onChanged: _onSearch,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            color: dark ? Colors.white : Colors.black,
          ),
          decoration: InputDecoration(
            hintText: l10n?.searchGlobalHint ?? 'SEARCH MOSQUE, CITY OR COUNTRY',
            hintStyle: GoogleFonts.montserrat(
              fontSize: 8,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
              color: dark ? Colors.white24 : Colors.black26,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 16,
              color: dark ? Colors.white38 : Colors.black38,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          ),
        ),
      ),
    );
  }

  // ── Stats row ──────────────────────────────────────────────────────────────
  Widget _buildStats(bool dark) {
    final items = [
      (_statsLoading ? '—' : _totalMosques.toString(),   'MOSQUES'),
      (_statsLoading ? '—' : _totalCountries.toString(), 'COUNTRIES'),
      (_statsLoading ? '—' : _totalVerified.toString(),  'VERIFIED'),
    ];

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
        child: Row(
          children: List.generate(items.length, (i) {
            final (num, label) = items[i];
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < items.length - 1 ? AppSpacing.sm : 0),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: dark ? Colors.white12 : Colors.black12,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      num,
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: dark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: GoogleFonts.montserrat(
                        fontSize: 6,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                        color: dark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── Section label ──────────────────────────────────────────────────────────
  Widget _buildSectionLabel(bool dark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 10),
      child: Row(
        children: [
          Text(
            'TOP MOSQUES',
            style: GoogleFonts.montserrat(
              fontSize: 7,
              letterSpacing: 3,
              fontWeight: FontWeight.w700,
              color: dark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: MinaretTheme.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: MinaretTheme.gold.withValues(alpha: 0.28),
                width: 0.5,
              ),
            ),
            child: Text(
              'BY POPULARITY',
              style: GoogleFonts.montserrat(
                fontSize: 6,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
                color: MinaretTheme.gold.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Scrollable list ────────────────────────────────────────────────────────
  Widget _buildList(bool dark) {
    final l10n = AppLocalizations.of(context);

    if (_filteredDocs.isEmpty && _docs.isEmpty) {
      return const Center(
        child: RepaintBoundary(
          child: PremiumLoadingScreen(type: LoadingType.pulse),
        ),
      );
    }

    if (_filteredDocs.isEmpty) {
      return Center(
        child: Text(
          l10n?.noMatchesArchive ?? 'NO MATCHES FOUND',
          style: GoogleFonts.montserrat(
            fontSize: 7,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
            color: dark ? Colors.white12 : Colors.black12,
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const ClampingScrollPhysics(),
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, 120),
      itemCount: _filteredDocs.length + (_hasMore ? 1 : 0),
      cacheExtent: 500,
      itemBuilder: (ctx, i) {
        // Load More button at the end
        if (i >= _filteredDocs.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: GestureDetector(
                onTap: _loading ? null : _fetchPage,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 13),
                  decoration: BoxDecoration(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: dark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.1),
                    ),
                  ),
                  child: _loading
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: dark ? Colors.white38 : Colors.black38,
                          ),
                        )
                      : Text(
                          'LOAD MORE',
                          style: GoogleFonts.montserrat(
                            fontSize: 7,
                            letterSpacing: 2.5,
                            fontWeight: FontWeight.w700,
                            color: dark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                ),
              ),
            ),
          );
        }

        return RepaintBoundary(
          child: _MosqueCard(
            data: _filteredDocs[i],
            docId: _filteredDocIds[i],
            distanceKm: _km(
              (_filteredDocs[i]['lat'] as num?)?.toDouble(),
              (_filteredDocs[i]['lng'] as num?)?.toDouble(),
            ),
            onTap: () => Navigator.push(
              ctx,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => DetailsPage(
                  data: _filteredDocs[i],
                  docId: _filteredDocIds[i],
                ),
                transitionsBuilder: (_, animation, __, child) => SlideTransition(
                  position: animation.drive(
                    Tween(begin: const Offset(1.0, 0.0), end: Offset.zero),
                  ),
                  child: child,
                ),
                transitionDuration: const Duration(milliseconds: 300),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Registry mosque card — two-section design (header + prayer row)
// ─────────────────────────────────────────────────────────────────────────────
class _MosqueCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;
  final double distanceKm;
  final VoidCallback onTap;

  const _MosqueCard({
    required this.data,
    required this.docId,
    required this.distanceKm,
    required this.onTap,
  });

  @override
  State<_MosqueCard> createState() => _MosqueCardState();
}

class _MosqueCardState extends State<_MosqueCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  static const _gold     = Color(0xFFC9A84C);
  static const _prayerOn = Color(0xFF7ECBA1);

  static const _prayers = [
    ('fajr',    'FJR'),
    ('dhuhr',   'DHR'),
    ('asr',     'ASR'),
    ('maghrib', 'MGH'),
    ('isha',    'ISH'),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _fmtFollowers(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  String? _nextPrayerKey() {
    final now = DateTime.now();
    for (final (key, _) in _prayers) {
      final t = widget.data[key]?.toString() ?? '';
      if (t.isEmpty || t == '--:--') continue;
      final parts = t.split(':');
      if (parts.length != 2) continue;
      final dt = DateTime(now.year, now.month, now.day,
          int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
      if (dt.isAfter(now)) return key;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isVerified   = widget.data['isVerified'] == true;
    final country      = (widget.data['country'] ?? '').toString().toUpperCase();
    final name         = widget.data['name']?.toString() ?? 'Mosque';
    final city         = widget.data['city']?.toString() ?? '';
    final followers    = (widget.data['followerCount'] as num?)?.toInt() ?? 0;
    final activePrayer = widget.data['activePrayer']?.toString() ?? _nextPrayerKey();

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown:   (_) => _ctrl.forward(),
        onTapUp:     (_) { _ctrl.reverse(); widget.onTap(); },
        onTapCancel: ()  => _ctrl.reverse(),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1A3320), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header section ────────────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0B1E0F), Color(0xFF152B15)],
                  ),
                ),
                child: Stack(
                  children: [
                    const Positioned.fill(child: CustomPaint(painter: _HexPainter())),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // badges row + chevron
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Flexible(
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    if (country.isNotEmpty)
                                      _RegistryChip(
                                        text: country,
                                        textColor: _gold,
                                        borderColor: _gold.withValues(alpha: 0.35),
                                        bgColor: _gold.withValues(alpha: 0.1),
                                      ),
                                    if (isVerified)
                                      _RegistryChip(
                                        text: '✓  VERIFIED',
                                        textColor: Colors.white.withValues(alpha: 0.6),
                                        borderColor: Colors.white.withValues(alpha: 0.15),
                                        bgColor: Colors.white.withValues(alpha: 0.05),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white38,
                                  size: 16,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // mosque name
                          Text(
                            name,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // meta row: city · distance · followers
                          Wrap(
                            spacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (city.isNotEmpty)
                                _MetaItem(
                                  icon: Icons.location_on_outlined,
                                  text: city,
                                ),
                              if (widget.distanceKm > 0)
                                _MetaItem(
                                  icon: Icons.near_me_outlined,
                                  text: '${widget.distanceKm.toStringAsFixed(1)} km',
                                  mono: true,
                                ),
                              if (followers > 0)
                                _MetaItem(
                                  icon: Icons.people_outline_rounded,
                                  text: _fmtFollowers(followers),
                                  mono: true,
                                  color: _gold,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Prayer times row ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1D0E),
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _prayers.map((p) {
                    final (key, label) = p;
                    final isActive = key == activePrayer;
                    final t = widget.data[key]?.toString() ?? '--:--';
                    return _RegistryPrayerCell(
                      label: label,
                      time: t,
                      isActive: isActive,
                      prayerOn: _prayerOn,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small helpers shared by the registry card
// ─────────────────────────────────────────────────────────────────────────────

class _RegistryChip extends StatelessWidget {
  final String text;
  final Color textColor, borderColor, bgColor;

  const _RegistryChip({
    required this.text,
    required this.textColor,
    required this.borderColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Text(
          text,
          style: GoogleFonts.montserrat(
            fontSize: 7,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      );
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool mono;
  final Color? color;

  const _MetaItem({
    required this.icon,
    required this.text,
    this.mono = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white38;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: c),
        const SizedBox(width: 3),
        Text(
          text,
          style: (mono ? GoogleFonts.ibmPlexMono : GoogleFonts.montserrat)(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            color: c,
          ),
        ),
      ],
    );
  }
}

class _RegistryPrayerCell extends StatelessWidget {
  final String label, time;
  final bool isActive;
  final Color prayerOn;

  const _RegistryPrayerCell({
    required this.label,
    required this.time,
    required this.isActive,
    required this.prayerOn,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 6,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
              color: isActive ? prayerOn : Colors.white24,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: isActive
                ? const EdgeInsets.symmetric(horizontal: 5, vertical: 2)
                : EdgeInsets.zero,
            decoration: isActive
                ? BoxDecoration(
                    color: prayerOn.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: prayerOn.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  )
                : null,
            child: Text(
              time,
              style: GoogleFonts.ibmPlexMono(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                color: isActive ? prayerOn : Colors.white30,
              ),
            ),
          ),
        ],
      );
}
