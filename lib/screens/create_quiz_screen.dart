import 'package:flutter/material.dart';

import '../services/classroom_service.dart';

class CreateQuizScreen extends StatefulWidget {
  const CreateQuizScreen({super.key, required this.classId});

  final String classId;

  @override
  State<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _QuestionForm {
  final TextEditingController question = TextEditingController();
  final TextEditingController timerSeconds = TextEditingController(text: '30');
  final List<TextEditingController> options = List.generate(
    4,
    (_) => TextEditingController(),
  );
  int correct = 0;

  void dispose() {
    question.dispose();
    timerSeconds.dispose();
    for (final option in options) {
      option.dispose();
    }
  }
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  final TextEditingController title = TextEditingController();
  final List<_QuestionForm> forms = [_QuestionForm()];
  bool busy = false;

  @override
  void dispose() {
    title.dispose();
    for (final form in forms) {
      form.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    final invalid =
        title.text.trim().isEmpty ||
        forms.any(
          (form) =>
              form.question.text.trim().isEmpty ||
              form.options.any((option) => option.text.trim().isEmpty),
        );

    if (invalid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Fill in the quiz title, every question, and all four options.',
          ),
        ),
      );
      return;
    }

    setState(() => busy = true);
    try {
      await ClassroomService().createQuiz(
        classId: widget.classId,
        title: title.text.trim(),
        questions: forms
            .map(
              (form) => <String, dynamic>{
                'text': form.question.text.trim(),
                'options': form.options
                    .map((option) => option.text.trim())
                    .toList(),
                'correctIndex': form.correct,
                'timerSeconds':
                    int.tryParse(form.timerSeconds.text.trim()) ?? 30,
              },
            )
            .toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quiz created successfully.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not create quiz: $e')));
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
      appBar: AppBar(title: const Text('Create Quiz')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: title,
            decoration: const InputDecoration(labelText: 'Quiz title'),
          ),
          const SizedBox(height: 12),
          ...List.generate(forms.length, (index) {
            final form = forms[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 14),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Question ${index + 1}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextField(
                      controller: form.question,
                      decoration: const InputDecoration(labelText: 'Question'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: form.timerSeconds,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Time limit (seconds)',
                        helperText: 'Set 5 to 600 seconds for this question.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    RadioGroup<int>(
                      groupValue: form.correct,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => form.correct = value);
                        }
                      },
                      child: Column(
                        children: List.generate(
                          4,
                          (optionIndex) => RadioListTile<int>(
                            contentPadding: EdgeInsets.zero,
                            value: optionIndex,
                            title: TextField(
                              controller: form.options[optionIndex],
                              decoration: InputDecoration(
                                labelText:
                                    'Option ${String.fromCharCode(65 + optionIndex)}',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Text(
                      'Select the radio button beside the correct answer.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: () => setState(() => forms.add(_QuestionForm())),
            icon: const Icon(Icons.add),
            label: const Text('Add question'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: busy ? null : save,
            child: Text(busy ? 'Saving...' : 'Save quiz'),
          ),
        ],
      ),
    );
  }
}
