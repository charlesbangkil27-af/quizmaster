import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String get uid =>
      FirebaseAuth.instance.currentUser?.uid ??
      (throw StateError('Please sign in.'));

  Stream<QuerySnapshot<Map<String, dynamic>>> notifications() => _db
      .collection('notifications')
      .where('recipientId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots();

  Future<void> markRead(String id) =>
      _db.collection('notifications').doc(id).update({'isRead': true});

  Future<void> createAnnouncement({
    required String classId,
    required String title,
    required String message,
  }) async {
    final cleanTitle = title.trim();
    final cleanMessage = message.trim();
    if (cleanTitle.isEmpty || cleanMessage.isEmpty) {
      throw ArgumentError('Enter an announcement title and message.');
    }
    if (cleanTitle.length > 100 || cleanMessage.length > 1000) {
      throw ArgumentError('Announcement is too long.');
    }
    final classDoc = await _db.collection('classes').doc(classId).get();
    if (!classDoc.exists || classDoc.data()?['teacherId'] != uid) {
      throw StateError('You can only announce in your own class.');
    }
    final students = await _db
        .collection('enrollments')
        .where('classId', isEqualTo: classId)
        .where('teacherId', isEqualTo: uid)
        .get();
    for (var start = 0; start < students.docs.length; start += 450) {
      final batch = _db.batch();
      for (final enrollment in students.docs.skip(start).take(450)) {
        final ref = _db.collection('notifications').doc();
        batch.set(ref, {
          'recipientId': enrollment.data()['studentId'],
          'senderId': uid,
          'classId': classId,
          'type': 'announcement',
          'title': cleanTitle,
          'body': cleanMessage,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  Future<void> notifyClassOfQuiz({
    required String classId,
    required String quizTitle,
  }) async {
    final students = await _db
        .collection('enrollments')
        .where('classId', isEqualTo: classId)
        .where('teacherId', isEqualTo: uid)
        .get();
    for (var start = 0; start < students.docs.length; start += 450) {
      final batch = _db.batch();
      for (final enrollment in students.docs.skip(start).take(450)) {
        final ref = _db.collection('notifications').doc();
        batch.set(ref, {
          'recipientId': enrollment.data()['studentId'],
          'senderId': uid,
          'classId': classId,
          'type': 'quiz',
          'title': 'New quiz available',
          'body': quizTitle,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  Future<void> notifyTeacherOfJoin({
    required String classId,
    required String teacherId,
  }) async {
    final ref = _db.collection('notifications').doc();
    await ref.set({
      'recipientId': teacherId,
      'senderId': uid,
      'studentId': uid,
      'classId': classId,
      'type': 'student_joined',
      'title': 'A student joined your class',
      'body': FirebaseAuth.instance.currentUser?.displayName ?? 'A student',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
