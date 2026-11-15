import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'notification_service.dart';

class ClassroomService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String get uid =>
      FirebaseAuth.instance.currentUser?.uid ??
      (throw StateError('Please sign in.'));
  Stream<QuerySnapshot<Map<String, dynamic>>> teacherClasses() => _db
      .collection('classes')
      .where('teacherId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots();
  Stream<QuerySnapshot<Map<String, dynamic>>> studentClasses() => _db
      .collection('enrollments')
      .where('studentId', isEqualTo: uid)
      .snapshots();

  // Backfill missing names on the current student's own enrollments.
  Future<void> ensureEnrollmentNames() async {
    final currentUid = uid;

    final profile = await _db.collection('users').doc(currentUid).get();
    final displayName = (profile.data()?['displayName'] ?? '')
        .toString()
        .trim();

    if (displayName.isEmpty) return;

    final enrollments = await _db
        .collection('enrollments')
        .where('studentId', isEqualTo: currentUid)
        .get();

    final batch = _db.batch();
    var changed = false;

    for (final enrollment in enrollments.docs) {
      final existingName = (enrollment.data()['studentName'] ?? '')
          .toString()
          .trim();

      if (existingName.isEmpty) {
        batch.update(enrollment.reference, {'studentName': displayName});
        changed = true;
      }
    }

    if (changed) {
      await batch.commit();
    }
  }

  String _code() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<String> createClass(
    String name,
    String section, {
    required int maxStudents,
  }) async {
    final n = name.trim();
    final s = section.trim();

    if (n.isEmpty || n.length > 100 || s.isEmpty || s.length > 60) {
      throw ArgumentError('Enter a valid class name and section.');
    }

    if (maxStudents < 1 || maxStudents > 500) {
      throw ArgumentError('Class capacity must be between 1 and 500.');
    }

    final p = await _db.collection('users').doc(uid).get();

    if (!p.exists ||
        p.data()?['role'] != 'teacher' ||
        p.data()?['isActive'] != true) {
      throw StateError('An active teacher account is required.');
    }

    for (var i = 0; i < 8; i++) {
      final code = _code();

      final classRef = _db.collection('classes').doc();
      final codeRef = _db.collection('classCodes').doc(code);

      final existing = await codeRef.get();
      if (existing.exists) continue;

      final batch = _db.batch();

      batch.set(classRef, {
        'name': n,
        'section': s,
        'teacherId': uid,
        'teacherName': p.data()?['displayName'] ?? 'Teacher',
        'joinCode': code,
        'maxStudents': maxStudents,
        'enrolledCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      batch.set(codeRef, {
        'classId': classRef.id,
        'className': n,
        'section': s,
        'teacherId': uid,
        'joinCode': code,
        'isActive': true,
      });

      await batch.commit();

      return code;
    }

    throw StateError('Could not generate a unique class code.');
  }

  Future<void> joinClass(String inputCode) async {
    final code = inputCode.trim().toUpperCase();

    if (!RegExp(r'^[A-HJ-NP-Z2-9]{6}$').hasMatch(code)) {
      throw ArgumentError('Enter a valid six-character class code.');
    }

    final p = await _db.collection('users').doc(uid).get();

    if (!p.exists ||
        p.data()?['role'] != 'student' ||
        p.data()?['isActive'] != true) {
      throw StateError('An active student account is required.');
    }

    final codeDoc = await _db.collection('classCodes').doc(code).get();

    if (!codeDoc.exists) {
      throw StateError('Invalid class code.');
    }

    final d = codeDoc.data()!;

    if (d['isActive'] != true) {
      throw StateError('This class is inactive.');
    }

    final classId = d['classId'] as String;
    final teacherId = d['teacherId'] as String;

    final classRef = _db.collection('classes').doc(classId);
    final enrollmentRef = _db.collection('enrollments').doc('${classId}_$uid');

    await _db.runTransaction((transaction) async {
      // Read every required document before performing any writes.
      final old = await transaction.get(enrollmentRef);
      final classSnapshot = await transaction.get(classRef);

      if (old.exists) {
        throw StateError('You already joined this class.');
      }

      if (!classSnapshot.exists) {
        throw StateError('This class no longer exists.');
      }

      final classData = classSnapshot.data()!;

      if (classData['isActive'] != true ||
          classData['joinCode'] != code ||
          classData['teacherId'] != teacherId) {
        throw StateError('This class is inactive or its code is invalid.');
      }

      // New classes enforce their configured capacity.
      // Legacy classes without maxStudents remain joinable.
      if (classData.containsKey('maxStudents')) {
        final maxStudents = classData['maxStudents'];
        final enrolledCount = classData['enrolledCount'];

        if (maxStudents is! int ||
            enrolledCount is! int ||
            maxStudents < 1 ||
            enrolledCount < 0) {
          throw StateError('This class has an invalid enrollment limit.');
        }

        if (enrolledCount >= maxStudents) {
          throw StateError('This class has reached its enrollment limit.');
        }

        transaction.update(classRef, {'enrolledCount': enrolledCount + 1});
      }

      transaction.set(enrollmentRef, {
        'classId': classId,
        'className': d['className'],
        'section': d['section'],
        'studentId': uid,
        'studentName': (p.data()?['displayName'] ?? '').toString().trim(),
        'teacherId': teacherId,
        'joinCode': code,
        'joinedAt': FieldValue.serverTimestamp(),
      });
    });

    try {
      await NotificationService().notifyTeacherOfJoin(
        classId: classId,
        teacherId: teacherId,
      );
    } catch (_) {
      // Joining the class must still succeed if an optional notification fails.
    }
  }

  // Teacher-only class roster. The teacherId filter is required by Firestore rules.
  Stream<QuerySnapshot<Map<String, dynamic>>> studentsForClass(
    String classId,
  ) => _db
      .collection('enrollments')
      .where('classId', isEqualTo: classId)
      .where('teacherId', isEqualTo: uid)
      .snapshots();

  // All quiz attempts belonging to this teacher's class.
  Stream<QuerySnapshot<Map<String, dynamic>>> attemptsForClass(
    String classId,
  ) => _db
      .collection('quizAttempts')
      .where('classId', isEqualTo: classId)
      .where('teacherId', isEqualTo: uid)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> teacherQuizzesForClass(
    String id,
  ) => _db
      .collection('quizzes')
      .where('classId', isEqualTo: id)
      .where('teacherId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots();
  Stream<QuerySnapshot<Map<String, dynamic>>> studentQuizzesForClass(
    String id,
  ) => _db
      .collection('quizzes')
      .where('classId', isEqualTo: id)
      .where('isPublished', isEqualTo: true)
      .snapshots();
  Future<void> createQuiz({
    required String classId,
    required String title,
    required List<Map<String, dynamic>> questions,
    String quizType = 'multiple_choice',
    bool isPublished = true,
  }) async {
    const supportedTypes = {
      'multiple_choice',
      'true_false',
      'identification',
      'multiple_select',
      'matching',
      'essay',
    };

    final t = title.trim();

    if (t.isEmpty ||
        t.length > 140 ||
        questions.isEmpty ||
        questions.length > 100) {
      throw ArgumentError('Enter a title and between 1 and 100 questions.');
    }

    if (!supportedTypes.contains(quizType)) {
      throw ArgumentError('Unsupported quiz type.');
    }

    final c = await _db.collection('classes').doc(classId).get();

    if (!c.exists ||
        c.data()?['teacherId'] != uid ||
        c.data()?['isActive'] != true) {
      throw StateError('You can only create quizzes in your active classes.');
    }

    final normalized = <Map<String, dynamic>>[];

    for (var i = 0; i < questions.length; i++) {
      final x = questions[i];
      final text = (x['text'] ?? '').toString().trim();
      final timer = (x['timerSeconds'] as num?)?.toInt() ?? 30;

      if (text.isEmpty || timer < 5 || timer > 600) {
        throw ArgumentError(
          'Question ${i + 1} is incomplete or has an invalid timer.',
        );
      }

      final item = <String, dynamic>{'text': text, 'timerSeconds': timer};

      switch (quizType) {
        case 'multiple_choice':
        case 'true_false':
          final options =
              (x['options'] as List?)
                  ?.map((v) => v.toString().trim())
                  .toList() ??
              (quizType == 'true_false' ? ['True', 'False'] : <String>[]);

          final correct = x['correctIndex'];

          final validTrueFalseOptions =
              quizType != 'true_false' ||
              (options.length == 2 &&
                  options.toSet().length == 2 &&
                  options.map((v) => v.toLowerCase()).toSet().containsAll({
                    'true',
                    'false',
                  }));

          if ((quizType == 'multiple_choice' &&
                  (options.length != 4 ||
                      options.toSet().length != 4 ||
                      options.any((v) => v.isEmpty))) ||
              !validTrueFalseOptions ||
              correct is! int ||
              correct < 0 ||
              correct >= options.length) {
            throw ArgumentError(
              'Question ${i + 1} has invalid options or answer.',
            );
          }

          item['options'] = options;
          item['correctIndex'] = correct;
          break;

        case 'identification':
          final answer = (x['correctAnswer'] ?? '').toString().trim();

          if (answer.isEmpty) {
            throw ArgumentError('Question ${i + 1} needs a correct answer.');
          }

          item['correctAnswer'] = answer;
          break;

        case 'multiple_select':
          final options =
              (x['options'] as List?)
                  ?.map((v) => v.toString().trim())
                  .toList() ??
              [];
          final correct =
              (x['correctIndices'] as List?)
                  ?.whereType<num>()
                  .map((v) => v.toInt())
                  .toList() ??
              [];

          if (options.length < 2 ||
              options.length > 6 ||
              options.any((v) => v.isEmpty) ||
              correct.isEmpty ||
              correct.any((v) => v < 0 || v >= options.length) ||
              correct.toSet().length != correct.length) {
            throw ArgumentError(
              'Question ${i + 1} needs valid options and correct selections.',
            );
          }

          item['options'] = options;
          item['correctIndices'] = correct;
          break;

        case 'matching':
          final pairs =
              (x['pairs'] as List?)
                  ?.whereType<Map>()
                  .map(
                    (pair) => {
                      'left': (pair['left'] ?? '').toString().trim(),
                      'right': (pair['right'] ?? '').toString().trim(),
                    },
                  )
                  .toList() ??
              [];

          if (pairs.length < 2 ||
              pairs.any(
                (p) =>
                    (p['left'] as String).isEmpty ||
                    (p['right'] as String).isEmpty,
              )) {
            throw ArgumentError(
              'Question ${i + 1} needs at least two complete matching pairs.',
            );
          }

          item['pairs'] = pairs;
          break;

        case 'essay':
          // Essay answers are reviewed and graded by the teacher.
          break;
      }

      normalized.add(item);
    }

    final quiz = _db.collection('quizzes').doc();
    final batch = _db.batch();

    batch.set(quiz, {
      'classId': classId,
      'teacherId': uid,
      'title': t,
      'quizType': quizType,
      'questionCount': normalized.length,
      'durationMinutes': 10,
      'createdAt': FieldValue.serverTimestamp(),
      'isPublished': isPublished,
    });

    for (var i = 0; i < normalized.length; i++) {
      final item = normalized[i];
      final question = quiz.collection('questions').doc();

      final questionData = <String, dynamic>{
        'text': item['text'],
        'order': i,
        'classId': classId,
        'teacherId': uid,
        'timerSeconds': item['timerSeconds'],
        'quizType': quizType,
      };

      if (item.containsKey('options')) {
        questionData['options'] = item['options'];
      }
      if (item.containsKey('pairs')) {
        questionData['pairs'] = item['pairs'];
      }

      batch.set(question, questionData);

      final answerKey = <String, dynamic>{
        'quizId': quiz.id,
        'classId': classId,
        'quizType': quizType,
        'points': 1,
      };

      if (item.containsKey('correctIndex')) {
        answerKey['correctIndex'] = item['correctIndex'];
      }
      if (item.containsKey('correctAnswer')) {
        answerKey['correctAnswer'] = item['correctAnswer'];
      }
      if (item.containsKey('correctIndices')) {
        answerKey['correctIndices'] = item['correctIndices'];
      }
      if (quizType == 'matching') {
        answerKey['correctPairs'] = {
          for (final pair in item['pairs'] as List) pair['left']: pair['right'],
        };
      }
      if (quizType == 'essay') {
        answerKey['manualReview'] = true;
      }

      batch.set(_db.collection('answerKeys').doc(question.id), answerKey);
    }

    await batch.commit();

    if (isPublished) {
      try {
        await NotificationService().notifyClassOfQuiz(
          classId: classId,
          quizTitle: t,
        );
      } catch (_) {
        // Quiz creation must not be rolled back by an optional notification.
      }
    }
  }
}
