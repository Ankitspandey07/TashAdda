import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teen_patti_app/main.dart';

void main() {
  testWidgets('main menu shows branding and play options', (tester) async {
    await tester.pumpWidget(const TeenPattiApp());
    expect(find.text('TashAdda'), findsOneWidget);
    expect(find.text('Play vs Bots'), findsOneWidget);
    expect(find.text('Play Online (Room Code)'), findsOneWidget);
    expect(find.text('Create Local Room (Host)'), findsOneWidget);
    expect(find.text('Search Local Rooms (Join)'), findsOneWidget);
  });

  testWidgets('main menu fills a phone-width screen without overflow', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const TeenPattiApp());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
