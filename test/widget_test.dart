import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mimusic_flutter/main.dart';

void main() {
  testWidgets('MiMusic app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: MiMusicApp(),
      ),
    );

    // Verify that our app shows the loading text.
    expect(find.text('MiMusic Flutter - Loading...'), findsOneWidget);
  });
}
