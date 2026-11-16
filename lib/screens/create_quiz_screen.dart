import 'package:flutter/material.dart';

import '../services/classroom_service.dart';

class CreateQuizScreen extends StatefulWidget {
  const CreateQuizScreen({super.key, required this.classId});

  final String classId;

  @override
  State<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _MatchingPair {
  final TextEditingController left = TextEditingController();
  final TextEditingController right = TextEditingController();

  void dispose() {
    left.dispose();
    right.dispose();
  }
}

class _QuestionForm {
  final TextEditingController question = TextEditingController();
  final TextEditingController timerSeconds = TextEditingController(text: '30');
  final TextEditingController correctAnswer = TextEditingController();

  final List<TextEditingController> options = List.generate(
    4,
    (_) => TextEditingController(),
  );

  final List<_MatchingPair> pairs = [_MatchingPair(), _MatchingPair()];

  int correct = 0;
  final Set<int> correctIndices = {0};

  void addOption() {
    if (options.length < 6) {
      options.add(TextEditingController());
    }
  }

  void removeOption(int index) {
    if (options.length > 2) {
      options.removeAt(index).dispose();
      correctIndices.remove(index);

      final adjusted = correctIndices
          .map((value) => value > index ? value - 1 : value)
          .toSet();

      correctIndices
        ..clear()
        ..addAll(adjusted);

      if (correct >= options.length) {
        correct = 0;
      }
    }
  }

  void addPair() {
    pairs.add(_MatchingPair());
  }

  void removePair(int index) {
    if (pairs.length > 2) {
      pairs.removeAt(index).dispose();
    }
  }

  void dispose() {
    question.dispose();
    timerSeconds.dispose();
    correctAnswer.dispose();

    for (final option in options) {
      option.dispose();
    }

    for (final pair in pairs) {
      pair.dispose();
    }
  }
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  final TextEditingController title = TextEditingController();
  final List<_QuestionForm> forms = [_QuestionForm()];

  bool busy = false;
  bool isPublished = true;

  String quizType = 'multiple_choice';

  static const Map<String, String> quizTypes = {
    'multiple_choice': 'Multiple Choice',
    'true_false': 'True or False',
    'identification': 'Identification',
    'multiple_select': 'Multiple Select',
    'matching': 'Matching Type',
    'essay': 'Essay',
  };

  static const Map<String, IconData> quizIcons = {
    'multiple_choice': Icons.radio_button_checked,
    'true_false': Icons.check_circle_outline,
    'identification': Icons.short_text,
    'multiple_select': Icons.checklist,
    'matching': Icons.compare_arrows,
    'essay': Icons.edit_note,
  };

  @override
  void dispose() {
    title.dispose();

    for (final form in forms) {
      form.dispose();
    }

    super.dispose();
  }

  void addQuestion() {
    setState(() => forms.add(_QuestionForm()));
  }

  void removeQuestion(int index) {
    if (forms.length <= 1) return;

    setState(() {
      forms.removeAt(index).dispose();
    });
  }

  Map<String, dynamic> buildQuestion(_QuestionForm form) {
    final data = <String, dynamic>{
      'text': form.question.text.trim(),
      'timerSeconds': int.tryParse(form.timerSeconds.text.trim()) ?? 30,
    };

    switch (quizType) {
      case 'multiple_choice':
        data['options'] = form.options
            .take(4)
            .map((option) => option.text.trim())
            .toList();
        data['correctIndex'] = form.correct;
        break;

      case 'true_false':
        data['correctIndex'] = form.correct;
        break;

      case 'identification':
        data['correctAnswer'] = form.correctAnswer.text.trim();
        break;

      case 'multiple_select':
        data['options'] = form.options
            .map((option) => option.text.trim())
            .toList();
        data['correctIndices'] = form.correctIndices.toList()..sort();
        break;

      case 'matching':
        data['pairs'] = form.pairs
            .map(
              (pair) => {
                'left': pair.left.text.trim(),
                'right': pair.right.text.trim(),
              },
            )
            .toList();
        break;

      case 'essay':
        break;
    }

    return data;
  }

