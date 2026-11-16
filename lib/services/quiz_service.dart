import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QuizService {
  final _db = FirebaseFirestore.instance;

  String get _uid =>
      FirebaseAuth.instance.currentUser?.uid ??
      (throw StateError('Please sign in.'));

  Future<Map<String, dynamic>> startQuiz(String quizId) async {
    final uid = _uid;
    final qr = _db.collection('quizzes').doc(quizId);
    final qs = await qr.get();

    if (!qs.exists || qs.data()?['isPublished'] != true) {
      throw StateError('Quiz unavailable.');
    }

    final quiz = qs.data()!;
    final enrollment = await _db
        .collection('enrollments')
        .doc('${quiz['classId']}_$uid')
        .get();

    if (!enrollment.exists) {
      throw StateError('Join this class before taking its quiz.');
    }

    // Check all previous attempts, including older random-ID attempts.
    final previous = await _db
        .collection('quizAttempts')
        .where('uid', isEqualTo: uid)
        .get();
    final matching = previous.docs
        .where((doc) => doc.data()['quizId'] == quizId)
        .toList();

    if (matching.any((doc) => doc.data()['status'] == 'submitted')) {
      throw StateError('You have already submitted this quiz.');
    }

    // Reuse an existing unfinished attempt.
    final unfinished = matching
        .where((doc) => doc.data()['status'] == 'inProgress')
        .toList();

    String attemptId;
    int duration;
    Timestamp expires;

    if (unfinished.isNotEmpty) {
      unfinished.sort((a, b) {
        final aTime = a.data()['startedAt'] as Timestamp;
        final bTime = b.data()['startedAt'] as Timestamp;
        return bTime.compareTo(aTime);
      });
      final existing = unfinished.first;
      final data = existing.data();
      attemptId = existing.id;
      duration = (data['durationMinutes'] as num?)?.toInt() ?? 10;
      expires = data['expiresAt'] as Timestamp;
    } else {
      final questionSnap = await qr
          .collection('questions')
          .orderBy('order')
          .get();
      if (questionSnap.docs.isEmpty) {
        throw StateError('This quiz has no questions.');
      }

      duration = ((quiz['durationMinutes'] as num?)?.toInt() ?? 10).clamp(
        1,
        180,
      );
      final now = Timestamp.now();
      expires = Timestamp.fromMillisecondsSinceEpoch(
        now.millisecondsSinceEpoch + duration * 60000,
      );

      // Fixed ID preserves one attempt per student per quiz.
      final attempt = _db.collection('quizAttempts').doc('${uid}_$quizId');

      await _db.runTransaction((transaction) async {
        final existing = await transaction.get(attempt);
        if (existing.exists) {
          final status = existing.data()?['status'];
          if (status == 'submitted') {
            throw StateError('You have already submitted this quiz.');
          }
          if (status == 'inProgress') {
            throw StateError('You already have an attempt in progress.');
          }
          throw StateError('An attempt already exists for this quiz.');
        }
        transaction.set(attempt, {
          'uid': uid,
          'teacherId': quiz['teacherId'],
          'quizId': quizId,
          'classId': quiz['classId'],
          'quizTitle': quiz['title'],
          'quizType': quiz['quizType'] ?? 'multiple_choice',
          'status': 'inProgress',
          'startedAt': now,
          'expiresAt': expires,
          'durationMinutes': duration,
        });
      });
      attemptId = attempt.id;
    }

    final snap = await qr.collection('questions').orderBy('order').get();
    if (snap.docs.isEmpty) {
      throw StateError('This quiz has no questions.');
    }

    return {
      'attemptId': attemptId,
      'durationMinutes': duration,
      'expiresAt': expires.millisecondsSinceEpoch,
      'quizType': quiz['quizType'] ?? 'multiple_choice',
      'questions': snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
    };
  }

  Future<Map<String, dynamic>> submitQuiz({
    required String attemptId,
    required Map<String, dynamic> answers,
  }) async {
    final ref = _db.collection('quizAttempts').doc(attemptId);
    final attemptSnap = await ref.get();
    if (!attemptSnap.exists || attemptSnap.data()?['uid'] != _uid) {
      throw StateError('Attempt not found.');
    }

    final attempt = attemptSnap.data()!;
    if (attempt['status'] == 'submitted') {
      throw StateError('Already submitted.');
    }

    final questionSnap = await _db
        .collection('quizzes')
        .doc(attempt['quizId'])
        .collection('questions')
        .orderBy('order')
        .get();

    var score = 0;
    var total = 0;
    var needsManualReview = false;

    for (final questionDoc in questionSnap.docs) {
      final question = questionDoc.data();
      final keySnap = await _db
          .collection('answerKeys')
          .doc(questionDoc.id)
          .get();
      if (!keySnap.exists) continue;

      final key = keySnap.data()!;
      final points = (key['points'] as num?)?.toInt() ?? 1;
      final type = (question['quizType'] ?? 'multiple_choice').toString();
      final answer = answers[questionDoc.id];
      total += points;

      switch (type) {
        case 'multiple_choice':
        case 'true_false':
          final options = (question['options'] as List? ?? [])
              .map((value) => value.toString())
              .toList();
          final selectedIndex = answer is int
              ? answer
              : answer is String
              ? options.indexOf(answer)
              : -1;
          if (selectedIndex == key['correctIndex']) score += points;
          break;

        case 'identification':
          final submitted = (answer ?? '').toString().trim().toLowerCase();
          final expected = (key['correctAnswer'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          if (submitted.isNotEmpty && submitted == expected) score += points;
          break;

        case 'multiple_select':
          final selected = (answer as List? ?? [])
              .whereType<num>()
              .map((value) => value.toInt())
              .toSet();
          final correct = (key['correctIndices'] as List? ?? [])
              .whereType<num>()
              .map((value) => value.toInt())
              .toSet();
          if (selected.isNotEmpty &&
              selected.length == correct.length &&
              selected.containsAll(correct)) {
            score += points;
          }
          break;

        case 'matching':
          final submitted = answer is Map
              ? answer.map(
                  (key, value) => MapEntry(key.toString(), value.toString()),
                )
              : <String, String>{};
          final rawCorrectPairs = key['correctPairs'];
          final correct = rawCorrectPairs is Map
              ? rawCorrectPairs.map(
                  (key, value) => MapEntry(key.toString(), value.toString()),
                )
              : <String, String>{};
          if (submitted.length == correct.length &&
              correct.entries.every(
                (entry) => submitted[entry.key] == entry.value,
              )) {
            score += points;
          }
          break;

        case 'essay':
          needsManualReview = true;
          break;

        default:
          // Unknown or legacy question types are not auto-scored.
          break;
      }
    }

    final percentage = total == 0 || needsManualReview
        ? 0
        : (score / total * 100).round();
    final currentUser = FirebaseAuth.instance.currentUser;

    // Keep this update compatible with the existing Firestore allow-list.
    await ref.update({
      'status': 'submitted',
      'answers': answers,
      'score': needsManualReview ? 0 : score,
      'totalPoints': total,
      'percentage': percentage,
      'submittedAt': FieldValue.serverTimestamp(),
      'wasLate':
          Timestamp.now().millisecondsSinceEpoch >
          (attempt['expiresAt'] as Timestamp).millisecondsSinceEpoch,
      if (needsManualReview) 'manualReviewStatus': 'pending',
    });

    // Essay submissions are excluded from the automatic practice leaderboard.
    if (!needsManualReview) {
      final displayName = currentUser?.displayName?.trim();
      try {
        await _refreshLeaderboard(
          classId: attempt['classId'].toString(),
          displayName: displayName == null || displayName.isEmpty
              ? 'Student'
              : displayName,
        );
      } catch (_) {
        // A leaderboard issue must not undo a completed submission.
      }
    }

    return {
      'score': needsManualReview ? null : score,
      'totalPoints': total,
      'percentage': needsManualReview ? null : percentage,
      'needsManualReview': needsManualReview,
    };
  }

  Future<void> _refreshLeaderboard({
    required String classId,
    required String displayName,
  }) async {
    final submitted = await _db
        .collection('quizAttempts')
        .where('uid', isEqualTo: _uid)
        .where('classId', isEqualTo: classId)
        .get();
    final completed = submitted.docs
        .where((doc) => doc.data()['status'] == 'submitted')
        .toList();

    var totalScore = 0;
    var totalPoints = 0;
    var percentageSum = 0.0;
    for (final doc in completed) {
      final data = doc.data();
      totalScore += (data['score'] as num?)?.toInt() ?? 0;
      totalPoints += (data['totalPoints'] as num?)?.toInt() ?? 0;
      percentageSum += (data['percentage'] as num?)?.toDouble() ?? 0;
    }

    final average = completed.isEmpty ? 0 : percentageSum / completed.length;
    await _db
        .collection('leaderboards')
        .doc(classId)
        .collection('entries')
        .doc(_uid)
        .set({
          'uid': _uid,
          'displayName': displayName,
          'attempts': completed.length,
          'totalScore': totalScore,
          'totalPoints': totalPoints,
          'averagePercentage': average,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> attemptsFor(String uid) => _db
      .collection('quizAttempts')
      .where('uid', isEqualTo: uid)
      .orderBy('startedAt', descending: true)
      .snapshots();
}
