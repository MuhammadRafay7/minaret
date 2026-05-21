import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:minaret/core/theme.dart';
import 'package:minaret/services/janaza_service.dart';

class JanazaAnnouncementCard extends StatelessWidget {
  final JanazaAnnouncement announcement;
  final VoidCallback? onDeactivate;
  final VoidCallback? onEdit;

  const JanazaAnnouncementCard({
    super.key,
    required this.announcement,
    this.onDeactivate,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('hh:mm a').format(announcement.janazaTime);
    final dateStr = DateFormat('EEE, d MMM').format(announcement.janazaTime);

    // Build family relations list
    final relations = <_Relation>[];
    if (announcement.fatherName.isNotEmpty)
      relations.add(_Relation('FATHER', announcement.fatherName));
    if (announcement.motherName.isNotEmpty)
      relations.add(_Relation('MOTHER', announcement.motherName));
    if (announcement.husbandName.isNotEmpty)
      relations.add(_Relation('HUSBAND', announcement.husbandName));
    if (announcement.wifeName.isNotEmpty)
      relations.add(_Relation('WIFE', announcement.wifeName));
    if (announcement.brotherName.isNotEmpty)
      relations.add(_Relation('BROTHER', announcement.brotherName));
    if (announcement.sisterName.isNotEmpty)
      relations.add(_Relation('SISTER', announcement.sisterName));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1F17),
        border: Border.all(
          color: MinaretTheme.gold.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────────────────────
          Row(
            children: [
              Icon(
                Icons.brightness_3_rounded,
                size: 12,
                color: MinaretTheme.gold.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Text(
                'JANAZA ANNOUNCEMENT',
                style: GoogleFonts.montserrat(
                  fontSize: 7.5,
                  letterSpacing: 3,
                  color: MinaretTheme.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (onEdit != null) ...[
                GestureDetector(
                  onTap: onEdit,
                  child: Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: MinaretTheme.gold.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              if (onDeactivate != null)
                GestureDetector(
                  onTap: onDeactivate,
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: MinaretTheme.slate.withValues(alpha: 0.4),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            'إِنَّا لِلَّهِ وَإِنَّا إِلَيْهِ رَاجِعُونَ',
            style: GoogleFonts.amiri(
              fontSize: 15,
              color: MinaretTheme.gold.withValues(alpha: 0.6),
              fontWeight: FontWeight.w400,
            ),
          ),

          const SizedBox(height: 14),

          // ── Deceased name + gender badge ─────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  announcement.deceasedName.toUpperCase(),
                  style: MinaretTheme.heading.copyWith(
                    fontSize: 22,
                    letterSpacing: 2,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ),
              if (announcement.gender.isNotEmpty) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: MinaretTheme.gold.withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                    color: MinaretTheme.gold.withValues(alpha: 0.06),
                  ),
                  child: Text(
                    announcement.gender.toUpperCase(),
                    style: GoogleFonts.montserrat(
                      fontSize: 7,
                      letterSpacing: 1.5,
                      color: MinaretTheme.gold.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),

          // ── Age ──────────────────────────────────────────────────────────
          if (announcement.age.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'AGE ${announcement.age}',
              style: GoogleFonts.montserrat(
                fontSize: 8,
                letterSpacing: 2,
                color: MinaretTheme.slate.withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          const SizedBox(height: 12),
          Container(height: 0.5, color: MinaretTheme.gold.withValues(alpha: 0.2)),
          const SizedBox(height: 12),

          // ── Time + Date ──────────────────────────────────────────────────
          Row(
            children: [
              _infoCell(label: 'TIME', value: timeStr),
              const SizedBox(width: 30),
              _infoCell(label: 'DATE', value: dateStr),
            ],
          ),

          // ── Location ─────────────────────────────────────────────────────
          if (announcement.locationNote.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 12,
                  color: MinaretTheme.gold.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    announcement.locationNote,
                    style: GoogleFonts.lato(
                      fontSize: 12,
                      color: MinaretTheme.slate.withValues(alpha: 0.7),
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // ── Family details ────────────────────────────────────────────────
          if (relations.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(height: 0.5, color: MinaretTheme.gold.withValues(alpha: 0.12)),
            const SizedBox(height: 14),
            Text(
              'SURVIVED BY',
              style: GoogleFonts.montserrat(
                fontSize: 7,
                letterSpacing: 2.5,
                color: MinaretTheme.slate.withValues(alpha: 0.45),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 20,
              runSpacing: 12,
              children: relations
                  .map((r) => _familyCell(label: r.label, value: r.value))
                  .toList(),
            ),
          ],

          // ── Mosque name ───────────────────────────────────────────────────
          if (announcement.mosqueName.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(height: 0.5, color: MinaretTheme.gold.withValues(alpha: 0.12)),
            const SizedBox(height: 10),
            Text(
              announcement.mosqueName.toUpperCase(),
              style: GoogleFonts.montserrat(
                fontSize: 8,
                letterSpacing: 2,
                color: MinaretTheme.emerald.withValues(alpha: 0.8),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoCell({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 7,
            letterSpacing: 2,
            color: MinaretTheme.slate.withValues(alpha: 0.5),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _familyCell({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 6.5,
            letterSpacing: 2,
            color: MinaretTheme.slate.withValues(alpha: 0.4),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.lato(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

class _Relation {
  final String label;
  final String value;
  const _Relation(this.label, this.value);
}
