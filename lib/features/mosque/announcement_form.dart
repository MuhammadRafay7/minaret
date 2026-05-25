import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:minaret/l10n/generated/app_localizations.dart';
import '../../core/theme.dart';
import '../../core/dependency_injection.dart';
import '../../repositories/mosque_repository.dart';
import '../../widgets/atelier_layout.dart';

class AnnouncementForm extends StatefulWidget {
  final String mosqueId;
  final String mosqueName;
  const AnnouncementForm({
    super.key,
    required this.mosqueId,
    required this.mosqueName,
  });

  @override
  State<AnnouncementForm> createState() => _AnnouncementFormState();
}

class _AnnouncementFormState extends State<AnnouncementForm> {
  final _textController = TextEditingController();
  bool _isLoading = false;

  Future<void> _postAnnouncement() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await ServiceLocator.get<MosqueRepository>().postAnnouncement(
        widget.mosqueId,
        widget.mosqueName,
        text,
      );

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.announcementPosted)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorPostingAnnouncement(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AtelierLayout(
        child: Column(
          children: [
            const SizedBox(height: 60),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 25.w),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        color: isDark ? Colors.white : MinaretTheme.onyx,
                        size: 20.sp),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    'NEW ANNOUNCEMENT',
                    style: MinaretTheme.heading.copyWith(
                      fontSize: 18.sp,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 25.w, vertical: 30.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'POSTING FOR: ${widget.mosqueName.toUpperCase()}',
                      style: MinaretTheme.detailHeader.copyWith(
                        color: MinaretTheme.gold,
                        fontSize: 8.sp,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    TextField(
                      controller: _textController,
                      maxLines: 6,
                      style: GoogleFonts.lato(
                        fontSize: 14.sp,
                        color: isDark ? Colors.white : MinaretTheme.onyx,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Write your message to the community...',
                        hintStyle: GoogleFonts.lato(
                          fontSize: 14.sp,
                          color: MinaretTheme.slate.withValues(alpha: 0.5),
                        ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: MinaretTheme.dividerColor,
                          ),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: MinaretTheme.gold),
                        ),
                        contentPadding: EdgeInsets.all(20.w),
                      ),
                    ),
                    SizedBox(height: 40.h),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _postAnnouncement,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: MinaretTheme.emerald, width: 1.5),
                          padding: EdgeInsets.symmetric(vertical: 20.h),
                          backgroundColor: MinaretTheme.emerald,
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 15.sp,
                                width: 15.sp,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'POST ANNOUNCEMENT',
                                style: GoogleFonts.montserrat(
                                  fontSize: 9.sp,
                                  letterSpacing: 4,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Text(
                      'Followers will receive an instant push notification.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(
                        fontSize: 10.sp,
                        color: MinaretTheme.slate,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
