import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ayar/src/design.dart';

void main() {
  testWidgets('RTL chevron points to the left', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.rtl,
      child: DirectionChevron(),
    ));
    expect(tester.widget<Icon>(find.byType(Icon)).icon,
      Icons.chevron_left_rounded);
  });

  testWidgets('LTR chevron points to the right', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: DirectionChevron(),
    ));
    expect(tester.widget<Icon>(find.byType(Icon)).icon,
      Icons.chevron_right_rounded);
  });

  testWidgets('Rapid number updates settle on latest value', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: AnimateNumber('1'),
    )));
    for (var i=2;i<40;i++) {
      await tester.pumpWidget(MaterialApp(home:Scaffold(
        body:AnimateNumber('$i'),
      )));
      await tester.pump(const Duration(milliseconds:5));
    }
    await tester.pump(const Duration(milliseconds:250));
    expect(find.text('39'),findsOneWidget);
  });
}
