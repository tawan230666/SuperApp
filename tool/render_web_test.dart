import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superapp/main.dart';
import 'package:superapp/navigation/app_router.dart';

void main() {
  testWidgets('render responsive Web review images with empty local data', (
    tester,
  ) async {
    // This executable is a flutter_test harness kept under tool/ for opt-in renders.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    await (FontLoader(
      'NotoSansThai',
    )..addFont(rootBundle.load('assets/fonts/NotoSansThai.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    tester.view.devicePixelRatio = 1;
    final key = GlobalKey();
    Directory('docs/previews/web').createSync(recursive: true);
    for (final width in [390, 768, 1024, 1440, 1920]) {
      tester.view.physicalSize = Size(width.toDouble(), 1100);
      await tester.pumpWidget(RepaintBoundary(key: key, child: const MyApp()));
      await tester.pumpAndSettle();
      final router =
          tester.widget<MaterialApp>(find.byType(MaterialApp)).routerDelegate!
              as CapitalRouter;
      for (final path in ['/dashboard', '/bot']) {
        router.navigate(path);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'docs/previews/web/${path.substring(1)}-$width.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
  });
}
