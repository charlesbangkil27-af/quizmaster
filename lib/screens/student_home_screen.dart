import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/classroom_service.dart';
import '../main.dart';
import 'class_detail_screen.dart';
import 'student_progress_screen.dart';
import 'notifications_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});
  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final code = TextEditingController();
  final svc = ClassroomService();
  bool joining = false;
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Future<void> join() async {
    if (code.text.trim().isEmpty) {
      msg('Enter a class join code first.');
      return;
    }
    setState(() => joining = true);
    try {
      await svc.joinClass(code.text.trim().toUpperCase());
      code.clear();
      msg('You joined the class successfully!');
    } catch (e) {
      msg(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => joining = false);
    }
  }

  void msg(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  @override
  Widget build(BuildContext context) {
    final displayName = FirebaseAuth.instance.currentUser?.displayName?.trim();
    final firstName = (displayName == null || displayName.isEmpty)
        ? 'Student'
        : displayName.split(' ').first;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: qmBlue),
            SizedBox(width: 9),
            Text('QuizMaster'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'My Progress',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StudentProgressScreen()),
            ),
            icon: const Icon(Icons.insights_rounded),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => AuthService().logout(),
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: svc.studentClasses(),
        builder: (context, s) {
          final count = s.data?.docs.length ?? 0;
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [qmNavy, Color(0xFF3448A8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: qmBlue.withValues(alpha: .18),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -12,
                      top: -18,
                      child: Icon(
                        Icons.school_rounded,
                        size: 120,
                        color: Colors.white.withValues(alpha: .08),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Text(
                            'STUDENT SPACE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Hey, $firstName 👋',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Ready to learn something new today?',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .78),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            _heroStat(
                              Icons.groups_rounded,
                              '$count',
                              'Joined classes',
                            ),
                            const SizedBox(width: 12),
                            _heroStat(
                              Icons.bolt_rounded,
                              'Learn',
                              'At your pace',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Join a classroom',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontSize: 19),
                    ),
                  ),
                  const Icon(Icons.key_rounded, color: qmBlue),
                ],
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Enter the code shared by your teacher to access class quizzes.',
                        style: TextStyle(height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: code,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                hintText: 'e.g. ABC123',
                                prefixIcon: Icon(Icons.vpn_key_rounded),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 54,
                            child: FilledButton(
                              onPressed: joining ? null : join,
                              child: joining
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.arrow_forward_rounded),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'My Classes',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontSize: 19),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9EDFF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$count classes',
                      style: const TextStyle(
                        color: qmBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (s.hasError)
                _emptyPanel(
                  Icons.cloud_off_rounded,
                  'Could not load classes',
                  'Check your connection and Firestore rules.',
                ),
              if (!s.hasData && !s.hasError)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (s.hasData && s.data!.docs.isEmpty)
                _emptyPanel(
                  Icons.menu_book_rounded,
                  'Your classroom starts here',
                  'Join a class using the code from your teacher.',
                ),
              if (s.hasData && s.data!.docs.isNotEmpty)
                ...s.data!.docs.asMap().entries.map((entry) {
                  final d = entry.value;
                  final x = d.data();
                  final colors = [
                    qmBlue,
                    qmPurple,
                    const Color(0xFF0E9F8A),
                    const Color(0xFFEA8B35),
                  ];
                  final color = colors[entry.key % colors.length];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClassDetailScreen(
                              classId: x['classId'].toString(),
                              className:
                                  '${x['className'] ?? 'Classroom'} - ${x['section'] ?? '—'}',
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.school_rounded,
                                  color: color,
                                  size: 27,
                                ),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      x['className'] ?? 'Classroom',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: qmNavy,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      'Section: ${x['section'] ?? '—'}',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xFF9AA3B8),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

Widget _heroStat(IconData icon, String value, String label) => Expanded(
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .72),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);
Widget _emptyPanel(IconData icon, String title, String subtitle) => Card(
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
    child: Column(
      children: [
        Icon(icon, size: 38, color: qmBlue.withValues(alpha: .7)),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(color: qmNavy, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(height: 1.4),
        ),
      ],
    ),
  ),
);
