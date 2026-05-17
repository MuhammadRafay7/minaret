import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'package:minaret/l10n/generated/app_localizations.dart';
import '../../core/app_spacing.dart';
import '../../core/constants/fiqh_constants.dart';
import '../../core/locale_format.dart';
import '../../core/location_service.dart';
import '../../core/theme.dart';
import '../../features/home/notifiers/home_notifier.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/atelier_layout.dart';
import '../../widgets/calculated_prayer_card.dart';
import '../../widgets/daily_hadith_card.dart';
import '../../widgets/enhanced_prayer_tracker_card.dart';
import '../../widgets/mosque_card.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/premium_loading.dart';
import '../../widgets/simple_filter_dialog.dart';
import '../../services/system_config_service.dart';

export '../../features/home/notifiers/home_notifier.dart' show SortType;

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HomeNotifier(),
      child: const _HomeView(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const Scaffold(body: PremiumLoadingScreen());

    return Consumer<HomeNotifier>(
      builder: (context, notifier, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final globalSettings = Provider.of<GlobalSettings?>(context);
        final features = globalSettings?.features;

        return AtelierLayout(
          child: Column(
            children: [
              const OfflineBanner(),
              const SizedBox(height: 55),
              _Header(notifier: notifier, l10n: l10n, isDark: isDark),
              Expanded(
                child: RefreshIndicator(
                  key: _refreshKey,
                  onRefresh: notifier.refresh,
                  color: MinaretTheme.emerald,
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.zero,
                    children: [
                      if (features?.enableHadith ?? true)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(25, 28, 25, 10),
                          child: DailyHadithCard(),
                        ),
                      if (features?.enablePrayerTracking ?? true)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(25, 0, 25, 10),
                          child: EnhancedPrayerTrackerCard(),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(25, 0, 25, 10),
                        child: CalculatedPrayerCard(position: notifier.position),
                      ),
                      if (notifier.isImam && notifier.prayerStats != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(25, 0, 25, 10),
                          child: _ImamStreakCard(stats: notifier.prayerStats!),
                        ),
                      _SearchAndFilters(
                        notifier: notifier,
                        l10n: l10n,
                        isDark: isDark,
                        searchController: _searchController,
                      ),
                      _MosqueList(notifier: notifier, l10n: l10n),
                      const SizedBox(height: 180),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.notifier,
    required this.l10n,
    required this.isDark,
  });

  final HomeNotifier notifier;
  final AppLocalizations l10n;
  final bool isDark;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return l10n.morningReflection;
    if (h < 17) return l10n.afternoonCongregation;
    return l10n.eveningDevotion;
  }

  String _hijriLine(BuildContext context) {
    final h = HijriCalendar.now();
    final day = LocaleFormat.localizedDigits(context, h.hDay.toString());
    final year = LocaleFormat.localizedDigits(context, h.hYear.toString());
    final code = Localizations.localeOf(context).languageCode;
    final rtl = code == 'ar' || code == 'ur';
    final raw = '$day ${h.longMonthName} $year AH';
    return rtl ? raw : raw.toUpperCase();
  }

  void _showCityPicker(BuildContext context) {
    final ctrl = TextEditingController();
    List<Map<String, dynamic>> results = [];
    bool searching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF151B24) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (_, setModal) => SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'SELECT LOCATION',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                    color: MinaretTheme.gold,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  style: GoogleFonts.montserrat(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search city (e.g. Lahore, Pakistan)',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: searching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: AppLoadingIndicator(size: 20),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.arrow_forward),
                            onPressed: () async {
                              if (ctrl.text.isEmpty) return;
                              setModal(() => searching = true);
                              final r = await LocationService.searchCities(ctrl.text);
                              setModal(() {
                                searching = false;
                                results = r;
                              });
                            },
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: Colors.grey.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: MinaretTheme.gold),
                    ),
                  ),
                  onSubmitted: (val) async {
                    if (val.isEmpty) return;
                    setModal(() => searching = true);
                    final r = await LocationService.searchCities(val);
                    setModal(() {
                      searching = false;
                      results = r;
                    });
                  },
                ),
                const SizedBox(height: 10),
                if (results.isNotEmpty)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx).size.height * 0.3),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: results.length,
                      itemBuilder: (_, i) {
                        final city = results[i];
                        return ListTile(
                          leading: const Icon(Icons.location_city,
                              color: MinaretTheme.gold),
                          title: Text(city['name'],
                              style: GoogleFonts.montserrat(fontSize: 14)),
                          onTap: () async {
                            await notifier.setManualLocation(
                                city['lat'], city['lng'], city['name']);
                            if (context.mounted) Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                if (results.isEmpty && !searching && ctrl.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text('No results found.',
                        style: GoogleFonts.montserrat(
                            fontSize: 12, color: Colors.grey)),
                  ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.my_location,
                      color: MinaretTheme.gold),
                  title: Text(
                    'Use Current Location (GPS)',
                    style: GoogleFonts.montserrat(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  onTap: () async {
                    await notifier.clearManualLocation();
                    if (context.mounted) Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(ctrl.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    final rtl = code == 'ar' || code == 'ur';
    String display(String v) => rtl ? v : v.toUpperCase();
    final subtitleColor =
        isDark ? Colors.white60 : MinaretTheme.slate.withOpacity(0.72);

    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 16, 25, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                display(_greeting()),
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  letterSpacing: 3,
                  color: MinaretTheme.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
              GestureDetector(
                onTap: () => _showCityPicker(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: MinaretTheme.gold.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 10, color: MinaretTheme.gold),
                      const SizedBox(width: 4),
                      Text(
                        notifier.manualCityName ?? 'GPS',
                        style: GoogleFonts.montserrat(
                          fontSize: 8,
                          color: MinaretTheme.gold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            display(notifier.isImam ? l10n.atelierTitle : l10n.minaretTitle),
            style: MinaretTheme.heading.copyWith(
              fontSize: 38,
              letterSpacing: 6,
              height: 1.1,
              color: isDark ? Colors.white : MinaretTheme.onyx,
            ),
          ),
          Text(
            _hijriLine(context),
            style: GoogleFonts.montserrat(
              fontSize: 9,
              letterSpacing: 1.6,
              color: subtitleColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search + Sort + Filter bar
// ─────────────────────────────────────────────────────────────────────────────

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.notifier,
    required this.l10n,
    required this.isDark,
    required this.searchController,
  });

  final HomeNotifier notifier;
  final AppLocalizations l10n;
  final bool isDark;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isDark ? const Color(0x1AFFFFFF) : MinaretTheme.dividerColor;
    final bgColor = isDark
        ? const Color(0xFF151B24)
        : MinaretTheme.surface.withOpacity(0.6);
    final code = Localizations.localeOf(context).languageCode;
    final rtl = code == 'ar' || code == 'ur';
    String display(String v) => rtl ? v : v.toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration:
                BoxDecoration(color: bgColor, border: Border.all(color: borderColor)),
            child: TextField(
              controller: searchController,
              onChanged: notifier.onSearchChanged,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: isDark ? Colors.white : MinaretTheme.onyx,
              ),
              decoration: InputDecoration(
                hintText: l10n.searchMosquesHint,
                hintStyle: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : MinaretTheme.slate,
                ),
                prefixIcon: Icon(Icons.search,
                    size: 20, color: MinaretTheme.gold.withOpacity(0.5)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
              ),
            ),
          ),
          const SizedBox(height: 22),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _SortChip(
                  label: display(l10n.nearestProximity),
                  type: SortType.proximity,
                  notifier: notifier,
                  isDark: isDark,
                ),
                const SizedBox(width: 10),
                _SortChip(
                  label: display(l10n.temporalOrder),
                  type: SortType.time,
                  notifier: notifier,
                  isDark: isDark,
                ),
                const SizedBox(width: 10),
                _SortChip(
                  label: display(l10n.favourite),
                  type: SortType.following,
                  notifier: notifier,
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              FilterButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => SimpleFilterDialog(
                    selectedRadiusKm: notifier.selectedRadiusKm,
                    selectedFiqh: notifier.selectedFiqh,
                    showRadiusFilter:
                        notifier.activeSort == SortType.proximity,
                    onRadiusChanged: notifier.setRadiusKm,
                    onFiqhChanged: notifier.setFiqh,
                  ),
                ),
                hasActiveFilters: notifier.hasActiveFilters,
              ),
              const Spacer(),
              if (notifier.hasActiveFilters)
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: MinaretTheme.gold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    _filterSummary(),
                    style: GoogleFonts.montserrat(
                      fontSize: 10.sp,
                      color: MinaretTheme.gold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _filterSummary() {
    final parts = <String>[];
    if (notifier.activeSort == SortType.proximity &&
        notifier.selectedRadiusKm != 3) {
      parts.add('${notifier.selectedRadiusKm.toStringAsFixed(0)}km');
    }
    if (notifier.selectedFiqh != null) {
      parts.add(FiqhConstants.labelFor(notifier.selectedFiqh));
    }
    return parts.join(' • ');
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.type,
    required this.notifier,
    required this.isDark,
  });

  final String label;
  final SortType type;
  final HomeNotifier notifier;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final selected = notifier.activeSort == type;
    final selectedColor = MinaretTheme.emerald;
    final unselectedBorder =
        isDark ? const Color(0x1AFFFFFF) : MinaretTheme.dividerColor;

    return GestureDetector(
      onTap: () => notifier.setActiveSort(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.transparent,
          border:
              Border.all(color: selected ? selectedColor : unselectedBorder),
        ),
        child: Text(
          label,
          style: GoogleFonts.montserrat(
            color: selected
                ? Colors.white
                : (isDark ? Colors.white60 : MinaretTheme.slate),
            fontSize: 10.5,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mosque list — reads pre-filtered list from notifier
// ─────────────────────────────────────────────────────────────────────────────

class _MosqueList extends StatelessWidget {
  const _MosqueList({required this.notifier, required this.l10n});

  final HomeNotifier notifier;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final code = Localizations.localeOf(context).languageCode;
    final rtl = code == 'ar' || code == 'ur';
    String display(String v) => rtl ? v : v.toUpperCase();

    if (notifier.isLoadingMosques) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: PremiumLoadingScreen(),
      );
    }

    if (notifier.hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Text(
            display('Could not load mosques'),
            style: GoogleFonts.montserrat(
              fontSize: 8,
              letterSpacing: 3,
              color: isDark ? Colors.white24 : Colors.black26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    final docs = notifier.filteredMosques;

    if (docs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Text(
            display(l10n.noMosquesFound),
            style: GoogleFonts.montserrat(
              fontSize: 8,
              letterSpacing: 3,
              color: isDark ? Colors.white24 : Colors.black26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
      itemCount: docs.length,
      itemBuilder: (_, i) {
        final doc = docs[i];
        final data = doc.data() as Map<String, dynamic>;
        return MosqueCard(
          data: data,
          docId: doc.id,
          distance: notifier.distanceKmForDoc(data).toStringAsFixed(1),
          isEditable: notifier.user?.uid == data['adminUid'],
          isFollowing: notifier.following.contains(doc.id),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Imam prayer streak card
// ─────────────────────────────────────────────────────────────────────────────

class _ImamStreakCard extends StatelessWidget {
  const _ImamStreakCard({required this.stats});

  final dynamic stats; // UserPrayerStats

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: MinaretTheme.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MinaretTheme.gold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined,
                  color: MinaretTheme.gold, size: 20),
              const SizedBox(width: 8),
              Text(
                'PRAYER STREAK',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MinaretTheme.gold,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              Text(
                'View Details',
                style: GoogleFonts.lato(
                    fontSize: 11,
                    color: MinaretTheme.gold,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios,
                  size: 12, color: MinaretTheme.gold),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Stat('Current Streak', '${stats.currentStreak}',
                    Icons.local_fire_department, MinaretTheme.emerald),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Stat('Longest Streak', '${stats.longestStreak}',
                    Icons.emoji_events, MinaretTheme.gold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Stat('Total Prayers', '${stats.totalPrayers}',
                    Icons.access_time, MinaretTheme.emeraldLight),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Stat(
                    'Completion Rate',
                    '${(stats.overallCompletionRate * 100).toInt()}%',
                    Icons.trending_up,
                    MinaretTheme.goldSoft),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.lato(
                    fontSize: 10,
                    color: MinaretTheme.slate,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.montserrat(
                fontSize: 16, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
