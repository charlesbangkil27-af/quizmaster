import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../services/quiz_service.dart';

class StudentProgressScreen extends StatelessWidget {
  const StudentProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('My Progress')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: QuizService().attemptsFor(uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load your progress.'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final submitted = snapshot.data!.docs
              .where((doc) => doc.data()['status'] == 'submitted')
              .toList();

          final pendingAttempts = submitted
              .where((doc) => doc.data()['manualReviewStatus'] == 'pending')
              .toList();

          final completedAttempts = submitted
              .where((doc) => doc.data()['manualReviewStatus'] != 'pending')
              .toList();

          final percentages = completedAttempts
              .map((doc) => (doc.data()['percentage'] as num?)?.toDouble() ?? 0)
              .toList();

          final average = percentages.isEmpty
              ? 0.0
              : percentages.reduce((a, b) => a + b) / percentages.length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  _metric(
                    'Completed',
                    '${completedAttempts.length}',
                    Icons.task_alt_rounded,
                  ),
                  const SizedBox(width: 10),
                  _metric(
                    'Pending',
                    '${pendingAttempts.length}',
                    Icons.pending_actions_rounded,
                  ),
                  const SizedBox(width: 10),
                  _metric(
                    'Average',
                    '${average.toStringAsFixed(0)}%',
                    Icons.insights_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'Quiz History',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              if (submitted.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Your completed quizzes will appear here.'),
                  ),
                ),
              ...submitted.map((doc) {
                final data = doc.data();
                final isPending = data['manualReviewStatus'] == 'pending';

                final percentage =
                    ((data['percentage'] as num?)?.toDouble() ?? 0)
                        .clamp(0, 100)
                        .toDouble();

                final rawFeedback = data['essayFeedback'];
                final feedback = rawFeedback is Map
                    ? Map<String, dynamic>.from(rawFeedback)
                    : <String, dynamic>{};

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['quizTitle']?.toString() ?? 'Quiz',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: qmNavy,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (isPending) ...[
                          const Row(
                            children: [
                              Icon(
                                Icons.pending_actions,
                                color: Colors.orange,
                                size: 19,
                              ),
                              SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  'Awaiting teacher review',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Your essay has been submitted. '
                            'Your final score will appear here after grading.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${data['score'] ?? 0} / '
                                  '${data['totalPoints'] ?? 0} points',
                                ),
                              ),
                              Text(
                                '${percentage.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: qmBlue,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: percentage / 100,
                            minHeight: 7,
                          ),
                          if (data['manualReviewStatus'] == 'graded' &&
                              feedback.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            const Divider(),
                            const Text(
                              'Teacher Feedback',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: qmNavy,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...feedback.entries
                                .where(
                                  (entry) =>
                                      entry.value.toString().trim().isNotEmpty,
                                )
                                .toList()
                                .asMap()
                                .entries
                                .map((entry) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      'Question ${entry.key + 1}: '
                                      '${entry.value}',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  );
                                }),
                          ],
                        ],
                      ],
                    ),
                  ),
                );
              }),
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Your progress reflects quiz submissions saved to your account.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _metric(String label, String value, IconData icon) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: qmBlue),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: qmNavy,
              ),
            ),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    ),
  );
}
