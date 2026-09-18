import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superapp/main.dart';
import 'package:superapp/ui/plan_forms.dart';
import 'package:superapp/data/plan_repository.dart';
import 'package:superapp/domain/investment_plan.dart';
import 'package:superapp/services/assistant_service.dart';

class RetryRepository implements PlanRepository {
  int attempts = 0;
  @override
  Future<InvestmentPlan?> load() async {
    if (attempts++ == 0) throw StateError('unavailable');
    return InvestmentPlan();
  }

  @override
  Future<void> save(InvestmentPlan plan) async {}
}

class ControlledAssistant implements AssistantService {
  final pending = Completer<String>();
  @override
  Future<String> reply(String question, InvestmentPlan plan) => pending.future;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  void mobile(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'plan sections save validated inputs without losing allocation ratios',
    (tester) async {
      mobile(tester);
      final original = InvestmentPlan()..setAllocation(40, 40, 20);
      await LocalPlanRepository().save(original);
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('รายละเอียดแผน'));
      await tester.pumpAndSettle();
      expect(find.text('เลือกรูปแบบแผน'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '500');
      await tester.tap(find.text('ใช้แผนนี้'));
      await tester.pumpAndSettle();
      final saved = (await LocalPlanRepository().load())!;
      expect(saved.capital, 50000);
      expect(saved.shortPercent, 40);
      expect(saved.trades, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('locked plan details preserve recorded trades and allocations', (
    tester,
  ) async {
    mobile(tester);
    final original = InvestmentPlan()
      ..record('TEST', 1000)
      ..allocate();
    await LocalPlanRepository().save(original);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('รายละเอียดแผน'));
    await tester.pumpAndSettle();
    expect(
      find.text('แผนล็อกหลังบันทึกเทรดแรก เพื่อรักษาเกณฑ์คำนวณย้อนหลัง'),
      findsOneWidget,
    );
    expect(find.byType(TextFormField), findsNothing);
    await tester.tap(find.text('ปิด'));
    await tester.pumpAndSettle();
    expect((await LocalPlanRepository().load())!.toJson(), original.toJson());
    expect(tester.takeException(), isNull);
  });
  testWidgets('read error offers retry and restores the dashboard', (
    tester,
  ) async {
    mobile(tester);
    await tester.pumpWidget(MyApp(repository: RetryRepository()));
    await tester.pumpAndSettle();
    expect(find.text('ไม่สามารถโหลดข้อมูลได้'), findsOneWidget);
    await tester.tap(find.text('ลองใหม่'));
    await tester.pumpAndSettle();
    expect(find.text('งบเสี่ยงคงเหลือ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'assistant composer remains reachable with keyboard and pending reply',
    (tester) async {
      mobile(tester);
      final service = ControlledAssistant();
      await tester.pumpWidget(MyApp(assistantService: service));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ผู้ช่วย').last);
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'งบเหลือเท่าไร');
      expect(tester.getBottomRight(find.byType(TextField)).dy, lessThan(564));
      await tester.tap(find.byTooltip('ส่งคำถาม'));
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
      expect(tester.takeException(), isNull);
      service.pending.complete('งบคงเหลือ 17.50 บาท');
      await tester.pumpAndSettle();
      expect(find.text('งบคงเหลือ 17.50 บาท'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, true);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('forms and settings fit 320px with larger text', (tester) async {
    mobile(tester);
    tester.view.physicalSize = const Size(320, 740);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    for (final form in ['plan', 'trade', 'ratios']) {
      final context = tester.element(find.byType(CapitalHome));
      switch (form) {
        case 'plan':
          showPlanForm(context, InvestmentPlan());
        case 'trade':
          showTradeForm(context, InvestmentPlan());
        case 'ratios':
          showRatioForm(context, InvestmentPlan());
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: form);
      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: form);
      await tester.tap(find.text('ยกเลิก'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byTooltip('ตั้งค่า'));
    await tester.pumpAndSettle();
    expect(find.text('เกี่ยวกับ Tipkhun Capital'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
