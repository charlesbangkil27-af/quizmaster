import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClassroomService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String get uid => FirebaseAuth.instance.currentUser?.uid ?? (throw StateError('Please sign in.'));
  Stream<QuerySnapshot<Map<String,dynamic>>> teacherClasses() => _db.collection('classes').where('teacherId',isEqualTo:uid).orderBy('createdAt',descending:true).snapshots();
  Stream<QuerySnapshot<Map<String,dynamic>>> studentClasses() => _db.collection('enrollments').where('studentId',isEqualTo:uid).snapshots();
  String _code() { const chars='ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; final r=Random.secure(); return List.generate(6,(_)=>chars[r.nextInt(chars.length)]).join(); }



Future<String> createClass(String name, String section) async {
  final n = name.trim();
  final s = section.trim();

  if (n.isEmpty || n.length > 100 || s.isEmpty || s.length > 60) {
    throw ArgumentError('Enter a valid class name and section.');
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

    var collision = false;

    await _db.runTransaction((transaction) async {
      final existing = await transaction.get(codeRef);

      if (existing.exists) {
        collision = true;
        return;
      }

      transaction.set(classRef, {
        'name': n,
        'section': s,
        'teacherId': uid,
        'teacherName': p.data()?['displayName'] ?? 'Teacher',
        'joinCode': code,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      transaction.set(codeRef, {
        'classId': classRef.id,
        'teacherId': uid,
        'joinCode': code,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    if (!collision) return code;
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

  // Look up only the exact class code.
  final codeDoc = await _db.collection('classCodes').doc(code).get();

  if (!codeDoc.exists || codeDoc.data()?['isActive'] != true) {
    throw StateError('Invalid or inactive class code.');
  }

  final data = codeDoc.data()!;
  final classId = data['classId'] as String;
  final teacherId = data['teacherId'] as String;

  final enrollmentRef = _db
      .collection('enrollments')
      .doc('${classId}_$uid');

  await _db.runTransaction((transaction) async {
    final existing = await transaction.get(enrollmentRef);

    if (existing.exists) {
      throw StateError('You already joined this class.');
    }

    transaction.set(enrollmentRef, {
      'classId': classId,
      'studentId': uid,
      'teacherId': teacherId,
      'joinCode': code,
      'joinedAt': FieldValue.serverTimestamp(),
    });
  });
}

  Stream<QuerySnapshot<Map<String,dynamic>>> teacherQuizzesForClass(String id)=>_db.collection('quizzes').where('classId',isEqualTo:id).where('teacherId',isEqualTo:uid).orderBy('createdAt',descending:true).snapshots();
  Stream<QuerySnapshot<Map<String,dynamic>>> studentQuizzesForClass(String id)=>_db.collection('quizzes').where('classId',isEqualTo:id).where('isPublished',isEqualTo:true).snapshots();
  Future<void> createQuiz({required String classId,required String title,required List<Map<String,dynamic>> questions}) async {
    final t=title.trim(); if(t.isEmpty||t.length>140||questions.isEmpty||questions.length>100) throw ArgumentError('Enter a title and between 1 and 100 questions.');
    final c=await _db.collection('classes').doc(classId).get(); if(!c.exists||c.data()?['teacherId']!=uid||c.data()?['isActive']!=true) throw StateError('You can only create quizzes in your active classes.');
    final q=<Map<String,dynamic>>[]; for(var i=0;i<questions.length;i++){final x=questions[i], text=(x['text']??'').toString().trim(), opts=(x['options'] as List?)?.map((v)=>v.toString().trim()).toList()??[], correct=x['correctIndex'], timer=(x['timerSeconds'] as num?)?.toInt()??30; if(text.isEmpty||opts.length!=4||opts.any((v)=>v.isEmpty)||correct is! int||correct<0||correct>3||timer<5||timer>600) throw ArgumentError('Question ${i+1} is incomplete or has an invalid timer (5–600 seconds).'); q.add({'text':text,'options':opts,'correctIndex':correct,'timerSeconds':timer});}
    final quiz=_db.collection('quizzes').doc(), batch=_db.batch(); batch.set(quiz,{'classId':classId,'teacherId':uid,'title':t,'questionCount':q.length,'durationMinutes':10,'createdAt':FieldValue.serverTimestamp(),'isPublished':true});
    for(var i=0;i<q.length;i++){final question=quiz.collection('questions').doc(); batch.set(question,{'text':q[i]['text'],'options':q[i]['options'],'order':i,'classId':classId,'teacherId':uid,'timerSeconds':q[i]['timerSeconds']}); batch.set(_db.collection('answerKeys').doc(question.id),{'quizId':quiz.id,'classId':classId,'correctIndex':q[i]['correctIndex'],'points':1});} await batch.commit();
  }
}
