import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';
import 'student_home_screen.dart';
import 'teacher_home_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, auth) {
        if (auth.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }
        final user = auth.data;
        if (user == null) return const LoginScreen();

        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          key: ValueKey(user.uid),
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(),
          builder: (context, profile) {
            if (profile.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen();
            }
            if (profile.hasError) {
              return _MessageScreen(
                title: 'Could not load your profile',
                message: 'Check your internet connection and Firestore rules, then try again.',
                action: 'Sign out',
                onPressed: () => AuthService().logout(),
              );
            }
            if (!profile.hasData || !profile.data!.exists) {
              return _MessageScreen(
                title: 'Profile not found',
                message: 'Your account has no QuizMaster profile. Sign out and register again, or contact the administrator.',
                action: 'Sign out',
                onPressed: () => AuthService().logout(),
              );
            }

            final data = profile.data!.data()!;
            final role = data['role'];
            if (data['isActive'] != true) {
              return _MessageScreen(
                title: 'Account disabled',
                message: 'This account is not active. If this is an older teacher account, update its isActive field to true and approvalStatus to approved in Firestore.',
                action: 'Sign out',
                onPressed: () => AuthService().logout(),
              );
            }
            if (role == 'teacher') return const TeacherHomeScreen();
            if (role == 'student') return const StudentHomeScreen();
            return _MessageScreen(
              title: 'Unsupported account role',
              message:
                  'This account role is not configured for the mobile app.',
              action: 'Sign out',
              onPressed: () => AuthService().logout(),
            );
          },
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _MessageScreen extends StatelessWidget {
  const _MessageScreen({
    required this.title,
    required this.message,
    required this.action,
    required this.onPressed,
  });
  final String title;
  final String message;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline_rounded, size: 48),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(onPressed: onPressed, child: Text(action)),
          ],
        ),
      ),
    ),
  );
}
