import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../core/theme.dart';
import '../core/constants/fiqh_constants.dart';
import '../l10n/generated/app_localizations.dart';

class SimpleFilterDialog extends StatefulWidget {
  final double selectedRadiusKm;
  final String? selectedFiqh;
  final bool showRadiusFilter;
  final ValueChanged<double> onRadiusChanged;
  final ValueChanged<String?> onFiqhChanged;

  const SimpleFilterDialog({
    super.key,
    required this.selectedRadiusKm,
    this.selectedFiqh,
    this.showRadiusFilter = true,
    required this.onRadiusChanged,
    required this.onFiqhChanged,
  });

  @override
  State<SimpleFilterDialog> createState() => _SimpleFilterDialogState();
}

class _SimpleFilterDialogState extends State<SimpleFilterDialog> {
  late double _tempRadius;
  late String? _tempFiqh;

  @override
  void initState() {
    super.initState();
    _tempRadius = widget.selectedRadiusKm;
    _tempFiqh = widget.selectedFiqh;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF151B24) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Container(
        width: 320.w,
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  'Filters',
                  style: GoogleFonts.montserrat(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),

            // Radius Filter
            if (widget.showRadiusFilter) ...[
              Text(
                l10n.radiusLabel,
                style: GoogleFonts.montserrat(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              SizedBox(height: 12.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: [1, 3, 5, 10, 20, 50].map((radius) {
                  final isSelected = _tempRadius == radius.toDouble();
                  return FilterChip(
                    label: Text('${radius}km'),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _tempRadius = radius.toDouble();
                      });
                    },
                    backgroundColor: isDark ? const Color(0xFF1A1F2E) : Colors.grey[100],
                    selectedColor: MinaretTheme.gold.withOpacity(0.2),
                    labelStyle: GoogleFonts.montserrat(
                      fontSize: 10.sp,
                      color: isSelected ? MinaretTheme.gold : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 20.h),
            ],

            // School of Thought Filter
            Text(
              l10n.schoolOfThoughtLabel,
              style: GoogleFonts.montserrat(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            SizedBox(height: 12.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                (null, 'ALL'),
                ...FiqhConstants.orderedKeys
                    .where((k) => k.isNotEmpty)
                    .map((k) => (k, FiqhConstants.labelFor(k))),
              ].map((option) {
                final key = option.$1;
                final label = option.$2;
                final isSelected = _tempFiqh == key;
                return FilterChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _tempFiqh = key;
                    });
                  },
                  backgroundColor: isDark ? const Color(0xFF1A1F2E) : Colors.grey[100],
                  selectedColor: MinaretTheme.emerald.withOpacity(0.2),
                  labelStyle: GoogleFonts.montserrat(
                    fontSize: 10.sp,
                    color: isSelected ? MinaretTheme.emerald : (isDark ? Colors.white70 : Colors.black87),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 24.h),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _tempRadius = 3;
                        _tempFiqh = null;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: MinaretTheme.gold),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                    child: Text(
                      'Reset',
                      style: GoogleFonts.montserrat(
                        fontSize: 12.sp,
                        color: MinaretTheme.gold,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onRadiusChanged(_tempRadius);
                      widget.onFiqhChanged(_tempFiqh);
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MinaretTheme.gold,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                    child: Text(
                      'Apply',
                      style: GoogleFonts.montserrat(
                        fontSize: 12.sp,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Simple filter button to trigger the dialog
class FilterButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool hasActiveFilters;

  const FilterButton({
    super.key,
    required this.onPressed,
    this.hasActiveFilters = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: hasActiveFilters 
            ? MinaretTheme.gold.withOpacity(0.1)
            : (isDark ? const Color(0xFF1A1F2E) : Colors.grey[100]),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: hasActiveFilters ? MinaretTheme.gold : MinaretTheme.dividerColor,
          width: hasActiveFilters ? 1.2 : 0.8,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune,
                  size: 16.sp,
                  color: hasActiveFilters 
                      ? MinaretTheme.gold 
                      : (isDark ? Colors.white70 : Colors.black54),
                ),
                SizedBox(width: 6.w),
                Text(
                  'Filter',
                  style: GoogleFonts.montserrat(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: hasActiveFilters 
                        ? MinaretTheme.gold 
                        : (isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
                if (hasActiveFilters) ...[
                  SizedBox(width: 6.w),
                  Container(
                    width: 6.w,
                    height: 6.w,
                    decoration: BoxDecoration(
                      color: MinaretTheme.gold,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
