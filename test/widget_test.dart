import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superapp/main.dart';
import 'package:superapp/data/plan_repository.dart';
import 'package:superapp/domain/investment_plan.dart';
import 'package:superapp/ui/workspace_widgets.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('mobile can record a loss and see remaining budget', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('Tipkhun Capital'), findsOneWidget);
    await tester.tap(find.text('บันทึกเทรด').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('บันทึกผลเทรด'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'TEST');
    await tester.enterText(find.byType(TextFormField).at(1), '-5');
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(find.text('TEST'), findsOneWidget);
    await tester.tap(find.text('ภาพรวม').last);
    await tester.pumpAndSettle();
    expect(find.text('฿12.50'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('wide layout and profit routing navigation render', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    await tester.tap(find.text('แบ่งกำไร').first);
    await tester.pumpAndSettle();
    expect(find.text('กำไรพร้อมจัดสรร'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('all pages fit mobile $width', (tester) async {
      tester.view.physicalSize = Size(width, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      for (final label in [
        'ภาพรวม',
        'บันทึกเทรด',
        'แบ่งกำไร',
        'ระยะยาว',
        'ผู้ช่วย',
      ]) {
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }
    });
  }
  testWidgets('overview quick actions record a trade and open the assistant', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(QuickAction, 'บันทึกเทรด'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'DEMO');
    await tester.enterText(find.byType(TextFormField).at(1), '-5');
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(find.text('฿12.50'), findsOneWidget);
    await tester.tap(find.widgetWithText(QuickAction, 'ทบทวนแผน'));
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.text('วันนี้เหลืองบความเสี่ยงเท่าไร?')),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('วันนี้เหลืองบความเสี่ยงเท่าไร?'));
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('allocation review saves once and updates the long-term page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1050);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final plan = InvestmentPlan()..record('DEMO', 1000);
    await LocalPlanRepository().save(plan);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('แบ่งกำไร').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ตรวจสอบและแบ่งกำไร'));
    await tester.tap(find.text('ตรวจสอบและแบ่งกำไร'));
    await tester.pumpAndSettle();
    expect(find.text('ยืนยันการกันกำไร'), findsOneWidget);
    await tester.tap(find.text('ยืนยัน'));
    await tester.pumpAndSettle();
    final saved = await LocalPlanRepository().load();
    expect(saved!.allocations, hasLength(1));
    expect(saved.longTerm, 300);
    expect(saved.distributable, 0);
    await tester.tap(find.text('ระยะยาว').last);
    await tester.pumpAndSettle();
    expect(find.text('฿3.00'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('stopped state and larger text fit a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await LocalPlanRepository().save(InvestmentPlan()..record('DEMO', -2000));
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('พักการเทรด'), findsOneWidget);
    for (final label in [
      'ภาพรวม',
      'บันทึกเทรด',
      'แบ่งกำไร',
      'ระยะยาว',
      'ผู้ช่วย',
    ]) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -450));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }
    }
  });
}
