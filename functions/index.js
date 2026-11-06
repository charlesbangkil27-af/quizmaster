const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const crypto = require('node:crypto');

initializeApp();
const db = getFirestore();
const REGION = 'us-central1';
const CODE_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

function requireAuth(request) {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Please sign in first.');
  return request.auth.uid;
}

async function requireActiveRole(uid, role) {
  const snap = await db.collection('users').doc(uid).get();
  const profile = snap.data();
  if (!profile || profile.isActive !== true || profile.role !== role) {
    throw new HttpsError('permission-denied', `An active ${role} account is required.`);
  }
  return profile;
}

function makeJoinCode() {
  const bytes = crypto.randomBytes(6);
  return Array.from(bytes, (byte) => CODE_CHARS[byte % CODE_CHARS.length]).join('');
}

exports.createClass = onCall({ region: REGION }, async (request) => {
  const uid = requireAuth(request);
  const profile = await requireActiveRole(uid, 'teacher');
  const name = String(request.data?.name ?? '').trim();
  const section = String(request.data?.section ?? '').trim();
  if (!name || !section || name.length > 100 || section.length > 60) {
    throw new HttpsError('invalid-argument', 'Enter a valid class name and section.');
  }

  let joinCode;
  let collision = true;
  for (let attempt = 0; attempt < 8 && collision; attempt += 1) {
    joinCode = makeJoinCode();
    const existing = await db.collection('classes').where('joinCode', '==', joinCode).limit(1).get();
    collision = !existing.empty;
  }
  if (collision) throw new HttpsError('resource-exhausted', 'Could not generate a unique class code. Try again.');

  const ref = db.collection('classes').doc();
  await ref.create({
    name,
    section,
    teacherId: uid,
    teacherName: profile.displayName || 'Teacher',
    joinCode,
    createdAt: FieldValue.serverTimestamp(),
    isActive: true,
  });
  return { classId: ref.id, joinCode };
});

exports.joinClass = onCall({ region: REGION }, async (request) => {
  const uid = requireAuth(request);
  await requireActiveRole(uid, 'student');
  const joinCode = String(request.data?.joinCode ?? '').trim().toUpperCase();
  if (!/^[A-HJ-NP-Z2-9]{6}$/.test(joinCode)) {
    throw new HttpsError('invalid-argument', 'Enter a valid six-character class code.');
  }

  const matches = await db.collection('classes')
    .where('joinCode', '==', joinCode)
    .where('isActive', '==', true)
    .limit(2)
    .get();
  if (matches.empty) throw new HttpsError('not-found', 'Invalid or inactive class code.');
  if (matches.size > 1) throw new HttpsError('failed-precondition', 'This class code is not unique. Contact the teacher.');

  const classroom = matches.docs[0];
  const enrollmentRef = db.collection('enrollments').doc(`${classroom.id}_${uid}`);
  await db.runTransaction(async (transaction) => {
    const existing = await transaction.get(enrollmentRef);
    if (existing.exists) throw new HttpsError('already-exists', 'You already joined this class.');
    const classNow = await transaction.get(classroom.ref);
    if (!classNow.exists || classNow.data().isActive !== true) {
      throw new HttpsError('failed-precondition', 'This class is no longer active.');
    }
    transaction.create(enrollmentRef, {
      classId: classroom.id,
      className: classroom.data().name,
      section: classroom.data().section,
      studentId: uid,
      teacherId: classroom.data().teacherId,
      joinedAt: FieldValue.serverTimestamp(),
    });
  });
  return { classId: classroom.id, className: classroom.data().name };
});

exports.createQuiz = onCall({ region: REGION }, async (request) => {
  const uid = requireAuth(request);
  await requireActiveRole(uid, 'teacher');
  const classId = String(request.data?.classId ?? '');
  const title = String(request.data?.title ?? '').trim();
  const questions = request.data?.questions;
  if (!classId || !title || title.length > 140 || !Array.isArray(questions) || questions.length < 1 || questions.length > 100) {
    throw new HttpsError('invalid-argument', 'Provide a quiz title and between 1 and 100 questions.');
  }
  const classRef = db.collection('classes').doc(classId);
  const classSnap = await classRef.get();
  if (!classSnap.exists || classSnap.data().teacherId !== uid || classSnap.data().isActive !== true) {
    throw new HttpsError('permission-denied', 'You can only create quizzes in your active classes.');
  }

  const normalized = questions.map((item, index) => {
    const text = String(item?.text ?? '').trim();
    const options = Array.isArray(item?.options) ? item.options.map((value) => String(value).trim()) : [];
    const correctIndex = Number(item?.correctIndex);
    if (!text || text.length > 1000 || options.length !== 4 || options.some((value) => !value || value.length > 300) || !Number.isInteger(correctIndex) || correctIndex < 0 || correctIndex > 3) {
      throw new HttpsError('invalid-argument', `Question ${index + 1} is incomplete or invalid.`);
    }
    return { text, options, correctIndex };
  });

  const quizRef = db.collection('quizzes').doc();
  const batch = db.batch();
  batch.create(quizRef, {
    classId,
    teacherId: uid,
    title,
    questionCount: normalized.length,
    durationMinutes: 10,
    createdAt: FieldValue.serverTimestamp(),
    isPublished: true,
  });
  normalized.forEach((item, index) => {
    const questionRef = quizRef.collection('questions').doc();
    batch.create(questionRef, { text: item.text, options: item.options, order: index });
    batch.create(db.collection('answerKeys').doc(questionRef.id), {
      quizId: quizRef.id,
      classId,
      correctIndex: item.correctIndex,
      points: 1,
    });
  });
  await batch.commit();
  return { quizId: quizRef.id };
});

