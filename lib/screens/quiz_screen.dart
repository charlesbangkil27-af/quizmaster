import 'dart:async';

import 'package:flutter/material.dart';

import '../services/quiz_service.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.quizId, required this.title});

  final String quizId;
  final String title;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final QuizService _service = QuizService();
  final Map<String, dynamic> _answers = {};
  final Map<String, TextEditingController> _essayControllers = {};

  Map<String, dynamic>? _quiz;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  Timer? _timer;
  int _currentIndex = 0;
  int _secondsLeft = 0;

  List<Map<String, dynamic>> get _questions =>
      (_quiz?['questions'] as List? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  String get _quizType => (_quiz?['quizType'] ?? 'multiple_choice').toString();

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _essayControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final data = await _service.startQuiz(widget.quizId);
      if (!mounted) return;
      setState(() {
        _quiz = data;
        _loading = false;
      });
      _startQuestionTimer();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  void _startQuestionTimer() {
    _timer?.cancel();
    if (_questions.isEmpty || _currentIndex >= _questions.length) return;

    final seconds =
        (_questions[_currentIndex]['timerSeconds'] as num?)?.toInt() ?? 30;
    setState(() => _secondsLeft = seconds.clamp(5, 600));

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _submitting) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        _nextQuestion(expired: true);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _nextQuestion({bool expired = false}) {
    if (_submitting) return;
    if (_currentIndex + 1 >= _questions.length) {
      _submit(auto: true);
      return;
    }

    setState(() => _currentIndex++);
    _startQuestionTimer();

    if (expired && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Time is up for that question. Moving to the next question.',
          ),
        ),
      );
    }
  }

  Future<void> _submit({bool auto = false}) async {
    if (_submitting || _quiz == null) return;

    if (!auto) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Submit quiz?'),
          content: const Text(
            'Are you sure you want to submit your answers? '
            'You cannot change them after submission.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Continue quiz'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _submitting = true);
    _timer?.cancel();

    try {
      final result = await _service.submitQuiz(
        attemptId: (_quiz!['attemptId'] ?? _quiz!['id']).toString(),
        answers: Map<String, dynamic>.from(_answers),
      );
      if (!mounted) return;

      final needsReview = result['needsManualReview'] == true;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(auto ? 'Quiz completed' : 'Quiz submitted'),
          content: Text(
            needsReview
                ? 'Your essay response has been submitted. '
                      'Your teacher needs to review it before a final score is available.'
                : 'Score: ${result['score'] ?? 0} / '
                      '${result['totalPoints'] ?? 0}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Submission failed: ${error.toString().replaceFirst('Bad state: ', '')}',
          ),
        ),
      );
    }
  }

  String _questionId(Map<String, dynamic> question, int index) =>
      (question['id'] ?? question['questionId'] ?? index).toString();

  Widget _buildAnswer(
    BuildContext context,
    Map<String, dynamic> question,
    String id,
  ) {
    final type = (question['quizType'] ?? _quizType).toString();
    final options = (question['options'] as List? ?? [])
        .map((value) => value.toString())
        .toList();

    switch (type) {
      case 'multiple_choice':
      case 'true_false':
        final selected = _answers[id];
        return RadioGroup<int>(
          groupValue: selected is int ? selected : null,
          onChanged: (value) {
            if (!_submitting && value != null) {
              setState(() => _answers[id] = value);
            }
          },
          child: Column(
            children: List.generate(options.length, (index) {
              return RadioListTile<int>(
                contentPadding: EdgeInsets.zero,
                value: index,
                title: Text(options[index]),
              );
            }),
          ),
        );

      case 'identification':
        return TextFormField(
          key: ValueKey('identification_$id'),
          initialValue: _answers[id]?.toString() ?? '',
          enabled: !_submitting,
          onChanged: (value) => _answers[id] = value,
          decoration: const InputDecoration(
            hintText: 'Type your answer here',
            border: OutlineInputBorder(),
          ),
        );

      case 'multiple_select':
        final selected = (_answers[id] as List? ?? [])
            .whereType<num>()
            .map((value) => value.toInt())
            .toSet();
        return Column(
          children: List.generate(options.length, (index) {
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: selected.contains(index),
              title: Text(options[index]),
              onChanged: _submitting
                  ? null
                  : (checked) {
                      setState(() {
                        final updated = Set<int>.from(selected);
                        if (checked == true) {
                          updated.add(index);
                        } else {
                          updated.remove(index);
                        }
                        _answers[id] = updated.toList()..sort();
                      });
                    },
            );
          }),
        );

      case 'matching':
        final pairs = (question['pairs'] as List? ?? [])
            .whereType<Map>()
            .map(
              (pair) => {
                'left': (pair['left'] ?? '').toString(),
                'right': (pair['right'] ?? '').toString(),
              },
            )
            .toList();
        final rightOptions =
            pairs.map((pair) => pair['right']!).toSet().toList()..sort();
        final current = (_answers[id] as Map? ?? {}).map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        );

        return Column(
          children: pairs.map((pair) {
            final left = pair['left']!;
            final selectedValue = current[left];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    left,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: rightOptions.contains(selectedValue)
                        ? selectedValue
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      hintText: 'Choose the matching answer',
                      border: OutlineInputBorder(),
                    ),
                    items: rightOptions
                        .map(
                          (option) => DropdownMenuItem<String>(
                            value: option,
                            child: Text(option),
                          ),
                        )
                        .toList(),
                    onChanged: _submitting
                        ? null
                        : (value) {
                            setState(() {
                              final updated = Map<String, String>.from(current);
                              if (value == null) {
                                updated.remove(left);
                              } else {
                                updated[left] = value;
                              }
                              _answers[id] = updated;
                            });
                          },
                  ),
                ],
              ),
            );
          }).toList(),
        );

      case 'essay':
        final controller = _essayControllers.putIfAbsent(
          id,
          () => TextEditingController(text: _answers[id]?.toString() ?? ''),
        );
        return TextField(
          controller: controller,
          enabled: !_submitting,
          minLines: 5,
          maxLines: 10,
          onChanged: (value) => _answers[id] = value,
          decoration: const InputDecoration(
            hintText: 'Write your answer here...',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        );

      default:
        return const Text(
          'This question type is not supported. Please contact your teacher.',
        );
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'multiple_choice':
        return 'MULTIPLE CHOICE';
      case 'true_false':
        return 'TRUE OR FALSE';
      case 'identification':
        return 'IDENTIFICATION';
      case 'multiple_select':
        return 'SELECT ALL THAT APPLY';
      case 'matching':
        return 'MATCHING TYPE';
      case 'essay':
        return 'ESSAY';
      default:
        return 'QUIZ QUESTION';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final questions = _questions;
    if (questions.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No questions available.')),
      );
    }

    final question = questions[_currentIndex];
    final id = _questionId(question, _currentIndex);
    final type = (question['quizType'] ?? _quizType).toString();
    final progress = (_currentIndex + 1) / questions.length;
    final isLast = _currentIndex + 1 == questions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_currentIndex + 1}/${questions.length}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Question ${_currentIndex + 1} of ${questions.length}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '$_secondsLeft sec',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _secondsLeft <= 5
                            ? Colors.red
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(value: progress, minHeight: 7),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _typeLabel(type),
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          question['text']?.toString() ?? 'Question',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (type == 'multiple_select') ...[
                          const SizedBox(height: 8),
                          Text(
                            'Select all correct answers.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 20),
                        _buildAnswer(context, question, id),
                      ],
                    ),
                  ),
                ),
                if (type == 'essay') ...[
                  const SizedBox(height: 8),
                  Text(
                    'Your essay will be reviewed by your teacher.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submitting
                      ? null
                      : () => isLast ? _submit() : _nextQuestion(),
                  icon: Icon(
                    isLast ? Icons.check_circle_outline : Icons.arrow_forward,
                  ),
                  label: Text(isLast ? 'Submit quiz' : 'Next question'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
