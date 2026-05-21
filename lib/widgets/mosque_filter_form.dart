import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../core/theme.dart';
import '../core/constants/fiqh_constants.dart';
import '../l10n/generated/app_localizations.dart';

class MosqueFilterForm extends StatefulWidget {
  final double selectedRadiusKm;
  final String? selectedFiqh;
  final ValueChanged<double> onRadiusChanged;
  final ValueChanged<String?> onFiqhChanged;
  final bool showRadiusFilter;

  const MosqueFilterForm({
    super.key,
    required this.selectedRadiusKm,
    this.selectedFiqh,
    required this.onRadiusChanged,
    required this.onFiqhChanged,
    this.showRadiusFilter = true,
  });

  @override
  State<MosqueFilterForm> createState() => _MosqueFilterFormState();
}

class _MosqueFilterFormState extends State<MosqueFilterForm> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151B24) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: MinaretTheme.gold.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 3.w,
                height: 20.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      MinaretTheme.gold.withValues(alpha: 0.0),
                      MinaretTheme.gold,
                      MinaretTheme.gold.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                'FILTERS',
                style: GoogleFonts.montserrat(
                  fontSize: 10.sp,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w800,
                  color: MinaretTheme.gold,
                ),
              ),
              const Spacer(),
              _ResetButton(
                onPressed: () {
                  widget.onRadiusChanged(3);
                  widget.onFiqhChanged(null);
                },
              ),
            ],
          ),
          SizedBox(height: 24.h),

          // Radius Filter
          if (widget.showRadiusFilter) ...[
            _FilterSection(
              title: l10n.radiusLabel,
              child: _RadiusSelector(
                selectedRadius: widget.selectedRadiusKm,
                onRadiusChanged: widget.onRadiusChanged,
                isDark: isDark,
              ),
            ),
            SizedBox(height: 20.h),
          ],

          // School of Thought Filter
          _FilterSection(
            title: l10n.schoolOfThoughtLabel,
            child: _FiqhSelector(
              selectedFiqh: widget.selectedFiqh,
              onFiqhChanged: widget.onFiqhChanged,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _FilterSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: GoogleFonts.montserrat(
            fontSize: 8.sp,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
            color: MinaretTheme.gold.withValues(alpha: 0.8),
          ),
        ),
        SizedBox(height: 12.h),
        child,
      ],
    );
  }
}

class _ResetButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ResetButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(
            color: MinaretTheme.gold.withValues(alpha: 0.3),
            width: 0.8,
          ),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Text(
          'RESET',
          style: GoogleFonts.montserrat(
            fontSize: 7.sp,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
            color: MinaretTheme.gold.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

class _RadiusSelector extends StatelessWidget {
  final double selectedRadius;
  final ValueChanged<double> onRadiusChanged;
  final bool isDark;

  const _RadiusSelector({
    required this.selectedRadius,
    required this.onRadiusChanged,
    required this.isDark,
  });

  static const List<double> _radiusOptions = [1, 3, 5, 10, 20, 50];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Custom slider-like selector
        Container(
          height: 40.h,
          child: Row(
            children: _radiusOptions.map((radius) {
              final isSelected = selectedRadius == radius;
              final index = _radiusOptions.indexOf(radius);
              
              return Expanded(
                child: GestureDetector(
                  onTap: () => onRadiusChanged(radius),
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: 1.w),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? MinaretTheme.gold.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4.r),
                            border: Border.all(
                              color: isSelected
                                  ? MinaretTheme.gold
                                  : MinaretTheme.dividerColor.withValues(alpha: 0.3),
                              width: isSelected ? 1.2 : 0.8,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${radius.toStringAsFixed(0)}',
                              style: GoogleFonts.ibmPlexMono(
                                fontSize: 9.sp,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? MinaretTheme.gold
                                    : (isDark ? Colors.white60 : MinaretTheme.slate),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (index < _radiusOptions.length - 1)
                        Expanded(
                          child: Container(
                            height: 1.h,
                            margin: EdgeInsets.symmetric(horizontal: 8.w),
                            color: MinaretTheme.dividerColor.withValues(alpha: 0.2),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(height: 8.h),
        // Selected value display
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: MinaretTheme.gold.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: Text(
            'Selected: ${selectedRadius.toStringAsFixed(0)} km radius',
            style: GoogleFonts.montserrat(
              fontSize: 8.sp,
              fontWeight: FontWeight.w600,
              color: MinaretTheme.gold,
            ),
          ),
        ),
      ],
    );
  }
}

class _FiqhSelector extends StatelessWidget {
  final String? selectedFiqh;
  final ValueChanged<String?> onFiqhChanged;
  final bool isDark;

  const _FiqhSelector({
    required this.selectedFiqh,
    required this.onFiqhChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      (null, 'ALL'),
      ...FiqhConstants.orderedKeys
          .where((k) => k.isNotEmpty)
          .map((k) => (k, FiqhConstants.labelFor(k))),
    ];

    return Wrap(
      spacing: 10.w,
      runSpacing: 10.h,
      children: options.map((option) {
        final key = option.$1;
        final label = option.$2;
        final isSelected = selectedFiqh == key;
        
        return GestureDetector(
          onTap: () => onFiqhChanged(key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
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
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 9.sp,
                letterSpacing: 1,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? MinaretTheme.emerald
                    : (isDark ? Colors.white70 : MinaretTheme.slate),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
