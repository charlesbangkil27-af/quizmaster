import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
class QuizService {
 final _db=FirebaseFirestore.instance;
 String get _uid=>FirebaseAuth.instance.currentUser?.uid??(throw StateError('Please sign in.'));
 Future<Map<String,dynamic>> startQuiz(String quizId) async {
  final qr=_db.collection('quizzes').doc(quizId), qs=await qr.get(); if(!qs.exists||qs.data()?['isPublished']!=true) throw StateError('Quiz unavailable.'); final quiz=qs.data()!;
  final enrollment=await _db.collection('enrollments').doc('${quiz['classId']}_$_uid').get(); if(!enrollment.exists) throw StateError('Join this class before taking its quiz.');
  final snap=await qr.collection('questions').orderBy('order').get(); if(snap.docs.isEmpty) throw StateError('This quiz has no questions.');
  final duration=((quiz['durationMinutes'] as num?)?.toInt()??10).clamp(1,180), now=Timestamp.now(), expires=Timestamp.fromMillisecondsSinceEpoch(now.millisecondsSinceEpoch+duration*60000), attempt=_db.collection('quizAttempts').doc();
  await attempt.set({'uid':_uid,'quizId':quizId,'classId':quiz['classId'],'quizTitle':quiz['title'],'status':'inProgress','startedAt':now,'expiresAt':expires,'durationMinutes':duration});
  return {'attemptId':attempt.id,'durationMinutes':duration,'expiresAt':expires.millisecondsSinceEpoch,'questions':snap.docs.map((d)=>{'id':d.id,...d.data()}).toList()};
 }
 Future<Map<String,dynamic>> submitQuiz({required String attemptId,required Map<String,String> answers}) async {
  final ref=_db.collection('quizAttempts').doc(attemptId), a=await ref.get(); if(!a.exists||a.data()?['uid']!=_uid) throw StateError('Attempt not found.'); final data=a.data()!; if(data['status']=='submitted') throw StateError('Already submitted.');
  final questions=await _db.collection('quizzes').doc(data['quizId']).collection('questions').get(); var score=0,total=0;
  for(final q in questions.docs){final key=await _db.collection('answerKeys').doc(q.id).get(); if(!key.exists) continue; final k=key.data()!, points=(k['points'] as num?)?.toInt()??1, opts=(q.data()['options'] as List?)?.map((v)=>v.toString()).toList()??[]; total+=points; if(opts.indexOf(answers[q.id]??'')==k['correctIndex']) score+=points;}
  final pct=total==0?0:(score/total*100).round(); await ref.update({'status':'submitted','answers':answers,'score':score,'totalPoints':total,'percentage':pct,'submittedAt':FieldValue.serverTimestamp(),'wasLate':Timestamp.now().millisecondsSinceEpoch>(data['expiresAt'] as Timestamp).millisecondsSinceEpoch}); return {'score':score,'totalPoints':total,'percentage':pct};
 }
 Stream<QuerySnapshot<Map<String,dynamic>>> attemptsFor(String uid)=>_db.collection('quizAttempts').where('uid',isEqualTo:uid).orderBy('startedAt',descending:true).snapshots();
}
