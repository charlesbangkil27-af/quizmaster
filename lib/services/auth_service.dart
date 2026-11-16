import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> authChanges() => _auth.authStateChanges();

  Future<void> register({
    required String displayName,
    required String email,
    required String password,
    required String role,
  }) async {
    if (role != 'student' && role != 'teacher') {
      throw ArgumentError('Only student and teacher accounts can register.');
    }
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) throw StateError('Registration failed.');

    try {
      await user.updateDisplayName(displayName.trim());
      await _db.collection('users').doc(user.uid).set({
        'displayName': displayName.trim(),
        'email': email.trim(),
        'role': role,
        // Student and teacher accounts are active immediately after registration.
        'isActive': true,
        'approvalStatus': 'approved',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Avoid leaving an authenticated account without its Firestore profile.
      await user.delete();
      rethrow;
    }
  }

  Future<void> login({required String email, required String password}) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> logout() => _auth.signOut();
}
