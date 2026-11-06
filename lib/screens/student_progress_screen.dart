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
          if (snapshot.hasError)
            return const Center(child: Text('Could not load your progress.'));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final attempts = snapshot.data!.docs
              .where((d) => d.data()['status'] == 'submitted')
              .toList();
          final percentages = attempts
              .map((d) => (d.data()['percentage'] as num?)?.toDouble() ?? 0)
              .toList();
          final average = percentages.isEmpty
              ? 0.0
              : percentages.reduce((a, b) => a + b) / percentages.length;
          final best = percentages.isEmpty
              ? 0.0
              : percentages.reduce((a, b) => a > b ? a : b);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  _metric(
                    'Completed',
                    '${attempts.length}',
                    Icons.task_alt_rounded,
                  ),
                  const SizedBox(width: 10),
                  _metric(
                    'Average',
                    '${average.toStringAsFixed(0)}%',
                    Icons.insights_rounded,
                  ),
                  const SizedBox(width: 10),
                  _metric(
                    'Best',
                    '${best.toStringAsFixed(0)}%',
                    Icons.emoji_events_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'Quiz History',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              if (attempts.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Your completed quizzes will appear here.'),
                  ),
                ),
              ...attempts.map((doc) {
                final d = doc.data();
                final pct = ((d['percentage'] as num?)?.toDouble() ?? 0)
                    .clamp(0, 100)
                    .toDouble();
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d['quizTitle']?.toString() ?? 'Quiz',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: qmNavy,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${d['score'] ?? 0} / ${d['totalPoints'] ?? 0} points',
                              ),
                            ),
                            Text(
                              '${pct.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: qmBlue,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: pct / 100, minHeight: 7),
                      ],
                    ),
                  ),
                );
              }),
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Progress reflects practice quiz submissions saved to your account.',
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
