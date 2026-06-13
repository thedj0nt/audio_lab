import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:audio_lab_frontend/main.dart';

void main() {
  testWidgets('Audio Lab App Smoke Test', (WidgetTester tester) async {
    // Set screen size to desktop width
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: AudioLabApp(),
      ),
    );

    // Verify that the brand name is displayed in the DAW sidebar/workspace.
    expect(find.text('ECHO LAB'), findsOneWidget);
    expect(find.text('Music Library'), findsOneWidget);

    // Reset physical size after test
    addTearDown(tester.view.resetPhysicalSize);
  });
}