  bool validateForm() {
    if (title.text.trim().isEmpty) {
      showMessage('Please enter a quiz title.');
      return false;
    }

    for (var i = 0; i < forms.length; i++) {
      final form = forms[i];

      if (form.question.text.trim().isEmpty) {
        showMessage('Please enter Question ${i + 1}.');
        return false;
      }

      final timer = int.tryParse(form.timerSeconds.text.trim());

      if (timer == null || timer < 5 || timer > 600) {
        showMessage(
          'Question ${i + 1}: timer must be between 5 and 600 seconds.',
        );
        return false;
      }

      if (quizType == 'multiple_choice' &&
          form.options.take(4).any((option) => option.text.trim().isEmpty)) {
        showMessage('Complete all four options in Question ${i + 1}.');
        return false;
      }

      if (quizType == 'identification' &&
          form.correctAnswer.text.trim().isEmpty) {
        showMessage('Enter the correct answer for Question ${i + 1}.');
        return false;
      }

      if (quizType == 'multiple_select') {
        if (form.options.any((option) => option.text.trim().isEmpty)) {
          showMessage('Complete all options in Question ${i + 1}.');
          return false;
        }

        if (form.correctIndices.isEmpty) {
          showMessage(
            'Select at least one correct answer in Question ${i + 1}.',
          );
          return false;
        }
      }

      if (quizType == 'matching') {
        if (form.pairs.any(
          (pair) =>
              pair.left.text.trim().isEmpty || pair.right.text.trim().isEmpty,
        )) {
          showMessage('Complete all matching pairs in Question ${i + 1}.');
          return false;
        }
      }
    }

    return true;
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> save() async {
    if (busy || !validateForm()) return;

    setState(() => busy = true);

    try {
      await ClassroomService().createQuiz(
        classId: widget.classId,
        title: title.text.trim(),
        quizType: quizType,
        isPublished: isPublished,
        questions: forms.map(buildQuestion).toList(),
      );

      if (!mounted) return;

      showMessage(
        isPublished ? 'Quiz published successfully!' : 'Quiz saved as draft!',
      );

      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        showMessage('Could not create quiz: $e');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Widget sectionTitle(String text, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
          ],
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget buildQuizTypeSelector() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionTitle('Quiz format', icon: Icons.category_outlined),
            DropdownButtonFormField<String>(
              value: quizType,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Select quiz type',
                border: OutlineInputBorder(),
              ),
              items: quizTypes.entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.key,
                  child: Row(
                    children: [
                      Icon(quizIcons[entry.key], size: 20),
                      const SizedBox(width: 10),
                      Text(entry.value),
                    ],
                  ),
                );
              }).toList(),
              onChanged: busy
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => quizType = value);
                      }
                    },
            ),
            const SizedBox(height: 10),
            Text(
              quizType == 'essay'
                  ? 'Students will write their answers. Teachers must review and grade submissions.'
                  : quizType == 'multiple_select'
                  ? 'Students can select more than one correct answer.'
                  : quizType == 'matching'
                  ? 'Create pairs of related words, terms, or descriptions.'
                  : 'All questions in this quiz will use the selected format.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildQuestionTypeFields(_QuestionForm form) {
    switch (quizType) {
      case 'multiple_choice':
        return Column(
          children: [
            RadioGroup<int>(
              groupValue: form.correct,
              onChanged: (value) {
                if (value != null) {
                  setState(() => form.correct = value);
                }
              },
              child: Column(
                children: List.generate(4, (index) {
                  return RadioListTile<int>(
                    contentPadding: EdgeInsets.zero,
                    value: index,
                    title: TextField(
                      controller: form.options[index],
                      decoration: InputDecoration(
                        labelText: 'Option ${String.fromCharCode(65 + index)}',
                        hintText: 'Enter option',
                      ),
                    ),
                  );
                }),
              ),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select the radio button beside the correct answer.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        );

      case 'true_false':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose the correct answer:'),
            RadioGroup<int>(
              groupValue: form.correct,
              onChanged: (value) {
                if (value != null) {
                  setState(() => form.correct = value);
                }
              },
              child: const Column(
                children: [
                  RadioListTile<int>(
                    contentPadding: EdgeInsets.zero,
                    value: 0,
                    title: Text('True'),
                  ),
                  RadioListTile<int>(
                    contentPadding: EdgeInsets.zero,
                    value: 1,
                    title: Text('False'),
                  ),
                ],
              ),
            ),
          ],
        );

      case 'identification':
        return TextField(
          controller: form.correctAnswer,
          decoration: const InputDecoration(
            labelText: 'Correct answer',
            hintText: 'Enter the expected answer',
            prefixIcon: Icon(Icons.check_circle_outline),
          ),
        );

      case 'multiple_select':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...List.generate(form.options.length, (index) {
              return Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: form.options[index],
                      decoration: InputDecoration(
                        labelText: 'Option ${String.fromCharCode(65 + index)}',
                      ),
                    ),
                  ),
                  Checkbox(
                    value: form.correctIndices.contains(index),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          form.correctIndices.add(index);
                        } else {
                          form.correctIndices.remove(index);
                        }
                      });
                    },
                  ),
                  if (form.options.length > 2)
                    IconButton(
                      tooltip: 'Remove option',
                      onPressed: () {
                        setState(() => form.removeOption(index));
                      },
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                ],
              );
            }),
            if (form.options.length < 6)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(form.addOption),
                  icon: const Icon(Icons.add),
                  label: const Text('Add option'),
                ),
              ),
            const Text(
              'Check every correct answer. At least one must be selected.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        );

      case 'matching':
        return Column(
          children: [
            ...List.generate(form.pairs.length, (index) {
              final pair = form.pairs[index];

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: pair.left,
                        decoration: InputDecoration(
                          labelText: 'Column A - ${index + 1}',
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.compare_arrows),
                    ),
                    Expanded(
                      child: TextField(
                        controller: pair.right,
                        decoration: InputDecoration(
                          labelText: 'Column B - ${index + 1}',
                        ),
                      ),
                    ),
                    if (form.pairs.length > 2)
                      IconButton(
                        tooltip: 'Remove pair',
                        onPressed: () {
                          setState(() => form.removePair(index));
                        },
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                  ],
                ),
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(form.addPair),
                icon: const Icon(Icons.add),
                label: const Text('Add matching pair'),
              ),
            ),
          ],
        );

      case 'essay':
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.rate_review_outlined),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Students will provide a written response. This question requires manual teacher review and grading.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        );
    }

    return const SizedBox.shrink();
  }

  Widget buildQuestionCard(int index) {
    final form = forms[index];

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 16, child: Text('${index + 1}')),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Question ${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (forms.length > 1)
                  IconButton(
                    tooltip: 'Remove question',
                    onPressed: busy ? null : () => removeQuestion(index),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: form.question,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: 'Question text',
                hintText: 'Write your question here...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),
            sectionTitle('Answer configuration'),
            buildQuestionTypeFields(form),
            const SizedBox(height: 14),
            TextField(
              controller: form.timerSeconds,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Time limit (seconds)',
                helperText: 'Minimum 5 seconds, maximum 600 seconds.',
                prefixIcon: Icon(Icons.timer_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Quiz'),
        actions: [
          if (busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.quiz_outlined, color: Colors.white, size: 32),
                  SizedBox(height: 12),
                  Text(
                    'Build a new quiz',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Choose a format, add your questions, and prepare your students for assessment.',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    sectionTitle('Quiz information', icon: Icons.edit_note),
                    TextField(
                      controller: title,
                      decoration: const InputDecoration(
                        labelText: 'Quiz title',
                        hintText: 'e.g. Chapter 1 Assessment',
                        prefixIcon: Icon(Icons.title),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            buildQuizTypeSelector(),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: sectionTitle(
                    'Questions',
                    icon: Icons.format_list_numbered,
                  ),
                ),
                Text(
                  '${forms.length} total',
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
            ...List.generate(forms.length, buildQuestionCard),
            OutlinedButton.icon(
              onPressed: busy ? null : addQuestion,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Add another question'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 18),
            Card(
              elevation: 0,
              child: SwitchListTile(
                value: isPublished,
                onChanged: busy
                    ? null
                    : (value) => setState(() => isPublished = value),
                title: Text(
                  isPublished ? 'Publish quiz' : 'Save as draft',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  isPublished
                      ? 'Students can see and take this quiz.'
                      : 'Only the teacher can manage this unpublished quiz.',
                ),
                secondary: Icon(
                  isPublished ? Icons.public : Icons.drafts_outlined,
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: busy ? null : save,
              icon: Icon(isPublished ? Icons.publish : Icons.save_outlined),
              label: Text(
                busy
                    ? 'Saving quiz...'
                    : isPublished
                    ? 'Publish Quiz'
                    : 'Save Quiz as Draft',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
