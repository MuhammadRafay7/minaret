import 'package:cloud_functions/cloud_functions.dart';
import '../core/dependency_injection.dart';
import '../repositories/user_repository.dart';

class ImamVerificationResult {
  final bool approved;
  final String status;
  final int score;
  final String reason;
  final int nameMatchConfidence;

  const ImamVerificationResult({
    required this.approved,
    required this.status,
    required this.score,
    required this.reason,
    required this.nameMatchConfidence,
  });

  factory ImamVerificationResult.fromMap(Map<String, dynamic> map) =>
      ImamVerificationResult(
        approved: map['approved'] == true,
        status: map['status'] ?? 'needs_review',
        score: (map['score'] as num?)?.toInt() ?? 0,
        reason: map['reason'] ?? 'Verification inconclusive.',
        nameMatchConfidence:
            (map['nameMatchConfidence'] as num?)?.toInt() ?? 0,
      );
}

class ImamVerificationService {
  static UserRepository get _repo => ServiceLocator.get<UserRepository>();

  static Future<ImamVerificationResult> verify({
    required String uid,
    required String idCardBase64,
    required String sanadBase64,
  }) async {
    final callable = FirebaseFunctions.instance
        .httpsCallable('verifyImamDocuments');

    final response =
        await callable.call<Map<String, dynamic>>({
      'idCardBase64': idCardBase64,
      'sanadBase64': sanadBase64,
    });

    final result = ImamVerificationResult.fromMap(
        Map<String, dynamic>.from(response.data));

    await _repo.saveVerificationResult(uid, {
      'documentsVerified': result.approved,
      'verificationStatus': result.status,
      'verificationScore': result.score,
      'verificationReason': result.reason,
      'nameMatchConfidence': result.nameMatchConfidence,
    });

    return result;
  }
}
