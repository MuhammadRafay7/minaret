import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../core/theme.dart';

/// Full-screen frosted success state — shown after saving mosque data etc.
class SuccessOverlay extends StatelessWidget {
  final String title;
  final String message;

  const SuccessOverlay({super.key, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        // Warm ivory at high opacity — consistent with app background
        color: MinaretTheme.background.withValues(alpha: 0.92),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Check circle
              Container(
                height: 64.w,
                width: 64.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: MinaretTheme.emerald.withValues(alpha: 0.08),
                  border: Border.all(
                    color: MinaretTheme.emerald.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: MinaretTheme.emerald,
                  size: 26.sp,
                ),
              ),

              SizedBox(height: 36.h),

              // Title
              Text(
                title.toUpperCase(),
                style: MinaretTheme.heading.copyWith(
                  fontSize: 15.sp,
                  letterSpacing: 7,
                ),
              ),

              SizedBox(height: 10.h),

              // Message — plain, readable sentence
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40.w),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(
                    fontSize: 13.sp,
                    color: MinaretTheme.slate,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
