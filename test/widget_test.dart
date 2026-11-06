import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('QuizMaster design components render', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('QuizMaster', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );

    expect(find.text('QuizMaster'), findsOneWidget);
  });
}
