import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:minaret/core/secure_http_client.dart';

import 'package:minaret/core/theme.dart';
import 'package:minaret/widgets/app_loading_indicator.dart';
import 'package:minaret/features/hadith/hadith_chapters_page.dart';

// ── Module-level cache so the hadith survives widget rebuilds ────────────────
// Cache is keyed by slot index (0–4) so each of the 5 daily slots is stored.
final Map<int, Map<String, dynamic>> _slotCache = {};
DateTime? _cacheDate;

/// Returns which of the 5 daily slots is currently active.
/// Slots change every (24 / 5) = ~4.8 hours:
///   slot 0 → 00:00–04:47
///   slot 1 → 04:48–09:35
///   slot 2 → 09:36–14:23
///   slot 3 → 14:24–19:11
///   slot 4 → 19:12–23:59
int _currentSlot() {
  final now = DateTime.now();
  final minutesInDay = now.hour * 60 + now.minute;
  const totalMinutes = 24 * 60;
  return (minutesInDay * 5) ~/ totalMinutes;
}

/// Returns a sequential hadith index for the given slot on the given day.
/// Index advances by 1 for every slot across every day, cycling through
/// the full collection.
///
///   global slot = dayOfYear * 5 + slotIndex
///   hadith index = globalSlot % totalCount
int _hadithIndexForSlot(int totalCount, int dayOfYear, int slot) {
  final globalSlot = dayOfYear * 5 + slot;
  return globalSlot % totalCount;
}

class DailyHadithCard extends StatefulWidget {
  const DailyHadithCard({super.key});

  @override
  State<DailyHadithCard> createState() => _DailyHadithCardState();
}

class _DailyHadithCardState extends State<DailyHadithCard> {
  late Future<Map<String, dynamic>> _hadithFuture;

  @override
  void initState() {
    super.initState();
    _hadithFuture = _getDailyHadith();
  }

  Future<Map<String, dynamic>> _getDailyHadith() async {
    final today = DateTime.now();
    final slot = _currentSlot();

    // Return cache if it was fetched today AND the slot hasn't changed
    final cacheValid =
        _slotCache.containsKey(slot) &&
        _cacheDate != null &&
        _cacheDate!.year == today.year &&
        _cacheDate!.month == today.month &&
        _cacheDate!.day == today.day;

    if (cacheValid) return _slotCache[slot]!;

    return _fetchHadithForSlot(slot);
  }

  Future<Map<String, dynamic>> _fetchHadithForSlot(int slot) async {
    try {
      final response = await SecureHttpClient.instance.get(
        'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/eng-bukhari.min.json',
      );

      if (response.statusCode == 200 &&
          response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final all = data['hadiths'];
        if (all is! List || all.isEmpty) throw Exception('hadiths key missing or empty');

        final now = DateTime.now();
        final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
        final index = _hadithIndexForSlot(all.length, dayOfYear, slot);

        final hadith = all[index] as Map<String, dynamic>;

        // Store in per-slot cache
        _slotCache[slot] = hadith;
        _cacheDate = now;
        return hadith;
      }
    } catch (e) {
      debugPrint('Hadith fetch error: $e');
    }

    // Fallback
    final fallback = {
      'text':
          'The best among you are those who have the best manners and character.',
      'hadithnumber': '6029',
    };
    _slotCache[slot] = fallback;
    _cacheDate = DateTime.now();
    return fallback;
  }

  void _openHadith(Map<String, dynamic> hadith) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HadithChaptersPage(
          bookId: 'eng-bukhari',
          bookName: 'Sahih Al-Bukhari',
          initialHadithNumber: hadith['hadithnumber']?.toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _hadithFuture,
      builder: (context, snapshot) {
        final slot = _currentSlot();

        if (snapshot.connectionState == ConnectionState.waiting &&
            !_slotCache.containsKey(slot)) {
          return _buildSkeleton();
        }

        final hadith = snapshot.data ?? _slotCache[slot] ?? {};
        final text =
            (hadith['text'] as String?)?.trim() ??
            "Unable to load today's inspiration.";

        return GestureDetector(
          onTap: () => _openHadith(hadith),
          child: Container(
            constraints: BoxConstraints(
              minWidth: 300.w,
              maxWidth: 500.w,
            ),
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: MinaretTheme.emerald,
              border: Border.all(
                color: MinaretTheme.gold.withValues(alpha: 0.3),
                width: 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top row: label + read button ─────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 16,
                          height: 1,
                          color: MinaretTheme.gold.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'DAILY INSPIRATION',
                          style: GoogleFonts.montserrat(
                            fontSize: 8,
                            letterSpacing: 3,
                            fontWeight: FontWeight.w800,
                            color: MinaretTheme.gold,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // ── Slot indicator dots ───────────────────────────
                        Row(
                          children: List.generate(5, (i) {
                            final active = i == slot;
                            return Container(
                              width: active ? 6 : 4,
                              height: active ? 6 : 4,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: active
                                    ? MinaretTheme.gold
                                    : MinaretTheme.gold.withValues(alpha: 0.25),
                                shape: BoxShape.circle,
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                    // ── Read full hadith button ───────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: MinaretTheme.gold.withValues(alpha: 0.4),
                          width: 0.7,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'READ',
                            style: GoogleFonts.montserrat(
                              fontSize: 7.5,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w700,
                              color: MinaretTheme.gold,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 8,
                            color: MinaretTheme.gold,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 18.h),

                // ── Hadith text ───────────────────────────────────────────
                Text(
                  text,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lato(
                    fontSize: 15.sp,
                    height: 1.75,
                    fontWeight: FontWeight.w300,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),

                SizedBox(height: 20.h),

                // ── Divider ───────────────────────────────────────────────
                Container(
                  height: 0.5,
                  constraints: BoxConstraints(
                    minWidth: 100.w,
                    maxWidth: 400.w,
                  ),
                  color: MinaretTheme.gold.withValues(alpha: 0.2),
                ),

                SizedBox(height: 14.h),

                // ── Footer: source + hadith number ────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_stories_outlined,
                          size: 10,
                          color: MinaretTheme.gold.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'SAHIH AL-BUKHARI  ·  NO. ${hadith['hadithnumber'] ?? '—'}',
                          style: GoogleFonts.ibmPlexMono(
                            fontSize: 8,
                            letterSpacing: 1.2,
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 11,
                      color: MinaretTheme.gold.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeleton() {
    return Container(
      height: 160.h,
      decoration: BoxDecoration(
        color: MinaretTheme.emeraldLight.withValues(alpha: 0.15),
        border: Border.all(color: MinaretTheme.dividerColor),
      ),
      child: const Center(
        child: AppLoadingIndicator(size: 18),
      ),
    );
  }
}
