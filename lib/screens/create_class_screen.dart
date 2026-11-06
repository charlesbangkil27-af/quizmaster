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

  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    section.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty || section.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter class name and section.')),
      );
      return;
    }

    setState(() => busy = true);

    try {
      final code = await ClassroomService().createClass(
        name.text.trim(),
        section.text.trim(),
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
