/// fiqh_selector.dart
/// Reusable Fiqh / Madhab selector widget.
/// Used on CreateMosquePage and EditMosquePage.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:minaret/core/theme.dart';
import 'package:minaret/core/constants/fiqh_constants.dart';

class FiqhSelector extends StatelessWidget {
  final String selectedKey;
  final ValueChanged<String> onChanged;

  const FiqhSelector({
    super.key,
    required this.selectedKey,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label
        Row(
          children: [
            Container(
              height: 1,
              width: 16,
              color: MinaretTheme.gold.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 8),
            Text(
              'SCHOOL OF THOUGHT (FIQH)',
              style: GoogleFonts.montserrat(
                fontSize: 7.5,
                letterSpacing: 3,
                color: MinaretTheme.gold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Chips grid
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: FiqhConstants.orderedKeys.map((key) {
            final label = FiqhConstants.options[key]!;
            final isSelected = selectedKey == key;
            return GestureDetector(
              onTap: () => onChanged(key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? MinaretTheme.emerald.withValues(alpha: 0.12)
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? MinaretTheme.emerald
                        : MinaretTheme.dividerColor,
                    width: isSelected ? 1.2 : 0.8,
                  ),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.montserrat(
                    fontSize: 9.5,
                    letterSpacing: 1,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? MinaretTheme.emerald
                        : MinaretTheme.slate.withValues(alpha: 0.7),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