exports.startQuiz = onCall({ region: REGION }, async (request) => {
  const uid = requireAuth(request);
  await requireActiveRole(uid, 'student');
  const quizId = String(request.data?.quizId ?? '');
  const quizRef = db.collection('quizzes').doc(quizId);
  const quizSnap = await quizRef.get();
  if (!quizSnap.exists || quizSnap.data().isPublished !== true) {
    throw new HttpsError('not-found', 'This quiz is not available.');
  }
  const quiz = quizSnap.data();
  const enrollment = await db.collection('enrollments').doc(`${quiz.classId}_${uid}`).get();
  if (!enrollment.exists) throw new HttpsError('permission-denied', 'Join this class before taking its quiz.');

  const questionsSnap = await quizRef.collection('questions').orderBy('order').get();
  if (questionsSnap.empty) throw new HttpsError('failed-precondition', 'This quiz has no questions.');
  const durationMinutes = Math.min(180, Math.max(1, Number(quiz.durationMinutes) || 10));
  const attemptRef = db.collection('quizAttempts').doc();
  const startedAt = Timestamp.now();
  const expiresAt = Timestamp.fromMillis(startedAt.toMillis() + durationMinutes * 60 * 1000);
  await attemptRef.create({
    uid,
    quizId,
    classId: quiz.classId,
    quizTitle: quiz.title,
    status: 'inProgress',
    startedAt,
    expiresAt,
    durationMinutes,
  });

  return {
    attemptId: attemptRef.id,
    durationMinutes,
    expiresAt: expiresAt.toMillis(),
    questions: questionsSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
  };
});

exports.submitQuiz = onCall({ region: REGION }, async (request) => {
  const uid = requireAuth(request);
  await requireActiveRole(uid, 'student');
  const attemptId = String(request.data?.attemptId ?? '');
  const answers = request.data?.answers;
  if (!attemptId || !answers || typeof answers !== 'object' || Array.isArray(answers)) {
    throw new HttpsError('invalid-argument', 'A valid attempt and answer map are required.');
  }

  const attemptRef = db.collection('quizAttempts').doc(attemptId);
  const attemptSnap = await attemptRef.get();
  if (!attemptSnap.exists || attemptSnap.data().uid !== uid) {
    throw new HttpsError('permission-denied', 'This quiz attempt does not belong to you.');
  }
  const attempt = attemptSnap.data();
  const questionsSnap = await db.collection('quizzes').doc(attempt.quizId).collection('questions').get();
  const answerKeySnaps = await Promise.all(questionsSnap.docs.map((doc) => db.collection('answerKeys').doc(doc.id).get()));
  const keyByQuestion = new Map(answerKeySnaps.filter((snap) => snap.exists).map((snap) => [snap.id, snap.data()]));

  let score = 0;
  let totalPoints = 0;
  for (const question of questionsSnap.docs) {
    const key = keyByQuestion.get(question.id);
    if (!key) continue;
    const points = Number(key.points) || 1;
    totalPoints += points;
    const selected = answers[question.id];
    const options = Array.isArray(question.data().options) ? question.data().options : [];
    const selectedIndex = options.indexOf(String(selected ?? ''));
    if (selectedIndex === Number(key.correctIndex)) score += points;
  }

  let alreadySubmitted = false;
  await db.runTransaction(async (transaction) => {
    const current = await transaction.get(attemptRef);
    if (!current.exists || current.data().uid !== uid) {
      throw new HttpsError('permission-denied', 'Quiz attempt not found.');
    }
    if (current.data().status === 'submitted') {
      alreadySubmitted = true;
      return;
    }
    transaction.update(attemptRef, {
      status: 'submitted',
      answers,
      score,
      totalPoints,
      submittedAt: FieldValue.serverTimestamp(),
      wasLate: Timestamp.now().toMillis() > current.data().expiresAt.toMillis(),
    });
  });
  if (alreadySubmitted) throw new HttpsError('already-exists', 'This quiz has already been submitted.');
  return { score, totalPoints, percentage: totalPoints ? Math.round((score / totalPoints) * 100) : 0 };
});
