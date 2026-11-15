import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/classroom_service.dart';
import '../services/document_reader_service.dart';
import '../services/document_quiz_generator.dart';

class AiQuizGeneratorScreen extends StatefulWidget {
  const AiQuizGeneratorScreen({super.key, required this.classId});

  final String classId;

  @override
  State<AiQuizGeneratorScreen> createState() => _AiQuizGeneratorScreenState();
}

class _AiQuizGeneratorScreenState extends State<AiQuizGeneratorScreen> {
  final titleController = TextEditingController();
  final questionCountController = TextEditingController(text: '10');
  final timerSecondsController = TextEditingController(text: '30');

  final reader = DocumentReaderService();
  final generator = DocumentQuizGenerator();

  PlatformFile? selectedFile;
  ExtractedDocument? document;
  List<Map<String, dynamic>> questions = [];

  String quizType = 'multiple_choice';
  int questionCount = 10;
  int timerSeconds = 30;

  bool reading = false;
  bool generating = false;
  bool saving = false;

  static const quizTypes = <String, String>{
    'multiple_choice': 'Multiple Choice',
    'true_false': 'True or False',
    'identification': 'Identification',
    'multiple_select': 'Multiple Select',
    'matching': 'Matching Type',
    'essay': 'Essay',
  };

  @override
  void dispose() {
    titleController.dispose();
    questionCountController.dispose();
    timerSecondsController.dispose();
    super.dispose();
  }

