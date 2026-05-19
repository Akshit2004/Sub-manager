import 'package:flutter_test/flutter_test.dart';

import 'package:sub_manager/main.dart';

void main() {
  testWidgets('shows the landing page', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('SubManager'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });
}
