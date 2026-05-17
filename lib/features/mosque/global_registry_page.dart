import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:minaret/l10n/generated/app_localizations.dart';

import '../../core/app_spacing.dart';
import '../../core/theme.dart';
import '../../widgets/premium_loading.dart';
import '../../widgets/atelier_layout.dart';
import 'details_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Hexagonal tiling background painter for mosque cards
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
      ..color = Colors.white.withOpacity(0.04)
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

class _GlobalRegistryPageState extends State<GlobalRegistryPage>
    with TickerProviderStateMixin {
  // search
  String _searchQuery = '';
  Timer? _debounce;
  static const _debounceDelay = Duration(milliseconds: 300); // Reduced for better responsiveness
  static const _maxSearches = 30;
  final _searchTs = <DateTime>[];

  // location
  Position? _position;

  // pagination
  static const _pageSize = 20; // Reduced for smoother loading
  final _docs = <QueryDocumentSnapshot>[];
  bool _hasMore = true;
  bool _loading = false;
  DocumentSnapshot? _lastDoc;

  // real stats from Firestore
  int _totalMosques   = 0;
  int _totalCountries = 0;
  int _totalVerified  = 0;
  bool _statsLoading  = true;

  // Performance optimizations
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _filteredDocs = [];
  List<String> _filteredDocIds = [];
  late AnimationController _animationController;

  // design colours — calmer, darker green matching the screenshot
  static const _cardBg     = Color(0xFF152B15);  // muted forest green
  static const _cardStroke = Color(0xFF1F3D1F);  // subtle border
  static const _gold       = Color(0xFFC9A84C);
  // active prayer: soft warm white-teal, not bright green
  static const _prayerOn   = Color(0xFF7ECBA1);  // calm sage highlight

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _initLocation();
    _fetchPage();
    _fetchStats();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Throttled scroll detection for better performance
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 300) {
      _fetchPage();
    }
  }

  Future<void> _fetchStats() async {
    try {
      // Simple query without complex where clauses to avoid index requirements
      final snap = await FirebaseFirestore.instance
          .collection('mosques')
          .limit(1000) // Limit to avoid excessive reads
          .get();

      int totalMosques = 0;
      int totalVerified = 0;
      final countries = <String>{};
      
      for (final doc in snap.docs) {
        final d = doc.data();
        // Skip restricted mosques in client-side filtering
        if (d['restricted'] == true) continue;
        
        totalMosques++;
        
        // Count verified mosques
        if (d['isVerified'] == true) totalVerified++;
        
        // Count unique countries
        final country = d['country']?.toString();
        if (country != null && country.isNotEmpty) {
          countries.add(country);
        }
      }

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
      // Set default values on error to prevent UI from breaking
      if (mounted) setState(() {
        _totalMosques   = 0;
        _totalCountries = 0;
        _totalVerified  = 0;
        _statsLoading   = false;
      });
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
    _filteredDocs.clear();
    _filteredDocIds.clear();
    
    for (final doc in _docs) {
      final m = doc.data() as Map<String, dynamic>;
      if (m['restricted'] == true) continue;
      final n = (m['name'] ?? '').toString().toLowerCase();
      final c = (m['city'] ?? '').toString().toLowerCase();
      if (n.contains(_searchQuery) || c.contains(_searchQuery)) {
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

  Future<void> _fetchPage() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      Query q = FirebaseFirestore.instance
          .collection('mosques')
          .orderBy('name')
          .limit(_pageSize);
      if (_lastDoc != null) q = q.startAfterDocument(_lastDoc!);
      final snap = await q.get();
      if (snap.docs.length < _pageSize) _hasMore = false;
      if (snap.docs.isNotEmpty) {
        _lastDoc = snap.docs.last;
        _docs.addAll(snap.docs);
        _updateFilteredDocs(); // Update filtered list when new data arrives
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
      body: AtelierLayout(
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
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, bool dark) {
    final l10n      = AppLocalizations.of(context)!;
    final textColor = dark ? Colors.white : Colors.black;
    final muted     = dark ? Colors.white38 : Colors.black38;
    final div       = dark ? Colors.white12 : Colors.black12;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(32, 64, 32, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand
          Text(
            'MINARET',
            style: GoogleFonts.montserrat(
              fontSize: 8,
              letterSpacing: 3,
              fontWeight: FontWeight.w800,
              color: MinaretTheme.gold,
            ),
          ),
          const SizedBox(height: 5),
          // Tagline
          Text(
            l10n.congregationArchive.toUpperCase(),
            style: GoogleFonts.montserrat(
              fontSize: 7,
              letterSpacing: 3,
              fontWeight: FontWeight.w700,
              color: muted,
            ),
          ),
          const SizedBox(height: 8),
          // GLOBAL — wide-tracked serif caps
          Text(
            l10n.globalHeader.toUpperCase(),
            style: MinaretTheme.heading.copyWith(
              fontSize: 14,
              letterSpacing: 10,
              fontWeight: FontWeight.w900,
              color: textColor,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          // Registry — large serif using app theme
          Text(
            l10n.registryHeader,
            style: MinaretTheme.heading.copyWith(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: textColor,
              height: 1,
            ),
          ),
          const SizedBox(height: 16),
          // ──◆── diamond divider with app theme gold
          Row(
            children: [
              Expanded(child: Container(height: 0.5, color: div)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Transform.rotate(
                  angle: math.pi / 4,
                  child: Container(width: 5, height: 5, color: MinaretTheme.gold.withOpacity(0.7)),
                ),
              ),
              Expanded(child: Container(height: 0.5, color: div)),
            ],
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
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: dark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.08),
          ),
        ),
        child: TextField(
          onChanged: _onSearch,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            color: dark ? Colors.white : Colors.black,
          ),
          decoration: InputDecoration(
            hintText: l10n?.searchGlobalHint ?? 'SEARCH MOSQUE OR CITY',
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

  // ── Stats row — real counts from Firestore ─────────────────────────────────
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
              child: RepaintBoundary(
                child: Container(
                  margin: EdgeInsets.only(right: i < items.length - 1 ? AppSpacing.sm : 0),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: dark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.05),
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
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── "ALL MOSQUES" label ────────────────────────────────────────────────────
  Widget _buildSectionLabel(bool dark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 10),
      child: Text(
        'ALL MOSQUES',
        style: GoogleFonts.montserrat(
          fontSize: 7,
          letterSpacing: 3,
          fontWeight: FontWeight.w700,
          color: dark ? Colors.white38 : Colors.black38,
        ),
      ),
    );
  }

  // ── Scrollable list ────────────────────────────────────────────────────────
  Widget _buildList(bool dark) {
    final l10n = AppLocalizations.of(context);
    // Use cached filtered list for better performance
    if (_filteredDocs.isEmpty && _docs.isEmpty) {
      return const Center(
        child: RepaintBoundary(
          child: PremiumLoadingScreen(type: LoadingType.pulse),
        ),
      );
    }

    if (_filteredDocs.isEmpty) {
      return Center(
        child: RepaintBoundary(
          child: Text(
            l10n?.noMatchesArchive ?? 'NO MATCHES FOUND',
            style: GoogleFonts.montserrat(
              fontSize: 7,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: dark ? Colors.white12 : Colors.black12,
            ),
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        // Performance: Throttle scroll-triggered fetches
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
          _fetchPage();
        }
        return false;
      },
      child: ListView.builder(
        // Performance: Use ClampingScrollPhysics for more predictable behavior
        physics: const ClampingScrollPhysics(),
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, 120),
        itemCount: _filteredDocs.length + (_hasMore ? 1 : 0),
        // Performance: Add cache extent for smoother scrolling
        cacheExtent: 500,
        itemBuilder: (ctx, i) {
          if (i >= _filteredDocs.length) {
            return RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: RepaintBoundary(
                            child: PremiumLoadingScreen(type: LoadingType.dots),
                          ),
                        )
                      : Text(
                          'LOAD MORE',
                          style: GoogleFonts.montserrat(
                            fontSize: 7,
                            letterSpacing: 2,
                            color: dark ? Colors.white24 : Colors.black26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            );
          }
          // Performance: Use RepaintBoundary for each card to isolate repaints
          return RepaintBoundary(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: _MosqueCard(
                data: _filteredDocs[i],
                distanceKm: _km(
                  (_filteredDocs[i]['lat'] as num?)?.toDouble(),
                  (_filteredDocs[i]['lng'] as num?)?.toDouble(),
                ),
                cardBg: _cardBg,
                cardStroke: _cardStroke,
                gold: _gold,
                prayerOn: _prayerOn,
                onTap: () => Navigator.push(
                  ctx,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => DetailsPage(
                      data: _filteredDocs[i],
                      docId: _filteredDocIds[i],
                    ),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      return SlideTransition(
                        position: animation.drive(
                          Tween(begin: const Offset(1.0, 0.0), end: Offset.zero),
                        ),
                        child: child,
                      );
                    },
                    transitionDuration: const Duration(milliseconds: 300),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mosque card widget with smooth animations
// ─────────────────────────────────────────────────────────────────────────────
class _MosqueCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final double distanceKm;
  final Color cardBg;
  final Color cardStroke;
  final Color gold;
  final Color prayerOn;
  final VoidCallback onTap;

  const _MosqueCard({
    required this.data,
    required this.distanceKm,
    required this.cardBg,
    required this.cardStroke,
    required this.gold,
    required this.prayerOn,
    required this.onTap,
  });

  @override
  State<_MosqueCard> createState() => _MosqueCardState();
}

class _MosqueCardState extends State<_MosqueCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Start with fade-in animation
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Firestore field key → display label
  static const _prayers = [
    ('fajr',    'FJR'),
    ('dhuhr',   'DHR'),
    ('asr',     'ASR'),
    ('maghrib', 'MGH'),
    ('isha',    'ISH'),
  ];

  @override
  Widget build(BuildContext context) {
    final isVerified   = widget.data['isVerified'] == true;
    final country      = (widget.data['country'] ?? 'COUNTRY').toString().toUpperCase();
    final name         = widget.data['name']?.toString() ?? 'Mosque';
    final city         = widget.data['city']?.toString() ?? '';
    final activePrayer = widget.data['activePrayer']?.toString(); // e.g. 'asr'

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: GestureDetector(
              onTapDown: (_) => _animationController.reverse(),
              onTapUp: (_) {
                _animationController.forward();
                widget.onTap();
              },
              onTapCancel: () => _animationController.forward(),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: widget.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: widget.cardStroke),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Hex pattern
                    Positioned.fill(
                      child: CustomPaint(painter: const _HexPainter()),
                    ),

                    // Content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Row 1: country + arrow ────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    country,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 7,
                                      letterSpacing: 2.5,
                                      fontWeight: FontWeight.w800,
                                      color: widget.gold,
                                    ),
                                  ),
                                  if (isVerified) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: widget.gold,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              // Arrow button
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Color(0xFFB3FFFFFF),
                                  size: 16,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // ── Row 2: mosque name ────────────────────────────────
                          Text(
                            name,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),

                          const SizedBox(height: 4),

                          // ── Row 3: city + distance ────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                city,
                                style: GoogleFonts.montserrat(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFB3FFFFFF),
                                ),
                              ),
                              if (widget.distanceKm > 0)
                                Text(
                                  '${widget.distanceKm.toStringAsFixed(1)} KM',
                                  style: GoogleFonts.ibmPlexMono(
                                    fontSize: 7,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFB3FFFFFF),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Thin divider
                          Container(
                            height: 0.5,
                            color: Colors.white.withOpacity(0.08),
                          ),

                          const SizedBox(height: 10),

                          // ── Row 4: prayer times ───────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: _prayers.map((prayer) {
                              final (key, label) = prayer;
                              final isActive = key == activePrayer;
                              final timeVal  = widget.data[key]?.toString() ?? '--:--';
                              return Column(
                                children: [
                                  Text(
                                    label,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 6,
                                      letterSpacing: 1.5,
                                      fontWeight: FontWeight.w700,
                                      color: isActive ? widget.prayerOn : Colors.white38,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    timeVal,
                                    style: GoogleFonts.ibmPlexMono(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isActive ? widget.prayerOn : Colors.white54,
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}