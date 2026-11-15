import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../services/essay_review_service.dart';

class EssayReviewScreen extends StatelessWidget {
  const EssayReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = EssayReviewService();

    return Scaffold(
      appBar: AppBar(title: const Text('Essay Reviews')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.pendingReviews(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load essay submissions: ${snapshot.error}',
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final pending =
              snapshot.data!.docs.where((doc) {
                final data = doc.data();
                return data['status'] == 'submitted' &&
                    data['manualReviewStatus'] == 'pending';
              }).toList()..sort((a, b) {
                final aTime = a.data()['submittedAt'];
                final bTime = b.data()['submittedAt'];
                if (aTime is Timestamp && bTime is Timestamp) {
                  return bTime.compareTo(aTime);
                }
                return 0;
              });

          if (pending.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.task_alt_rounded, size: 58, color: Colors.green),
                    SizedBox(height: 14),
                    Text(
                      'No pending essay reviews',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'New essay submissions will appear here.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${pending.length} submission${pending.length == 1 ? '' : 's'} waiting for review',
                style: const TextStyle(
                  color: qmNavy,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ...pending.map((doc) {
                final data = doc.data();
                final uid = data['uid']?.toString() ?? 'Unknown student';
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: const CircleAvatar(
                      child: Icon(Icons.edit_document),
                    ),
                    title: Text(
                      data['quizTitle']?.toString() ?? 'Essay Quiz',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text('Student ID: $uid'),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      final reviewed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              EssayReviewDetailScreen(attemptId: doc.id),
                        ),
                      );
                      if (reviewed == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Essay grade saved successfully.'),
                          ),
                        );
                      }
                    },
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

class EssayReviewDetailScreen extends StatefulWidget {
  final String attemptId;

  const EssayReviewDetailScreen({super.key, required this.attemptId});

  @override
  State<EssayReviewDetailScreen> createState() =>
      _EssayReviewDetailScreenState();
}

class _EssayReviewDetailScreenState extends State<EssayReviewDetailScreen> {
  final EssayReviewService _service = EssayReviewService();
  late final Future<Map<String, dynamic>> _reviewFuture;
  final Map<String, TextEditingController> _scoreControllers = {};
  final Map<String, TextEditingController> _feedbackControllers = {};
  bool _controllersInitialized = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _reviewFuture = _service.loadReview(widget.attemptId);
  }

  @override
  void dispose() {
    for (final controller in _scoreControllers.values) {
      controller.dispose();
    }
    for (final controller in _feedbackControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeControllers(List<Map<String, dynamic>> questions) {
    if (_controllersInitialized) return;
    for (final question in questions) {
      final id = question['id'].toString();
      _scoreControllers[id] = TextEditingController(text: '0');
      _feedbackControllers[id] = TextEditingController();
    }
    _controllersInitialized = true;
  }

  Future<void> _saveGrade(List<Map<String, dynamic>> questions) async {
    final scores = <String, int>{};
    final feedback = <String, String>{};

    for (final question in questions) {
      final id = question['id'].toString();
      final maxPoints = (question['points'] as num).toInt();
      final score = int.tryParse(_scoreControllers[id]!.text.trim());

      if (score == null || score < 0 || score > maxPoints) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enter a valid score from 0 to $maxPoints.')),
        );
        return;
      }

      scores[id] = score;
      feedback[id] = _feedbackControllers[id]!.text.trim();
    }

    setState(() => _saving = true);
    try {
      await _service.gradeAttempt(
        attemptId: widget.attemptId,
        scores: scores,
        feedback: feedback,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save grade: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review Essay Submission')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _reviewFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Unable to open submission: ${snapshot.error}'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final result = snapshot.data!;
          final attempt = result['attempt'] as Map<String, dynamic>;
          final questions = (result['questions'] as List)
              .cast<Map<String, dynamic>>();
          _initializeControllers(questions);

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      attempt['quizTitle']?.toString() ?? 'Essay Quiz',
                      style: const TextStyle(
                        color: qmNavy,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text('Student ID: ${attempt['uid'] ?? 'Unknown'}'),
                    const SizedBox(height: 16),
                    if (questions.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No essay questions were found.'),
                        ),
                      ),
                    ...questions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final question = entry.value;
                      final id = question['id'].toString();
                      final maxPoints = (question['points'] as num).toInt();
                      final answer = question['answer'];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Question ${index + 1}',
                                style: const TextStyle(
                                  color: qmBlue,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                question['text']?.toString() ?? '',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Student answer',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(top: 6),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: SelectableText(
                                  answer?.toString().trim().isNotEmpty == true
                                      ? answer.toString()
                                      : '(No answer provided)',
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _scoreControllers[id],
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Points awarded (0–$maxPoints)',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _feedbackControllers[id],
                                minLines: 2,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  labelText: 'Feedback for student (optional)',
                                  alignLabelWithHint: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving || questions.isEmpty
                          ? null
                          : () => _saveGrade(questions),
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(_saving ? 'Saving...' : 'Save Final Grade'),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
