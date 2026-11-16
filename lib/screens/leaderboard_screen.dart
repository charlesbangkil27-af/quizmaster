import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../main.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({
    super.key,
    required this.classId,
    required this.className,
  });
  final String classId;
  final String className;

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('leaderboards')
        .doc(classId)
        .collection('entries')
        .orderBy('averagePercentage', descending: true)
        .limit(50)
        .snapshots();
    return Scaffold(
      appBar: AppBar(title: const Text('Class Leaderboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(className, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          const Text(
            'Practice ranking based on submitted quiz scores.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Could not load leaderboard. Check Firestore rules.',
                  ),
                );
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final entries = snapshot.data!.docs;
              if (entries.isEmpty)
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No submitted quizzes yet.'),
                );
              return Card(
                child: Column(
                  children: [
                    for (var i = 0; i < entries.length; i++)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: i == 0
                              ? const Color(0xFFFFF0C2)
                              : const Color(0xFFE9EDFF),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        title: Text(
                          entries[i].data()['displayName']?.toString() ??
                              'Student',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: qmNavy,
                          ),
                        ),
                        subtitle: Text(
                          '${entries[i].data()['attempts'] ?? 0} quizzes completed',
                        ),
                        trailing: Text(
                          '${((entries[i].data()['averagePercentage'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 17,
                            color: qmBlue,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
