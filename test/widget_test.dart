import 'package:flutter_test/flutter_test.dart';
import 'package:athena/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AthenaApp());
    expect(find.text('SCAN'), findsOneWidget);
  });
}
