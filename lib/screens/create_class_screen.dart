import 'package:flutter/material.dart';

import '../services/classroom_service.dart';

class CreateClassScreen extends StatefulWidget {
  const CreateClassScreen({super.key});

  @override
  State<CreateClassScreen> createState() => _CreateClassScreenState();
}

class _CreateClassScreenState extends State<CreateClassScreen> {
  final TextEditingController name = TextEditingController();
  final TextEditingController section = TextEditingController();
  final TextEditingController maxStudents = TextEditingController(text: '40');

  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    section.dispose();
    maxStudents.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final capacity = int.tryParse(maxStudents.text.trim());

    if (name.text.trim().isEmpty || section.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter class name and section.')),
      );
      return;
    }

    if (capacity == null || capacity < 1 || capacity > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum students must be between 1 and 500.'),
        ),
      );
      return;
    }

    setState(() => busy = true);

    try {
      final code = await ClassroomService().createClass(
        name.text.trim(),
        section.text.trim(),
        maxStudents: capacity,
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Class created!'),
          content: SelectableText(
            'Share this join code with your students:\n\n$code',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not create class: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Class')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'Class name (e.g. Information Technology)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: section,
              decoration: const InputDecoration(
                labelText: 'Section (e.g. BSIT 2A)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: maxStudents,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Maximum students (1–500)',
                helperText: 'Default: 40 students',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : save,
                child: Text(busy ? 'Creating...' : 'Create Class'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
