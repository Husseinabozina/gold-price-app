import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ayar/src/data.dart';
import 'package:ayar/src/screens.dart';

void main() {
  testWidgets('Welcome fits small screens with large accessibility text', (tester) async {
    tester.view.physicalSize = const Size(320, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.6)),
        child: child!,
      ),
      home: WelcomeScreen(data: PreviewData()),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('الدخول كزائر'));
    await tester.tap(find.text('الدخول كزائر'));
    await tester.pumpAndSettle();
    expect(find.text('الأسعار اليوم'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
