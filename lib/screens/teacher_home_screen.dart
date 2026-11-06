import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../services/auth_service.dart';
import '../services/classroom_service.dart';
import 'class_detail_screen.dart';
import 'create_class_screen.dart';
import 'teacher_dashboard_screen.dart';
import 'notifications_screen.dart';

class TeacherHomeScreen extends StatelessWidget {
  const TeacherHomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final service = ClassroomService();
    final displayName = FirebaseAuth.instance.currentUser?.displayName?.trim();
    final firstName = (displayName == null || displayName.isEmpty)
        ? 'Teacher'
        : displayName.split(' ').first;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            QuizMasterLogo(size: 32),
            SizedBox(width: 9),
            Text('QuizMaster'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Dashboard',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TeacherDashboardScreen()),
            ),
            icon: const Icon(Icons.analytics_rounded),
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: qmBlue,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateClassScreen()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create class'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.teacherClasses(),
        builder: (context, snapshot) {
          final classCount = snapshot.data?.docs.length ?? 0;
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
            children: [
              Container(
                padding: const EdgeInsets.all(23),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF171F45), Color(0xFF5945B8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: qmPurple.withValues(alpha: .2),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      right: -10,
                      top: -18,
                      child: Icon(
                        Icons.cast_for_education_rounded,
                        size: 125,
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
                            'TEACHER WORKSPACE',
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
                          'Welcome, $firstName 👋',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Create classes and make learning interactive.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .78),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            _stat(
                              Icons.groups_rounded,
                              '$classCount',
                              'Your classes',
                            ),
                            const SizedBox(width: 12),
                            _stat(Icons.quiz_rounded, 'Create', 'Quizzes'),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 23),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your Classes',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontSize: 19),
                    ),
                  ),
                  const Icon(Icons.grid_view_rounded, color: qmBlue),
                ],
              ),
              const SizedBox(height: 12),
              if (snapshot.hasError)
                _empty(
                  Icons.cloud_off_rounded,
                  'Unable to load classes',
                  'Check your connection and Firestore rules.',
                ),
              if (!snapshot.hasData && !snapshot.hasError)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (snapshot.hasData && snapshot.data!.docs.isEmpty)
                _empty(
                  Icons.add_home_work_rounded,
                  'No classes yet',
                  'Tap “Create class” to set up your first classroom.',
                ),
              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty)
                ...snapshot.data!.docs.asMap().entries.map((entry) {
                  final doc = entry.value;
                  final data = doc.data();
                  final className = '${data['name'] ?? 'Class'}';
                  final section = '${data['section'] ?? ''}';
                  final code = '${data['joinCode'] ?? '—'}';
                  const colors = [
                    qmBlue,
                    qmPurple,
                    Color(0xFF0E9F8A),
                    Color(0xFFEA8B35),
                  ];
                  final color = colors[entry.key % colors.length];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClassDetailScreen(
                              classId: doc.id,
                              className: '$className - $section',
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: .12),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Icon(
                                      Icons.school_rounded,
                                      color: color,
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          className,
                                          style: const TextStyle(
                                            color: qmNavy,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Section: $section',
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
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F6FC),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.key_rounded,
                                      size: 18,
                                      color: qmBlue,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Join code',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    SelectableText(
                                      code,
                                      style: const TextStyle(
                                        color: qmBlue,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
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

Widget _stat(IconData icon, String value, String label) => Expanded(
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
Widget _empty(IconData icon, String title, String subtitle) => Card(
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
