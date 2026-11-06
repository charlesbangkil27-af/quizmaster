import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../main.dart';

class TeacherDashboardScreen extends StatelessWidget {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final db = FirebaseFirestore.instance;
    final classes = db
        .collection('classes')
        .where('teacherId', isEqualTo: uid)
        .snapshots();
    final students = db
        .collection('enrollments')
        .where('teacherId', isEqualTo: uid)
        .snapshots();
    final quizzes = db
        .collection('quizzes')
        .where('teacherId', isEqualTo: uid)
        .snapshots();
    final attempts = db
        .collection('quizAttempts')
        .where('teacherId', isEqualTo: uid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Teacher Dashboard')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: classes,
        builder: (context, c) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: students,
          builder: (context, s) =>
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: quizzes,
                builder: (context, q) =>
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: attempts,
                      builder: (context, a) {
                     if ([c, s, q, a].any((x) => x.hasError)) {
  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dashboard Loading Errors',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (c.hasError) Text('Classes: ${c.error}'),
        if (s.hasError) Text('Enrollments: ${s.error}'),
        if (q.hasError) Text('Quizzes: ${q.error}'),
        if (a.hasError) Text('Quiz Attempts: ${a.error}'),
      ],
    ),
  );
}
                        if ([c, s, q, a].any((x) => !x.hasData)) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final submittedDocs = a.data!.docs
                            .where((d) => d.data()['status'] == 'submitted')
                            .toList();
                        final scores = submittedDocs
                            .map(
                              (d) =>
                                  (d.data()['percentage'] as num?)
                                      ?.toDouble() ??
                                  0,
                            )
                            .toList();
                        final average = scores.isEmpty
                            ? 0.0
                            : scores.reduce((x, y) => x + y) / scores.length;
                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            const Text(
                              'Your teaching overview',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: qmNavy,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _tile(
                                  'Classes',
                                  '${c.data!.docs.length}',
                                  Icons.school_rounded,
                                ),
                                _tile(
                                  'Students',
                                  '${s.data!.docs.length}',
                                  Icons.groups_rounded,
                                ),
                                _tile(
                                  'Quizzes',
                                  '${q.data!.docs.length}',
                                  Icons.quiz_rounded,
                                ),
                                _tile(
                                  'Submissions',
                                  '${submittedDocs.length}',
                                  Icons.assignment_turned_in_rounded,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Average student score',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${average.toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                        fontSize: 30,
                                        color: qmBlue,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const Text(
                                      'Based on submitted practice quizzes.',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Recent quiz submissions',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: qmNavy,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (submittedDocs.isEmpty)
                              const Card(
                                child: Padding(
                                  padding: EdgeInsets.all(18),
                                  child: Text('No quiz submissions yet.'),
                                ),
                              )
                            else
                              ...submittedDocs.take(20).map((doc) {
                                final d = doc.data();
                                return Card(
                                  child: ListTile(
                                    leading: const Icon(
                                      Icons.assignment_turned_in_rounded,
                                      color: qmBlue,
                                    ),
                                    title: Text(
                                      d['quizTitle']?.toString() ?? 'Quiz',
                                    ),
                                    subtitle: Text(
                                      'Score: ${d['score'] ?? 0}/${d['totalPoints'] ?? 0}',
                                    ),
                                    trailing: Text('${d['percentage'] ?? 0}%'),
                                  ),
                                );
                              }),
                            const Padding(
                              padding: EdgeInsets.only(top: 10),
                              child: Text(
                                'Dashboard statistics include submissions made after this update.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
              ),
        ),
      ),
    );
  }

  Widget _tile(String label, String value, IconData icon) => SizedBox(
    width: 160,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: qmBlue),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                color: qmNavy,
              ),
            ),
            Text(label),
          ],
        ),
      ),
    ),
  );
}
