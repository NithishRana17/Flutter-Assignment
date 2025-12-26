// Basic Flutter widget test for Logbook Lite

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logbook_lite/main.dart';

void main() {
  testWidgets('App builds successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: LogbookLiteApp(),
      ),
    );

    // Verify the app starts
    expect(find.byType(LogbookLiteApp), findsOneWidget);
  });
}
