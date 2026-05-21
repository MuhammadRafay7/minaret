import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_spacing.dart';
import '../../core/theme.dart';

class LegalDocBody extends StatefulWidget {
  const LegalDocBody({super.key, required this.type});

  final String type;

  @override
  State<LegalDocBody> createState() => _LegalDocBodyState();
}

class _LegalDocBodyState extends State<LegalDocBody> {
  Map<String, dynamic>? _doc;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('legal_docs')
          .where('type', isEqualTo: widget.type)
          .limit(1)
          .get();
      if (!mounted) return;
      setState(() {
        _doc = snap.docs.isNotEmpty ? snap.docs.first.data() : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_doc == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            _error != null
                ? 'Failed to load document. Please try again later.'
                : 'This document is not available yet.',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 13,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    final content = _doc!['content'] as String? ?? '';
    final version = _doc!['version'] as String? ?? '';
    final lastUpdated = _doc!['lastUpdated'];
    final dateStr = _formatDate(lastUpdated);

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _loading = true);
        await _fetch();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._renderContent(content),
            const SizedBox(height: 40),
            Center(
              child: Text(
                [
                  if (dateStr.isNotEmpty) 'Last Updated: $dateStr',
                  if (version.isNotEmpty) 'v$version',
                ].join(' · '),
                style: GoogleFonts.montserrat(fontSize: 10, color: Colors.grey),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  List<Widget> _renderContent(String content) {
    final widgets = <Widget>[];
    // Split into blocks by double newline
    final blocks = content.split(RegExp(r'\n{2,}'));
    for (final block in blocks) {
      final text = block.trim();
      if (text.isEmpty) continue;

      if (_isHeading(text)) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 6),
            child: Text(
              text.toUpperCase(),
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: MinaretTheme.gold,
              ),
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              text,
              style: GoogleFonts.notoNaskhArabic(fontSize: 14, height: 1.7),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  // A block is a heading if it's a single line, short, and doesn't end with sentence punctuation.
  bool _isHeading(String text) {
    if (text.contains('\n')) return false;
    if (text.length > 80) return false;
    if (text.endsWith('.') || text.endsWith(',') || text.endsWith(':')) return false;
    return true;
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '';
    try {
      final date = ts is Timestamp ? ts.toDate() : DateTime.parse(ts.toString());
      const months = [
        '', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
      ];
      return '${months[date.month]} ${date.year}';
    } catch (_) {
      return '';
    }
  }
}
