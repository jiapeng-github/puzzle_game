import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_game/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PuzzleApp());
    expect(find.byType(PuzzleApp), findsOneWidget);
  });
}
