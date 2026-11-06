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
  Map<String, dynamic>? _quiz;
  final Map<String, String> _answers = {};
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

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
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
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not start quiz. Check your connection, class enrollment, and whether the quiz is published.';
        });
      }
    }
  }

  void _startQuestionTimer() {
    _timer?.cancel();
    if (_questions.isEmpty || _currentIndex >= _questions.length) return;
    final seconds = (_questions[_currentIndex]['timerSeconds'] as num?)?.toInt() ?? 30;
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
        const SnackBar(content: Text('Time is up for that question. Moving to the next question.')),
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
          content: const Text('Are you sure you want to submit your answers? You cannot change them after submission.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Continue quiz')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Submit')),
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
        answers: Map<String, String>.from(_answers),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: Text(auto ? 'Quiz completed' : 'Quiz submitted'),
          content: Text('Score: ${result['score'] ?? 0} / ${result['totalPoints'] ?? 0}'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submission failed. Check your connection and try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) {
      return Scaffold(appBar: AppBar(title: Text(widget.title)), body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!))));
    }
    final questions = _questions;
    if (questions.isEmpty) return const Scaffold(body: Center(child: Text('No questions available.')));
    final question = questions[_currentIndex];
    final id = (question['id'] ?? question['questionId'] ?? _currentIndex).toString();
    final options = (question['options'] as List? ?? []).map((v) => v.toString()).toList();
    final progress = (_currentIndex + 1) / questions.length;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Question ${_currentIndex + 1} of ${questions.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('$_secondsLeft sec', style: TextStyle(fontWeight: FontWeight.w800, color: _secondsLeft <= 5 ? Colors.red : Theme.of(context).colorScheme.primary)),
            ]),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress),
          ]),
        ),
        Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(question['text']?.toString() ?? 'Question', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 18),
            RadioGroup<String>(
              groupValue: _answers[id],
              onChanged: (value) {
                if (!_submitting && value != null) setState(() => _answers[id] = value);
              },
              child: Column(children: options.map((option) => RadioListTile<String>(contentPadding: EdgeInsets.zero, title: Text(option), value: option)).toList()),
            ),
          ]))),
        ])),
        SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, child: FilledButton(
          onPressed: _submitting ? null : () => _currentIndex + 1 == questions.length ? _submit() : _nextQuestion(),
          child: Text(_currentIndex + 1 == questions.length ? 'Submit quiz' : 'Next question'),
        )))),
      ]),
    );
  }
}
