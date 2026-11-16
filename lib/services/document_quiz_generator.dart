import 'dart:math';

class DocumentQuizGenerator {
  static const _stopWords = {
    'about',
    'above',
    'after',
    'again',
    'against',
    'also',
    'among',
    'because',
    'before',
    'being',
    'below',
    'between',
    'both',
    'could',
    'does',
    'doing',
    'during',
    'each',
    'from',
    'further',
    'have',
    'having',
    'here',
    'hers',
    'him',
    'himself',
    'into',
    'itself',
    'more',
    'most',
    'other',
    'over',
    'same',
    'should',
    'some',
    'such',
    'than',
    'that',
    'their',
    'theirs',
    'them',
    'themselves',
    'then',
    'there',
    'these',
    'they',
    'this',
    'those',
    'through',
    'under',
    'until',
    'very',
    'what',
    'when',
    'where',
    'which',
    'while',
    'will',
    'with',
    'would',
    'your',
    'yours',
    'you',
    'and',
    'are',
    'for',
    'not',
    'but',
    'can',
    'was',
    'were',
    'the',
    'a',
    'an',
    'in',
    'on',
    'at',
    'to',
    'of',
    'is',
    'as',
    'by',
    'or',
    'be',
    'it',
    'if',
    'we',
    'he',
    'she',
  };

  List<Map<String, dynamic>> generate({
    required String sourceText,
    required String quizType,
    required int questionCount,
    int timerSeconds = 30,
  }) {
    if (questionCount < 1 || questionCount > 50) {
      throw ArgumentError('Question count must be between 1 and 50.');
    }

    if (timerSeconds < 5 || timerSeconds > 600) {
      throw ArgumentError('Timer must be between 5 and 600 seconds.');
    }

    final sentences = _sentences(sourceText);

    if (sentences.isEmpty) {
      throw ArgumentError(
        'The document does not contain enough readable sentences.',
      );
    }

    if (sentences.length < questionCount) {
      throw ArgumentError(
        'The document contains only ${sentences.length} usable sentences. '
        'You requested $questionCount questions. '
        'Please choose a document with more readable content '
        'or enter a lower question count.',
      );
    }

    final terms = _terms(sourceText);

    if (terms.length < 2) {
      throw ArgumentError(
        'The document needs more readable content to generate questions.',
      );
    }

    final questions = <Map<String, dynamic>>[];
    final random = Random();

    for (var i = 0; i < questionCount; i++) {
      final sentence = sentences[i];
      final keyword = _keyword(sentence, terms, i);
      final distractors = terms
          .where((term) => term.toLowerCase() != keyword.toLowerCase())
          .toList();

      final distractor = distractors.isEmpty
          ? 'Not stated in the document'
          : distractors[i % distractors.length];

      final question = <String, dynamic>{
        'text': '',
        'timerSeconds': timerSeconds,
      };

      switch (quizType) {
        case 'multiple_choice':
          final options = <String>[
            keyword,
            ...distractors
                .where((term) => term.toLowerCase() != distractor.toLowerCase())
                .take(2),
            distractor,
          ];

          while (options.length < 4) {
            options.add('None of the above ${options.length}');
          }

          final shuffledOptions = options.take(4).toList()..shuffle(random);

          question['text'] =
              'Which term completes this statement: '
              '${_blank(sentence, keyword)}?';
          question['options'] = shuffledOptions;
          question['correctIndex'] = shuffledOptions.indexOf(keyword);
          break;

        case 'true_false':
          final makeFalse = i.isOdd;
          final statement = makeFalse
              ? _replaceTerm(sentence, keyword, distractor)
              : sentence;
          final options = <String>['True', 'False']..shuffle(random);
          final correctAnswer = makeFalse ? 'False' : 'True';

          question['text'] =
              'Is the following statement true or false?\n'
              '$statement';
          question['options'] = options;
          question['correctIndex'] = options.indexOf(correctAnswer);
          break;

        case 'identification':
          question['text'] =
              'Identify the term described below: '
              '${_blank(sentence, keyword)}.';
          question['correctAnswer'] = keyword;
          break;

        case 'multiple_select':
          final secondCorrect = terms.firstWhere(
            (term) =>
                term.toLowerCase() != keyword.toLowerCase() &&
                sentence.toLowerCase().contains(term.toLowerCase()),
            orElse: () => keyword,
          );

          final correctAnswers = <String>[
            keyword,
            if (secondCorrect != keyword) secondCorrect,
          ];

          final options = <String>[
            ...correctAnswers,
            ...distractors
                .where(
                  (term) => !correctAnswers.any(
                    (correct) => correct.toLowerCase() == term.toLowerCase(),
                  ),
                )
                .take(4),
          ]..shuffle(random);

          question['text'] =
              'Select the term or terms that appear in this statement: '
              '${_shorten(sentence, 180)}';
          question['options'] = options;
          question['correctIndices'] = correctAnswers
              .map(options.indexOf)
              .toList();
          break;

        case 'matching':
          final pairs = <Map<String, String>>[];
          final used = <String>{};

          for (var j = 0; j < sentences.length && pairs.length < 4; j++) {
            final current = sentences[(i + j) % sentences.length];
            final term = _keyword(current, terms, i + j);

            if (used.add(term.toLowerCase())) {
              pairs.add({
                'left': term,
                'right': _shorten(
                  current.replaceAll(
                    RegExp(RegExp.escape(term), caseSensitive: false),
                    '_____ ',
                  ),
                  120,
                ),
              });
            }
          }

          while (pairs.length < 2) {
            final term = terms[(i + pairs.length) % terms.length];
            if (used.add(term.toLowerCase())) {
              pairs.add({
                'left': term,
                'right': 'Related statement from the source document',
              });
            }
          }

          question['text'] = 'Match each term in Column A with its corresponding statement in Column B.';
          question['pairs'] = pairs;
          break;

        case 'essay':
          question['text'] =
              'Explain the main idea of this statement:\n'
              '${_shorten(sentence, 240)}';
          break;

        default:
          throw ArgumentError('Unsupported quiz type: $quizType');
      }

      questions.add(question);
    }

    return questions;
  }

