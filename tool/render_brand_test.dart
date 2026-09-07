import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superapp/main.dart';
import 'package:superapp/ui/brand_mark.dart';

void main() {
  testWidgets('Export brand assets and design previews', (tester) async {
    final font = FontLoader('NotoSansThai')
      ..addFont(rootBundle.load('assets/fonts/NotoSansThai.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    tester.view.devicePixelRatio = 1;
    final key = GlobalKey();
    Future<void> save(String path) async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(path).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    final files = [
      ...Directory('android/app/src/main/res')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('ic_launcher.png')),
      ...Directory(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset',
      ).listSync().whereType<File>().where((f) => f.path.endsWith('.png')),
      ...Directory(
        'macos/Runner/Assets.xcassets/AppIcon.appiconset',
      ).listSync().whereType<File>().where((f) => f.path.endsWith('.png')),
      ...Directory('web')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.png')),
    ];
    for (final file in files) {
      final bytes = file.readAsBytesSync();
      final size = ByteData.sublistView(bytes).getUint32(16).toDouble();
      tester.view.physicalSize = Size.square(size);
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: const Color(0xFF123C32),
            child: Center(child: BrandMark(size: size * .75)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await save(file.path);
    }
    for (final size in [
      const Size(320, 740),
      const Size(390, 844),
      const Size(1440, 1050),
    ]) {
      // This executable is run with flutter test to export deterministic previews.
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size;
      await tester.pumpWidget(RepaintBoundary(key: key, child: const MyApp()));
      await tester.pumpAndSettle();
      await save('docs/previews/overview-${size.width.toInt()}.png');
      expect(tester.takeException(), isNull);
      for (final entry in {
        'journal': 'บันทึกเทรด',
        'allocation': 'แบ่งกำไร',
        'long-term': 'ระยะยาว',
        'assistant': 'ผู้ช่วย',
      }.entries) {
        await tester.tap(
          find.descendant(
            of: find.byType(size.width >= 850 ? NavigationRail : NavigationBar),
            matching: find.text(entry.value),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        await save('docs/previews/${entry.key}-${size.width.toInt()}.png');
        expect(tester.takeException(), isNull, reason: entry.key);
      }
      await tester.pumpWidget(const SizedBox());
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
