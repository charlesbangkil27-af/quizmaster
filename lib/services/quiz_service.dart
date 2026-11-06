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

  // Check previous attempts, including older random-ID attempts.
  final previous = await _db
      .collection('quizAttempts')
      .where('uid', isEqualTo: uid)
      .get();

  final matching = previous.docs
      .where((doc) => doc.data()['quizId'] == quizId)
      .toList();

  final submitted = matching.any(
    (doc) => doc.data()['status'] == 'submitted',
  );

  if (submitted) {
    throw StateError('You have already submitted this quiz.');
  }

  // Reuse an existing unfinished attempt, if there is one.
  final unfinished = matching.where(
    (doc) => doc.data()['status'] == 'inProgress',
  ).toList();

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
    final snap = await qr.collection('questions').orderBy('order').get();

    if (snap.docs.isEmpty) {
      throw StateError('This quiz has no questions.');
    }

    duration = ((quiz['durationMinutes'] as num?)?.toInt() ?? 10)
        .clamp(1, 180);

    final now = Timestamp.now();
    expires = Timestamp.fromMillisecondsSinceEpoch(
      now.millisecondsSinceEpoch + duration * 60000,
    );

    // Fixed ID: only one attempt document per student per quiz.
    final attempt = _db
        .collection('quizAttempts')
        .doc('${uid}_$quizId');

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
    'questions': snap.docs
        .map((d) => {'id': d.id, ...d.data()})
        .toList(),
  };
}


  Future<Map<String, dynamic>> submitQuiz({
    required String attemptId,
    required Map<String, String> answers,
  }) async {
    final ref = _db.collection('quizAttempts').doc(attemptId);
    final a = await ref.get();
    if (!a.exists || a.data()?['uid'] != _uid) {
      throw StateError('Attempt not found.');
    }
    final data = a.data()!;
    if (data['status'] == 'submitted') throw StateError('Already submitted.');
    final questions = await _db
        .collection('quizzes')
        .doc(data['quizId'])
        .collection('questions')
        .get();
    var score = 0;
    var total = 0;
    for (final q in questions.docs) {
      final key = await _db.collection('answerKeys').doc(q.id).get();
      if (!key.exists) continue;
      final k = key.data()!;
      final points = (k['points'] as num?)?.toInt() ?? 1;
      final options =
          (q.data()['options'] as List?)?.map((v) => v.toString()).toList() ??
          [];
      total += points;
      if (options.indexOf(answers[q.id] ?? '') == k['correctIndex'])
        score += points;
    }
    final pct = total == 0 ? 0 : (score / total * 100).round();
    final currentUser = FirebaseAuth.instance.currentUser;
    await ref.update({
      'status': 'submitted',
      'answers': answers,
      'score': score,
      'totalPoints': total,
      'percentage': pct,
      'submittedAt': FieldValue.serverTimestamp(),
      'wasLate':
          Timestamp.now().millisecondsSinceEpoch >
          (data['expiresAt'] as Timestamp).millisecondsSinceEpoch,
    });

    // Practice leaderboard only. Client-side scoring is not secure for high-stakes exams.
    final displayName = currentUser?.displayName?.trim();
    try {
      await _refreshLeaderboard(
        classId: data['classId'].toString(),
        displayName: displayName == null || displayName.isEmpty
            ? 'Student'
            : displayName,
      );
    } catch (_) {
      // A leaderboard issue must not undo a completed practice submission.
    }
    return {'score': score, 'totalPoints': total, 'percentage': pct};
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
        .where((d) => d.data()['status'] == 'submitted')
        .toList();
    var totalScore = 0;
    var totalPoints = 0;
    var percentageSum = 0.0;
    for (final doc in completed) {
      final d = doc.data();
      totalScore += (d['score'] as num?)?.toInt() ?? 0;
      totalPoints += (d['totalPoints'] as num?)?.toInt() ?? 0;
      percentageSum += (d['percentage'] as num?)?.toDouble() ?? 0;
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
