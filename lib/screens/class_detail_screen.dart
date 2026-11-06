import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../services/classroom_service.dart';
import 'create_quiz_screen.dart';
import 'quiz_screen.dart';
import 'leaderboard_screen.dart';
import '../services/notification_service.dart';

class ClassDetailScreen extends StatelessWidget {
  const ClassDetailScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  final String classId;
  final String className;

  @override
  Widget build(BuildContext context) {
    final service = ClassroomService();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, profile) {
        if (profile.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (profile.hasError || !profile.hasData || !profile.data!.exists) {
          return const Scaffold(
            body: Center(child: Text('Could not load account profile.')),
          );
        }
        final isTeacher = profile.data?.data()?['role'] == 'teacher';
        final quizzes = isTeacher
            ? service.teacherQuizzesForClass(classId)
            : service.studentQuizzesForClass(classId);

        return Scaffold(
          appBar: AppBar(
            title: Text(className),
            actions: [
              if (isTeacher)
                IconButton(
                  tooltip: 'Post announcement',
                  icon: const Icon(Icons.campaign_outlined),
                  onPressed: () => _showAnnouncement(context, classId),
                ),
              IconButton(
                tooltip: 'Leaderboard',
                icon: const Icon(Icons.emoji_events_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LeaderboardScreen(
                      classId: classId,
                      className: className,
                    ),
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: isTeacher
              ? FloatingActionButton.extended(
                  backgroundColor: qmBlue,
                  foregroundColor: Colors.white,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateQuizScreen(classId: classId),
                    ),
                  ),
                  icon: const Icon(Icons.quiz_rounded),
                  label: const Text('Create quiz'),
                )
              : null,
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: quizzes,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'Could not load quizzes. Check your connection and Firestore rules.',
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.quiz_outlined,
                          size: 48,
                          color: qmBlue,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isTeacher
                              ? 'No quizzes created yet.'
                              : 'No published quizzes yet.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data();
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE9EDFF),
                        child: Icon(Icons.assignment_rounded, color: qmBlue),
                      ),
                      title: Text(
                        data['title']?.toString() ?? 'Quiz',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: qmNavy,
                        ),
                      ),
                      subtitle: Text('${data['questionCount'] ?? 0} questions'),
                      trailing: Icon(
                        isTeacher
                            ? Icons.chevron_right_rounded
                            : Icons.play_circle_fill_rounded,
                        color: qmBlue,
                      ),
                      onTap: isTeacher
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => QuizScreen(
                                  quizId: doc.id,
                                  title: data['title']?.toString() ?? 'Quiz',
                                ),
                              ),
                            ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

Future<void> _showAnnouncement(BuildContext context, String classId) async {
  final title = TextEditingController();
  final message = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final send = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Class announcement'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: title,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a title.' : null,
            ),
            TextFormField(
              controller: message,
              maxLength: 1000,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Message'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a message.' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(dialogContext, true);
            }
          },
          child: const Text('Send'),
        ),
      ],
    ),
  );
  if (send == true && context.mounted) {
    try {
      await NotificationService().createAnnouncement(
        classId: classId,
        title: title.text,
        message: message.text,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement sent to your students.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send announcement: $e')),
        );
      }
    }
  }
  title.dispose();
  message.dispose();
}
