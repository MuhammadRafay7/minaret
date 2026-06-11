import 'package:flutter_test/flutter_test.dart';
import 'package:minaret/features/auth/auth_page.dart';

void main() {
  group('InternationalDocumentVerificationService.verifyFromRawText', () {
    // ── Name extraction + scoring ──────────────────────────────────────────

    test('identical names → approved (similarity = 1.0)', () {
      final result = InternationalDocumentVerificationService.verifyFromRawText(
        idRawText: 'Name: John Smith\nAge: 35',
        sanadRawText: 'Name: John Smith\nDate: 2020',
      );
      expect(result.approved, isTrue);
      expect(result.status, 'approved');
      expect(result.score, 100);
    });

    test('near-identical names → approved (similarity ≥ 0.80)', () {
      // "muhammad ali khan" vs "muhammad ali khan" — same after cleaning
      final result = InternationalDocumentVerificationService.verifyFromRawText(
        idRawText: 'Name: Muhammad Ali Khan',
        sanadRawText: 'Name: Muhammad Ali Khan',
      );
      expect(result.approved, isTrue);
      expect(result.status, 'approved');
    });

    test('partially similar names → needs_review (0.55 ≤ similarity < 0.80)',
        () {
      // "muhammad ali" vs "ahmad ali" — Dice ≈ 0.63 (in needs_review band)
      final result = InternationalDocumentVerificationService.verifyFromRawText(
        idRawText: 'Name: Muhammad Ali',
        sanadRawText: 'Name: Ahmad Ali',
      );
      expect(result.approved, isFalse);
      expect(result.status, 'needs_review');
      expect(result.score, greaterThanOrEqualTo(55));
      expect(result.score, lessThan(80));
    });

    test('different names → rejected (similarity < 0.55)', () {
      // "john smith" vs "jane wilson" share no bigrams → similarity = 0
      final result = InternationalDocumentVerificationService.verifyFromRawText(
        idRawText: 'Name: John Smith',
        sanadRawText: 'Name: Jane Wilson',
      );
      expect(result.approved, isFalse);
      expect(result.status, 'rejected');
      expect(result.score, lessThan(55));
    });

    test('name too short to extract → needs_review with score 0', () {
      final result = InternationalDocumentVerificationService.verifyFromRawText(
        idRawText: 'Name: J',
        sanadRawText: 'Name: M',
      );
      expect(result.approved, isFalse);
      expect(result.status, 'needs_review');
      expect(result.score, 0);
    });

    // ── ID number matching ─────────────────────────────────────────────────

    test('matching PK CNIC numbers → approved immediately (score = 100)', () {
      // Pakistani CNIC: XXXXX-XXXXXXX-X
      final result = InternationalDocumentVerificationService.verifyFromRawText(
        idRawText: '35201-1234567-3',
        sanadRawText: '35201-1234567-3',
        countryCode: 'PK',
      );
      expect(result.approved, isTrue);
      expect(result.status, 'approved');
      expect(result.score, 100);
    });

    test('mismatched PK CNIC numbers → rejected', () {
      final result = InternationalDocumentVerificationService.verifyFromRawText(
        idRawText: '35201-1234567-3',
        sanadRawText: '35201-9999999-9',
        countryCode: 'PK',
      );
      expect(result.approved, isFalse);
      expect(result.status, 'rejected');
      expect(result.score, 0);
    });

    test('matching US SSN numbers → approved immediately', () {
      // US SSN: XXX-XX-XXXX
      final result = InternationalDocumentVerificationService.verifyFromRawText(
        idRawText: '123-45-6789',
        sanadRawText: '123-45-6789',
        countryCode: 'US',
      );
      expect(result.approved, isTrue);
      expect(result.status, 'approved');
    });
  });
}
