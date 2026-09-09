import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superapp/main.dart';
import 'package:superapp/navigation/app_router.dart';
import 'package:superapp/data/plan_repository.dart';
import 'package:superapp/data/paper_repository.dart';
import 'package:superapp/domain/investment_plan.dart';
import 'package:superapp/services/assistant_service.dart';
import 'package:superapp/state/paper_session.dart';
import 'package:superapp/ui/trade_table.dart';
import 'package:superapp/ui/web_panels.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('route parser preserves all public paths and unknown routes', () async {
    const parser = CapitalRouteParser();
    for (final path in [...appPaths, '/missing']) {
      expect(
        await parser.parseRouteInformation(
          RouteInformation(uri: Uri(path: path)),
        ),
        path,
      );
      expect(parser.restoreRouteInformation(path).uri.path, path);
    }
    expect(
      await parser.parseRouteInformation(RouteInformation(uri: Uri(path: '/'))),
      '/dashboard',
    );
  });
  test('chart series derives net P&L including fees, empty remains empty', () {
    final p = InvestmentPlan();
    expect(journalEquity(p), isEmpty);
    p.record('FIXTURE', 100, fees: 10);
    p.record('FIXTURE', -200);
    expect(journalEquity(p), [35000, 35090, 34890]);
    expect(journalDrawdown(p), [0, 0, -200]);
  });
  test('CSV escapes quotes, newlines and spreadsheet formulas', () {
    expect(csvCell('=HYPERLINK("bad")'), '"\'=HYPERLINK(""bad"")"');
    expect(csvCell(' @SUM(1)'), '"\' @SUM(1)"');
    final p = InvestmentPlan()..record('FIXTURE,\nasset', 101, fees: 1);
    final csv = tradeCsv(p.trades);
    expect(csv, contains('"FIXTURE,\nasset"'));
    expect(csv, contains('"101","1","100"'));
    expect(csv, contains('Manual journal'));
  });
  test(
    'paper repository reload preserves state without legacy mutation',
    () async {
      final legacy = InvestmentPlan()..record('LEGACY FIXTURE', 100);
      await LocalPlanRepository().save(legacy);
      final before = (await SharedPreferences.getInstance()).getString(
        LocalPlanRepository.key,
      );
      final session = PaperSession(LocalPaperRepository());
      await session.load(legacy);
      await session.run(session.engine!.start);
      await session.run(() async {
        await session.engine!.submit('fixture');
      });
      final restored = PaperSession(LocalPaperRepository());
      await restored.load(legacy);
      expect(restored.engine!.state.name, 'paused');
      expect(restored.engine!.reserved, 100);
      expect(
        (await SharedPreferences.getInstance()).getString(
          LocalPlanRepository.key,
        ),
        before,
      );
      session.dispose();
      restored.dispose();
    },
  );
  test(
    'copilot reports missing backtest and actual paper status read-only',
    () async {
      final session = PaperSession(LocalPaperRepository());
      await session.load(InvestmentPlan());
      await session.run(session.engine!.start);
      final service = LocalAssistantService(
        readPaper: () => session.engine!.snapshot(),
      );
      final before = session.engine!.snapshot();
      expect(
        await service.reply('สถานะ bot', InvestmentPlan()),
        contains('active'),
      );
      expect(
        await service.reply('ผล backtest', InvestmentPlan()),
        contains('ยังไม่มี'),
      );
      expect(session.engine!.snapshot(), before);
      session.dispose();
    },
  );
  for (final width in [390.0, 768.0, 1024.0, 1440.0, 1920.0]) {
    testWidgets('all web routes fit $width with populated journal', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final plan = InvestmentPlan()
        ..record('FIXTURE', 100, fees: 1, strategy: 'test-only');
      await LocalPlanRepository().save(plan);
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      final router =
          tester.widget<MaterialApp>(find.byType(MaterialApp)).routerDelegate!
              as CapitalRouter;
      for (final path in [...appPaths, '/missing']) {
        router.navigate(path);
        await tester.pumpAndSettle();
        expect(router.currentConfiguration, path);
        expect(tester.takeException(), isNull, reason: '$width $path');
        if (path == '/trades' && width >= 1024) {
          expect(find.byType(PaginatedDataTable), findsOneWidget);
        }
      }
      router.navigate('/dashboard');
      await tester.pumpAndSettle();
      expect(
        width >= 1024
            ? find.byType(NavigationRail)
            : find.byType(NavigationBar),
        findsOneWidget,
      );
    });
  }
  testWidgets('desktop journal filters update rows and empty state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await LocalPlanRepository().save(
      InvestmentPlan()
        ..record('ALPHA', 100)
        ..record('BETA', -50),
    );
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    final router =
        tester.widget<MaterialApp>(find.byType(MaterialApp)).routerDelegate!
            as CapitalRouter;
    router.navigate('/trades');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'NO MATCH');
    await tester.pumpAndSettle();
    expect(find.byType(PaginatedDataTable), findsNothing);
    await tester.enterText(find.byType(TextField), 'ALPHA');
    await tester.pumpAndSettle();
    expect(find.byType(PaginatedDataTable), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('large text bot and analytics remain scrollable', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    final router =
        tester.widget<MaterialApp>(find.byType(MaterialApp)).routerDelegate!
            as CapitalRouter;
    for (final path in ['/bot', '/risk-analytics', '/settings']) {
      router.navigate(path);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
