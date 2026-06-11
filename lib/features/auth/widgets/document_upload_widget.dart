import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';

/// A tappable document upload tile.
///
/// Shows the selected image as a thumbnail when [imageBytes] is non-null,
/// or a placeholder prompt with an upload icon otherwise.
class DocumentUploadWidget extends StatelessWidget {
  final String label;
  final Uint8List? imageBytes;
  final VoidCallback onPick;
  final bool isDark;

  const DocumentUploadWidget({
    super.key,
    required this.label,
    required this.imageBytes,
    required this.onPick,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final lineColor = isDark ? Colors.white24 : MinaretTheme.dividerColor;
    final surfaceColor = isDark
        ? const Color(0xFF151B24)
        : Colors.white.withOpacity(0.45);
    final secondaryText =
        isDark ? Colors.white70 : MinaretTheme.slate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: MinaretTheme.label,
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onPick,
          child: Container(
            height: 130,
            width: double.infinity,
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border.all(
                color: imageBytes != null
                    ? MinaretTheme.emerald.withOpacity(0.5)
                    : lineColor,
                width: imageBytes != null ? 1.2 : 0.8,
              ),
            ),
            child: imageBytes != null
                ? _ThumbnailWithChangeOverlay(bytes: imageBytes!, isDark: isDark)
                : _UploadPlaceholder(secondaryText: secondaryText),
          ),
        ),
      ],
    );
  }
}

class _ThumbnailWithChangeOverlay extends StatelessWidget {
  final Uint8List bytes;
  final bool isDark;
  const _ThumbnailWithChangeOverlay({required this.bytes, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(bytes, fit: BoxFit.cover),
        Positioned(
          bottom: 8,
          right: 8,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            color: Colors.black54,
            child: Text(
              'CHANGE',
              style: GoogleFonts.montserrat(
                fontSize: 7,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UploadPlaceholder extends StatelessWidget {
  final Color secondaryText;
  const _UploadPlaceholder({required this.secondaryText});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 30,
          color: MinaretTheme.gold.withOpacity(0.5),
        ),
        const SizedBox(height: 8),
        Text(
          'TAP TO UPLOAD',
          style: GoogleFonts.montserrat(
            fontSize: 8.5,
            color: secondaryText,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
