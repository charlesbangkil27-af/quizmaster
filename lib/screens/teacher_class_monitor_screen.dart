import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/classroom_service.dart';

class TeacherClassMonitorScreen extends StatefulWidget {
  const TeacherClassMonitorScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  final String classId;
  final String className;

  @override
  State<TeacherClassMonitorScreen> createState() =>
      _TeacherClassMonitorScreenState();
}

class _TeacherClassMonitorScreenState extends State<TeacherClassMonitorScreen>
    with SingleTickerProviderStateMixin {
  final ClassroomService _service = ClassroomService();
  late final TabController _tabs;
  String? _selectedQuizId;

  static const Color _navy = Color(0xFF172554);
  static const Color _blue = Color(0xFF405DE6);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String _studentName(Map<String, dynamic> data) {
    final name = (data['studentName'] ?? '').toString().trim();
    return name.isEmpty ? 'Name unavailable' : name;
  }

  String _lastName(String name) {
    final trimmed = name.trim();
    if (trimmed.contains(',')) {
      return trimmed.split(',').first.trim().toLowerCase();
    }
    final parts = trimmed.split(RegExp(r'\s+'));
    return parts.isEmpty ? trimmed.toLowerCase() : parts.last.toLowerCase();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortedStudents(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final result = [...docs];
    result.sort((a, b) {
      final nameA = _studentName(a.data());
      final nameB = _studentName(b.data());
      final byLastName = _lastName(nameA).compareTo(_lastName(nameB));
      return byLastName != 0
          ? byLastName
          : nameA.toLowerCase().compareTo(nameB.toLowerCase());
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.className),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.groups_outlined), text: 'Students'),
            Tab(
              icon: Icon(Icons.assignment_turned_in_outlined),
              text: 'Submissions',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_buildStudentsTab(), _buildSubmissionsTab()],
      ),
    );
  }

  Widget _buildStudentsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.studentsForClass(widget.classId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Could not load class roster.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final students = _sortedStudents(snapshot.data!.docs);

        if (students.isEmpty) {
          return const Center(
            child: Text('No students have joined this class yet.'),
          );
        }

        return Column(
          children: [
            _summaryCard(
              icon: Icons.people_alt_outlined,
              label: 'Enrolled students',
              value: '${students.length}',
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                itemCount: students.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final data = students[index].data();
                  final name = _studentName(data);

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFE9EDFF),
                        child: Text(
                          name == 'Name unavailable'
                              ? '?'
                              : name.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: _blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          color: _navy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text('Joined ${_joinedDate(data['joinedAt'])}'),
                      trailing: const Icon(Icons.verified_user_outlined),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _joinedDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      return '${date.month}/${date.day}/${date.year}';
    }
    return 'Date unavailable';
  }

  Widget _buildSubmissionsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.teacherQuizzesForClass(widget.classId),
      builder: (context, quizSnapshot) {
        if (quizSnapshot.hasError) {
          return const Center(child: Text('Could not load class quizzes.'));
        }
        if (!quizSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final quizzes = quizSnapshot.data!.docs;
        if (quizzes.isEmpty) {
          return const Center(
            child: Text('No quizzes available for monitoring.'),
          );
        }

        final selected = quizzes.any((q) => q.id == _selectedQuizId)
            ? _selectedQuizId!
            : quizzes.first.id;
        final selectedQuiz = quizzes.firstWhere((q) => q.id == selected);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: DropdownButtonFormField<String>(
                initialValue: selected,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Select quiz',
                  prefixIcon: Icon(Icons.quiz_outlined),
                  border: OutlineInputBorder(),
                ),
                items: quizzes.map((quiz) {
                  final title = quiz.data()['title']?.toString() ?? 'Quiz';
                  return DropdownMenuItem(
                    value: quiz.id,
                    child: Text(title, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedQuizId = value);
                  }
                },
              ),
            ),
            Expanded(child: _buildQuizResults(selectedQuiz)),
          ],
        );
      },
    );
  }

  Widget _buildQuizResults(QueryDocumentSnapshot<Map<String, dynamic>> quiz) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.studentsForClass(widget.classId),
      builder: (context, studentSnapshot) {
        if (studentSnapshot.hasError) {
          return const Center(child: Text('Could not load students.'));
        }
        if (!studentSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _service.attemptsForClass(widget.classId),
          builder: (context, attemptSnapshot) {
            if (attemptSnapshot.hasError) {
              return const Center(child: Text('Could not load submissions.'));
            }
            if (!attemptSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final students = _sortedStudents(studentSnapshot.data!.docs);
            final attempts = attemptSnapshot.data!.docs
                .where((doc) => doc.data()['quizId'] == quiz.id)
                .toList();

            // Select only the latest attempt for each enrolled student.
            final latestAttemptsByUid =
                <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

            for (final doc in attempts) {
              final uid = (doc.data()['uid'] ?? '').toString();
              if (uid.isEmpty) continue;

              final existing = latestAttemptsByUid[uid];
              final currentTime = doc.data()['startedAt'];
              final existingTime = existing?.data()['startedAt'];

              final currentMillis = currentTime is Timestamp
                  ? currentTime.millisecondsSinceEpoch
                  : 0;
              final existingMillis = existingTime is Timestamp
                  ? existingTime.millisecondsSinceEpoch
                  : 0;

              if (existing == null || currentMillis >= existingMillis) {
                latestAttemptsByUid[uid] = doc;
              }
            }

            // Count the same latest attempts that will appear in the list.
            var completed = 0;
            var pending = 0;
            var inProgress = 0;
            var notSubmitted = 0;

            for (final studentDoc in students) {
              final uid = (studentDoc.data()['studentId'] ?? '').toString();
              final attempt = latestAttemptsByUid[uid]?.data();

              if (attempt == null) {
                notSubmitted++;
              } else if (attempt['status'] == 'inProgress') {
                inProgress++;
              } else if (attempt['status'] == 'submitted' &&
                  attempt['manualReviewStatus'] == 'pending') {
                pending++;
              } else if (attempt['status'] == 'submitted') {
                completed++;
              } else {
                notSubmitted++;
              }
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _countChip('Submitted', completed, Colors.green),
                      _countChip('Pending review', pending, Colors.orange),
                      _countChip('In progress', inProgress, Colors.blue),
                      _countChip(
                        'Not submitted',
                        notSubmitted < 0 ? 0 : notSubmitted,
                        Colors.grey,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: students.isEmpty
                      ? const Center(child: Text('No enrolled students.'))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                          itemCount: students.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final student = students[index].data();
                            final uid = student['studentId']?.toString() ?? '';

                            final attempt = latestAttemptsByUid[uid]?.data();

                            return _submissionTile(
                              _studentName(student),
                              attempt,
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _submissionTile(String name, Map<String, dynamic>? attempt) {
    String status;
    String detail;
    Color color;
    IconData icon;

    if (attempt == null) {
      status = 'Not submitted';
      detail = 'No attempt recorded';
      color = Colors.grey;
      icon = Icons.hourglass_empty;
    } else if (attempt['status'] == 'inProgress') {
      status = 'In progress';
      detail = 'Quiz started, awaiting submission';
      color = Colors.blue;
      icon = Icons.pending_outlined;
    } else if (attempt['manualReviewStatus'] == 'pending') {
      status = 'Pending review';
      detail = 'Essay answers need teacher grading';
      color = Colors.orange;
      icon = Icons.rate_review_outlined;
    } else if (attempt['status'] == 'submitted') {
      final score = (attempt['score'] as num?)?.toString() ?? '0';
      final total = (attempt['totalPoints'] as num?)?.toString() ?? '0';
      final percentage =
          (attempt['percentage'] as num?)?.toStringAsFixed(0) ?? '0';
      status = 'Submitted';
      detail = 'Score: $score / $total points ($percentage%)';
      color = Colors.green;
      icon = Icons.check_circle_outline;
    } else {
      status = 'Not submitted';
      detail = 'No completed submission';
      color = Colors.grey;
      icon = Icons.hourglass_empty;
    }

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(
          name,
          style: const TextStyle(color: _navy, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(detail),
        trailing: Text(
          status,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: ListTile(
        leading: Icon(icon, color: _blue, size: 30),
        title: Text(label),
        trailing: Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _navy,
          ),
        ),
      ),
    );
  }

  Widget _countChip(String label, int count, Color color) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
        child: Text(
          '$count',
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ),
      label: Text(label),
    );
  }
}
