// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:heart_beat/main.dart';

void main() {
  testWidgets('App renders and shows connect button', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const HeartBeatApp());

    // Verify UI elements exist
    expect(find.text('心拍数表示 (Android / Windows)'), findsOneWidget);
    expect(find.text('Coospo HW9 に接続'), findsOneWidget);
  });
}