  List<String> _sentences(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ')
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((sentence) => sentence.trim())
        .where((sentence) => sentence.length >= 25)
        .toSet()
        .toList();
  }

  List<String> _terms(String text) {
    final matches = RegExp(r'\b[A-Za-z][A-Za-z0-9-]{3,}\b')
        .allMatches(text)
        .map((match) => match.group(0)!)
        .where((word) => !_stopWords.contains(word.toLowerCase()));

    final counts = <String, int>{};

    for (final word in matches) {
      final key = word.toLowerCase();
      counts[key] = (counts[key] ?? 0) + 1;
    }

    final original = <String, String>{};

    for (final match in RegExp(
      r'\b[A-Za-z][A-Za-z0-9-]{3,}\b',
    ).allMatches(text)) {
      final word = match.group(0)!;
      original.putIfAbsent(word.toLowerCase(), () => word);
    }

    final ranked = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    return ranked.map((key) => original[key]!).toList();
  }

  String _keyword(String sentence, List<String> terms, int seed) {
    final matches = terms
        .where((term) => sentence.toLowerCase().contains(term.toLowerCase()))
        .toList();

    if (matches.isNotEmpty) {
      matches.sort((a, b) => b.length.compareTo(a.length));
      return matches[seed % matches.length];
    }

    return terms[seed % terms.length];
  }

  String _blank(String sentence, String keyword) {
    return sentence.replaceFirst(
      RegExp(RegExp.escape(keyword), caseSensitive: false),
      '_____',
    );
  }

  String _replaceTerm(String sentence, String keyword, String replacement) {
    return sentence.replaceFirst(
      RegExp(RegExp.escape(keyword), caseSensitive: false),
      replacement,
    );
  }

  String _shorten(String text, int limit) {
    if (text.length <= limit) return text;
    return '${text.substring(0, limit).trim()}...';
  }
}
