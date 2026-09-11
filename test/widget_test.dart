import 'package:flutter_test/flutter_test.dart';
import 'package:under_fummander_tracker/main.dart';

void main() {
  testWidgets('La aplicación inicia correctamente', (WidgetTester tester) async {
    await tester.pumpWidget(const UnderFummanderTracker());

    expect(find.text('Under Fummander Tracker'), findsOneWidget);
  });
}