  Future<void> pickDocument() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'pptx', 'txt'],
      );

      if (file == null || !mounted) return;

      setState(() {
        reading = true;
        selectedFile = file;
        document = null;
        questions = [];
      });

      final extracted = await reader.extract(file);

      if (!mounted) return;

      setState(() {
        document = extracted;
        titleController.text = file.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
      });

      _message('Document successfully read.');
    } catch (error) {
      if (mounted) _message('Could not read document: $error', error: true);
    } finally {
      if (mounted) setState(() => reading = false);
    }
  }

  void generateQuestions() {
    if (document == null) {
      _message('Please select a document first.', error: true);
      return;
    }

    final requestedCount = int.tryParse(questionCountController.text.trim());
    final requestedTimer = int.tryParse(timerSecondsController.text.trim());

    if (requestedCount == null || requestedCount < 1 || requestedCount > 50) {
      _message('Number of questions must be between 1 and 50.', error: true);
      return;
    }

    if (requestedTimer == null || requestedTimer < 5 || requestedTimer > 600) {
      _message(
        'Time per question must be between 5 and 600 seconds.',
        error: true,
      );
      return;
    }

    setState(() {
      generating = true;
      questionCount = requestedCount;
      timerSeconds = requestedTimer;
    });

    try {
      final result = generator.generate(
        sourceText: document!.text,
        quizType: quizType,
        questionCount: requestedCount,
        timerSeconds: requestedTimer,
      );

      setState(() {
        questions = result;
      });

      _message('${result.length} questions generated. Please review them.');
    } catch (error) {
      _message('Generation failed: $error', error: true);
    } finally {
      if (mounted) {
        setState(() => generating = false);
      }
    }
  }

  Future<void> saveQuiz({required bool publish}) async {
    if (saving) return;

    if (questions.isEmpty) {
      _message('Generate questions before saving.', error: true);
      return;
    }

    if (titleController.text.trim().isEmpty) {
      _message('Please enter a quiz title.', error: true);
      return;
    }

    setState(() => saving = true);

    try {
      await ClassroomService().createQuiz(
        classId: widget.classId,
        title: titleController.text.trim(),
        questions: questions,
        quizType: quizType,
        isPublished: publish,
      );

      if (!mounted) return;

      _message(
        publish
            ? 'Quiz published successfully. Students can now access it.'
            : 'Quiz saved as draft successfully.',
      );
      Navigator.pop(context);
    } catch (error) {
      _message('Could not save quiz: $error', error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }

  Widget _buildQuestionEditor(int index) {
    final question = questions[index];
    final List<String> options =
        (question['options'] as List?)?.cast<String>() ??
        (quizType == 'true_false' ? <String>['True', 'False'] : <String>[]);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Question ${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove question',
                  onPressed: () {
                    setState(() => questions.removeAt(index));
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
            TextFormField(
              key: ValueKey('question-$index-${question['text']}'),
              initialValue: question['text']?.toString() ?? '',
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Question',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              onChanged: (value) => question['text'] = value,
            ),
            const SizedBox(height: 12),

            if (quizType == 'multiple_choice' || quizType == 'true_false') ...[
              const Text(
                'Select the correct answer',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              RadioGroup<int>(
                groupValue: question['correctIndex'] as int? ?? 0,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => question['correctIndex'] = value);
                },
                child: Column(
                  children: List.generate(
                    options.length,
                    (optionIndex) => RadioListTile<int>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: TextFormField(
                        key: ValueKey('option-$index-$optionIndex'),
                        initialValue: options[optionIndex],
                        decoration: InputDecoration(
                          labelText: 'Option ${optionIndex + 1}',
                          isDense: true,
                        ),
                        onChanged: (value) => options[optionIndex] = value,
                      ),
                      value: optionIndex,
                    ),
                  ),
                ),
              ),
            ],

            if (quizType == 'identification') ...[
              TextFormField(
                key: ValueKey('answer-$index'),
                initialValue: question['correctAnswer']?.toString() ?? '',
                decoration: const InputDecoration(
                  labelText: 'Correct answer',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => question['correctAnswer'] = value,
              ),
            ],

            if (quizType == 'multiple_select') ...[
              const Text(
                'Edit options and select all correct answers',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              ...List.generate(options.length, (optionIndex) {
                final selected = (question['correctIndices'] as List? ?? [])
                    .contains(optionIndex);

                return Row(
                  children: [
                    Checkbox(
                      value: selected,
                      onChanged: (checked) {
                        setState(() {
                          final indices = (question['correctIndices'] as List)
                              .cast<int>();
                          if (checked == true) {
                            if (!indices.contains(optionIndex)) {
                              indices.add(optionIndex);
                            }
                          } else {
                            indices.remove(optionIndex);
                          }
                        });
                      },
                    ),
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('multi-$index-$optionIndex'),
                        initialValue: options[optionIndex],
                        decoration: InputDecoration(
                          labelText: 'Option ${optionIndex + 1}',
                          isDense: true,
                        ),
                        onChanged: (value) => options[optionIndex] = value,
                      ),
                    ),
                  ],
                );
              }),
            ],

            if (quizType == 'matching') ...[
              const Text(
                'Matching pairs',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...List.generate((question['pairs'] as List).length, (pairIndex) {
                final pair =
                    (question['pairs'] as List)[pairIndex]
                        as Map<String, dynamic>;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('left-$index-$pairIndex'),
                          initialValue: pair['left']?.toString() ?? '',
                          decoration: const InputDecoration(
                            labelText: 'Term',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (value) => pair['left'] = value,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          key: ValueKey('right-$index-$pairIndex'),
                          initialValue: pair['right']?.toString() ?? '',
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Match',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (value) => pair['right'] = value,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            if (quizType == 'essay')
              const Text(
                'Essay responses will be manually checked and graded by the teacher.',
                style: TextStyle(color: Colors.deepOrange),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generate Quiz from Document')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.science_outlined, color: Colors.deepOrange),
                      SizedBox(width: 8),
                      Text(
                        'Offline Demo Generator',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    'This prototype extracts terms and sentences from your '
                    'document. It is not yet powered by an AI model. '
                    'Always review questions and answers before saving.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            OutlinedButton.icon(
              onPressed: reading ? null : pickDocument,
              icon: reading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(
                reading ? 'Reading document...' : 'Select learning document',
              ),
            ),

            if (selectedFile != null) ...[
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: Text(selectedFile!.name),
                subtitle: Text(
                  document == null
                      ? 'Reading...'
                      : '${document!.characterCount} characters extracted',
                ),
              ),
            ],

            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              maxLength: 140,
              decoration: const InputDecoration(
                labelText: 'Quiz title',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: quizType,
              decoration: const InputDecoration(
                labelText: 'Quiz type',
                border: OutlineInputBorder(),
              ),
              items: quizTypes.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  quizType = value;
                  questions = [];
                });
              },
            ),

            const SizedBox(height: 18),
            TextField(
              controller: questionCountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Number of Questions',
                helperText: 'Enter a number from 1 to 50',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                final parsed = int.tryParse(value.trim());
                if (parsed != null && parsed >= 1 && parsed <= 50) {
                  setState(() => questionCount = parsed);
                }
              },
            ),

            const SizedBox(height: 16),
            TextField(
              controller: timerSecondsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Time per Question (seconds)',
                helperText: 'Enter a number from 5 to 600 seconds',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                final parsed = int.tryParse(value.trim());
                if (parsed != null && parsed >= 5 && parsed <= 600) {
                  setState(() {
                    timerSeconds = parsed;
                    for (final question in questions) {
                      question['timerSeconds'] = parsed;
                    }
                  });
                }
              },
            ),

            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: document == null || generating
                  ? null
                  : generateQuestions,
              icon: generating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(generating ? 'Generating...' : 'Generate Questions'),
            ),

            if (questions.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Review Generated Questions (${questions.length})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'Edit the question text, options, and correct answers. '
                'Remove any question that is not suitable.',
              ),
              const SizedBox(height: 12),
              ...List.generate(questions.length, _buildQuestionEditor),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: saving ? null : () => saveQuiz(publish: false),
                icon: const Icon(Icons.save_outlined),
                label: Text(saving ? 'Saving...' : 'Save as Draft'),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: saving ? null : () => saveQuiz(publish: true),
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.publish),
                label: Text(saving ? 'Publishing...' : 'Publish to Students'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
