import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superapp/domain/investment_plan.dart';
import 'package:superapp/ui/bot_dashboard.dart';

void main() {
  testWidgets('paper controls persist fills and emergency at 320px', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: BotDashboard(plan: InvestmentPlan())),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start Paper'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Paper'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ทดลองซื้อ 1 หน่วย ฿1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ทดลองซื้อ 1 หน่วย ฿1'));
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getString(
        'tipkhun.paper.synthetic.v1',
      ),
      contains('"state":"filled"'),
    );
    await tester.ensureVisible(find.text('Emergency Stop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Emergency Stop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getString(
        'tipkhun.paper.synthetic.v1',
      ),
      isNot(contains('"state":"locked"')),
    );
    await tester.tap(find.text('Emergency Stop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยืนยันหยุดฉุกเฉิน'));
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getString(
        'tipkhun.paper.synthetic.v1',
      ),
      contains('locked'),
    );
    expect(tester.takeException(), isNull);
  });
}
