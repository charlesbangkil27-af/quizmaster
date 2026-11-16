import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EssayReviewService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _uid =>
      FirebaseAuth.instance.currentUser?.uid ??
      (throw StateError('Please sign in.'));

  Stream<QuerySnapshot<Map<String, dynamic>>> pendingReviews() {
    return _db
        .collection('quizAttempts')
        .where('teacherId', isEqualTo: _uid)
        .snapshots();
  }

  Future<Map<String, dynamic>> loadReview(String attemptId) async {
    final attemptRef = _db.collection('quizAttempts').doc(attemptId);
    final attemptSnap = await attemptRef.get();

    if (!attemptSnap.exists) {
      throw StateError('Submission not found.');
    }

    final attempt = attemptSnap.data()!;

    if (attempt['teacherId'] != _uid) {
      throw StateError('You cannot review this submission.');
    }

    if (attempt['status'] != 'submitted' ||
        attempt['manualReviewStatus'] != 'pending') {
      throw StateError('This submission is not pending review.');
    }

    final quizRef = _db.collection('quizzes').doc(attempt['quizId'].toString());

    final quizSnap = await quizRef.get();

    if (!quizSnap.exists || quizSnap.data()?['quizType'] != 'essay') {
      throw StateError('This is not an essay quiz.');
    }

    final questionSnap = await quizRef
        .collection('questions')
        .orderBy('order')
        .get();

    final questions = <Map<String, dynamic>>[];

    for (final questionDoc in questionSnap.docs) {
      final question = questionDoc.data();

      if (question['quizType'] != 'essay') continue;

      final keySnap = await _db
          .collection('answerKeys')
          .doc(questionDoc.id)
          .get();

      final points = (keySnap.data()?['points'] as num?)?.toInt() ?? 1;

      questions.add({
        'id': questionDoc.id,
        'text': question['text']?.toString() ?? '',
        'answer': (attempt['answers'] as Map?)?[questionDoc.id],
        'points': points,
        'order': question['order'] ?? 0,
      });
    }

    return {'attempt': attempt, 'questions': questions};
  }

  Future<void> gradeAttempt({
    required String attemptId,
    required Map<String, int> scores,
    required Map<String, String> feedback,
  }) async {
    final attemptRef = _db.collection('quizAttempts').doc(attemptId);
    final attemptSnap = await attemptRef.get();

    if (!attemptSnap.exists) {
      throw StateError('Submission not found.');
    }

    final attempt = attemptSnap.data()!;

    if (attempt['teacherId'] != _uid) {
      throw StateError('You cannot grade this submission.');
    }

    if (attempt['status'] != 'submitted' ||
        attempt['manualReviewStatus'] != 'pending') {
      throw StateError('This submission has already been reviewed.');
    }

    final quizRef = _db.collection('quizzes').doc(attempt['quizId'].toString());
    final quizSnap = await quizRef.get();

    if (!quizSnap.exists || quizSnap.data()?['quizType'] != 'essay') {
      throw StateError('Invalid essay quiz.');
    }

    final questionSnap = await quizRef
        .collection('questions')
        .orderBy('order')
        .get();

    var totalPoints = 0;
    var earnedPoints = 0;
    final validatedScores = <String, int>{};

    for (final questionDoc in questionSnap.docs) {
      final question = questionDoc.data();
      if (question['quizType'] != 'essay') continue;

      final keySnap = await _db
          .collection('answerKeys')
          .doc(questionDoc.id)
          .get();

      final maxPoints = (keySnap.data()?['points'] as num?)?.toInt() ?? 1;
      final awarded = scores[questionDoc.id];

      if (awarded == null || awarded < 0 || awarded > maxPoints) {
        throw StateError(
          'Invalid score for question ${questionDoc.id}. '
          'Allowed range: 0 to $maxPoints.',
        );
      }

      totalPoints += maxPoints;
      earnedPoints += awarded;
      validatedScores[questionDoc.id] = awarded;
    }

    if (validatedScores.isEmpty || totalPoints == 0) {
      throw StateError('No essay questions were found.');
    }

    if (scores.length != validatedScores.length) {
      throw StateError(
        'The submitted scores do not match the essay questions.',
      );
    }

    final percentage = (earnedPoints / totalPoints * 100).round();

    await attemptRef.update({
      'score': earnedPoints,
      'totalPoints': totalPoints,
      'percentage': percentage,
      'essayScores': validatedScores,
      'essayFeedback': feedback,
      'manualReviewStatus': 'graded',
      'gradedBy': _uid,
      'gradedAt': FieldValue.serverTimestamp(),
    });
  }
}
