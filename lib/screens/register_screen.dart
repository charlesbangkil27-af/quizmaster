import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}
class _RegisterScreenState extends State<RegisterScreen> {
  final name = TextEditingController(), email = TextEditingController(), password = TextEditingController();
  String role = 'student'; bool busy = false, hide = true;
  @override void dispose() { name.dispose(); email.dispose(); password.dispose(); super.dispose(); }
  void msg(String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  Future<void> create() async {
    if (name.text.trim().isEmpty || !email.text.contains('@') || password.text.length < 6) { msg('Enter name, valid email, and password (6+ characters).'); return; }
    setState(() => busy = true);
    try { await AuthService().register(displayName: name.text.trim(), email: email.text.trim(), password: password.text, role: role); if (mounted) Navigator.pop(context); }
    on FirebaseAuthException catch (e) { if (mounted) msg(e.message ?? 'Registration failed'); }
    catch (e) { if (mounted) msg('Could not create profile: $e'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create account')),
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: Card(child: Padding(padding: const EdgeInsets.all(25), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Center(child: QuizMasterLogo(size: 66)),
      const SizedBox(height: 18), const Text('Join QuizMaster', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: qmNavy)), const SizedBox(height: 6), const Text('Create your account and start learning.', style: TextStyle(height: 1.4)), const SizedBox(height: 22),
      const Text('Full name', style: TextStyle(fontWeight: FontWeight.w700, color: qmNavy)), const SizedBox(height: 7), TextField(controller: name, decoration: const InputDecoration(hintText: 'Your name', prefixIcon: Icon(Icons.person_outline_rounded))),
      const SizedBox(height: 14), const Text('Email address', style: TextStyle(fontWeight: FontWeight.w700, color: qmNavy)), const SizedBox(height: 7), TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'you@example.com', prefixIcon: Icon(Icons.mail_outline_rounded))),
      const SizedBox(height: 14), const Text('Password', style: TextStyle(fontWeight: FontWeight.w700, color: qmNavy)), const SizedBox(height: 7), TextField(controller: password, obscureText: hide, decoration: InputDecoration(hintText: 'At least 6 characters', prefixIcon: const Icon(Icons.lock_outline_rounded), suffixIcon: IconButton(onPressed: () => setState(() => hide = !hide), icon: Icon(hide ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
      const SizedBox(height: 14), const Text('Account type', style: TextStyle(fontWeight: FontWeight.w700, color: qmNavy)), const SizedBox(height: 7), DropdownButtonFormField<String>(initialValue: role, decoration: const InputDecoration(prefixIcon: Icon(Icons.badge_outlined)), items: const [DropdownMenuItem(value: 'student', child: Text('Student')), DropdownMenuItem(value: 'teacher', child: Text('Teacher'))], onChanged: (v) => setState(() => role = v ?? 'student')),
      const SizedBox(height: 20), SizedBox(height: 52, child: FilledButton(onPressed: busy ? null : create, child: busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create account'))),
      const SizedBox(height: 12), const Text('Your account will be activated automatically. You can sign in and start using QuizMaster right away.', style: TextStyle(fontSize: 12, height: 1.4))
    ])))))));
}
